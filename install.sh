#!/bin/bash
################################################################################
# FILE NAME   : install.sh
# DESCRIPTION : Arachne -> ~/.claude 심볼릭 링크 설치 스크립트
# DATA        : 2026-05-05
# Modification: 2026-05-31
################################################################################

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
DOTFILES_DIR="$REPO_DIR/dotfiles"

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
# FUNCTION    : install_dotfiles
# DESCRIPTION : dotfiles/ 의 파일을 홈 디렉터리에 심볼릭 링크로 설치
################################################################################
install_dotfiles() {
    echo "[Arachne] dotfiles 설치 시작"

    # bash_profile -> .bash_profile (기존 파일과 충돌 방지: 동일 파일이면 스킵)
    local bp_dst="$HOME/.bash_profile"
    local bp_src="$DOTFILES_DIR/bash_profile"
    if [ "$(readlink -f "$bp_dst" 2>/dev/null)" = "$bp_src" ]; then
        echo "  스킵 (이미 링크됨): $bp_dst"
    else
        backup_and_link "$bp_src" "$bp_dst"
    fi

    # vimrc -> .vimrc
    local vimrc_dst="$HOME/.vimrc"
    local vimrc_src="$DOTFILES_DIR/vimrc"
    if [ "$(readlink -f "$vimrc_dst" 2>/dev/null)" = "$vimrc_src" ]; then
        echo "  스킵 (이미 링크됨): $vimrc_dst"
    else
        backup_and_link "$vimrc_src" "$vimrc_dst"
    fi

    echo "[Arachne] dotfiles 설치 완료"
    echo "  적용하려면: source ~/.bash_profile"
}

################################################################################
# FUNCTION    : export_dotfiles
# DESCRIPTION : ~/.bash_profile, ~/.vimrc -> dotfiles/ 로 내보내기
################################################################################
export_dotfiles() {
    echo "[Arachne] dotfiles 내보내기 시작"

    # 심볼릭 링크인 경우 이미 레포와 연결되어 있으므로 불필요
    if [ -L "$HOME/.bash_profile" ]; then
        echo "  스킵 (.bash_profile 은 이미 심볼릭 링크)"
    else
        cp "$HOME/.bash_profile" "$DOTFILES_DIR/bash_profile"
        echo "  복사: ~/.bash_profile -> dotfiles/bash_profile"
    fi

    if [ -L "$HOME/.vimrc" ]; then
        echo "  스킵 (.vimrc 는 이미 심볼릭 링크)"
    else
        cp "$HOME/.vimrc" "$DOTFILES_DIR/vimrc"
        echo "  복사: ~/.vimrc -> dotfiles/vimrc"
    fi

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
