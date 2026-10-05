#!/usr/bin/env bats
################################################################################
# FILE NAME   : logtrace.bats
# DESCRIPTION : templates/project/c-system/tools/logtrace.sh 계약 검증 — 두 프로세스 로그를
#               시각순으로 합치기, 레벨 필터, 없는 경로 처리, 디렉터리·gz 입력,
#               메시지 안의 txn= 무시, 일치 없음·잘못된 인자 종료 코드.
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SCRIPT="${REPO_DIR}/templates/project/c-system/tools/logtrace.sh"
    TMP_DIR=$(mktemp -d)
    # 서버 프로세스 두 개의 로그 — 같은 거래 T100 이 번갈아 나온다
    cat > "${TMP_DIR}/gw.log" <<'EOF'
ts=2026-10-05T10:00:00.000100+09:00 host=h1 proc=gw pid=10 tid=10 lvl=INFO mod=net file=gw.c fn=Recv:10 txn=T100 msg=요청 수신
ts=2026-10-05T10:00:00.000300+09:00 host=h1 proc=gw pid=10 tid=10 lvl=DEBUG mod=net file=gw.c fn=Fwd:20 txn=T100 msg=전달
ts=2026-10-05T10:00:00.000400+09:00 host=h1 proc=gw pid=10 tid=10 lvl=INFO mod=net file=gw.c fn=Recv:10 txn=T200 msg=다른 거래
ts=2026-10-05T10:00:00.000900+09:00 host=h1 proc=gw pid=10 tid=10 lvl=INFO mod=net file=gw.c fn=Reply:30 txn=T100 msg=응답 송신
EOF
    cat > "${TMP_DIR}/order.log" <<'EOF'
ts=2026-10-05T10:00:00.000200+09:00 host=h1 proc=order pid=20 tid=21 lvl=INFO mod=svc file=order.c fn=Start:5 txn=T100 msg=주문 처리 시작
ts=2026-10-05T10:00:00.000500+09:00 host=h1 proc=order pid=20 tid=21 lvl=ERROR mod=db file=order.c fn=Save:50 txn=T100 msg=insert failed sqlcode=-1 stmt=ORD_INS_01
ts=2026-10-05T10:00:00.000600+09:00 host=h1 proc=order pid=20 tid=21 lvl=WARN mod=svc file=order.c fn=Retry:60 txn=T999 msg=retry txn=T100
EOF
}

teardown() {
    rm -rf "${TMP_DIR}"
}

@test "logtrace: 두 프로세스 로그를 시각순으로 합쳐 일치 줄만 출력" {
    run bash "${SCRIPT}" T100 "${TMP_DIR}/gw.log" "${TMP_DIR}/order.log"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 5 ]
    [[ "${lines[0]}" == *"msg=요청 수신" ]]
    [[ "${lines[1]}" == *"msg=주문 처리 시작" ]]
    [[ "${lines[2]}" == *"msg=전달" ]]
    [[ "${lines[3]}" == *"stmt=ORD_INS_01" ]]
    [[ "${lines[4]}" == *"msg=응답 송신" ]]
}

@test "logtrace: 다른 거래와 메시지 안의 txn= 는 섞이지 않음" {
    run bash "${SCRIPT}" T100 "${TMP_DIR}/gw.log" "${TMP_DIR}/order.log"
    [ "$status" -eq 0 ]
    [[ "$output" != *"txn=T200"* ]]
    [[ "$output" != *"txn=T999"* ]]
}

@test "logtrace: -l WARN 은 WARN 이상만 출력 (소문자 허용)" {
    run bash "${SCRIPT}" -l warn T100 "${TMP_DIR}/gw.log" "${TMP_DIR}/order.log"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == *"lvl=ERROR"* ]]
}

@test "logtrace: 없는 파일은 표준 에러로 알리고 나머지는 처리" {
    run bash -c '"$1" T100 "$2" "$3" 2>/dev/null' _ "${SCRIPT}" "${TMP_DIR}/none.log" "${TMP_DIR}/order.log"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    run bash -c '"$1" T100 "$2" "$3" 2>&1 >/dev/null' _ "${SCRIPT}" "${TMP_DIR}/none.log" "${TMP_DIR}/order.log"
    [[ "$output" == *"경로 없음"* ]]
}

@test "logtrace: 디렉터리 입력과 회전된 gz 파일도 읽음" {
    mkdir -p "${TMP_DIR}/dir"
    mv "${TMP_DIR}/gw.log" "${TMP_DIR}/dir/gw.log-20261005"
    gzip "${TMP_DIR}/dir/gw.log-20261005"
    cp "${TMP_DIR}/order.log" "${TMP_DIR}/dir/order.log"
    echo "ts=2026-10-05T10:00:00.000000+09:00 txn=T100 msg=무시할 파일" > "${TMP_DIR}/dir/notes.txt"
    run bash "${SCRIPT}" T100 "${TMP_DIR}/dir"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 5 ]
    [[ "$output" != *"무시할 파일"* ]]
}

@test "logtrace: 일치 없음은 종료 코드 1, 출력 없음" {
    run bash "${SCRIPT}" T404 "${TMP_DIR}/gw.log"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
}

@test "logtrace: 잘못된 거래 ID·레벨·인자 부족은 종료 코드 2" {
    run bash "${SCRIPT}" 'T1;rm' "${TMP_DIR}/gw.log"
    [ "$status" -eq 2 ]
    run bash "${SCRIPT}" -l LOUD T100 "${TMP_DIR}/gw.log"
    [ "$status" -eq 2 ]
    run bash "${SCRIPT}" T100
    [ "$status" -eq 2 ]
}

@test "logtrace: 시스템 /bin/bash(macOS 는 3.2)로도 같은 결과" {
    [ -x /bin/bash ] || skip "/bin/bash 없음"
    run /bin/bash "${SCRIPT}" -l info T100 "${TMP_DIR}/gw.log" "${TMP_DIR}/order.log"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [[ "${lines[0]}" == *"msg=요청 수신" ]]
    [[ "${lines[3]}" == *"msg=응답 송신" ]]
}

@test "logtrace: bash 3.2 비호환 문법 없음 (연관 배열·mapfile·대소문자 확장)" {
    run grep -nE 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+(,,|\^\^)\}' "${SCRIPT}"
    [ "$status" -eq 1 ]
}
