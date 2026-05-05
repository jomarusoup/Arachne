#!/bin/bash
# FILE NAME   : install.sh
# DESCRIPTION : Arachne -> ~/.claude 심볼릭 링크 설치 스크립트
# DATA        : 2026-05-05
# Modification: 2026-05-05

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

SYMLINK_TARGETS=(
    "CLAUDE.md"
    "statusline-command.sh"
    "commands"
    "agents"
    "rules"
    "hooks"
)

usage() {
    echo "Usage: $0 [--export-settings]"
    echo ""
    echo "  (no args)          : ~/.claude/ 에 심볼릭 링크 설치"
    echo "  --export-settings  : ~/.claude/settings.json -> settings.template.json 으로 내보내기"
}

# FUNCTION    : backup_and_link
# DESCRIPTION : 기존 파일 백업 후 심볼릭 링크 생성
# PARAMETERS  : string src - 레포 내 원본 경로
#               string dst - ~/.claude/ 내 대상 경로
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

# FUNCTION    : install
# DESCRIPTION : 심볼릭 링크 설치 및 settings.json 생성
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

    echo "[Arachne] 설치 완료"
}

# FUNCTION    : export_settings
# DESCRIPTION : ~/.claude/settings.json -> settings.template.json 내보내기
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
    --help|-h)         usage ;;
    "")                install ;;
    *)                 echo "[ERROR] 알 수 없는 옵션: $1"; usage; exit 1 ;;
esac
