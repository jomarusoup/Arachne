#!/usr/bin/env bats
################################################################################
# FILE NAME   : collect.bats
# DESCRIPTION : templates/project/c-system/tools/collect.sh 계약 검증 — dry-run 은 아무것도
#               만들지 않음, --env prod 프로파일링 거부, 운영 표시 파일 존중, 환경 미지정
#               프로파일링 거부, 로그 꼬리의 카드·주민등록번호 모양 숫자 마스킹, tar.gz 생성,
#               환경변수 미수집, 잘못된 인자 종료 코드.
#               bash 3.2 는 마지막이 아닌 [[ ]] 실패로 테스트를 떨어뜨리지 않으므로
#               단언은 [ ] 와 grep -q 로만 쓴다. 샘플 숫자는 검증 자리가 맞지 않는 합성 값이다.
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SCRIPT="${REPO_DIR}/templates/project/c-system/tools/collect.sh"
    TMP_DIR=$(mktemp -d)
    OUT_DIR="${TMP_DIR}/out"
    mkdir -p "${OUT_DIR}"
    # 운영 표시 파일이 이 머신의 실제 설정에 좌우되지 않게 없는 경로로 고정한다
    export COLLECT_ENV_MARKER="${TMP_DIR}/no-marker"
    cat > "${TMP_DIR}/app.log" <<'EOF'
ts=2026-10-05T10:00:00.000100+09:00 lvl=INFO txn=G01-1728104602123456-000042 msg=pay card=4000 1234 5678 9011 amt=5000
ts=2026-10-05T10:00:00.000200+09:00 lvl=INFO txn=G01-1728104602123456-000043 msg=join rrn=900101-1234567
ts=2026-10-05T10:00:00.000300+09:00 lvl=INFO txn=G01-1728104602123456-000044 msg=pan 4000123456789011 5000
EOF
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# 헬퍼: 파일에 패턴이 있으면 실패한다 (! grep 은 마지막 줄이 아니면 실패로 치지 않는다)
#-------------------------------------------------------------------------------
refute_grep() {
    if grep -q "$@"; then
        echo "있으면 안 되는 내용 발견: $1"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# 헬퍼: 결과 tar.gz 를 풀어 묶음 디렉터리 경로를 출력한다
#-------------------------------------------------------------------------------
extract_bundle() {
    local tarball
    tarball=$(ls "${OUT_DIR}"/collect-*.tar.gz)
    mkdir -p "${TMP_DIR}/x"
    tar -xzf "${tarball}" -C "${TMP_DIR}/x"
    ls -d "${TMP_DIR}"/x/collect-*
}

@test "collect: dry-run 은 계획만 출력하고 아무 파일도 만들지 않는다" {
    run bash "${SCRIPT}" --dry-run --log "${TMP_DIR}/app.log" --out "${OUT_DIR}"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'dry-run'
    echo "$output" | grep -q 'app.log'
    [ -z "$(ls -A "${OUT_DIR}")" ]
}

@test "collect: --env prod 와 --allow-profile 은 거부(3)하고 아무것도 만들지 않는다" {
    run bash "${SCRIPT}" --env prod --allow-profile --out "${OUT_DIR}"
    [ "$status" -eq 3 ]
    echo "$output" | grep -q '운영 서버'
    [ -z "$(ls -A "${OUT_DIR}")" ]
}

@test "collect: 운영 표시 파일에 prod 가 있으면 --env staging 이어도 프로파일링 거부" {
    printf 'prod\n' > "${TMP_DIR}/marker"
    COLLECT_ENV_MARKER="${TMP_DIR}/marker" run bash "${SCRIPT}" --env staging --allow-profile --out "${OUT_DIR}"
    [ "$status" -eq 3 ]
    [ -z "$(ls -A "${OUT_DIR}")" ]
}

@test "collect: 환경을 밝히지 않은 프로파일링 요청은 거부" {
    run bash "${SCRIPT}" --allow-profile --dry-run --out "${OUT_DIR}"
    [ "$status" -eq 3 ]
    echo "$output" | grep -q -- '--env dev'
}

@test "collect: tar.gz 를 만들고 로그 꼬리의 카드·주민등록번호 모양 숫자를 가린다" {
    run bash "${SCRIPT}" --log "${TMP_DIR}/app.log" --tail 50 --out "${OUT_DIR}"
    [ "$status" -eq 0 ]
    ls "${OUT_DIR}"/collect-*.tar.gz > /dev/null

    bundle=$(extract_bundle)
    [ -f "${bundle}/MANIFEST.txt" ]
    [ -f "${bundle}/system.txt" ]
    [ -f "${bundle}/ipc.txt" ]
    [ -f "${bundle}/process.txt" ]
    [ -f "${bundle}/socket.txt" ]
    masked="${bundle}/logs/1-app.log.masked"
    [ -f "${masked}" ]
    # 원문 숫자는 남지 않는다
    refute_grep '4000 1234 5678 9011' "${masked}"
    refute_grep '4000123456789011' "${masked}"
    refute_grep '1234567' "${masked}"
    # 끝 4자리·주민번호 앞 7자리·거래 ID·금액은 남는다
    grep -q 'card=\*\*\*\* \*\*\*\* \*\*\*\* 9011 amt=5000' "${masked}"
    grep -q 'rrn=900101-1\*\*\*\*\*\*' "${masked}"
    grep -q 'pan \*\*\*\*\*\*\*\*\*\*\*\*9011 5000' "${masked}"
    grep -q 'txn=G01-1728104602123456-000042' "${masked}"
}

@test "collect: 전화번호·이메일도 가린다(끝 4자리·아이디 첫 글자만 남김)" {
    printf '%s\n' 'ts=1 txn=T1 phone=010-1234-5678 tel=02-345-6789 mail=kim.cs@example.com amt=15000' \
        > "${TMP_DIR}/contact.log"
    run bash "${SCRIPT}" --env dev --log "${TMP_DIR}/contact.log" --out "${OUT_DIR}"
    [ "$status" -eq 0 ]
    bundle=$(extract_bundle)
    masked=$(ls "${bundle}"/logs/*contact.log.masked)
    refute_grep '1234-5678' "${masked}"
    refute_grep '345-6789' "${masked}"
    refute_grep 'kim.cs@' "${masked}"
    grep -q 'phone=010-\*\*\*\*-5678' "${masked}"
    grep -q 'tel=02-\*\*\*\*-6789' "${masked}"
    grep -q 'mail=k\*\*\*@example.com' "${masked}"
    grep -q 'amt=15000' "${masked}"
}

@test "collect: 환경변수 값을 수집하지 않는다" {
    COLLECT_CANARY_SECRET=canary-value-7f3 run bash "${SCRIPT}" --out "${OUT_DIR}"
    [ "$status" -eq 0 ]
    bundle=$(extract_bundle)
    refute_grep -r 'canary-value-7f3' "${bundle}"
}

@test "collect: 읽을 수 없는 로그는 MISSING.txt 에 경로만 적고 계속한다" {
    run bash "${SCRIPT}" --log "${TMP_DIR}/none.log" --out "${OUT_DIR}"
    [ "$status" -eq 0 ]
    bundle=$(extract_bundle)
    grep -q 'none.log' "${bundle}/logs/MISSING.txt"
}

@test "collect: 잘못된 인자는 사용법 오류(2)" {
    run bash "${SCRIPT}" --env qa --out "${OUT_DIR}"
    [ "$status" -eq 2 ]
    run bash "${SCRIPT}" --name 'bad name;rm' --out "${OUT_DIR}"
    [ "$status" -eq 2 ]
    run bash "${SCRIPT}" --tail abc --out "${OUT_DIR}"
    [ "$status" -eq 2 ]
    run bash "${SCRIPT}" --unknown
    [ "$status" -eq 2 ]
}
