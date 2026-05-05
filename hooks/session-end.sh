#!/bin/bash
################################################################################
# FILE NAME   : session-end.sh
# DESCRIPTION : Stop Hook — 세션 종료 시 수동 저장 없으면 자동 스냅샷 생성
# DATA        : 2026-05-05
# Modification: 2026-05-05
################################################################################

SESSION_DIR="$(pwd)/.claude/sessions"
TODAY=$(date +%Y-%m-%d)
DATE=$(date +%Y-%m-%d-%H%M)

mkdir -p "$SESSION_DIR"

SAVED=$(ls "$SESSION_DIR"/${TODAY}[^a]*.md 2>/dev/null | head -1)

if [ -n "$SAVED" ]; then
    echo "[세션 종료] 세션 파일 저장됨: $(basename $SAVED)"
else
    FILE="$SESSION_DIR/auto-${DATE}.md"
    LINES=$(wc -l < "$(pwd)/src/index.html" 2>/dev/null || echo "?")
    cat > "$FILE" << TEMPLATE
# 자동 저장 — ${DATE}
> /save-session 없이 종료됨. 다음 세션에서 대화 내용 직접 확인 필요.

## 파일 상태
- src/index.html: ${LINES}줄
- 저장 시각: ${DATE}
TEMPLATE
    echo "[세션 종료] ⚠️  /save-session 미실행 → auto-${DATE}.md 자동 생성"
fi
