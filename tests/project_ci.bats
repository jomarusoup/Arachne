#!/usr/bin/env bats
################################################################################
# FILE NAME   : project_ci.bats
# DESCRIPTION : Arachne 사용 프로젝트의 로컬·GitHub CI 공통 검증 계약
# DATA        : 2026-06-09
# Modification: 2026-06-09
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    TMP_DIR=$(mktemp -d)
    PROJECT_DIR="${TMP_DIR}/project"
    mkdir -p "${PROJECT_DIR}"
    git -C "${PROJECT_DIR}" init -q
    printf '# project\n' > "${PROJECT_DIR}/README.md"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# init-ci 생성 계약
#-------------------------------------------------------------------------------
@test "project ci: init-ci 는 검증 자산과 main push/PR workflow 생성" {
    run bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}"
    [ "$status" -eq 0 ]
    [ -x "${PROJECT_DIR}/.arachne/verify.sh" ]
    [ -f "${PROJECT_DIR}/.arachne/commands" ]
    [ -f "${PROJECT_DIR}/.github/workflows/arachne.yml" ]
    grep -qF "branches: [main]" \
        "${PROJECT_DIR}/.github/workflows/arachne.yml"
    grep -qF "bash .arachne/verify.sh" \
        "${PROJECT_DIR}/.github/workflows/arachne.yml"
}

@test "project ci: 기본 profile 은 minimal" {
    run bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}"
    [ "$status" -eq 0 ]
    [ "$(cat "${PROJECT_DIR}/.arachne/profile")" = "minimal" ]
    grep -qF "git diff --check" "${PROJECT_DIR}/.arachne/commands"
}

@test "project ci: python-web profile 은 Python과 Web 검증 명령 생성" {
    run bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}" \
        --profile python-web
    [ "$status" -eq 0 ]
    [ "$(cat "${PROJECT_DIR}/.arachne/profile")" = "python-web" ]
    grep -qF "uv sync --frozen" "${PROJECT_DIR}/.arachne/commands"
    grep -qF "pnpm install --frozen-lockfile" \
        "${PROJECT_DIR}/.arachne/commands"
    grep -qF "actions/setup-python@v6" \
        "${PROJECT_DIR}/.github/workflows/arachne.yml"
    grep -qF "astral-sh/setup-uv@v8.2.0" \
        "${PROJECT_DIR}/.github/workflows/arachne.yml"
    grep -qF "actions/setup-node@v6" \
        "${PROJECT_DIR}/.github/workflows/arachne.yml"
    grep -qF "corepack enable" \
        "${PROJECT_DIR}/.github/workflows/arachne.yml"
}

@test "project ci: profile 재실행은 사용자 commands 를 보존" {
    bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}" --profile python
    printf 'printf \"custom-check\\n\"\n' > "${PROJECT_DIR}/.arachne/commands"

    run bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}" --profile web
    [ "$status" -eq 0 ]
    [ "$(cat "${PROJECT_DIR}/.arachne/profile")" = "web" ]
    grep -qF 'custom-check' "${PROJECT_DIR}/.arachne/commands"
    run grep -F "pnpm install" "${PROJECT_DIR}/.arachne/commands"
    [ "$status" -ne 0 ]
}

@test "project ci: 알 수 없는 profile 을 거부" {
    run bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}" \
        --profile unknown
    [ "$status" -ne 0 ]
    [[ "$output" == *"알 수 없는 profile"* ]]
}

@test "project ci: init-ci 재실행은 사용자 commands 를 보존" {
    bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}"
    printf 'printf \"custom-check\\n\"\n' > "${PROJECT_DIR}/.arachne/commands"

    run bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}"
    [ "$status" -eq 0 ]
    grep -qF 'custom-check' "${PROJECT_DIR}/.arachne/commands"
}

@test "project ci: init-ci 는 관리 디렉터리 심볼릭 링크를 거부" {
    outside_dir="${TMP_DIR}/outside"
    mkdir -p "$outside_dir"
    ln -s "$outside_dir" "${PROJECT_DIR}/.arachne"

    run bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}"
    [ "$status" -ne 0 ]
    [[ "$output" == *"심볼릭 링크"* ]]
    [ ! -e "${outside_dir}/verify.sh" ]
}

#-------------------------------------------------------------------------------
# project-check 실행 계약
#-------------------------------------------------------------------------------
@test "project ci: project-check 는 설정 명령을 실행" {
    bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}"
    printf 'printf \"configured-check\\n\"\n' > "${PROJECT_DIR}/.arachne/commands"

    run bash "${REPO_DIR}/install.sh" project-check "${PROJECT_DIR}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"configured-check"* ]]
    [[ "$output" == *"모든 프로젝트 검증 통과"* ]]
}

@test "project ci: project-check 는 실패한 명령의 상태를 전파" {
    bash "${REPO_DIR}/install.sh" init-ci "${PROJECT_DIR}"
    printf 'printf \"expected-failure\\n\"; exit 7\n' > \
        "${PROJECT_DIR}/.arachne/commands"

    run bash "${REPO_DIR}/install.sh" project-check "${PROJECT_DIR}"
    [ "$status" -eq 7 ]
    [[ "$output" == *"expected-failure"* ]]
    [[ "$output" == *"[FAIL]"* ]]
}

@test "project ci: project-check 는 초기화되지 않은 프로젝트를 거부" {
    run bash "${REPO_DIR}/install.sh" project-check "${PROJECT_DIR}"
    [ "$status" -ne 0 ]
    [[ "$output" == *"init-ci"* ]]
}
