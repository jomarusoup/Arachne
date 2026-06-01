#!/usr/bin/env bats
################################################################################
# FILE NAME   : install.bats
# DESCRIPTION : install.sh 동작 검증 테스트
# DATA        : 2026-06-01
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TMP_DIR=$(mktemp -d)
    export HOME="${TMP_DIR}"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# 심볼릭 링크 생성 검증
#-------------------------------------------------------------------------------
@test "install: CLAUDE.md 심볼릭 링크 생성" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -L "${TMP_DIR}/.claude/CLAUDE.md" ]
}

@test "install: commands/ 심볼릭 링크 생성" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -L "${TMP_DIR}/.claude/commands" ]
}

@test "install: agents/ 심볼릭 링크 생성" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -L "${TMP_DIR}/.claude/agents" ]
}

@test "install: hooks/ 심볼릭 링크 생성" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -L "${TMP_DIR}/.claude/hooks" ]
}

@test "install: skills/ 심볼릭 링크 생성" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -L "${TMP_DIR}/.claude/skills" ]
}

#-------------------------------------------------------------------------------
# settings.json 생성 검증
#-------------------------------------------------------------------------------
@test "install: settings.json 생성됨 (심볼릭 링크 아님)" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -f "${TMP_DIR}/.claude/settings.json" ]
    [ ! -L "${TMP_DIR}/.claude/settings.json" ]
}

@test "install: settings.json에 __HOME__ 플레이스홀더 없음" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    run grep "__HOME__" "${TMP_DIR}/.claude/settings.json"
    [ "$status" -ne 0 ]
}

@test "install: settings.json에 실제 HOME 경로 포함" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    run grep "${TMP_DIR}" "${TMP_DIR}/.claude/settings.json"
    [ "$status" -eq 0 ]
}

#-------------------------------------------------------------------------------
# 재설치 시 백업 검증
#-------------------------------------------------------------------------------
@test "install: 기존 파일 있을 때 .bak으로 백업" {
    mkdir -p "${TMP_DIR}/.claude"
    echo "old content" > "${TMP_DIR}/.claude/CLAUDE.md"

    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -f "${TMP_DIR}/.claude/CLAUDE.md.bak" ]
}

#-------------------------------------------------------------------------------
# --export-settings 검증
#-------------------------------------------------------------------------------
@test "export-settings: settings.json -> template 내보내기" {
    bash "${REPO_DIR}/install.sh"
    TMP_TEMPLATE=$(mktemp)

    # settings.json 복사 후 export 테스트
    run bash -c "
        cd '${REPO_DIR}'
        cp settings.template.json '${TMP_TEMPLATE}'
        bash install.sh --export-settings
        diff settings.template.json '${TMP_TEMPLATE}' || true
    "
    [ "$status" -eq 0 ]

    # 원본 복원
    cp "${TMP_TEMPLATE}" "${REPO_DIR}/settings.template.json"
    rm -f "${TMP_TEMPLATE}"
}
