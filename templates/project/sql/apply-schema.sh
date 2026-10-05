#!/usr/bin/env bash
################################################################################
# FILE NAME   : apply-schema.sh
# DESCRIPTION : 도구 없이 관리하는 .sql 스키마 파일을 버전 순서대로 적용한다.
#               <sql 루트>/<방언>/ 아래 V<번호>__<설명>.sql 을 번호 순으로 나열하고,
#               적용 이력과 비교해 미적용 버전만 SQL_CLIENT 로 실행한다.
#               R__<설명>.sql 은 체크섬이 바뀌었을 때만 버전 파일 뒤에 다시 적용한다.
#               첫 실패에서 멈추고, --dry-run 은 실행 계획만 출력한다.
#               접속 정보(SQL_CLIENT·SQL_APPLIED_CMD 내용)는 출력하지 않는다.
#               규약 정본: skills/sql-schema-versioning/SKILL.md
################################################################################
# 사용법:
#   apply-schema.sh --dialect oracle|postgres [--dir <sql 루트>]
#                   (--applied-from <파일> | --empty-db) [--dry-run]
#   적용 이력 출처(셋 중 하나):
#     --applied-from <파일>  한 줄에 하나: "<버전> [체크섬]" 또는 "R__<설명> [체크섬]"
#     SQL_APPLIED_CMD        같은 형식을 출력하는 명령 (SCHEMA_HISTORY 조회)
#     --empty-db             이력이 없는 빈 DB (모든 버전이 미적용)
#   실제 적용: SQL_CLIENT 에 표준입력으로 SQL 을 받는 명령을 지정한다.
#     예) SQL_CLIENT='sqlplus -s /@APP_DB'   SQL_CLIENT='psql -X -q service=app'
#   종료 코드: 0 성공 · 1 사용법 · 2 파일명 오류·버전 중복 · 3 이력 불일치 · 4 적용 실패
################################################################################

set -euo pipefail

readonly EXIT_USAGE=1
readonly EXIT_BAD_FILE=2
readonly EXIT_HISTORY=3
readonly EXIT_APPLY=4
readonly VERSIONED_RE='^V[0-9]+__[A-Za-z0-9][A-Za-z0-9_]*\.sql$'
readonly REPEATABLE_RE='^R__[A-Za-z0-9][A-Za-z0-9_]*\.sql$'

SQL_ROOT="$(cd "$(dirname "$0")" && pwd)"
DIALECT=""
DRY_RUN=0
EMPTY_DB=0
APPLIED_FROM=""
WORK_DIR=""

#===============================================================================
# FUNCTION    : Die
# DESCRIPTION : 오류 메시지를 stderr 로 출력하고 지정 코드로 종료한다.
# PARAMETERS  : int    code    - 종료 코드
#               string message - 출력할 메시지
#===============================================================================
Die() {
    echo "[apply-schema] ERROR: $2" >&2
    exit "$1"
}

Usage() {
    sed -n '/^# 사용법:/,/^######/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'
}

#===============================================================================
# FUNCTION    : ParseArgs
# DESCRIPTION : 명령행 인자를 해석해 전역 설정에 반영한다.
# PARAMETERS  : string args... - 스크립트 인자 전체
#===============================================================================
ParseArgs() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dialect)      [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--dialect 값 필요"; DIALECT="$2"; shift ;;
            --dir)          [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--dir 값 필요"; SQL_ROOT="$2"; shift ;;
            --applied-from) [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--applied-from 값 필요"; APPLIED_FROM="$2"; shift ;;
            --empty-db)     EMPTY_DB=1 ;;
            --dry-run)      DRY_RUN=1 ;;
            -h|--help)      Usage; exit 0 ;;
            *)              Usage >&2; Die "${EXIT_USAGE}" "알 수 없는 인자: $1" ;;
        esac
        shift
    done

    case "${DIALECT}" in
        oracle|postgres) ;;
        *) Die "${EXIT_USAGE}" "--dialect 는 oracle 또는 postgres" ;;
    esac
    [ -d "${SQL_ROOT}/${DIALECT}" ] || Die "${EXIT_USAGE}" "방언 디렉터리 없음: ${SQL_ROOT}/${DIALECT}"
    if [ -n "${APPLIED_FROM}" ] && [ ! -f "${APPLIED_FROM}" ]; then
        Die "${EXIT_USAGE}" "적용 이력 파일 없음: ${APPLIED_FROM}"
    fi
    if [ -z "${APPLIED_FROM}" ] && [ "${EMPTY_DB}" -eq 0 ] && [ -z "${SQL_APPLIED_CMD:-}" ]; then
        Die "${EXIT_USAGE}" "적용 이력 출처 필요: --applied-from, --empty-db, SQL_APPLIED_CMD 중 하나"
    fi
    if [ "${DRY_RUN}" -eq 0 ] && [ -z "${SQL_CLIENT:-}" ]; then
        Die "${EXIT_USAGE}" "실제 적용에는 SQL_CLIENT 가 필요하다 (계획만 보려면 --dry-run)"
    fi
}

#===============================================================================
# FUNCTION    : FileChecksum
# DESCRIPTION : 줄바꿈(CRLF/LF)에 무관한 파일 체크섬(POSIX cksum CRC)을 계산한다.
# PARAMETERS  : string path - 대상 파일
# RETURNED    : stdout 에 체크섬 숫자
#===============================================================================
FileChecksum() {
    tr -d '\r' < "$1" | cksum | awk '{print $1}'
}

#===============================================================================
# FUNCTION    : NormalizeVersion
# DESCRIPTION : 버전 번호의 앞자리 0을 제거한다 (V001 과 V1 은 같은 버전).
# PARAMETERS  : string version - 숫자 문자열
# RETURNED    : stdout 에 정규화된 번호
#===============================================================================
NormalizeVersion() {
    local stripped
    stripped=$(printf '%s' "$1" | sed 's/^0*//')
    printf '%s\n' "${stripped:-0}"
}

#===============================================================================
# FUNCTION    : ScanFiles
# DESCRIPTION : 방언 디렉터리의 .sql 파일명을 검증하고 목록 파일을 만든다.
#               versioned: "<번호>\t<파일명>\t<체크섬>" (번호 오름차순)
#               repeatable: "R__<설명>\t<파일명>\t<체크섬>" (이름 오름차순)
#===============================================================================
ScanFiles() {
    local dir="${SQL_ROOT}/${DIALECT}"
    local path
    local base
    local version
    local bad_count=0
    local dups

    : > "${WORK_DIR}/versioned.raw"
    : > "${WORK_DIR}/repeatable.raw"
    for path in "${dir}"/*.sql; do
        [ -e "${path}" ] || continue
        base=$(basename "${path}")
        if printf '%s\n' "${base}" | grep -Eq "${VERSIONED_RE}"; then
            version=$(printf '%s' "${base}" | sed -E 's/^V([0-9]+)__.*/\1/')
            printf '%s\t%s\t%s\n' "$(NormalizeVersion "${version}")" "${base}" \
                "$(FileChecksum "${path}")" >> "${WORK_DIR}/versioned.raw"
        elif printf '%s\n' "${base}" | grep -Eq "${REPEATABLE_RE}"; then
            printf '%s\t%s\t%s\n' "${base%.sql}" "${base}" \
                "$(FileChecksum "${path}")" >> "${WORK_DIR}/repeatable.raw"
        else
            echo "[apply-schema] 잘못된 파일명: ${DIALECT}/${base} (V<번호>__<설명>.sql 또는 R__<설명>.sql)" >&2
            bad_count=$((bad_count + 1))
        fi
    done
    [ "${bad_count}" -eq 0 ] || Die "${EXIT_BAD_FILE}" "명명 규약 위반 ${bad_count}건"

    dups=$(cut -f1 "${WORK_DIR}/versioned.raw" | sort -n | uniq -d | tr '\n' ' ')
    [ -z "${dups}" ] || Die "${EXIT_BAD_FILE}" "버전 번호 중복: ${dups}"

    sort -t "$(printf '\t')" -k1,1n "${WORK_DIR}/versioned.raw" > "${WORK_DIR}/versioned"
    sort "${WORK_DIR}/repeatable.raw" > "${WORK_DIR}/repeatable"
}

#===============================================================================
# FUNCTION    : LoadApplied
# DESCRIPTION : 적용 이력을 "<키>\t<체크섬>" 형식으로 정리한다.
#               키는 정규화된 버전 번호 또는 R__<설명>. 체크섬이 없으면 빈 값.
#               형식에 맞지 않는 줄(빈 줄·주석·클라이언트 머리말)은 버린다.
#===============================================================================
LoadApplied() {
    local raw="${WORK_DIR}/applied.raw"

    if [ "${EMPTY_DB}" -eq 1 ]; then
        : > "${raw}"
    elif [ -n "${APPLIED_FROM}" ]; then
        tr -d '\r' < "${APPLIED_FROM}" > "${raw}"
    else
        bash -c "${SQL_APPLIED_CMD}" < /dev/null | tr -d '\r' > "${raw}" \
            || Die "${EXIT_HISTORY}" "적용 이력 조회 실패 (SQL_APPLIED_CMD)"
    fi

    awk '
        $1 ~ /^[0-9]+$/ { v = $1; sub(/^0+/, "", v); if (v == "") v = "0"; print v "\t" $2; next }
        $1 ~ /^R__[A-Za-z0-9_]+$/ { print $1 "\t" $2 }
    ' "${raw}" > "${WORK_DIR}/applied"
}

#===============================================================================
# FUNCTION    : AppliedChecksum
# DESCRIPTION : 키의 마지막 적용 기록을 찾는다.
# PARAMETERS  : string key - 버전 번호 또는 R__<설명>
# RETURNED    : 기록이 있으면 0 (stdout 에 체크섬, 없으면 빈 줄), 없으면 1
#===============================================================================
AppliedChecksum() {
    awk -F '\t' -v key="$1" '
        $1 == key { found = 1; sum = $2 }
        END { if (found) { print sum; exit 0 } exit 1 }
    ' "${WORK_DIR}/applied"
}

#===============================================================================
# FUNCTION    : BuildPlan
# DESCRIPTION : 미적용 버전과 변경된 반복 파일로 실행 계획을 만든다.
#               적용된 버전의 체크섬 불일치·순서 역전(최신 적용 버전보다 낮은
#               미적용 버전)은 이력 불일치로 중단한다.
#               plan: "<V|R>\t<키>\t<파일명>\t<체크섬>"
#===============================================================================
BuildPlan() {
    local key
    local base
    local sum
    local recorded
    local max_applied=-1
    local problems=0

    : > "${WORK_DIR}/plan"
    while IFS="$(printf '\t')" read -r key base sum; do
        if recorded=$(AppliedChecksum "${key}"); then
            [ "${key}" -gt "${max_applied}" ] && max_applied="${key}"
            if [ -n "${recorded}" ] && [ "${recorded}" != "${sum}" ]; then
                echo "[apply-schema] 체크섬 불일치: ${base} (기록 ${recorded}, 파일 ${sum}) — 배포된 버전은 수정하지 않는다" >&2
                problems=$((problems + 1))
            fi
        fi
    done < "${WORK_DIR}/versioned"

    while IFS="$(printf '\t')" read -r key base sum; do
        AppliedChecksum "${key}" > /dev/null && continue
        if [ "${key}" -lt "${max_applied}" ]; then
            echo "[apply-schema] 순서 역전: ${base} 는 적용된 V${max_applied} 보다 낮다 — 새 번호로 다시 만든다" >&2
            problems=$((problems + 1))
            continue
        fi
        printf 'V\t%s\t%s\t%s\n' "${key}" "${base}" "${sum}" >> "${WORK_DIR}/plan"
    done < "${WORK_DIR}/versioned"
    [ "${problems}" -eq 0 ] || Die "${EXIT_HISTORY}" "적용 이력과 파일이 맞지 않는다 (${problems}건)"

    while IFS="$(printf '\t')" read -r key base sum; do
        if recorded=$(AppliedChecksum "${key}") && [ "${recorded}" = "${sum}" ]; then
            continue
        fi
        printf 'R\t%s\t%s\t%s\n' "${key}" "${base}" "${sum}" >> "${WORK_DIR}/plan"
    done < "${WORK_DIR}/repeatable"
}

#===============================================================================
# FUNCTION    : PrintPlan
# DESCRIPTION : 실행 계획을 사람이 읽는 형식으로 출력한다.
#===============================================================================
PrintPlan() {
    local kind
    local key
    local base
    local sum
    local count

    count=$(wc -l < "${WORK_DIR}/plan" | tr -d ' ')
    echo "[apply-schema] 방언=${DIALECT} 미적용=${count}건"
    while IFS="$(printf '\t')" read -r kind key base sum; do
        if [ "${kind}" = "V" ]; then
            echo "  PENDING V${key}  ${DIALECT}/${base}  checksum=${sum}"
        else
            echo "  REPEAT  ${key}  ${DIALECT}/${base}  checksum=${sum}"
        fi
    done < "${WORK_DIR}/plan"
}

#===============================================================================
# FUNCTION    : HistoryInsertSql
# DESCRIPTION : 적용 성공 뒤 SCHEMA_HISTORY 에 남길 INSERT 문을 만든다.
#               설명은 파일명에서 오며 [A-Za-z0-9_] 만 허용되므로 따옴표 문제가 없다.
# PARAMETERS  : string kind - V 또는 R
#               string key  - 버전 번호 또는 R__<설명>
#               string base - 파일명
#               string sum  - 체크섬
#===============================================================================
HistoryInsertSql() {
    local kind="$1"
    local key="$2"
    local base="$3"
    local sum="$4"
    local version_sql="NULL"
    local desc
    local who="current_user"

    [ "${kind}" = "V" ] && version_sql="'${key}'"
    desc=$(printf '%s' "${base%.sql}" | sed -e 's/^[VR][0-9]*__//' -e 's/_/ /g')
    [ "${DIALECT}" = "oracle" ] && who="USER"
    printf "INSERT INTO SCHEMA_HISTORY (version, description, script, checksum, applied_by) VALUES (%s, '%s', '%s', %s, %s);\n" \
        "${version_sql}" "${desc}" "${base}" "${sum}" "${who}"
}

#===============================================================================
# FUNCTION    : ApplyOne
# DESCRIPTION : 파일 하나와 이력 기록을 한 입력 스트림으로 SQL_CLIENT 에 보낸다.
#               방언별 머리말이 첫 오류에서 클라이언트를 비정상 종료시키므로
#               실패하면 이력 INSERT 는 실행되지 않는다.
# PARAMETERS  : string kind - V 또는 R
#               string key  - 버전 번호 또는 R__<설명>
#               string base - 파일명
#               string sum  - 체크섬
# RETURNED    : 클라이언트 종료 코드
#===============================================================================
ApplyOne() {
    local path="${SQL_ROOT}/${DIALECT}/$3"

    {
        if [ "${DIALECT}" = "oracle" ]; then
            printf 'WHENEVER SQLERROR EXIT FAILURE ROLLBACK\nWHENEVER OSERROR EXIT FAILURE ROLLBACK\n'
        else
            printf '\\set ON_ERROR_STOP on\n'
        fi
        cat "${path}"
        printf '\n'
        HistoryInsertSql "$1" "$2" "$3" "$4"
        printf 'COMMIT;\n'
        if [ "${DIALECT}" = "oracle" ]; then
            printf 'EXIT\n'
        fi
    } | bash -c "${SQL_CLIENT}"
}

Cleanup() {
    if [ -n "${WORK_DIR}" ]; then
        rm -rf "${WORK_DIR}"
    fi
}

Main() {
    local kind
    local key
    local base
    local sum
    local applied_count=0

    ParseArgs "$@"
    WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/apply-schema.XXXXXX")
    trap Cleanup EXIT

    ScanFiles
    LoadApplied
    BuildPlan
    PrintPlan

    if [ "${DRY_RUN}" -eq 1 ]; then
        echo "[apply-schema] dry-run — 실행하지 않음"
        return 0
    fi

    while IFS="$(printf '\t')" read -r kind key base sum; do
        echo "[apply-schema] 적용: ${DIALECT}/${base}"
        if ! ApplyOne "${kind}" "${key}" "${base}" "${sum}" < /dev/null; then
            Die "${EXIT_APPLY}" "적용 실패: ${DIALECT}/${base} — 이후 버전은 실행하지 않았다 (적용 ${applied_count}건). 원인을 고친 새 버전으로 전진 수정한다"
        fi
        applied_count=$((applied_count + 1))
    done < "${WORK_DIR}/plan"
    echo "[apply-schema] 완료: ${applied_count}건 적용"
}

Main "$@"
