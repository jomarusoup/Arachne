#!/usr/bin/env bats
################################################################################
# FILE NAME   : new_project.bats
# DESCRIPTION : arachne new <project> 스캐폴딩 동작 검증
# DATA        : 2026-06-06
# Modification: 2026-06-12
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TMP_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#===============================================================================
# FUNCTION    : run_new
# DESCRIPTION : install.sh new 를 격리된 parent(TMP_DIR) 에 실행
#===============================================================================
run_new() {
    run bash "${REPO_DIR}/install.sh" new "$@"
}

#-------------------------------------------------------------------------------
# 구조 생성 검증
#-------------------------------------------------------------------------------
@test "new: 기록 구조 생성 (README + docs/{issue,idea,task,template})" {
    run_new myproj "${TMP_DIR}"
    [ "$status" -eq 0 ]
    [ -f "${TMP_DIR}/myproj/README.md" ]
    [ -d "${TMP_DIR}/myproj/docs/issue" ]
    [ -d "${TMP_DIR}/myproj/docs/idea" ]
    [ -d "${TMP_DIR}/myproj/docs/task" ]
    [ -f "${TMP_DIR}/myproj/docs/task/README.md" ]
    [ -f "${TMP_DIR}/myproj/docs/template/example.md" ]
    [ -f "${TMP_DIR}/myproj/docs/template/task.md" ]
}

@test "new: 프로젝트 검증 스크립트와 GitHub Actions workflow 생성" {
    run_new myproj "${TMP_DIR}"
    [ "$status" -eq 0 ]
    [ -x "${TMP_DIR}/myproj/.arachne/verify.sh" ]
    [ -f "${TMP_DIR}/myproj/.arachne/commands" ]
    [ -f "${TMP_DIR}/myproj/.github/workflows/arachne.yml" ]
    grep -qF "bash .arachne/verify.sh" \
        "${TMP_DIR}/myproj/.github/workflows/arachne.yml"
}

@test "new: web profile 프로젝트 검증 계약 생성" {
    run_new myproj "${TMP_DIR}" --profile web
    [ "$status" -eq 0 ]
    [ "$(cat "${TMP_DIR}/myproj/.arachne/profile")" = "web" ]
    grep -qF "pnpm install --frozen-lockfile" \
        "${TMP_DIR}/myproj/.arachne/commands"
}

@test "new: 알 수 없는 profile 거부" {
    run_new myproj "${TMP_DIR}" --profile unknown
    [ "$status" -ne 0 ]
    [[ "$output" == *"알 수 없는 profile"* ]]
    [ ! -e "${TMP_DIR}/myproj" ]
}

@test "new: 빈 디렉터리에 .gitkeep 배치" {
    run_new myproj "${TMP_DIR}"
    [ -f "${TMP_DIR}/myproj/docs/issue/.gitkeep" ]
    [ -f "${TMP_DIR}/myproj/docs/idea/.gitkeep" ]
}

#-------------------------------------------------------------------------------
# frontmatter — example.md SSOT 치환
#-------------------------------------------------------------------------------
@test "new: README frontmatter 치환 (Title·날짜·MOC)" {
    run_new myproj "${TMP_DIR}"
    local today
    today=$(date +%F)
    grep -qF "Title: myproj" "${TMP_DIR}/myproj/README.md"
    grep -qF "creation: ${today}" "${TMP_DIR}/myproj/README.md"
    grep -qF "MOC:: [[myproj]]" "${TMP_DIR}/myproj/README.md"
    run grep -F "YYYY-MM-DD" "${TMP_DIR}/myproj/README.md"
    [ "$status" -ne 0 ]   # 플레이스홀더가 남아있으면 안 됨
}

@test "new: 복사된 template/example.md 는 원본과 동일" {
    run_new myproj "${TMP_DIR}"
    run diff "${REPO_DIR}/docs/template/example.md" "${TMP_DIR}/myproj/docs/template/example.md"
    [ "$status" -eq 0 ]
}

@test "new: task 규약과 템플릿은 원본과 동일" {
    run_new myproj "${TMP_DIR}"
    run diff "${REPO_DIR}/docs/task/README.md" "${TMP_DIR}/myproj/docs/task/README.md"
    [ "$status" -eq 0 ]
    run diff "${REPO_DIR}/docs/template/task.md" "${TMP_DIR}/myproj/docs/template/task.md"
    [ "$status" -eq 0 ]
}

#-------------------------------------------------------------------------------
# 지침 스텁 — 프로젝트 AGENTS.md(SSOT) + CLAUDE.md 포인터
#-------------------------------------------------------------------------------
@test "new: AGENTS.md 스텁 생성 (프로젝트명 치환 + 필수 섹션)" {
    run_new myproj "${TMP_DIR}"
    [ "$status" -eq 0 ]
    [ -f "${TMP_DIR}/myproj/AGENTS.md" ]
    grep -qF "# myproj" "${TMP_DIR}/myproj/AGENTS.md"
    grep -qF "## 구조" "${TMP_DIR}/myproj/AGENTS.md"
    grep -qF "## 빌드·검증" "${TMP_DIR}/myproj/AGENTS.md"
    grep -qF "## grep 키워드 매핑" "${TMP_DIR}/myproj/AGENTS.md"
    grep -qF "## 학습된 패턴" "${TMP_DIR}/myproj/AGENTS.md"
    run grep -F "{{PROJECT}}" "${TMP_DIR}/myproj/AGENTS.md"
    [ "$status" -ne 0 ]   # 플레이스홀더가 남아있으면 안 됨
}

@test "new: CLAUDE.md 는 AGENTS.md 포인터" {
    run_new myproj "${TMP_DIR}"
    [ "$status" -eq 0 ]
    [ -f "${TMP_DIR}/myproj/CLAUDE.md" ]
    grep -qF "@AGENTS.md" "${TMP_DIR}/myproj/CLAUDE.md"
    run grep -F "{{PROJECT}}" "${TMP_DIR}/myproj/CLAUDE.md"
    [ "$status" -ne 0 ]
}

@test "new: 프로젝트명의 sed 메타문자(&) 오치환 없음" {
    run_new "AT&T" "${TMP_DIR}"
    [ "$status" -eq 0 ]
    grep -qF "# AT&T" "${TMP_DIR}/AT&T/AGENTS.md"
    run grep -F "{{PROJECT}}" "${TMP_DIR}/AT&T/AGENTS.md"
    [ "$status" -ne 0 ]
}

@test "new: AGENTS.md 스텁 섹션은 미기재 마커 포함" {
    run_new myproj "${TMP_DIR}"
    [ "$status" -eq 0 ]
    grep -qF "<!-- 미기재:" "${TMP_DIR}/myproj/AGENTS.md"
}

#-------------------------------------------------------------------------------
# git init
#-------------------------------------------------------------------------------
@test "new: 기본은 git init 수행" {
    run_new myproj "${TMP_DIR}"
    [ -d "${TMP_DIR}/myproj/.git" ]
}

@test "new: --no-git 은 git init 생략" {
    run_new myproj "${TMP_DIR}" --no-git
    [ "$status" -eq 0 ]
    [ ! -d "${TMP_DIR}/myproj/.git" ]
}

#-------------------------------------------------------------------------------
# 안전성
#-------------------------------------------------------------------------------
@test "new: 프로젝트명 없으면 에러" {
    run bash "${REPO_DIR}/install.sh" new
    [ "$status" -ne 0 ]
}

@test "new: 이미 존재하는 디렉터리면 거부" {
    mkdir -p "${TMP_DIR}/myproj"
    run_new myproj "${TMP_DIR}"
    [ "$status" -ne 0 ]
    [[ "$output" == *"이미 존재"* ]]
}

@test "new: 프로젝트명에 슬래시 거부" {
    run_new "a/b" "${TMP_DIR}"
    [ "$status" -ne 0 ]
}
