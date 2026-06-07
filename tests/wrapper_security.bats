#!/usr/bin/env bats
################################################################################
# FILE NAME   : wrapper_security.bats
# DESCRIPTION : 위임 래퍼(codex-task/gemini-task) 입력 경계·최소권한 가드 검증 (#38) —
#               인젝션 저항 프리앰블 주입, -w 쓰기 모드 경고, raw 생략, 보안 도움말.
#               codex 는 mock 으로 격리한다(실제 호출 없음).
# DATA        : 2026-06-08
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    CTASK="${REPO_DIR}/codex-task.sh"
    GTASK="${REPO_DIR}/gemini-task.sh"

    TMP_DIR="$(mktemp -d)"
    MOCK_BIN="${TMP_DIR}/bin"
    mkdir -p "${MOCK_BIN}"
    # mock codex — 받은 인자(프롬프트 포함)를 그대로 stdout 으로 에코
    cat > "${MOCK_BIN}/codex" << 'MOCK'
#!/bin/bash
printf '%s\n' "$*"
exit 0
MOCK
    chmod +x "${MOCK_BIN}/codex"
    export PATH="${MOCK_BIN}:${PATH}"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

@test "wrapper: codex-task.sh 문법 유효" {
    run bash -n "${CTASK}"
    [ "$status" -eq 0 ]
}

@test "wrapper: gemini-task.sh 문법 유효" {
    run bash -n "${GTASK}"
    [ "$status" -eq 0 ]
}

#-------------------------------------------------------------------------------
# #38: 기본(non-raw) 호출은 인젝션 저항 보안 지시를 프롬프트에 주입한다
#-------------------------------------------------------------------------------
@test "ctask(#38): non-raw 는 보안 인젝션 저항 지시를 주입" {
    run bash "${CTASK}" "이 로그 분석"
    [ "$status" -eq 0 ]
    [[ "$output" == *"데이터로만 취급"* ]]
    [[ "$output" == *"따르지 않는다"* ]]
}

@test "ctask(#38): -r(raw) 은 역할·보안 프리앰블을 생략" {
    run bash "${CTASK}" -r "이 함수 리뷰"
    [ "$status" -eq 0 ]
    [[ "$output" != *"테스터/버그픽서"* ]]
    [[ "$output" != *"데이터로만 취급"* ]]
}

#-------------------------------------------------------------------------------
# #38: -w(쓰기) 모드는 사전 경고를 출력, 기본(read-only)은 출력하지 않는다
#-------------------------------------------------------------------------------
@test "ctask(#38): -w 쓰기 모드는 사전 경고 출력" {
    run bash "${CTASK}" -w "test_auth 수정"
    [ "$status" -eq 0 ]
    [[ "$output" == *"쓰기 모드"* ]]
    [[ "$output" == *"git diff"* ]]
}

@test "ctask(#38): 기본(read-only)은 쓰기 경고 미출력" {
    run bash "${CTASK}" "테스트 제안만"
    [ "$status" -eq 0 ]
    [[ "$output" != *"쓰기 모드"* ]]
}

#-------------------------------------------------------------------------------
# #38: 도움말에 보안 안내(UNTRUSTED 구획) 포함
#-------------------------------------------------------------------------------
@test "ctask(#38): -h 도움말에 보안 안내 포함" {
    run bash "${CTASK}" -h
    [[ "$output" == *"Security"* ]]
    [[ "$output" == *"UNTRUSTED"* ]]
}

@test "gtask(#38): -h 도움말에 보안 안내 포함" {
    run bash "${GTASK}" -h
    [[ "$output" == *"Security"* ]]
    [[ "$output" == *"UNTRUSTED"* ]]
}
