################################################################################
# FILE NAME   : toolchain.sh
# DESCRIPTION : arachne 개발 도구 도메인 — 하네스가 쓰는 리눅스 도구·언어 툴체인
#               (Go·Rust·Docker 등)의 설치 여부를 그룹별로 점검하고, 사용자 확인 후
#               설치한다. install.sh 에서 source 되는 라이브러리로 단독 실행하지
#               않는다 (ArachneLog·ArachneSection 은 install.sh 가 정의).
################################################################################
# shellcheck shell=bash

#-------------------------------------------------------------------------------
# 도구 카탈로그 — "그룹|명령|dnf 패키지|apt 패키지|brew 패키지|방식"
#   명령  : command -v 로 검사할 이름. a/b 는 둘 중 하나만 있어도 설치됨으로 본다
#   패키지: 공백 구분 다중 패키지, "-" 는 해당 패키지 관리자 미지원
#   방식  : pkg(패키지 관리자) · go:<모듈> · pip:<패키지> · special:<이름> · manual:<안내>
# 테스트용 override: ARACHNE_TOOLS_CATALOG_FILE (같은 형식의 줄 목록 파일)
#-------------------------------------------------------------------------------
readonly TOOL_CATALOG=(
    "core|git|git|git|git|pkg"
    "core|jq|jq|jq|jq|pkg"
    "core|curl|curl|curl|curl|pkg"
    "core|python3|python3|python3|python@3|pkg"
    "core|node|nodejs|nodejs|node|pkg"
    "core|npm|npm|npm|-|pkg"
    "core|tmux|tmux|tmux|tmux|pkg"
    "core|bats|bats|bats|bats-core|pkg"
    "core|shellcheck|ShellCheck|shellcheck|shellcheck|pkg"
    "core|rg|ripgrep|ripgrep|ripgrep|pkg"
    "core|gh|-|-|-|manual:https://cli.github.com 의 저장소 등록 안내를 따른다"
    "core|claude|-|-|-|special:claude"
    "vm|mise|-|-|mise|special:mise"
    "search|fd/fdfind|fd-find|fd-find|fd|pkg"
    "search|fzf|fzf|fzf|fzf|pkg"
    "search|tree|tree|tree|tree|pkg"
    "cpp|gcc|gcc|gcc|gcc|pkg"
    "cpp|g++|gcc-c++|g++|-|pkg"
    "cpp|make|make|make|make|pkg"
    "cpp|cmake|cmake|cmake|cmake|pkg"
    "cpp|gdb|gdb|gdb|-|pkg"
    "cpp|valgrind|valgrind|valgrind|-|pkg"
    "cpp|strace|strace|strace|-|pkg"
    "cpp|ltrace|ltrace|ltrace|-|pkg"
    "cpp|perf|perf|@perf|-|pkg"
    "cpp|cppcheck|cppcheck|cppcheck|cppcheck|pkg"
    "cpp|clang-format|clang-tools-extra|clang-format|clang-format|pkg"
    "go|go|-|-|go|special:go"
    "go|goimports|-|-|-|go:golang.org/x/tools/cmd/goimports@latest"
    "go|staticcheck|-|-|-|go:honnef.co/go/tools/cmd/staticcheck@latest"
    "go|golangci-lint|-|-|-|go:github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest"
    "go|govulncheck|-|-|-|go:golang.org/x/vuln/cmd/govulncheck@latest"
    "rust|cargo|-|-|-|special:rustup"
    "python|ruff|-|-|-|pip:ruff"
    "python|mypy|-|-|-|pip:mypy"
    "container|docker|-|-|-|special:docker"
    "container|docker-compose|-|-|-|special:docker"
    "db|psql|postgresql|postgresql-client|libpq|pkg"
    "db|sqlite3|sqlite|sqlite3|sqlite|pkg"
)

# 그룹 처리 순서와 표시 이름 — core 를 먼저 처리해야 jq·curl 을 뒤 그룹이 쓴다
readonly TOOL_GROUPS=(core vm search cpp go rust python container db)

# RHEL 계열에서 EPEL 이 있어야 설치되는 dnf 패키지
readonly EPEL_PACKAGES=" bats ShellCheck ripgrep fd-find fzf cppcheck "

# 공식 배포처
readonly GO_DL_BASE="https://go.dev/dl"
readonly RUSTUP_URL="https://sh.rustup.rs"
readonly DOCKER_DL_BASE="https://download.docker.com/linux"

# 실행 상태 (ToolsCommand 가 초기화)
TOOLS_PM="none"
TOOLS_OS_ID="unknown"
TOOLS_OS_LIKE=""
TOOLS_SUDO=""
TOOLS_DRY_RUN=0
TOOLS_ASSUME_YES=0
TOOLS_CHECK_ONLY=0
TOOLS_SELECTED=""
TOOLS_FAIL_COUNT=0

#===============================================================================
# FUNCTION    : RunWithTimeout
# DESCRIPTION : 외부 명령에 시간 상한 적용 — macOS 는 timeout 이 없고 coreutils 의
#               gtimeout 만 있을 수 있다. 둘 다 없으면 상한 없이 실행한다.
#               (외부 명령 전용 — 셸 함수에는 쓰지 않는다)
# PARAMETERS  : int sec - 초
#               나머지  - 실행할 명령과 인자
#===============================================================================
RunWithTimeout() {
    local sec="$1"

    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout "${sec}" "$@"
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout "${sec}" "$@"
    else
        "$@"
    fi
}

#===============================================================================
# FUNCTION    : DnfQuery
# DESCRIPTION : 조회 전용 dnf 실행 — 출력 파싱을 위해 로캘을 C 로 고정하고(한국어
#               로캘은 'Important/Sec.' 를 '중요/보안.' 으로 번역), GPG 키 가져오기
#               같은 프롬프트는 거절(--assumeno)하며, 메타데이터를 받지 못한 저장소는
#               건너뛴다. stderr 는 DNF_QUERY_ERR 파일에 남긴다.
# PARAMETERS  : 나머지 - dnf 하위 명령과 인자
# RETURNED    : dnf 종료 코드
#===============================================================================
DNF_QUERY_ERR=""
DnfQuery() {
    [ -n "${DNF_QUERY_ERR}" ] || DNF_QUERY_ERR=$(mktemp)
    LC_ALL=C RunWithTimeout 300 dnf -q --assumeno --setopt=skip_if_unavailable=True "$@" \
        2>>"${DNF_QUERY_ERR}" </dev/null
}

#===============================================================================
# FUNCTION    : DnfRepoErrors
# DESCRIPTION : 직전 DnfQuery 들에서 실패한 저장소·거절된 GPG 키 목록 ('; ' 구분)
#===============================================================================
DnfRepoErrors() {
    [ -n "${DNF_QUERY_ERR}" ] && [ -f "${DNF_QUERY_ERR}" ] || return 0
    {
        grep -oE "for repo '[^']+'" "${DNF_QUERY_ERR}" 2>/dev/null | grep -oE "'[^']+'" | tr -d "'"
        # -q + --assumeno 에서는 오류 문구 대신 거절된 GPG 키 가져오기 블록만 남는다
        awk '/Importing GPG key/ { k = $4 } /Userid/ && k != "" { sub(/^[^:]*: */, ""); print "GPG키 " k " " $0; k = "" }' \
            "${DNF_QUERY_ERR}" 2>/dev/null
    } | sort -u | paste -sd ';' - | sed 's/;/; /g' || true
}

#===============================================================================
# FUNCTION    : ToolGroupLabel
# DESCRIPTION : 그룹 키를 사용자 표시 이름으로 변환
# PARAMETERS  : string group - 그룹 키
#===============================================================================
ToolGroupLabel() {
    case "$1" in
        core)      echo "필수 (하네스 동작)" ;;
        vm)        echo "버전 관리자 (mise — 프로젝트별 버전 고정)" ;;
        search)    echo "코드 조사" ;;
        cpp)       echo "C/C++ 시스템" ;;
        go)        echo "Go" ;;
        rust)      echo "Rust" ;;
        python)    echo "Python 린터" ;;
        container) echo "컨테이너 (Docker)" ;;
        db)        echo "DB 클라이언트" ;;
        *)         echo "$1" ;;
    esac
}

#===============================================================================
# FUNCTION    : ToolCatalogLines
# DESCRIPTION : 카탈로그 항목을 한 줄씩 출력 (테스트 override 반영)
#===============================================================================
ToolCatalogLines() {
    if [ -n "${ARACHNE_TOOLS_CATALOG_FILE:-}" ]; then
        grep -v '^[[:space:]]*\(#\|$\)' "${ARACHNE_TOOLS_CATALOG_FILE}"
        return 0
    fi
    printf '%s\n' "${TOOL_CATALOG[@]}"
}

#===============================================================================
# FUNCTION    : DetectToolsPlatform
# DESCRIPTION : 패키지 관리자·배포판·권한 상승 방법을 감지해 TOOLS_* 에 기록.
#               테스트용 override: ARACHNE_TOOLS_PM, ARACHNE_TOOLS_OS_ID
#===============================================================================
DetectToolsPlatform() {
    local os_release="/etc/os-release"

    if [ -r "${os_release}" ]; then
        # shellcheck source=/dev/null
        TOOLS_OS_ID=$(. "${os_release}" && echo "${ID:-unknown}")
        # shellcheck source=/dev/null
        TOOLS_OS_LIKE=$(. "${os_release}" && echo "${ID_LIKE:-}")
    elif [ "$(uname -s)" = "Darwin" ]; then
        TOOLS_OS_ID="macos"
    fi
    TOOLS_OS_ID="${ARACHNE_TOOLS_OS_ID:-${TOOLS_OS_ID}}"

    if [ -n "${ARACHNE_TOOLS_PM:-}" ]; then
        TOOLS_PM="${ARACHNE_TOOLS_PM}"
    elif command -v brew >/dev/null 2>&1 && [ "$(uname -s)" = "Darwin" ]; then
        TOOLS_PM="brew"
    elif command -v dnf >/dev/null 2>&1; then
        TOOLS_PM="dnf"
    elif command -v apt-get >/dev/null 2>&1; then
        TOOLS_PM="apt"
    elif command -v brew >/dev/null 2>&1; then
        TOOLS_PM="brew"
    fi

    #---------------------------------------------------------------------------
    # brew 는 사용자 권한으로 설치한다. 그 외에는 root 가 아니면 sudo 를 쓴다.
    #---------------------------------------------------------------------------
    if [ "${TOOLS_PM}" = "brew" ] || [ "$(id -u)" -eq 0 ]; then
        TOOLS_SUDO=""
    elif command -v sudo >/dev/null 2>&1; then
        TOOLS_SUDO="sudo"
    else
        TOOLS_SUDO="__none__"
    fi
}

#===============================================================================
# FUNCTION    : IsToolPresent
# DESCRIPTION : 도구 설치 여부 검사. docker-compose 는 compose 플러그인을 확인한다
# PARAMETERS  : string spec - 카탈로그 명령 칸 (a/b 형식 허용)
# RETURNED    : 0(설치됨) / 1(미설치)
#===============================================================================
IsToolPresent() {
    local spec="$1"
    local name

    if [ "${spec}" = "docker-compose" ]; then
        command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 && return 0
        command -v docker-compose >/dev/null 2>&1 && return 0
        return 1
    fi
    for name in ${spec//\// }; do
        command -v "${name}" >/dev/null 2>&1 && return 0
    done
    # 공식 tarball·go install 경로는 현재 셸 PATH 밖일 수 있다 (새 셸에서 반영)
    [ "${spec}" = "go" ] && [ -x /usr/local/go/bin/go ] && return 0
    [ -x "${HOME}/go/bin/${spec}" ] && return 0
    [ -x "${HOME}/.cargo/bin/${spec}" ] && return 0
    [ -x "${HOME}/.local/bin/${spec}" ] && return 0
    return 1
}

#===============================================================================
# FUNCTION    : ToolVersionNote
# DESCRIPTION : 버전 확인이 의미 있는 도구(go·docker)의 짧은 버전 문자열 출력
# PARAMETERS  : string spec - 카탈로그 명령 칸
#===============================================================================
ToolVersionNote() {
    case "$1" in
        go)     GoBinary >/dev/null && "$(GoBinary)" env GOVERSION 2>/dev/null ;;
        docker)
            if command -v rpm >/dev/null 2>&1 && rpm -q podman-docker >/dev/null 2>&1; then
                echo "podman-docker 에뮬레이션"
            else
                docker --version 2>/dev/null | awk '{print $3}' | tr -d ',' || true
            fi
            ;;
        docker-compose) docker compose version --short 2>/dev/null || true ;;
    esac
}

#===============================================================================
# FUNCTION    : RunToolCmd
# DESCRIPTION : 설치 명령 실행. dry-run 이면 명령만 출력한다
# PARAMETERS  : 나머지 인자 - 실행할 명령과 인자
# RETURNED    : 명령의 종료 코드 (dry-run 은 0)
#===============================================================================
RunToolCmd() {
    if [ "${TOOLS_DRY_RUN}" -eq 1 ]; then
        printf '[Arachne][DRY] %s\n' "$*"
        return 0
    fi
    ArachneLog "RUN" "$*"
    "$@"
}

#===============================================================================
# FUNCTION    : ToolsDone
# DESCRIPTION : 설치 완료 로그 — dry-run 에서는 실제로 설치되지 않았으므로 생략
# PARAMETERS  : string message - 완료 메시지
#===============================================================================
ToolsDone() {
    [ "${TOOLS_DRY_RUN}" -eq 1 ] && return 0
    ArachneLog "DONE" "$1"
}

#===============================================================================
# FUNCTION    : RunToolSudo
# DESCRIPTION : 권한 상승이 필요한 설치 명령 실행 (root·brew 는 그대로 실행)
# PARAMETERS  : 나머지 인자 - 실행할 명령과 인자
# RETURNED    : 명령의 종료 코드 / sudo 없으면 1
#===============================================================================
RunToolSudo() {
    if [ "${TOOLS_SUDO}" = "__none__" ]; then
        ArachneLog "ERROR" "tools: root 권한이 필요하지만 sudo 가 없습니다 — $*"
        return 1
    fi
    if [ -n "${TOOLS_SUDO}" ]; then
        RunToolCmd "${TOOLS_SUDO}" "$@"
    else
        RunToolCmd "$@"
    fi
}

#===============================================================================
# FUNCTION    : AskTools
# DESCRIPTION : y/N 확인. --yes 면 묻지 않고 승인, 비대화형이면 거부
# PARAMETERS  : string question - 질문 문구
# RETURNED    : 0(승인) / 1(거부)
#===============================================================================
AskTools() {
    local question="$1"
    local reply=""

    [ "${TOOLS_ASSUME_YES}" -eq 1 ] && return 0
    [ -t 0 ] || return 1
    read -r -p "[Arachne] ${question} [y/N]: " reply || true
    case "${reply}" in
        y|Y|yes|YES) return 0 ;;
        *)           return 1 ;;
    esac
}

#===============================================================================
# FUNCTION    : ResolvePackages
# DESCRIPTION : 카탈로그 패키지 칸을 현재 배포판 패키지명으로 변환 (@perf 등)
# PARAMETERS  : string pkgs - 카탈로그 패키지 칸
#===============================================================================
ResolvePackages() {
    local pkgs="$1"

    case "${pkgs}" in
        @perf)
            if [ "${TOOLS_OS_ID}" = "debian" ]; then
                echo "linux-perf"
            elif apt-cache show "linux-tools-$(uname -r)" >/dev/null 2>&1; then
                # 실행 중 커널(-aws·-azure 등)과 맞는 perf — generic 은 래퍼만 깔릴 수 있다
                echo "linux-tools-common linux-tools-$(uname -r)"
            else
                echo "linux-tools-common linux-tools-generic"
            fi
            ;;
        *) echo "${pkgs}" ;;
    esac
}

#===============================================================================
# FUNCTION    : IsRhelLike
# DESCRIPTION : EPEL 이 필요한 RHEL 계열(Rocky·Alma·CentOS·RHEL)인지 판정
# RETURNED    : 0(RHEL 계열) / 1(그 외 — Fedora 포함)
#===============================================================================
IsRhelLike() {
    [ "${TOOLS_OS_ID}" = "amzn" ] && return 1
    case " ${TOOLS_OS_ID} ${TOOLS_OS_LIKE} " in
        *" fedora "*) [ "${TOOLS_OS_ID}" != "fedora" ] ;;
        *" rhel "*|*" centos "*) return 0 ;;
        *) return 1 ;;
    esac
}

#===============================================================================
# FUNCTION    : EnsureEpel
# DESCRIPTION : RHEL 계열에서 EPEL 패키지가 포함되면 epel-release 를 먼저 설치
# PARAMETERS  : string pkgs - 설치할 dnf 패키지 목록 (공백 구분)
# RETURNED    : 0(준비됨·불필요) / 1(설치 실패)
#===============================================================================
EnsureEpel() {
    local pkgs="$1"
    local pkg
    local needs_epel=0

    IsRhelLike || return 0
    for pkg in ${pkgs}; do
        case "${EPEL_PACKAGES}" in *" ${pkg} "*) needs_epel=1 ;; esac
    done
    [ "${needs_epel}" -eq 1 ] || return 0
    rpm -q epel-release >/dev/null 2>&1 && return 0

    ArachneLog "STEP" "tools: EPEL 저장소 활성화 (bats·ShellCheck·ripgrep 등 제공)"
    if [ "${TOOLS_OS_ID}" = "rhel" ]; then
        # 정식 RHEL 은 기본 저장소에 epel-release 가 없다 — Fedora 프로젝트 배포 rpm 사용
        RunToolSudo dnf -y install \
            "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm"
    else
        RunToolSudo dnf -y install epel-release
    fi
}

#===============================================================================
# FUNCTION    : DropEpelPackages
# DESCRIPTION : 패키지 목록에서 EPEL 전용 패키지를 뺀 나머지 출력
# PARAMETERS  : string pkgs - 패키지 목록 (공백 구분)
#===============================================================================
DropEpelPackages() {
    local pkg
    local kept=""

    for pkg in $1; do
        case "${EPEL_PACKAGES}" in
            *" ${pkg} "*) ArachneLog "SKIP" "tools: ${pkg} — EPEL 없이 설치 불가" ;;
            *)            kept="${kept} ${pkg}" ;;
        esac
    done
    echo "${kept# }"
}

#===============================================================================
# FUNCTION    : InstallSystemPackages
# DESCRIPTION : 패키지 관리자로 여러 패키지를 한 번에 설치
# PARAMETERS  : string pkgs - 설치할 패키지 목록 (공백 구분)
# RETURNED    : 0(성공) / 1(실패)
#===============================================================================
InstallSystemPackages() {
    local pkgs="$1"
    local pkg_list=()

    read -r -a pkg_list <<< "${pkgs}"
    [ "${#pkg_list[@]}" -gt 0 ] || return 0

    case "${TOOLS_PM}" in
        dnf)
            if ! EnsureEpel "${pkgs}"; then
                ArachneLog "WARN" "tools: EPEL 준비 실패 — EPEL 전용 패키지만 빼고 계속 설치"
                read -r -a pkg_list <<< "$(DropEpelPackages "${pkgs}")"
                [ "${#pkg_list[@]}" -gt 0 ] || return 1
                RunToolSudo dnf -y install "${pkg_list[@]}"
                return 1
            fi
            RunToolSudo dnf -y install "${pkg_list[@]}"
            ;;
        apt)
            RunToolSudo apt-get update || return 1
            RunToolSudo apt-get install -y "${pkg_list[@]}"
            ;;
        brew)
            RunToolCmd brew install "${pkg_list[@]}"
            ;;
        *)
            ArachneLog "ERROR" "tools: 지원하는 패키지 관리자(dnf·apt·brew)가 없습니다 — 수동 설치: ${pkgs}"
            return 1
            ;;
    esac
}

#===============================================================================
# FUNCTION    : GoBinary
# DESCRIPTION : 사용할 go 실행 파일 경로 출력 (방금 설치한 /usr/local/go 포함)
# RETURNED    : 0(찾음) / 1(없음)
#===============================================================================
GoBinary() {
    if command -v go >/dev/null 2>&1; then
        command -v go
    elif [ -x /usr/local/go/bin/go ]; then
        echo /usr/local/go/bin/go
    else
        return 1
    fi
}

#===============================================================================
# FUNCTION    : Sha256Of
# DESCRIPTION : 파일의 sha256 해시 출력 (sha256sum·shasum 겸용)
# PARAMETERS  : string path - 대상 파일
#===============================================================================
Sha256Of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

#===============================================================================
# FUNCTION    : InstallGoOfficial
# DESCRIPTION : go.dev 공식 tarball 을 sha256 검증 후 /usr/local/go 에 설치.
#               이미 최신이면 건너뛰고, 구버전이면 업그레이드 여부를 묻는다.
#               brew 환경은 brew install go 를 쓴다.
# RETURNED    : 0(성공·불필요) / 1(실패·거부)
#===============================================================================
InstallGoOfficial() {
    local latest
    local current=""
    local go_os
    local go_arch
    local file_name
    local want_sha
    local got_sha
    local tmp_dir

    if [ "${TOOLS_PM}" = "brew" ]; then
        RunToolCmd brew install go
        return $?
    fi
    command -v curl >/dev/null 2>&1 || { ArachneLog "ERROR" "tools: Go 설치에 curl 이 필요합니다 (core 그룹)"; return 1; }
    command -v jq >/dev/null 2>&1 || { ArachneLog "ERROR" "tools: Go 체크섬 검증에 jq 가 필요합니다 (core 그룹)"; return 1; }

    if [ "${TOOLS_DRY_RUN}" -eq 1 ]; then
        # dry-run 은 네트워크 조회 없이 명령 형태만 보인다
        RunToolCmd curl -fsSL "https://go.dev/VERSION?m=text"
        RunToolCmd curl -fsSLo "/tmp/<최신>.linux-<arch>.tar.gz" "${GO_DL_BASE}/<최신>.linux-<arch>.tar.gz"
        RunToolCmd "sha256 검증 (${GO_DL_BASE}/?mode=json)"
        RunToolSudo rm -rf /usr/local/go.prev
        RunToolSudo mv /usr/local/go /usr/local/go.prev
        RunToolSudo tar -C /usr/local -xzf "/tmp/<최신>.linux-<arch>.tar.gz"
        return 0
    fi
    latest=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1) || { ArachneLog "ERROR" "tools: Go 최신 버전 조회 실패"; return 1; }
    current=$(GoOfficialVersion || true)
    if command -v go >/dev/null 2>&1 && [ "$(command -v go)" != "/usr/local/go/bin/go" ]; then
        ArachneLog "WARN" "tools: 배포판 go 가 PATH 에 있음 ($(command -v go)) — 공식본(/usr/local/go/bin)이 PATH 앞에 오도록 dotfiles 를 병합하세요"
    fi
    if [ "${current}" = "${latest}" ]; then
        ArachneLog "SKIP" "tools: Go ${current} — 이미 최신"
        return 0
    fi
    if [ -n "${current}" ] && [ "${TOOLS_GO_NO_PROMPT:-0}" -ne 1 ] \
        && ! AskTools "Go ${current} → ${latest} 로 업그레이드할까요?"; then
        ArachneLog "SKIP" "tools: Go ${current} 유지"
        return 0
    fi

    go_os=$(uname -s | tr '[:upper:]' '[:lower:]')
    case "$(uname -m)" in
        x86_64|amd64)  go_arch="amd64" ;;
        aarch64|arm64) go_arch="arm64" ;;
        *) ArachneLog "ERROR" "tools: 지원하지 않는 CPU 아키텍처 $(uname -m)"; return 1 ;;
    esac
    file_name="${latest}.${go_os}-${go_arch}.tar.gz"
    want_sha=$(curl -fsSL "${GO_DL_BASE}/?mode=json" \
        | jq -r --arg f "${file_name}" '.[].files[] | select(.filename == $f) | .sha256' | head -1)
    if [ -z "${want_sha}" ]; then
        ArachneLog "ERROR" "tools: ${file_name} 의 공식 체크섬을 찾지 못했습니다"
        return 1
    fi

    tmp_dir=$(mktemp -d)
    RunToolCmd curl -fsSLo "${tmp_dir}/${file_name}" "${GO_DL_BASE}/${file_name}" || { rm -rf "${tmp_dir}"; return 1; }
    got_sha=$(Sha256Of "${tmp_dir}/${file_name}")
    if [ "${got_sha}" != "${want_sha}" ]; then
        ArachneLog "ERROR" "tools: Go tarball 체크섬 불일치 — 설치 중단 (기대 ${want_sha}, 실제 ${got_sha})"
        rm -rf "${tmp_dir}"
        return 1
    fi
    ArachneLog "OK" "tools: sha256 검증 통과 (${file_name})"
    #---------------------------------------------------------------------------
    # 기존 설치본은 /usr/local/go.prev 로 보존 — arachne -t --rollback go 로 복귀
    #---------------------------------------------------------------------------
    if [ -d /usr/local/go ]; then
        RunToolSudo rm -rf /usr/local/go.prev && RunToolSudo mv /usr/local/go /usr/local/go.prev
    fi \
        && RunToolSudo tar -C /usr/local -xzf "${tmp_dir}/${file_name}"
    local rc=$?
    rm -rf "${tmp_dir}"
    if [ "${rc}" -eq 0 ]; then
        RecordToolHistory "go" "${current:-없음}" "${latest}" "special:go"
        ToolsDone "tools: $(/usr/local/go/bin/go version) — 새 셸에서 PATH 반영 (이전 버전: /usr/local/go.prev)"
    fi
    return "${rc}"
}

#===============================================================================
# FUNCTION    : InstallMise
# DESCRIPTION : 버전 관리자 mise 설치 — brew 또는 공식 설치 스크립트(파일로 받아
#               실행, ~/.local/bin/mise). 셸 연동은 dotfiles 의 ARACHNE 섹션이 한다.
# RETURNED    : 0(성공) / 1(실패)
#===============================================================================
InstallMise() {
    local tmp_dir
    local rc

    if [ "${TOOLS_PM}" = "brew" ]; then
        RunToolCmd brew install mise
        return $?
    fi
    if [ "${TOOLS_DRY_RUN}" -eq 1 ]; then
        RunToolCmd curl -fsSLo /tmp/mise-install.sh "${MISE_INSTALL_URL}"
        RunToolCmd sh /tmp/mise-install.sh
        return 0
    fi
    tmp_dir=$(mktemp -d)
    RunToolCmd curl -fsSLo "${tmp_dir}/mise-install.sh" "${MISE_INSTALL_URL}" \
        && RunToolCmd sh "${tmp_dir}/mise-install.sh"
    rc=$?
    rm -rf "${tmp_dir}"
    [ "${rc}" -eq 0 ] && ToolsDone "tools: mise 설치 완료 — 새 셸에서 활성화 (프로젝트의 mise.toml·.tool-versions 자동 적용)"
    return "${rc}"
}

#===============================================================================
# FUNCTION    : InstallRustup
# DESCRIPTION : rustup 공식 설치 스크립트를 내려받아 실행 (파이프 실행 대신 파일로)
# RETURNED    : 0(성공) / 1(실패)
#===============================================================================
InstallRustup() {
    local tmp_dir

    if [ "${TOOLS_DRY_RUN}" -eq 1 ]; then
        RunToolCmd curl --proto '=https' --tlsv1.2 -sSfo /tmp/rustup-init.sh "${RUSTUP_URL}"
        RunToolCmd sh /tmp/rustup-init.sh -y
        return 0
    fi
    tmp_dir=$(mktemp -d)
    RunToolCmd curl --proto '=https' --tlsv1.2 -sSfo "${tmp_dir}/rustup-init.sh" "${RUSTUP_URL}" \
        && RunToolCmd sh "${tmp_dir}/rustup-init.sh" -y
    local rc=$?
    rm -rf "${tmp_dir}"
    [ "${rc}" -eq 0 ] && ToolsDone "tools: rustup 설치 완료 — 새 셸 또는 '. ~/.cargo/env' 로 PATH 반영"
    return "${rc}"
}

#===============================================================================
# FUNCTION    : ResolveDockerConflict
# DESCRIPTION : docker-ce 와 충돌하는 패키지(podman-docker·docker.io 등) 확인 후
#               제거 동의를 받는다
# RETURNED    : 0(충돌 없음·제거함) / 1(사용자 거부·실패)
#===============================================================================
ResolveDockerConflict() {
    local conflicts=""
    local pkg

    case "${TOOLS_PM}" in
        dnf)
            for pkg in podman-docker docker docker-common docker-engine; do
                rpm -q "${pkg}" >/dev/null 2>&1 && conflicts="${conflicts} ${pkg}"
            done
            ;;
        apt)
            for pkg in docker.io docker-compose docker-doc podman-docker; do
                dpkg -s "${pkg}" >/dev/null 2>&1 && conflicts="${conflicts} ${pkg}"
            done
            ;;
    esac
    conflicts="${conflicts# }"
    [ -z "${conflicts}" ] && return 0

    ArachneLog "WARN" "tools: Docker CE 와 충돌하는 패키지 설치됨 — ${conflicts}"
    if ! AskTools "${conflicts} 를 제거하고 공식 Docker CE 를 설치할까요? (podman 자체는 유지)"; then
        ArachneLog "SKIP" "tools: 기존 Docker 대체 패키지 유지 — Docker CE 설치 생략"
        return 1
    fi
    # shellcheck disable=SC2086
    case "${TOOLS_PM}" in
        dnf) RunToolSudo dnf -y remove ${conflicts} ;;
        apt) RunToolSudo apt-get remove -y ${conflicts} ;;
    esac
}

#===============================================================================
# FUNCTION    : AddDockerRepo
# DESCRIPTION : 공식 Docker CE 패키지 저장소 등록 (dnf·apt)
# RETURNED    : 0(성공) / 1(미지원 배포판·실패)
#===============================================================================
AddDockerRepo() {
    local repo_os
    local codename
    local arch

    case "${TOOLS_PM}" in
        dnf)
            case "${TOOLS_OS_ID}" in
                fedora) repo_os="fedora" ;;
                centos) repo_os="centos" ;;
                *)      repo_os="rhel" ;;
            esac
            RunToolSudo dnf -y install dnf-plugins-core || return 1
            if dnf --version 2>/dev/null | grep -q 'dnf5'; then
                RunToolSudo dnf config-manager addrepo --overwrite \
                    --from-repofile="${DOCKER_DL_BASE}/${repo_os}/docker-ce.repo"
            else
                RunToolSudo dnf config-manager --add-repo "${DOCKER_DL_BASE}/${repo_os}/docker-ce.repo"
            fi
            ;;
        apt)
            case "${TOOLS_OS_ID}" in
                ubuntu|debian) repo_os="${TOOLS_OS_ID}" ;;
                *) ArachneLog "ERROR" "tools: Docker 공식 apt 저장소는 ubuntu·debian 만 지원 (${TOOLS_OS_ID})"; return 1 ;;
            esac
            # shellcheck source=/dev/null
            codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")
            arch=$(dpkg --print-architecture)
            RunToolSudo apt-get update || return 1
            RunToolSudo apt-get install -y ca-certificates curl || return 1
            RunToolSudo install -m 0755 -d /etc/apt/keyrings || return 1
            RunToolSudo curl -fsSL "${DOCKER_DL_BASE}/${repo_os}/gpg" -o /etc/apt/keyrings/docker.asc || return 1
            RunToolSudo chmod a+r /etc/apt/keyrings/docker.asc || return 1
            if [ "${TOOLS_DRY_RUN}" -eq 1 ]; then
                RunToolCmd "write /etc/apt/sources.list.d/docker.list (${repo_os} ${codename} stable)"
            else
                printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] %s/%s %s stable\n' \
                    "${arch}" "${DOCKER_DL_BASE}" "${repo_os}" "${codename}" \
                    | RunToolSudo tee /etc/apt/sources.list.d/docker.list >/dev/null || return 1
            fi
            RunToolSudo apt-get update
            ;;
        *)
            ArachneLog "ERROR" "tools: Docker 저장소 등록 미지원 패키지 관리자 (${TOOLS_PM})"
            return 1
            ;;
    esac
}

#===============================================================================
# FUNCTION    : InstallDockerOfficial
# DESCRIPTION : 공식 저장소에서 Docker CE + buildx·compose 플러그인 설치 후
#               서비스 활성화. docker 그룹 추가는 root 권한 상당이라 따로 묻는다.
#               macOS 는 brew cask(Docker Desktop).
# RETURNED    : 0(성공) / 1(실패·거부)
#===============================================================================
InstallDockerOfficial() {
    local user_name="${USER:-$(id -un)}"

    if [ "${TOOLS_PM}" = "brew" ]; then
        RunToolCmd brew install --cask docker
        return $?
    fi
    ResolveDockerConflict || return 1
    AddDockerRepo || return 1
    InstallSystemPackages "docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" || return 1
    if command -v systemctl >/dev/null 2>&1; then
        RunToolSudo systemctl enable --now docker || ArachneLog "WARN" "tools: docker 서비스 시작 실패 — systemctl status docker 확인"
    fi
    if [ "$(id -u)" -ne 0 ] \
        && AskTools "${user_name} 를 docker 그룹에 추가할까요? (sudo 없이 docker 실행 — root 권한과 같은 수준)"; then
        RunToolSudo usermod -aG docker "${user_name}" \
            && ToolsDone "tools: docker 그룹 추가 — 다시 로그인해야 반영"
    fi
    return 0
}

#===============================================================================
# FUNCTION    : InstallPipTool
# DESCRIPTION : Python CLI 도구 설치 — pipx 우선, 없으면 pip --user
# PARAMETERS  : string pkg - PyPI 패키지명
# RETURNED    : 0(성공) / 1(실패)
#===============================================================================
InstallPipTool() {
    local pkg="$1"

    if command -v pipx >/dev/null 2>&1; then
        RunToolCmd pipx install "${pkg}"
        return $?
    fi
    command -v python3 >/dev/null 2>&1 || { ArachneLog "ERROR" "tools: ${pkg} 설치에 python3 가 필요합니다"; return 1; }
    if ! RunToolCmd python3 -m pip install --user "${pkg}"; then
        ArachneLog "WARN" "tools: pip 설치 실패 — 배포판이 시스템 pip 를 막았다면(PEP 668) pipx 를 먼저 설치하세요"
        return 1
    fi
}

#===============================================================================
# FUNCTION    : InstallToolGroup
# DESCRIPTION : 한 그룹의 누락 도구를 방식별로 묶어 설치
# PARAMETERS  : string group   - 그룹 키
#               string entries - 누락 카탈로그 줄 (줄바꿈 구분)
#===============================================================================
InstallToolGroup() {
    local group="$1"
    local entries="$2"
    local line
    local spec
    local dnf_pkg
    local apt_pkg
    local brew_pkg
    local method
    local pkg
    local pkgs=""
    local go_mods=""
    local specials=""
    local go_bin
    local mod
    local special

    #---------------------------------------------------------------------------
    # 1) 방식별 분류 — 시스템 패키지는 한 번의 설치 명령으로 묶는다
    #---------------------------------------------------------------------------
    while IFS='|' read -r _ spec dnf_pkg apt_pkg brew_pkg method; do
        [ -n "${spec}" ] || continue
        case "${method}" in
            pkg)
                case "${TOOLS_PM}" in
                    dnf)  pkg="${dnf_pkg}" ;;
                    apt)  pkg=$(ResolvePackages "${apt_pkg}") ;;
                    brew) pkg="${brew_pkg}" ;;
                    *)    pkg="-" ;;
                esac
                if [ "${pkg}" = "-" ]; then
                    ArachneLog "SKIP" "tools: ${spec} — ${TOOLS_PM} 패키지 없음 (이 플랫폼 미지원)"
                else
                    pkgs="${pkgs} ${pkg}"
                fi
                ;;
            go:*)      go_mods="${go_mods} ${method#go:}" ;;
            pip:*)     InstallPipTool "${method#pip:}" || TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1)) ;;
            special:*)
                case " ${specials} " in *" ${method#special:} "*) ;; *) specials="${specials} ${method#special:}" ;; esac
                ;;
            manual:*)  ArachneLog "WARN" "tools: ${spec} 수동 설치 필요 — ${method#manual:}" ;;
        esac
    done <<< "${entries}"

    #---------------------------------------------------------------------------
    # 2) 특수 설치(go 본체 등)를 먼저 — go install 이 방금 깐 go 를 쓰도록
    #---------------------------------------------------------------------------
    for special in ${specials}; do
        case "${special}" in
            go)     InstallGoOfficial ;;
            rustup) InstallRustup ;;
            docker) InstallDockerOfficial ;;
            mise)   InstallMise ;;
            claude) ArachneLog "WARN" "tools: claude 수동 설치 필요 — https://claude.com/claude-code (설치 후 갱신은 arachne -t --update)" ;;
        esac || TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1))
    done

    if [ -n "${pkgs# }" ]; then
        InstallSystemPackages "${pkgs# }" || TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1))
    fi

    if [ -n "${go_mods}" ]; then
        if go_bin=$(GoBinary) || [ "${TOOLS_DRY_RUN}" -eq 1 ]; then
            go_bin="${go_bin:-go}"
            for mod in ${go_mods}; do
                RunToolCmd "${go_bin}" install "${mod}" || TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1))
            done
        else
            ArachneLog "ERROR" "tools: ${group} — go 가 없어 go install 도구를 설치하지 못했습니다"
            TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1))
        fi
    fi
}

#===============================================================================
# FUNCTION    : ReportToolGroups
# DESCRIPTION : 선택된 그룹의 도구별 설치 여부 표 출력, 누락을 MISSING_<그룹> 에 기록
# RETURNED    : 누락 도구 총 개수를 TOOLS_MISSING_TOTAL 에 기록
#===============================================================================
ReportToolGroups() {
    local group
    local line
    local spec
    local note
    local present_list
    local missing_list
    local catalog
    local missing_var

    catalog=$(ToolCatalogLines)
    TOOLS_MISSING_TOTAL=0
    for group in "${TOOL_GROUPS[@]}"; do
        IsGroupSelected "${group}" || continue
        present_list=""
        missing_list=""
        missing_var="MISSING_${group}"
        printf -v "${missing_var}" '%s' ""
        while IFS= read -r line; do
            [ "${line%%|*}" = "${group}" ] || continue
            spec=$(echo "${line}" | cut -d'|' -f2)
            if IsToolPresent "${spec}"; then
                note=$(ToolVersionNote "${spec}") || note=""
                present_list="${present_list} ${spec}${note:+(${note})}"
            else
                missing_list="${missing_list} ${spec}"
                printf -v "${missing_var}" '%s%s\n' "${!missing_var}" "${line}"
                TOOLS_MISSING_TOTAL=$((TOOLS_MISSING_TOTAL + 1))
            fi
        done <<< "${catalog}"
        [ -n "${present_list}${missing_list}" ] || continue
        if [ -z "${missing_list}" ]; then
            ArachneLog "OK" "$(ToolGroupLabel "${group}"):${present_list}"
        else
            ArachneLog "WARN" "$(ToolGroupLabel "${group}") — 누락:${missing_list}${present_list:+ / 설치됨:${present_list}}"
            ReportMissingImpact "${missing_list}"
        fi
    done
}

#===============================================================================
# FUNCTION    : ReportMissingImpact
# DESCRIPTION : 누락 도구가 하네스 기능에 주는 영향 출력 (install.sh 의
#               PREFLIGHT_TOOLS "명령:영향" 목록을 재사용 — 문구 단일 출처)
# PARAMETERS  : string missing_list - 누락 도구 이름 (공백 구분)
#===============================================================================
ReportMissingImpact() {
    local name
    local entry

    for name in $1; do
        for entry in ${PREFLIGHT_TOOLS[@]+"${PREFLIGHT_TOOLS[@]}"}; do
            [ "${entry%%:*}" = "${name%%/*}" ] || continue
            printf '[Arachne][WARN]     └ %s: %s\n' "${name%%/*}" "${entry#*:}" >&2
        done
    done
}

#===============================================================================
# FUNCTION    : IsGroupSelected
# DESCRIPTION : --group 지정 여부에 따라 그룹 포함 판정 (미지정이면 전체)
# PARAMETERS  : string group - 그룹 키
# RETURNED    : 0(포함) / 1(제외)
#===============================================================================
IsGroupSelected() {
    [ -z "${TOOLS_SELECTED}" ] && return 0
    case ",${TOOLS_SELECTED}," in *",$1,"*) return 0 ;; esac
    return 1
}

#===============================================================================
# FUNCTION    : ToolsUsage
# DESCRIPTION : arachne -t 사용법 출력
#===============================================================================
ToolsUsage() {
    echo "Usage: arachne -t [--check] [--yes] [--dry-run] [--group G1,G2]"
    echo "                  [--update [--allow-major] [--all-system] [--project DIR]]"
    echo "                  [--rollback TOOL]"
    echo ""
    echo "  하네스가 쓰는 개발 도구를 그룹별로 점검하고, 누락 그룹마다 설치 여부를 묻는다."
    echo "  --check      점검만 (필수 그룹 누락 시 종료코드 1)"
    echo "  --yes        묻지 않고 누락 도구 모두 설치 (Docker 충돌 패키지 제거 포함)"
    echo "  --dry-run    실행할 설치 명령만 출력"
    echo "  --group G    대상 그룹 한정: ${TOOL_GROUPS[*]}"
    echo "  --update     설치된 도구 버전 점검·갱신. 판정: 하네스 필수 미달 Y · 패치 Y ·"
    echo "               마이너/메이저 N · 프로젝트 고정 범위 유지 · 단일 버전 도구 충돌은 보고만"
    echo "  --allow-major --yes 와 함께 마이너·메이저 업데이트도 승인"
    echo "  --all-system --update 와 함께 시스템 전체 패키지 업그레이드 (기본 N)"
    echo "  --project D  고정 버전을 읽을 프로젝트 (기본: 현재 git 저장소)"
    echo "               근거: .arachne/toolchain.lock > mise.toml > .tool-versions > go.mod · rust-toolchain.toml"
    echo "  --rollback T 직전 업데이트 되돌리기 (go: /usr/local/go.prev, go 린터: 이력 버전)"
    echo ""
    echo "  설치 방식: 시스템 도구는 dnf/apt/brew, Go 는 go.dev 공식 tarball(sha256 검증),"
    echo "            Go 린터는 go install, Rust 는 rustup, Docker 는 공식 Docker CE 저장소."
}

#===============================================================================
# FUNCTION    : ToolsCommand
# DESCRIPTION : arachne -t 진입점 — 옵션 해석 → 점검 → 그룹별 확인 → 설치 → 재점검
# PARAMETERS  : 나머지 인자 - --check · --yes · --dry-run · --group G
# RETURNED    : 0(정상) / 1(점검 모드에서 필수 누락, 또는 설치 실패)
#===============================================================================
ToolsCommand() {
    local group
    local entries
    local missing_names
    local valid
    local missing_var

    TOOLS_DRY_RUN="${ARACHNE_TOOLS_DRYRUN:-0}"
    TOOLS_ASSUME_YES=0
    TOOLS_CHECK_ONLY=0
    TOOLS_SELECTED=""
    TOOLS_FAIL_COUNT=0
    TOOLS_UPDATE_MODE=0
    TOOLS_ALLOW_MAJOR=0
    TOOLS_ALL_SYSTEM=0
    TOOLS_PROJECT_DIR=""
    TOOLS_ROLLBACK=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --check)    TOOLS_CHECK_ONLY=1 ;;
            --yes|-y)   TOOLS_ASSUME_YES=1 ;;
            --dry-run)  TOOLS_DRY_RUN=1 ;;
            --group=*)  TOOLS_SELECTED="${1#--group=}" ;;
            --group)    shift || true; TOOLS_SELECTED="${1:-}" ;;
            --update)      TOOLS_UPDATE_MODE=1 ;;
            --allow-major) TOOLS_ALLOW_MAJOR=1 ;;
            --all-system)  TOOLS_ALL_SYSTEM=1 ;;
            --project=*)   TOOLS_PROJECT_DIR="${1#--project=}" ;;
            --project)     shift || true; TOOLS_PROJECT_DIR="${1:-}" ;;
            --rollback=*)  TOOLS_ROLLBACK="${1#--rollback=}" ;;
            --rollback)    shift || true; TOOLS_ROLLBACK="${1:-}" ;;
            -h|--help)  ToolsUsage; return 0 ;;
            *)          ArachneLog "ERROR" "tools: 알 수 없는 인자 '$1'"; ToolsUsage >&2; return 1 ;;
        esac
        shift || true
    done
    for group in ${TOOLS_SELECTED//,/ }; do
        valid=0
        case " ${TOOL_GROUPS[*]} " in *" ${group} "*) valid=1 ;; esac
        if [ "${valid}" -eq 0 ]; then
            ArachneLog "ERROR" "tools: 알 수 없는 그룹 '${group}' (${TOOL_GROUPS[*]})"
            return 1
        fi
    done

    DetectToolsPlatform
    if [ -n "${TOOLS_ROLLBACK}" ]; then
        RunToolsRollback "${TOOLS_ROLLBACK}"
        return $?
    fi
    if [ -z "${TOOLS_PROJECT_DIR}" ]; then
        TOOLS_PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || true)
    fi
    if [ -n "${TOOLS_PROJECT_DIR}" ] && [ ! -d "${TOOLS_PROJECT_DIR}" ]; then
        ArachneLog "ERROR" "tools: 프로젝트 디렉터리 없음 — ${TOOLS_PROJECT_DIR}"
        return 1
    fi

    ArachneSection "개발 도구 점검 (${TOOLS_OS_ID} · 패키지 관리자 ${TOOLS_PM})"
    ReportToolGroups

    if [ "${TOOLS_MISSING_TOTAL}" -eq 0 ]; then
        ArachneLog "OK" "tools: 대상 도구 모두 설치됨"
        [ "${TOOLS_UPDATE_MODE}" -eq 1 ] && RunToolsUpdateStep
        return "$(ToolsExitCode)"
    fi
    if [ "${TOOLS_CHECK_ONLY}" -eq 1 ]; then
        ArachneLog "WARN" "tools: 누락 ${TOOLS_MISSING_TOTAL}건 — 설치: arachne -t"
        [ "${TOOLS_UPDATE_MODE}" -eq 1 ] && RunToolsUpdateStep
        if IsGroupSelected core && [ -n "${MISSING_core:-}" ]; then
            return 1
        fi
        return 0
    fi
    if [ "${TOOLS_ASSUME_YES}" -eq 0 ] && [ ! -t 0 ]; then
        ArachneLog "WARN" "tools: 비대화형 실행 — 누락 ${TOOLS_MISSING_TOTAL}건 설치 생략 (arachne -t --yes 로 설치)"
        [ "${TOOLS_UPDATE_MODE}" -eq 1 ] && RunToolsUpdateStep
        return "$(ToolsExitCode)"
    fi

    #---------------------------------------------------------------------------
    # 그룹 단위 확인 후 설치 — core 부터 순서대로 (뒤 그룹이 curl·jq 를 쓴다)
    #---------------------------------------------------------------------------
    for group in "${TOOL_GROUPS[@]}"; do
        IsGroupSelected "${group}" || continue
        missing_var="MISSING_${group}"
        entries="${!missing_var:-}"
        [ -n "${entries}" ] || continue
        missing_names=$(echo "${entries}" | cut -d'|' -f2 | tr '\n' ' ')
        if AskTools "$(ToolGroupLabel "${group}") 누락 도구 설치할까요? — ${missing_names% }"; then
            ArachneSection "$(ToolGroupLabel "${group}") 설치"
            InstallToolGroup "${group}" "${entries}"
        else
            ArachneLog "SKIP" "tools: $(ToolGroupLabel "${group}") 설치 생략"
        fi
    done

    if [ "${TOOLS_DRY_RUN}" -eq 0 ]; then
        hash -r
        ArachneSection "설치 후 재점검"
        ReportToolGroups
    fi
    [ "${TOOLS_UPDATE_MODE}" -eq 1 ] && RunToolsUpdateStep
    return "$(ToolsExitCode)"
}

#===============================================================================
# FUNCTION    : RunToolsUpdateStep
# DESCRIPTION : --update 단계 실행 (toolchain-update.sh) — 실패해도 흐름 유지
#===============================================================================
RunToolsUpdateStep() {
    RunToolsUpdate || TOOLS_FAIL_COUNT=$((TOOLS_FAIL_COUNT + 1))
    return 0
}

#===============================================================================
# FUNCTION    : ToolsExitCode
# DESCRIPTION : 누적 실패 수로 최종 종료 코드 결정·요약 출력 (stdout 은 코드만)
#===============================================================================
ToolsExitCode() {
    if [ "${TOOLS_FAIL_COUNT}" -gt 0 ]; then
        ArachneLog "ERROR" "tools: 실패 ${TOOLS_FAIL_COUNT}건 — 위 로그 확인" >&2
        echo 1
        return 0
    fi
    printf '[Arachne][DONE] tools: 완료\n' >&2
    echo 0
}

#===============================================================================
# FUNCTION    : MaybeRunTools
# DESCRIPTION : -i 설치 끝에 개발 도구 점검. 대화형이면 그룹별 설치 여부를 묻고,
#               비대화형이면 점검 결과만 출력한다. 실패해도 설치 결과에 영향 없음.
#               ARACHNE_SKIP_TOOLS=1 이면 건너뛴다.
#===============================================================================
MaybeRunTools() {
    if [ "${ARACHNE_SKIP_TOOLS:-0}" -eq 1 ]; then
        ArachneLog "SKIP" "tools: ARACHNE_SKIP_TOOLS=1 — 개발 도구 점검 생략"
        return 0
    fi
    if [ -t 0 ]; then
        ToolsCommand || true
    else
        ToolsCommand --check || true
    fi
}
