#!/usr/bin/env bats
################################################################################
# FILE NAME   : skill_meta.bats
# DESCRIPTION : skills/*.md frontmatter 계약 검증 — name(파일명 일치)·description·
#               triggers(paths·keywords) 필드가 전 스킬에 존재하는지 검사한다.
#               triggers 는 스킬 라우팅 힌트의 결정론 비율을 높이는 계약 필드다.
# DATA        : 2026-07-02
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SKILLS_DIR="${REPO_DIR}/skills"

#-------------------------------------------------------------------------------
# 헬퍼: 스킬 파일의 frontmatter 블록만 출력 (첫 --- ~ 둘째 --- 사이)
#-------------------------------------------------------------------------------
frontmatter() {
    awk '/^---$/{c++; next} c==1' "$1"
}

skill_files() {
    local path
    for path in "${SKILLS_DIR}"/*.md; do
        [ "$(basename "$path")" = "README.md" ] && continue
        echo "$path"
    done
}

@test "skill meta: 모든 스킬에 frontmatter 블록 존재" {
    local bad=""
    local path
    while read -r path; do
        head -1 "$path" | grep -q '^---$' || bad="${bad} $(basename "$path")"
    done < <(skill_files)
    [ -z "$bad" ] || { echo "frontmatter 없음:${bad}"; false; }
}

@test "skill meta: name 필드가 파일명과 일치" {
    local bad=""
    local path stem name
    while read -r path; do
        stem="$(basename "$path" .md)"
        name=$(frontmatter "$path" | grep -E '^name:' | head -1 | sed -E 's/^name:[[:space:]]*//')
        [ "$name" = "$stem" ] || bad="${bad} ${stem}(name:${name:-없음})"
    done < <(skill_files)
    [ -z "$bad" ] || { echo "name 불일치:${bad}"; false; }
}

@test "skill meta: description 필드 비어 있지 않음" {
    local bad=""
    local path desc
    while read -r path; do
        desc=$(frontmatter "$path" | grep -E '^description:[[:space:]]*[^[:space:]]' | head -1)
        [ -n "$desc" ] || bad="${bad} $(basename "$path")"
    done < <(skill_files)
    [ -z "$bad" ] || { echo "description 누락:${bad}"; false; }
}

@test "skill meta: triggers.paths 필드 존재 (빈 배열 허용)" {
    local bad=""
    local path
    while read -r path; do
        frontmatter "$path" | grep -qE '^triggers:' \
            && frontmatter "$path" | grep -qE '^[[:space:]]+paths:[[:space:]]*\[' \
            || bad="${bad} $(basename "$path")"
    done < <(skill_files)
    [ -z "$bad" ] || { echo "triggers.paths 누락:${bad}"; false; }
}

@test "skill meta: triggers.keywords 는 비어 있지 않은 배열" {
    local bad=""
    local path
    while read -r path; do
        frontmatter "$path" | grep -qE '^[[:space:]]+keywords:[[:space:]]*\["' \
            || bad="${bad} $(basename "$path")"
    done < <(skill_files)
    [ -z "$bad" ] || { echo "triggers.keywords 누락 또는 빈 배열:${bad}"; false; }
}
