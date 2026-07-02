#!/usr/bin/env bats
################################################################################
# FILE NAME   : verify_command.bats
# DESCRIPTION : /verify 커맨드(commands/verify.md)의 리포트 영속화 계약 검증.
#               /verify 는 마크다운 커맨드라, 리포트 기록 절차·형식 필드가
#               문서에서 빠지지 않도록 문서 계약(doc-contract)을 검사한다.
#               정책 정본(docs/PROJECT-CI.md)과의 상호 참조도 확인한다.
# DATA        : 2026-07-02
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    VERIFY_CMD="${REPO_DIR}/commands/verify.md"
    PROJECT_CI="${REPO_DIR}/docs/PROJECT-CI.md"
    GIT_CMD="${REPO_DIR}/commands/git.md"
}

@test "verify command: 커맨드 문서 존재" {
    [ -f "${VERIFY_CMD}" ]
}

@test "verify command: 리포트 기록 STEP 명시 (.arachne/reports)" {
    grep -q "리포트 기록" "${VERIFY_CMD}"
    grep -q ".arachne/reports/" "${VERIFY_CMD}"
}

@test "verify command: 통과·실패 무관 기록 원칙 명시" {
    grep -q "통과·실패와 무관하게 기록" "${VERIFY_CMD}"
}

@test "verify command: frontmatter 필수 필드 명시" {
    grep -q "type: verify" "${VERIFY_CMD}"
    grep -q "result: pass" "${VERIFY_CMD}"
    grep -q "branch:" "${VERIFY_CMD}"
    grep -q "commit:" "${VERIFY_CMD}"
    grep -q "scope:" "${VERIFY_CMD}"
}

@test "verify command: .arachne 없는 프로젝트는 기록 생략 규칙 명시" {
    grep -q "없으면 기록을 생략" "${VERIFY_CMD}"
    grep -q "arachne init-ci" "${VERIFY_CMD}"
}

@test "verify command: 리포트 불변(수정·삭제 금지) 원칙 명시" {
    grep -q "수정·삭제하지 않는다" "${VERIFY_CMD}"
}

@test "project-ci: reports/ 소유권·리포트 정책 절 존재" {
    grep -q ".arachne/reports/" "${PROJECT_CI}"
    grep -q "검증 리포트" "${PROJECT_CI}"
    grep -q "CI(\`verify.sh\`)는 리포트를 생성하지 않는다" "${PROJECT_CI}"
}

@test "git command: 새 verify 리포트를 같은 커밋에 포함 규칙 명시" {
    grep -q ".arachne/reports/" "${GIT_CMD}"
    grep -q "같은 커밋에 포함" "${GIT_CMD}"
}
