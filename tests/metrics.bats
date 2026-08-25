#!/usr/bin/env bats
################################################################################
# FILE NAME   : metrics.bats
# DESCRIPTION : 계측(MetricAppend, ADR-0003 기준선 수집) 검증 — 동시 쓰기 무결성·
#               실패 3경로 불가침·복제 블록 동기화·보존 prune·종료코드 보존.
#               쿼터 감지 로직(IsQuotaError/SetCooldown)은 검증 대상이 아니다.
# DATA        : 2026-08-25
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

    TMP_DIR="$(mktemp -d)"
    MOCK_BIN="${TMP_DIR}/bin"
    STATE_DIR="${TMP_DIR}/state"
    mkdir -p "${MOCK_BIN}" "${STATE_DIR}"

    # 상태·계측 디렉터리를 격리 (래퍼의 METRICS_DIR 유도식과 동일 변수)
    export ARACHNE_STATE_DIR="${STATE_DIR}"
    export PATH="${MOCK_BIN}:${PATH}"

    MONTH="$(date -u +%Y-%m)"
    CALL_LOG="${STATE_DIR}/metrics/wrapper-calls-${MONTH}.log"
    COOLDOWN_LOG="${STATE_DIR}/metrics/cooldown-entries-${MONTH}.log"
}

teardown() {
    chmod -R u+w "${TMP_DIR}" 2>/dev/null || true
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# 모킹 헬퍼 — 지정 종료코드로 끝나는 가짜 gemini CLI 생성
#-------------------------------------------------------------------------------
make_gemini_stub() {
    local exit_code="$1"
    cat > "${MOCK_BIN}/gemini" << STUB
#!/bin/bash
echo "stub-output"
exit ${exit_code}
STUB
    chmod +x "${MOCK_BIN}/gemini"
}

#-------------------------------------------------------------------------------
# 밀폐 PATH — 호스트에 실제 CLI(gemini 등)가 있어도 감지되지 않도록 필요한
# 도구만 심볼릭한다 (atask.bats A-11 패턴 재사용)
#-------------------------------------------------------------------------------
make_safe_bin() {
    local safe_bin="${TMP_DIR}/safebin"
    mkdir -p "${safe_bin}"
    local tool
    for tool in bash sh cat date grep head cut mkdir mktemp mv rm basename tr sed wc find; do
        ln -s "$(command -v "${tool}")" "${safe_bin}/${tool}" 2>/dev/null || true
    done
    echo "${safe_bin}"
}

#===============================================================================
# T1 — 동시 쓰기 무결성 (flock 없는 O_APPEND 단일 write 방식 검증)
#===============================================================================

@test "T1: 동시 30회 호출 — 라인 30개, 섞이거나 찢긴 라인 0" {
    make_gemini_stub 0
    local ii
    for ii in $(seq 1 30); do
        bash "${REPO_DIR}/gemini-task.sh" "t${ii}" >/dev/null 2>&1 &
    done
    wait

    [ -f "${CALL_LOG}" ]
    local line_count
    line_count=$(wc -l < "${CALL_LOG}")
    [ "${line_count}" -eq 30 ]
    # 전 라인이 스키마에 완전 매칭해야 함 — 부분 라인·병합 라인은 매칭 실패로 드러남
    local valid_count
    valid_count=$(grep -cE $'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\tgemini-task\tread\tsuggest\t0\t[0-9]+$' "${CALL_LOG}")
    [ "${valid_count}" -eq 30 ]
}

#===============================================================================
# T2 — 로그 실패 3경로가 래퍼 본연 종료코드를 바꾸지 않음
#===============================================================================

@test "T2a: STATE_DIR 부모가 파일(mkdir 실패) — 본연 rc=0 불변" {
    make_gemini_stub 0
    touch "${TMP_DIR}/blocker"
    export ARACHNE_STATE_DIR="${TMP_DIR}/blocker/sub"
    run bash "${REPO_DIR}/gemini-task.sh" "x"
    [ "$status" -eq 0 ]
    [[ "$output" == *"stub-output"* ]]
}

@test "T2b: metrics 디렉터리 쓰기 권한 없음(리다이렉션 실패) — 본연 rc=0 불변" {
    make_gemini_stub 0
    mkdir -p "${STATE_DIR}/metrics"
    chmod 500 "${STATE_DIR}/metrics"
    run bash "${REPO_DIR}/gemini-task.sh" "x"
    [ "$status" -eq 0 ]
    [ ! -f "${CALL_LOG}" ]
}

@test "T2c: 로그 파일이 읽기 전용 — 본연 rc=0 불변, 파일 불변" {
    make_gemini_stub 0
    mkdir -p "${STATE_DIR}/metrics"
    touch "${CALL_LOG}"
    chmod 400 "${CALL_LOG}"
    run bash "${REPO_DIR}/gemini-task.sh" "x"
    [ "$status" -eq 0 ]
    [ ! -s "${CALL_LOG}" ]
}

#===============================================================================
# T3 — 복제 블록 동기화 (B-07 식 드리프트 가드)
#===============================================================================

@test "T3: METRICS 블록이 3개 래퍼에서 byte-identical" {
    local wrapper
    for wrapper in codex-task.sh gemini-task.sh arachne-task.sh; do
        sed -n '/METRICS-BLOCK-BEGIN/,/METRICS-BLOCK-END/p' \
            "${REPO_DIR}/${wrapper}" > "${TMP_DIR}/blk-${wrapper}"
        [ -s "${TMP_DIR}/blk-${wrapper}" ]
    done
    diff "${TMP_DIR}/blk-codex-task.sh" "${TMP_DIR}/blk-gemini-task.sh"
    diff "${TMP_DIR}/blk-codex-task.sh" "${TMP_DIR}/blk-arachne-task.sh"
}

#===============================================================================
# T4 — 보존 prune (90일 초과 월 파일 삭제, 현재 파일은 유지)
#===============================================================================

@test "T4: 90일 초과 로그 파일은 prune, 현재 월 파일은 생성" {
    make_gemini_stub 0
    mkdir -p "${STATE_DIR}/metrics"
    local old_log="${STATE_DIR}/metrics/wrapper-calls-2026-01.log"
    touch "${old_log}"
    touch -t 202601010000 "${old_log}"
    run bash "${REPO_DIR}/gemini-task.sh" "x"
    [ "$status" -eq 0 ]
    [ ! -f "${old_log}" ]
    [ -f "${CALL_LOG}" ]
}

#===============================================================================
# T5 — trap 확장이 종료코드를 오염시키지 않음 (0 / 127 / 하위 CLI 비영)
#      atask 가 이 값으로 폴백을 판정하므로 오염되면 폴백 사슬이 어긋난다.
#===============================================================================

@test "T5: rc=0 (하위 CLI 정상) 보존 + 로그에 rc=0 기록" {
    make_gemini_stub 0
    run bash "${REPO_DIR}/gemini-task.sh" "x"
    [ "$status" -eq 0 ]
    grep -qE $'\t0\t[0-9]+$' "${CALL_LOG}"
}

@test "T5: rc=127 (미설치 가드) 보존 + 로그에 rc=127 기록" {
    local safe_bin
    safe_bin="$(make_safe_bin)"
    PATH="${safe_bin}" run bash "${REPO_DIR}/gemini-task.sh" "x"
    [ "$status" -eq 127 ]
    grep -qE $'\t127\t[0-9]+$' "${CALL_LOG}"
}

@test "T5: rc=3 (하위 CLI 비영 종료) 보존 + 로그에 rc=3 기록" {
    make_gemini_stub 3
    run bash "${REPO_DIR}/gemini-task.sh" "x"
    [ "$status" -eq 3 ]
    grep -qE $'\t3\t[0-9]+$' "${CALL_LOG}"
}

#===============================================================================
# T6 — 쿨다운 진입 이력 (atask 쿼터 폴백 경로의 관찰 전용 기록)
#===============================================================================

@test "T6: atask 쿼터 폴백 시 cooldown-entries 에 진입 이력 1줄" {
    # claude 는 쿼터 오류, codex-task 는 미설치(127), gemini-task 는 스텁 성공
    cat > "${MOCK_BIN}/claude" << 'STUB'
#!/bin/bash
echo "Error: 429 rate limit exceeded" >&2
exit 1
STUB
    cat > "${MOCK_BIN}/codex-task" << 'STUB'
#!/bin/bash
exit 127
STUB
    cat > "${MOCK_BIN}/gemini-task" << 'STUB'
#!/bin/bash
echo "OUTPUT_FROM_gemini-task"
exit 0
STUB
    chmod +x "${MOCK_BIN}/claude" "${MOCK_BIN}/codex-task" "${MOCK_BIN}/gemini-task"

    run bash "${REPO_DIR}/arachne-task.sh" -R impl "작업"
    [ "$status" -eq 0 ]
    [ -f "${COOLDOWN_LOG}" ]
    local entry_count
    entry_count=$(grep -cE $'^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\tclaude\timpl\t[0-9]+$' "${COOLDOWN_LOG}")
    [ "${entry_count}" -eq 1 ]
    # atask 자신의 호출 기록도 남는다 (rc=0)
    grep -qE $'\tarachne-task\timpl\tsuggest\t0\t[0-9]+$' "${CALL_LOG}"
}
