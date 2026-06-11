#!/usr/bin/env bats
################################################################################
# FILE NAME   : atask.bats
# DESCRIPTION : arachne-task.sh (atask) 자동 폴백 캐스케이드 검증 —
#               claude/codex-task/gemini-task 를 모킹해 순서·쿼터 폴백·쿨다운·
#               일반 에러 비폴백을 확인한다.
# DATA        : 2026-06-07
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SCRIPT="${REPO_DIR}/arachne-task.sh"

    TMP_DIR="$(mktemp -d)"
    MOCK_BIN="${TMP_DIR}/bin"
    mkdir -p "${MOCK_BIN}"

    # 상태 파일을 격리된 디렉터리로
    export ARACHNE_STATE_DIR="${TMP_DIR}/state"
    # 쿨다운을 짧게(테스트 속도) — 단, 0보다는 커야 의미 있음
    export ATASK_COOLDOWN_CLAUDE=3600
    export ATASK_COOLDOWN_DEFAULT=3600

    # 모킹된 CLI 를 PATH 앞에 둔다
    export PATH="${MOCK_BIN}:${PATH}"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# 모킹 헬퍼 — 이름별 동작을 환경변수로 제어하는 가짜 CLI 생성
#   <name>_BEHAVIOR = ok | quota | err
#-------------------------------------------------------------------------------
make_mock() {
    local name="$1"
    cat > "${MOCK_BIN}/${name}" << 'MOCK'
#!/bin/bash
self="$(basename "$0")"
var="$(echo "${self}" | tr 'a-z-' 'A-Z_')_BEHAVIOR"
behavior="${!var:-ok}"
case "${behavior}" in
    ok)        echo "OUTPUT_FROM_${self}"; exit 0 ;;
    quota)     echo "Error: 429 rate limit exceeded" >&2; exit 1 ;;
    err)       echo "Error: syntax error in input" >&2; exit 2 ;;
    diskquota) echo "Error: disk quota exceeded" >&2; exit 1 ;;
esac
MOCK
    chmod +x "${MOCK_BIN}/${name}"
}

@test "atask: 스크립트 존재·문법 유효" {
    [ -f "${SCRIPT}" ]
    run bash -n "${SCRIPT}"
    [ "$status" -eq 0 ]
}

@test "atask: --dry-run 은 impl 순서(claude codex gemini) 출력" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    run bash "${SCRIPT}" --dry-run -R impl "x"
    [ "$status" -eq 0 ]
    [[ "$output" == *"order=claude codex gemini"* ]]
}

@test "atask: read 역할은 gemini 먼저" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    run bash "${SCRIPT}" --dry-run -R read "x"
    [[ "$output" == *"order=gemini codex claude"* ]]
}

@test "atask: claude 성공 시 claude 가 처리" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    run bash "${SCRIPT}" -R impl "작업"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OUTPUT_FROM_claude"* ]]
    [[ "$output" == *"처리 완료: claude"* ]]
}

@test "atask: claude 쿼터 소진 → codex 로 폴백 + 쿨다운 기록" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    CLAUDE_BEHAVIOR=quota run bash "${SCRIPT}" -R impl "작업"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OUTPUT_FROM_codex-task"* ]]
    [[ "$output" == *"처리 완료: codex"* ]]
    # 상태 파일에 claude 쿨다운이 기록돼야 함
    grep -q "^claude	" "${ARACHNE_STATE_DIR}/arachne-quota-state"
}

@test "atask: claude+codex 쿼터 소진 → gemini 가 처리" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    CLAUDE_BEHAVIOR=quota CODEX_TASK_BEHAVIOR=quota run bash "${SCRIPT}" -R impl "작업"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OUTPUT_FROM_gemini-task"* ]]
    [[ "$output" == *"처리 완료: gemini"* ]]
}

@test "atask: 전 CLI 쿼터 소진 → 실패(exit 1)" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    CLAUDE_BEHAVIOR=quota CODEX_TASK_BEHAVIOR=quota GEMINI_TASK_BEHAVIOR=quota \
        run bash "${SCRIPT}" -R impl "작업"
    [ "$status" -eq 1 ]
    [[ "$output" == *"전 CLI 소진"* ]]
}

@test "atask: 쿼터가 아닌 일반 에러는 폴백하지 않고 중단" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    CLAUDE_BEHAVIOR=err run bash "${SCRIPT}" -R impl "작업"
    [ "$status" -eq 2 ]
    # codex 로 넘어가지 않아야 함
    [[ "$output" != *"OUTPUT_FROM_codex-task"* ]]
    [[ "$output" == *"폴백 중단"* ]]
}

@test "atask: 쿨다운 중인 claude 는 건너뛰고 codex 부터 시작" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    # claude 를 미래 시각으로 쿨다운 등록
    mkdir -p "${ARACHNE_STATE_DIR}"
    printf 'claude\t%s\n' "$(( $(date +%s) + 9999 ))" > "${ARACHNE_STATE_DIR}/arachne-quota-state"
    run bash "${SCRIPT}" -R impl "작업"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OUTPUT_FROM_codex-task"* ]]
    [[ "$output" == *"skip claude (쿨다운"* ]]
}

@test "atask: 미설치 CLI 는 건너뛴다" {
    # codex-task 만 만들고 claude 는 만들지 않음 → impl 에서 claude skip.
    # 디렉터리 허용(/usr/bin 등)만으로는 호스트에 /usr/bin/claude 가 있으면 실제
    # CLI 가 호출돼 비결정 실패·토큰 소모가 난다(A-11). 필요한 도구만 심볼릭한
    # 밀폐 PATH 를 구성해 어떤 호스트 배치에서도 claude 미감지를 보장한다.
    make_mock codex-task

    local safe_bin="${TMP_DIR}/safebin"
    mkdir -p "${safe_bin}"
    local tool
    for tool in bash sh cat date grep head cut mkdir mktemp mv rm basename tr sed wc; do
        ln -s "$(command -v "${tool}")" "${safe_bin}/${tool}" 2>/dev/null || true
    done

    PATH="${MOCK_BIN}:${safe_bin}" run bash "${SCRIPT}" -R impl "작업"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip claude (미설치)"* ]]
    [[ "$output" == *"OUTPUT_FROM_codex-task"* ]]
}

@test "atask: 빈 프롬프트는 usage 와 함께 실패" {
    make_mock claude
    run bash "${SCRIPT}" -R impl
    [ "$status" -eq 1 ]
    [[ "$output" == *"프롬프트가 비어 있습니다"* ]]
}

@test "atask: 알 수 없는 역할은 실패" {
    run bash "${SCRIPT}" -R bogus "작업"
    [ "$status" -eq 1 ]
    [[ "$output" == *"알 수 없는 역할"* ]]
}

#-------------------------------------------------------------------------------
# #31: 쿼터 단어가 섞인 일반 오류는 폴백하지 않는다 (오판 방지)
#-------------------------------------------------------------------------------
@test "atask(#31): 'disk quota exceeded' 는 쿼터 소진으로 오판하지 않고 중단" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    CLAUDE_BEHAVIOR=diskquota run bash "${SCRIPT}" -R impl "작업"
    [ "$status" -eq 1 ]
    [[ "$output" != *"OUTPUT_FROM_codex-task"* ]]
    [[ "$output" == *"폴백 중단"* ]]
    # claude 쿨다운이 등록되지 않아야 함
    [ ! -f "${ARACHNE_STATE_DIR}/arachne-quota-state" ] || ! grep -q "^claude	" "${ARACHNE_STATE_DIR}/arachne-quota-state"
}

#-------------------------------------------------------------------------------
# #32: 모델 옵션(-m) 제거 — 알 수 없는 옵션으로 거부
#-------------------------------------------------------------------------------
@test "atask(#32): -m 옵션은 제거되어 거부된다" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    run bash "${SCRIPT}" -m gpt-4 "작업"
    [ "$status" -eq 1 ]
    [[ "$output" == *"알 수 없는 옵션: -m"* ]]
}

#-------------------------------------------------------------------------------
# #37: 쿨다운 표시가 GNU date -d 없이 상대 시간으로 — '?' 없이 표시
#-------------------------------------------------------------------------------
@test "atask(#37): --dry-run 쿨다운 표시는 상대 시간(분)으로 출력" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    mkdir -p "${ARACHNE_STATE_DIR}"
    printf 'claude\t%s\n' "$(( $(date +%s) + 6000 ))" > "${ARACHNE_STATE_DIR}/arachne-quota-state"
    run bash "${SCRIPT}" --dry-run -R impl "작업"
    [ "$status" -eq 0 ]
    [[ "$output" == *"분 후 회복"* || "$output" == *"m 후 회복"* ]]
    [[ "$output" != *": cooldown until"* ]]
    [[ "$output" != *"?"* ]]
}

#-------------------------------------------------------------------------------
# #26: impl 폴백 시 역할·커밋 자동 승계가 아님을 경고
#-------------------------------------------------------------------------------
@test "atask(#26): impl 에서 claude 아닌 후보가 처리하면 역할 비승계 경고" {
    make_mock claude; make_mock codex-task; make_mock gemini-task
    CLAUDE_BEHAVIOR=quota run bash "${SCRIPT}" -R impl "작업"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OUTPUT_FROM_codex-task"* ]]
    [[ "$output" == *"역할 제한"* ]]
    [[ "$output" == *"자동 승계 아님"* ]]
}
