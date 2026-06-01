#!/usr/bin/env bats
################################################################################
# FILE NAME   : hooks.bats
# DESCRIPTION : hooks/ 스크립트 존재·실행권한·기본 동작 검증
# DATA        : 2026-06-01
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOKS_DIR="${REPO_DIR}/hooks"

#-------------------------------------------------------------------------------
# 파일 존재 및 실행 권한
#-------------------------------------------------------------------------------
@test "hooks: session-start.sh 존재" {
    [ -f "${HOOKS_DIR}/session-start.sh" ]
}

@test "hooks: session-start.sh 실행 권한" {
    [ -x "${HOOKS_DIR}/session-start.sh" ]
}

@test "hooks: session-end.sh 존재" {
    [ -f "${HOOKS_DIR}/session-end.sh" ]
}

@test "hooks: session-end.sh 실행 권한" {
    [ -x "${HOOKS_DIR}/session-end.sh" ]
}

@test "hooks: pre-compact.sh 존재" {
    [ -f "${HOOKS_DIR}/pre-compact.sh" ]
}

@test "hooks: pre-compact.sh 실행 권한" {
    [ -x "${HOOKS_DIR}/pre-compact.sh" ]
}

@test "hooks: gemini-check.sh 존재" {
    [ -f "${HOOKS_DIR}/gemini-check.sh" ]
}

@test "hooks: gemini-check.sh 실행 권한" {
    [ -x "${HOOKS_DIR}/gemini-check.sh" ]
}

#-------------------------------------------------------------------------------
# 문법 검사
#-------------------------------------------------------------------------------
@test "hooks: session-start.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/session-start.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: session-end.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/session-end.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: pre-compact.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/pre-compact.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: gemini-check.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/gemini-check.sh"
    [ "$status" -eq 0 ]
}

#-------------------------------------------------------------------------------
# gemini-check.sh: git 레포 외부에서 조용히 종료
#-------------------------------------------------------------------------------
@test "gemini-check.sh: git 레포 외부에서 종료 0" {
    # git rev-parse --show-toplevel 이 실패하는 경로에서 실행
    TMP_DIR=$(mktemp -d)
    run bash -c "cd '${TMP_DIR}' && bash '${HOOKS_DIR}/gemini-check.sh'"
    [ "$status" -eq 0 ]
    rm -rf "${TMP_DIR}"
}
