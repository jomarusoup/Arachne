#!/usr/bin/env bats
################################################################################
# FILE NAME   : ua_stale.bats
# DESCRIPTION : hooks/ua-stale-check.sh 검증 — meta.json 유무·기준 커밋 최신/
#               뒤처짐/유실·비 git 저장소·임계값 동작.
# DATA        : 2026-07-02
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
HOOK="${REPO_DIR}/hooks/ua-stale-check.sh"

setup() {
    FIX="$(mktemp -d)"
}

teardown() {
    rm -rf "${FIX}"
}

#-------------------------------------------------------------------------------
# 헬퍼: 픽스처 git 저장소에 커밋 1개 추가 (해시 stdout)
#-------------------------------------------------------------------------------
add_commit() {
    echo "$RANDOM $1" > "${FIX}/f.txt"
    git -C "${FIX}" add f.txt
    git -C "${FIX}" -c user.email=t@t -c user.name=t commit -qm "$1"
    git -C "${FIX}" rev-parse HEAD
}

make_repo() {
    git -C "${FIX}" init -q
}

make_meta() {
    mkdir -p "${FIX}/.understand-anything"
    printf '{\n  "lastAnalyzedAt": "2026-07-01T00:00:00.000Z",\n  "gitCommitHash": "%s",\n  "version": "1.0.0",\n  "analyzedFiles": 3\n}\n' "$1" \
        > "${FIX}/.understand-anything/meta.json"
}

@test "ua-stale: meta.json 없으면 침묵·종료 0" {
    make_repo
    add_commit c1 >/dev/null
    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ua-stale: git 저장소가 아니면 침묵·종료 0" {
    make_meta "0000000000000000000000000000000000000000"
    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ua-stale: 기준 커밋 == HEAD 이면 침묵" {
    make_repo
    hash=$(add_commit c1)
    make_meta "${hash}"
    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ua-stale: 2커밋 뒤처지면 경고에 개수·기준 커밋·안내 포함" {
    make_repo
    hash=$(add_commit c1)
    make_meta "${hash}"
    add_commit c2 >/dev/null
    add_commit c3 >/dev/null
    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"UA-stale"* ]]
    [[ "$output" == *"2커밋 뒤처짐"* ]]
    [[ "$output" == *"${hash:0:7}"* ]]
    [[ "$output" == *"/understand"* ]]
}

@test "ua-stale: 기준 커밋이 저장소에 없으면 유실 안내·종료 0" {
    make_repo
    add_commit c1 >/dev/null
    make_meta "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"찾을 수 없습니다"* ]]
    [[ "$output" == *"deadbee"* ]]
}

@test "ua-stale: gitCommitHash 필드 없으면 침묵·종료 0" {
    make_repo
    add_commit c1 >/dev/null
    mkdir -p "${FIX}/.understand-anything"
    echo '{"version":"1.0.0"}' > "${FIX}/.understand-anything/meta.json"
    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ua-stale: UA_STALE_THRESHOLD 미만 뒤처짐은 침묵" {
    make_repo
    hash=$(add_commit c1)
    make_meta "${hash}"
    add_commit c2 >/dev/null
    add_commit c3 >/dev/null
    UA_STALE_REPO="${FIX}" UA_STALE_THRESHOLD=5 run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ua-stale: 같은 기준 커밋 경고는 스누즈 기간 내 1회만" {
    make_repo
    hash=$(add_commit c1)
    make_meta "${hash}"
    add_commit c2 >/dev/null

    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"UA-stale"* ]]
    [ -f "${FIX}/.claude/ua-stale-warned" ]

    # 두 번째 실행 — 같은 기준 커밋이므로 침묵
    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "ua-stale: UA_STALE_SNOOZE_DAYS=0 이면 매번 경고" {
    make_repo
    hash=$(add_commit c1)
    make_meta "${hash}"
    add_commit c2 >/dev/null

    UA_STALE_REPO="${FIX}" UA_STALE_SNOOZE_DAYS=0 run bash "${HOOK}"
    [[ "$output" == *"UA-stale"* ]]
    UA_STALE_REPO="${FIX}" UA_STALE_SNOOZE_DAYS=0 run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"UA-stale"* ]]
}

@test "ua-stale: 재분석으로 기준 커밋이 바뀌면 스누즈 무효화·재경고" {
    make_repo
    hash1=$(add_commit c1)
    make_meta "${hash1}"
    add_commit c2 >/dev/null

    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [[ "$output" == *"UA-stale"* ]]

    # 재분석 상당 — 기준 커밋 갱신 후 다시 뒤처짐
    hash2=$(add_commit c3)
    make_meta "${hash2}"
    add_commit c4 >/dev/null
    UA_STALE_REPO="${FIX}" run bash "${HOOK}"
    [ "$status" -eq 0 ]
    [[ "$output" == *"UA-stale"* ]]
}
