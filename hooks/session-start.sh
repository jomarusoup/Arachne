#!/bin/bash
################################################################################
# FILE NAME   : session-start.sh
# DESCRIPTION : SessionStart Hook — 세션 시작 시 최근 세션 파일 경로 안내
# DATA        : 2026-05-05
# Modification: 2026-06-04
################################################################################

SESSION_DIR="$HOME/.claude/sessions"

if [ ! -d "$SESSION_DIR" ]; then
    exit 0
fi

# auto- 제외하고 수동 저장 세션만 (없으면 auto 포함)
LATEST=$(ls -t "$SESSION_DIR"/[0-9]*.md 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
    LATEST=$(ls -t "$SESSION_DIR"/*.md 2>/dev/null | head -1)
fi

if [ -n "$LATEST" ]; then
    echo "┌───────────────────────────────────────────────────────────────────────────────"
    echo "│  [세션 이어받기] "
    echo "│  최근 세션: $(basename "$LATEST")"
    echo "│  → cat $LATEST"
    echo "└───────────────────────────────────────────────────────────────────────────────"
fi
