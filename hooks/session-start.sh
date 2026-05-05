#!/bin/bash
# SessionStart Hook — 세션 시작 시 자동 실행
# 최근 세션 파일을 찾아 경로를 안내

SESSION_DIR="$(pwd)/.claude/sessions"

if [ ! -d "$SESSION_DIR" ]; then
  exit 0
fi

# auto- 제외하고 수동 저장 세션만 (없으면 auto 포함)
LATEST=$(ls -t "$SESSION_DIR"/[0-9]*.md 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
  LATEST=$(ls -t "$SESSION_DIR"/*.md 2>/dev/null | head -1)
fi

if [ -n "$LATEST" ]; then
  echo "┌─────────────────────────────────────────┐"
  echo "│  [세션 이어받기]                         │"
  echo "│  최근 세션: $(basename $LATEST)"
  echo "│  → cat $LATEST"
  echo "└─────────────────────────────────────────┘"
fi
