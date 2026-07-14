#!/bin/bash
################################################################################
# FILE NAME   : session-end.sh
# DESCRIPTION : Stop Hook — 세션 종료 시 git 기반 프로젝트 상태 스냅샷 생성,
#               git-bus 기준점(last-seen-commit) 갱신
# DATA        : 2026-05-05
# Modification: 2026-06-12
################################################################################

# 훅은 자동 실행·의도적 continue 경로라 -e 제외 (실패해도 세션을 막지 않음)
set -uo pipefail

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

    #---------------------------------------------------------------------------
    # 지침 스텁 넛지 — 프로젝트 AGENTS.md 에 미기재 섹션이 남아 있으면 제안만 기록
    # (자동 작성 금지 — doc-drift-check.sh 와 같은 원칙. 반영은 diff 승인 후)
    #---------------------------------------------------------------------------
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

    local unfilled
    if [ -f "$repo_root/AGENTS.md" ]; then
        unfilled=$(grep -c '<!-- 미기재:' "$repo_root/AGENTS.md" 2>/dev/null || true)
        if [ "${unfilled:-0}" -gt 0 ]; then
            echo "4. AGENTS.md 미기재 섹션 ${unfilled}개 — 이번 세션에서 파악된" >> "$file"
            echo "   구조·빌드·grep 키워드가 있으면 채우기 제안 (diff 승인 후 반영)" >> "$file"
        fi
    fi
}

#===============================================================================
# FUNCTION    : UpdateUpstreamRef
# DESCRIPTION : git-bus 기준점 — fetch 후 리모트 HEAD를 last-seen-commit 에 저장.
#               Stop 훅은 매 턴 실행되므로 fetch 는 git-bus-check.sh 와 같은
#               스탬프(last-fetch-epoch)로 스로틀한다 (F-04 우회 방지).
#===============================================================================
UpdateUpstreamRef() {
    local repo_dir
    repo_dir=$(git rev-parse --show-toplevel 2>/dev/null)
    [ -z "$repo_dir" ] && return

    #---------------------------------------------------------------------------
    # fetch 스로틀 — 기본 300초 간격 (GIT_BUS_FETCH_INTERVAL 초로 조정, 0이면 매번)
    #---------------------------------------------------------------------------
    local fetch_interval="${GIT_BUS_FETCH_INTERVAL:-300}"
    local fetch_stamp="$repo_dir/.claude/last-fetch-epoch"
    local now last_fetch
    now=$(date +%s)
    last_fetch=0
    [ -f "$fetch_stamp" ] && last_fetch=$(cat "$fetch_stamp" 2>/dev/null)
    case "$last_fetch" in
        ''|*[!0-9]*) last_fetch=0 ;;
    esac

    if [ $(( now - last_fetch )) -ge "$fetch_interval" ]; then
        git -C "$repo_dir" fetch -q origin 2>/dev/null || true
        mkdir -p "$(dirname "$fetch_stamp")"
        echo "$now" > "$fetch_stamp"
    fi

    local remote_branch
    remote_branch=$(git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)

    local current_head
    if [ -n "$remote_branch" ]; then
        current_head=$(git -C "$repo_dir" rev-parse "$remote_branch" 2>/dev/null)
    else
        current_head=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null)
    fi
    [ -z "$current_head" ] && return

    # #30: .claude 디렉터리가 없으면(갓 clone 등) 생성 후 기록 — 없으면 기준점 저장이 조용히 실패
    mkdir -p "$repo_dir/.claude"
    echo "$current_head" > "$repo_dir/.claude/last-seen-commit"
}

#-------------------------------------------------------------------------------
# 오늘 수동 저장 세션이 있으면 스냅샷 생략
# (수동 세션은 날짜로 시작, 자동 세션은 auto- 접두사 — 글롭이 겹치지 않는다)
#-------------------------------------------------------------------------------
SAVED=$(ls "$SESSION_DIR/${TODAY}"*.md 2>/dev/null | head -1)

if [ -n "$SAVED" ]; then
    echo "[세션 종료] 세션 파일 저장됨: $(basename "$SAVED")"
else
    #---------------------------------------------------------------------------
    # Stop 훅은 매 턴 실행되므로 스냅샷 파일은 하루 1개(auto-YYYY-MM-DD.md)를
    # 덮어쓴다 — 분 단위 파일명은 하루 수십 개씩 무한 누적됐다.
    #---------------------------------------------------------------------------
    FILE="$SESSION_DIR/auto-${TODAY}.md"
    SaveSnapshot "$FILE"
    echo "[세션 종료] ⚠️  /save-session 미실행 → auto-${TODAY}.md 자동 갱신"
fi

#-------------------------------------------------------------------------------
# 보존 기간 정리 — 14일 지난 자동 스냅샷은 삭제 (수동 세션은 건드리지 않음)
#-------------------------------------------------------------------------------
find "$SESSION_DIR" -maxdepth 1 -name 'auto-*.md' -mtime +14 -delete 2>/dev/null || true

UpdateUpstreamRef
