#!/usr/bin/env bash
################################################################################
# FILE NAME   : logtrace.sh
# DESCRIPTION : 거래/요청 ID 하나의 로그 줄을 여러 파일·디렉터리에서 모아 시각순으로 출력한다.
#               key=value 한 줄 형식(ts=… lvl=… txn=…)을 전제한다.
#               표준 출력에는 일치한 원본 줄만 낸다. 진단은 표준 에러에 경로만 적는다.
#               규약 정본: skills/operational-logging/SKILL.md
################################################################################
# 사용법:
#   logtrace.sh [-l 레벨] <거래ID> <파일|디렉터리>...
#     -l 레벨   이 레벨 이상만 출력 (TRACE·DEBUG·INFO·WARN·ERROR·FATAL)
#   디렉터리는 하위의 *.log·*.log.*·*.log-*(dateext) 파일을 모두 읽는다. *.gz 는 풀어서 읽는다.
#   시각 정렬은 ts= 값의 문자열 순서다. 모든 서버가 같은 시각 정책(같은 시간대 또는 UTC)을 써야 한다.
#   종료 코드: 0 일치 있음 · 1 일치 없음 · 2 사용법 오류
################################################################################

set -euo pipefail

readonly EXIT_FOUND=0
readonly EXIT_NOT_FOUND=1
readonly EXIT_USAGE=2
readonly TXN_ID_RE='^[A-Za-z0-9._:-]+$'
readonly LEVEL_RE='^(TRACE|DEBUG|INFO|WARN|ERROR|FATAL)$'

#===============================================================================
# FUNCTION    : Usage
# DESCRIPTION : 사용법을 표준 에러로 출력하고 사용법 오류로 끝낸다.
#===============================================================================
Usage() {
    echo "사용법: logtrace.sh [-l 레벨] <거래ID> <파일|디렉터리>..." >&2
    exit "${EXIT_USAGE}"
}

#===============================================================================
# FUNCTION    : EmitFile
# DESCRIPTION : 파일 하나의 내용을 표준 출력으로 낸다. *.gz 는 풀어서 낸다.
# PARAMETERS  : string path - 로그 파일 경로
#===============================================================================
EmitFile() {
    local path="$1"

    case "${path}" in
        *.gz) gzip -dc -- "${path}" 2>/dev/null || true ;;
        *)    cat -- "${path}" 2>/dev/null || true ;;
    esac
}

#===============================================================================
# FUNCTION    : EmitPaths
# DESCRIPTION : 인자로 받은 파일·디렉터리의 로그 내용을 모두 이어서 낸다.
#               없는 경로는 표준 에러에 경로만 알리고 건너뛴다.
# PARAMETERS  : string... paths - 파일 또는 디렉터리
#===============================================================================
EmitPaths() {
    local path
    local file

    for path in "$@"; do
        if [ -d "${path}" ]; then
            while IFS= read -r -d '' file; do
                EmitFile "${file}"
            done < <(find "${path}" -type f \( -name '*.log' -o -name '*.log.*' -o -name '*.log-*' \) -print0)
        elif [ -f "${path}" ]; then
            EmitFile "${path}"
        else
            echo "[logtrace] 경로 없음: ${path}" >&2
        fi
    done
}

#===============================================================================
# FUNCTION    : FilterLines
# DESCRIPTION : txn= 필드가 정확히 일치하고 레벨이 기준 이상인 줄만 "ts<TAB>원본 줄"로 낸다.
# PARAMETERS  : string txn_id    - 거래 ID
#               string min_level - 최소 레벨 (빈 값이면 모두)
#===============================================================================
FilterLines() {
    local txn_id="$1"
    local min_level="$2"

    LC_ALL=C awk -v want="txn=${txn_id}" -v min="${min_level}" '
        BEGIN {
            rank["TRACE"] = 0; rank["DEBUG"] = 1; rank["INFO"] = 2
            rank["WARN"] = 3; rank["ERROR"] = 4; rank["FATAL"] = 5
        }
        {
            ts = ""; lvl = ""; hit = 0
            nf = split($0, field, " ")
            for (ii = 1; ii <= nf; ii++) {
                if (field[ii] == want) { hit = 1 }
                else if (substr(field[ii], 1, 3) == "ts=") { ts = substr(field[ii], 4) }
                else if (substr(field[ii], 1, 4) == "lvl=") { lvl = substr(field[ii], 5) }
                if (substr(field[ii], 1, 4) == "msg=") { break }   # 메시지 안의 txn= 는 보지 않는다
            }
            if (!hit) { next }
            if (min != "" && (!(lvl in rank) || rank[lvl] < rank[min])) { next }
            print ts "\t" $0
        }'
}

#-------------------------------------------------------------------------------
# 인자 처리
#-------------------------------------------------------------------------------
min_level=""
while getopts ":l:h" opt; do
    case "${opt}" in
        l) min_level=$(printf '%s' "${OPTARG}" | tr '[:lower:]' '[:upper:]') ;;
        *) Usage ;;
    esac
done
shift $((OPTIND - 1))

[ "$#" -ge 2 ] || Usage
txn_id="$1"
shift
[[ "${txn_id}" =~ ${TXN_ID_RE} ]] || { echo "[logtrace] 거래 ID는 영문·숫자·._:- 만 허용" >&2; exit "${EXIT_USAGE}"; }
if [ -n "${min_level}" ] && ! [[ "${min_level}" =~ ${LEVEL_RE} ]]; then
    echo "[logtrace] 알 수 없는 레벨" >&2
    exit "${EXIT_USAGE}"
fi

#-------------------------------------------------------------------------------
# 수집 → 거르기 → 시각순 정렬(같은 시각은 입력 순서 유지) → 원본 줄만 출력
#-------------------------------------------------------------------------------
result=$(EmitPaths "$@" | FilterLines "${txn_id}" "${min_level}" | LC_ALL=C sort -s -t "$(printf '\t')" -k1,1 | cut -f2-)

if [ -z "${result}" ]; then
    exit "${EXIT_NOT_FOUND}"
fi
printf '%s\n' "${result}"
exit "${EXIT_FOUND}"
