#!/usr/bin/env bats
################################################################################
# FILE NAME   : drift.bats
# DESCRIPTION : 드리프트 검출 검증 — #39 규약 동기화(check_convention_sync.sh)와
#               #35 인덱스 stem 단어경계 매칭.
# DATA        : 2026-06-08
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SYNC="${REPO_DIR}/tests/check_convention_sync.sh"
    FIX="$(mktemp -d)"
}

teardown() {
    rm -rf "${FIX}"
}

#-------------------------------------------------------------------------------
# 동기화된 픽스처 생성 — AGENTS.md 와 rules 양쪽에 모든 핵심 토큰 포함
#-------------------------------------------------------------------------------
make_fixture() {
    mkdir -p "${FIX}/rules/common"
    cat > "${FIX}/AGENTS.md" << 'EOF'
naming: snake_case g_SnakeCase PascalCase SCREAMING_SNAKE_CASE camelCase
tdd: RED GREEN REFACTOR AAA
git: feat fix refactor docs test chore perf style
EOF
    echo "snake_case g_SnakeCase PascalCase SCREAMING_SNAKE_CASE camelCase" > "${FIX}/rules/common/coding-style.md"
    echo "RED GREEN REFACTOR AAA" > "${FIX}/rules/common/testing.md"
    echo "feat fix refactor docs test chore perf style" > "${FIX}/rules/common/git-workflow.md"
}

@test "check_convention_sync(#39): 실제 레포에서 PASS" {
    run bash "${SYNC}"
    [ "$status" -eq 0 ]
}

@test "check_convention_sync(#39): 동기화된 픽스처는 PASS" {
    make_fixture
    CONV_SYNC_REPO="${FIX}" run bash "${SYNC}"
    [ "$status" -eq 0 ]
}

@test "check_convention_sync(#39): 한쪽 토큰 누락 시 FAIL(exit 1)" {
    make_fixture
    # testing.md 에서 REFACTOR 제거 → AGENTS.md 와 불일치
    echo "RED GREEN AAA" > "${FIX}/rules/common/testing.md"
    CONV_SYNC_REPO="${FIX}" run bash "${SYNC}"
    [ "$status" -eq 1 ]
    [[ "$output" == *"REFACTOR"* ]]
    [[ "$output" == *"DRIFT"* ]]
}

#-------------------------------------------------------------------------------
# #35: 인덱스 stem 매칭은 단어 경계 — 더 긴 단어의 부분일치를 거부한다
#-------------------------------------------------------------------------------
@test "index(#35): stem 단어경계 매칭은 부분일치를 거부" {
    printf 'api-designer 패턴 설명 문서\n' > "${FIX}/idx.md"
    # -w(강화된 동작): 'api-design' 은 'api-designer' 의 일부이므로 매칭 안 됨
    run grep -qwF "api-design" "${FIX}/idx.md"
    [ "$status" -ne 0 ]
    # -F(옛 동작): 부분일치라 매칭됨 → 이것이 false-negative 원인이었음
    run grep -qF "api-design" "${FIX}/idx.md"
    [ "$status" -eq 0 ]
}
