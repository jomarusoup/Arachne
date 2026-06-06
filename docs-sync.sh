#!/bin/bash
################################################################################
# FILE NAME   : docs-sync.sh
# DESCRIPTION : 원격 프로젝트 문서를 Obsidian 프로젝트 폴더와 rsync로 동기화
# DATA        : 2026-06-06
# Modification: 2026-06-06
################################################################################

set -euo pipefail

PROG="docs-sync"
DEFAULT_CONFIG="${HOME}/.config/arachne/docs-sync.conf"

RSYNC_FILTERS=(
    "--include=/README.md"
    "--include=/docs/***"
    "--exclude=*"
)

RSYNC_BASE_OPTS=(
    "-avz"
    "--prune-empty-dirs"
)

################################################################################
# FUNCTION    : Usage
# DESCRIPTION : 사용법 출력
################################################################################
Usage() {
    cat <<'EOF'
Usage:
  docs-sync pull [PROJECT] [--config PATH] [--dry-run] [--delete]
  docs-sync push [PROJECT] [--config PATH] [--dry-run] [--delete]
  docs-sync list [--config PATH]
  docs-sync init [--config PATH]

Config format:
  # name<TAB>ssh_target<TAB>ssh_port<TAB>remote_dir<TAB>local_dir
  arachne	user@203.0.113.10	22	/home/Harness/Arachne	$HOME/Obsidian/프로젝트/Arachne

Legacy config format is also supported:
  # name<TAB>remote_root<TAB>local_dir
  arachne	user@203.0.113.10:/home/Harness/Arachne	$HOME/Obsidian/프로젝트/Arachne

Notes:
  - pull: remote project docs -> local Obsidian project folder
  - push: local Obsidian project folder -> remote project docs
  - --dry-run prints the rsync plan without changing files
  - --delete is opt-in because it removes files missing from the source
EOF
}

################################################################################
# FUNCTION    : ExpandPath
# DESCRIPTION : 설정의 $HOME 또는 ~ 를 실제 홈 경로로 확장
# PARAMETERS  : string path_value - 확장할 경로
# RETURNED    : 확장된 경로 stdout
################################################################################
ExpandPath() {
    local path_value="$1"
    path_value="${path_value/#\~/$HOME}"
    path_value="${path_value//\$HOME/$HOME}"
    printf '%s\n' "$path_value"
}

################################################################################
# FUNCTION    : EnsureConfig
# DESCRIPTION : 설정 파일 존재 확인
# PARAMETERS  : string config_path - 설정 파일 경로
################################################################################
EnsureConfig() {
    local config_path="$1"

    if [ ! -f "$config_path" ]; then
        echo "[ERROR] 설정 파일이 없습니다: $config_path" >&2
        echo "        먼저 실행: ${PROG} init --config $config_path" >&2
        exit 1
    fi
}

################################################################################
# FUNCTION    : InitConfig
# DESCRIPTION : 예시 설정 파일 생성
# PARAMETERS  : string config_path - 설정 파일 경로
################################################################################
InitConfig() {
    local config_path="$1"
    local config_dir
    config_dir="$(dirname "$config_path")"

    mkdir -p "$config_dir"
    if [ -e "$config_path" ]; then
        echo "[ERROR] 이미 존재합니다: $config_path" >&2
        exit 1
    fi

    {
        printf '# docs-sync project map\n'
        printf '# name<TAB>ssh_target<TAB>ssh_port<TAB>remote_dir<TAB>local_dir\n'
        # shellcheck disable=SC2016
        printf '# arachne\tuser@203.0.113.10\t22\t/home/Harness/Arachne\t$HOME/Obsidian/프로젝트/Arachne\n'
    } > "$config_path"

    echo "[docs-sync] 생성: $config_path"
}

################################################################################
# FUNCTION    : ListProjects
# DESCRIPTION : 설정 파일의 프로젝트 목록 출력
# PARAMETERS  : string config_path - 설정 파일 경로
################################################################################
ListProjects() {
    local config_path="$1"
    local name
    local ssh_target
    local ssh_port
    local remote_dir
    local local_dir
    local legacy_local_dir

    EnsureConfig "$config_path"

    while IFS=$'\t' read -r name ssh_target ssh_port remote_dir local_dir; do
        case "${name:-}" in
            ""|\#*) continue ;;
        esac
        if [ -z "${local_dir:-}" ]; then
            legacy_local_dir="$ssh_port"
            printf '%s\t%s\t%s\n' "$name" "$ssh_target" "$(ExpandPath "$legacy_local_dir")"
        else
            printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$ssh_target" "$ssh_port" "$remote_dir" "$(ExpandPath "$local_dir")"
        fi
    done < "$config_path"
}

################################################################################
# FUNCTION    : BuildRemoteRoot
# DESCRIPTION : 설정 컬럼으로 rsync 원격 루트 생성
# PARAMETERS  : string ssh_target       - user@host 또는 legacy remote_root
#               string ssh_port         - SSH 포트 또는 legacy local_dir
#               string remote_dir       - 원격 프로젝트 루트
#               string local_dir        - Obsidian 내 프로젝트 문서 폴더
# RETURNED    : remote_root, local_dir, ssh_port 를 탭 구분 stdout
################################################################################
BuildRemoteRoot() {
    local ssh_target="$1"
    local ssh_port="$2"
    local remote_dir="${3:-}"
    local local_dir="${4:-}"

    local remote_root
    local resolved_local_dir
    local resolved_ssh_port

    if [ -z "$local_dir" ]; then
        remote_root="$ssh_target"
        resolved_local_dir="$ssh_port"
        resolved_ssh_port=""
    else
        remote_dir="${remote_dir%/}"
        remote_root="${ssh_target}:${remote_dir}"
        resolved_local_dir="$local_dir"
        resolved_ssh_port="$ssh_port"
    fi

    printf '%s\t%s\t%s\n' "$remote_root" "$resolved_local_dir" "$resolved_ssh_port"
}

################################################################################
# FUNCTION    : SyncOne
# DESCRIPTION : 단일 프로젝트 문서 동기화
# PARAMETERS  : string mode        - pull | push
#               string name        - 프로젝트명
#               string remote_root - 원격 프로젝트 루트
#               string local_dir   - Obsidian 내 프로젝트 문서 폴더
#               string ssh_port    - SSH 포트(비어 있으면 기본값)
#               string dry_run     - 1이면 변경 없음
#               string delete_flag - 1이면 대상에서 사라진 파일 삭제
################################################################################
SyncOne() {
    local mode="$1"
    local name="$2"
    local remote_root="$3"
    local local_dir="$4"
    local ssh_port="$5"
    local dry_run="$6"
    local delete_flag="$7"

    local src
    local dst
    local extra_opts=()

    local_dir="$(ExpandPath "$local_dir")"
    remote_root="${remote_root%/}"
    local_dir="${local_dir%/}"

    if [ "$dry_run" = "1" ]; then
        extra_opts+=("--dry-run")
    fi
    if [ "$delete_flag" = "1" ]; then
        extra_opts+=("--delete")
    fi
    if [ -n "$ssh_port" ] && [ "$ssh_port" != "22" ]; then
        extra_opts+=("-e" "ssh -p ${ssh_port}")
    fi

    case "$mode" in
        pull)
            mkdir -p "$local_dir"
            src="${remote_root}/"
            dst="${local_dir}/"
            ;;
        push)
            if [ ! -d "$local_dir" ]; then
                echo "[ERROR] 로컬 디렉터리가 없습니다: $local_dir" >&2
                exit 1
            fi
            src="${local_dir}/"
            dst="${remote_root}/"
            ;;
        *)
            echo "[ERROR] 알 수 없는 모드: $mode" >&2
            exit 1
            ;;
    esac

    echo "[docs-sync] ${mode}: ${name}"
    rsync "${RSYNC_BASE_OPTS[@]}" "${extra_opts[@]}" "${RSYNC_FILTERS[@]}" "$src" "$dst"
}

################################################################################
# FUNCTION    : RunSync
# DESCRIPTION : 설정 파일을 읽어 전체 또는 지정 프로젝트를 동기화
# PARAMETERS  : string mode          - pull | push
#               string config_path   - 설정 파일 경로
#               string project_filter - 비어 있으면 전체
#               string dry_run       - 1이면 변경 없음
#               string delete_flag   - 1이면 삭제 반영
################################################################################
RunSync() {
    local mode="$1"
    local config_path="$2"
    local project_filter="$3"
    local dry_run="$4"
    local delete_flag="$5"

    local name
    local ssh_target
    local ssh_port
    local remote_dir
    local local_dir
    local remote_root
    local resolved_local_dir
    local resolved_ssh_port
    local matched=0

    EnsureConfig "$config_path"
    command -v rsync >/dev/null 2>&1 || { echo "[ERROR] rsync가 필요합니다." >&2; exit 1; }

    while IFS=$'\t' read -r name ssh_target ssh_port remote_dir local_dir; do
        case "${name:-}" in
            ""|\#*) continue ;;
        esac
        if [ -n "$project_filter" ] && [ "$project_filter" != "$name" ]; then
            continue
        fi
        matched=1
        IFS=$'\t' read -r remote_root resolved_local_dir resolved_ssh_port \
            < <(BuildRemoteRoot "$ssh_target" "$ssh_port" "${remote_dir:-}" "${local_dir:-}")
        SyncOne "$mode" "$name" "$remote_root" "$resolved_local_dir" "$resolved_ssh_port" "$dry_run" "$delete_flag"
    done < "$config_path"

    if [ "$matched" = "0" ]; then
        echo "[ERROR] 설정에서 프로젝트를 찾지 못했습니다: ${project_filter:-전체}" >&2
        exit 1
    fi
}

################################################################################
# FUNCTION    : Main
# DESCRIPTION : 인자 파싱 및 실행
################################################################################
Main() {
    local mode="${1:-}"
    local config_path="$DEFAULT_CONFIG"
    local project_filter=""
    local dry_run=0
    local delete_flag=0

    case "$mode" in
        pull|push|list|init) shift ;;
        -h|--help|"") Usage; exit 0 ;;
        *) echo "[ERROR] 알 수 없는 명령: $mode" >&2; Usage; exit 1 ;;
    esac

    while [ $# -gt 0 ]; do
        case "$1" in
            --config)
                shift
                config_path="${1:-}"
                ;;
            --config=*)
                config_path="${1#--config=}"
                ;;
            --dry-run|-n)
                dry_run=1
                ;;
            --delete)
                delete_flag=1
                ;;
            -*)
                echo "[ERROR] 알 수 없는 옵션: $1" >&2
                exit 1
                ;;
            *)
                if [ -n "$project_filter" ]; then
                    echo "[ERROR] 프로젝트는 하나만 지정할 수 있습니다." >&2
                    exit 1
                fi
                project_filter="$1"
                ;;
        esac
        shift || true
    done

    config_path="$(ExpandPath "$config_path")"

    case "$mode" in
        init) InitConfig "$config_path" ;;
        list) ListProjects "$config_path" ;;
        pull|push) RunSync "$mode" "$config_path" "$project_filter" "$dry_run" "$delete_flag" ;;
    esac
}

Main "$@"
