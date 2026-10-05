#!/usr/bin/env bash
################################################################################
# FILE NAME   : check-layout.sh
# DESCRIPTION : 레이아웃 드리프트 검출. C 헤더 정본에서 매니페스트(layout.json)와 테스트
#               벡터를 임시 디렉터리에 다시 생성하고, 커밋된 vectors/ 와 한 바이트라도
#               다르면 실패한다. 구조체·상수·인코더를 바꾸고 벡터를 갱신하지 않은
#               변경을 CI 에서 잡는다. 의도한 변경이면 make vectors 로 갱신해 같은 PR 에
#               커밋하고, 계약 변경 절차(api-contracts)를 밟는다.
################################################################################
# 사용법: check-layout.sh
# 종료 코드: 0 일치 · 1 드리프트 · 2 빌드·생성 실패
################################################################################
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly COMMITTED_DIR="${SCRIPT_DIR}/vectors"

#-------------------------------------------------------------------------------
# 생성기 빌드 — 출력은 실패할 때만 보여 준다
#-------------------------------------------------------------------------------
build_log="$(make -C "${SCRIPT_DIR}" --no-print-directory build/gen_vectors 2>&1)" || {
    printf '%s\n' "${build_log}" >&2
    echo "[LAYOUT] 생성기 빌드 실패" >&2
    exit 2
}

if [ ! -d "${COMMITTED_DIR}" ]; then
    echo "[LAYOUT] 커밋된 벡터 디렉터리가 없다: ${COMMITTED_DIR} (make vectors 로 만든다)" >&2
    exit 2
fi

tmp_root="${TMPDIR:-/tmp}"
work_dir="$(mktemp -d "${tmp_root%/}/check-layout.XXXXXX")"
trap 'rm -rf "${work_dir}"' EXIT

if ! "${SCRIPT_DIR}/build/gen_vectors" "${work_dir}"; then
    echo "[LAYOUT] 벡터 생성 실패" >&2
    exit 2
fi

#-------------------------------------------------------------------------------
# 비교 — 매니페스트는 텍스트 diff 로, 벡터는 파일 목록과 바이트를 함께 본다
#-------------------------------------------------------------------------------
if ! diff -r "${COMMITTED_DIR}" "${work_dir}"; then
    echo "[LAYOUT] 드리프트: 헤더 정본에서 다시 만든 결과가 커밋된 vectors/ 와 다르다" >&2
    echo "[LAYOUT] 의도한 변경이면 make vectors 후 같은 PR 에 커밋하고 호환성을 판정한다" >&2
    exit 1
fi

echo "[LAYOUT] 일치: vectors/ 가 stream_msg.h 정본과 같다"
