#!/bin/bash
################################################################################
# FILE NAME   : validate_settings.sh
# DESCRIPTION : settings.template.json 유효성 검사
# DATA        : 2026-06-01
################################################################################

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="${REPO_DIR}/settings.template.json"
PASS=0
FAIL=0

#===============================================================================
# FUNCTION    : CheckPass
# DESCRIPTION : 검사 통과 출력
# PARAMETERS  : string msg - 검사 항목명
#===============================================================================
CheckPass() {
    echo "  [PASS] $1"
    PASS=$((PASS + 1))
}

#===============================================================================
# FUNCTION    : CheckFail
# DESCRIPTION : 검사 실패 출력 후 종료 코드 기록
# PARAMETERS  : string msg - 검사 항목명
#===============================================================================
CheckFail() {
    echo "  [FAIL] $1"
    FAIL=$((FAIL + 1))
}

echo "[validate_settings] settings.template.json 검사 시작"
echo ""

#-------------------------------------------------------------------------------
# 파일 존재
#-------------------------------------------------------------------------------
if [ ! -f "${TEMPLATE}" ]; then
    echo "[ERROR] ${TEMPLATE} 파일이 없습니다."
    exit 1
fi
CheckPass "파일 존재"

#-------------------------------------------------------------------------------
# JSON 유효성 (jq 필요)
#-------------------------------------------------------------------------------
if command -v jq &>/dev/null; then
    if jq empty "${TEMPLATE}" 2>/dev/null; then
        CheckPass "JSON 파싱 성공"
    else
        CheckFail "JSON 파싱 실패 — 문법 오류"
    fi
else
    echo "  [SKIP] jq 미설치 — JSON 파싱 검사 생략"
fi

#-------------------------------------------------------------------------------
# 필수 키 존재
#-------------------------------------------------------------------------------
REQUIRED_KEYS=(
    ".statusLine"
    ".hooks"
    ".hooks.SessionStart"
    ".hooks.Stop"
    ".hooks.PreCompact"
    ".enabledPlugins"
)

for key in "${REQUIRED_KEYS[@]}"; do
    if command -v jq &>/dev/null; then
        if jq -e "${key}" "${TEMPLATE}" >/dev/null 2>&1; then
            CheckPass "필수 키: ${key}"
        else
            CheckFail "필수 키 없음: ${key}"
        fi
    fi
done

#-------------------------------------------------------------------------------
# __HOME__ 플레이스홀더 확인
#-------------------------------------------------------------------------------
if grep -q "__HOME__" "${TEMPLATE}"; then
    CheckPass "__HOME__ 플레이스홀더 존재"
else
    CheckFail "__HOME__ 플레이스홀더 없음 — install.sh 치환 대상 누락"
fi

#-------------------------------------------------------------------------------
# 실제 홈 경로 하드코딩 여부
#-------------------------------------------------------------------------------
if grep -q "${HOME}" "${TEMPLATE}"; then
    CheckFail "실제 HOME 경로 하드코딩 발견: ${HOME}"
else
    CheckPass "실제 HOME 경로 하드코딩 없음"
fi

#-------------------------------------------------------------------------------
# 결과 요약
#-------------------------------------------------------------------------------
echo ""
echo "결과: ${PASS}개 통과 / $((PASS + FAIL))개 검사"

if [ "${FAIL}" -gt 0 ]; then
    echo "[FAIL] ${FAIL}개 항목 실패"
    exit 1
fi

echo "[PASS] 모든 검사 통과"
exit 0
