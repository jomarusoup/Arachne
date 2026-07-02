#!/usr/bin/env bats
################################################################################
# FILE NAME   : hooks.bats
# DESCRIPTION : hooks/ 스크립트 존재·실행권한·기본 동작 검증
# DATA        : 2026-06-01
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOKS_DIR="${REPO_DIR}/hooks"

#-------------------------------------------------------------------------------
# 파일 존재 및 실행 권한
#-------------------------------------------------------------------------------
@test "hooks: session-start.sh 존재" {
    [ -f "${HOOKS_DIR}/session-start.sh" ]
}

@test "hooks: session-start.sh 실행 권한" {
    [ -x "${HOOKS_DIR}/session-start.sh" ]
}

@test "hooks: session-end.sh 존재" {
    [ -f "${HOOKS_DIR}/session-end.sh" ]
}

@test "hooks: session-end.sh 실행 권한" {
    [ -x "${HOOKS_DIR}/session-end.sh" ]
}

@test "hooks: pre-compact.sh 존재" {
    [ -f "${HOOKS_DIR}/pre-compact.sh" ]
}

@test "hooks: pre-compact.sh 실행 권한" {
    [ -x "${HOOKS_DIR}/pre-compact.sh" ]
}

@test "hooks: git-bus-check.sh 존재" {
    [ -f "${HOOKS_DIR}/git-bus-check.sh" ]
}

@test "hooks: git-bus-check.sh 실행 권한" {
    [ -x "${HOOKS_DIR}/git-bus-check.sh" ]
}

@test "hooks: atask-quota-warn.sh 존재·실행권한" {
    [ -f "${HOOKS_DIR}/atask-quota-warn.sh" ]
    [ -x "${HOOKS_DIR}/atask-quota-warn.sh" ]
}

@test "hooks: doc-drift-check.sh 존재·실행권한" {
    [ -f "${HOOKS_DIR}/doc-drift-check.sh" ]
    [ -x "${HOOKS_DIR}/doc-drift-check.sh" ]
}

@test "hooks: ua-stale-check.sh 존재·실행권한" {
    [ -f "${HOOKS_DIR}/ua-stale-check.sh" ]
    [ -x "${HOOKS_DIR}/ua-stale-check.sh" ]
}

#-------------------------------------------------------------------------------
# 문법 검사
#-------------------------------------------------------------------------------
@test "hooks: session-start.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/session-start.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: session-end.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/session-end.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: pre-compact.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/pre-compact.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: git-bus-check.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/git-bus-check.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: atask-quota-warn.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/atask-quota-warn.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: doc-drift-check.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/doc-drift-check.sh"
    [ "$status" -eq 0 ]
}

@test "hooks: ua-stale-check.sh 문법 오류 없음" {
    run bash -n "${HOOKS_DIR}/ua-stale-check.sh"
    [ "$status" -eq 0 ]
}

#-------------------------------------------------------------------------------
# atask-quota-warn.sh: 상태 파일 없으면 조용히 종료
#-------------------------------------------------------------------------------
@test "atask-quota-warn.sh: 상태 파일 없으면 침묵·종료 0" {
    TMP_DIR=$(mktemp -d)
    run env ARACHNE_STATE_DIR="${TMP_DIR}" bash "${HOOKS_DIR}/atask-quota-warn.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# doc-drift-check.sh: 문서 파일 편집은 무시, 기능 파일은 알림
#-------------------------------------------------------------------------------
@test "doc-drift-check.sh: .md 편집은 알림 안 함" {
    TMP_DIR=$(mktemp -d)
    run bash -c "echo '{\"session_id\":\"t\",\"tool_input\":{\"file_path\":\"/x/docs/USAGE.md\"}}' | env ARACHNE_STATE_DIR='${TMP_DIR}' bash '${HOOKS_DIR}/doc-drift-check.sh'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    rm -rf "${TMP_DIR}"
}

@test "doc-drift-check.sh: 기능 파일(.sh) 편집은 알림" {
    TMP_DIR=$(mktemp -d)
    run bash -c "echo '{\"session_id\":\"t2\",\"tool_input\":{\"file_path\":\"/x/install.sh\"}}' | env ARACHNE_STATE_DIR='${TMP_DIR}' bash '${HOOKS_DIR}/doc-drift-check.sh'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"문서 드리프트"* ]]
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# git-bus-check.sh: git 레포 외부에서 조용히 종료
#-------------------------------------------------------------------------------
@test "git-bus-check.sh: git 레포 외부에서 종료 0" {
    # git rev-parse --show-toplevel 이 실패하는 경로에서 실행
    TMP_DIR=$(mktemp -d)
    run bash -c "cd '${TMP_DIR}' && bash '${HOOKS_DIR}/git-bus-check.sh'"
    [ "$status" -eq 0 ]
    rm -rf "${TMP_DIR}"
}

@test "git-bus-check.sh: 리모트 불가(오프라인 상당)에서도 종료 0" {
    # fetch 실패 경로 — 존재하지 않는 origin URL + 스로틀 0으로 fetch 강제
    TMP_DIR=$(mktemp -d)
    git -C "${TMP_DIR}" init -q
    ( cd "${TMP_DIR}" \
      && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m c1 \
      && git remote add origin /nonexistent/offline.git )
    run bash -c "cd '${TMP_DIR}' && GIT_BUS_FETCH_INTERVAL=0 bash '${HOOKS_DIR}/git-bus-check.sh'"
    [ "$status" -eq 0 ]
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# #30: .claude 부재 시에도 기준점(last-seen-commit)을 생성한다 (mkdir 보장)
#-------------------------------------------------------------------------------
@test "git-bus-check.sh(#30): .claude 부재 신규 레포에서 기준점 파일 생성" {
    TMP_REPO=$(mktemp -d)
    git -C "${TMP_REPO}" init -q
    git -C "${TMP_REPO}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    run bash -c "cd '${TMP_REPO}' && bash '${HOOKS_DIR}/git-bus-check.sh'"
    [ "$status" -eq 0 ]
    [ -f "${TMP_REPO}/.claude/last-seen-commit" ]
    rm -rf "${TMP_REPO}"
}

#-------------------------------------------------------------------------------
# F-04: fetch 스로틀 — 스탬프 파일 기록, 간격 내에는 갱신 안 함
#-------------------------------------------------------------------------------
@test "git-bus-check.sh(F-04): fetch 스탬프 파일 생성" {
    TMP_REPO=$(mktemp -d)
    git -C "${TMP_REPO}" init -q
    git -C "${TMP_REPO}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    run bash -c "cd '${TMP_REPO}' && bash '${HOOKS_DIR}/git-bus-check.sh'"
    [ "$status" -eq 0 ]
    [ -f "${TMP_REPO}/.claude/last-fetch-epoch" ]
    rm -rf "${TMP_REPO}"
}

@test "git-bus-check.sh(F-04): 간격 내 스탬프는 갱신하지 않음" {
    TMP_REPO=$(mktemp -d)
    git -C "${TMP_REPO}" init -q
    git -C "${TMP_REPO}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    mkdir -p "${TMP_REPO}/.claude"
    stamp_before=$(( $(date +%s) - 10 ))
    echo "${stamp_before}" > "${TMP_REPO}/.claude/last-fetch-epoch"

    run bash -c "cd '${TMP_REPO}' && bash '${HOOKS_DIR}/git-bus-check.sh'"
    [ "$status" -eq 0 ]
    [ "$(cat "${TMP_REPO}/.claude/last-fetch-epoch")" = "${stamp_before}" ]
    rm -rf "${TMP_REPO}"
}

@test "session-end.sh(#30): .claude 부재 시 기준점 디렉터리 생성 후 기록" {
    TMP_REPO=$(mktemp -d)
    TMP_HOME=$(mktemp -d)
    git -C "${TMP_REPO}" init -q
    git -C "${TMP_REPO}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    run bash -c "cd '${TMP_REPO}' && HOME='${TMP_HOME}' bash '${HOOKS_DIR}/session-end.sh'"
    [ "$status" -eq 0 ]
    [ -f "${TMP_REPO}/.claude/last-seen-commit" ]
    rm -rf "${TMP_REPO}" "${TMP_HOME}"
}

#-------------------------------------------------------------------------------
# 지침 스텁 넛지 — AGENTS.md 미기재 섹션을 스냅샷에 제안으로만 기록
#-------------------------------------------------------------------------------
@test "session-end.sh: AGENTS.md 미기재 섹션 있으면 스냅샷에 넛지 기록" {
    TMP_REPO=$(mktemp -d)
    TMP_HOME=$(mktemp -d)
    git -C "${TMP_REPO}" init -q
    git -C "${TMP_REPO}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    printf '# t\n## 구조\n<!-- 미기재: x -->\n' > "${TMP_REPO}/AGENTS.md"

    run bash -c "cd '${TMP_REPO}' && HOME='${TMP_HOME}' bash '${HOOKS_DIR}/session-end.sh'"
    [ "$status" -eq 0 ]
    grep -q '미기재' "${TMP_HOME}"/.claude/sessions/auto-*.md
    rm -rf "${TMP_REPO}" "${TMP_HOME}"
}

@test "session-end.sh: AGENTS.md 없거나 다 채워지면 넛지 없음" {
    TMP_REPO=$(mktemp -d)
    TMP_HOME=$(mktemp -d)
    git -C "${TMP_REPO}" init -q
    git -C "${TMP_REPO}" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
    printf '# t\n## 구조\n- src/: 코어\n' > "${TMP_REPO}/AGENTS.md"

    run bash -c "cd '${TMP_REPO}' && HOME='${TMP_HOME}' bash '${HOOKS_DIR}/session-end.sh'"
    [ "$status" -eq 0 ]
    # glob 미확장 시 grep 이 exit 2 로 실패해도 ! 가 통과시키므로 파일을 특정해 검사
    local session_file
    session_file=$(ls "${TMP_HOME}"/.claude/sessions/auto-*.md 2>/dev/null | head -1)
    [ -n "$session_file" ]
    ! grep -q '미기재' "$session_file"
    rm -rf "${TMP_REPO}" "${TMP_HOME}"
}

#-------------------------------------------------------------------------------
# #29: 세션 저장(save-session)·복원(훅) 경로 일치 — 홈 절대경로
#-------------------------------------------------------------------------------
@test "session(#29): save-session 저장 경로가 훅의 읽기 경로와 일치" {
    grep -q 'HOME/.claude/sessions' "${HOOKS_DIR}/session-start.sh"
    grep -q 'HOME/.claude/sessions' "${HOOKS_DIR}/session-end.sh"
    grep -q '~/.claude/sessions' "${REPO_DIR}/commands/save-session.md"
    # 옛 프로젝트 상대경로(`.claude/sessions/` 단독)로 안내하지 않아야 함
    ! grep -qE '저장 위치: `\.claude/sessions' "${REPO_DIR}/commands/save-session.md"
}
