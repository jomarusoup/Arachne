#!/bin/bash
################################################################################
# FILE NAME   : gemini-check.sh
# DESCRIPTION : Gemini 작업 완료 감지 — 마지막 Claude 세션 이후 새 커밋 확인
# DATA        : 2026-05-31
# Modification: 2026-05-31
################################################################################

REPO_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$REPO_DIR" ]; then
    exit 0
fi

STATE_FILE="$REPO_DIR/.claude/last-seen-commit"
CURRENT_HEAD=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null)

if [ -z "$CURRENT_HEAD" ]; then
    exit 0
fi

#-------------------------------------------------------------------------------
# 최초 실행 — 현재 HEAD 저장 후 종료
#-------------------------------------------------------------------------------
if [ ! -f "$STATE_FILE" ]; then
    mkdir -p "$(dirname "$STATE_FILE")"
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
NEW_COMMITS=$(git -C "$REPO_DIR" log --oneline "$LAST_SEEN..HEAD" 2>/dev/null)
if [ -z "$NEW_COMMITS" ]; then
    echo "$CURRENT_HEAD" > "$STATE_FILE"
    exit 0
fi

COMMIT_COUNT=$(echo "$NEW_COMMITS" | wc -l | tr -d ' ')

echo "┌───────────────────────────────────────────────────────────────────────────────"
echo "│  [Gemini 작업 감지] 마지막 세션 이후 커밋 ${COMMIT_COUNT}건"
echo "└───────────────────────────────────────────────────────────────────────────────"
echo ""

#-----------------------------------------------------------------------
# 커밋 목록
#-----------------------------------------------------------------------
echo "  커밋 목록:"
git -C "$REPO_DIR" log --pretty=format:"  %C(yellow)%h%Creset  %s  %C(dim)(%cr)%Creset" "$LAST_SEEN..HEAD"
echo ""
echo ""

#-----------------------------------------------------------------------
# 변경 파일 목록
#-----------------------------------------------------------------------
echo "  변경 파일:"
git -C "$REPO_DIR" diff --name-status "$LAST_SEEN..HEAD" 2>/dev/null | \
    sed 's/^A/  [추가]/' | \
    sed 's/^M/  [수정]/' | \
    sed 's/^D/  [삭제]/'
echo ""

#-----------------------------------------------------------------------
# 상태 갱신 — 이후 중복 알림 방지
#-----------------------------------------------------------------------
echo "$CURRENT_HEAD" > "$STATE_FILE"
