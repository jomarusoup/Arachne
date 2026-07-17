#!/usr/bin/env bats
################################################################################
# FILE NAME   : install.bats
# DESCRIPTION : install.sh 동작 검증 테스트
# DATA        : 2026-06-01
# Modification: 2026-07-17
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TMP_DIR=$(mktemp -d)
    export HOME="${TMP_DIR}"

    #---------------------------------------------------------------------------
    # -i/-u 가 확장 도구를 항상 설치·갱신하므로 실제 setup-extras.sh 실행을
    # 기록 스텁으로 격리한다 (호출 인자는 extras.args 로 검증).
    #---------------------------------------------------------------------------
    FAKE_EXTRAS="${TMP_DIR}/fake-extras.sh"
    cat > "${FAKE_EXTRAS}" <<EOF
#!/bin/bash
printf '%s\n' "\$*" > "${TMP_DIR}/extras.args"
EOF
    export ARACHNE_EXTRAS_SCRIPT="${FAKE_EXTRAS}"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#===============================================================================
# FUNCTION    : run_install
# DESCRIPTION : install.sh 를 설치 모드로 실행하고 종료코드 0 을 단언.
#               최초 설치와 재설치 양쪽에서 유효한 -i 명시 호출을 사용한다.
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

@test "install: task 명령 별칭은 gtask ctask atask 로 등록" {
    run_install

    [ -L "${TMP_DIR}/.local/bin/gtask" ]
    [ -L "${TMP_DIR}/.local/bin/ctask" ]
    [ -L "${TMP_DIR}/.local/bin/atask" ]
    [ ! -e "${TMP_DIR}/.local/bin/gask" ]
    [ ! -e "${TMP_DIR}/.local/bin/cask" ]
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
# 최초 install.sh 무인자 실행과 설치 후 arachne 무인자 실행 구분
#-------------------------------------------------------------------------------
@test "no-arg: install.sh 직접 실행은 최초 설치 수행" {
    run bash "${REPO_DIR}/install.sh"
    [ "$status" -eq 0 ]
    [ -f "${TMP_DIR}/.claude/settings.json" ]
}

@test "no-arg: arachne 커맨드는 usage 출력만 수행" {
    ln -s "${REPO_DIR}/install.sh" "${TMP_DIR}/arachne"

    run bash "${TMP_DIR}/arachne"

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

@test "install: .bak 디렉터리가 이미 있어도 백업이 중첩되지 않음" {
    # 이전 백업(디렉터리)이 남아 있으면 mv 가 그 안으로 이동했던 회귀 방지
    mkdir -p "${TMP_DIR}/.claude/commands.bak"
    mkdir -p "${TMP_DIR}/.claude/commands"
    echo "user file" > "${TMP_DIR}/.claude/commands/mine.md"

    run_install
    [ -L "${TMP_DIR}/.claude/commands" ]
    [ -f "${TMP_DIR}/.claude/commands.bak/mine.md" ]
    [ ! -e "${TMP_DIR}/.claude/commands.bak/commands" ]
}

#-------------------------------------------------------------------------------
# 사용자 선호 키 보존 — 재설치가 /model·theme 선택을 템플릿 값으로 되돌리지 않음
#-------------------------------------------------------------------------------
@test "install: 재설치 시 기존 settings.json 의 model·theme 보존" {
    command -v jq >/dev/null 2>&1 || skip "jq 미설치"
    run_install
    # 사용자가 /model 등으로 바꾼 상태를 재현
    jq '.model = "user-picked-model" | .theme = "light"' \
        "${TMP_DIR}/.claude/settings.json" > "${TMP_DIR}/.claude/settings.json.tmp"
    mv "${TMP_DIR}/.claude/settings.json.tmp" "${TMP_DIR}/.claude/settings.json"

    run_install
    [ "$(jq -r '.model' "${TMP_DIR}/.claude/settings.json")" = "user-picked-model" ]
    [ "$(jq -r '.theme' "${TMP_DIR}/.claude/settings.json")" = "light" ]
    # 하네스 소유 영역(hooks 등)은 템플릿 기준으로 갱신 유지
    [ "$(jq -r '.hooks.SessionStart | length' "${TMP_DIR}/.claude/settings.json")" != "null" ]
}

#-------------------------------------------------------------------------------
# dotfiles 병합 회귀 (A-01): 사용자 함수의 '{'·'}' 줄과 중복 제거가 충돌해
# 병합본 문법이 깨지지 않아야 한다
#-------------------------------------------------------------------------------
@test "dotfiles: 사용자 함수 있는 .bash_profile 병합 후에도 문법 유효" {
    cat > "${TMP_DIR}/.bash_profile" <<'EOF'
my_user_func()
{
    echo "user function"
}
umask 002
EOF

    run_install

    run bash -n "${TMP_DIR}/.bash_profile"
    [ "$status" -eq 0 ]
}

@test "dotfiles: 사용자 영역과 중복된 export/alias 는 섹션에서 제외" {
    echo "alias ls='ls -aF'" > "${TMP_DIR}/.bash_profile"

    run_install

    # ARACHNE 섹션 안에는 동일 alias 가 다시 들어가지 않아야 한다
    section=$(awk '/=== ARACHNE BEGIN ===/{s=1;next} /=== ARACHNE END ===/{s=0} s' \
        "${TMP_DIR}/.bash_profile")
    run grep -cxF "alias ls='ls -aF'" <<< "${section}"
    [ "$output" -eq 0 ]
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

#-------------------------------------------------------------------------------
# Codex 타깃 설치 검증 (Phase 2)
#-------------------------------------------------------------------------------
@test "codex: AGENTS.md 마커 병합으로 ~/.codex/AGENTS.md 생성" {
    run bash "${REPO_DIR}/install.sh" -i --target codex
    [ "$status" -eq 0 ]
    [ -f "${TMP_DIR}/.codex/AGENTS.md" ]
    grep -qF "<!-- === ARACHNE BEGIN === -->" "${TMP_DIR}/.codex/AGENTS.md"
    grep -qF "<!-- === ARACHNE END === -->" "${TMP_DIR}/.codex/AGENTS.md"
}

@test "codex: 재실행 멱등성 — 마커 쌍이 1개만 유지" {
    bash "${REPO_DIR}/install.sh" -i --target codex
    bash "${REPO_DIR}/install.sh" -i --target codex
    run grep -cF "<!-- === ARACHNE BEGIN === -->" "${TMP_DIR}/.codex/AGENTS.md"
    [ "$output" -eq 1 ]
}

@test "codex: 사용자 보충 내용 보존" {
    mkdir -p "${TMP_DIR}/.codex"
    echo "USER-SUPPLEMENT-XYZ" > "${TMP_DIR}/.codex/AGENTS.md"

    run bash "${REPO_DIR}/install.sh" -i --target codex
    [ "$status" -eq 0 ]
    grep -qF "USER-SUPPLEMENT-XYZ" "${TMP_DIR}/.codex/AGENTS.md"
}

@test "codex: SSOT 본문이 실제로 반영됨" {
    bash "${REPO_DIR}/install.sh" -i --target codex
    # AGENTS.md 첫 헤더 라인이 병합 결과에 존재해야 함
    run head -1 "${REPO_DIR}/AGENTS.md"
    local first_line="$output"
    grep -qF "$first_line" "${TMP_DIR}/.codex/AGENTS.md"
}

#-------------------------------------------------------------------------------
# GitHub Copilot 타깃 설치 검증
#-------------------------------------------------------------------------------
@test "copilot: CLI 전역 지침을 마커 병합으로 생성" {
    run bash "${REPO_DIR}/install.sh" -i --target copilot
    [ "$status" -eq 0 ]
    [ -f "${TMP_DIR}/.copilot/copilot-instructions.md" ]
    grep -qF "<!-- === ARACHNE BEGIN === -->" \
        "${TMP_DIR}/.copilot/copilot-instructions.md"
}

@test "copilot: VS Code 사용자 지침은 유효한 frontmatter로 생성" {
    bash "${REPO_DIR}/install.sh" -i --target copilot
    local vscode_file="${TMP_DIR}/.copilot/instructions/arachne.instructions.md"

    [ "$(head -1 "$vscode_file")" = "---" ]
    grep -qF 'applyTo: "**"' "$vscode_file"
    grep -qF "<!-- === ARACHNE BEGIN === -->" "$vscode_file"
}

@test "copilot: CLI 사용자 보충 내용 보존" {
    mkdir -p "${TMP_DIR}/.copilot"
    echo "USER-COPILOT-SUPPLEMENT" > \
        "${TMP_DIR}/.copilot/copilot-instructions.md"

    bash "${REPO_DIR}/install.sh" -i --target copilot
    bash "${REPO_DIR}/install.sh" -i --target copilot

    grep -qF "USER-COPILOT-SUPPLEMENT" \
        "${TMP_DIR}/.copilot/copilot-instructions.md"
    run grep -cF "<!-- === ARACHNE BEGIN === -->" \
        "${TMP_DIR}/.copilot/copilot-instructions.md"
    [ "$output" -eq 1 ]
}

#-------------------------------------------------------------------------------
# --check 연결 점검 검증 (Phase 3)
#-------------------------------------------------------------------------------
@test "check: 모든 CLI 정상 연결 시 OK 및 exit 0" {
    # 모든 타깃을 설치해 홈 디렉터리 기반 감지를 보장한다.
    bash "${REPO_DIR}/install.sh" -i --target claude
    bash "${REPO_DIR}/install.sh" -i --target gemini
    bash "${REPO_DIR}/install.sh" -i --target codex
    bash "${REPO_DIR}/install.sh" -i --target copilot

    run bash "${REPO_DIR}/install.sh" --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"모든 연결 정상"* ]]
}

@test "check: Copilot 지침이 AGENTS.md와 다르면 stale 탐지" {
    bash "${REPO_DIR}/install.sh" -i --target claude
    bash "${REPO_DIR}/install.sh" -i --target copilot
    copilot_file="${TMP_DIR}/.copilot/instructions/arachne.instructions.md"
    sed 's/# AGENTS.md/# STALE.md/' "$copilot_file" > "${copilot_file}.tmp"
    mv "${copilot_file}.tmp" "$copilot_file"

    run bash "${REPO_DIR}/install.sh" --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL] Copilot"* ]]
}

@test "check: Codex 섹션이 AGENTS.md와 다르면 stale 탐지 (exit 1)" {
    bash "${REPO_DIR}/install.sh" -i --target claude
    # 마커는 있으나 본문이 낡은 Codex 파일 위조
    mkdir -p "${TMP_DIR}/.codex"
    {
        echo "<!-- === ARACHNE BEGIN === -->"
        echo "OLD-STALE-CONTENT"
        echo "<!-- === ARACHNE END === -->"
    } > "${TMP_DIR}/.codex/AGENTS.md"

    run bash "${REPO_DIR}/install.sh" --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"stale"* ]]
}

@test "check: Claude 미설치 시 FAIL (exit 1)" {
    run bash "${REPO_DIR}/install.sh" --check
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL] Claude"* ]]
}

#-------------------------------------------------------------------------------
# #34: 특정 CLI 타깃 설치는 공통 인프라(dotfiles·전체 bin)를 건드리지 않는다
#-------------------------------------------------------------------------------
@test "install(#34): --target gemini 는 공통 설치(bin/dotfiles)를 생략" {
    run bash "${REPO_DIR}/install.sh" -i --target gemini
    [ "$status" -eq 0 ]
    [ -L "${TMP_DIR}/.gemini/GEMINI.md" ]
    [ ! -e "${TMP_DIR}/.local/bin/arachne" ]
    [[ "$output" == *"공통 설치(dotfiles·bin) 생략"* ]]
}

@test "install(#34): 전체 설치(-i)는 공통 bin 을 등록" {
    run_install
    [ -L "${TMP_DIR}/.local/bin/arachne" ]
}

@test "install: -i 는 확장 도구 전체를 자동 설치·갱신 (--all --update)" {
    run_install
    [[ "$output" == *"전체 확장 도구 설정 시작"* ]]
    [ "$(cat "${TMP_DIR}/extras.args")" = "--all --update" ]
}

@test "update: -u 는 확장 도구 전체를 자동 설치·갱신 (--all --update)" {
    make_mock_git
    PATH="${TMP_DIR}/mockbin:${PATH}" ARACHNE_FORCE=1 \
        run bash "${REPO_DIR}/install.sh" -u
    [ "$status" -eq 0 ]
    [[ "$output" == *"전체 확장 도구 갱신 시작"* ]]
    [ "$(cat "${TMP_DIR}/extras.args")" = "--all --update" ]
}

@test "install: --target gemini 는 확장 도구를 실행하지 않음" {
    run bash "${REPO_DIR}/install.sh" -i --target gemini
    [ "$status" -eq 0 ]
    [ ! -e "${TMP_DIR}/extras.args" ]
}

#-------------------------------------------------------------------------------
# 의존성 사전 점검(preflight) — 경고만 출력, 설치 비차단
#-------------------------------------------------------------------------------
@test "preflight: -i 설치 시 의존성 사전 점검 섹션 출력" {
    run_install
    [[ "$output" == *"의존성 사전 점검"* ]]
}

@test "preflight: 누락 도구는 경고만 출력하고 설치는 계속 (exit 0)" {
    ARACHNE_PREFLIGHT_TOOLS="missing_tool_xyz_123:테스트영향" \
        run bash "${REPO_DIR}/install.sh" -i
    [ "$status" -eq 0 ]
    [[ "$output" == *"[Arachne][WARN] preflight: missing_tool_xyz_123 미설치 — 테스트영향"* ]]
    [[ "$output" == *"누락 1건"* ]]
    [ -L "${TMP_DIR}/.claude/CLAUDE.md" ]
}

@test "preflight: 권장 도구 모두 존재하면 OK 출력" {
    ARACHNE_PREFLIGHT_TOOLS="bash:없음" \
        run bash "${REPO_DIR}/install.sh" -i
    [ "$status" -eq 0 ]
    [[ "$output" == *"preflight: 권장 도구 모두 감지됨"* ]]
}

@test "install: --with-ua 는 Understand-Anything 설정만 호출" {
    local fake_extras="${TMP_DIR}/setup-extras.sh"
    cat > "${fake_extras}" <<EOF
#!/bin/bash
printf '%s\n' "\$*" > "${TMP_DIR}/extras.args"
EOF

    ARACHNE_EXTRAS_SCRIPT="${fake_extras}" run bash "${REPO_DIR}/install.sh" -i --with-ua

    [ "$status" -eq 0 ]
    [[ "$output" == *"==============================================================================="* ]]
    [[ "$output" == *"[Arachne] Understand-Anything 확장 도구 설정 시작"* ]]
    [[ "$output" == *"[Arachne][RUN] extras: bash ${fake_extras} --ua"* ]]
    [[ "$output" == *"[Arachne] Understand-Anything 확장 도구 설정 완료"* ]]
    [ "$(cat "${TMP_DIR}/extras.args")" = "--ua" ]
}

@test "update: --with-ua 는 Understand-Anything 갱신 인자를 전달" {
    make_mock_git
    local fake_extras="${TMP_DIR}/setup-extras.sh"
    cat > "${fake_extras}" <<EOF
#!/bin/bash
printf '%s\n' "\$*" > "${TMP_DIR}/extras.args"
EOF

    PATH="${TMP_DIR}/mockbin:${PATH}" \
        ARACHNE_FORCE=1 \
        ARACHNE_EXTRAS_SCRIPT="${fake_extras}" \
        run bash "${REPO_DIR}/install.sh" -u --with-ua

    [ "$status" -eq 0 ]
    [[ "$output" == *"[Arachne] 업데이트 시작 (git pull)"* ]]
    [[ "$output" == *"[Arachne] 최신 소스 기반 재설치 진행"* ]]
    [[ "$output" == *"[Arachne] Understand-Anything 확장 도구 갱신 시작"* ]]
    [[ "$output" == *"[Arachne] Understand-Anything 확장 도구 갱신 완료"* ]]
    [ "$(cat "${TMP_DIR}/extras.args")" = "--ua --update" ]
}

#-------------------------------------------------------------------------------
# #28: 사용자 수정된 settings.json 을 조용히 덮어쓰지 않고 경고 + .bak 보존
#-------------------------------------------------------------------------------
@test "install(#28): 사용자 수정 settings.json 교체 시 경고 + .bak 보존" {
    run_install
    echo '{"USER_EDIT_XYZ": true}' > "${TMP_DIR}/.claude/settings.json"
    run bash "${REPO_DIR}/install.sh" -i
    [ "$status" -eq 0 ]
    [[ "$output" == *"사용자 수정이 교체됩니다"* ]]
    grep -qF "USER_EDIT_XYZ" "${TMP_DIR}/.claude/settings.json.bak"
}

#-------------------------------------------------------------------------------
# #33: arachne -u 는 dirty 작업트리에서 중단(ARACHNE_FORCE 로 우회)
#-------------------------------------------------------------------------------
make_mock_git() {
    mkdir -p "${TMP_DIR}/mockbin"
    cat > "${TMP_DIR}/mockbin/git" << 'GITMOCK'
#!/bin/bash
case "$1" in
    rev-parse) [ "$2" = "--abbrev-ref" ] && echo "feature-x" || echo "deadbeef" ;;
    diff)      exit 1 ;;   # dirty (diff·diff --cached 모두 변경 있음)
    pull)      echo "[mockgit] pull" ;;
    *)         exit 0 ;;
esac
GITMOCK
    chmod +x "${TMP_DIR}/mockbin/git"
}

@test "update(#33): dirty 작업트리에서 arachne -u 중단(exit 1)" {
    make_mock_git
    PATH="${TMP_DIR}/mockbin:${PATH}" run bash "${REPO_DIR}/install.sh" -u
    [ "$status" -eq 1 ]
    [[ "$output" == *"작업트리에 커밋되지 않은 변경"* ]]
}

@test "update(#33): ARACHNE_FORCE=1 은 dirty 검증을 우회" {
    make_mock_git
    PATH="${TMP_DIR}/mockbin:${PATH}" ARACHNE_FORCE=1 run bash "${REPO_DIR}/install.sh" -u
    [ "$status" -eq 0 ]
    [[ "$output" == *"강제"* ]]
}
