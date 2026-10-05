#!/usr/bin/env bats
################################################################################
# FILE NAME   : shm_tools.bats
# DESCRIPTION : templates/project/c-system/tools 공유메모리 운영 도구 계약 검증 —
#               shm_view 기본 마스킹·원문 보기 감사 로그·키/범위 조회,
#               shm_recover 손상 판정·dry-run 무변경·파일 원천 재적재,
#               shmctl.sh 생성·상태·삭제의 dry-run 기본값과 안전 조건.
#               리눅스 전용 동작(attach 프로세스 수)은 macOS 에서 건너뛴다.
################################################################################
# bash 3.2 는 마지막 줄이 아닌 [[ ]] 실패로 테스트를 실패시키지 않는다 — [ ]·grep -q 만 쓴다.

setup_file() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    TOOLS_DIR="${REPO_DIR}/templates/project/c-system/tools"
    if [ -n "${SHM_TOOLS_BIN_DIR:-}" ]; then
        BIN="${SHM_TOOLS_BIN_DIR}"
    else
        BIN="${BATS_FILE_TMPDIR}/bin"
        if command -v cc >/dev/null 2>&1; then
            make -s -C "${TOOLS_DIR}" OUT="${BIN}" >"${BATS_FILE_TMPDIR}/build.log" 2>&1 || true
        fi
    fi
    export REPO_DIR TOOLS_DIR BIN
}

setup() {
    if [ ! -x "${BIN}/shm_view" ] || [ ! -x "${BIN}/shm_recover" ] || \
       [ ! -x "${BIN}/shm_admin" ] || [ ! -x "${BIN}/test_shm_fixture" ]; then
        skip "도구 빌드 실패 또는 C 컴파일러 없음"
    fi
    # macOS POSIX 이름 한도(31자) 안쪽 — 테스트마다 다른 이름
    SEG="/arcbt${BATS_TEST_NUMBER}_$$"
    WORK="${BATS_TEST_TMPDIR}"
    SHMCTL="${TOOLS_DIR}/shmctl.sh"
    "${BIN}/shm_admin" remove "${SEG}" 2>/dev/null || true
}

teardown() {
    if [ -n "${HOLD_PID:-}" ]; then
        kill "${HOLD_PID}" 2>/dev/null || true
        wait "${HOLD_PID}" 2>/dev/null || true
    fi
    if [ -n "${SEG:-}" ] && [ -x "${BIN}/shm_admin" ]; then
        "${BIN}/shm_admin" remove "${SEG}" 2>/dev/null || true
    fi
}

# 합성 원천 — 키 순서를 섞어 둔다(정렬은 도구가 한다)
WriteSourceCsv() {
    printf '%s\n' \
        'item_id,group_id,prc,qty,last_ts,name,flags' \
        '# 합성 데이터' \
        '300,1,500,3,1700000000000003,syn-c,0' \
        '100,1,500,1,1700000000000001,syn-a,0x1' \
        '200,2,500,2,1700000000000002,syn-b,0' > "$1"
}

# 끝난 프로세스의 pid 를 담은 pidfile — "소유 프로세스 멈춤" 상태
WriteStoppedPidfile() {
    sleep 0 &
    local dead_pid=$!
    wait "${dead_pid}" 2>/dev/null || true
    echo "${dead_pid}" > "$1"
}

@test "shm_view: 개인정보 필드는 기본 마스킹" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 5
    run "${BIN}/shm_view" --name "${SEG}"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'masked=yes'
    echo "$output" | grep -q '| \*\*\*\*'
    [ "$(echo "$output" | grep -c 'cust-')" -eq 0 ]
    [ "$(echo "$output" | grep -cE '^[0-9]+ +\|')" -eq 5 ]
}

@test "shm_view: --unmask 는 사유를 감사 로그에 남긴 뒤 원문 출력" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 5
    run "${BIN}/shm_view" --name "${SEG}" --key 30 --format csv \
        --unmask "INC-1234 tester check" --audit-log "${WORK}/audit.log"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^30,2,1002,4,1700000000000002,cust-0003,0x00000000$'
    [ -f "${WORK}/audit.log" ]
    grep -q "action=unmask segment=${SEG} query=key:30 reason=\"INC-1234 tester check\"" "${WORK}/audit.log"
    grep -q "user=$(id -un) uid=$(id -u)" "${WORK}/audit.log"
    if [ "$(uname -s)" = "Linux" ]; then
        perm=$(stat -c '%a' "${WORK}/audit.log")
    else
        perm=$(stat -f '%Lp' "${WORK}/audit.log")
    fi
    [ "${perm}" = "600" ]
}

@test "shm_view: 사유가 짧거나 감사 로그를 못 쓰면 원문 보기 거부" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 2
    run "${BIN}/shm_view" --name "${SEG}" --unmask "ab" --audit-log "${WORK}/audit.log"
    [ "$status" -eq 3 ]
    [ ! -f "${WORK}/audit.log" ]
    run "${BIN}/shm_view" --name "${SEG}" --unmask "INC-1 check" --audit-log "${WORK}/no/dir/a.log"
    [ "$status" -eq 3 ]
    [ "$(echo "$output" | grep -c 'cust-')" -eq 0 ]
}

@test "shm_view: 키·범위 조회(bsearch)와 CSV 출력" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 5
    run "${BIN}/shm_view" --name "${SEG}" --range 15 40 --format csv
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "item_id,group_id,prc,qty,last_ts,name,flags" ]
    [ "${#lines[@]}" -eq 5 ]          # 머리글 + 20·30·40 + 요약(stderr 합침)
    echo "$output" | grep -q '^20,1,1001,2,1700000000000001,\*\*\*\*,0x00000000$'
    run "${BIN}/shm_view" --name "${SEG}" --key 35
    [ "$status" -eq 1 ]
    echo "$output" | grep -q 'rows=0'
}

@test "shm_view --header: 레코드 없이 헤더 요약만" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 5
    run "${BIN}/shm_view" --name "${SEG}" --header
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^state=READY(2)$'
    echo "$output" | grep -q '^rec_cnt=5$'
    echo "$output" | grep -q '^header_check=ok'
    [ "$(echo "$output" | grep -c 'cust-')" -eq 0 ]
}

@test "shm_recover: 매직 손상 → --dry-run 은 CORRUPT 보고만 하고 바꾸지 않음" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 5
    "${BIN}/test_shm_fixture" corrupt-magic "${SEG}"
    WriteSourceCsv "${WORK}/src.csv"
    run "${BIN}/shm_recover" --name "${SEG}" --source "file:${WORK}/src.csv" --dry-run
    [ "$status" -eq 2 ]
    echo "$output" | grep -q '^verdict=CORRUPT$'
    echo "$output" | grep -q '^check.header=매직 불일치$'
    echo "$output" | grep -q '^result=dry-run'
    run "${BIN}/shm_view" --name "${SEG}" --header
    [ "$status" -eq 2 ]
    echo "$output" | grep -q '^magic=0xdeadbeef (bad)$'
    echo "$output" | grep -q '^rec_cnt=5$'
    run "${BIN}/shm_recover" --name "${SEG}" --verify-only
    [ "$status" -eq 2 ]
}

@test "shm_recover: --apply 는 파일 원천으로 재적재하고 READY·검증 통과" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 5
    "${BIN}/test_shm_fixture" corrupt-magic "${SEG}"
    WriteSourceCsv "${WORK}/src.csv"
    run "${BIN}/shm_recover" --name "${SEG}" --source "file:${WORK}/src.csv" --apply --yes \
        --log "${WORK}/recover.log"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^result=READY rec_cnt=3 '
    grep -q 'msg=상태 전환 to=RECOVERING' "${WORK}/recover.log"
    grep -q 'msg=세그먼트 검증 통과 rec_cnt=3' "${WORK}/recover.log"
    grep -q 'msg=상태 전환 to=READY' "${WORK}/recover.log"
    run "${BIN}/shm_recover" --name "${SEG}" --verify-only
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^check.checksum=ok$'
    echo "$output" | grep -q '^check.sorted=ok$'
    run "${BIN}/shm_view" --name "${SEG}" --format csv
    [ "$status" -eq 0 ]
    [ "${lines[1]%%,*}" = "100" ]
    [ "${lines[3]%%,*}" = "300" ]
}

@test "shm_recover: --yes 없는 비대화 --apply 와 중복 키 원천은 세그먼트를 바꾸지 않음" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 5
    "${BIN}/test_shm_fixture" corrupt-magic "${SEG}"
    WriteSourceCsv "${WORK}/src.csv"
    run "${BIN}/shm_recover" --name "${SEG}" --source "file:${WORK}/src.csv" --apply </dev/null
    [ "$status" -eq 3 ]
    echo '100,1,1,1,1,dup,0' >> "${WORK}/src.csv"
    run "${BIN}/shm_recover" --name "${SEG}" --source "file:${WORK}/src.csv" --apply --yes
    [ "$status" -eq 1 ]
    run "${BIN}/shm_view" --name "${SEG}" --header
    echo "$output" | grep -q '^magic=0xdeadbeef (bad)$'
}

@test "shm_recover: 정상 세그먼트는 --force-reload 없이는 재적재하지 않음" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 5
    WriteSourceCsv "${WORK}/src.csv"
    run "${BIN}/shm_recover" --name "${SEG}" --source "file:${WORK}/src.csv" --apply --yes
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^verdict=OK$'
    run "${BIN}/shm_view" --name "${SEG}" --header
    echo "$output" | grep -q '^rec_cnt=5$'
    run "${BIN}/shm_recover" --name "${SEG}" --source "file:${WORK}/src.csv" --apply --yes --force-reload
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^result=READY rec_cnt=3 '
}

@test "shmctl remove: 기본 dry-run, --apply --yes 로만 삭제, 실행 로그 기록" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 5
    WriteStoppedPidfile "${WORK}/owner.pid"
    run bash "${SHMCTL}" remove "${SEG}" --pidfile "${WORK}/owner.pid" \
        --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^owner_process=stopped$'
    echo "$output" | grep -q '^result=dry-run'
    "${BIN}/shm_admin" exists "${SEG}"
    grep -q "action=remove target=${SEG} result=dry-run" "${WORK}/shmctl.log"
    run bash "${SHMCTL}" remove "${SEG}" --apply --yes --pidfile "${WORK}/owner.pid" \
        --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^removed=${SEG}$"
    run "${BIN}/shm_admin" exists "${SEG}"
    [ "$status" -eq 1 ]
    grep -q "action=remove target=${SEG} result=ok" "${WORK}/shmctl.log"
    grep -q "user=$(id -un) " "${WORK}/shmctl.log"
}

@test "shmctl remove: 소유 프로세스가 살아 있거나 확인 수단이 없으면 거부" {
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 1
    echo "$$" > "${WORK}/live.pid"
    run bash "${SHMCTL}" remove "${SEG}" --apply --yes --pidfile "${WORK}/live.pid" \
        --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 3 ]
    echo "$output" | grep -q 'reason=owner-running'
    "${BIN}/shm_admin" exists "${SEG}"
    WriteStoppedPidfile "${WORK}/owner.pid"
    run bash "${SHMCTL}" remove "${SEG}" --apply --pidfile "${WORK}/owner.pid" \
        --log "${WORK}/shmctl.log" --bin-dir "${BIN}" </dev/null
    [ "$status" -eq 3 ]
    echo "$output" | grep -q 'reason=not-confirmed'
    "${BIN}/shm_admin" exists "${SEG}"
    grep -q "result=refused:owner-running" "${WORK}/shmctl.log"
}

@test "shmctl remove: macOS 는 attach 수를 셀 수 없어 --pidfile 없이 거부" {
    if [ "$(uname -s)" = "Linux" ]; then
        skip "리눅스는 /proc 로 attach 수를 센다"
    fi
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 1
    run bash "${SHMCTL}" remove "${SEG}" --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 3 ]
    echo "$output" | grep -q '^attach_count=unknown$'
    echo "$output" | grep -q 'reason=unverifiable'
}

@test "shmctl remove: attach 한 프로세스가 있으면 거부 (리눅스 전용)" {
    if [ "$(uname -s)" != "Linux" ]; then
        skip "attach 프로세스 수는 리눅스 /proc 에서만 센다"
    fi
    "${BIN}/test_shm_fixture" fill "${SEG}" 16 1
    "${BIN}/test_shm_fixture" hold "${SEG}" 30 > "${WORK}/hold.out" &
    HOLD_PID=$!
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        grep -q holding "${WORK}/hold.out" 2>/dev/null && break
        sleep 0.2
    done
    run bash "${SHMCTL}" remove "${SEG}" --apply --yes --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 3 ]
    echo "$output" | grep -q '^attach_count=1$'
    echo "$output" | grep -q 'reason=attached'
}

@test "shmctl create·status: 새로 만들기는 바로, 기존 위 재생성은 dry-run" {
    run bash "${SHMCTL}" create "${SEG}" 8 --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "^created=${SEG} rec_cap=8 "
    run bash "${SHMCTL}" status "${SEG}" --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^state=INIT(1)$'
    echo "$output" | grep -q '^attach_count='
    WriteStoppedPidfile "${WORK}/owner.pid"
    run bash "${SHMCTL}" create "${SEG}" 4 --pidfile "${WORK}/owner.pid" \
        --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^result=dry-run'
    run "${BIN}/shm_view" --name "${SEG}" --header
    echo "$output" | grep -q '^rec_cap=8$'
    grep -q "action=create target=${SEG} result=ok:rec_cap=8,mode=0600" "${WORK}/shmctl.log"
    grep -q "action=status target=${SEG} result=rc=0" "${WORK}/shmctl.log"
}

@test "shmctl: 잘못된 대상 이름·list" {
    run bash "${SHMCTL}" remove "/bad name;rm" --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 1 ]
    run bash "${SHMCTL}" list --log "${WORK}/shmctl.log" --bin-dir "${BIN}"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q '^## SysV'
    grep -q 'action=list target=- result=ok' "${WORK}/shmctl.log"
}
