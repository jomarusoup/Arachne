#!/bin/bash
# PreCompact Hook — 컨텍스트 압축 전 자동 실행
# 현재 파일 상태를 임시 저장 (auto-* 파일은 .gitignore 제외됨)

SESSION_DIR="$(pwd)/.claude/sessions"
mkdir -p "$SESSION_DIR"

DATE=$(date +%Y-%m-%d-%H%M)
FILE="$SESSION_DIR/auto-${DATE}.md"

LINES=$(wc -l < taskflow.html 2>/dev/null || echo "?")

cat > "$FILE" << TEMPLATE
# 자동 저장 — ${DATE} (PreCompact)
> 컨텍스트 압축 전 자동 생성. /save-session 으로 정리 필요.

## 파일 상태
- taskflow.html: ${LINES}줄
- 저장 시각: ${DATE}

## 작업 중이던 내용
(이 세션의 대화에서 직접 확인)

## 다음 세션 시작 시
1. 이 파일 또는 최근 수동 세션 파일 읽기
2. CLAUDE.md 확인
3. /status 실행
TEMPLATE

echo "[PreCompact] 임시 세션 저장 완료: auto-${DATE}.md"
