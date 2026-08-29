#!/bin/bash
################################################################################
# FILE NAME   : smoke_hooks.sh
# DESCRIPTION : 훅 런타임 스모크 (#40) — Git Bash(Windows)·Linux 양쪽에서
#               실제 외부 CLI 없이 실행되는지 검증한다. CI 의 Windows job 이
#               'shell: bash'(Git Bash)로 이 스크립트를 돌려 런타임 호환성을 확인한다.
#               GNU 전용 의존(date -d 등) 없이 동작해야 한다.
# DATA        : 2026-06-08
################################################################################

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)"
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

#===============================================================================
# FUNCTION    : Expect
# DESCRIPTION : 실제 종료코드가 기대값과 같은지 검사
# PARAMETERS  : string desc - 항목 설명
#               int expected - 기대 종료코드
#               int actual   - 실제 종료코드
#===============================================================================
Expect() {
    if [ "$2" -eq "$3" ]; then
        echo "  [ok]   $1"
    else
        echo "  [FAIL] $1 (exit $3, 기대 $2)"
        FAIL=1
    fi
}

echo "[smoke] 훅 Git Bash/Linux 런타임 스모크"

#-------------------------------------------------------------------------------
# 1. doc-drift-check — stdin JSON 처리
#-------------------------------------------------------------------------------
rc=0
echo '{"session_id":"smoke","tool_input":{"file_path":"/x/install.sh"}}' \
    | ARACHNE_STATE_DIR="$TMP/s3" bash "$REPO_DIR/hooks/doc-drift-check.sh" >/dev/null || rc=$?
Expect "doc-drift-check (stdin JSON)" 0 "$rc"

#-------------------------------------------------------------------------------
# 2. git-bus-check — git 레포 외부에서 조용히 종료
#-------------------------------------------------------------------------------
rc=0
( cd "$TMP" && bash "$REPO_DIR/hooks/git-bus-check.sh" ) >/dev/null || rc=$?
Expect "git-bus-check (non-repo)" 0 "$rc"

#-------------------------------------------------------------------------------
# 3. ua-stale-check — meta.json 없는 프로젝트에서 조용히 종료
#-------------------------------------------------------------------------------
rc=0
mkdir -p "$TMP/s5"
out=$(UA_STALE_REPO="$TMP/s5" bash "$REPO_DIR/hooks/ua-stale-check.sh") || rc=$?
Expect "ua-stale-check (no meta)" 0 "$rc"
[ -z "$out" ] || { echo "  [FAIL] ua-stale-check 가 meta 없는데 출력함"; FAIL=1; }

if [ "$FAIL" -eq 0 ]; then
    echo "[PASS] 훅 런타임 스모크 통과"
else
    echo "[FAIL] 스모크 실패 — 위 항목 확인"
fi
exit "$FAIL"
