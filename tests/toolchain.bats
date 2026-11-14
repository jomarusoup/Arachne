#!/usr/bin/env bats
################################################################################
# FILE NAME   : toolchain.bats
# DESCRIPTION : arachne -t (lib/toolchain.sh) 개발 도구 점검·설치 흐름 검증.
#               실제 설치는 하지 않는다 — 카탈로그·패키지 관리자를 override 하고
#               dry-run 으로 실행할 명령만 확인한다.
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TMP_DIR=$(mktemp -d)
    export HOME="${TMP_DIR}"
    CATALOG="${TMP_DIR}/catalog.txt"
    export ARACHNE_TOOLS_CATALOG_FILE="${CATALOG}"
    export ARACHNE_TOOLS_PM="dnf"
    export ARACHNE_TOOLS_OS_ID="fedora"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#===============================================================================
# FUNCTION    : write_catalog
# DESCRIPTION : 테스트용 카탈로그 작성 (인자 한 개 = 한 줄)
#===============================================================================
write_catalog() {
    printf '%s\n' "$@" > "${CATALOG}"
}

@test "tools --check: 필수 그룹 누락 시 종료코드 1 과 누락 목록" {
    write_catalog "core|bash|-|-|-|pkg" "core|zz_missing_core|zz-pkg|zz-apt|zz-brew|pkg"
    run bash "${REPO_DIR}/install.sh" -t --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"누락: zz_missing_core"* ]] || false
    [[ "$output" == *"설치됨: bash"* ]] || false
}

@test "tools --check: 선택 그룹만 누락이면 종료코드 0" {
    write_catalog "core|bash|-|-|-|pkg" "go|zz_missing_go|-|-|-|go:example.com/zz@latest"
    run bash "${REPO_DIR}/install.sh" -t --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"누락 1건"* ]] || false
}

@test "tools: 모두 설치돼 있으면 OK" {
    write_catalog "core|bash|-|-|-|pkg" "search|ls/zz_alt|-|-|-|pkg"
    run bash "${REPO_DIR}/install.sh" -t --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"대상 도구 모두 설치됨"* ]] || false
}

@test "tools: 알 수 없는 그룹·인자는 거부" {
    write_catalog "core|bash|-|-|-|pkg"
    run bash "${REPO_DIR}/install.sh" -t --group nosuch
    [ "$status" -eq 1 ]
    [[ "$output" == *"알 수 없는 그룹"* ]] || false
    run bash "${REPO_DIR}/install.sh" -t --bogus
    [ "$status" -eq 1 ]
}

@test "tools: 비대화형에서 --yes 없으면 설치하지 않는다" {
    write_catalog "core|zz_missing_core|zz-pkg|zz-apt|zz-brew|pkg"
    run bash "${REPO_DIR}/install.sh" -t --dry-run < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"비대화형 실행"* ]] || false
    [[ "$output" != *"[DRY]"* ]] || false
}

@test "tools --yes --dry-run: dnf 패키지는 한 명령으로 묶어 설치" {
    write_catalog "core|zz_a|zz-pkg-a|-|-|pkg" "core|zz_b|zz-pkg-b|-|-|pkg"
    run bash "${REPO_DIR}/install.sh" -t --yes --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" =~ \[DRY\]\ (sudo\ )?dnf\ -y\ install\ zz-pkg-a\ zz-pkg-b ]] || false
}

@test "tools --yes --dry-run: apt 는 update 후 install, 미지원 패키지는 SKIP" {
    export ARACHNE_TOOLS_PM="apt"
    export ARACHNE_TOOLS_OS_ID="ubuntu"
    write_catalog "core|zz_a|-|zz-apt-a|-|pkg" "core|zz_b|zz-dnf-only|-|-|pkg"
    run bash "${REPO_DIR}/install.sh" -t --yes --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt-get update"* ]] || false
    [[ "$output" == *"apt-get install -y zz-apt-a"* ]] || false
    [[ "$output" == *"zz_b — apt 패키지 없음"* ]] || false
}

@test "tools --yes --dry-run: Go 린터는 go install 로 설치" {
    write_catalog "go|zz_golint|-|-|-|go:example.com/zz/cmd/zz_golint@latest"
    run bash "${REPO_DIR}/install.sh" -t --yes --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"go install example.com/zz/cmd/zz_golint@latest"* ]] || false
}

@test "tools --group: 지정 그룹만 점검·설치" {
    write_catalog "core|zz_core|zz-core|-|-|pkg" "db|zz_db|zz-db|-|-|pkg"
    run bash "${REPO_DIR}/install.sh" -t --yes --dry-run --group db
    [ "$status" -eq 0 ]
    [[ "$output" == *"zz-db"* ]] || false
    [[ "$output" != *"zz-core"* ]] || false
}

@test "tools --yes --dry-run: brew 의 Docker 는 cask, manual 항목은 안내만" {
    export ARACHNE_TOOLS_PM="brew"
    write_catalog "container|zz_docker|-|-|-|special:docker" "core|zz_gh|-|-|-|manual:https://example.invalid 안내"
    run bash "${REPO_DIR}/install.sh" -t --yes --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"brew install --cask docker"* ]] || false
    [[ "$output" == *"zz_gh 수동 설치 필요"* ]] || false
}

@test "tools --yes --dry-run: 같은 special 은 한 번만 실행" {
    export ARACHNE_TOOLS_PM="brew"
    write_catalog "container|zz_docker|-|-|-|special:docker" "container|zz_compose|-|-|-|special:docker"
    run bash "${REPO_DIR}/install.sh" -t --yes --dry-run
    [ "$status" -eq 0 ]
    [ "$(grep -c 'brew install --cask docker' <<< "$output")" -eq 1 ]
}

@test "tools: -i 끝에 비대화형 점검이 실행되고 ARACHNE_SKIP_TOOLS=1 로 생략" {
    export ARACHNE_EXTRAS_SCRIPT="${TMP_DIR}/fake-extras.sh"
    printf '#!/bin/bash\nexit 0\n' > "${ARACHNE_EXTRAS_SCRIPT}"
    write_catalog "core|bash|-|-|-|pkg"
    run bash "${REPO_DIR}/install.sh" -i < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"개발 도구 점검"* ]] || false
    ARACHNE_SKIP_TOOLS=1 run bash "${REPO_DIR}/install.sh" -i < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"개발 도구 점검 생략"* ]] || false
}

@test "tools: 도움말에 -t 옵션 노출" {
    run bash "${REPO_DIR}/install.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"-t, --tools"* ]] || false
}

@test "tools --yes --dry-run: RHEL 계열은 EPEL 패키지 전에 epel-release 설치" {
    export ARACHNE_TOOLS_OS_ID="rocky"
    mkdir -p "${TMP_DIR}/bin"
    printf '#!/bin/bash\nexit 1\n' > "${TMP_DIR}/bin/rpm"
    chmod +x "${TMP_DIR}/bin/rpm"
    write_catalog "core|zz_rg|ripgrep|-|-|pkg"
    PATH="${TMP_DIR}/bin:${PATH}" run bash "${REPO_DIR}/install.sh" -t --yes --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"dnf -y install epel-release"* ]] || false
    [[ "$output" == *"dnf -y install ripgrep"* ]] || false
}

@test "tools --yes --dry-run: Go 본체 설치는 네트워크 조회 없이 명령만 출력" {
    export ARACHNE_TOOLS_PM="dnf"
    write_catalog "go|zz_go|-|-|-|special:go"
    PATH="/usr/bin:/bin" run bash "${REPO_DIR}/install.sh" -t --yes --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"tar -C /usr/local -xzf"* ]] || false
    [[ "$output" == *"sha256 검증"* ]] || false
}

@test "tools: PATH 밖 ~/.cargo/bin · ~/.local/bin 설치본도 설치됨으로 인식" {
    mkdir -p "${HOME}/.cargo/bin" "${HOME}/.local/bin"
    printf '#!/bin/sh\n' > "${HOME}/.cargo/bin/zz_cargo_tool"
    printf '#!/bin/sh\n' > "${HOME}/.local/bin/zz_pip_tool"
    chmod +x "${HOME}/.cargo/bin/zz_cargo_tool" "${HOME}/.local/bin/zz_pip_tool"
    write_catalog "rust|zz_cargo_tool|-|-|-|special:rustup" "python|zz_pip_tool|-|-|-|pip:zz"
    run bash "${REPO_DIR}/install.sh" -t --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"대상 도구 모두 설치됨"* ]] || false
}
