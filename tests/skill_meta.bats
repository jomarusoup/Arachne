#!/usr/bin/env bats
################################################################################
# FILE NAME   : skill_meta.bats
# DESCRIPTION : skills/<이름>/SKILL.md frontmatter 계약 검증 — Agent Skills 표준
#               포맷(디렉터리 + SKILL.md, name·description 필드) 준수와
#               구 평면 포맷(*.md 단일 파일·triggers 블록)의 회귀를 차단한다.
# DATA        : 2026-07-02
# Modification: 2026-09-13
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILLS_DIR="${REPO_DIR}/skills"

#-------------------------------------------------------------------------------
# 헬퍼: 스킬 파일의 frontmatter 블록만 출력 (첫 --- ~ 둘째 --- 사이)
#-------------------------------------------------------------------------------
frontmatter() {
    awk '/^---$/{c++; next} c==1' "$1"
}

# 스킬 디렉터리 나열 (archive/, Claude 앱 동기화 산출물 synced/ 제외)
skill_dirs() {
    local path
    for path in "${SKILLS_DIR}"/*/; do
        [ "$(basename "$path")" = "archive" ] && continue
        [ "$(basename "$path")" = "synced" ] && continue
        echo "${path%/}"
    done
}

skill_files() {
    local dir
    while read -r dir; do
        echo "${dir}/SKILL.md"
    done < <(skill_dirs)
}

@test "skill meta: skills/ 최상위에 평면 .md 없음 (README.md 제외 — 구 포맷 회귀 차단)" {
    local bad=""
    local path
    for path in "${SKILLS_DIR}"/*.md; do
        [ -e "$path" ] || continue
        [ "$(basename "$path")" = "README.md" ] && continue
        bad="${bad} $(basename "$path")"
    done
    [ -z "$bad" ] || { echo "평면 스킬 파일 발견 — skills/<이름>/SKILL.md 로 두세요:${bad}"; false; }
}

@test "skill meta: 모든 스킬 디렉터리에 SKILL.md 존재" {
    local bad=""
    local dir
    while read -r dir; do
        [ -f "${dir}/SKILL.md" ] || bad="${bad} $(basename "$dir")"
    done < <(skill_dirs)
    [ -z "$bad" ] || { echo "SKILL.md 없음:${bad}"; false; }
}

@test "skill meta: 모든 스킬에 frontmatter 블록 존재" {
    local bad=""
    local path
    while read -r path; do
        [ -f "$path" ] || continue
        head -1 "$path" | grep -q '^---$' || bad="${bad} $(basename "$(dirname "$path")")"
    done < <(skill_files)
    [ -z "$bad" ] || { echo "frontmatter 없음:${bad}"; false; }
}

@test "skill meta: name 필드가 디렉터리명과 일치" {
    local bad=""
    local path stem name
    while read -r path; do
        [ -f "$path" ] || continue
        stem="$(basename "$(dirname "$path")")"
        name=$(frontmatter "$path" | grep -E '^name:' | head -1 | sed -E 's/^name:[[:space:]]*//')
        [ "$name" = "$stem" ] || bad="${bad} ${stem}(name:${name:-없음})"
    done < <(skill_files)
    [ -z "$bad" ] || { echo "name 불일치:${bad}"; false; }
}

@test "skill meta: description 필드 비어 있지 않음" {
    local bad=""
    local path desc
    while read -r path; do
        [ -f "$path" ] || continue
        desc=$(frontmatter "$path" | grep -E '^description:[[:space:]]*[^[:space:]]' | head -1)
        [ -n "$desc" ] || bad="${bad} $(basename "$(dirname "$path")")"
    done < <(skill_files)
    [ -z "$bad" ] || { echo "description 누락:${bad}"; false; }
}

@test "skill meta: 비표준 triggers 블록 없음 (경로·키워드 힌트는 description에)" {
    local bad=""
    local path
    while read -r path; do
        [ -f "$path" ] || continue
        frontmatter "$path" | grep -qE '^triggers:' \
            && bad="${bad} $(basename "$(dirname "$path")")"
    done < <(skill_files)
    [ -z "$bad" ] || { echo "표준 외 triggers 블록 발견:${bad}"; false; }
}
