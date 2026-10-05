#!/usr/bin/env bash
################################################################################
# FILE NAME   : apply.sh
# DESCRIPTION : compose 의 일회성 schema 서비스에서 sql/apply-schema.sh 를 부른다.
#               SCHEMA_HISTORY 가 없으면 빈 DB 로 보고(--empty-db), 있으면 그 이력과
#               비교해 미적용 버전만 적용한다. 다시 실행해도 안전하다.
#               접속 정보는 환경변수로만 받고 명령 인자·출력에 남기지 않는다.
#               규약 정본: skills/sql-schema-versioning/SKILL.md
################################################################################
# 사용법:
#   apply.sh postgres|oracle [--dry-run]
#   postgres: PGHOST·PGUSER·PGPASSWORD·PGDATABASE (psql 표준 환경변수)
#   oracle  : ORA_CONNECT(호스트:포트/서비스)·APP_USER·APP_USER_PASSWORD
#   SQL_DIR : sql 루트 (기본 /sql — apply-schema.sh 와 <방언>/ 디렉터리가 있는 곳)
################################################################################

set -euo pipefail

readonly EXIT_USAGE=1

SQL_DIR="${SQL_DIR:-/sql}"
g_HistoryArg=""

#===============================================================================
# FUNCTION    : Die
# DESCRIPTION : 오류 메시지를 표준 에러로 내고 지정 코드로 끝낸다.
# PARAMETERS  : int    code    - 종료 코드
#               string message - 메시지
#===============================================================================
Die() {
    echo "[schema] ERROR: $2" >&2
    exit "$1"
}

#===============================================================================
# FUNCTION    : RequireEnv
# DESCRIPTION : 이름으로 받은 환경변수들이 모두 비어 있지 않은지 확인한다. 값은 출력하지 않는다.
# PARAMETERS  : string names... - 환경변수 이름
#===============================================================================
RequireEnv() {
    local name

    for name in "$@"; do
        [ -n "${!name:-}" ] || Die "${EXIT_USAGE}" "환경변수 ${name} 필요"
    done
}

#===============================================================================
# FUNCTION    : SetupPostgres
# DESCRIPTION : psql 을 SQL_CLIENT 로 정한다. 이력 테이블이 있으면 SQL_APPLIED_CMD 를,
#               없으면 g_HistoryArg 에 --empty-db 를 정한다.
#===============================================================================
SetupPostgres() {
    local exists

    RequireEnv PGHOST PGUSER PGPASSWORD PGDATABASE
    export SQL_CLIENT='psql -X -q'
    exists=$(psql -X -q -t -A -c "SELECT to_regclass('schema_history') IS NOT NULL")
    if [ "${exists}" = "t" ]; then
        export SQL_APPLIED_CMD="psql -X -q -t -A -F ' ' -c \"SELECT coalesce(version, regexp_replace(script, '\\.sql\$', '')), checksum FROM schema_history ORDER BY installed_rank\""
    else
        g_HistoryArg="--empty-db"
    fi
}

#===============================================================================
# FUNCTION    : SetupOracle
# DESCRIPTION : sqlplus 를 SQL_CLIENT 로 정한다. 비밀번호는 sqlplus 명령 인자가 아니라
#               표준입력의 CONNECT 로 넘긴다. 이력 처리는 SetupPostgres 와 같다.
#===============================================================================
SetupOracle() {
    local connect_cmd
    local quiet
    local exists

    RequireEnv ORA_CONNECT APP_USER APP_USER_PASSWORD
    # 아래 두 문자열은 apply-schema.sh 의 bash -c 안에서 펼쳐진다
    connect_cmd='printf "CONNECT %s/\"%s\"@%s\n" "${APP_USER}" "${APP_USER_PASSWORD}" "${ORA_CONNECT}"'
    quiet='printf "SET HEADING OFF FEEDBACK OFF PAGESIZE 0 VERIFY OFF ECHO OFF\n"'
    export SQL_CLIENT="{ ${connect_cmd}; cat; } | sqlplus -s /nolog"
    exists=$( { eval "${connect_cmd}"; eval "${quiet}"
                echo "SELECT COUNT(*) FROM user_tables WHERE table_name = 'SCHEMA_HISTORY';"
                echo "EXIT"; } | sqlplus -s /nolog | tr -d ' \r' | grep -E '^[0-9]+$' | head -n 1 || true)
    if [ "${exists:-0}" -gt 0 ]; then
        export SQL_APPLIED_CMD="{ ${connect_cmd}; ${quiet}; echo \"SELECT NVL(version, REGEXP_REPLACE(script, '\\.sql\$', '')) || ' ' || checksum FROM schema_history ORDER BY installed_rank;\"; echo EXIT; } | sqlplus -s /nolog"
    else
        g_HistoryArg="--empty-db"
    fi
}

#===============================================================================
# FUNCTION    : Main
# DESCRIPTION : 방언별 설정 뒤 apply-schema.sh 를 실행한다.
# PARAMETERS  : string dialect - postgres 또는 oracle
#               string option  - (선택) --dry-run
#===============================================================================
Main() {
    local dialect="${1:-}"
    local extra=()

    [ -f "${SQL_DIR}/apply-schema.sh" ] || Die "${EXIT_USAGE}" "apply-schema.sh 없음: ${SQL_DIR}"
    case "${dialect}" in
        postgres) SetupPostgres ;;
        oracle)   SetupOracle ;;
        *)        Die "${EXIT_USAGE}" "사용법: apply.sh postgres|oracle [--dry-run]" ;;
    esac

    [ "${2:-}" = "--dry-run" ] && extra+=(--dry-run)
    [ -n "${g_HistoryArg}" ] && extra+=("${g_HistoryArg}")
    bash "${SQL_DIR}/apply-schema.sh" --dialect "${dialect}" --dir "${SQL_DIR}" ${extra[@]+"${extra[@]}"}
}

Main "$@"
