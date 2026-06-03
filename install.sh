#!/bin/bash
################################################################################
# FILE NAME   : install.sh
# DESCRIPTION : Arachne -> ~/.claude 심볼릭 링크 설치 스크립트
# DATA        : 2026-05-05
# Modification: 2026-06-03
################################################################################

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
DOTFILES_DIR="$REPO_DIR/dotfiles"
ARACHNE_TAG="ARACHNE"

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
    echo "Usage: $0 [--export-settings] [--export-dotfiles]"
    echo ""
    echo "  (no args)          : ~/.claude/ 심볼릭 링크 + dotfiles 설치"
    echo "  --export-settings  : ~/.claude/settings.json -> settings.template.json 으로 내보내기"
    echo "  --export-dotfiles  : ~/.bash_profile, ~/.vimrc -> dotfiles/ 로 내보내기"
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
    --export-settings) export_settings ;;
    --export-dotfiles) export_dotfiles ;;
    --help|-h)         usage ;;
    "")                install ;;
    *)                 echo "[ERROR] 알 수 없는 옵션: $1"; usage; exit 1 ;;
esac
