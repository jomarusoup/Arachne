#!/bin/bash
################################################################################
# FILE NAME   : git-bus-check.sh
# DESCRIPTION : git-bus — 업스트림 브랜치의 새 커밋 감지(작성 CLI 판별 없음).
#               마지막 기준점(.claude/last-seen-commit) 이후 새 커밋을 다음 프롬프트에 알린다.
# DATA        : 2026-05-31
# Modification: 2026-06-08
################################################################################

# 훅은 자동 실행·의도적 continue 경로라 -e 제외 (실패해도 세션을 막지 않음)
set -uo pipefail

REPO_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_DIR" ]; then
    exit 0
fi

#-------------------------------------------------------------------------------
# 리모트에서 최신 상태 fetch — git pull 없이 업스트림 새 커밋만 감지
#-------------------------------------------------------------------------------
git -C "$REPO_DIR" fetch -q origin 2>/dev/null || true

#-------------------------------------------------------------------------------
# 비교 기준: 리모트 트래킹 브랜치 HEAD (없으면 로컬 HEAD)
#-------------------------------------------------------------------------------
REMOTE_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
if [ -n "$REMOTE_BRANCH" ]; then
    CURRENT_HEAD=$(git -C "$REPO_DIR" rev-parse "$REMOTE_BRANCH" 2>/dev/null)
else
    CURRENT_HEAD=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)
fi

if [ -z "$CURRENT_HEAD" ]; then
    exit 0
fi

STATE_FILE="$REPO_DIR/.claude/last-seen-commit"

# #30: 모든 기준점 write(최초·갱신) 전에 .claude 디렉터리를 보장한다 — 부재 시 저장 실패 방지
mkdir -p "$(dirname "$STATE_FILE")"

#-------------------------------------------------------------------------------
# 최초 실행 — 현재 HEAD 저장 후 종료
#-------------------------------------------------------------------------------
if [ ! -f "$STATE_FILE" ]; then
    echo "$CURRENT_HEAD" > "$STATE_FILE"
    exit 0
fi

LAST_SEEN=$(cat "$STATE_FILE")

if [ "$CURRENT_HEAD" = "$LAST_SEEN" ]; then
    exit 0
fi

#-------------------------------------------------------------------------------
# 새 커밋 존재 — 목록 및 변경 파일 출력
#-------------------------------------------------------------------------------
NEW_COMMITS=$(git -C "$REPO_DIR" log --oneline "$LAST_SEEN..$CURRENT_HEAD" 2>/dev/null)
if [ -z "$NEW_COMMITS" ]; then
    echo "$CURRENT_HEAD" > "$STATE_FILE"
    exit 0
fi

COMMIT_COUNT=$(echo "$NEW_COMMITS" | wc -l | tr -d ' ')

echo "┌───────────────────────────────────────────────────────────────────────────────"
echo "│  [git-bus] 업스트림 새 커밋 ${COMMIT_COUNT}건 (작성 CLI 판별 없음)"
echo "└───────────────────────────────────────────────────────────────────────────────"
echo ""

#-----------------------------------------------------------------------
# 커밋 목록
#-----------------------------------------------------------------------
echo "  커밋 목록:"
git -C "$REPO_DIR" log --pretty=format:"  %C(yellow)%h%Creset  %s  %C(dim)(%cr)%Creset" "$LAST_SEEN..$CURRENT_HEAD"
echo ""
echo ""

#-----------------------------------------------------------------------
# 변경 파일 목록
#-----------------------------------------------------------------------
echo "  변경 파일:"
git -C "$REPO_DIR" diff --name-status "$LAST_SEEN..$CURRENT_HEAD" 2>/dev/null | \
    sed 's/^A/  [추가]/' | \
    sed 's/^M/  [수정]/' | \
    sed 's/^D/  [삭제]/'
echo ""

#-----------------------------------------------------------------------
# 상태 갱신 — 이후 중복 알림 방지
#-----------------------------------------------------------------------
echo "$CURRENT_HEAD" > "$STATE_FILE"
