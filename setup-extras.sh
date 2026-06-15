#!/usr/bin/env bash
################################################################################
# FILE NAME   : setup-extras.sh
# DESCRIPTION : Arachne 확장 도구 통합 설치 (Linux/macOS)
#               - Understand-Anything · taste-skill : Claude Code 로컬 마켓플레이스
#               - codegraph                         : 독립 CLI(PATH) + Arachne 래퍼
#               대화형 선택 메뉴 + 비대화형 플래그. 멱등 — 재실행 안전.
# DATA        : 2026-06-14
# Modification: 2026-06-15
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

#-------------------------------------------------------------------------------
# 전역 경로 — setup-extras.sh 가 위치한 레포 디렉터리 기준
#-------------------------------------------------------------------------------
REPO_SCRIPT="$(ResolvePath "${BASH_SOURCE[0]}")"
REPO_DIR="$(dirname "$REPO_SCRIPT")"
readonly REPO_DIR
readonly CLAUDE_DIR="$HOME/.claude"
readonly SETTINGS_TEMPLATE="$REPO_DIR/settings.template.json"
readonly SETTINGS_LIVE="$CLAUDE_DIR/settings.json"

#-------------------------------------------------------------------------------
# 클론 위치 — env 로 override 가능 (기본 $HOME 하위)
#-------------------------------------------------------------------------------
readonly UA_CLONE="${UA_CLONE:-$HOME/Understand-Anything}"
readonly TASTE_CLONE="${TASTE_CLONE:-$HOME/taste-skill}"
readonly CODEGRAPH_CLONE="${CODEGRAPH_CLONE:-$HOME/codegraph}"

#-------------------------------------------------------------------------------
# 원격 저장소 URL — 클론이 없을 때 자동 git clone 출처 (env 로 override 가능)
#-------------------------------------------------------------------------------
readonly UA_URL="${UA_URL:-https://github.com/Egonex-AI/Understand-Anything.git}"
readonly TASTE_URL="${TASTE_URL:-https://github.com/Leonxlnx/taste-skill.git}"
readonly CODEGRAPH_URL="${CODEGRAPH_URL:-https://github.com/colbymchenry/codegraph.git}"

#-------------------------------------------------------------------------------
# 플러그인 식별자 — <plugin>@<marketplace> (각 레포 .claude-plugin/marketplace.json)
#-------------------------------------------------------------------------------
readonly UA_PLUGIN="understand-anything@understand-anything"
readonly UA_MARKET="understand-anything"
readonly TASTE_PLUGIN="taste-skill@taste-skill"
readonly TASTE_MARKET="taste-skill"

readonly LOG_PREFIX="[Arachne-extras]"

# 선택 상태: -1 미지정 / 0 제외 / 1 포함
WANT_UA=-1
WANT_TASTE=-1
WANT_CG=-1
ASSUME_YES=0
NO_CLONE=0
DO_UPDATE=0

#===============================================================================
# FUNCTION    : LogInfo / LogWarn / LogError
# DESCRIPTION : 접두어 붙은 로그 출력 (경고·에러는 stderr)
#===============================================================================
LogInfo()  { echo "${LOG_PREFIX} $*"; }
LogWarn()  { echo "${LOG_PREFIX} [주의] $*" >&2; }
LogError() { echo "${LOG_PREFIX} [ERROR] $*" >&2; }

#===============================================================================
# FUNCTION    : Usage
# DESCRIPTION : 사용법 출력
#===============================================================================
Usage() {
    cat <<EOF
Usage: setup-extras.sh [OPTION]...

Arachne 확장 도구 통합 설치 (Understand-Anything · taste-skill · codegraph)

옵션이 없고 터미널이면 대화형 선택 메뉴, 옵션이 없고 비터미널이면 이 도움말.

Options:
  --all          감지된 확장 도구 전부 설치 (비대화형)
  --ua           Understand-Anything 플러그인만
  --taste        taste-skill 플러그인만
  --codegraph    codegraph CLI(+래퍼)만
  --no-clone     로컬 클론이 없어도 git clone 하지 않음 (기존 클론만 사용)
  --update       기존 클론·플러그인·CLI 를 최신으로 갱신 (git pull + plugin update)
  -y, --yes      대화형 프롬프트에 모두 yes (감지된 전부 설치)
  -h, --help     이 도움말

UA·taste-skill 은 Claude Code 로컬 마켓플레이스라 로컬 클론이 필요하다.
클론이 없으면 아래 URL 에서 자동으로 git clone 한다(--no-clone 으로 비활성).
codegraph 는 npm 전역 설치가 기본이라 클론이 필요 없다.

환경변수 (클론 경로 override):
  UA_CLONE         (기본 \$HOME/Understand-Anything)
  TASTE_CLONE      (기본 \$HOME/taste-skill)
  CODEGRAPH_CLONE  (기본 \$HOME/codegraph)

환경변수 (클론 출처 URL override):
  UA_URL           (기본 github.com/Egonex-AI/Understand-Anything)
  TASTE_URL        (기본 github.com/Leonxlnx/taste-skill)
  CODEGRAPH_URL    (기본 github.com/colbymchenry/codegraph)
EOF
}

#===============================================================================
# FUNCTION    : ParseArgs
# DESCRIPTION : 인자 파싱 — 선택 플래그가 하나라도 있으면 비대화형으로 전환
# PARAMETERS  : 커맨드라인 인자 ("$@")
#===============================================================================
ParseArgs() {
    local explicit=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --all)        WANT_UA=1; WANT_TASTE=1; WANT_CG=1; explicit=1 ;;
            --ua)         WANT_UA=1; explicit=1 ;;
            --taste)      WANT_TASTE=1; explicit=1 ;;
            --codegraph)  WANT_CG=1; explicit=1 ;;
            --no-clone)   NO_CLONE=1 ;;
            --update)     DO_UPDATE=1 ;;
            -y|--yes)     ASSUME_YES=1 ;;
            -h|--help)    Usage; exit 0 ;;
            *)            LogError "알 수 없는 옵션: $1"; Usage >&2; exit 1 ;;
        esac
        shift || true
    done

    # 특정 플래그 지정 시 미지정 항목은 명시적으로 제외
    if [ "$explicit" -eq 1 ]; then
        [ "$WANT_UA" -eq -1 ]    && WANT_UA=0
        [ "$WANT_TASTE" -eq -1 ] && WANT_TASTE=0
        [ "$WANT_CG" -eq -1 ]    && WANT_CG=0
    fi
    return 0
}

#===============================================================================
# FUNCTION    : Confirm
# DESCRIPTION : [Y/n] 프롬프트 — ASSUME_YES 면 즉시 yes
# PARAMETERS  : string prompt - 질문 문구
# RETURNED    : 0(yes) / 1(no)
#===============================================================================
Confirm() {
    local prompt="$1"
    local reply

    if [ "$ASSUME_YES" -eq 1 ]; then
        return 0
    fi
    read -r -p "${LOG_PREFIX} ${prompt} [Y/n] " reply || true
    case "$reply" in
        [nN]|[nN][oO]) return 1 ;;
        *)             return 0 ;;
    esac
}

#===============================================================================
# FUNCTION    : JsonSetEnabledPlugin
# DESCRIPTION : JSON 파일의 .enabledPlugins[key]=true 설정 (jq → node 폴백)
# PARAMETERS  : string file - 대상 JSON 경로
#               string key  - plugin@marketplace 키
# RETURNED    : 0(성공) / 1(파일없음) / 2(도구없음)
#===============================================================================
JsonSetEnabledPlugin() {
    local file="$1"
    local key="$2"
    local tmp

    [ -f "$file" ] || return 1

    if command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        if jq --arg k "$key" \
            '.enabledPlugins = ((.enabledPlugins // {}) + {($k): true})' \
            "$file" > "$tmp"; then
            mv "$tmp" "$file"
        else
            rm -f "$tmp"
            return 1
        fi
        return 0
    fi

    if command -v node >/dev/null 2>&1; then
        node -e '
            const fs = require("fs");
            const [f, k] = process.argv.slice(1);
            const j = JSON.parse(fs.readFileSync(f, "utf8"));
            j.enabledPlugins = j.enabledPlugins || {};
            j.enabledPlugins[k] = true;
            fs.writeFileSync(f, JSON.stringify(j, null, 2) + "\n");
        ' "$file" "$key"
        return 0
    fi

    return 2
}

#===============================================================================
# FUNCTION    : SyncEnabledPlugin
# DESCRIPTION : enabledPlugins 항목을 템플릿과 라이브 settings.json 양쪽에 반영.
#               템플릿 반영이 핵심 — arachne -i 재생성 시 활성화가 보존된다.
# PARAMETERS  : string key - plugin@marketplace 키
#===============================================================================
SyncEnabledPlugin() {
    local key="$1"

    if JsonSetEnabledPlugin "$SETTINGS_TEMPLATE" "$key"; then
        LogInfo "settings.template.json 에 enabledPlugins 동기화: $key"
    else
        LogWarn "settings.template.json 갱신 실패 — 재설치 후 'arachne -e' 로 보존하세요: $key"
    fi
    # 라이브 settings.json 은 claude plugin install 이 이미 갱신하지만, 멱등하게 보강
    JsonSetEnabledPlugin "$SETTINGS_LIVE" "$key" >/dev/null 2>&1 || true
}

#===============================================================================
# FUNCTION    : CloneRepo
# DESCRIPTION : 로컬 클론이 없으면 git clone (멱등). --no-clone 이면 클론 안 함.
#               이미 존재하면 그대로 사용한다(덮어쓰기·pull 안 함).
# PARAMETERS  : string label - 표시 이름
#               string url   - 원격 저장소 URL
#               string clone - 로컬 클론 경로
# RETURNED    : 0(클론 존재·성공) / 1(없음·클론 실패)
#===============================================================================
CloneRepo() {
    local label="$1"
    local url="$2"
    local clone="$3"

    if [ -d "$clone/.git" ] || [ -f "$clone/.claude-plugin/marketplace.json" ]; then
        if [ "$DO_UPDATE" -eq 1 ] && [ -d "$clone/.git" ] && command -v git >/dev/null 2>&1; then
            LogInfo "${label}: git pull (업데이트) — $clone"
            git -C "$clone" pull --ff-only || LogWarn "${label}: git pull 실패 — $clone"
        else
            LogInfo "${label}: 클론 이미 존재 — $clone"
        fi
        return 0
    fi
    if [ -e "$clone" ]; then
        LogWarn "${label}: $clone 가 git 클론이 아님 — 수동 확인 필요"
        return 1
    fi
    if [ "$NO_CLONE" -eq 1 ]; then
        LogWarn "${label}: 클론 없음 + --no-clone — 스킵 ($clone)"
        return 1
    fi
    if ! command -v git >/dev/null 2>&1; then
        LogWarn "${label}: git 미설치 — 클론 불가 ($clone)"
        return 1
    fi

    LogInfo "${label}: git clone $url → $clone"
    if git clone --depth 1 "$url" "$clone"; then
        return 0
    fi
    LogWarn "${label}: git clone 실패 — $url"
    return 1
}

#===============================================================================
# FUNCTION    : RegisterMarketplace
# DESCRIPTION : 로컬 클론을 Claude Code 마켓플레이스로 등록 (멱등)
# PARAMETERS  : string clone  - 클론 경로
#               string market - 마켓플레이스 이름
#===============================================================================
RegisterMarketplace() {
    local clone="$1"
    local market="$2"

    if claude plugin marketplace list 2>/dev/null | grep -qiw "$market"; then
        if [ "$DO_UPDATE" -eq 1 ]; then
            LogInfo "마켓플레이스 갱신: $market"
            claude plugin marketplace update "$market" || LogWarn "마켓플레이스 갱신 실패: $market"
        else
            LogInfo "마켓플레이스 이미 등록됨: $market"
        fi
        return 0
    fi
    LogInfo "마켓플레이스 등록: $clone"
    claude plugin marketplace add "$clone"
}

#===============================================================================
# FUNCTION    : InstallPlugin
# DESCRIPTION : 마켓플레이스 플러그인 설치 (멱등) + enabledPlugins 동기화
# PARAMETERS  : string plugin - plugin@marketplace
#===============================================================================
InstallPlugin() {
    local plugin="$1"

    # plugin list 는 마켓플레이스 가용 목록·enabledPlugins 동기화분까지 보여줘
    # 실제 미설치 상태도 매칭될 수 있다 → update 실패 시 install 로 폴백(자가 치유).
    if claude plugin list 2>/dev/null | grep -qiw "${plugin%@*}"; then
        if [ "$DO_UPDATE" -eq 1 ]; then
            LogInfo "플러그인 갱신: $plugin"
            if ! claude plugin update "${plugin%@*}"; then
                LogWarn "플러그인 갱신 실패 — 설치로 폴백: $plugin"
                claude plugin install "$plugin" --scope user \
                    || LogWarn "플러그인 설치 실패: $plugin"
            fi
        else
            LogInfo "플러그인 이미 설치됨: $plugin"
        fi
    else
        LogInfo "플러그인 설치: $plugin (scope: user)"
        claude plugin install "$plugin" --scope user \
            || LogWarn "플러그인 설치 실패: $plugin"
    fi
    SyncEnabledPlugin "$plugin"
}

#===============================================================================
# FUNCTION    : SetupPluginRepo
# DESCRIPTION : 클론(없으면 git clone) → 마켓플레이스 등록 → 플러그인 설치 일괄 처리
# PARAMETERS  : string label  - 표시 이름
#               string url    - 원격 저장소 URL (클론 없을 때 출처)
#               string clone  - 클론 경로
#               string market - 마켓플레이스 이름
#               string plugin - plugin@marketplace
# RETURNED    : 0(성공) / 1(스킵)
#===============================================================================
SetupPluginRepo() {
    local label="$1"
    local url="$2"
    local clone="$3"
    local market="$4"
    local plugin="$5"

    if ! command -v claude >/dev/null 2>&1; then
        LogWarn "${label}: claude CLI 미감지 — 플러그인 설치 스킵"
        return 1
    fi
    CloneRepo "$label" "$url" "$clone" || return 1
    if [ ! -f "$clone/.claude-plugin/marketplace.json" ]; then
        LogWarn "${label}: 마켓플레이스 매니페스트 없음 ($clone) — 스킵"
        return 1
    fi

    LogInfo "=== ${label} 설치 ==="
    RegisterMarketplace "$clone" "$market"
    InstallPlugin "$plugin"
    return 0
}

#===============================================================================
# FUNCTION    : InstallCodegraph
# DESCRIPTION : codegraph CLI 를 PATH 에 설치 (멱등) — 클론 installer → npm 폴백.
#               래퍼(commands/codegraph.md)는 레포에 항상 존재하므로 별도 생성 불필요.
# RETURNED    : 0(성공) / 1(실패)
#===============================================================================
InstallCodegraph() {
    LogInfo "=== codegraph 설치 ==="
    if command -v codegraph >/dev/null 2>&1; then
        if [ "$DO_UPDATE" -eq 1 ] && command -v npm >/dev/null 2>&1; then
            LogInfo "codegraph 갱신 (npm install -g @latest → \$HOME/.local)"
            npm install -g --prefix "$HOME/.local" @colbymchenry/codegraph@latest \
                || LogWarn "codegraph 갱신 실패"
        else
            LogInfo "codegraph 이미 설치됨: $(command -v codegraph)"
        fi
        return 0
    fi

    if [ -f "$CODEGRAPH_CLONE/install.sh" ]; then
        LogInfo "codegraph 설치 (clone installer)"
        sh "$CODEGRAPH_CLONE/install.sh"
    elif command -v npm >/dev/null 2>&1; then
        #-----------------------------------------------------------------------
        # npm 전역 설치 — 시스템 디렉터리(/usr/lib) 쓰기 권한 부족 시 EACCES.
        # --prefix "$HOME/.local" 로 사용자 홈에 설치(이미 PATH 에 있음).
        #-----------------------------------------------------------------------
        LogInfo "codegraph 설치 (npm @colbymchenry/codegraph → \$HOME/.local)"
        npm install -g --prefix "$HOME/.local" @colbymchenry/codegraph
    else
        LogWarn "codegraph 설치 불가 — 클론($CODEGRAPH_CLONE)도 npm 도 없음"
        return 1
    fi

    if command -v codegraph >/dev/null 2>&1; then
        LogInfo "codegraph OK: $(codegraph --version 2>/dev/null || echo installed)"
    else
        LogWarn "codegraph 가 PATH 에 없습니다 — ~/.local/bin 을 PATH 에 추가하세요"
    fi
}

#===============================================================================
# FUNCTION    : InteractiveSelect
# DESCRIPTION : 클론이 존재하는 항목만 대화형으로 포함 여부 질의
#===============================================================================
InteractiveSelect() {
    echo "${LOG_PREFIX} 확장 도구 설치 — 항목별로 선택하세요."

    if [ -d "$UA_CLONE" ] || command -v git >/dev/null 2>&1; then
        Confirm "Understand-Anything 플러그인 설치? (없으면 자동 clone → $UA_CLONE)" && WANT_UA=1 || WANT_UA=0
    else
        LogInfo "Understand-Anything 클론 없음 + git 미설치 — 건너뜀 ($UA_CLONE)"
        WANT_UA=0
    fi

    if [ -d "$TASTE_CLONE" ] || command -v git >/dev/null 2>&1; then
        Confirm "taste-skill 플러그인 설치? (없으면 자동 clone → $TASTE_CLONE)" && WANT_TASTE=1 || WANT_TASTE=0
    else
        LogInfo "taste-skill 클론 없음 + git 미설치 — 건너뜀 ($TASTE_CLONE)"
        WANT_TASTE=0
    fi

    if [ -d "$CODEGRAPH_CLONE" ] || command -v npm >/dev/null 2>&1; then
        Confirm "codegraph CLI 설치(+/codegraph 래퍼)?" && WANT_CG=1 || WANT_CG=0
    else
        LogInfo "codegraph 클론·npm 없음 — 건너뜀"
        WANT_CG=0
    fi
    return 0
}

#===============================================================================
# FUNCTION    : main
# DESCRIPTION : 진입점 — 인자 파싱 후 선택 항목 설치
# PARAMETERS  : 커맨드라인 인자 ("$@")
#===============================================================================
main() {
    ParseArgs "$@"

    # 선택 미지정(전부 -1) 이면: TTY → 대화형 / 비TTY → 도움말
    if [ "$WANT_UA" -eq -1 ] && [ "$WANT_TASTE" -eq -1 ] && [ "$WANT_CG" -eq -1 ]; then
        if [ "$ASSUME_YES" -eq 1 ]; then
            WANT_UA=1; WANT_TASTE=1; WANT_CG=1
        elif [ -t 0 ]; then
            InteractiveSelect
        else
            Usage
            exit 0
        fi
    fi

    [ "$WANT_UA" -eq 1 ]    && SetupPluginRepo "Understand-Anything" "$UA_URL" "$UA_CLONE" "$UA_MARKET" "$UA_PLUGIN" || true
    [ "$WANT_TASTE" -eq 1 ] && SetupPluginRepo "taste-skill" "$TASTE_URL" "$TASTE_CLONE" "$TASTE_MARKET" "$TASTE_PLUGIN" || true
    [ "$WANT_CG" -eq 1 ]    && InstallCodegraph || true

    LogInfo "확장 도구 설정 완료. (플러그인은 Claude Code 재시작 후 활성화)"
}

main "$@"
