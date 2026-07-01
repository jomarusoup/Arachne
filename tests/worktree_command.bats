#!/usr/bin/env bats
################################################################################
# FILE NAME   : worktree_command.bats
# DESCRIPTION : /worktree 커맨드(commands/worktree.md)의 병렬 세션 가드 계약을 검증한다.
# DATA        : 2026-07-01
# Modification: 2026-07-01
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    WORKTREE_CMD="${REPO_DIR}/commands/worktree.md"
}

@test "worktree command: 커맨드 문서 존재" {
    [ -f "${WORKTREE_CMD}" ]
}

@test "worktree command: create/status/cleanup 모드 명시" {
    grep -q "create <task>" "${WORKTREE_CMD}"
    grep -q "status" "${WORKTREE_CMD}"
    grep -q "cleanup <path>" "${WORKTREE_CMD}"
}

@test "worktree command: 새 worktree 생성 명령 명시" {
    grep -q "git worktree list" "${WORKTREE_CMD}"
    grep -q "git pull --ff-only" "${WORKTREE_CMD}"
    grep -q "git worktree add ../Arachne-<task> feat/<task>" "${WORKTREE_CMD}"
}

@test "worktree command: dirty 작업트리와 기존 경로 가드 명시" {
    grep -q "미커밋 변경" "${WORKTREE_CMD}"
    grep -q "이미 있으면 덮어쓰지 않는다" "${WORKTREE_CMD}"
    grep -q "브랜치가 이미 있으면" "${WORKTREE_CMD}"
}

@test "worktree command: cleanup 안전 가드 명시" {
    grep -q "git worktree remove <path>" "${WORKTREE_CMD}"
    grep -q "git worktree prune" "${WORKTREE_CMD}"
    grep -q "push되지 않았거나 PR에 반영되지 않았으면 제거하지 않는다" "${WORKTREE_CMD}"
}
