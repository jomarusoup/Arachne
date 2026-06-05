#!/bin/bash
################################################################################
# FILE NAME   : install.sh
# DESCRIPTION : Arachne -> ~/.claude 심볼릭 링크 설치 스크립트
# DATA        : 2026-05-05
# Modification: 2026-06-04
################################################################################

set -e

# readlink -f 로 심볼릭 링크(arachne -> install.sh)를 해석해야 실제 레포 경로를 얻는다.
# 미해석 시 arachne 커맨드 실행 위치(~/.local/bin)가 잡혀 update/session 이 실패한다.
REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
DOTFILES_DIR="$REPO_DIR/dotfiles"
LOCAL_BIN="$HOME/.local/bin"
ARACHNE_TAG="ARACHNE"
PROG="arachne"
ARACHNE_VERSION="1.0.0"

# "스크립트명:커맨드명" 형식 — git pull 시 심볼릭 링크라 자동 업데이트됨
BIN_TARGETS=(
    "install.sh:arachne"
    "tmux.sh:tws"
    "gask.sh:gask"
)

SYMLINK_TARGETS=(
    "CLAUDE.md"
    "statusline-command.sh"
    "commands"
    "agents"
    "rules"
    "hooks"
    "skills"
)

################################################################################
# FUNCTION    : usage
# DESCRIPTION : 사용법 출력
################################################################################
usage() {
    local entry
    local script
    local cmd

    echo "Usage: ${PROG} [OPTION]"
    echo ""
    echo "Arachne — Claude Code 글로벌 설정 관리 도구"
    echo ""
    echo "Options:"
    echo "  -i, --install          설치/재설치 수행"
    echo "  -u, --update           git pull 후 최신 상태로 재설치"
    echo "  -s, --session          tmux 워크스페이스 매니저(tws) 실행"
    echo "  -e, --export-settings  ~/.claude/settings.json -> settings.template.json 내보내기"
    echo "  -d, --export-dotfiles  ~/.bash_profile, ~/.vimrc -> dotfiles/ 내보내기"
    echo "  -h, --help             이 도움말 출력"
    echo "  -v, --version          버전 정보 출력"
    echo ""
    echo "설치 후 사용 가능한 CLI 커맨드:"
    for entry in "${BIN_TARGETS[@]}"; do
        script="${entry%%:*}"
        cmd="${entry##*:}"
        echo "  ${cmd}  (-> ${script})"
    done
}

################################################################################
# FUNCTION    : show_version
# DESCRIPTION : 버전 정보 출력 (git 단축 해시 포함)
################################################################################
show_version() {
    local rev
    rev=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    echo "${PROG} ${ARACHNE_VERSION} (${rev})"
}

################################################################################
# FUNCTION    : update_arachne
# DESCRIPTION : git pull 후 최신 상태로 재설치 (동기화 허브)
################################################################################
update_arachne() {
    echo "[Arachne] 업데이트 시작 (git pull)"
    cd "$REPO_DIR" || { echo "[ERROR] 레포 디렉터리 진입 실패: $REPO_DIR" >&2; exit 1; }
    git pull
    echo "[Arachne] 최신 소스 기반 재설치 진행"
    install
}

################################################################################
# FUNCTION    : run_session
# DESCRIPTION : tmux 워크스페이스 매니저 실행 (tws 래퍼)
################################################################################
run_session() {
    local tmux_script="$REPO_DIR/tmux.sh"
    if [ -f "$tmux_script" ]; then
        exec "$tmux_script"
    else
        echo "[ERROR] tmux.sh 파일을 찾을 수 없습니다: $tmux_script"
        exit 1
    fi
}

################################################################################
# FUNCTION    : backup_and_link
# DESCRIPTION : 기존 파일/디렉터리 백업 후 심볼릭 링크 생성
# PARAMETERS  : string src - 레포 내 원본 경로
#               string dst - ~/.claude/ 내 대상 경로
################################################################################
backup_and_link() {
    local src="$1"
    local dst="$2"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        echo "  백업: $dst -> $dst.bak"
        mv "$dst" "$dst.bak"
    elif [ -L "$dst" ]; then
        rm "$dst"
    fi

    ln -s "$src" "$dst"
    echo "  링크: $dst -> $src"
}

################################################################################
# FUNCTION    : register_bin
# DESCRIPTION : BIN_TARGETS 를 ~/.local/bin/ 에 심볼릭 링크로 등록
#               git pull 시 자동 업데이트 (재실행 불필요)
#               새 스크립트 추가 시에만 재실행 필요
################################################################################
register_bin() {
    echo "[Arachne] bin 등록 시작: $LOCAL_BIN"
    mkdir -p "$LOCAL_BIN"

    for entry in "${BIN_TARGETS[@]}"; do
        local script="${entry%%:*}"
        local cmd="${entry##*:}"
        local src="$REPO_DIR/$script"
        local dst="$LOCAL_BIN/$cmd"

        if [ ! -f "$src" ]; then
            echo "  스킵 (파일 없음): $script"
            continue
        fi

        chmod +x "$src"

        if [ -L "$dst" ]; then
            rm "$dst"
        elif [ -e "$dst" ]; then
            echo "  백업: $dst -> $dst.bak"
            mv "$dst" "$dst.bak"
        fi

        ln -s "$src" "$dst"
        echo "  등록: $cmd -> $src"
    done

    echo "[Arachne] bin 등록 완료"

    if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
        echo "  주의: $LOCAL_BIN 이 PATH에 없습니다. ~/.bash_profile에 추가하세요:"
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

################################################################################
# FUNCTION    : install
# DESCRIPTION : 심볼릭 링크 설치 및 settings.json 생성
################################################################################
install() {
    echo "[Arachne] 설치 시작: $REPO_DIR -> $CLAUDE_DIR"
    mkdir -p "$CLAUDE_DIR"

    for target in "${SYMLINK_TARGETS[@]}"; do
        backup_and_link "$REPO_DIR/$target" "$CLAUDE_DIR/$target"
    done

    # settings.json: __HOME__ 치환 후 생성 (심볼릭 링크 아님)
    local settings_dst="$CLAUDE_DIR/settings.json"
    if [ -e "$settings_dst" ] && [ ! -L "$settings_dst" ]; then
        echo "  백업: $settings_dst -> $settings_dst.bak"
        cp "$settings_dst" "$settings_dst.bak"
    fi
    sed "s|__HOME__|$HOME|g" "$REPO_DIR/settings.template.json" > "$settings_dst"
    echo "  생성: $settings_dst (from settings.template.json)"

    echo "[Arachne] Claude 설치 완료"
    install_dotfiles
    register_bin
}

################################################################################
# FUNCTION    : merge_dotfile
# DESCRIPTION : dotfiles/ 내용을 사용자 파일에 ARACHNE 섹션으로 병합
#               기존 파일 내용 유지, 섹션이 있으면 갱신 / 없으면 끝에 추가
# PARAMETERS  : string src - dotfiles/ 내 원본 경로
#               string dst - 홈 디렉터리 내 대상 경로
################################################################################
merge_dotfile() {
    local src="$1"
    local dst="$2"

    local begin="# === ${ARACHNE_TAG} BEGIN ==="
    local end="# === ${ARACHNE_TAG} END ==="
    local tmp
    tmp=$(mktemp)

    # 심볼릭 링크 → 일반 파일로 변환
    if [ -L "${dst}" ]; then
        local link_target
        link_target=$(readlink -f "${dst}" 2>/dev/null || true)
        rm "${dst}"

        if [ "${link_target}" = "$(readlink -f "${src}")" ]; then
            # Arachne dotfile 자체로의 링크: 빈 파일로 시작 (내용은 섹션으로 재주입)
            touch "${dst}"
        else
            # 다른 파일로의 링크: 해당 내용 보존
            cp "${link_target}" "${dst}" 2>/dev/null || touch "${dst}"
        fi
        echo "  변환: 심볼릭 링크 → 파일 ${dst}"
    fi

    [ -f "${dst}" ] || touch "${dst}"

    if grep -qF "${begin}" "${dst}" 2>/dev/null; then
        # 기존 ARACHNE 섹션 교체 (마커 외부 내용 유지)
        awk -v b="${begin}" -v e="${end}" \
            'BEGIN{skip=0}
             index($0,b){skip=1; next}
             index($0,e){skip=0; next}
             !skip{print}' "${dst}" > "${tmp}"
        echo "  갱신 (ARACHNE 섹션): ${dst}"
    else
        # 최초 설치: 기존 내용 보존 후 섹션 추가
        cp "${dst}" "${tmp}"
        echo "  병합 (ARACHNE 섹션 추가): ${dst}"
    fi

    {
        printf '\n%s\n' "${begin}"
        cat "${src}"
        printf '%s\n' "${end}"
    } >> "${tmp}"

    mv "${tmp}" "${dst}"
}

################################################################################
# FUNCTION    : install_dotfiles
# DESCRIPTION : dotfiles/ 내용을 홈 디렉터리 파일에 ARACHNE 섹션으로 병합 설치
################################################################################
install_dotfiles() {
    echo "[Arachne] dotfiles 설치 시작"
    merge_dotfile "$DOTFILES_DIR/bash_profile" "$HOME/.bash_profile"
    merge_dotfile "$DOTFILES_DIR/vimrc"        "$HOME/.vimrc"
    echo "[Arachne] dotfiles 설치 완료"
    echo "  적용하려면: source ~/.bash_profile"
}

################################################################################
# FUNCTION    : _export_single
# DESCRIPTION : 사용자 파일의 ARACHNE 섹션을 dotfiles/ 로 추출
# PARAMETERS  : string src - 홈 디렉터리 내 원본 파일 경로
#               string dst - dotfiles/ 내 대상 경로
#               string label - 로그 표시용 파일명
################################################################################
_export_single() {
    local src="$1"
    local dst="$2"
    local label="$3"

    local begin="# === ${ARACHNE_TAG} BEGIN ==="
    local end="# === ${ARACHNE_TAG} END ==="

    if [ ! -f "${src}" ] && [ ! -L "${src}" ]; then
        echo "  스킵 (없음): ${src}"
        return
    fi

    if grep -qF "${begin}" "${src}" 2>/dev/null; then
        # ARACHNE 섹션만 추출
        awk -v b="${begin}" -v e="${end}" \
            'BEGIN{skip=0}
             index($0,b){skip=1; next}
             index($0,e){skip=0; next}
             skip{print}' "${src}" > "${dst}"
        echo "  추출: ARACHNE 섹션 → dotfiles/${label}"
    elif [ -L "${src}" ]; then
        echo "  스킵 (심볼릭 링크, 이미 레포와 연결됨): ${src}"
    else
        cp "${src}" "${dst}"
        echo "  복사: ${label}"
    fi
}

################################################################################
# FUNCTION    : export_dotfiles
# DESCRIPTION : ~/.bash_profile, ~/.vimrc -> dotfiles/ 로 내보내기
################################################################################
export_dotfiles() {
    echo "[Arachne] dotfiles 내보내기 시작"
    _export_single "$HOME/.bash_profile" "$DOTFILES_DIR/bash_profile" ".bash_profile"
    _export_single "$HOME/.vimrc"        "$DOTFILES_DIR/vimrc"        ".vimrc"
    echo "[Arachne] dotfiles 내보내기 완료"
    echo "  커밋하려면: cd $REPO_DIR && git add dotfiles/ && git commit -m 'chore: update dotfiles'"
}

################################################################################
# FUNCTION    : export_settings
# DESCRIPTION : ~/.claude/settings.json -> settings.template.json 내보내기
################################################################################
export_settings() {
    local settings_src="$CLAUDE_DIR/settings.json"
    local template_dst="$REPO_DIR/settings.template.json"

    if [ ! -f "$settings_src" ]; then
        echo "[ERROR] $settings_src 파일이 없습니다."
        exit 1
    fi

    sed "s|$HOME|__HOME__|g" "$settings_src" > "$template_dst"
    echo "[Arachne] settings.template.json 갱신 완료"
    echo "  커밋하려면: cd $REPO_DIR && git add settings.template.json && git commit -m 'chore: update settings template'"
}

case "${1:-}" in
    ""|"-h"|--help|help)                      usage ;;
    -i|--install|install)                     install ;;
    -u|--update|update)                       update_arachne ;;
    -s|--session|session)                     run_session ;;
    -e|--export-settings|export-settings)     export_settings ;;
    -d|--export-dotfiles|export-dotfiles)     export_dotfiles ;;
    -v|--version)                             show_version ;;
    *)                                        echo "[ERROR] 알 수 없는 옵션: $1" >&2; usage >&2; exit 1 ;;
esac
