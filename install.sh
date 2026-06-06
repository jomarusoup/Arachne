#!/bin/bash
################################################################################
# FILE NAME   : install.sh
# DESCRIPTION : Arachne -> ~/.claude 심볼릭 링크 설치 스크립트
# DATA        : 2026-05-05
# Modification: 2026-06-04
################################################################################

set -euo pipefail

# readlink -f 로 심볼릭 링크(arachne -> install.sh)를 해석해야 실제 레포 경로를 얻는다.
# 미해석 시 arachne 커맨드 실행 위치(~/.local/bin)가 잡혀 update/session 이 실패한다.
REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
DOTFILES_DIR="$REPO_DIR/dotfiles"
LOCAL_BIN="$HOME/.local/bin"
ARACHNE_TAG="ARACHNE"
PROG="arachne"
ARACHNE_VERSION="1.0.0"
ENTRY_NAME="$(basename "$0")"

# "스크립트명:커맨드명" 형식 — git pull 시 심볼릭 링크라 자동 업데이트됨
# 위임 래퍼는 짧은 별칭(gask/cask)과 명시적 이름(gemini-task/codex-task) 둘 다 등록
BIN_TARGETS=(
    "install.sh:arachne"
    "tmux.sh:tws"
    "gemini-task.sh:gask"
    "gemini-task.sh:gemini-task"
    "codex-task.sh:cask"
    "codex-task.sh:codex-task"
    "docs-sync.sh:docs-sync"
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
    echo "      --target T          설치 대상 CLI: claude|gemini|codex|all (기본 all)"
    echo "                          (-i/-u 와 함께 사용. 미감지 CLI는 자동 스킵)"
    echo "  -c, --check            3개 CLI 연결 상태 점검 (심볼릭 댕글링·Codex stale 탐지)"
    echo "  -s, --session          tmux 워크스페이스 매니저(tws) 실행"
    echo "  -e, --export-settings  ~/.claude/settings.json -> settings.template.json 내보내기"
    echo "  -d, --export-dotfiles  ~/.bash_profile, ~/.vimrc, ~/.zshrc -> dotfiles/ 내보내기"
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
# FUNCTION    : install_claude
# DESCRIPTION : Claude Code 타깃 설치 — 심볼릭 링크 + settings.json 생성
#               (rules/ 가 ~/.claude/rules/ 로 링크돼 네이티브 자동 로드됨)
################################################################################
install_claude() {
    echo "[Arachne] Claude 설치 시작: $REPO_DIR -> $CLAUDE_DIR"
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
}

################################################################################
# FUNCTION    : install_gemini
# DESCRIPTION : Gemini CLI 타깃 설치 — AGENTS.md(SSOT)를 ~/.gemini/GEMINI.md 로 심볼릭
#               심볼릭이라 AGENTS.md 수정이 재설치 없이 즉시 반영됨
################################################################################
install_gemini() {
    local gemini_dir="$HOME/.gemini"
    echo "[Arachne] Gemini 설치 시작: AGENTS.md -> $gemini_dir/GEMINI.md"
    mkdir -p "$gemini_dir"
    backup_and_link "$REPO_DIR/AGENTS.md" "$gemini_dir/GEMINI.md"
    echo "[Arachne] Gemini 설치 완료"
}

################################################################################
# FUNCTION    : install_codex
# DESCRIPTION : Codex CLI 타깃 설치 — AGENTS.md(SSOT)를 ~/.codex/AGENTS.md 로 병합.
#               import 미지원이라 심볼릭 대신 마커 병합(사용자 보충 보존).
#               Markdown 친화 마커(<!-- === ARACHNE ... === -->) 사용.
#               심볼릭이 아니므로 AGENTS.md 수정 후 재반영하려면
#               arachne -i --target codex 재실행이 필요하다.
################################################################################
install_codex() {
    local codex_dir="$HOME/.codex"
    echo "[Arachne] Codex 설치 시작: AGENTS.md -> $codex_dir/AGENTS.md"
    mkdir -p "$codex_dir"
    merge_dotfile "$REPO_DIR/AGENTS.md" "$codex_dir/AGENTS.md" "<!--" " -->"
    echo "[Arachne] Codex 설치 완료"
}

################################################################################
# FUNCTION    : detect_cli
# DESCRIPTION : 대상 CLI 설치 여부 검사 (홈 디렉터리 또는 바이너리 존재)
# PARAMETERS  : string cli - gemini | codex
# RETURNED    : 0(감지) / 1(미감지)
################################################################################
detect_cli() {
    local cli="$1"
    case "$cli" in
        gemini) [ -d "$HOME/.gemini" ] || command -v gemini >/dev/null 2>&1 ;;
        codex)  [ -d "$HOME/.codex" ]  || command -v codex  >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

################################################################################
# FUNCTION    : _detect_zsh_target
# DESCRIPTION : ~/.zshrc 적용 대상 여부 판단
#               zshrc 파일이 이미 있거나 기본 셸이 zsh인 경우 적용
# RETURNED    : 0(적용) / 1(스킵)
################################################################################
_detect_zsh_target() {
    [ -f "$HOME/.zshrc" ] || [[ "$SHELL" == */zsh ]]
}

################################################################################
# FUNCTION    : install_shared
# DESCRIPTION : 타깃 무관 공통 설치 (dotfiles 병합 + bin 등록) — 항상 1회
################################################################################
install_shared() {
    install_dotfiles
    register_bin
}

################################################################################
# FUNCTION    : install
# DESCRIPTION : 타깃 디스패처 — ARACHNE_TARGET 에 따라 CLI별 설치 후 공통 설치
#               all 은 감지된 CLI 에만 설치(미감지 시 graceful skip)
################################################################################
install() {
    case "${ARACHNE_TARGET:-all}" in
        claude) install_claude ;;
        gemini) install_gemini ;;
        codex)  install_codex ;;
        all)
            install_claude
            if detect_cli gemini; then
                install_gemini
            else
                echo "[Arachne] Gemini CLI 미감지 — 스킵"
            fi
            if detect_cli codex; then
                install_codex
            else
                echo "[Arachne] Codex CLI 미감지 — 스킵"
            fi
            ;;
    esac
    install_shared
}

################################################################################
# FUNCTION    : merge_dotfile
# DESCRIPTION : dotfiles/ 내용을 사용자 파일에 ARACHNE 섹션으로 병합
#               기존 파일 내용 유지, 섹션이 있으면 갱신 / 없으면 끝에 추가
#               중복 감지: 사용자 영역에 이미 존재하는 줄은 섹션에서 제외
# PARAMETERS  : string src            - dotfiles/ 내 원본 경로
#               string dst            - 홈 디렉터리 내 대상 경로
#               string comment_char   - 형식별 주석 시작 문자 (기본: #, vimrc: ", md: <!--)
#               string comment_suffix - 형식별 주석 종료 문자 (기본: 없음, md: " -->")
################################################################################
merge_dotfile() {
    local src="$1"
    local dst="$2"
    local comment_char="${3:-#}"
    local comment_suffix="${4:-}"

    local begin="${comment_char} === ${ARACHNE_TAG} BEGIN ===${comment_suffix}"
    local end="${comment_char} === ${ARACHNE_TAG} END ===${comment_suffix}"
    local tmp
    tmp=$(mktemp)

    # 심볼릭 링크 → 일반 파일로 변환
    if [ -L "${dst}" ]; then
        local link_target
        link_target=$(readlink -f "${dst}" 2>/dev/null || true)
        rm "${dst}"

        if [ "${link_target}" = "$(readlink -f "${src}")" ]; then
            touch "${dst}"
        else
            cp "${link_target}" "${dst}" 2>/dev/null || touch "${dst}"
        fi
        echo "  변환: 심볼릭 링크 → 파일 ${dst}"
    fi

    [ -f "${dst}" ] || touch "${dst}"

    # 사용자 영역(ARACHNE 섹션 제외) 추출 — 중복 감지용
    local user_content
    user_content=$(awk -v b="${begin}" -v e="${end}" \
        'BEGIN{skip=0}
         index($0,b){skip=1; next}
         index($0,e){skip=0; next}
         !skip{print}' "${dst}")

    # src 줄 중 사용자 영역에 없는 것만 필터링
    local tmp_filtered
    tmp_filtered=$(mktemp)
    local skipped=0

    while IFS= read -r line; do
        local trimmed
        trimmed=$(printf '%s' "${line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # 빈 줄·주석은 그대로 통과
        if [ -z "${trimmed}" ] || [[ "${trimmed}" == "${comment_char}"* ]]; then
            printf '%s\n' "${line}" >> "${tmp_filtered}"
            continue
        fi
        # 사용자 영역에 이미 존재하면 스킵
        if printf '%s\n' "${user_content}" | grep -qxF "${trimmed}" 2>/dev/null; then
            skipped=$((skipped + 1))
        else
            printf '%s\n' "${line}" >> "${tmp_filtered}"
        fi
    done < "${src}"

    # 실질 내용(주석·공백 제외)이 남아있는지 확인
    local has_content=0
    while IFS= read -r chk_line; do
        local chk_trim
        chk_trim=$(printf '%s' "${chk_line}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [ -n "${chk_trim}" ] && [[ "${chk_trim}" != "${comment_char}"* ]]; then
            has_content=1
            break
        fi
    done < "${tmp_filtered}"

    # 기존 ARACHNE 섹션 처리
    local action="추가"
    if grep -qF "${begin}" "${dst}" 2>/dev/null; then
        awk -v b="${begin}" -v e="${end}" \
            'BEGIN{skip=0}
             index($0,b){skip=1; next}
             index($0,e){skip=0; next}
             !skip{print}' "${dst}" > "${tmp}"
        action="갱신"
    else
        cp "${dst}" "${tmp}"
    fi

    if [ "${has_content}" -gt 0 ]; then
        {
            printf '\n%s\n' "${begin}"
            cat "${tmp_filtered}"
            printf '%s\n' "${end}"
        } >> "${tmp}"
        if [ "${skipped}" -gt 0 ]; then
            echo "  ${action}: ${dst} (${skipped}줄 중복 제외)"
        else
            echo "  ${action}: ${dst}"
        fi
    else
        if [ "${skipped}" -gt 0 ]; then
            echo "  스킵: ${dst} (${skipped}줄 — 모두 이미 존재)"
        else
            echo "  ${action}: ${dst}"
        fi
    fi

    rm -f "${tmp_filtered}"
    mv "${tmp}" "${dst}"
}

################################################################################
# FUNCTION    : install_dotfiles
# DESCRIPTION : dotfiles/ 내용을 홈 디렉터리 파일에 ARACHNE 섹션으로 병합 설치
#               중복 줄 자동 제외, zsh 감지 시 ~/.zshrc 에도 적용
################################################################################
install_dotfiles() {
    echo "[Arachne] dotfiles 설치 시작"
    merge_dotfile "$DOTFILES_DIR/bash_profile" "$HOME/.bash_profile" "#"
    merge_dotfile "$DOTFILES_DIR/vimrc"        "$HOME/.vimrc"        '"'
    if _detect_zsh_target; then
        local zsh_src="$DOTFILES_DIR/bash_profile"
        [ -f "$DOTFILES_DIR/zshrc" ] && zsh_src="$DOTFILES_DIR/zshrc"
        merge_dotfile "${zsh_src}" "$HOME/.zshrc" "#"
    fi
    echo "[Arachne] dotfiles 설치 완료"
    echo "  적용하려면: source ~/.bash_profile  (zsh: source ~/.zshrc)"
}

################################################################################
# FUNCTION    : _export_single
# DESCRIPTION : 사용자 파일의 ARACHNE 섹션을 dotfiles/ 로 추출
# PARAMETERS  : string src          - 홈 디렉터리 내 원본 파일 경로
#               string dst          - dotfiles/ 내 대상 경로
#               string label        - 로그 표시용 파일명
#               string comment_char - 파일 형식별 주석 문자 (기본: #, vimrc: ")
################################################################################
_export_single() {
    local src="$1"
    local dst="$2"
    local label="$3"
    local comment_char="${4:-#}"

    local begin="${comment_char} === ${ARACHNE_TAG} BEGIN ==="
    local end="${comment_char} === ${ARACHNE_TAG} END ==="

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
# DESCRIPTION : ~/.bash_profile, ~/.vimrc, ~/.zshrc -> dotfiles/ 로 내보내기
################################################################################
export_dotfiles() {
    echo "[Arachne] dotfiles 내보내기 시작"
    _export_single "$HOME/.bash_profile" "$DOTFILES_DIR/bash_profile" ".bash_profile" "#"
    _export_single "$HOME/.vimrc"        "$DOTFILES_DIR/vimrc"        ".vimrc"        '"'
    if [ -f "$HOME/.zshrc" ]; then
        _export_single "$HOME/.zshrc" "$DOTFILES_DIR/zshrc" ".zshrc" "#"
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

################################################################################
# FUNCTION    : parse_target
# DESCRIPTION : 인자에서 --target 값을 파싱해 전역 ARACHNE_TARGET 에 저장·검증
# PARAMETERS  : 커맨드 뒤 나머지 인자들 ("$@")
################################################################################
ARACHNE_TARGET="all"
parse_target() {
    ARACHNE_TARGET="all"
    while [ $# -gt 0 ]; do
        case "$1" in
            --target=*) ARACHNE_TARGET="${1#--target=}" ;;
            --target)   shift || true; ARACHNE_TARGET="${1:-}" ;;
        esac
        shift || true
    done
    case "$ARACHNE_TARGET" in
        claude|gemini|codex|all) ;;
        *) echo "[ERROR] 알 수 없는 타깃: '$ARACHNE_TARGET' (claude|gemini|codex|all)" >&2; exit 1 ;;
    esac
}

################################################################################
# FUNCTION    : check_arachne
# DESCRIPTION : 3개 CLI 연결 상태 점검 — 심볼릭 댕글링·Codex 마커 stale 탐지.
#               OK/SKIP/FAIL 출력. 하나라도 FAIL 이면 종료코드 1.
################################################################################
check_arachne() {
    local fail=0
    echo "[Arachne] 연결 상태 점검"

    #---------------------------------------------------------------------------
    # Claude — ~/.claude/CLAUDE.md 가 레포 CLAUDE.md 로 해석되는가
    #---------------------------------------------------------------------------
    if [ "$(readlink -e "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null)" = "$(readlink -e "$REPO_DIR/CLAUDE.md")" ]; then
        echo "  [OK]   Claude : ~/.claude/CLAUDE.md -> 레포"
    else
        echo "  [FAIL] Claude : ~/.claude/CLAUDE.md 가 레포로 연결되지 않음 (arachne -i 필요)"
        fail=1
    fi

    #---------------------------------------------------------------------------
    # Gemini — 감지된 경우에만. ~/.gemini/GEMINI.md -> 레포 AGENTS.md
    #---------------------------------------------------------------------------
    if detect_cli gemini; then
        if [ "$(readlink -e "$HOME/.gemini/GEMINI.md" 2>/dev/null)" = "$(readlink -e "$REPO_DIR/AGENTS.md")" ]; then
            echo "  [OK]   Gemini : ~/.gemini/GEMINI.md -> AGENTS.md"
        else
            echo "  [FAIL] Gemini : 심볼릭 끊김/불일치 (arachne -i --target gemini 필요)"
            fail=1
        fi
    else
        echo "  [SKIP] Gemini : 미감지"
    fi

    #---------------------------------------------------------------------------
    # Codex — 감지된 경우에만. 마커 존재 + 섹션 본문이 현재 AGENTS.md 와 일치
    #---------------------------------------------------------------------------
    if detect_cli codex; then
        local codex_file="$HOME/.codex/AGENTS.md"
        local begin="<!-- === ${ARACHNE_TAG} BEGIN === -->"
        local end="<!-- === ${ARACHNE_TAG} END === -->"
        if [ ! -f "$codex_file" ]; then
            echo "  [FAIL] Codex  : ~/.codex/AGENTS.md 없음 (arachne -i --target codex 필요)"
            fail=1
        elif ! grep -qF "$begin" "$codex_file"; then
            echo "  [FAIL] Codex  : ARACHNE 마커 없음 (arachne -i --target codex 필요)"
            fail=1
        else
            local extracted
            extracted=$(awk -v b="$begin" -v e="$end" \
                'index($0,b){s=1;next} index($0,e){s=0;next} s' "$codex_file")
            if [ "$extracted" = "$(cat "$REPO_DIR/AGENTS.md")" ]; then
                echo "  [OK]   Codex  : ~/.codex/AGENTS.md (AGENTS.md 최신)"
            else
                echo "  [FAIL] Codex  : 섹션이 AGENTS.md 와 다름 — stale (arachne -i --target codex 재실행)"
                fail=1
            fi
        fi
    else
        echo "  [SKIP] Codex  : 미감지"
    fi

    if [ "$fail" -eq 0 ]; then
        echo "[Arachne] 모든 연결 정상"
    else
        echo "[Arachne] 연결 문제 발견 — 위 안내대로 재설치 필요" >&2
    fi
    return "$fail"
}

case "${1:-}" in
    "")
        if [ "$ENTRY_NAME" = "install.sh" ]; then
            install
        else
            usage
        fi
        ;;
    "-h"|--help|help)                         usage ;;
    -i|--install|install)                     shift; parse_target "$@"; install ;;
    -u|--update|update)                       shift; parse_target "$@"; update_arachne ;;
    -c|--check|check)                         check_arachne ;;
    -s|--session|session)                     run_session ;;
    -e|--export-settings|export-settings)     export_settings ;;
    -d|--export-dotfiles|export-dotfiles)     export_dotfiles ;;
    -v|--version)                             show_version ;;
    *)                                        echo "[ERROR] 알 수 없는 옵션: $1" >&2; usage >&2; exit 1 ;;
esac
