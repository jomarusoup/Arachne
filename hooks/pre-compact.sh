#!/bin/bash
################################################################################
# FILE NAME   : pre-compact.sh
# DESCRIPTION : PreCompact Hook — 컨텍스트 압축 전 git 기반 프로젝트 상태 저장
# DATA        : 2026-05-05
# Modification: 2026-05-31
################################################################################

# 훅은 자동 실행·의도적 continue 경로라 -e 제외 (실패해도 세션을 막지 않음)
set -uo pipefail

# 세션 저장·복원 경로는 홈 절대경로로 통일 — session-start.sh 가 읽는 위치와
# 일치해야 압축 전 스냅샷이 다음 세션에서 발견된다 (workflow-04 잔존 수정)
SESSION_DIR="$HOME/.claude/sessions"
mkdir -p "$SESSION_DIR"

DATE=$(date +%Y-%m-%d-%H%M)
FILE="$SESSION_DIR/auto-${DATE}.md"

#---------------------------------------------------------------------------
# 상태 수집 및 파일 작성
#---------------------------------------------------------------------------
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")
LAST_COMMITS=$(git log --oneline -5 2>/dev/null || echo "(git 없음)")
CHANGED_FILES=$(git status --short 2>/dev/null || echo "")
CHANGED_COUNT=0
[ -n "$CHANGED_FILES" ] && CHANGED_COUNT=$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')

BUILD_INFO=""
if [ -f "Makefile" ] || [ -f "CMakeLists.txt" ]; then
    BIN_COUNT=$(find . -maxdepth 3 -type f -perm /111 ! -path './.git/*' ! -name '*.sh' 2>/dev/null | wc -l | tr -d ' ')
    BUILD_INFO="- 실행 파일: ${BIN_COUNT}개 감지"
elif [ -f "package.json" ]; then
    PKG=$(node -e "const p=require('./package.json');console.log(p.name+'@'+p.version)" 2>/dev/null || echo "N/A")
    BUILD_INFO="- 패키지: ${PKG}"
elif [ -f "go.mod" ]; then
    MOD=$(head -1 go.mod 2>/dev/null | awk '{print $2}')
    BUILD_INFO="- Go 모듈: ${MOD}"
fi

cat > "$FILE" << TEMPLATE
# 자동 저장 — ${DATE} (PreCompact)
> 컨텍스트 압축 전 자동 생성. /save-session 으로 정리 필요.

## 프로젝트 상태
- 브랜치: ${BRANCH}
- 미커밋 변경: ${CHANGED_COUNT}건
${BUILD_INFO}
- 저장 시각: ${DATE}

## 최근 커밋 (최대 5건)
${LAST_COMMITS}

## 미커밋 파일
${CHANGED_FILES:-"(없음)"}

## 작업 중이던 내용
(이 세션의 대화에서 직접 확인)

## 다음 세션 시작 시
1. 이 파일 또는 최근 수동 세션 파일 읽기
2. CLAUDE.md 확인
3. git status 확인
TEMPLATE

echo "[PreCompact] 임시 세션 저장 완료: auto-${DATE}.md"
