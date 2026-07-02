################################################################################
# FILE NAME   : feedback.sh
# DESCRIPTION : arachne 피드백 도메인 — 개선 의견 초안 생성(new)·목록(list)·
#               GitHub Issue 제출(submit). install.sh 에서 source 되는 라이브러리로,
#               단독 실행하지 않는다 (REPO_DIR·arachne_log·arachne_section 은
#               install.sh 가 정의).
# DATA        : 2026-07-02
# Modification: 2026-07-02
################################################################################
# shellcheck shell=bash

################################################################################
# FUNCTION    : create_feedback_draft
# DESCRIPTION : 프로젝트 docs/feedback 에 Arachne 피드백 초안 생성
# PARAMETERS  : string title - 선택 제목
################################################################################
create_feedback_draft() {
    local title="${1:-Arachne feedback}"
    local project_abs
    local project_name
    local project_safe
    local title_safe
    local today
    local stamp
    local feedback_dir
    local feedback_file
    local feedback_tmpl="$REPO_DIR/docs/template/feedback.md"

    if [ ! -f "$feedback_tmpl" ]; then
        arachne_log "ERROR" "피드백 템플릿이 없습니다: $feedback_tmpl"
        return 1
    fi
    arachne_section "feedback 초안 생성 시작"
    project_abs=$(pwd)
    project_name=$(basename "$project_abs")
    project_safe=$(printf '%s' "$project_name" | sed 's/[&\\]/\\&/g')
    title_safe=$(printf '%s' "$title" | sed 's/[&\\]/\\&/g')
    today=$(date +%F)
    stamp=$(date +%Y-%m-%d-%H%M%S)
    feedback_dir="$project_abs/docs/feedback"
    feedback_file="$feedback_dir/${stamp}-arachne-feedback.md"

    mkdir -p "$feedback_dir"
    sed -e "s/YYYY-MM-DD/${today}/g" \
        -e "s/Title: \"Arachne feedback\"/Title: \"${title_safe}\"/" \
        -e "s/\[\[Project_name\]\]/[[${project_safe}]]/" \
        "$feedback_tmpl" > "$feedback_file"
    arachne_section "feedback 초안 생성 완료"
    echo "$feedback_file"
}

################################################################################
# FUNCTION    : list_feedback_drafts
# DESCRIPTION : 프로젝트 docs/feedback 문서의 제출 상태 목록 출력
################################################################################
list_feedback_drafts() {
    local feedback_dir="$PWD/docs/feedback"
    local feedback_file
    local status
    local title

    arachne_section "feedback 목록 조회"
    if [ ! -d "$feedback_dir" ]; then
        arachne_log "SKIP" "feedback 문서 없음: $feedback_dir"
        return 0
    fi
    find "$feedback_dir" -maxdepth 1 -type f -name '*.md' | sort | while read -r feedback_file; do
        status=$(sed -n 's/^status: "\(.*\)"/\1/p' "$feedback_file" | head -n 1)
        title=$(sed -n 's/^Title: "\(.*\)"/\1/p' "$feedback_file" | head -n 1)
        printf '%s\t%s\t%s\n' "${status:-unknown}" "${title:-untitled}" "$feedback_file"
    done
}

################################################################################
# FUNCTION    : assert_feedback_safe
# DESCRIPTION : 제출 전 명백한 민감정보 후보를 차단
# PARAMETERS  : string feedback_file - 검사 대상
################################################################################
assert_feedback_safe() {
    local feedback_file="$1"
    local secret_pattern='(sk-[A-Za-z0-9_-]{12,}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16})'
    local path_pattern='(/home/[^[:space:]]+|/Users/[^[:space:]]+|[A-Za-z]:\\Users\\[^[:space:]]+)'

    if grep -Eq "$secret_pattern|$path_pattern" "$feedback_file"; then
        arachne_log "ERROR" "피드백에 토큰 또는 절대 경로로 보이는 문자열이 있습니다."
        echo "        마스킹 후 다시 제출하거나 --allow-sensitive 를 명시하세요." >&2
        return 1
    fi
}

################################################################################
# FUNCTION    : submit_feedback
# DESCRIPTION : 피드백 문서를 미리보기·확인 후 GitHub Issue 로 제출
# PARAMETERS  : string feedback_file + 선택 --allow-sensitive
################################################################################
submit_feedback() {
    local allow_sensitive=0
    local feedback_file=""
    local title
    local issue_url
    local submitted_at
    local tmp_file
    local answer

    while [ $# -gt 0 ]; do
        case "$1" in
            --allow-sensitive) allow_sensitive=1 ;;
            -*) arachne_log "ERROR" "알 수 없는 feedback submit 옵션: $1"; return 1 ;;
            *)  feedback_file="$1" ;;
        esac
        shift
    done
    arachne_section "feedback 제출 시작"
    if [ -z "$feedback_file" ] || [ ! -f "$feedback_file" ]; then
        arachne_log "ERROR" "제출할 feedback 파일이 필요합니다"
        return 1
    fi
    if grep -Eq '^status: "submitted"|^- \*\*상태\*\*: submitted' "$feedback_file"; then
        arachne_log "ERROR" "이미 제출된 feedback 입니다: $feedback_file"
        return 1
    fi
    [ "$allow_sensitive" -eq 1 ] || assert_feedback_safe "$feedback_file" || return 1

    command -v gh >/dev/null 2>&1 || {
        arachne_log "ERROR" "gh CLI가 필요합니다"
        return 1
    }
    gh auth status >/dev/null 2>&1 || {
        arachne_log "ERROR" "gh 인증 상태를 확인할 수 없습니다"
        return 1
    }
    gh repo view >/dev/null 2>&1 || {
        arachne_log "ERROR" "현재 디렉터리에서 GitHub 저장소를 확인할 수 없습니다"
        return 1
    }

    arachne_section "feedback 제출 미리보기: $feedback_file"
    sed -n '1,220p' "$feedback_file"
    if [ "${ARACHNE_FEEDBACK_YES:-0}" != "1" ]; then
        printf 'Submit to GitHub Issue? Type YES: '
        read -r answer
        if [ "$answer" != "YES" ]; then
            arachne_log "SKIP" "feedback 제출 취소"
            return 1
        fi
    fi

    title=$(sed -n 's/^Title: "\(.*\)"/\1/p' "$feedback_file" | head -n 1)
    issue_url=$(gh issue create --title "${title:-Arachne feedback}" --body-file "$feedback_file")
    submitted_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    tmp_file="${feedback_file}.tmp"
    sed -e 's/^status: ".*"/status: "submitted"/' \
        -e 's/^- \*\*상태\*\*: .*/- **상태**: submitted/' \
        -e "s|^- \*\*제출 URL\*\*:.*|- **제출 URL**: ${issue_url}|" \
        -e "s|^- \*\*제출 시각\*\*:.*|- **제출 시각**: ${submitted_at}|" \
        "$feedback_file" > "$tmp_file"
    mv "$tmp_file" "$feedback_file"
    arachne_section "feedback 제출 완료: $issue_url"
}

################################################################################
# FUNCTION    : feedback_command
# DESCRIPTION : Arachne 개선 피드백 초안·목록·제출 서브커맨드 처리
# PARAMETERS  : new|list|submit ...
################################################################################
feedback_command() {
    local subcommand="${1:-}"

    case "$subcommand" in
        new)    shift; create_feedback_draft "$*" ;;
        list)   list_feedback_drafts ;;
        submit) shift; submit_feedback "$@" ;;
        *)
            echo "Usage: arachne feedback new [title] | list | submit <file> [--allow-sensitive]" >&2
            return 1
            ;;
    esac
}
