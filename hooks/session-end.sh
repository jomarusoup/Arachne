#!/bin/bash
################################################################################
# FILE NAME   : session-end.sh
# DESCRIPTION : Stop Hook — 세션 종료 시 git 기반 프로젝트 상태 스냅샷 생성,
#               Gemini 감지 기준점(last-seen-commit) 갱신
# DATA        : 2026-05-05
# Modification: 2026-06-04
################################################################################

SESSION_DIR="$HOME/.claude/sessions"
TODAY=$(date +%Y-%m-%d)
DATE=$(date +%Y-%m-%d-%H%M)

mkdir -p "$SESSION_DIR"

#===============================================================================
# FUNCTION    : SaveSnapshot
# DESCRIPTION : git 기반 프로젝트 상태를 세션 파일에 기록
#===============================================================================
SaveSnapshot() {
    local file="$1"

    #---------------------------------------------------------------------------
    # git 상태 수집
    #---------------------------------------------------------------------------
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "N/A")

    local last_commits
    last_commits=$(git log --oneline -5 2>/dev/null || echo "(git 없음)")

    local changed_files
    changed_files=$(git status --short 2>/dev/null || echo "")

    local changed_count=0
    [ -n "$changed_files" ] && changed_count=$(echo "$changed_files" | wc -l | tr -d ' ')

    cat > "$file" << TEMPLATE
# 자동 저장 — ${DATE}
> /save-session 없이 종료됨. 다음 세션에서 대화 내용 직접 확인 필요.

## 프로젝트 상태
- 브랜치: ${branch}
- 미커밋 변경: ${changed_count}건
- 저장 시각: ${DATE}

## 최근 커밋 (최대 5건)
${last_commits}

## 미커밋 파일
${changed_files:-"(없음)"}

## 다음 세션 시작 시
1. 이 파일 또는 최근 수동 세션 파일 읽기
2. CLAUDE.md 확인
3. git status 확인
TEMPLATE
}

#===============================================================================
# FUNCTION    : UpdateGeminiRef
# DESCRIPTION : Gemini 감지 기준점 — fetch 후 리모트 HEAD를 last-seen-commit 에 저장
#===============================================================================
UpdateGeminiRef() {
    local repo_dir
    repo_dir=$(git rev-parse --show-toplevel 2>/dev/null)
    [ -z "$repo_dir" ] && return

    git -C "$repo_dir" fetch -q origin 2>/dev/null || true

    local remote_branch
    remote_branch=$(git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)

    local current_head
    if [ -n "$remote_branch" ]; then
        current_head=$(git -C "$repo_dir" rev-parse "$remote_branch" 2>/dev/null)
    else
        current_head=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)
    fi
    [ -z "$current_head" ] && return

    echo "$current_head" > "$repo_dir/.claude/last-seen-commit"
}

#-------------------------------------------------------------------------------
# 오늘 수동 저장 세션이 있으면 스냅샷 생략
#-------------------------------------------------------------------------------
SAVED=$(ls "$SESSION_DIR"/${TODAY}[^a]*.md 2>/dev/null | head -1)

if [ -n "$SAVED" ]; then
    echo "[세션 종료] 세션 파일 저장됨: $(basename "$SAVED")"
else
    FILE="$SESSION_DIR/auto-${DATE}.md"
    SaveSnapshot "$FILE"
    echo "[세션 종료] ⚠️  /save-session 미실행 → auto-${DATE}.md 자동 생성"
fi

UpdateGeminiRef
