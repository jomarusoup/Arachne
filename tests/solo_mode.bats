#!/usr/bin/env bats
################################################################################
# FILE NAME   : solo_mode.bats
# DESCRIPTION : 솔로 모드(Claude 단독, Codex/Gemini 미설치) 검증 —
#               위임 래퍼의 미설치 가드(127 + 친절 메시지)와
#               atask 의 127 스킵(쿨다운 없이 다음 후보)을 확인한다.
# DATA        : 2026-06-11
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

    TMP_DIR="$(mktemp -d)"
    MOCK_BIN="${TMP_DIR}/bin"
    SAFE_BIN="${TMP_DIR}/safebin"
    mkdir -p "${MOCK_BIN}" "${SAFE_BIN}"

    # 밀폐 PATH — 호스트의 gemini/codex/claude 가 어디 있든 보이지 않게,
    # 스크립트 실행에 필요한 도구만 심볼릭한다 (atask.bats A-11 과 같은 방식)
    local tool
    for tool in bash sh cat date grep head cut mkdir mktemp mv rm basename tr sed wc; do
        ln -s "$(command -v "${tool}")" "${SAFE_BIN}/${tool}" 2>/dev/null || true
    done

    export ARACHNE_STATE_DIR="${TMP_DIR}/state"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# 래퍼 미설치 가드 — 명확한 메시지 + 종료코드 127
#-------------------------------------------------------------------------------
@test "solo: gtask 는 gemini 미설치 시 127 + 안내 메시지" {
    PATH="${SAFE_BIN}" run bash "${REPO_DIR}/gemini-task.sh" "질문"
    [ "$status" -eq 127 ]
    [[ "$output" == *"Gemini CLI 미설치"* ]]
    [[ "$output" == *"arachne -i --target gemini"* ]]
}

@test "solo: ctask 는 codex 미설치 시 127 + 안내 메시지" {
    PATH="${SAFE_BIN}" run bash "${REPO_DIR}/codex-task.sh" "작업"
    [ "$status" -eq 127 ]
    [[ "$output" == *"Codex CLI 미설치"* ]]
    [[ "$output" == *"arachne -i --target codex"* ]]
}

#-------------------------------------------------------------------------------
# atask — 127(하위 CLI 미설치)은 쿨다운 등록 없이 다음 후보로 건너뛴다
#-------------------------------------------------------------------------------
@test "solo: atask 는 127 래퍼를 쿨다운 없이 건너뛰고 다음 후보 실행" {
    # test 역할 순서: codex → claude → gemini.
    # codex-task 는 미설치 가드처럼 127, claude 는 정상 응답.
    cat > "${MOCK_BIN}/codex-task" << 'MOCK'
#!/bin/bash
echo "[ctask] Codex CLI 미설치 — tester/fixer 위임 불가." >&2
exit 127
MOCK
    cat > "${MOCK_BIN}/claude" << 'MOCK'
#!/bin/bash
echo "OUTPUT_FROM_claude"
MOCK
    chmod +x "${MOCK_BIN}/codex-task" "${MOCK_BIN}/claude"

    PATH="${MOCK_BIN}:${SAFE_BIN}" run bash "${REPO_DIR}/arachne-task.sh" -R test "작업"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip codex (하위 CLI 미설치)"* ]]
    [[ "$output" == *"OUTPUT_FROM_claude"* ]]
    # 미설치는 쿼터가 아니므로 쿨다운 상태 파일에 codex 가 기록되지 않아야 한다
    ! grep -q "^codex" "${ARACHNE_STATE_DIR}/arachne-quota-state" 2>/dev/null
}
