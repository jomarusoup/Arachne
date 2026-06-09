#!/usr/bin/env bats
################################################################################
# FILE NAME   : install.bats
# DESCRIPTION : install.sh 동작 검증 테스트
# DATA        : 2026-06-01
# Modification: 2026-06-09
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
