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

@test "hooks: git-bus-check.sh 존재" {
    [ -f "${HOOKS_DIR}/git-bus-check.sh" ]
}

@test "hooks: git-bus-check.sh 실행 권한" {
    [ -x "${HOOKS_DIR}/git-bus-check.sh" ]
}

@test "hooks: atask-quota-warn.sh 존재·실행권한" {
    [ -f "${HOOKS_DIR}/atask-quota-warn.sh" ]
    [ -x "${HOOKS_DIR}/atask-quota-warn.sh" ]
}

@test "hooks: doc-drift-check.sh 존재·실행권한" {
    [ -f "${HOOKS_DIR}/doc-drift-check.sh" ]
    [ -x "${HOOKS_DIR}/doc-drift-check.sh" ]
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

@test "hooks: git-bus-check.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/git-bus-check.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: atask-quota-warn.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/atask-quota-warn.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: doc-drift-check.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/doc-drift-check.sh"
    [ "$status" -eq 0 ]
}

#-------------------------------------------------------------------------------
# atask-quota-warn.sh: 상태 파일 없으면 조용히 종료
#-------------------------------------------------------------------------------
@test "atask-quota-warn.sh: 상태 파일 없으면 침묵·종료 0" {
    TMP_DIR=$(mktemp -d)
    run env ARACHNE_STATE_DIR="${TMP_DIR}" bash "${HOOKS_DIR}/atask-quota-warn.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# doc-drift-check.sh: 문서 파일 편집은 무시, 기능 파일은 알림
#-------------------------------------------------------------------------------
@test "doc-drift-check.sh: .md 편집은 알림 안 함" {
    TMP_DIR=$(mktemp -d)
    run bash -c "echo '{\"session_id\":\"t\",\"tool_input\":{\"file_path\":\"/x/docs/USAGE.md\"}}' | env ARACHNE_STATE_DIR='${TMP_DIR}' bash '${HOOKS_DIR}/doc-drift-check.sh'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm -rf "${TMP_DIR}"
}

@test "doc-drift-check.sh: 기능 파일(.sh) 편집은 알림" {
    TMP_DIR=$(mktemp -d)
    run bash -c "echo '{\"session_id\":\"t2\",\"tool_input\":{\"file_path\":\"/x/install.sh\"}}' | env ARACHNE_STATE_DIR='${TMP_DIR}' bash '${HOOKS_DIR}/doc-drift-check.sh'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"문서 드리프트"* ]]
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# git-bus-check.sh: git 레포 외부에서 조용히 종료
#-------------------------------------------------------------------------------
@test "git-bus-check.sh: git 레포 외부에서 종료 0" {
    # git rev-parse --show-toplevel 이 실패하는 경로에서 실행
    TMP_DIR=$(mktemp -d)
    run bash -c "cd '${TMP_DIR}' && bash '${HOOKS_DIR}/git-bus-check.sh'"
    [ "$status" -eq 0 ]
    rm -rf "${TMP_DIR}"
}
