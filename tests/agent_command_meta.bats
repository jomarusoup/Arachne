#!/usr/bin/env bats
################################################################################
# FILE NAME   : agent_command_meta.bats
# DESCRIPTION : agents/·commands/ 의 frontmatter 형식을 고정한다.
#               스킬은 skill_meta.bats 가 같은 역할을 한다.
#                 - 에이전트: name·description·tools·model 필수, name = 파일명,
#                   방어 기준선 절 존재, 리뷰어(-reviewer)는 쓰기 도구 금지
#                 - 커맨드: description 필수
# DATA        : 2026-10-05
# Modification: 2026-10-05
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# frontmatter 블록(첫 번째 --- 와 두 번째 --- 사이)을 출력한다
frontmatter() {
    awk '/^---$/{c++; next} c==1' "$1"
}

@test "agent meta: 필수 필드 4종(name·description·tools·model)" {
    local bad=""
    local file field
    for file in "${REPO_DIR}"/agents/*.md; do
        for field in name description tools model; do
            frontmatter "${file}" | grep -qE "^${field}:" || bad="${bad} $(basename "${file}"):${field}"
        done
    done
    [ -z "${bad}" ] || { echo "필드 없음:${bad}"; false; }
}

@test "agent meta: name 이 파일명과 같음" {
    local bad=""
    local file name
    for file in "${REPO_DIR}"/agents/*.md; do
        name=$(frontmatter "${file}" | sed -nE 's/^name:[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/p')
        [ "${name}" = "$(basename "${file}" .md)" ] || bad="${bad} $(basename "${file}")"
    done
    [ -z "${bad}" ] || { echo "불일치:${bad}"; false; }
}

@test "agent meta: 모든 에이전트에 프롬프트 방어 기준선 절" {
    local bad=""
    local file
    for file in "${REPO_DIR}"/agents/*.md; do
        grep -q '프롬프트 방어 기준선' "${file}" || bad="${bad} $(basename "${file}")"
    done
    [ -z "${bad}" ] || { echo "방어 기준선 없음:${bad}"; false; }
}

@test "agent meta: 리뷰어 에이전트는 Write·Edit 도구를 갖지 않음" {
    local bad=""
    local file
    for file in "${REPO_DIR}"/agents/*-reviewer.md; do
        frontmatter "${file}" | grep -E '^tools:' | grep -qE 'Write|Edit' && bad="${bad} $(basename "${file}")"
    done
    [ -z "${bad}" ] || { echo "쓰기 도구 보유:${bad}"; false; }
}

@test "command meta: 모든 커맨드에 description" {
    local bad=""
    local file
    for file in "${REPO_DIR}"/commands/*.md; do
        frontmatter "${file}" | grep -qE '^description:' || bad="${bad} $(basename "${file}")"
    done
    [ -z "${bad}" ] || { echo "description 없음:${bad}"; false; }
}

@test "skill·command: 예시 코드의 위치 인자 자리표시자는 이스케이프" {
    # 스킬·커맨드를 인자와 함께 호출하면 본문의 $1 · $2 가 치환된다.
    # 예시 SQL 의 자리표시자가 깨지지 않게 \$1 로 쓰거나 ? 표기를 쓴다.
    run bash -c "grep -nE '(^|[^\\\\])\\\$[0-9]' '${REPO_DIR}'/skills/*/SKILL.md"
    [ -z "$output" ] || { echo "이스케이프 안 된 자리표시자: $output"; false; }
}
