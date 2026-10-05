#!/usr/bin/env bash
################################################################################
# FILE NAME   : run-poc.sh
# DESCRIPTION : 처리량 PoC 일괄 실행 — 레이트별로 C 송신기 + 수신기(node·c)를 돌리고 Markdown 결과 표 출력
#
# 사용: ./run-poc.sh                       기본 — 1만·10만·100만 건/초, 64B, 10초, node·c 수신기
#       DURATION=5 ./run-poc.sh            짧게
#       RATES="50000 200000" RECEIVERS=node MSG_SIZE=256 ./run-poc.sh
# 환경변수: RATES, MSG_SIZE, DURATION, RECEIVERS, PORT_BASE, OUT_DIR, NODE_BIN
# bash 3.2 호환 (macOS 기본 bash).
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RATES="${RATES:-10000 100000 1000000}"
MSG_SIZE="${MSG_SIZE:-64}"
DURATION="${DURATION:-10}"
RECEIVERS="${RECEIVERS:-node c}"
PORT_BASE="${PORT_BASE:-47100}"
OUT_DIR="${OUT_DIR:-${SCRIPT_DIR}/results}"
NODE_BIN="${NODE_BIN:-node}"
COOLDOWN_SEC=1

SENDER_BIN="${SCRIPT_DIR}/build/poc_sender"
C_RECEIVER_BIN="${SCRIPT_DIR}/build/poc_receiver"
NODE_RECEIVER="${SCRIPT_DIR}/receiver-node/receiver.mjs"
REPORT_SCRIPT="${SCRIPT_DIR}/report.mjs"

#===============================================================================
# FUNCTION    : Die
# DESCRIPTION : 오류 메시지를 stderr 로 내고 종료한다
# PARAMETERS  : string message - 메시지
#===============================================================================
Die() {
    echo "[run-poc] ERROR: ${1}" >&2
    exit 1
}

#===============================================================================
# FUNCTION    : CheckPrereq
# DESCRIPTION : 빌드와 node 존재를 확인한다 (빌드가 없으면 make 실행)
#===============================================================================
CheckPrereq() {
    if [ ! -x "${SENDER_BIN}" ] || [ ! -x "${C_RECEIVER_BIN}" ]; then
        make -C "${SCRIPT_DIR}" all >/dev/null || Die "build failed"
    fi
    command -v "${NODE_BIN}" >/dev/null 2>&1 || Die "node not found (NODE_BIN=${NODE_BIN})"
}

#===============================================================================
# FUNCTION    : RunOne
# DESCRIPTION : 송신기 1개와 수신기 1개를 같은 포트로 묶어 한 번 측정한다
# PARAMETERS  : string receiver - node 또는 c
#               int rate - 목표 메시지/초
#               int port - TCP 포트
#===============================================================================
RunOne() {
    local receiver="${1}"
    local rate="${2}"
    local port="${3}"
    local tag="${receiver}-${rate}"
    local sender_pid

    echo "[run-poc] ${tag}: ${rate} msg/s x ${DURATION}s, ${MSG_SIZE}B" >&2
    "${SENDER_BIN}" -p "${port}" -r "${rate}" -s "${MSG_SIZE}" -d "${DURATION}" \
        -o "${OUT_DIR}/${tag}.send.json" 2>"${OUT_DIR}/${tag}.send.log" &
    sender_pid=$!

    if [ "${receiver}" = "node" ]; then
        "${NODE_BIN}" "${NODE_RECEIVER}" --port "${port}" \
            --out "${OUT_DIR}/${tag}.recv.json" 2>"${OUT_DIR}/${tag}.recv.log" \
            || echo "[run-poc] ${tag}: receiver failed" >&2
    else
        "${C_RECEIVER_BIN}" -p "${port}" \
            -o "${OUT_DIR}/${tag}.recv.json" 2>"${OUT_DIR}/${tag}.recv.log" \
            || echo "[run-poc] ${tag}: receiver failed" >&2
    fi
    wait "${sender_pid}" || echo "[run-poc] ${tag}: sender failed" >&2
    sleep "${COOLDOWN_SEC}"
}

Main() {
    local port="${PORT_BASE}"
    local rate
    local receiver

    CheckPrereq
    mkdir -p "${OUT_DIR}"
    rm -f "${OUT_DIR}"/*.json "${OUT_DIR}"/*.log

    for rate in ${RATES}; do
        for receiver in ${RECEIVERS}; do
            RunOne "${receiver}" "${rate}" "${port}"
            port=$((port + 1))
        done
    done

    "${NODE_BIN}" "${REPORT_SCRIPT}" "${OUT_DIR}" | tee "${OUT_DIR}/result.md"
}

Main "$@"
