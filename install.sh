#!/bin/bash
################################################################################
# FILE NAME   : install.sh
# DESCRIPTION : Arachne 멀티 CLI 설정 설치 스크립트
# DATA        : 2026-05-05
# Modification: 2026-06-12
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
    echo "  -u, --update           git pull 후 최신 상태로 재설치"
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
    arachne_log "STEP" "update: git pull 후 재설치 시작 (repo=$REPO_DIR)"
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
    arachne_log "STEP" "install: 최신 소스 기반 재설치 진행"
    install
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
    echo "[Arachne] Claude 설치 시작: $REPO_DIR -> $CLAUDE_DIR"
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

    echo "[Arachne] GitHub Copilot 설치 시작: AGENTS.md -> $copilot_dir"
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
    echo "[Arachne] GitHub Copilot 설치 완료"
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
    arachne_log "STEP" "install: target=$target repo=$REPO_DIR"
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

    case "${ARACHNE_TARGET:-all}" in
        all|claude) ;;
        *)
            arachne_log "SKIP" "extras: target=${ARACHNE_TARGET:-all} — Claude 플러그인 대상이 아님"
            return 0
            ;;
    esac

    if [ "${ARACHNE_WITH_UA:-0}" -eq 1 ]; then
        arachne_log "STEP" "extras: Understand-Anything 단독 설정 시작"
        run_extras --ua ${pass_args[@]+"${pass_args[@]}"}
        arachne_log "DONE" "extras: Understand-Anything 단독 설정 완료"
        return 0
    fi

    if [ "${ARACHNE_WITH_EXTRAS:-0}" -eq 1 ]; then
        arachne_log "STEP" "extras: 전체 확장 도구 설정 시작"
        if [ -t 0 ]; then run_extras ${pass_args[@]+"${pass_args[@]}"}; else run_extras --all ${pass_args[@]+"${pass_args[@]}"}; fi
        arachne_log "DONE" "extras: 전체 확장 도구 설정 완료"
        return 0
    fi

    if [ -t 0 ]; then
        local reply
        local action="설정"
        case " ${pass_args[*]-} " in *" --update "*) action="갱신" ;; esac
        read -r -p "[Arachne] 확장 도구(Understand-Anything·taste-skill·codegraph)도 ${action}할까요? [y/N] " reply || true
        case "$reply" in
            [yY]|[yY][eE][sS]) run_extras ${pass_args[@]+"${pass_args[@]}"} ;;
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
        *) echo "[ERROR] 알 수 없는 타깃: '$ARACHNE_TARGET' (claude|gemini|codex|copilot|all)" >&2; exit 1 ;;
    esac
}

################################################################################
# FUNCTION    : check_arachne
# DESCRIPTION : CLI 연결 상태 점검 — 심볼릭 댕글링·병합 파일 stale 탐지.
#               OK/SKIP/FAIL 출력. 하나라도 FAIL 이면 종료코드 1.
################################################################################
check_arachne() {
    local fail=0
    echo "[Arachne] 연결 상태 점검"

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
        echo "[Arachne] 모든 연결 정상"
    else
        echo "[Arachne] 연결 문제 발견 — 위 안내대로 재설치 필요" >&2
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
            echo "[ERROR] 알 수 없는 profile: '$profile' (minimal|python|web|python-web)" >&2
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
                    echo "[ERROR] --profile 값이 필요합니다" >&2
                    return 1
                }
                profile="$1"
                ;;
            -*) echo "[ERROR] 알 수 없는 옵션: $1" >&2; return 1 ;;
            *) positional+=("$1") ;;
        esac
        shift
    done

    if [ "${#positional[@]}" -gt 1 ]; then
        echo "[ERROR] 프로젝트 디렉터리는 하나만 지정할 수 있습니다" >&2
        return 1
    fi
    validate_project_profile "$profile" || return 1

    local project_dir="${positional[0]:-$PWD}"
    local verify_tmpl="$REPO_DIR/templates/project/verify.sh"
    local commands_tmpl="$REPO_DIR/templates/project/profiles/$profile/commands"
    local workflow_tmpl="$REPO_DIR/templates/project/arachne.yml"
    local managed_path
    local project_abs

    if [ ! -d "$project_dir" ]; then
        echo "[ERROR] 프로젝트 디렉터리가 없습니다: $project_dir" >&2
        return 1
    fi
    if [ ! -f "$verify_tmpl" ] || [ ! -f "$commands_tmpl" ] \
        || [ ! -f "$workflow_tmpl" ]; then
        echo "[ERROR] 프로젝트 CI 템플릿이 없습니다: $REPO_DIR/templates/project" >&2
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
            echo "[ERROR] 프로젝트 CI 관리 경로가 심볼릭 링크입니다: $managed_path" >&2
            return 1
        fi
    done

    mkdir -p "$project_abs/.arachne" "$project_abs/.github/workflows"
    cp "$verify_tmpl" "$project_abs/.arachne/verify.sh"
    chmod +x "$project_abs/.arachne/verify.sh"
    cp "$workflow_tmpl" "$project_abs/.github/workflows/arachne.yml"
    printf '%s\n' "$profile" > "$project_abs/.arachne/profile"

    if [ ! -f "$project_abs/.arachne/commands" ]; then
        cp "$commands_tmpl" "$project_abs/.arachne/commands"
        echo "  생성: .arachne/commands"
    else
        echo "  보존: .arachne/commands"
    fi

    echo "[Arachne] 프로젝트 CI 초기화 완료: $project_abs"
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

    if [ ! -d "$project_dir" ]; then
        echo "[ERROR] 프로젝트 디렉터리가 없습니다: $project_dir" >&2
        return 1
    fi

    project_abs=$(cd "$project_dir" && pwd)
    verify_script="$project_abs/.arachne/verify.sh"
    if [ ! -f "$verify_script" ]; then
        echo "[ERROR] 프로젝트 CI가 초기화되지 않았습니다: arachne init-ci \"$project_abs\"" >&2
        return 1
    fi

    bash "$verify_script"
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
                    echo "[ERROR] --profile 값이 필요합니다" >&2
                    exit 1
                }
                profile="$1"
                ;;
            -*)       echo "[ERROR] 알 수 없는 옵션: $1" >&2; exit 1 ;;
            *)        positional+=("$1") ;;
        esac
        shift
    done

    local proj="${positional[0]:-}"
    local parent="${positional[1]:-$PWD}"

    #---------------------------------------------------------------------------
    # 입력 검증
    #---------------------------------------------------------------------------
    if [ -z "$proj" ]; then
        echo "[ERROR] 프로젝트명이 필요합니다: arachne new <project> [parent-dir] [--no-git]" >&2
        exit 1
    fi
    case "$proj" in
        */*|.*) echo "[ERROR] 프로젝트명에 '/'·선행 '.' 사용 불가: $proj" >&2; exit 1 ;;
    esac
    validate_project_profile "$profile" || exit 1

    local tmpl="$REPO_DIR/docs/template/example.md"
    local idea_tmpl="$REPO_DIR/docs/template/idea.md"
    local issue_tmpl="$REPO_DIR/docs/template/issue.md"
    local audit_tmpl="$REPO_DIR/docs/template/audit.md"
    local task_tmpl="$REPO_DIR/docs/template/task.md"
    local task_rules="$REPO_DIR/docs/task/README.md"
    local agents_tmpl="$REPO_DIR/templates/project/AGENTS.md"
    local claude_tmpl="$REPO_DIR/templates/project/CLAUDE.md"
    if [ ! -f "$tmpl" ] || [ ! -f "$idea_tmpl" ] || [ ! -f "$issue_tmpl" ] \
        || [ ! -f "$audit_tmpl" ] || [ ! -f "$task_tmpl" ] || [ ! -f "$task_rules" ] \
        || [ ! -f "$agents_tmpl" ] || [ ! -f "$claude_tmpl" ]; then
        echo "[ERROR] 문서 템플릿 또는 task 규약이 없습니다" >&2
        exit 1
    fi

    local dest="$parent/$proj"
    if [ -e "$dest" ]; then
        echo "[ERROR] 이미 존재합니다: $dest" >&2
        exit 1
    fi

    #---------------------------------------------------------------------------
    # 기록 구조 생성
    #---------------------------------------------------------------------------
    mkdir -p "$dest/docs/issue" "$dest/docs/idea" "$dest/docs/task" "$dest/docs/template"
    touch "$dest/docs/issue/.gitkeep" "$dest/docs/idea/.gitkeep"
    cp "$tmpl" "$dest/docs/template/example.md"
    cp "$idea_tmpl" "$dest/docs/template/idea.md"
    cp "$issue_tmpl" "$dest/docs/template/issue.md"
    cp "$audit_tmpl" "$dest/docs/template/audit.md"
    cp "$task_tmpl" "$dest/docs/template/task.md"
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

    echo "[Arachne] 신규 프로젝트 생성: $dest"
    echo "  profile: $profile"
    echo "  구조: README.md, AGENTS.md, CLAUDE.md, docs/{issue,idea,task,template}, .arachne, .github/workflows"
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
    -s|--session|session)                     run_session ;;
    -e|--export-settings|export-settings)     export_settings ;;
    -d|--export-dotfiles|export-dotfiles)     export_dotfiles ;;
    -v|--version)                             show_version ;;
    *)                                        echo "[ERROR] 알 수 없는 옵션: $1" >&2; usage >&2; exit 1 ;;
esac
