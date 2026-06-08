#!/usr/bin/env bats
################################################################################
# FILE NAME   : smoke.bats
# DESCRIPTION : 훅·atask 런타임 스모크(tests/smoke_hooks.sh)를 bats 로도 실행 (#40) —
#               Windows job 은 Git Bash 로, ubuntu job 은 이 bats 로 동일 스모크를 돈다.
# DATA        : 2026-06-08
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "smoke(#40): 훅·atask 런타임 스모크 통과" {
    run bash "${REPO_DIR}/tests/smoke_hooks.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[PASS]"* ]]
}
