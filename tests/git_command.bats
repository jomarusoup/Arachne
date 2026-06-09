#!/usr/bin/env bats
################################################################################
# FILE NAME   : git_command.bats
# DESCRIPTION : /git 커맨드(commands/git.md)의 가드 절차가 문서화돼 있는지 검증 (#27).
#               /git 은 Haiku 위임 마크다운 커맨드라, 가드가 절차에서 빠지지 않도록
#               문서 계약(doc-contract)을 검사한다.
# DATA        : 2026-06-08
# Modification: 2026-06-09
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    GIT_CMD="${REPO_DIR}/commands/git.md"
}

@test "git command(#27): 커맨드 문서 존재" {
    [ -f "${GIT_CMD}" ]
}

@test "git command(#27): 변경 소유권 점검 가드 명시" {
    grep -q "소유권" "${GIT_CMD}"
    grep -q "혼입 금지" "${GIT_CMD}"
}

@test "git command(#27): 브랜치 가드 명시" {
    grep -q "브랜치 가드" "${GIT_CMD}"
    grep -q "의도치 않은 브랜치면 중단" "${GIT_CMD}"
}

@test "git command(#27): 검증 선행 가드 명시" {
    grep -q "검증 선행" "${GIT_CMD}"
    grep -q "shellcheck" "${GIT_CMD}"
    grep -q "git diff --check" "${GIT_CMD}"
}

@test "git command: Arachne 프로젝트 검증을 로컬 CI 게이트로 실행" {
    grep -q "arachne project-check" "${GIT_CMD}"
    grep -q ".arachne/verify.sh" "${GIT_CMD}"
}

@test "git command(#27): non-fast-forward 푸시 가드 명시" {
    grep -q "non-fast-forward" "${GIT_CMD}"
    grep -q "pull --no-rebase" "${GIT_CMD}"
    grep -q "임의로 해결하지 말고" "${GIT_CMD}"
}
