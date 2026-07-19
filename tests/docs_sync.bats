#!/usr/bin/env bats

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SCRIPT="${REPO_DIR}/docs-sync.sh"
    TMP_DIR="$(mktemp -d)"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

@test "docs-sync.sh: exists" {
    [ -f "${SCRIPT}" ]
}

@test "docs-sync.sh: syntax is valid" {
    run bash -n "${SCRIPT}"
    [ "$status" -eq 0 ]
}

@test "docs-sync init: creates config file" {
    run bash "${SCRIPT}" init --config "${TMP_DIR}/docs-sync.conf"
    [ "$status" -eq 0 ]
    [ -f "${TMP_DIR}/docs-sync.conf" ]
}

@test "docs-sync list: reads tab-delimited project map" {
    # shellcheck disable=SC2016
    printf 'sample\tuser@example.com\t2222\t/srv/sample\t$HOME/notes/sample\n' > "${TMP_DIR}/docs-sync.conf"

    run bash "${SCRIPT}" list --config "${TMP_DIR}/docs-sync.conf"

    [ "$status" -eq 0 ]
    [[ "$output" == *"sample"* ]]
    [[ "$output" == *"2222"* ]]
    [[ "$output" == *"${HOME}/notes/sample"* ]]
}

@test "docs-sync list: keeps legacy remote-root format working" {
    # shellcheck disable=SC2016
    printf 'legacy\tuser@example.com:/srv/legacy\t$HOME/notes/legacy\n' > "${TMP_DIR}/docs-sync.conf"

    run bash "${SCRIPT}" list --config "${TMP_DIR}/docs-sync.conf"

    [ "$status" -eq 0 ]
    [[ "$output" == *"legacy"* ]]
    [[ "$output" == *"user@example.com:/srv/legacy"* ]]
    [[ "$output" == *"${HOME}/notes/legacy"* ]]
}
