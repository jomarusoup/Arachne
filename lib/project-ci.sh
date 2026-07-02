################################################################################
# FILE NAME   : project-ci.sh
# DESCRIPTION : arachne 프로젝트 도메인 — 신규 프로젝트 스캐폴딩(new)·프로젝트 CI
#               생성/갱신(init-ci)·로컬 검증(project-check). install.sh 에서 source
#               되는 라이브러리로, 단독 실행하지 않는다 (REPO_DIR·arachne_log·
#               arachne_section 은 install.sh 가 정의).
# DATA        : 2026-07-02
# Modification: 2026-07-02
################################################################################
# shellcheck shell=bash

################################################################################
# FUNCTION    : validate_project_profile
# DESCRIPTION : 프로젝트 CI profile 이름 검증
# PARAMETERS  : string profile - minimal|python|web|python-web
# RETURNED    : 유효하면 0, 아니면 1
################################################################################
validate_project_profile() {
    local profile="$1"

    case "$profile" in
        minimal|python|web|python-web) return 0 ;;
        *)
            arachne_log "ERROR" "알 수 없는 profile: '$profile' (minimal|python|web|python-web)"
            return 1
            ;;
    esac
}

################################################################################
# FUNCTION    : profile_has_design_docs
# DESCRIPTION : profile 이 프로젝트 디자인 문서 생성을 요구하는지 판정
# PARAMETERS  : string profile - minimal|python|web|python-web
# RETURNED    : web 계열이면 0, 아니면 1
################################################################################
profile_has_design_docs() {
    local profile="$1"

    case "$profile" in
        web|python-web) return 0 ;;
        *)              return 1 ;;
    esac
}

################################################################################
# FUNCTION    : install_project_design_docs
# DESCRIPTION : Web profile 프로젝트에 docs/design/DESIGN.md 최소 템플릿 생성
# PARAMETERS  : string project_abs - 프로젝트 절대 경로
#               string profile     - minimal|python|web|python-web
################################################################################
install_project_design_docs() {
    local project_abs="$1"
    local profile="$2"
    local project_name
    local project_safe
    local today
    local design_tmpl="$REPO_DIR/templates/project/design/DESIGN.md"
    local design_dir="$project_abs/docs/design"
    local decisions_dir="$design_dir/decisions"
    local design_file="$design_dir/DESIGN.md"
    local legacy_file="$project_abs/DESIGN.md"
    local managed_path

    profile_has_design_docs "$profile" || return 0
    if [ ! -f "$design_tmpl" ]; then
        arachne_log "ERROR" "디자인 문서 템플릿이 없습니다: $design_tmpl"
        return 1
    fi
    for managed_path in "$design_dir" "$design_file" "$decisions_dir" "$legacy_file"; do
        if [ -L "$managed_path" ]; then
            arachne_log "ERROR" "디자인 문서 경로가 심볼릭 링크입니다: $managed_path"
            return 1
        fi
    done

    mkdir -p "$decisions_dir"
    touch "$decisions_dir/.gitkeep"
    if [ -f "$design_file" ]; then
        echo "  보존: docs/design/DESIGN.md"
        return 0
    fi

    project_name=$(basename "$project_abs")
    project_safe=$(printf '%s' "$project_name" | sed 's/[&\\]/\\&/g')
    today=$(date +%F)
    sed -e "s/YYYY-MM-DD/${today}/g" \
        -e "s/Project_name/${project_safe}/g" \
        -e "s/Title: \"Project design\"/Title: \"${project_safe} design\"/" \
        "$design_tmpl" > "$design_file"
    echo "  생성: docs/design/DESIGN.md"
}

################################################################################
# FUNCTION    : init_project_ci
# DESCRIPTION : 프로젝트에 로컬·GitHub CI 공통 검증 자산 설치 또는 갱신
# PARAMETERS  : 위치인자 project_dir + --profile minimal|python|web|python-web
################################################################################
init_project_ci() {
    local profile="minimal"
    local positional=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --profile=*) profile="${1#--profile=}" ;;
            --profile)
                shift
                [ $# -gt 0 ] || {
                    arachne_log "ERROR" "--profile 값이 필요합니다"
                    return 1
                }
                profile="$1"
                ;;
            -*) arachne_log "ERROR" "알 수 없는 옵션: $1"; return 1 ;;
            *) positional+=("$1") ;;
        esac
        shift
    done

    if [ "${#positional[@]}" -gt 1 ]; then
        arachne_log "ERROR" "프로젝트 디렉터리는 하나만 지정할 수 있습니다"
        return 1
    fi
    validate_project_profile "$profile" || return 1

    local project_dir="${positional[0]:-$PWD}"
    local verify_tmpl="$REPO_DIR/templates/project/verify.sh"
    local commands_tmpl="$REPO_DIR/templates/project/profiles/$profile/commands"
    local workflow_tmpl="$REPO_DIR/templates/project/arachne.yml"
    local managed_path
    local project_abs

    arachne_section "프로젝트 CI 초기화 시작 (profile=$profile)"
    if [ ! -d "$project_dir" ]; then
        arachne_log "ERROR" "프로젝트 디렉터리가 없습니다: $project_dir"
        return 1
    fi
    if [ ! -f "$verify_tmpl" ] || [ ! -f "$commands_tmpl" ] \
        || [ ! -f "$workflow_tmpl" ]; then
        arachne_log "ERROR" "프로젝트 CI 템플릿이 없습니다: $REPO_DIR/templates/project"
        return 1
    fi

    project_abs=$(cd "$project_dir" && pwd)
    for managed_path in \
        "$project_abs/.arachne" \
        "$project_abs/.github" \
        "$project_abs/.github/workflows" \
        "$project_abs/.arachne/verify.sh" \
        "$project_abs/.arachne/profile" \
        "$project_abs/.github/workflows/arachne.yml"; do
        if [ -L "$managed_path" ]; then
            arachne_log "ERROR" "프로젝트 CI 관리 경로가 심볼릭 링크입니다: $managed_path"
            return 1
        fi
    done

    mkdir -p "$project_abs/.arachne" "$project_abs/.github/workflows"
    cp "$verify_tmpl" "$project_abs/.arachne/verify.sh"
    chmod +x "$project_abs/.arachne/verify.sh"
    cp "$workflow_tmpl" "$project_abs/.github/workflows/arachne.yml"
    printf '%s\n' "$profile" > "$project_abs/.arachne/profile"
    install_project_design_docs "$project_abs" "$profile" || return 1

    if [ ! -f "$project_abs/.arachne/commands" ]; then
        cp "$commands_tmpl" "$project_abs/.arachne/commands"
        echo "  생성: .arachne/commands"
    else
        echo "  보존: .arachne/commands"
    fi

    arachne_section "프로젝트 CI 초기화 완료: $project_abs"
    echo "  profile: $profile"
    echo "  관리: .arachne/profile, .arachne/verify.sh, .github/workflows/arachne.yml"
    return 0
}

################################################################################
# FUNCTION    : check_project
# DESCRIPTION : 프로젝트에 설치된 공통 검증 runner 실행
# PARAMETERS  : string project_dir - 대상 프로젝트 경로, 기본 현재 디렉터리
# RETURNED    : 검증 runner의 종료 상태
################################################################################
check_project() {
    local project_dir="${1:-$PWD}"
    local project_abs
    local verify_script

    arachne_section "프로젝트 검증 시작"
    if [ ! -d "$project_dir" ]; then
        arachne_log "ERROR" "프로젝트 디렉터리가 없습니다: $project_dir"
        return 1
    fi

    project_abs=$(cd "$project_dir" && pwd)
    verify_script="$project_abs/.arachne/verify.sh"
    if [ ! -f "$verify_script" ]; then
        arachne_log "ERROR" "프로젝트 CI가 초기화되지 않았습니다: arachne init-ci \"$project_abs\""
        return 1
    fi

    if bash "$verify_script"; then
        arachne_section "프로젝트 검증 완료"
        return 0
    else
        arachne_section "프로젝트 검증 실패"
        return 1
    fi
}

################################################################################
# FUNCTION    : new_project
# DESCRIPTION : 신규 프로젝트를 기록 가능한 문서 구조로 스캐폴딩.
#               문서 종류별 frontmatter 는 docs/template/*.md 에서 파생.
# PARAMETERS  : 위치인자 project_name [parent_dir] + 플래그 --no-git
#               --profile minimal|python|web|python-web
#               parent_dir 생략 시 현재 디렉터리. 대상 존재 시 거부.
################################################################################
new_project() {
    local do_git=1
    local profile="minimal"
    local positional=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-git) do_git=0 ;;
            --profile=*) profile="${1#--profile=}" ;;
            --profile)
                shift
                [ $# -gt 0 ] || {
                    arachne_log "ERROR" "--profile 값이 필요합니다"
                    exit 1
                }
                profile="$1"
                ;;
            -*)       arachne_log "ERROR" "알 수 없는 옵션: $1"; exit 1 ;;
            *)        positional+=("$1") ;;
        esac
        shift
    done

    local proj="${positional[0]:-}"
    local parent="${positional[1]:-$PWD}"

    #---------------------------------------------------------------------------
    # 입력 검증
    #---------------------------------------------------------------------------
    arachne_section "신규 프로젝트 생성 시작"
    if [ -z "$proj" ]; then
        arachne_log "ERROR" "프로젝트명이 필요합니다: arachne new <project> [parent-dir] [--no-git]"
        exit 1
    fi
    case "$proj" in
        */*|.*) arachne_log "ERROR" "프로젝트명에 '/'·선행 '.' 사용 불가: $proj"; exit 1 ;;
    esac
    validate_project_profile "$profile" || exit 1

    local tmpl="$REPO_DIR/docs/template/example.md"
    local idea_tmpl="$REPO_DIR/docs/template/idea.md"
    local issue_tmpl="$REPO_DIR/docs/template/issue.md"
    local audit_tmpl="$REPO_DIR/docs/template/audit.md"
    local task_tmpl="$REPO_DIR/docs/template/task.md"
    local feedback_tmpl="$REPO_DIR/docs/template/feedback.md"
    local task_rules="$REPO_DIR/docs/task/README.md"
    local agents_tmpl="$REPO_DIR/templates/project/AGENTS.md"
    local claude_tmpl="$REPO_DIR/templates/project/CLAUDE.md"
    if [ ! -f "$tmpl" ] || [ ! -f "$idea_tmpl" ] || [ ! -f "$issue_tmpl" ] \
        || [ ! -f "$audit_tmpl" ] || [ ! -f "$task_tmpl" ] || [ ! -f "$feedback_tmpl" ] || [ ! -f "$task_rules" ] \
        || [ ! -f "$agents_tmpl" ] || [ ! -f "$claude_tmpl" ]; then
        arachne_log "ERROR" "문서 템플릿 또는 task 규약이 없습니다"
        exit 1
    fi

    local dest="$parent/$proj"
    if [ -e "$dest" ]; then
        arachne_log "ERROR" "이미 존재합니다: $dest"
        exit 1
    fi

    #---------------------------------------------------------------------------
    # 기록 구조 생성
    #---------------------------------------------------------------------------
    mkdir -p "$dest/docs/issue" "$dest/docs/idea" "$dest/docs/task" "$dest/docs/feedback" "$dest/docs/template"
    touch "$dest/docs/issue/.gitkeep" "$dest/docs/idea/.gitkeep" "$dest/docs/feedback/.gitkeep"
    cp "$tmpl" "$dest/docs/template/example.md"
    cp "$idea_tmpl" "$dest/docs/template/idea.md"
    cp "$issue_tmpl" "$dest/docs/template/issue.md"
    cp "$audit_tmpl" "$dest/docs/template/audit.md"
    cp "$task_tmpl" "$dest/docs/template/task.md"
    cp "$feedback_tmpl" "$dest/docs/template/feedback.md"
    cp "$task_rules" "$dest/docs/task/README.md"

    #---------------------------------------------------------------------------
    # README.md — example.md frontmatter 치환 (Title·날짜·MOC)
    #---------------------------------------------------------------------------
    local today
    today=$(date +%F)
    sed -e "s/^Title:.*/Title: ${proj}/" \
        -e "s/YYYY-MM-DD/${today}/g" \
        -e "s/\[\[Project_name\]\]/[[${proj}]]/" \
        "$tmpl" > "$dest/README.md"
    printf '\n# %s\n' "$proj" >> "$dest/README.md"

    #---------------------------------------------------------------------------
    # 지침 스텁 — AGENTS.md(프로젝트 SSOT) + CLAUDE.md(포인터)
    # 섹션 골격만 생성하고 본문은 비워둔다(미기재 마커). 자동 기록은 하지 않으며
    # /learn·사람 승인으로만 채운다 — 지침 파일은 매 세션 로드되는 반복 비용이므로.
    #---------------------------------------------------------------------------
    # sed replacement 메타문자(& \) 이스케이프 — 프로젝트명 "AT&T" 등 오치환 방지
    local proj_safe
    proj_safe=$(printf '%s' "${proj}" | sed 's/[&\\]/\\&/g')
    sed "s/{{PROJECT}}/${proj_safe}/g" "$agents_tmpl" > "$dest/AGENTS.md"
    sed "s/{{PROJECT}}/${proj_safe}/g" "$claude_tmpl" > "$dest/CLAUDE.md"

    #---------------------------------------------------------------------------
    # git 초기화 (기본) — --no-git 으로 생략
    #---------------------------------------------------------------------------
    if [ "$do_git" -eq 1 ]; then
        git -C "$dest" init -q
    fi

    #---------------------------------------------------------------------------
    # 프로젝트 로컬 검증 + GitHub Actions CI
    #---------------------------------------------------------------------------
    init_project_ci "$dest" --profile "$profile"

    arachne_section "신규 프로젝트 생성 완료: $dest"
    echo "  profile: $profile"
    echo "  구조: README.md, AGENTS.md, CLAUDE.md, docs/{issue,idea,task,feedback,template}, .arachne, .github/workflows"
    [ "$do_git" -eq 1 ] && echo "  git 저장소 초기화됨"
    return 0
}
