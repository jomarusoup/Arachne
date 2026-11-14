################################################################################
# FILE NAME   : toolchain-update.sh
# DESCRIPTION : arachne -t --update 도메인 — 설치된 개발 도구의 현재·최신 버전과
#               프로젝트 고정 버전을 비교해 업데이트 여부를 판정하고, 확인 후
#               갱신·이력 기록·되돌리기를 수행한다. lib/toolchain.sh 와 함께
#               install.sh 에서 source 된다 (단독 실행하지 않음).
#
#               판정 2계층
#                 전역 계층   : 하네스 기준선. 패치는 기본 Y, 마이너·메이저는 기본 N.
#                               한 프로젝트 때문에 전역 버전을 내리지 않는다.
#                 프로젝트 계층: 프로젝트 고정이 있으면 그 범위를 지킨다. 버전 관리자
#                               (Go toolchain·go tool·rustup·mise)가 프로젝트별로
#                               맞추는 도구는 전역을 건드리지 않는다.
################################################################################
# shellcheck shell=bash

readonly TOOLCHAIN_HISTORY_FILE="${HOME}/.claude/arachne/toolchain-history.log"
readonly MISE_INSTALL_URL="https://mise.run"
readonly MISE_RELEASE_API="https://api.github.com/repos/jdx/mise/releases/latest"
readonly PYPI_JSON_BASE="https://pypi.org/pypi"

TOOLS_UPDATE_MODE=0
TOOLS_ALLOW_MAJOR=0
TOOLS_ALL_SYSTEM=0
TOOLS_PROJECT_DIR=""
TOOLS_ROLLBACK=""

#===============================================================================
# FUNCTION    : NormalizeVersion
# DESCRIPTION : 다양한 버전 표기를 숫자 점 구분 형태로 정규화
#               go1.27.3 → 1.27.3 · v2.15.0 → 2.15.0 · 1:2.34-1ubuntu1 → 2.34
#               2.1.325 (Claude Code) → 2.1.325
# PARAMETERS  : string raw - 원본 버전 문자열
#===============================================================================
NormalizeVersion() {
    local ver="$1"

    ver="${ver%% *}"
    ver="${ver#*:}"
    ver="${ver#"${ver%%[0-9]*}"}"
    ver="${ver%%[-+~]*}"
    echo "${ver}"
}

#===============================================================================
# FUNCTION    : VersionField
# DESCRIPTION : 정규화된 버전의 N번째(1부터) 숫자 필드 출력 (없으면 0)
# PARAMETERS  : string ver   - 정규화된 버전
#               int    index - 필드 번호
#===============================================================================
VersionField() {
    local field

    field=$(echo "$1" | awk -F. -v n="$2" '{ print $n }')
    field="${field%%[!0-9]*}"
    echo "${field:-0}"
}

#===============================================================================
# FUNCTION    : VersionLevel
# DESCRIPTION : 현재 → 최신 버전 차이 수준 판정
# PARAMETERS  : string cur    - 현재 버전
#               string latest - 최신 버전
# RETURNED    : same | patch | minor | major | newer | unknown (stdout)
#===============================================================================
VersionLevel() {
    local cur
    local latest
    local idx
    local cur_field
    local new_field

    cur=$(NormalizeVersion "$1")
    latest=$(NormalizeVersion "$2")
    if [ -z "${cur}" ] || [ -z "${latest}" ]; then
        echo "unknown"
        return 0
    fi
    for idx in 1 2 3 4; do
        cur_field=$(VersionField "${cur}" "${idx}")
        new_field=$(VersionField "${latest}" "${idx}")
        if [ "${cur_field}" -lt "${new_field}" ]; then
            case "${idx}" in
                1) echo "major" ;;
                2) echo "minor" ;;
                *) echo "patch" ;;
            esac
            return 0
        fi
        if [ "${cur_field}" -gt "${new_field}" ]; then
            echo "newer"
            return 0
        fi
    done
    echo "same"
}

#===============================================================================
# FUNCTION    : VersionMatches
# DESCRIPTION : 버전이 고정 범위를 만족하는지 판정
#               범위 형식: 2.10 · 2.10.x · 2.10.1(정확) · >=1.25 · *
# PARAMETERS  : string ver        - 검사할 버전
#               string constraint - 고정 범위
# RETURNED    : 0(만족) / 1(불만족)
#===============================================================================
VersionMatches() {
    local ver
    local constraint="$2"
    local level
    local prefix
    local idx
    local field_count

    ver=$(NormalizeVersion "$1")
    case "${constraint}" in
        ""|"*"|latest) return 0 ;;
        ">="*)
            level=$(VersionLevel "${constraint#>=}" "${ver}")
            case "${level}" in same|patch|minor|major) return 0 ;; esac
            return 1
            ;;
    esac
    prefix=$(NormalizeVersion "${constraint}")
    prefix="${prefix%.x}"
    prefix="${prefix%.\*}"
    [ -n "${prefix}" ] || return 0
    field_count=$(echo "${prefix}" | awk -F. '{print NF}')
    for idx in $(seq 1 "${field_count}"); do
        [ "$(VersionField "${ver}" "${idx}")" = "$(VersionField "${prefix}" "${idx}")" ] || return 1
    done
    return 0
}

#===============================================================================
# FUNCTION    : ReadProjectPin
# DESCRIPTION : 현재 프로젝트에서 도구의 고정 버전과 관리 주체를 찾는다.
#               우선순위: .arachne/toolchain.lock > mise.toml > .tool-versions
#                         > 도구 고유 파일(go.mod · rust-toolchain.toml)
# PARAMETERS  : string tool - 카탈로그 도구 이름 (go · golangci-lint · cmake ...)
#               string dir  - 프로젝트 디렉터리
# RETURNED    : "범위|관리자" (stdout). 관리자: lock · mise · go-toolchain ·
#               go-tool · rustup. 고정 없으면 빈 문자열
#===============================================================================
ReadProjectPin() {
    local tool="$1"
    local dir="$2"
    local value
    local mise_name="${tool}"

    [ -n "${dir}" ] && [ -d "${dir}" ] || return 0
    [ "${tool}" = "cargo" ] && mise_name="rust"

    if [ -f "${dir}/.arachne/toolchain.lock" ]; then
        value=$(awk -F= -v t="${tool}" '
            /^[[:space:]]*#/ {next}
            { gsub(/[[:space:]]/, "") }
            $1 == t { print $2; exit }' "${dir}/.arachne/toolchain.lock")
        [ -n "${value}" ] && { echo "${value}|lock"; return 0; }
    fi
    if [ -f "${dir}/mise.toml" ]; then
        value=$(awk -v t="${mise_name}" '
            /^\[/ { in_tools = ($0 ~ /^\[tools\]/); next }
            in_tools {
                line = $0; gsub(/[[:space:]"]/, "", line)
                split(line, kv, "=")
                if (kv[1] == t) { print kv[2]; exit }
            }' "${dir}/mise.toml")
        [ -n "${value}" ] && { echo "${value}|mise"; return 0; }
    fi
    if [ -f "${dir}/.tool-versions" ]; then
        value=$(awk -v t="${mise_name}" '$1 == t { print $2; exit }' "${dir}/.tool-versions")
        [ -n "${value}" ] && { echo "${value}|mise"; return 0; }
    fi

    case "${tool}" in
        go)
            [ -f "${dir}/go.mod" ] || return 0
            value=$(awk '$1 == "toolchain" { print $2; exit }' "${dir}/go.mod")
            [ -z "${value}" ] && value=$(awk '$1 == "go" { print ">=" $2; exit }' "${dir}/go.mod")
            [ -n "${value}" ] && echo "${value}|go-toolchain"
            ;;
        goimports|staticcheck|golangci-lint|govulncheck)
            [ -f "${dir}/go.mod" ] || return 0
            if grep -Eq "^[[:space:]]*(tool[[:space:]]+)?[^[:space:]]*/${tool}([[:space:]]|$)" "${dir}/go.mod" \
                && grep -Eq '^[[:space:]]*tool[[:space:]]|^tool[[:space:]]*\(' "${dir}/go.mod"; then
                echo "go.mod tool|go-tool"
            fi
            ;;
        cargo)
            if [ -f "${dir}/rust-toolchain.toml" ]; then
                value=$(awk -F= '/channel/ { gsub(/[[:space:]"]/, "", $2); print $2; exit }' "${dir}/rust-toolchain.toml")
                echo "${value:-toolchain}|rustup"
            elif [ -f "${dir}/rust-toolchain" ]; then
                echo "$(head -1 "${dir}/rust-toolchain")|rustup"
            fi
            ;;
    esac
}

#===============================================================================
# FUNCTION    : GoMinorSupported
# DESCRIPTION : Go 보안 지원 정책 — 최신 두 마이너 라인만 보안 수정을 받는다
# PARAMETERS  : string cur    - 현재 Go 버전
#               string latest - 최신 Go 버전
# RETURNED    : 0(지원 중) / 1(지원 종료)
#===============================================================================
GoMinorSupported() {
    local cur
    local latest

    cur=$(NormalizeVersion "$1")
    latest=$(NormalizeVersion "$2")
    [ "$(VersionField "${cur}" 1)" = "$(VersionField "${latest}" 1)" ] || return 1
    [ $(( $(VersionField "${latest}" 2) - $(VersionField "${cur}" 2) )) -le 1 ]
}

#===============================================================================
# FUNCTION    : ToolUpdateDecision
# DESCRIPTION : 한 도구의 업데이트 판정
# PARAMETERS  : string tool     - 도구 이름
#               string cur      - 현재 버전
#               string latest   - 최신 버전 (모르면 빈 문자열)
#               string pin      - ReadProjectPin 결과 ("범위|관리자" 또는 빈 값)
#               int    required - 1이면 하네스 필수 조건 미달
# RETURNED    : "판정|기본응답|사유" (stdout)
#               판정: update · skip · project · conflict, 기본응답: Y · N · -
#===============================================================================
ToolUpdateDecision() {
    local tool="$1"
    local cur="$2"
    local latest="$3"
    local pin="$4"
    local required="$5"
    local constraint="${pin%%|*}"
    local manager="${pin#*|}"
    local level

    if [ "${required}" -eq 1 ]; then
        echo "update|Y|하네스 필수 조건 미달"
        return 0
    fi
    if [ -z "${latest}" ]; then
        echo "skip|-|최신 버전 확인 불가"
        return 0
    fi
    level=$(VersionLevel "${cur}" "${latest}")
    case "${level}" in
        same|newer) echo "skip|-|최신 (${cur})"; return 0 ;;
        unknown)    echo "skip|-|버전 해석 불가 (${cur} / ${latest})"; return 0 ;;
    esac

    #---------------------------------------------------------------------------
    # 프로젝트 고정 — 버전 관리자가 프로젝트별로 맞추면 전역은 기준선 규칙만 따른다
    #---------------------------------------------------------------------------
    if [ -n "${pin}" ]; then
        case "${manager}" in
            go-toolchain|go-tool|rustup|mise)
                if [ "${level}" = "patch" ]; then
                    echo "update|Y|패치 (${cur} → ${latest}) — 프로젝트 고정 ${constraint} 는 ${manager} 가 별도 관리"
                else
                    echo "update|N|${level} (${cur} → ${latest}) — 프로젝트 고정 ${constraint} 는 ${manager} 가 별도 관리"
                fi
                return 0
                ;;
        esac
        if ! VersionMatches "${cur}" "${constraint}"; then
            echo "conflict|-|프로젝트 고정 ${constraint} ≠ 설치 ${cur} — 머신 단일 버전 도구: 컨테이너 또는 mise 고정 권장"
            return 0
        fi
        if ! VersionMatches "${latest}" "${constraint}"; then
            echo "skip|-|프로젝트 고정 ${constraint} 유지 (최신 ${latest} 있음)"
            return 0
        fi
    fi

    if [ "${tool}" = "go" ] && ! GoMinorSupported "${cur}" "${latest}"; then
        echo "update|Y|Go ${cur} 보안 지원 종료 (최신 두 마이너만 지원) → ${latest}"
        return 0
    fi
    case "${level}" in
        patch) echo "update|Y|패치 (${cur} → ${latest})" ;;
        *)     echo "update|N|${level} (${cur} → ${latest}) — 동작 변경 가능" ;;
    esac
}

#===============================================================================
# FUNCTION    : AskDefault
# DESCRIPTION : 기본값 있는 확인. --yes 는 기본 Y 항목만 승인하고, 기본 N 항목은
#               --allow-major 일 때만 승인한다. 비대화형이면 거부.
# PARAMETERS  : string question - 질문 문구
#               string default  - Y | N
# RETURNED    : 0(승인) / 1(거부)
#===============================================================================
AskDefault() {
    local question="$1"
    local default="$2"
    local reply=""
    local hint="[y/N]"

    [ "${default}" = "Y" ] && hint="[Y/n]"
    if [ "${TOOLS_ASSUME_YES}" -eq 1 ]; then
        [ "${default}" = "Y" ] && return 0
        [ "${TOOLS_ALLOW_MAJOR}" -eq 1 ] && return 0
        return 1
    fi
    [ -t 0 ] || return 1
    read -r -p "[Arachne] ${question} ${hint}: " reply || true
    case "${reply}" in
        y|Y|yes|YES) return 0 ;;
        n|N|no|NO)   return 1 ;;
        "")          [ "${default}" = "Y" ] ;;
        *)           return 1 ;;
    esac
}

#===============================================================================
# FUNCTION    : RecordToolHistory
# DESCRIPTION : 업데이트 전후 버전을 이력 파일에 한 줄로 기록 (되돌리기 근거)
# PARAMETERS  : string tool - 도구 이름
#               string from - 이전 버전
#               string to   - 새 버전
#               string ref  - 되돌리기 참조 (go install 패키지 경로 등)
#===============================================================================
RecordToolHistory() {
    [ "${TOOLS_DRY_RUN}" -eq 1 ] && return 0
    mkdir -p "$(dirname "${TOOLCHAIN_HISTORY_FILE}")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$(date '+%F %T')" "$1" "$2" "$3" "${4:-}" >> "${TOOLCHAIN_HISTORY_FILE}"
}

#-------------------------------------------------------------------------------
# 현재·최신 버전 조회 — 네트워크 실패는 빈 문자열로 처리해 판정이 skip 이 되게 한다
#-------------------------------------------------------------------------------

#===============================================================================
# FUNCTION    : PkgInstalledVersion
# DESCRIPTION : 시스템 패키지의 설치 버전 출력 (미설치면 빈 값)
# PARAMETERS  : string pkg - 패키지명
#===============================================================================
PkgInstalledVersion() {
    case "${TOOLS_PM}" in
        dnf)
            # 미설치 메시지는 로캘마다 다르다 — 종료 코드로 판정
            if rpm -q "$1" >/dev/null 2>&1; then
                rpm -q --qf '%{VERSION}\n' "$1" 2>/dev/null | head -1
            fi
            ;;
        apt)  dpkg-query -W -f='${Version}\n' "$1" 2>/dev/null | head -1 ;;
        brew) brew list --versions "$1" 2>/dev/null | awk '{print $2}' ;;
    esac
}

#===============================================================================
# FUNCTION    : PkgNameForTool
# DESCRIPTION : 도구 실행 파일을 실제로 설치한 패키지 이름 (카탈로그 이름과 다를 수
#               있다 — 예: psql 이 postgresql16 에서 온 경우). 못 찾으면 카탈로그 값.
# PARAMETERS  : string line - 카탈로그 줄
#===============================================================================
PkgNameForTool() {
    local line="$1"
    local spec
    local path=""
    local owner=""
    local pkg=""

    spec=$(echo "${line}" | cut -d'|' -f2)
    spec="${spec%%/*}"
    command -v "${spec}" >/dev/null 2>&1 && path=$(readlink -f "$(command -v "${spec}")")
    if [ -n "${path}" ]; then
        case "${TOOLS_PM}" in
            dnf) owner=$(rpm -qf --qf '%{NAME}\n' "${path}" 2>/dev/null | head -1) || owner="" ;;
            apt) owner=$(dpkg -S "${path}" 2>/dev/null | head -1 | cut -d: -f1) || owner="" ;;
        esac
        case "${owner}" in *" "*|"") owner="" ;; esac
    fi
    if [ -n "${owner}" ]; then
        echo "${owner}"
        return 0
    fi
    case "${TOOLS_PM}" in
        dnf)  pkg=$(echo "${line}" | cut -d'|' -f3) ;;
        apt)  pkg=$(ResolvePackages "$(echo "${line}" | cut -d'|' -f4)") ;;
        brew) pkg=$(echo "${line}" | cut -d'|' -f5) ;;
    esac
    pkg="${pkg%% *}"
    [ "${pkg}" = "-" ] || echo "${pkg}"
}

#===============================================================================
# FUNCTION    : PkgCandidateVersions
# DESCRIPTION : 업데이트 가능한 패키지 목록을 "패키지 새버전" 줄로 출력
#               (dnf versionlock · apt-mark hold 걸린 패키지는 관리자가 제외한다)
# PARAMETERS  : string pkgs - 조회할 패키지 목록 (공백 구분)
#===============================================================================
PkgCandidateVersions() {
    local pkgs="$1"
    local pkg_list=()

    read -r -a pkg_list <<< "${pkgs}"
    [ "${#pkg_list[@]}" -gt 0 ] || return 0
    case "${TOOLS_PM}" in
        dnf)
            # 첫 실행은 사용자 캐시 메타데이터를 받느라 느릴 수 있다 — 상한을 둔다
            DnfQuery check-update "${pkg_list[@]}" \
                | awk 'NF >= 3 && $1 ~ /\./ { name = $1; sub(/\.[^.]*$/, "", name); ver = $2; sub(/-[^-]*$/, "", ver); sub(/^[0-9]+:/, "", ver); print name, ver }' || true
            ;;
        apt)
            RunWithTimeout 120 apt list --upgradable 2>/dev/null </dev/null \
                | awk -F'[/ ]' 'NR > 1 { print $1, $3 }' || true
            ;;
        brew)
            RunWithTimeout 120 brew outdated --verbose "${pkg_list[@]}" 2>/dev/null </dev/null \
                | awk '{ print $1, $NF }' || true
            ;;
    esac
}

#===============================================================================
# FUNCTION    : GoOfficialVersion
# DESCRIPTION : /usr/local/go 공식 설치본 버전 (없으면 PATH 의 go)
#===============================================================================
GoOfficialVersion() {
    if [ -x /usr/local/go/bin/go ]; then
        /usr/local/go/bin/go env GOVERSION 2>/dev/null
    elif command -v go >/dev/null 2>&1; then
        go env GOVERSION 2>/dev/null
    fi
}

#===============================================================================
# FUNCTION    : GoLatestVersion
# DESCRIPTION : go.dev 최신 안정 버전 (예: go1.27.3)
#===============================================================================
GoLatestVersion() {
    curl -fsSL --max-time 15 "https://go.dev/VERSION?m=text" 2>/dev/null | head -1
}

#===============================================================================
# FUNCTION    : GoToolBinary
# DESCRIPTION : go install 도구의 실행 파일 경로 (PATH 또는 GOPATH/bin)
# PARAMETERS  : string name - 도구 이름
#===============================================================================
GoToolBinary() {
    if command -v "$1" >/dev/null 2>&1; then
        command -v "$1"
    elif [ -x "${HOME}/go/bin/$1" ]; then
        echo "${HOME}/go/bin/$1"
    fi
}

#===============================================================================
# FUNCTION    : GoToolModule
# DESCRIPTION : go install 도구 바이너리에 기록된 "모듈경로 버전" 출력
# PARAMETERS  : string bin - 실행 파일 경로
#===============================================================================
GoToolModule() {
    local go_bin

    go_bin=$(GoBinary) || return 0
    "${go_bin}" version -m "$1" 2>/dev/null | awk '$1 == "mod" { print $2, $3; exit }'
}

#===============================================================================
# FUNCTION    : GoModuleLatest
# DESCRIPTION : Go 모듈의 최신 버전 조회
# PARAMETERS  : string module - 모듈 경로
#===============================================================================
GoModuleLatest() {
    local go_bin

    go_bin=$(GoBinary) || return 0
    (cd "${TMPDIR:-/tmp}" && GOFLAGS=-mod=mod RunWithTimeout 60 "${go_bin}" list -m -f '{{.Version}}' "$1@latest" 2>/dev/null </dev/null) || true
}

#===============================================================================
# FUNCTION    : PypiLatest
# DESCRIPTION : PyPI 패키지 최신 버전
# PARAMETERS  : string pkg - 패키지명
#===============================================================================
PypiLatest() {
    command -v jq >/dev/null 2>&1 || return 0
    curl -fsSL --max-time 15 "${PYPI_JSON_BASE}/$1/json" 2>/dev/null | jq -r '.info.version // empty' 2>/dev/null || true
}

#===============================================================================
# FUNCTION    : PipToolVersion
# DESCRIPTION : pipx/pip 로 설치한 도구의 현재 버전
# PARAMETERS  : string pkg - 패키지명
#===============================================================================
PipToolVersion() {
    local ver=""

    if command -v pipx >/dev/null 2>&1; then
        ver=$(pipx list --short 2>/dev/null | awk -v p="$1" '$1 == p { print $2; exit }')
    fi
    if [ -z "${ver}" ] && command -v python3 >/dev/null 2>&1; then
        ver=$(python3 -m pip show "$1" 2>/dev/null | awk '/^Version:/ { print $2; exit }')
    fi
    echo "${ver}"
}

#===============================================================================
# FUNCTION    : NpmLatest
# DESCRIPTION : npm 패키지 최신 버전
# PARAMETERS  : string pkg - 패키지명
#===============================================================================
NpmLatest() {
    command -v npm >/dev/null 2>&1 || return 0
    RunWithTimeout 20 npm view "$1" version 2>/dev/null </dev/null || true
}

#===============================================================================
# FUNCTION    : RustLatestFromCheck
# DESCRIPTION : rustup check 결과에서 "현재 최신" 두 값을 출력 (갱신 없으면 빈 값)
#===============================================================================
RustLatestFromCheck() {
    local rustup_bin
    local versions

    rustup_bin=$(command -v rustup || echo "${HOME}/.cargo/bin/rustup")
    [ -x "${rustup_bin}" ] || return 0
    # 예: stable-x86_64-... - Update available : 1.80.0 (해시 날짜) -> 1.81.0 (해시 날짜)
    #     stable-x86_64-... - Up to date : 1.81.0 (해시 날짜)
    versions=$(RunWithTimeout 60 "${rustup_bin}" check 2>/dev/null </dev/null | grep '^stable' | head -1 \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -2 | tr '\n' ' ') || true
    versions="${versions% }"
    [ -n "${versions}" ] || return 0
    echo "${versions%% *} ${versions##* }"
}

#===============================================================================
# FUNCTION    : MiseLatest
# DESCRIPTION : mise 최신 릴리스 버전
#===============================================================================
MiseLatest() {
    command -v jq >/dev/null 2>&1 || return 0
    curl -fsSL --max-time 15 "${MISE_RELEASE_API}" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null || true
}

#-------------------------------------------------------------------------------
# 업데이트 실행
#-------------------------------------------------------------------------------

#===============================================================================
# FUNCTION    : UpgradeSystemPackages
# DESCRIPTION : 시스템 패키지 업그레이드 (이미 최신이면 관리자가 no-op 처리)
# PARAMETERS  : string pkgs - 패키지 목록 (공백 구분)
#===============================================================================
UpgradeSystemPackages() {
    local pkg_list=()

    read -r -a pkg_list <<< "$1"
    [ "${#pkg_list[@]}" -gt 0 ] || return 0
    case "${TOOLS_PM}" in
        dnf)  RunToolSudo dnf -y upgrade "${pkg_list[@]}" ;;
        apt)  RunToolSudo apt-get install -y --only-upgrade "${pkg_list[@]}" ;;
        brew) RunToolCmd brew upgrade "${pkg_list[@]}" ;;
        *)    return 1 ;;
    esac
}

#===============================================================================
# FUNCTION    : ApplyToolUpdate
# DESCRIPTION : 판정이 승인된 도구 하나를 방식별로 갱신하고 이력을 남긴다
# PARAMETERS  : string spec   - 도구 이름
#               string method - 카탈로그 방식
#               string cur    - 현재 버전
#               string latest - 목표 버전
#               string pkg    - 시스템 패키지명 (pkg 방식)
# RETURNED    : 0(성공) / 1(실패)
#===============================================================================
ApplyToolUpdate() {
    local spec="$1"
    local method="$2"
    local cur="$3"
    local latest="$4"
    local pkg="$5"
    local go_bin
    local rc=0

    case "${method}" in
        pkg)
            UpgradeSystemPackages "${pkg}" || rc=1
            ;;
        special:go)
            TOOLS_GO_NO_PROMPT=1 InstallGoOfficial || rc=1
            ;;
        go:*)
            go_bin=$(GoBinary) || go_bin="go"
            RunToolCmd "${go_bin}" install "${method#go:}" || rc=1
            ;;
        special:rustup)
            RunToolCmd "$(command -v rustup || echo "${HOME}/.cargo/bin/rustup")" update stable || rc=1
            ;;
        pip:*)
            if command -v pipx >/dev/null 2>&1; then
                RunToolCmd pipx upgrade "${method#pip:}" || rc=1
            else
                RunToolCmd python3 -m pip install --user --upgrade "${method#pip:}" || rc=1
            fi
            ;;
        special:mise)
            RunToolCmd mise self-update -y || rc=1
            ;;
        special:claude)
            RunToolCmd claude update || rc=1
            ;;
        *)
            ArachneLog "SKIP" "tools: ${spec} — 업데이트 방식 없음"
            return 0
            ;;
    esac
    if [ "${rc}" -eq 0 ]; then
        [ "${method}" = "special:go" ] || RecordToolHistory "${spec}" "${cur}" "${latest}" "${method}"
        ToolsDone "tools: ${spec} ${cur} → ${latest}"
    fi
    return "${rc}"
}

#===============================================================================
# FUNCTION    : ToolVersionPair
# DESCRIPTION : 카탈로그 한 줄의 "현재버전|최신버전|필수(0/1)|시스템패키지" 출력.
#               pkg 방식은 후보 목록(candidates)에서 최신 버전을 찾는다.
# PARAMETERS  : string line       - 카탈로그 줄
#               string candidates - PkgCandidateVersions 결과
#===============================================================================
ToolVersionPair() {
    local line="$1"
    local candidates="$2"
    local spec
    local method
    local pkg=""
    local cur=""
    local latest=""
    local required=0
    local bin
    local mod_info
    local rust_pair

    spec=$(echo "${line}" | cut -d'|' -f2)
    method=$(echo "${line}" | cut -d'|' -f6)

    case "${method}" in
        pkg)
            pkg=$(PkgNameForTool "${line}")
            [ -n "${pkg}" ] && cur=$(PkgInstalledVersion "${pkg}")
            if [ -n "${cur}" ]; then
                latest=$(echo "${candidates}" | awk -v p="${pkg}" '$1 == p { print $2; exit }')
                [ -n "${latest}" ] || latest="${cur}"
            fi
            ;;
        special:go)
            cur=$(GoOfficialVersion)
            [ -n "${cur}" ] && latest=$(GoLatestVersion)
            ;;
        go:*)
            bin=$(GoToolBinary "${spec}")
            if [ -n "${bin}" ]; then
                mod_info=$(GoToolModule "${bin}")
                cur="${mod_info#* }"
                # 하네스 스킬의 .golangci.yml 은 v2 형식 — v1 바이너리는 필수 교체
                if [ "${spec}" = "golangci-lint" ] && [[ "${mod_info%% *}" != */v2* ]]; then
                    required=1
                fi
                [ -n "${mod_info}" ] && latest=$(GoModuleLatest "$(echo "${method#go:}" | sed -E 's#/cmd/.*##; s#@.*##')")
            fi
            ;;
        special:rustup)
            rust_pair=$(RustLatestFromCheck)
            cur="${rust_pair%% *}"
            latest="${rust_pair##* }"
            ;;
        pip:*)
            cur=$(PipToolVersion "${method#pip:}")
            [ -n "${cur}" ] && latest=$(PypiLatest "${method#pip:}")
            ;;
        special:mise)
            if command -v mise >/dev/null 2>&1; then
                cur=$(RunWithTimeout 20 mise --version 2>/dev/null </dev/null | awk '{print $1}')
                latest=$(MiseLatest)
            fi
            ;;
        special:claude)
            if command -v claude >/dev/null 2>&1; then
                cur=$(RunWithTimeout 20 claude --version 2>/dev/null </dev/null | awk '{print $1}')
                latest=$(NpmLatest "@anthropic-ai/claude-code")
            fi
            ;;
    esac
    echo "${cur}|${latest}|${required}|${pkg}"
}

#===============================================================================
# FUNCTION    : DotfilesStale
# DESCRIPTION : 홈 dotfile 의 ARACHNE 섹션이 저장소 원본과 다른지 검사
#               (병합을 임시 사본에 시뮬레이션해 결과를 비교)
# RETURNED    : 다른 파일 목록 (stdout, 공백 구분)
#===============================================================================
DotfilesStale() {
    local stale=""
    local entry
    local src
    local dst
    local comment
    local tmp

    for entry in "bash_profile|${HOME}/.bash_profile|#" "vimrc|${HOME}/.vimrc|\""; do
        src="${DOTFILES_DIR}/${entry%%|*}"
        dst=$(echo "${entry}" | cut -d'|' -f2)
        comment="${entry##*|}"
        if [ ! -f "${src}" ] || [ ! -f "${dst}" ]; then
            continue
        fi
        tmp=$(mktemp)
        cp "${dst}" "${tmp}"
        MergeDotfile "${src}" "${tmp}" "${comment}" >/dev/null 2>&1 || true
        cmp -s "${tmp}" "${dst}" || stale="${stale} ${dst}"
        rm -f "${tmp}"
    done
    echo "${stale# }"
}

#===============================================================================
# FUNCTION    : UpdateProjectLayer
# DESCRIPTION : 프로젝트 계층 — mise 고정 파일이 있으면 프로젝트 버전 설치를 제안
#===============================================================================
UpdateProjectLayer() {
    local dir="${TOOLS_PROJECT_DIR}"

    [ -n "${dir}" ] || return 0
    if [ -f "${dir}/mise.toml" ] || [ -f "${dir}/.tool-versions" ]; then
        if ! command -v mise >/dev/null 2>&1; then
            ArachneLog "WARN" "tools: ${dir} 에 mise 고정 파일이 있지만 mise 미설치 — arachne -t --group vm"
            return 0
        fi
        if AskDefault "프로젝트 고정 버전 설치 (mise install @ ${dir})?" Y; then
            (cd "${dir}" && RunToolCmd mise install) || TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1))
        fi
    fi
}

#===============================================================================
# FUNCTION    : RunToolsUpdate
# DESCRIPTION : --update 본체 — 설치된 도구별 판정 표 출력 → 승인 항목 갱신
#               → 프로젝트 계층 → dotfiles 최신화 → (선택) 시스템 전체 업그레이드
#===============================================================================
RunToolsUpdate() {
    local catalog
    local line
    local group
    local spec
    local method
    local all_pkgs=""
    local candidates
    local pair
    local cur
    local latest
    local required
    local pkg
    local pin
    local decision
    local verdict
    local default
    local reason
    local stale

    catalog=$(ToolCatalogLines)
    ArachneSection "버전 점검 (프로젝트: ${TOOLS_PROJECT_DIR:-없음})"

    #---------------------------------------------------------------------------
    # 시스템 패키지 후보는 한 번에 조회 (dnf check-update 반복 호출 방지)
    #---------------------------------------------------------------------------
    while IFS= read -r line; do
        [ "$(echo "${line}" | cut -d'|' -f6)" = "pkg" ] || continue
        IsGroupSelected "${line%%|*}" || continue
        IsToolPresent "$(echo "${line}" | cut -d'|' -f2)" || continue
        all_pkgs="${all_pkgs} $(PkgNameForTool "${line}")"
    done <<< "${catalog}"
    # Docker CE 는 special 이지만 패키지로 설치되므로 갱신 대상에 포함
    IsGroupSelected container && all_pkgs="${all_pkgs} docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
    all_pkgs=$(echo "${all_pkgs}" | tr ' ' '\n' | grep -v '^-\?$' | sort -u | tr '\n' ' ')
    [ "${TOOLS_PM}" = "dnf" ] && DNF_QUERY_ERR=$(mktemp)
    candidates=$(PkgCandidateVersions "${all_pkgs}")
    if [ "${TOOLS_PM}" = "dnf" ]; then
        if [ -n "$(DnfRepoErrors)" ]; then
            ArachneLog "WARN" "tools: 저장소 조회 실패(해당 저장소 패키지는 판정 제외) — $(DnfRepoErrors)"
        fi
        rm -f "${DNF_QUERY_ERR}"
        DNF_QUERY_ERR=""
    fi

    for group in "${TOOL_GROUPS[@]}"; do
        IsGroupSelected "${group}" || continue
        while IFS= read -r line; do
            [ "${line%%|*}" = "${group}" ] || continue
            spec=$(echo "${line}" | cut -d'|' -f2)
            method=$(echo "${line}" | cut -d'|' -f6)
            IsToolPresent "${spec}" || continue
            [ "${method}" = "special:docker" ] && continue

            pair=$(ToolVersionPair "${line}" "${candidates}")
            cur=$(echo "${pair}" | cut -d'|' -f1)
            latest=$(echo "${pair}" | cut -d'|' -f2)
            required=$(echo "${pair}" | cut -d'|' -f3)
            pkg=$(echo "${pair}" | cut -d'|' -f4)
            [ -n "${cur}" ] || continue

            pin=$(ReadProjectPin "${spec%%/*}" "${TOOLS_PROJECT_DIR}")
            decision=$(ToolUpdateDecision "${spec%%/*}" "${cur}" "${latest}" "${pin}" "${required}")
            verdict="${decision%%|*}"
            default=$(echo "${decision}" | cut -d'|' -f2)
            reason="${decision#*|*|}"

            case "${verdict}" in
                skip)     ArachneLog "OK" "${spec}: ${reason}" ;;
                conflict) ArachneLog "WARN" "${spec}: ${reason}" ;;
                update)
                    if [ "${TOOLS_CHECK_ONLY}" -eq 1 ]; then
                        ArachneLog "WARN" "${spec}: 업데이트 대상 — ${reason} (기본 ${default})"
                    elif AskDefault "${spec}: ${reason} — 업데이트할까요?" "${default}"; then
                        ApplyToolUpdate "${spec%%/*}" "${method}" "${cur}" "${latest}" "${pkg}" \
                            || TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1))
                    else
                        ArachneLog "SKIP" "${spec}: 유지 (${cur})"
                    fi
                    ;;
            esac
        done <<< "${catalog}"
    done

    #---------------------------------------------------------------------------
    # Docker CE 패키지 — docker-ce 로 설치된 경우에만 (podman-docker 는 대상 아님)
    #---------------------------------------------------------------------------
    if IsGroupSelected container; then
        pkg=$(echo "${candidates}" | awk '$1 ~ /^(docker-ce|docker-ce-cli|containerd\.io|docker-buildx-plugin|docker-compose-plugin)$/ { printf "%s ", $1 }')
        if [ -n "${pkg}" ] && AskDefault "Docker CE 패키지 업데이트 있음 (${pkg% }) — 업데이트할까요?" Y; then
            UpgradeSystemPackages "${pkg% }" || TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1))
        fi
    fi

    UpdateProjectLayer

    stale=$(DotfilesStale)
    if [ -n "${stale}" ]; then
        ArachneLog "WARN" "tools: dotfile ARACHNE 섹션이 저장소와 다름 — ${stale}"
        if AskDefault "dotfiles 를 저장소 기준으로 다시 병합할까요?" Y; then
            if [ "${TOOLS_DRY_RUN}" -eq 1 ]; then
                RunToolCmd "InstallDotfiles (${stale})"
            else
                InstallDotfiles
            fi
        fi
    fi

    if [ "${TOOLS_ALL_SYSTEM}" -eq 1 ] && AskDefault "시스템 전체 패키지 업그레이드 (커널 포함)?" N; then
        case "${TOOLS_PM}" in
            dnf)  RunToolSudo dnf -y upgrade ;;
            apt)  RunToolSudo apt-get update && RunToolSudo apt-get upgrade -y ;;
            brew) RunToolCmd brew upgrade ;;
        esac || TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1))
    fi
}

#===============================================================================
# FUNCTION    : RunToolsRollback
# DESCRIPTION : 직전 업데이트 되돌리기. go 는 /usr/local/go.prev 와 교체,
#               go install 도구는 이력의 이전 버전으로 재설치, 그 외는 안내.
# PARAMETERS  : string tool - 되돌릴 도구 이름
# RETURNED    : 0(성공) / 1(실패·근거 없음)
#===============================================================================
RunToolsRollback() {
    local tool="$1"
    local last
    local from
    local method
    local go_bin
    local pkg_path

    if [ "${tool}" = "go" ]; then
        if [ ! -d /usr/local/go.prev ]; then
            ArachneLog "ERROR" "tools: /usr/local/go.prev 없음 — 되돌릴 Go 가 없습니다"
            return 1
        fi
        if [ ! -d /usr/local/go ]; then
            # 설치 도중 tar 실패 등으로 현재 설치본이 없는 상태 — 이전 본만 복귀
            RunToolSudo mv /usr/local/go.prev /usr/local/go || return 1
            ToolsDone "tools: Go 복구 — $(/usr/local/go/bin/go version 2>/dev/null)"
            return 0
        fi
        RunToolSudo rm -rf /usr/local/go.rollback-tmp \
            && RunToolSudo mv /usr/local/go /usr/local/go.rollback-tmp \
            && RunToolSudo mv /usr/local/go.prev /usr/local/go \
            && RunToolSudo mv /usr/local/go.rollback-tmp /usr/local/go.prev \
            || return 1
        ToolsDone "tools: Go 되돌림 — $(/usr/local/go/bin/go version 2>/dev/null)"
        return 0
    fi

    last=""
    if [ -f "${TOOLCHAIN_HISTORY_FILE}" ]; then
        last=$(awk -F'\t' -v t="${tool}" '$2 == t && $5 !~ /^rollback/ { line = $0 } END { print line }' "${TOOLCHAIN_HISTORY_FILE}")
    fi
    if [ -z "${last}" ]; then
        ArachneLog "ERROR" "tools: ${tool} 업데이트 이력 없음 (${TOOLCHAIN_HISTORY_FILE})"
        return 1
    fi
    from=$(echo "${last}" | cut -f3)
    method=$(echo "${last}" | cut -f5)
    case "${method}" in
        go:*)
            go_bin=$(GoBinary) || { ArachneLog "ERROR" "tools: go 없음"; return 1; }
            pkg_path="${method#go:}"
            RunToolCmd "${go_bin}" install "${pkg_path%@*}@${from}" || return 1
            RecordToolHistory "${tool}" "$(echo "${last}" | cut -f4)" "${from}" "rollback:${method}"
            ToolsDone "tools: ${tool} → ${from} 되돌림"
            ;;
        pkg)
            ArachneLog "WARN" "tools: 시스템 패키지는 패키지 관리자 이력으로 되돌린다 — dnf history undo last / apt install ${tool}=${from}"
            ;;
        *)
            ArachneLog "WARN" "tools: ${tool} 자동 되돌리기 미지원 — 이전 버전 ${from} (이력: ${TOOLCHAIN_HISTORY_FILE})"
            ;;
    esac
}
