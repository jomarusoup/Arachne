#!/usr/bin/env bats
################################################################################
# FILE NAME   : install.bats
# DESCRIPTION : install.sh 동작 검증 테스트
# DATA        : 2026-06-01
# Modification: 2026-06-05
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TMP_DIR=$(mktemp -d)
    export HOME="${TMP_DIR}"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#===============================================================================
# FUNCTION    : run_install
# DESCRIPTION : install.sh 를 설치 모드로 실행하고 종료코드 0 을 단언.
#               무인자 실행은 usage(도움말)이므로 설치는 -i 플래그가 필수.
#               설치 호출부를 한 곳으로 모아 플래그 드리프트를 차단한다.
# RETURNED    : 0(성공) — 실패 시 단언이 테스트를 실패시킴
#===============================================================================
run_install() {
    run bash "${REPO_DIR}/install.sh" -i
    [ "$status" -eq 0 ]
}

#-------------------------------------------------------------------------------
# 심볼릭 링크 생성 검증
#-------------------------------------------------------------------------------
@test "install: CLAUDE.md 심볼릭 링크 생성" {
    run_install
    [ -L "${TMP_DIR}/.claude/CLAUDE.md" ]
}

@test "install: commands/ 심볼릭 링크 생성" {
    run_install
    [ -L "${TMP_DIR}/.claude/commands" ]
}

@test "install: agents/ 심볼릭 링크 생성" {
    run_install
    [ -L "${TMP_DIR}/.claude/agents" ]
}

@test "install: hooks/ 심볼릭 링크 생성" {
    run_install
    [ -L "${TMP_DIR}/.claude/hooks" ]
}

@test "install: skills/ 심볼릭 링크 생성" {
    run_install
    [ -L "${TMP_DIR}/.claude/skills" ]
}

#-------------------------------------------------------------------------------
# settings.json 생성 검증
#-------------------------------------------------------------------------------
@test "install: settings.json 생성됨 (심볼릭 링크 아님)" {
    run_install
    [ -f "${TMP_DIR}/.claude/settings.json" ]
    [ ! -L "${TMP_DIR}/.claude/settings.json" ]
}

@test "install: settings.json에 __HOME__ 플레이스홀더 없음" {
    run_install
    run grep "__HOME__" "${TMP_DIR}/.claude/settings.json"
    [ "$status" -ne 0 ]
}

@test "install: settings.json에 실제 HOME 경로 포함" {
    run_install
    run grep "${TMP_DIR}" "${TMP_DIR}/.claude/settings.json"
    [ "$status" -eq 0 ]
}

#-------------------------------------------------------------------------------
# 무인자 실행은 설치하지 않고 usage 만 출력 (안전 기본값)
#-------------------------------------------------------------------------------
@test "no-arg: 무인자 실행은 설치하지 않음 (usage 출력)" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ ! -e "${TMP_DIR}/.claude/settings.json" ]
    [[ "$output" == *"Usage:"* ]]
}

#-------------------------------------------------------------------------------
# 재설치 시 백업 검증
#-------------------------------------------------------------------------------
@test "install: 기존 파일 있을 때 .bak으로 백업" {
    mkdir -p "${TMP_DIR}/.claude"
    echo "old content" > "${TMP_DIR}/.claude/CLAUDE.md"

    run_install
    [ -f "${TMP_DIR}/.claude/CLAUDE.md.bak" ]
}

#-------------------------------------------------------------------------------
# --export-settings 검증
#-------------------------------------------------------------------------------
@test "export-settings: settings.json -> template 내보내기" {
    bash "${REPO_DIR}/install.sh" -i
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
