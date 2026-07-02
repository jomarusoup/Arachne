#!/usr/bin/env bats
################################################################################
# FILE NAME   : sgrep.bats
# DESCRIPTION : dotfiles/bash_profile 의 sgrep/lgrep 검증 — rules/ 언어 프로필
#               확장자 커버리지(java·tsx·vue·scss 등), 제외 디렉터리(.git·
#               node_modules·build), 기존 확장자 회귀, rg/find 폴백 동등성.
# DATA        : 2026-07-02
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    FIX="$(mktemp -d)"

    #--- 픽스처 프로젝트: 언어별 소스 + 제외 대상 디렉터리
    mkdir -p "${FIX}/src/ui" "${FIX}/node_modules/pkg" "${FIX}/.git" "${FIX}/build"
    echo 'NEEDLE legacy c'       > "${FIX}/src/main.c"
    echo 'NEEDLE legacy cpp'     > "${FIX}/src/app.cpp"
    echo 'NEEDLE legacy py'      > "${FIX}/src/tool.py"
    echo 'NEEDLE legacy sh'      > "${FIX}/src/run.sh"
    echo 'NEEDLE legacy md'      > "${FIX}/note.md"
    echo 'NEEDLE new java'       > "${FIX}/src/App.java"
    echo 'NEEDLE new tsx'        > "${FIX}/src/ui/View.tsx"
    echo 'NEEDLE new vue'        > "${FIX}/src/ui/Card.vue"
    echo 'NEEDLE new scss'       > "${FIX}/src/ui/style.scss"
    echo 'NEEDLE excluded dep'   > "${FIX}/node_modules/pkg/index.js"
    echo 'NEEDLE excluded git'   > "${FIX}/.git/notes.md"
    echo 'NEEDLE excluded build' > "${FIX}/build/out.c"
    printf 'line1\nNEEDLE ctx\nline3\n' > "${FIX}/src/ctx.py"
}

teardown() {
    rm -rf "${FIX}"
}

#-------------------------------------------------------------------------------
# 헬퍼: bash_profile 로드 후 픽스처 디렉터리에서 함수 실행
#   $1 = SGREP_FORCE_FIND 값 ("" = rg 우선 / "1" = find 폴백 강제)
#   $2 = 함수명 (sgrep / lgrep), 나머지 = 인자
#-------------------------------------------------------------------------------
run_profile_fn() {
    local force="$1"
    local fn="$2"
    shift 2
    (
        cd "${FIX}" || exit 1
        HOME="${FIX}"
        source "${REPO_DIR}/dotfiles/bash_profile" >/dev/null 2>&1
        SGREP_FORCE_FIND="${force}" "${fn}" "$@"
    )
}

#-------------------------------------------------------------------------------
# 신규 확장자 커버리지 (fact-check false-negative 수정 검증)
#-------------------------------------------------------------------------------
@test "sgrep(rg): java·tsx·vue·scss 파일을 찾는다" {
    command -v rg >/dev/null 2>&1 || skip "rg 미설치"
    run run_profile_fn "" sgrep NEEDLE
    [ "$status" -eq 0 ]
    [[ "$output" == *"App.java"* ]]
    [[ "$output" == *"View.tsx"* ]]
    [[ "$output" == *"Card.vue"* ]]
    [[ "$output" == *"style.scss"* ]]
}

@test "sgrep(find 폴백): java·tsx·vue·scss 파일을 찾는다" {
    run run_profile_fn "1" sgrep NEEDLE
    [ "$status" -eq 0 ]
    [[ "$output" == *"App.java"* ]]
    [[ "$output" == *"View.tsx"* ]]
    [[ "$output" == *"Card.vue"* ]]
    [[ "$output" == *"style.scss"* ]]
}

#-------------------------------------------------------------------------------
# 기존 확장자 회귀 방지
#-------------------------------------------------------------------------------
@test "sgrep(rg): 기존 c·cpp·py·sh·md 검색이 깨지지 않는다" {
    command -v rg >/dev/null 2>&1 || skip "rg 미설치"
    run run_profile_fn "" sgrep NEEDLE
    [[ "$output" == *"main.c"* ]]
    [[ "$output" == *"app.cpp"* ]]
    [[ "$output" == *"tool.py"* ]]
    [[ "$output" == *"run.sh"* ]]
    [[ "$output" == *"note.md"* ]]
}

@test "sgrep(find 폴백): 기존 c·cpp·py·sh·md 검색이 깨지지 않는다" {
    run run_profile_fn "1" sgrep NEEDLE
    [[ "$output" == *"main.c"* ]]
    [[ "$output" == *"app.cpp"* ]]
    [[ "$output" == *"tool.py"* ]]
    [[ "$output" == *"run.sh"* ]]
    [[ "$output" == *"note.md"* ]]
}

#-------------------------------------------------------------------------------
# 제외 디렉터리 (.git · node_modules · build)
#-------------------------------------------------------------------------------
@test "sgrep(rg): node_modules·.git·build 아래는 제외한다" {
    command -v rg >/dev/null 2>&1 || skip "rg 미설치"
    run run_profile_fn "" sgrep NEEDLE
    [[ "$output" != *"node_modules"* ]]
    [[ "$output" != *".git/"* ]]
    [[ "$output" != *"build/out.c"* ]]
}

@test "sgrep(find 폴백): node_modules·.git·build 아래는 제외한다" {
    run run_profile_fn "1" sgrep NEEDLE
    [[ "$output" != *"node_modules"* ]]
    [[ "$output" != *".git/"* ]]
    [[ "$output" != *"build/out.c"* ]]
}

#-------------------------------------------------------------------------------
# 출력 형식·컨텍스트·인자 처리
#-------------------------------------------------------------------------------
@test "sgrep: 파일명:행번호:내용 형식으로 출력한다" {
    run run_profile_fn "1" sgrep 'NEEDLE legacy c'
    [[ "$output" == *"main.c:1:"* ]]
}

@test "lgrep: 매칭 행 전후 컨텍스트를 포함한다" {
    run run_profile_fn "1" lgrep 'NEEDLE ctx'
    [[ "$output" == *"line1"* ]]
    [[ "$output" == *"line3"* ]]
}

@test "sgrep: 인자 없으면 usage 출력 후 실패한다" {
    run run_profile_fn "1" sgrep
    [ "$status" -eq 1 ]
    [[ "$output" == *"usage"* ]]
}
