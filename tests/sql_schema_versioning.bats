#!/usr/bin/env bats
################################################################################
# FILE NAME   : sql_schema_versioning.bats
# DESCRIPTION : templates/project/sql/apply-schema.sh 계약 검증 — 버전 정렬(V2 < V10),
#               dry-run 계획, 적용된 버전 건너뛰기, 버전 중복·잘못된 파일명 거부,
#               체크섬 불일치 거부, 첫 실패에서 중단, 접속 정보 비출력.
#               DB 없이 --applied-from 과 가짜 SQL_CLIENT 로 검증한다.
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SCRIPT="${REPO_DIR}/templates/project/sql/apply-schema.sh"
    TMP_DIR=$(mktemp -d)
    SQL_DIR="${TMP_DIR}/sql"
    mkdir -p "${SQL_DIR}/postgres" "${SQL_DIR}/oracle"
    unset SQL_CLIENT SQL_APPLIED_CMD
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# 헬퍼: 방언 디렉터리에 SQL 파일 생성
#-------------------------------------------------------------------------------
make_sql() {
    printf '%s\n' "${3:-SELECT 1;}" > "${SQL_DIR}/$1/$2"
}

@test "apply-schema: 템플릿 스크립트와 방언별 SCHEMA_HISTORY DDL 존재" {
    [ -x "${SCRIPT}" ]
    grep -qi "CREATE TABLE SCHEMA_HISTORY" "${REPO_DIR}/templates/project/sql/oracle/V1__create_schema_history.sql"
    grep -qi "CREATE TABLE schema_history" "${REPO_DIR}/templates/project/sql/postgres/V1__create_schema_history.sql"
}

@test "apply-schema: 버전은 숫자 순서로 정렬 (V2 가 V10 보다 먼저)" {
    make_sql postgres V10__ten.sql
    make_sql postgres V2__two.sql
    make_sql postgres V1__one.sql
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" --empty-db --dry-run
    [ "$status" -eq 0 ]
    local order
    order=$(printf '%s\n' "$output" | grep PENDING | awk '{print $2}' | tr '\n' ' ')
    [ "$order" = "V1 V2 V10 " ]
}

@test "apply-schema: dry-run 은 계획만 출력하고 SQL_CLIENT 를 실행하지 않음" {
    make_sql postgres V1__one.sql
    export SQL_CLIENT="touch ${TMP_DIR}/client-called"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" --empty-db --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"미적용=1건"* ]]
    [[ "$output" == *"dry-run"* ]]
    [ ! -e "${TMP_DIR}/client-called" ]
}

@test "apply-schema: 적용된 버전은 건너뛰고 미적용만 계획 (앞자리 0 동일 취급)" {
    make_sql postgres V001__one.sql
    make_sql postgres V2__two.sql
    make_sql postgres V3__three.sql
    printf '1\n# 주석\n\n002\n' > "${TMP_DIR}/applied.txt"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" \
        --applied-from "${TMP_DIR}/applied.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"미적용=1건"* ]]
    [[ "$output" == *"PENDING V3"* ]]
    [[ "$output" != *"PENDING V1 "* ]]
    [[ "$output" != *"PENDING V2 "* ]]
}

@test "apply-schema: 버전 번호 중복 거부 (V1 과 V001)" {
    make_sql oracle V1__one.sql
    make_sql oracle V001__dup.sql
    run bash "${SCRIPT}" --dialect oracle --dir "${SQL_DIR}" --empty-db --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *"버전 번호 중복"* ]]
}

@test "apply-schema: 잘못된 파일명 거부" {
    make_sql oracle V1__one.sql
    make_sql oracle create_table.sql
    make_sql oracle V2_missing_double_underscore.sql
    run bash "${SCRIPT}" --dialect oracle --dir "${SQL_DIR}" --empty-db --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *"create_table.sql"* ]]
    [[ "$output" == *"V2_missing_double_underscore.sql"* ]]
}

@test "apply-schema: 적용된 버전의 체크섬 불일치 거부" {
    make_sql postgres V1__one.sql
    printf '1 12345\n' > "${TMP_DIR}/applied.txt"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" \
        --applied-from "${TMP_DIR}/applied.txt" --dry-run
    [ "$status" -eq 3 ]
    [[ "$output" == *"체크섬 불일치"* ]]
}

@test "apply-schema: 최신 적용 버전보다 낮은 미적용 버전은 순서 역전으로 거부" {
    make_sql postgres V1__one.sql
    make_sql postgres V2__late.sql
    make_sql postgres V3__three.sql
    printf '1\n3\n' > "${TMP_DIR}/applied.txt"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" \
        --applied-from "${TMP_DIR}/applied.txt" --dry-run
    [ "$status" -eq 3 ]
    [[ "$output" == *"순서 역전"* ]]
}

@test "apply-schema: 반복 파일 R__ 은 체크섬이 같으면 건너뛰고 바뀌면 다시 계획" {
    make_sql postgres V1__one.sql
    make_sql postgres R__views.sql "CREATE OR REPLACE VIEW v AS SELECT 1;"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" --empty-db --dry-run
    [ "$status" -eq 0 ]
    local sum
    sum=$(printf '%s\n' "$output" | grep "REPEAT" | sed -E 's/.*checksum=//')
    printf '1\nR__views %s\n' "${sum}" > "${TMP_DIR}/applied.txt"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" \
        --applied-from "${TMP_DIR}/applied.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"미적용=0건"* ]]

    make_sql postgres R__views.sql "CREATE OR REPLACE VIEW v AS SELECT 2;"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" \
        --applied-from "${TMP_DIR}/applied.txt" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"REPEAT  R__views"* ]]
}

@test "apply-schema: 실제 적용은 순서대로 실행하고 이력 INSERT 를 함께 보냄" {
    make_sql postgres V1__one.sql "CREATE TABLE a (id int);"
    make_sql postgres V2__two.sql "CREATE TABLE b (id int);"
    export SQL_CLIENT="cat >> ${TMP_DIR}/stream.log"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" --empty-db
    [ "$status" -eq 0 ]
    [[ "$output" == *"완료: 2건 적용"* ]]
    grep -q "ON_ERROR_STOP" "${TMP_DIR}/stream.log"
    grep -q "INSERT INTO SCHEMA_HISTORY .*'V1__one.sql'" "${TMP_DIR}/stream.log"
    local first_b
    local first_a
    first_a=$(grep -n "TABLE a" "${TMP_DIR}/stream.log" | cut -d: -f1)
    first_b=$(grep -n "TABLE b" "${TMP_DIR}/stream.log" | cut -d: -f1)
    [ "${first_a}" -lt "${first_b}" ]
}

@test "apply-schema: 첫 실패에서 중단하고 이후 버전은 실행하지 않음" {
    make_sql oracle V1__ok.sql "CREATE TABLE a (id NUMBER);"
    make_sql oracle V2__bad.sql "FAIL_HERE;"
    make_sql oracle V3__never.sql "CREATE TABLE c (id NUMBER);"
    cat > "${TMP_DIR}/fake_client.sh" <<'EOF'
input=$(cat)
printf '%s\n' "${input}" >> "${FAKE_LOG}"
case "${input}" in *FAIL_HERE*) exit 1 ;; esac
exit 0
EOF
    export FAKE_LOG="${TMP_DIR}/stream.log"
    export SQL_CLIENT="bash ${TMP_DIR}/fake_client.sh"
    run bash "${SCRIPT}" --dialect oracle --dir "${SQL_DIR}" --empty-db
    [ "$status" -eq 4 ]
    [[ "$output" == *"적용 실패: oracle/V2__bad.sql"* ]]
    grep -q "WHENEVER SQLERROR EXIT FAILURE" "${FAKE_LOG}"
    ! grep -q "TABLE c" "${FAKE_LOG}"
}

@test "apply-schema: 접속 정보(SQL_CLIENT 내용)를 출력하지 않음" {
    make_sql postgres V1__one.sql
    export SQL_CLIENT="cat > /dev/null; : SECRET_MARKER_XYZ"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" --empty-db
    [ "$status" -eq 0 ]
    [[ "$output" != *"SECRET_MARKER_XYZ"* ]]
}

@test "apply-schema: 이력 출처가 없으면 거부" {
    make_sql postgres V1__one.sql
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" --dry-run
    [ "$status" -eq 1 ]
    [[ "$output" == *"적용 이력 출처 필요"* ]]
}

@test "apply-schema: PostgreSQL 은 스키마 변경과 이력 INSERT 를 한 트랜잭션(BEGIN…COMMIT)으로 묶음" {
    make_sql postgres V1__one.sql "CREATE TABLE a (id int);"
    export SQL_CLIENT="cat >> ${TMP_DIR}/stream.log"
    run bash "${SCRIPT}" --dialect postgres --dir "${SQL_DIR}" --empty-db
    [ "$status" -eq 0 ]
    local begin_line ddl_line insert_line commit_line
    begin_line=$(grep -n '^BEGIN;' "${TMP_DIR}/stream.log" | head -1 | cut -d: -f1)
    ddl_line=$(grep -n 'CREATE TABLE a' "${TMP_DIR}/stream.log" | head -1 | cut -d: -f1)
    insert_line=$(grep -n 'INSERT INTO SCHEMA_HISTORY' "${TMP_DIR}/stream.log" | head -1 | cut -d: -f1)
    commit_line=$(grep -n '^COMMIT;' "${TMP_DIR}/stream.log" | head -1 | cut -d: -f1)
    [ -n "${begin_line}" ]
    [ "${begin_line}" -lt "${ddl_line}" ]
    [ "${ddl_line}" -lt "${insert_line}" ]
    [ "${insert_line}" -lt "${commit_line}" ]
}
