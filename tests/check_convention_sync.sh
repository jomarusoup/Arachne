#!/bin/bash
################################################################################
# FILE NAME   : check_convention_sync.sh
# DESCRIPTION : AGENTS.md(다이제스트) ↔ rules/(풀버전) 내용 동기화 검사 (#39) —
#               핵심 규약 토큰(네이밍·TDD 단계·git type)이 양쪽에 모두 존재하는지
#               확인해, 한쪽만 고쳐 두 정본이 어긋나는 드리프트를 CI 에서 차단한다.
#               파일명 인덱스 검사(check_index.sh)와 달리 '내용 단위' 동기화를 본다.
# DATA        : 2026-06-08
################################################################################

set -uo pipefail

# 테스트는 CONV_SYNC_REPO 로 픽스처 디렉터리를 주입한다. 미지정 시 실제 레포.
REPO_DIR="${CONV_SYNC_REPO:-$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)}"
FAIL=0

#-------------------------------------------------------------------------------
# 동기화 대상 — "rules_file::token1 token2 ..." 형식.
# 각 토큰은 AGENTS.md 와 해당 rules 파일에 단어 경계(-w)로 모두 존재해야 한다.
#-------------------------------------------------------------------------------
SYNC_GROUPS=(
    "rules/common/coding-style.md::snake_case g_SnakeCase PascalCase SCREAMING_SNAKE_CASE camelCase"
    "rules/common/testing.md::RED GREEN REFACTOR AAA"
    "rules/common/git-workflow.md::feat fix refactor docs test chore perf style"
    "rules/common/workflow.md::sgrep codegraph [PLAN]"
)

#===============================================================================
# FUNCTION    : Present
# DESCRIPTION : 토큰이 파일에 단어 경계로 존재하는지 검사
# PARAMETERS  : string token - 검사 토큰
#               string file  - 대상 파일(REPO_DIR 상대)
# RETURNED    : 0(존재) / 1(없음)
#===============================================================================
Present() {
    grep -qwF "$1" "$REPO_DIR/$2" 2>/dev/null
}

agents="AGENTS.md"
if [ ! -f "$REPO_DIR/$agents" ]; then
    echo "[FAIL] AGENTS.md 없음: $REPO_DIR/$agents"
    exit 1
fi

for group in "${SYNC_GROUPS[@]}"; do
    rules_file="${group%%::*}"
    tokens="${group#*::}"
    echo "[sync] AGENTS.md ↔ $rules_file"
    for tok in $tokens; do
        if ! Present "$tok" "$agents"; then
            echo "  [DRIFT] '$tok' 가 AGENTS.md 에 없음 (정본: $rules_file)"
            FAIL=1
        fi
        if ! Present "$tok" "$rules_file"; then
            echo "  [DRIFT] '$tok' 가 $rules_file 에 없음 (AGENTS.md 와 불일치)"
            FAIL=1
        fi
    done
done

if [ "$FAIL" -eq 0 ]; then
    echo "[PASS] 규약 동기화 — AGENTS.md ↔ rules 핵심 토큰 일치"
else
    echo "[FAIL] 규약 드리프트 — 위 토큰을 양쪽 정본에 일치시키세요"
fi
exit "$FAIL"
