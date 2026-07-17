#!/bin/bash
################################################################################
# FILE NAME   : install.sh
# DESCRIPTION : Arachne 멀티 CLI 설정 설치 스크립트
# DATA        : 2026-05-05
# Modification: 2026-07-17
################################################################################

set -euo pipefail

#===============================================================================
# FUNCTION    : ResolvePath
# DESCRIPTION : GNU readlink -f 없이 파일·심볼릭 링크의 절대 경로 계산
# PARAMETERS  : string path - 해석할 파일 경로
# RETURNED    : 절대 경로
#===============================================================================
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

#===============================================================================
# FUNCTION    : ArachneLog
# DESCRIPTION : Arachne 스크립트의 사용자 출력 형식을 통일
# PARAMETERS  : string level   - STEP|RUN|SKIP|DONE|WARN|ERROR
#               string message - 출력할 메시지
#===============================================================================
ArachneLog() {
    local level="$1"
    local message="$2"

    case "$level" in
        WARN|ERROR) printf '[Arachne][%s] %s\n' "$level" "$message" >&2 ;;
        *)          printf '[Arachne][%s] %s\n' "$level" "$message" ;;
    esac
}

#===============================================================================
# FUNCTION    : ArachneSection
# DESCRIPTION : 긴 설치·업데이트 로그의 주요 단계 경계를 배너로 표시
# PARAMETERS  : string message - 섹션 제목
#===============================================================================
ArachneSection() {
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

#===============================================================================
# FUNCTION    : Usage
# DESCRIPTION : 사용법 출력
#===============================================================================
Usage() {
    local entry
    local script
    local cmd

    echo "Usage: ${PROG} [OPTION]"
    echo ""
    echo "Arachne — Claude Code 글로벌 설정 관리 도구"
    echo ""
    echo "Options:"
    echo "  -i, --install          설치/재설치 수행 + 확장 도구(UA·taste-skill·codegraph)"
    echo "                          자동 설치·최신 갱신 (미설치는 설치, 기설치는 갱신)"
    echo "  -u, --update           대화형: Arachne/Understand/codegraph 중 선택 갱신"
    echo "      --target T          설치 대상 CLI: claude|gemini|codex|copilot|all (기본 all)"
    echo "                          (-i/-u 와 함께 사용. 미감지 CLI는 자동 스킵)"
    echo "      --with-ua           -i/-u 와 함께: 확장 도구를 Understand-Anything 만으로 한정"
    echo "      --with-extras       (하위 호환) 기본 동작과 동일 — 전체 확장 도구 멱등 설정"
    echo "      --extras            확장 도구 통합 설치만 단독 실행 (대화형 선택 메뉴)"
    echo "  -c, --check            CLI 연결 상태 점검 (심볼릭 댕글링·병합본 stale 탐지)"
    echo "  -n, --new P [DIR]      신규 프로젝트 스캐폴딩 (README + AGENTS/CLAUDE 지침 스텁"
    echo "                         + docs/{issue,idea,task,template})"
    echo "                         DIR 생략 시 현재 디렉터리. --no-git 으로 git init 생략"
    echo "                         --profile minimal|python|web|python-web|cpp|rust (기본 minimal)"
    echo "      --init-ci [DIR]    프로젝트 검증 runner + GitHub Actions workflow 생성/갱신"
    echo "                         --profile minimal|python|web|python-web|cpp|rust (기본 minimal)"
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

#===============================================================================
# FUNCTION    : ShowVersion
# DESCRIPTION : 버전 정보 출력 (git 단축 해시 포함)
#===============================================================================
ShowVersion() {
    local rev
    rev=$(git -C "$REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    echo "${PROG} ${ARACHNE_VERSION} (${rev})"
}

#===============================================================================
# FUNCTION    : UpdateArachneCore
# DESCRIPTION : git pull 후 최신 상태로 재설치 (Arachne 본체)
#===============================================================================
UpdateArachneCore() {
    ArachneSection "업데이트 시작 (git pull)"
    cd "$REPO_DIR" || { ArachneLog "ERROR" "update: 레포 디렉터리 진입 실패 (repo=$REPO_DIR)"; exit 1; }

    #---------------------------------------------------------------------------
    # #33: pull·재설치 전에 레포 상태를 검증한다. 비-main 브랜치는 경고하고,
    #      커밋되지 않은 변경(dirty)이 있으면 pull 충돌·재설치 손실 위험이 있어 중단한다.
    #      ARACHNE_FORCE=1 로 강제 진행 가능.
    #---------------------------------------------------------------------------
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
    if [ "$branch" != "main" ]; then
        ArachneLog "WARN" "update: 현재 브랜치가 main 이 아님 (branch=$branch)"
    fi
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        ArachneLog "ERROR" "update: 작업트리에 커밋되지 않은 변경이 있음 — git pull 충돌·재설치 손실 위험"
        ArachneLog "ERROR" "update: 커밋/스태시 후 재실행 또는 ARACHNE_FORCE=1 arachne -u 로 강제"
        if [ "${ARACHNE_FORCE:-0}" != "1" ]; then
            exit 1
        fi
        ArachneLog "WARN" "update: ARACHNE_FORCE=1 — dirty 검증 무시"
    fi

    ArachneLog "RUN" "git pull"
    git pull
    ArachneSection "최신 소스 기반 재설치 진행"
    Install
}

#===============================================================================
# FUNCTION    : RunUpdateUnderstand
# DESCRIPTION : Understand-Anything 확장 도구만 갱신
#===============================================================================
RunUpdateUnderstand() {
    case "${ARACHNE_TARGET:-all}" in
        all|claude) ;;
        *)
            ArachneLog "SKIP" "extras: target=${ARACHNE_TARGET:-all} — Claude 플러그인 대상이 아님"
            return 0
            ;;
    esac

    ArachneSection "Understand-Anything 확장 도구 갱신 시작"
    RunExtras --ua --update
    ArachneSection "Understand-Anything 확장 도구 갱신 완료"
}

#===============================================================================
# FUNCTION    : RunUpdateCodegraph
# DESCRIPTION : codegraph CLI 만 갱신
#===============================================================================
RunUpdateCodegraph() {
    ArachneSection "codegraph 확장 도구 갱신 시작"
    RunExtras --codegraph --update
    ArachneSection "codegraph 확장 도구 갱신 완료"
}

#===============================================================================
# FUNCTION    : UpdateMark
# DESCRIPTION : 업데이트 선택 메뉴의 체크박스 상태 문자열 반환
# PARAMETERS  : integer enabled - 1이면 선택됨, 0이면 선택 안 됨
#===============================================================================
UpdateMark() {
    if [ "$1" -eq 1 ]; then
        printf 'x'
    else
        printf ' '
    fi
}

#===============================================================================
# FUNCTION    : UpdateInteractiveMenu
# DESCRIPTION : -u 기본 대화형 체크박스 메뉴
#===============================================================================
UpdateInteractiveMenu() {
    local want_core=1
    local want_ua=0
    local want_cg=0
    local reply
    local item

    while true; do
        ArachneSection "업데이트 항목 선택"
        printf '  [%s] 1) Arachne 최신 소스 업데이트 + 재설치\n' "$(UpdateMark "$want_core")"
        printf '  [%s] 2) Understand-Anything 플러그인 갱신\n' "$(UpdateMark "$want_ua")"
        printf '  [%s] 3) codegraph CLI 갱신\n' "$(UpdateMark "$want_cg")"
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
                ArachneLog "SKIP" "update: 사용자가 취소함"
                return 0
                ;;
            *)
                for item in $reply; do
                    case "$item" in
                        1) [ "$want_core" -eq 1 ] && want_core=0 || want_core=1 ;;
                        2) [ "$want_ua" -eq 1 ] && want_ua=0 || want_ua=1 ;;
                        3) [ "$want_cg" -eq 1 ] && want_cg=0 || want_cg=1 ;;
                        *) ArachneLog "WARN" "update: 알 수 없는 선택 '$item' 무시" ;;
                    esac
                done
                ;;
        esac
    done

    if [ "$want_core" -eq 0 ] && [ "$want_ua" -eq 0 ] && [ "$want_cg" -eq 0 ]; then
        ArachneLog "SKIP" "update: 선택된 항목 없음"
        return 0
    fi

    [ "$want_core" -eq 1 ] && UpdateArachneCore
    [ "$want_ua" -eq 1 ] && RunUpdateUnderstand
    [ "$want_cg" -eq 1 ] && RunUpdateCodegraph
}

#===============================================================================
# FUNCTION    : UpdateArachne
# DESCRIPTION : -u 진입점. 대화형이면 체크박스 선택, 비대화형·플래그 지정은 기존 흐름 유지
#===============================================================================
UpdateArachne() {
    if [ -t 0 ] && [ "${ARACHNE_WITH_UA:-0}" -eq 0 ] && [ "${ARACHNE_WITH_EXTRAS:-0}" -eq 0 ]; then
        UpdateInteractiveMenu
        return 0
    fi

    UpdateArachneCore
    # -u 도 -i 와 동일하게 확장 도구 동기화 — 전체 설치·갱신이 기본,
    # --with-ua 지정 시 Understand-Anything 만.
    MaybeRunExtras --update
}

#===============================================================================
# FUNCTION    : RunSession
# DESCRIPTION : tmux 워크스페이스 매니저 실행 (tws 래퍼)
#===============================================================================
RunSession() {
    local tmux_script="$REPO_DIR/tmux.sh"
    ArachneSection "tmux 워크스페이스 실행"

    if [ -f "$tmux_script" ]; then
        exec "$tmux_script"
    else
        ArachneLog "ERROR" "tmux.sh 파일을 찾을 수 없습니다: $tmux_script"
        exit 1
    fi
}

#===============================================================================
# FUNCTION    : BackupAndLink
# DESCRIPTION : 기존 파일/디렉터리 백업 후 심볼릭 링크 생성
# PARAMETERS  : string src - 레포 내 원본 경로
#               string dst - ~/.claude/ 내 대상 경로
#===============================================================================
BackupAndLink() {
    local src="$1"
    local dst="$2"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        # 기존 .bak 이 디렉터리면 mv 가 그 안으로 중첩 이동한다 — 1세대 백업
        # 정책(직전 것만 보존)에 맞게 이전 백업을 지우고 교체한다.
        rm -rf "$dst.bak"
        echo "  백업: $dst -> $dst.bak"
        mv "$dst" "$dst.bak"
    elif [ -L "$dst" ]; then
        rm "$dst"
    fi

    ln -s "$src" "$dst"
    echo "  링크: $dst -> $src"
}

#===============================================================================
# FUNCTION    : RegisterBin
# DESCRIPTION : BIN_TARGETS 를 ~/.local/bin/ 에 심볼릭 링크로 등록
#               git pull 시 자동 업데이트 (재실행 불필요)
#               새 스크립트 추가 시에만 재실행 필요
#===============================================================================
RegisterBin() {
    ArachneSection "bin 등록 시작: $LOCAL_BIN"
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
            rm -rf "$dst.bak"
            echo "  백업: $dst -> $dst.bak"
            mv "$dst" "$dst.bak"
        fi

        ln -s "$src" "$dst"
        echo "  등록: $cmd -> $src"
    done

    ArachneSection "bin 등록 완료"

    # F-10: 부분 문자열 grep 은 유사 경로(~/.local/binx 등)에 오탐 — 정확한 항목 매칭
    case ":$PATH:" in
        *":$LOCAL_BIN:"*) ;;
        *)
            echo "  주의: $LOCAL_BIN 이 PATH에 없습니다. ~/.bash_profile에 추가하세요:"
            echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
            ;;
    esac
}

#===============================================================================
# FUNCTION    : InstallClaude
# DESCRIPTION : Claude Code 타깃 설치 — 심볼릭 링크 + settings.json 생성
#               (rules/ 가 ~/.claude/rules/ 로 링크돼 네이티브 자동 로드됨)
#===============================================================================
InstallClaude() {
    ArachneSection "Claude 설치 시작: $REPO_DIR -> $CLAUDE_DIR"
    mkdir -p "$CLAUDE_DIR"

    # local 선언 — 동적 스코프에서 호출자(install)의 변수를 덮어쓰지 않도록 한다
    local link_target
    for link_target in "${SYMLINK_TARGETS[@]}"; do
        BackupAndLink "$REPO_DIR/$link_target" "$CLAUDE_DIR/$link_target"
    done

    # settings.json: __HOME__ 치환 후 생성 (심볼릭 링크 아님)
    # #28: 기존 settings.json 이 템플릿 생성본과 다르면(=사용자 수정) 조용히 덮어쓰지 않고
    #      경고한다. 직전 값은 .bak 에 보존하되, 보존하려면 arachne -e 로 템플릿에 반영하도록 안내.
    local settings_dst="$CLAUDE_DIR/settings.json"
    local new_settings
    new_settings=$(sed "s|__HOME__|$HOME|g" "$REPO_DIR/settings.template.json")

    #---------------------------------------------------------------------------
    # 사용자 선호 키 보존 — /model·/config 로 저장한 model·theme 은 재설치가
    # 템플릿 기본값으로 되돌리지 않는다 (jq 가용 + 기존 파일이 유효 JSON일 때).
    #---------------------------------------------------------------------------
    if command -v jq >/dev/null 2>&1 \
        && [ -f "$settings_dst" ] && jq -e . "$settings_dst" >/dev/null 2>&1; then
        local merged
        merged=$(printf '%s\n' "$new_settings" | jq \
            --slurpfile cur "$settings_dst" \
            '. + {model: ($cur[0].model // .model), theme: ($cur[0].theme // .theme)}
             | with_entries(select(.value != null))' 2>/dev/null) \
            && [ -n "$merged" ] && new_settings="$merged"
    fi

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

    ArachneSection "Claude 설치 완료"
}

#===============================================================================
# FUNCTION    : InstallGemini
# DESCRIPTION : Gemini CLI 타깃 설치 — AGENTS.md(SSOT)를 ~/.gemini/GEMINI.md 로 심볼릭
#               심볼릭이라 AGENTS.md 수정이 재설치 없이 즉시 반영됨
#===============================================================================
InstallGemini() {
    local gemini_dir="$HOME/.gemini"
    ArachneSection "Gemini 설치 시작: AGENTS.md -> $gemini_dir/GEMINI.md"
    mkdir -p "$gemini_dir"
    BackupAndLink "$REPO_DIR/AGENTS.md" "$gemini_dir/GEMINI.md"
    ArachneSection "Gemini 설치 완료"
}

#===============================================================================
# FUNCTION    : InstallCodex
# DESCRIPTION : Codex CLI 타깃 설치 — AGENTS.md(SSOT)를 ~/.codex/AGENTS.md 로 병합.
#               import 미지원이라 심볼릭 대신 마커 병합(사용자 보충 보존).
#               Markdown 친화 마커(<!-- === ARACHNE ... === -->) 사용.
#               심볼릭이 아니므로 AGENTS.md 수정 후 재반영하려면
#               arachne -i --target codex 재실행이 필요하다.
#===============================================================================
InstallCodex() {
    local codex_dir="$HOME/.codex"
    ArachneSection "Codex 설치 시작: AGENTS.md -> $codex_dir/AGENTS.md"
    mkdir -p "$codex_dir"
    MergeDotfile "$REPO_DIR/AGENTS.md" "$codex_dir/AGENTS.md" "<!--" " -->"
    ArachneSection "Codex 설치 완료"
}

#===============================================================================
# FUNCTION    : InstallCopilot
# DESCRIPTION : GitHub Copilot 타깃 설치.
#               Copilot CLI 전역 지침은 사용자 내용을 보존하는 마커 병합으로,
#               VS Code 사용자 지침은 Arachne 전용 .instructions.md 로 생성한다.
#               일반 파일만 사용해 macOS·Linux·WSL·Git Bash에서 링크 권한 없이 동작한다.
#===============================================================================
InstallCopilot() {
    local copilot_dir="$HOME/.copilot"
    local instructions_dir="$copilot_dir/instructions"
    local vscode_file="$instructions_dir/arachne.instructions.md"
    local tmp

    ArachneSection "GitHub Copilot 설치 시작: AGENTS.md -> $copilot_dir"
    mkdir -p "$instructions_dir"

    MergeDotfile \
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
    ArachneSection "GitHub Copilot 설치 완료"
}

#===============================================================================
# FUNCTION    : DetectCli
# DESCRIPTION : 대상 CLI 설치 여부 검사 (홈 디렉터리 또는 바이너리 존재)
# PARAMETERS  : string cli - gemini | codex | copilot
# RETURNED    : 0(감지) / 1(미감지)
#===============================================================================
DetectCli() {
    local cli="$1"
    case "$cli" in
        gemini) [ -d "$HOME/.gemini" ] || command -v gemini >/dev/null 2>&1 ;;
        codex)  [ -d "$HOME/.codex" ]  || command -v codex  >/dev/null 2>&1 ;;
        copilot) [ -d "$HOME/.copilot" ] || command -v copilot >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

#===============================================================================
# FUNCTION    : _DetectZshTarget
# DESCRIPTION : ~/.zshrc 적용 대상 여부 판단
#               zshrc 파일이 이미 있거나 기본 셸이 zsh인 경우 적용
# RETURNED    : 0(적용) / 1(스킵)
#===============================================================================
_DetectZshTarget() {
    [ -f "$HOME/.zshrc" ] || [[ "$SHELL" == */zsh ]]
}

#===============================================================================
# FUNCTION    : InstallShared
# DESCRIPTION : 타깃 무관 공통 설치 (dotfiles 병합 + bin 등록) — 항상 1회
#===============================================================================
InstallShared() {
    InstallDotfiles
    RegisterBin
}

#===============================================================================
# FUNCTION    : Install
# DESCRIPTION : 타깃 디스패처 — ARACHNE_TARGET 에 따라 CLI별 설치 후 공통 설치
#               all 은 감지된 CLI 에만 설치(미감지 시 graceful skip)
#===============================================================================
Install() {
    local target="${ARACHNE_TARGET:-all}"
    ArachneSection "설치/재설치 시작 (target=$target)"
    case "$target" in
        claude) InstallClaude ;;
        gemini) InstallGemini ;;
        codex)  InstallCodex ;;
        copilot) InstallCopilot ;;
        all)
            InstallClaude
            if DetectCli gemini; then
                InstallGemini
            else
                ArachneLog "SKIP" "install: Gemini CLI 미감지 — target=gemini"
            fi
            if DetectCli codex; then
                InstallCodex
            else
                ArachneLog "SKIP" "install: Codex CLI 미감지 — target=codex"
            fi
            if DetectCli copilot; then
                InstallCopilot
            else
                ArachneLog "SKIP" "install: GitHub Copilot 미감지 — target=copilot"
            fi
            ;;
    esac

    #---------------------------------------------------------------------------
    # #34: 공통 설치(dotfiles 병합 + 전체 bin 등록)는 전체 설치(all)에서만 수행.
    # 특정 CLI 타깃 지정 시 공통 인프라(~/.bash_profile·~/.local/bin)를 건드리지 않는다.
    #---------------------------------------------------------------------------
    if [ "$target" = "all" ]; then
        InstallShared
    else
        ArachneLog "SKIP" "install: 타깃 '$target' — 공통 설치(dotfiles·bin) 생략 (전체 설치는 'arachne -i')"
    fi
    ArachneLog "DONE" "install: target=$target"
}

#===============================================================================
# FUNCTION    : RunExtras
# DESCRIPTION : 확장 도구 통합 설치 스크립트(setup-extras.sh) 실행
#               UA·taste-skill 로컬 마켓플레이스 + codegraph CLI(+래퍼)
# PARAMETERS  : 나머지 인자 - setup-extras.sh 로 그대로 전달
#===============================================================================
RunExtras() {
    local extras="${ARACHNE_EXTRAS_SCRIPT:-$REPO_DIR/setup-extras.sh}"
    if [ ! -f "$extras" ]; then
        ArachneLog "SKIP" "extras: setup 스크립트 없음 — path=$extras"
        return 0
    fi
    ArachneLog "RUN" "extras: bash $extras $*"
    bash "$extras" "$@"
}

#===============================================================================
# FUNCTION    : MaybeRunExtras
# DESCRIPTION : -i/-u 설치 후 확장 도구 동기화. Claude 타깃(all|claude)에서만 동작.
#               --with-ua 지정 시 Understand-Anything 만 실행하고, 그 외에는 항상
#               전체 확장 도구를 설치·갱신한다(--all --update 멱등 — 미설치는
#               설치, 기설치는 git pull/plugin update 로 최신화).
# PARAMETERS  : 나머지 인자 - setup-extras.sh 로 전달 (예: --update)
#===============================================================================
MaybeRunExtras() {
    local pass_args=("$@")
    local action="설정"

    case " ${pass_args[*]-} " in *" --update "*) action="갱신" ;; esac

    case "${ARACHNE_TARGET:-all}" in
        all|claude) ;;
        *)
            ArachneLog "SKIP" "extras: target=${ARACHNE_TARGET:-all} — Claude 플러그인 대상이 아님"
            return 0
            ;;
    esac

    if [ "${ARACHNE_WITH_UA:-0}" -eq 1 ]; then
        ArachneSection "Understand-Anything 확장 도구 ${action} 시작"
        RunExtras --ua ${pass_args[@]+"${pass_args[@]}"}
        ArachneSection "Understand-Anything 확장 도구 ${action} 완료"
        return 0
    fi

    #---------------------------------------------------------------------------
    # 기본 동작: 전체 확장 도구를 항상 설치하고 기설치면 최신으로 갱신한다.
    # --all/--update 는 이미 강제하므로 pass_args 의 중복 지정은 걸러 전달한다.
    #---------------------------------------------------------------------------
    local forward_args=()
    local pass_arg
    for pass_arg in ${pass_args[@]+"${pass_args[@]}"}; do
        case "$pass_arg" in
            --all|--update) ;;
            *)              forward_args+=("$pass_arg") ;;
        esac
    done
    ArachneSection "전체 확장 도구 ${action} 시작 (미설치는 설치, 기설치는 최신 갱신)"
    RunExtras --all --update ${forward_args[@]+"${forward_args[@]}"}
    ArachneSection "전체 확장 도구 ${action} 완료"
}

#===============================================================================
# FUNCTION    : MergeDotfile
# DESCRIPTION : dotfiles/ 내용을 사용자 파일에 ARACHNE 섹션으로 병합
#               기존 파일 내용 유지, 섹션이 있으면 갱신 / 없으면 끝에 추가
#               중복 감지: 사용자 영역에 이미 있는 export/alias 줄만 섹션에서 제외
#               (블록 구조 줄까지 제외하면 병합본 문법이 깨지므로 범위 한정)
# PARAMETERS  : string src            - dotfiles/ 내 원본 경로
#               string dst            - 홈 디렉터리 내 대상 경로
#               string comment_char   - 형식별 주석 시작 문자 (기본: #, vimrc: ", md: <!--)
#               string comment_suffix - 형식별 주석 종료 문자 (기본: 없음, md: " -->")
#===============================================================================
MergeDotfile() {
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

#===============================================================================
# FUNCTION    : InstallDotfiles
# DESCRIPTION : dotfiles/ 내용을 홈 디렉터리 파일에 ARACHNE 섹션으로 병합 설치
#               중복 줄 자동 제외, zsh 감지 시 ~/.zshrc 에도 적용
#===============================================================================
InstallDotfiles() {
    ArachneSection "dotfiles 설치 시작"
    MergeDotfile "$DOTFILES_DIR/bash_profile" "$HOME/.bash_profile" "#"
    MergeDotfile "$DOTFILES_DIR/vimrc"        "$HOME/.vimrc"        '"'
    if _DetectZshTarget; then
        local zsh_src="$DOTFILES_DIR/bash_profile"
        [ -f "$DOTFILES_DIR/zshrc" ] && zsh_src="$DOTFILES_DIR/zshrc"
        MergeDotfile "${zsh_src}" "$HOME/.zshrc" "#"
    fi
    ArachneSection "dotfiles 설치 완료"
    echo "  적용하려면: source ~/.bash_profile  (zsh: source ~/.zshrc)"
}

#===============================================================================
# FUNCTION    : _ExportSingle
# DESCRIPTION : 사용자 파일의 ARACHNE 섹션을 dotfiles/ 로 추출
# PARAMETERS  : string src          - 홈 디렉터리 내 원본 파일 경로
#               string dst          - dotfiles/ 내 대상 경로
#               string label        - 로그 표시용 파일명
#               string comment_char - 파일 형식별 주석 문자 (기본: #, vimrc: ")
#===============================================================================
_ExportSingle() {
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

#===============================================================================
# FUNCTION    : ExportDotfiles
# DESCRIPTION : ~/.bash_profile, ~/.vimrc, ~/.zshrc -> dotfiles/ 로 내보내기
#===============================================================================
ExportDotfiles() {
    ArachneSection "dotfiles 내보내기 시작"
    _ExportSingle "$HOME/.bash_profile" "$DOTFILES_DIR/bash_profile" ".bash_profile" "#"
    _ExportSingle "$HOME/.vimrc"        "$DOTFILES_DIR/vimrc"        ".vimrc"        '"'
    if [ -f "$HOME/.zshrc" ]; then
        _ExportSingle "$HOME/.zshrc" "$DOTFILES_DIR/zshrc" ".zshrc" "#"
    fi
    ArachneSection "dotfiles 내보내기 완료"
    echo "  커밋하려면: cd $REPO_DIR && git add dotfiles/ && git commit -m 'chore: update dotfiles'"
}

#===============================================================================
# FUNCTION    : ExportSettings
# DESCRIPTION : ~/.claude/settings.json -> settings.template.json 내보내기
#===============================================================================
ExportSettings() {
    local settings_src="$CLAUDE_DIR/settings.json"
    local template_dst="$REPO_DIR/settings.template.json"

    ArachneSection "settings.template.json 내보내기 시작"
    if [ ! -f "$settings_src" ]; then
        ArachneLog "ERROR" "$settings_src 파일이 없습니다."
        exit 1
    fi

    sed "s|$HOME|__HOME__|g" "$settings_src" > "$template_dst"
    ArachneSection "settings.template.json 갱신 완료"
    echo "  커밋하려면: cd $REPO_DIR && git add settings.template.json && git commit -m 'chore: update settings template'"
}

#===============================================================================
# FUNCTION    : ParseTarget
# DESCRIPTION : 인자에서 --target 값을 파싱해 전역 ARACHNE_TARGET 에 저장·검증
# PARAMETERS  : 커맨드 뒤 나머지 인자들 ("$@")
#===============================================================================
ARACHNE_TARGET="all"
ARACHNE_WITH_UA=0
ARACHNE_WITH_EXTRAS=0
ParseTarget() {
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
        *) ArachneLog "ERROR" "알 수 없는 타깃: '$ARACHNE_TARGET' (claude|gemini|codex|copilot|all)"; exit 1 ;;
    esac
}

#===============================================================================
# FUNCTION    : CheckArachne
# DESCRIPTION : CLI 연결 상태 점검 — 심볼릭 댕글링·병합 파일 stale 탐지.
#               OK/SKIP/FAIL 출력. 하나라도 FAIL 이면 종료코드 1.
#===============================================================================
CheckArachne() {
    local fail=0
    ArachneSection "연결 상태 점검 시작"

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
    if DetectCli gemini; then
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
    if DetectCli codex; then
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
    if DetectCli copilot; then
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
        ArachneSection "연결 상태 점검 완료: 모든 연결 정상"
    else
        ArachneSection "연결 상태 점검 완료: 문제 발견"
        ArachneLog "ERROR" "연결 문제 발견 — 위 안내대로 재설치 필요"
    fi
    return "$fail"
}

################################################################################
# 도메인 라이브러리 로드 — install.sh 는 설치·배선 도메인만 직접 담고,
# 프로젝트 스캐폴딩·CI(project-ci)와 피드백(feedback)은 lib/ 에서 source 한다.
# (동작 보존 추출 — 함수·디스패처 계약 불변)
################################################################################
# shellcheck source=lib/project-ci.sh
source "$REPO_DIR/lib/project-ci.sh"
# shellcheck source=lib/feedback.sh
source "$REPO_DIR/lib/feedback.sh"

case "${1:-}" in
    "")
        if [ "$ENTRY_NAME" = "install.sh" ]; then
            Install
        else
            Usage
        fi
        ;;
    "-h"|--help|help)                         Usage ;;
    -i|--install|install)                     shift; ParseTarget "$@"; Install; MaybeRunExtras ;;
    -u|--update|update)                       shift; ParseTarget "$@"; UpdateArachne ;;
    --extras|extras)                          shift; RunExtras "$@" ;;
    -c|--check|check)                         CheckArachne ;;
    -n|--new|new)                             shift; NewProject "$@" ;;
    --init-ci|init-ci)                        shift; InitProjectCi "$@" ;;
    --project-check|project-check)            shift; CheckProject "${1:-$PWD}" ;;
    feedback)                                 shift; FeedbackCommand "$@" ;;
    -s|--session|session)                     RunSession ;;
    -e|--export-settings|export-settings)     ExportSettings ;;
    -d|--export-dotfiles|export-dotfiles)     ExportDotfiles ;;
    -v|--version)                             ShowVersion ;;
    *)                                        ArachneLog "ERROR" "알 수 없는 옵션: $1"; Usage >&2; exit 1 ;;
esac
