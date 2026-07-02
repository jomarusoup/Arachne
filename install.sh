#!/bin/bash
################################################################################
# FILE NAME   : install.sh
# DESCRIPTION : Arachne 멀티 CLI 설정 설치 스크립트
# DATA        : 2026-05-05
# Modification: 2026-07-01
################################################################################

set -euo pipefail

################################################################################
# FUNCTION    : ResolvePath
# DESCRIPTION : GNU readlink -f 없이 파일·심볼릭 링크의 절대 경로 계산
# PARAMETERS  : string path - 해석할 파일 경로
# RETURNED    : 절대 경로
################################################################################
ResolvePath() {
    local path="$1"
    local dir
    local target

    while [ -L "$path" ]; do
        dir=$(cd -P "$(dirname "$path")" && pwd)
        target=$(readlink "$path")
        case "$target" in
            /*) path="$target" ;;
            *)  path="$dir/$target" ;;
        esac
    done

    dir=$(cd -P "$(dirname "$path")" && pwd)
    printf '%s/%s\n' "$dir" "$(basename "$path")"
}

# 심볼릭 링크(arachne -> install.sh)를 해석해야 실제 레포 경로를 얻는다.
# 미해석 시 arachne 커맨드 실행 위치(~/.local/bin)가 잡혀 update/session 이 실패한다.
REPO_SCRIPT="$(ResolvePath "$0")"
REPO_DIR="$(dirname "$REPO_SCRIPT")"
CLAUDE_DIR="$HOME/.claude"
DOTFILES_DIR="$REPO_DIR/dotfiles"
LOCAL_BIN="$HOME/.local/bin"
ARACHNE_TAG="ARACHNE"
PROG="arachne"
ARACHNE_SEPARATOR="==============================================================================="
# 버전 정본은 레포 루트 VERSION 파일 (F-07: 설치기별 하드코딩 드리프트 방지)
ARACHNE_VERSION="$(cat "$REPO_DIR/VERSION" 2>/dev/null | tr -d '[:space:]')"
ARACHNE_VERSION="${ARACHNE_VERSION:-unknown}"
ENTRY_NAME="$(basename "$0")"

################################################################################
# FUNCTION    : arachne_log
# DESCRIPTION : Arachne 스크립트의 사용자 출력 형식을 통일
# PARAMETERS  : string level   - STEP|RUN|SKIP|DONE|WARN|ERROR
#               string message - 출력할 메시지
################################################################################
arachne_log() {
    local level="$1"
    local message="$2"

    case "$level" in
        WARN|ERROR) printf '[Arachne][%s] %s\n' "$level" "$message" >&2 ;;
        *)          printf '[Arachne][%s] %s\n' "$level" "$message" ;;
    esac
}

################################################################################
# FUNCTION    : arachne_section
# DESCRIPTION : 긴 설치·업데이트 로그의 주요 단계 경계를 배너로 표시
# PARAMETERS  : string message - 섹션 제목
################################################################################
arachne_section() {
    local message="$1"

    printf '%s\n' "$ARACHNE_SEPARATOR"
    printf '[Arachne] %s\n' "$message"
    printf '%s\n' "$ARACHNE_SEPARATOR"
}

# "스크립트명:커맨드명" 형식 — git pull 시 심볼릭 링크라 자동 업데이트됨
# 위임 래퍼는 짧은 별칭(gtask/ctask)과 명시적 이름(gemini-task/codex-task) 둘 다 등록
BIN_TARGETS=(
    "install.sh:arachne"
    "tmux.sh:tws"
    "gemini-task.sh:gtask"
    "gemini-task.sh:gemini-task"
    "codex-task.sh:ctask"
    "codex-task.sh:codex-task"
    "arachne-task.sh:atask"
    "arachne-task.sh:arachne-task"
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
    echo "  -u, --update           대화형: Arachne/Understand/codegraph 중 선택 갱신"
    echo "      --target T          설치 대상 CLI: claude|gemini|codex|copilot|all (기본 all)"
    echo "                          (-i/-u 와 함께 사용. 미감지 CLI는 자동 스킵)"
    echo "      --with-ua           -i/-u 와 함께: Understand-Anything 만 멱등 설정"
    echo "      --with-extras       -i/-u 와 함께: 확장 도구(UA·taste-skill·codegraph) 멱등 설정"
    echo "      --extras            확장 도구 통합 설치만 단독 실행 (대화형 선택 메뉴)"
    echo "  -c, --check            CLI 연결 상태 점검 (심볼릭 댕글링·병합본 stale 탐지)"
    echo "  -n, --new P [DIR]      신규 프로젝트 스캐폴딩 (README + AGENTS/CLAUDE 지침 스텁"
    echo "                         + docs/{issue,idea,task,template})"
    echo "                         DIR 생략 시 현재 디렉터리. --no-git 으로 git init 생략"
    echo "                         --profile minimal|python|web|python-web (기본 minimal)"
    echo "      --init-ci [DIR]    프로젝트 검증 runner + GitHub Actions workflow 생성/갱신"
    echo "                         --profile minimal|python|web|python-web (기본 minimal)"
    echo "      --project-check [DIR]"
    echo "                         프로젝트의 .arachne/verify.sh 실행 (기본 현재 디렉터리)"
    echo "      feedback new|list|submit"
    echo "                         Arachne 개선 피드백 초안 작성·목록·GitHub Issue 제출"
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
# FUNCTION    : update_arachne_core
# DESCRIPTION : git pull 후 최신 상태로 재설치 (Arachne 본체)
################################################################################
update_arachne_core() {
    arachne_section "업데이트 시작 (git pull)"
    cd "$REPO_DIR" || { arachne_log "ERROR" "update: 레포 디렉터리 진입 실패 (repo=$REPO_DIR)"; exit 1; }

    #---------------------------------------------------------------------------
    # #33: pull·재설치 전에 레포 상태를 검증한다. 비-main 브랜치는 경고하고,
    #      커밋되지 않은 변경(dirty)이 있으면 pull 충돌·재설치 손실 위험이 있어 중단한다.
    #      ARACHNE_FORCE=1 로 강제 진행 가능.
    #---------------------------------------------------------------------------
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    if [ "$branch" != "main" ]; then
        arachne_log "WARN" "update: 현재 브랜치가 main 이 아님 (branch=$branch)"
    fi
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        arachne_log "ERROR" "update: 작업트리에 커밋되지 않은 변경이 있음 — git pull 충돌·재설치 손실 위험"
        arachne_log "ERROR" "update: 커밋/스태시 후 재실행 또는 ARACHNE_FORCE=1 arachne -u 로 강제"
        if [ "${ARACHNE_FORCE:-0}" != "1" ]; then
            exit 1
        fi
        arachne_log "WARN" "update: ARACHNE_FORCE=1 — dirty 검증 무시"
    fi

    arachne_log "RUN" "git pull"
    git pull
    arachne_section "최신 소스 기반 재설치 진행"
    install
}

################################################################################
# FUNCTION    : run_update_understand
# DESCRIPTION : Understand-Anything 확장 도구만 갱신
################################################################################
run_update_understand() {
    case "${ARACHNE_TARGET:-all}" in
        all|claude) ;;
        *)
            arachne_log "SKIP" "extras: target=${ARACHNE_TARGET:-all} — Claude 플러그인 대상이 아님"
            return 0
            ;;
    esac

    arachne_section "Understand-Anything 확장 도구 갱신 시작"
    run_extras --ua --update
    arachne_section "Understand-Anything 확장 도구 갱신 완료"
}

################################################################################
# FUNCTION    : run_update_codegraph
# DESCRIPTION : codegraph CLI 만 갱신
################################################################################
run_update_codegraph() {
    arachne_section "codegraph 확장 도구 갱신 시작"
    run_extras --codegraph --update
    arachne_section "codegraph 확장 도구 갱신 완료"
}

################################################################################
# FUNCTION    : update_mark
# DESCRIPTION : 업데이트 선택 메뉴의 체크박스 상태 문자열 반환
# PARAMETERS  : integer enabled - 1이면 선택됨, 0이면 선택 안 됨
################################################################################
update_mark() {
    if [ "$1" -eq 1 ]; then
        printf 'x'
    else
        printf ' '
    fi
}

################################################################################
# FUNCTION    : update_interactive_menu
# DESCRIPTION : -u 기본 대화형 체크박스 메뉴
################################################################################
update_interactive_menu() {
    local want_core=1
    local want_ua=0
    local want_cg=0
    local reply
    local item

    while true; do
        arachne_section "업데이트 항목 선택"
        printf '  [%s] 1) Arachne 최신 소스 업데이트 + 재설치\n' "$(update_mark "$want_core")"
        printf '  [%s] 2) Understand-Anything 플러그인 갱신\n' "$(update_mark "$want_ua")"
        printf '  [%s] 3) codegraph CLI 갱신\n' "$(update_mark "$want_cg")"
        printf '\n'
        read -r -p "[Arachne] 번호로 토글, Enter=선택 실행, a=전체 선택, n=전체 해제, q=취소: " reply || true

        case "$reply" in
            "")
                break
                ;;
            a|A)
                want_core=1
                want_ua=1
                want_cg=1
                ;;
            n|N)
                want_core=0
                want_ua=0
                want_cg=0
                ;;
            q|Q)
                arachne_log "SKIP" "update: 사용자가 취소함"
                return 0
                ;;
            *)
                for item in $reply; do
                    case "$item" in
                        1) [ "$want_core" -eq 1 ] && want_core=0 || want_core=1 ;;
                        2) [ "$want_ua" -eq 1 ] && want_ua=0 || want_ua=1 ;;
                        3) [ "$want_cg" -eq 1 ] && want_cg=0 || want_cg=1 ;;
                        *) arachne_log "WARN" "update: 알 수 없는 선택 '$item' 무시" ;;
                    esac
                done
                ;;
        esac
    done

    if [ "$want_core" -eq 0 ] && [ "$want_ua" -eq 0 ] && [ "$want_cg" -eq 0 ]; then
        arachne_log "SKIP" "update: 선택된 항목 없음"
        return 0
    fi

    [ "$want_core" -eq 1 ] && update_arachne_core
    [ "$want_ua" -eq 1 ] && run_update_understand
    [ "$want_cg" -eq 1 ] && run_update_codegraph
}

################################################################################
# FUNCTION    : update_arachne
# DESCRIPTION : -u 진입점. 대화형이면 체크박스 선택, 비대화형·플래그 지정은 기존 흐름 유지
################################################################################
update_arachne() {
    if [ -t 0 ] && [ "${ARACHNE_WITH_UA:-0}" -eq 0 ] && [ "${ARACHNE_WITH_EXTRAS:-0}" -eq 0 ]; then
        update_interactive_menu
        return 0
    fi

    update_arachne_core
    # -u 도 -i 와 동일하게 확장 도구 분기. --with-extras 면 멱등 동기화,
    # 미지정 대화형이면 질의(자동 강제 X — noarg-safe 원칙 유지).
    # update 모드 — 선택된 확장 도구의 클론·플러그인·CLI 를 git pull/plugin update 로 갱신.
    maybe_run_extras --update
}

################################################################################
# FUNCTION    : run_session
# DESCRIPTION : tmux 워크스페이스 매니저 실행 (tws 래퍼)
################################################################################
run_session() {
    local tmux_script="$REPO_DIR/tmux.sh"
    arachne_section "tmux 워크스페이스 실행"

    if [ -f "$tmux_script" ]; then
        exec "$tmux_script"
    else
        arachne_log "ERROR" "tmux.sh 파일을 찾을 수 없습니다: $tmux_script"
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
    arachne_section "bin 등록 시작: $LOCAL_BIN"
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

    arachne_section "bin 등록 완료"

    # F-10: 부분 문자열 grep 은 유사 경로(~/.local/binx 등)에 오탐 — 정확한 항목 매칭
    case ":$PATH:" in
        *":$LOCAL_BIN:"*) ;;
        *)
            echo "  주의: $LOCAL_BIN 이 PATH에 없습니다. ~/.bash_profile에 추가하세요:"
            echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
            ;;
    esac
}

################################################################################
# FUNCTION    : install_claude
# DESCRIPTION : Claude Code 타깃 설치 — 심볼릭 링크 + settings.json 생성
#               (rules/ 가 ~/.claude/rules/ 로 링크돼 네이티브 자동 로드됨)
################################################################################
install_claude() {
    arachne_section "Claude 설치 시작: $REPO_DIR -> $CLAUDE_DIR"
    mkdir -p "$CLAUDE_DIR"

    # local 선언 — 동적 스코프에서 호출자(install)의 변수를 덮어쓰지 않도록 한다
    local link_target
    for link_target in "${SYMLINK_TARGETS[@]}"; do
        backup_and_link "$REPO_DIR/$link_target" "$CLAUDE_DIR/$link_target"
    done

    # settings.json: __HOME__ 치환 후 생성 (심볼릭 링크 아님)
    # #28: 기존 settings.json 이 템플릿 생성본과 다르면(=사용자 수정) 조용히 덮어쓰지 않고
    #      경고한다. 직전 값은 .bak 에 보존하되, 보존하려면 arachne -e 로 템플릿에 반영하도록 안내.
    local settings_dst="$CLAUDE_DIR/settings.json"
    local new_settings
    new_settings=$(sed "s|__HOME__|$HOME|g" "$REPO_DIR/settings.template.json")
    if [ -e "$settings_dst" ] && [ ! -L "$settings_dst" ]; then
        cp "$settings_dst" "$settings_dst.bak"
        echo "  백업: $settings_dst -> $settings_dst.bak"
        if ! printf '%s\n' "$new_settings" | diff -q - "$settings_dst" >/dev/null 2>&1; then
            echo "  [주의] 기존 settings.json 이 템플릿 생성본과 다릅니다 — 사용자 수정이 교체됩니다." >&2
            echo "         보존하려면 먼저 'arachne -e' 로 변경을 템플릿에 반영하세요 (직전 값은 .bak 에 보존)." >&2
        fi
    fi
    printf '%s\n' "$new_settings" > "$settings_dst"
    echo "  생성: $settings_dst (from settings.template.json)"

    arachne_section "Claude 설치 완료"
}

################################################################################
# FUNCTION    : install_gemini
# DESCRIPTION : Gemini CLI 타깃 설치 — AGENTS.md(SSOT)를 ~/.gemini/GEMINI.md 로 심볼릭
#               심볼릭이라 AGENTS.md 수정이 재설치 없이 즉시 반영됨
################################################################################
install_gemini() {
    local gemini_dir="$HOME/.gemini"
    arachne_section "Gemini 설치 시작: AGENTS.md -> $gemini_dir/GEMINI.md"
    mkdir -p "$gemini_dir"
    backup_and_link "$REPO_DIR/AGENTS.md" "$gemini_dir/GEMINI.md"
    arachne_section "Gemini 설치 완료"
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
    arachne_section "Codex 설치 시작: AGENTS.md -> $codex_dir/AGENTS.md"
    mkdir -p "$codex_dir"
    merge_dotfile "$REPO_DIR/AGENTS.md" "$codex_dir/AGENTS.md" "<!--" " -->"
    arachne_section "Codex 설치 완료"
}

################################################################################
# FUNCTION    : install_copilot
# DESCRIPTION : GitHub Copilot 타깃 설치.
#               Copilot CLI 전역 지침은 사용자 내용을 보존하는 마커 병합으로,
#               VS Code 사용자 지침은 Arachne 전용 .instructions.md 로 생성한다.
#               일반 파일만 사용해 macOS·Linux·WSL·Git Bash에서 링크 권한 없이 동작한다.
################################################################################
install_copilot() {
    local copilot_dir="$HOME/.copilot"
    local instructions_dir="$copilot_dir/instructions"
    local vscode_file="$instructions_dir/arachne.instructions.md"
    local tmp

    arachne_section "GitHub Copilot 설치 시작: AGENTS.md -> $copilot_dir"
    mkdir -p "$instructions_dir"

    merge_dotfile \
        "$REPO_DIR/AGENTS.md" \
        "$copilot_dir/copilot-instructions.md" \
        "<!--" \
        " -->"

    tmp=$(mktemp)
    {
        printf '%s\n' "---"
        printf '%s\n' "name: Arachne Shared Rules"
        printf '%s\n' "description: Arachne AGENTS.md shared coding rules"
        printf '%s\n' "applyTo: \"**\""
        printf '%s\n\n' "---"
        printf '%s\n' "<!-- === ${ARACHNE_TAG} BEGIN === -->"
        cat "$REPO_DIR/AGENTS.md"
        printf '%s\n' "<!-- === ${ARACHNE_TAG} END === -->"
    } > "$tmp"
    mv "$tmp" "$vscode_file"

    echo "  생성: $vscode_file"
    arachne_section "GitHub Copilot 설치 완료"
}

################################################################################
# FUNCTION    : detect_cli
# DESCRIPTION : 대상 CLI 설치 여부 검사 (홈 디렉터리 또는 바이너리 존재)
# PARAMETERS  : string cli - gemini | codex | copilot
# RETURNED    : 0(감지) / 1(미감지)
################################################################################
detect_cli() {
    local cli="$1"
    case "$cli" in
        gemini) [ -d "$HOME/.gemini" ] || command -v gemini >/dev/null 2>&1 ;;
        codex)  [ -d "$HOME/.codex" ]  || command -v codex  >/dev/null 2>&1 ;;
        copilot) [ -d "$HOME/.copilot" ] || command -v copilot >/dev/null 2>&1 ;;
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
    local target="${ARACHNE_TARGET:-all}"
    arachne_section "설치/재설치 시작 (target=$target)"
    case "$target" in
        claude) install_claude ;;
        gemini) install_gemini ;;
        codex)  install_codex ;;
        copilot) install_copilot ;;
        all)
            install_claude
            if detect_cli gemini; then
                install_gemini
            else
                arachne_log "SKIP" "install: Gemini CLI 미감지 — target=gemini"
            fi
            if detect_cli codex; then
                install_codex
            else
                arachne_log "SKIP" "install: Codex CLI 미감지 — target=codex"
            fi
            if detect_cli copilot; then
                install_copilot
            else
                arachne_log "SKIP" "install: GitHub Copilot 미감지 — target=copilot"
            fi
            ;;
    esac

    #---------------------------------------------------------------------------
    # #34: 공통 설치(dotfiles 병합 + 전체 bin 등록)는 전체 설치(all)에서만 수행.
    # 특정 CLI 타깃 지정 시 공통 인프라(~/.bash_profile·~/.local/bin)를 건드리지 않는다.
    #---------------------------------------------------------------------------
    if [ "$target" = "all" ]; then
        install_shared
    else
        arachne_log "SKIP" "install: 타깃 '$target' — 공통 설치(dotfiles·bin) 생략 (전체 설치는 'arachne -i')"
    fi
    arachne_log "DONE" "install: target=$target"
}

################################################################################
# FUNCTION    : run_extras
# DESCRIPTION : 확장 도구 통합 설치 스크립트(setup-extras.sh) 실행
#               UA·taste-skill 로컬 마켓플레이스 + codegraph CLI(+래퍼)
# PARAMETERS  : 나머지 인자 - setup-extras.sh 로 그대로 전달
################################################################################
run_extras() {
    local extras="${ARACHNE_EXTRAS_SCRIPT:-$REPO_DIR/setup-extras.sh}"
    if [ ! -f "$extras" ]; then
        arachne_log "SKIP" "extras: setup 스크립트 없음 — path=$extras"
        return 0
    fi
    arachne_log "RUN" "extras: bash $extras $*"
    bash "$extras" "$@"
}

################################################################################
# FUNCTION    : maybe_run_extras
# DESCRIPTION : -i/-u 설치 후 확장 도구 설정 분기. Claude 타깃(all|claude)에서만 동작.
#               --with-ua 지정 시 Understand-Anything 만 실행한다.
#               --with-extras 지정 시 실행(비TTY는 --all), 미지정 시 대화형일 때만
#               설치 여부를 질의한다(무인자=help 원칙 유지 — 비대화형은 조용히 스킵).
# PARAMETERS  : 나머지 인자 - setup-extras.sh 로 전달 (예: --update)
################################################################################
maybe_run_extras() {
    local pass_args=("$@")
    local action="설정"

    case " ${pass_args[*]-} " in *" --update "*) action="갱신" ;; esac

    case "${ARACHNE_TARGET:-all}" in
        all|claude) ;;
        *)
            arachne_log "SKIP" "extras: target=${ARACHNE_TARGET:-all} — Claude 플러그인 대상이 아님"
            return 0
            ;;
    esac

    if [ "${ARACHNE_WITH_UA:-0}" -eq 1 ]; then
        arachne_section "Understand-Anything 확장 도구 ${action} 시작"
        run_extras --ua ${pass_args[@]+"${pass_args[@]}"}
        arachne_section "Understand-Anything 확장 도구 ${action} 완료"
        return 0
    fi

    if [ "${ARACHNE_WITH_EXTRAS:-0}" -eq 1 ]; then
        arachne_section "전체 확장 도구 ${action} 시작"
        if [ -t 0 ]; then run_extras ${pass_args[@]+"${pass_args[@]}"}; else run_extras --all ${pass_args[@]+"${pass_args[@]}"}; fi
        arachne_section "전체 확장 도구 ${action} 완료"
        return 0
    fi

    if [ -t 0 ]; then
        local reply
        arachne_section "확장 도구 ${action} 선택"
        read -r -p "[Arachne] 확장 도구(Understand-Anything·taste-skill·codegraph)도 ${action}할까요? [y/N] " reply || true
        case "$reply" in
            [yY]|[yY][eE][sS]) run_extras ${pass_args[@]+"${pass_args[@]}"}; arachne_section "확장 도구 ${action} 완료" ;;
            *) arachne_log "SKIP" "extras: ${action} 건너뜀 (나중에 'arachne --extras' 로 가능)" ;;
        esac
    fi
}

################################################################################
# FUNCTION    : merge_dotfile
# DESCRIPTION : dotfiles/ 내용을 사용자 파일에 ARACHNE 섹션으로 병합
#               기존 파일 내용 유지, 섹션이 있으면 갱신 / 없으면 끝에 추가
#               중복 감지: 사용자 영역에 이미 있는 export/alias 줄만 섹션에서 제외
#               (블록 구조 줄까지 제외하면 병합본 문법이 깨지므로 범위 한정)
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
        link_target=$(ResolvePath "${dst}" 2>/dev/null || true)
        rm "${dst}"

        if [ "${link_target}" = "$(ResolvePath "${src}")" ]; then
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
        # 중복 제거는 한 줄로 의미가 완결되는 export/alias 만 대상으로 한다.
        # 임의 줄까지 제외하면 사용자 파일의 '{'·'}' 같은 블록 구조 줄과 우연히
        # 일치한 함수 본문이 빠져 병합본 문법이 깨진다 (CHANGELOG-AUDIT A-01).
        case "${trimmed}" in
            export\ *|alias\ *)
                if printf '%s\n' "${user_content}" | grep -qxF "${trimmed}" 2>/dev/null; then
                    skipped=$((skipped + 1))
                    continue
                fi
                ;;
        esac
        printf '%s\n' "${line}" >> "${tmp_filtered}"
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
    arachne_section "dotfiles 설치 시작"
    merge_dotfile "$DOTFILES_DIR/bash_profile" "$HOME/.bash_profile" "#"
    merge_dotfile "$DOTFILES_DIR/vimrc"        "$HOME/.vimrc"        '"'
    if _detect_zsh_target; then
        local zsh_src="$DOTFILES_DIR/bash_profile"
        [ -f "$DOTFILES_DIR/zshrc" ] && zsh_src="$DOTFILES_DIR/zshrc"
        merge_dotfile "${zsh_src}" "$HOME/.zshrc" "#"
    fi
    arachne_section "dotfiles 설치 완료"
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
    arachne_section "dotfiles 내보내기 시작"
    _export_single "$HOME/.bash_profile" "$DOTFILES_DIR/bash_profile" ".bash_profile" "#"
    _export_single "$HOME/.vimrc"        "$DOTFILES_DIR/vimrc"        ".vimrc"        '"'
    if [ -f "$HOME/.zshrc" ]; then
        _export_single "$HOME/.zshrc" "$DOTFILES_DIR/zshrc" ".zshrc" "#"
    fi
    arachne_section "dotfiles 내보내기 완료"
    echo "  커밋하려면: cd $REPO_DIR && git add dotfiles/ && git commit -m 'chore: update dotfiles'"
}

################################################################################
# FUNCTION    : export_settings
# DESCRIPTION : ~/.claude/settings.json -> settings.template.json 내보내기
################################################################################
export_settings() {
    local settings_src="$CLAUDE_DIR/settings.json"
    local template_dst="$REPO_DIR/settings.template.json"

    arachne_section "settings.template.json 내보내기 시작"
    if [ ! -f "$settings_src" ]; then
        arachne_log "ERROR" "$settings_src 파일이 없습니다."
        exit 1
    fi

    sed "s|$HOME|__HOME__|g" "$settings_src" > "$template_dst"
    arachne_section "settings.template.json 갱신 완료"
    echo "  커밋하려면: cd $REPO_DIR && git add settings.template.json && git commit -m 'chore: update settings template'"
}

################################################################################
# FUNCTION    : parse_target
# DESCRIPTION : 인자에서 --target 값을 파싱해 전역 ARACHNE_TARGET 에 저장·검증
# PARAMETERS  : 커맨드 뒤 나머지 인자들 ("$@")
################################################################################
ARACHNE_TARGET="all"
ARACHNE_WITH_UA=0
ARACHNE_WITH_EXTRAS=0
parse_target() {
    ARACHNE_TARGET="all"
    ARACHNE_WITH_UA=0
    ARACHNE_WITH_EXTRAS=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --target=*)    ARACHNE_TARGET="${1#--target=}" ;;
            --target)      shift || true; ARACHNE_TARGET="${1:-}" ;;
            --with-ua)     ARACHNE_WITH_UA=1 ;;
            --with-extras) ARACHNE_WITH_EXTRAS=1 ;;
        esac
        shift || true
    done
    case "$ARACHNE_TARGET" in
        claude|gemini|codex|copilot|all) ;;
        *) arachne_log "ERROR" "알 수 없는 타깃: '$ARACHNE_TARGET' (claude|gemini|codex|copilot|all)"; exit 1 ;;
    esac
}

################################################################################
# FUNCTION    : check_arachne
# DESCRIPTION : CLI 연결 상태 점검 — 심볼릭 댕글링·병합 파일 stale 탐지.
#               OK/SKIP/FAIL 출력. 하나라도 FAIL 이면 종료코드 1.
################################################################################
check_arachne() {
    local fail=0
    arachne_section "연결 상태 점검 시작"

    #---------------------------------------------------------------------------
    # Claude — SYMLINK_TARGETS 전체가 레포로 해석되고 settings.json 이 존재하는가
    # (F-08: CLAUDE.md 하나만 보면 rules/hooks 등 부분 끊김을 놓친다)
    #---------------------------------------------------------------------------
    local claude_fail=0
    local claude_target
    for claude_target in "${SYMLINK_TARGETS[@]}"; do
        if [ ! -e "$CLAUDE_DIR/$claude_target" ] \
            || [ "$(ResolvePath "$CLAUDE_DIR/$claude_target")" != "$(ResolvePath "$REPO_DIR/$claude_target")" ]; then
            echo "  [FAIL] Claude : ~/.claude/$claude_target 가 레포로 연결되지 않음 (arachne -i 필요)"
            claude_fail=1
        fi
    done
    if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
        echo "  [FAIL] Claude : ~/.claude/settings.json 없음 (arachne -i 필요)"
        claude_fail=1
    fi
    if [ "$claude_fail" -eq 0 ]; then
        echo "  [OK]   Claude : ~/.claude 링크 ${#SYMLINK_TARGETS[@]}개 + settings.json -> 레포"
    else
        fail=1
    fi

    #---------------------------------------------------------------------------
    # Gemini — 감지된 경우에만. ~/.gemini/GEMINI.md -> 레포 AGENTS.md
    #---------------------------------------------------------------------------
    if detect_cli gemini; then
        if [ -e "$HOME/.gemini/GEMINI.md" ] \
            && [ "$(ResolvePath "$HOME/.gemini/GEMINI.md")" = "$(ResolvePath "$REPO_DIR/AGENTS.md")" ]; then
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

    #---------------------------------------------------------------------------
    # GitHub Copilot — CLI 전역 지침과 VS Code 사용자 지침이 현재 AGENTS.md 인가
    #---------------------------------------------------------------------------
    if detect_cli copilot; then
        local copilot_cli_file="$HOME/.copilot/copilot-instructions.md"
        local copilot_vscode_file="$HOME/.copilot/instructions/arachne.instructions.md"
        local begin="<!-- === ${ARACHNE_TAG} BEGIN === -->"
        local end="<!-- === ${ARACHNE_TAG} END === -->"
        local cli_extracted=""
        local vscode_extracted=""

        if [ -f "$copilot_cli_file" ]; then
            cli_extracted=$(awk -v b="$begin" -v e="$end" \
                'index($0,b){s=1;next} index($0,e){s=0;next} s' "$copilot_cli_file")
        fi
        if [ -f "$copilot_vscode_file" ]; then
            vscode_extracted=$(awk -v b="$begin" -v e="$end" \
                'index($0,b){s=1;next} index($0,e){s=0;next} s' "$copilot_vscode_file")
        fi

        if [ "$cli_extracted" = "$(cat "$REPO_DIR/AGENTS.md")" ] \
            && [ "$vscode_extracted" = "$(cat "$REPO_DIR/AGENTS.md")" ]; then
            echo "  [OK]   Copilot: CLI + VS Code 사용자 지침 최신"
        else
            echo "  [FAIL] Copilot: 지침 없음/불일치 (arachne -i --target copilot 필요)"
            fail=1
        fi
    else
        echo "  [SKIP] Copilot: 미감지"
    fi

    if [ "$fail" -eq 0 ]; then
        arachne_section "연결 상태 점검 완료: 모든 연결 정상"
    else
        arachne_section "연결 상태 점검 완료: 문제 발견"
        arachne_log "ERROR" "연결 문제 발견 — 위 안내대로 재설치 필요"
    fi
    return "$fail"
}

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

case "${1:-}" in
    "")
        if [ "$ENTRY_NAME" = "install.sh" ]; then
            install
        else
            usage
        fi
        ;;
    "-h"|--help|help)                         usage ;;
    -i|--install|install)                     shift; parse_target "$@"; install; maybe_run_extras ;;
    -u|--update|update)                       shift; parse_target "$@"; update_arachne ;;
    --extras|extras)                          shift; run_extras "$@" ;;
    -c|--check|check)                         check_arachne ;;
    -n|--new|new)                             shift; new_project "$@" ;;
    --init-ci|init-ci)                        shift; init_project_ci "$@" ;;
    --project-check|project-check)            shift; check_project "${1:-$PWD}" ;;
    feedback)                                 shift; feedback_command "$@" ;;
    -s|--session|session)                     run_session ;;
    -e|--export-settings|export-settings)     export_settings ;;
    -d|--export-dotfiles|export-dotfiles)     export_dotfiles ;;
    -v|--version)                             show_version ;;
    *)                                        arachne_log "ERROR" "알 수 없는 옵션: $1"; usage >&2; exit 1 ;;
esac
