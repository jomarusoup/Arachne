#!/usr/bin/env bats
################################################################################
# FILE NAME   : docs_cli_contract.bats
# DESCRIPTION : 핵심 CLI 도움말과 사용자 문서의 발견성 계약
# DATA        : 2026-06-09
# Modification: 2026-06-09
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

#-------------------------------------------------------------------------------
# CLI 명령이 도움말과 두 사용자 진입점에 모두 노출되는지 확인
#-------------------------------------------------------------------------------
@test "docs cli: 프로젝트 profile 명령이 도움말과 문서에 존재" {
    local help_output
    local token

    help_output=$(bash "${REPO_DIR}/install.sh" --help)
    for token in "init-ci" "project-check" "python-web" "cpp" "rust" "feedback"; do
        [[ "$help_output" == *"$token"* ]]
        grep -qF "$token" "${REPO_DIR}/README.md"
        grep -qF "$token" "${REPO_DIR}/docs/USAGE.md"
    done
}

@test "docs cli: 프로젝트 CI 정본 문서가 README와 USAGE에서 연결" {
    grep -qF "docs/PROJECT-CI.md" "${REPO_DIR}/README.md"
    grep -qF "PROJECT-CI.md" "${REPO_DIR}/docs/USAGE.md"
    grep -qF "PYTHON-WEB-PROFILE.md" "${REPO_DIR}/docs/USAGE.md"
}

@test "docs cli: 디자인 문서 계약과 /design 탐색 순서가 문서화됨" {
    grep -qF "DESIGN-DOCS.md" "${REPO_DIR}/README.md"
    grep -qF "DESIGN-DOCS.md" "${REPO_DIR}/docs/USAGE.md"
    grep -qF "docs/design/DESIGN.md" "${REPO_DIR}/commands/design.md"
}
