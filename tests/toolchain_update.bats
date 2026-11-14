#!/usr/bin/env bats
################################################################################
# FILE NAME   : toolchain_update.bats
# DESCRIPTION : arachne -t --update 버전 판정(lib/toolchain-update.sh)과
#               install 재실행 시 "이미 최신이면 다시 하지 않음" 동작 검증
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TMP_DIR=$(mktemp -d)
    export HOME="${TMP_DIR}"
    PROJ="${TMP_DIR}/proj"
    mkdir -p "${PROJ}/.arachne"

    #---------------------------------------------------------------------------
    # 라이브러리 단위 테스트용 — install.sh 가 정의하는 로그 함수만 대체
    #---------------------------------------------------------------------------
    ArachneLog() { printf '[Arachne][%s] %s\n' "$1" "$2"; }
    ArachneSection() { printf '[Arachne] %s\n' "$1"; }
    # shellcheck source=/dev/null
    source "${REPO_DIR}/lib/toolchain.sh"
    # shellcheck source=/dev/null
    source "${REPO_DIR}/lib/toolchain-update.sh"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# 버전 비교
#-------------------------------------------------------------------------------
@test "VersionLevel: 패치·마이너·메이저·동일·더새것 구분" {
    [ "$(VersionLevel go1.27.3 go1.27.5)" = "patch" ]
    [ "$(VersionLevel v2.10.1 v2.15.0)" = "minor" ]
    [ "$(VersionLevel 3.26.5 4.0.0)" = "major" ]
    [ "$(VersionLevel 1:2.34.1-1ubuntu1 2.34.1)" = "same" ]
    [ "$(VersionLevel 2.1.325 2.1.300)" = "newer" ]
    [ "$(VersionLevel '' 1.0)" = "unknown" ]
}

@test "VersionMatches: 접두·.x·정확·>= 범위" {
    VersionMatches 2.10.3 2.10
    VersionMatches 2.10.3 2.10.x
    VersionMatches v2.10.1 2.10.1
    ! VersionMatches 2.11.0 2.10 || false
    VersionMatches go1.27.3 '>=1.25'
    ! VersionMatches 1.24.0 '>=1.25' || false
}

#-------------------------------------------------------------------------------
# 프로젝트 고정 읽기
#-------------------------------------------------------------------------------
@test "ReadProjectPin: toolchain.lock 이 mise.toml 보다 우선" {
    printf 'cmake=3.26.x\n' > "${PROJ}/.arachne/toolchain.lock"
    printf '[tools]\ncmake = "3.31"\n' > "${PROJ}/mise.toml"
    [ "$(ReadProjectPin cmake "${PROJ}")" = "3.26.x|lock" ]
}

@test "ReadProjectPin: mise.toml · .tool-versions · go.mod · rust-toolchain.toml" {
    printf '[tools]\nnode = "22"\n' > "${PROJ}/mise.toml"
    printf 'python 3.12.4\n' > "${PROJ}/.tool-versions"
    printf 'module x\n\ngo 1.25\n\ntoolchain go1.25.4\n' > "${PROJ}/go.mod"
    printf '[toolchain]\nchannel = "1.80.0"\n' > "${PROJ}/rust-toolchain.toml"
    [ "$(ReadProjectPin node "${PROJ}")" = "22|mise" ]
    [ "$(ReadProjectPin python "${PROJ}")" = "3.12.4|mise" ]
    [ "$(ReadProjectPin go "${PROJ}")" = "go1.25.4|go-toolchain" ]
    [ "$(ReadProjectPin cargo "${PROJ}")" = "1.80.0|rustup" ]
    [ -z "$(ReadProjectPin valgrind "${PROJ}")" ]
}

#-------------------------------------------------------------------------------
# 판정
#-------------------------------------------------------------------------------
@test "Decision: 고정 없음 — 패치 Y, 마이너 N, 동일 skip" {
    [[ "$(ToolUpdateDecision cmake 3.26.5 3.26.6 '' 0)" == "update|Y|"* ]] || false
    [[ "$(ToolUpdateDecision cmake 3.26.5 3.31.0 '' 0)" == "update|N|"* ]] || false
    [[ "$(ToolUpdateDecision cmake 3.26.5 3.26.5 '' 0)" == "skip|"* ]] || false
}

@test "Decision: 하네스 필수 미달은 버전과 무관하게 Y" {
    [[ "$(ToolUpdateDecision golangci-lint v1.64.8 v2.15.0 '' 1)" == "update|Y|하네스 필수"* ]] || false
}

@test "Decision: 단일 버전 도구 고정 범위 안 + 최신이 범위 밖이면 유지" {
    run ToolUpdateDecision cmake 3.26.5 3.31.0 "3.26.x|lock" 0
    [[ "$output" == "skip|-|프로젝트 고정 3.26.x 유지"* ]] || false
}

@test "Decision: 단일 버전 도구 고정과 설치가 다르면 충돌 보고만" {
    run ToolUpdateDecision valgrind 3.21.0 3.23.0 "3.19.x|lock" 0
    [[ "$output" == "conflict|"* ]] || false
}

@test "Decision: 버전 관리자 고정은 전역 판정에 영향 없음 (전역은 기준선 규칙)" {
    run ToolUpdateDecision go go1.27.3 go1.27.5 "go1.25.4|go-toolchain" 0
    [[ "$output" == "update|Y|"*"go-toolchain 가 별도 관리"* ]] || false
}

@test "Decision: Go 보안 지원 종료 라인은 마이너 차이여도 Y" {
    [[ "$(ToolUpdateDecision go go1.24.9 go1.27.3 '' 0)" == "update|Y|Go go1.24.9 보안 지원 종료"* ]] || false
    [[ "$(ToolUpdateDecision go go1.26.9 go1.27.3 '' 0)" == "update|N|"* ]] || false
}

@test "AskDefault: --yes 는 기본 Y 만 승인, --allow-major 면 기본 N 도 승인" {
    TOOLS_ASSUME_YES=1
    TOOLS_ALLOW_MAJOR=0
    AskDefault "q" Y
    ! AskDefault "q" N || false
    TOOLS_ALLOW_MAJOR=1
    AskDefault "q" N
}

#-------------------------------------------------------------------------------
# CLI 통합
#-------------------------------------------------------------------------------
@test "tools --rollback: 이력 없으면 실패 메시지" {
    run bash "${REPO_DIR}/install.sh" -t --rollback zz_tool
    [ "$status" -eq 1 ]
    [[ "$output" == *"업데이트 이력 없음"* ]] || false
}

@test "tools --rollback: go 린터는 이력의 이전 버전으로 재설치 (dry-run)" {
    mkdir -p "${HOME}/.claude/arachne"
    printf '2026-11-14 10:00:00\tstaticcheck\tv0.7.0\tv0.8.2\tgo:honnef.co/go/tools/cmd/staticcheck@latest\n' \
        > "${HOME}/.claude/arachne/toolchain-history.log"
    ARACHNE_TOOLS_DRYRUN=1 run bash "${REPO_DIR}/install.sh" -t --rollback staticcheck
    [ "$status" -eq 0 ]
    [[ "$output" == *"install honnef.co/go/tools/cmd/staticcheck@v0.7.0"* ]] || false
}

@test "tools --update --check: 고정 근거 프로젝트를 표시하고 오류 없이 끝남" {
    printf 'core|bash|-|-|-|pkg\n' > "${TMP_DIR}/catalog.txt"
    ARACHNE_TOOLS_CATALOG_FILE="${TMP_DIR}/catalog.txt" ARACHNE_TOOLS_PM=none \
        run bash "${REPO_DIR}/install.sh" -t --update --check --project "${PROJ}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"버전 점검 (프로젝트: ${PROJ})"* ]] || false
}

#-------------------------------------------------------------------------------
# install 재실행 — 이미 최신이면 다시 하지 않음
#-------------------------------------------------------------------------------
@test "install 재실행: 링크·bin·settings·dotfiles 모두 유지·최신, settings.bak 보존" {
    export ARACHNE_EXTRAS_SCRIPT="${TMP_DIR}/fake-extras.sh"
    printf '#!/bin/bash\nexit 0\n' > "${ARACHNE_EXTRAS_SCRIPT}"
    export ARACHNE_SKIP_TOOLS=1
    run bash "${REPO_DIR}/install.sh" -i
    [ "$status" -eq 0 ]
    printf 'sentinel\n' > "${HOME}/.claude/settings.json.bak"

    run bash "${REPO_DIR}/install.sh" -i
    [ "$status" -eq 0 ]
    [[ "$output" == *"유지: ${HOME}/.claude/CLAUDE.md"* ]] || false
    [[ "$output" == *"유지: arachne"* ]] || false
    [[ "$output" == *"최신: ${HOME}/.claude/settings.json"* ]] || false
    [[ "$output" == *"최신: ${HOME}/.bash_profile"* ]] || false
    [ "$(cat "${HOME}/.claude/settings.json.bak")" = "sentinel" ]
}

@test "install -i: 끝에서 도구 점검이 돌면 시작의 preflight 는 생략" {
    export ARACHNE_EXTRAS_SCRIPT="${TMP_DIR}/fake-extras.sh"
    printf '#!/bin/bash\nexit 0\n' > "${ARACHNE_EXTRAS_SCRIPT}"
    printf 'core|bash|-|-|-|pkg\n' > "${TMP_DIR}/catalog.txt"
    ARACHNE_TOOLS_CATALOG_FILE="${TMP_DIR}/catalog.txt" run bash "${REPO_DIR}/install.sh" -i < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" != *"의존성 사전 점검"* ]] || false
    [[ "$output" == *"개발 도구 점검"* ]] || false
}

@test "check: 홈 dotfile 섹션이 저장소와 다르면 WARN (실패는 아님)" {
    export ARACHNE_EXTRAS_SCRIPT="${TMP_DIR}/fake-extras.sh"
    printf '#!/bin/bash\nexit 0\n' > "${ARACHNE_EXTRAS_SCRIPT}"
    export ARACHNE_SKIP_TOOLS=1
    bash "${REPO_DIR}/install.sh" -i >/dev/null 2>&1
    sed -i 's/^alias df=.*/alias df=CHANGED/' "${HOME}/.bash_profile"
    run bash "${REPO_DIR}/install.sh" -c
    [[ "$output" == *"[WARN] Dotfile: 저장소와 다름"* ]] || false
}

@test "dotfiles: LD_LIBRARY_PATH 기존 값을 보존하고 빠진 경로만 추가" {
    run bash -c "LD_LIBRARY_PATH=/opt/oracle/lib; source <(sed -n '/arachne_lib_dir in/,/export LD_LIBRARY_PATH/p' '${REPO_DIR}/dotfiles/bash_profile'); echo \"\$LD_LIBRARY_PATH\""
    [ "$output" = "/opt/oracle/lib:/lib64:/lib:/usr/local/lib64" ]
}

@test "extras: enabledPlugins 가 이미 true 면 템플릿을 다시 쓰지 않음" {
    eval "$(sed -n '/^JsonSetEnabledPlugin() {/,/^}/p' "${REPO_DIR}/setup-extras.sh")"
    printf '{\n  "enabledPlugins": {"a@b": true}\n}\n' > "${TMP_DIR}/s.json"
    touch -d '2020-01-01' "${TMP_DIR}/s.json"
    JsonSetEnabledPlugin "${TMP_DIR}/s.json" "a@b"
    [ "$(date -r "${TMP_DIR}/s.json" +%Y)" = "2020" ]
}
