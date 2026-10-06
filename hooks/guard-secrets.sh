#!/bin/bash
################################################################################
# FILE NAME   : guard-secrets.sh
# DESCRIPTION : PreToolUse(Bash) 가드. git commit 직전에 커밋될 변경을 검사해
#               비밀값과 개인정보가 저장소에 들어가는 것을 막는다.
#                 - 비밀값(액세스 키, API 키, 개인키, 비밀번호 리터럴,
#                   DB 접속 문자열)                              → deny
#                 - 주민등록번호(검증 자리 일치), 카드번호(Luhn 일치) → deny
#                 - 연락처·이메일이 한 파일에 많음, 데이터 파일 → ask
#               테스트 픽스처 경로와 ARACHNE-SYNTHETIC-DATA 표식이 있는 파일은
#               합성 데이터로 보고 개인정보 검사를 건너뛴다.
#               보고에는 파일:줄만 남기고 값 자체는 출력하지 않는다.
################################################################################

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/lib-guard.sh
. "${HOOK_DIR}/lib-guard.sh"

# lib-guard.sh 함수가 채우는 결과 변수 (shellcheck 가 source 를 따라가지 않으므로 여기서 초기화)
g_Tokens=()
g_CommitAll=0

readonly MAX_REPORT=5
readonly PHONE_ASK_MIN=3
readonly EMAIL_ASK_MIN=5
readonly SQL_INSERT_ASK_MIN=50

#-------------------------------------------------------------------------------
# 비밀값 패턴 (ERE). 값이 변수·플레이스홀더면 걸리지 않게 리터럴만 본다
#-------------------------------------------------------------------------------
readonly -a SECRET_PATTERNS=(
    '(^|[^A-Za-z0-9])(AKIA|ASIA)[0-9A-Z]{16}'
    '(^|[^A-Za-z0-9_-])sk-(ant-)?[A-Za-z0-9_-]{20,}'
    '(^|[^A-Za-z0-9])gh[pousr]_[A-Za-z0-9]{36}'
    'github_pat_[A-Za-z0-9_]{22,}'
    'xox[abprs]-[A-Za-z0-9-]{10,}'
    '-----BEGIN ([A-Z]+ )?PRIVATE KEY-----'
    '(password|passwd|pwd|secret|api_?key)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'$[:space:]{<]{6,}["'"'"']'
    'postgres(ql)?://[^:/[:space:]]+:[^@/[:space:]$]+@'
    '(sqlplus|CONNECT)[[:space:]]+[A-Za-z0-9_]+/[^@[:space:]:$]+@'
    'IDENTIFIED[[:space:]]+BY[[:space:]]+["'"'"']?[A-Za-z0-9!#%^&*_+-]{4,}'
)

g_DenyReasons=""
g_AskReasons=""
AddDeny() { g_DenyReasons="${g_DenyReasons}${g_DenyReasons:+ / }$1"; }
AddAsk()  { g_AskReasons="${g_AskReasons}${g_AskReasons:+ / }$1"; }

#===============================================================================
# FUNCTION    : IsSyntheticFile
# DESCRIPTION : 테스트 픽스처 경로이거나 합성 데이터 표식이 있는 파일인지 판정한다.
# PARAMETERS  : string path - 저장소 기준 파일 경로
# RETURNED    : 0(합성 데이터로 취급) / 1(아님)
#===============================================================================
IsSyntheticFile() {
    local path="$1"
    case "${path}" in
        */fixtures/*|fixtures/*|*/testdata/*|testdata/*) return 0 ;;
    esac
    git show ":${path}" 2>/dev/null | head -20 | grep -q 'ARACHNE-SYNTHETIC-DATA'
}

#===============================================================================
# FUNCTION    : FindValidIds
# DESCRIPTION : 추가된 줄에서 검증 자리가 맞는 주민등록번호와 Luhn 이 맞는
#               카드번호를 찾아 줄 번호를 출력한다(값은 출력하지 않음).
# PARAMETERS  : stdin - "줄번호<TAB>내용" 형식의 추가된 줄
# RETURNED    : "rrn:줄번호" 또는 "card:줄번호" 를 stdout 으로
#===============================================================================
FindValidIds() {
    awk -F '\t' '
    function rrn_ok(s,   w, sum, i, chk) {
        split("2 3 4 5 6 7 8 9 2 3 4 5", w, " ")
        sum = 0
        for (i = 1; i <= 12; i++) sum += substr(s, i, 1) * w[i]
        chk = (11 - (sum % 11)) % 10
        return chk == substr(s, 13, 1) + 0
    }
    function luhn_ok(s,   n, i, d, sum, alt) {
        n = length(s); sum = 0; alt = 0
        for (i = n; i >= 1; i--) {
            d = substr(s, i, 1) + 0
            if (alt) { d *= 2; if (d > 9) d -= 9 }
            sum += d; alt = !alt
        }
        return (sum % 10) == 0
    }
    {
        line = $2
        rest = line
        while (match(rest, /[0-9]{6}-?[1-4][0-9]{6}/)) {
            cand = substr(rest, RSTART, RLENGTH); gsub(/-/, "", cand)
            pre = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : ""
            post = substr(rest, RSTART + RLENGTH, 1)
            if (pre !~ /[0-9]/ && post !~ /[0-9]/ && rrn_ok(cand)) { print "rrn:" $1; break }
            rest = substr(rest, RSTART + RLENGTH)
        }
        rest = line
        while (match(rest, /[3-6][0-9]{3}([ -]?[0-9]{4}){2}[ -]?[0-9]{1,7}/)) {
            cand = substr(rest, RSTART, RLENGTH); gsub(/[ -]/, "", cand)
            pre = (RSTART > 1) ? substr(rest, RSTART - 1, 1) : ""
            post = substr(rest, RSTART + RLENGTH, 1)
            if (length(cand) >= 13 && length(cand) <= 19 && pre !~ /[0-9]/ && post !~ /[0-9]/ && luhn_ok(cand)) {
                print "card:" $1; break
            }
            rest = substr(rest, RSTART + RLENGTH)
        }
    }'
}

#===============================================================================
# FUNCTION    : AddedLines
# DESCRIPTION : 스테이징된 파일 하나의 추가된 줄을 "새 줄번호<TAB>내용"으로 출력한다.
# PARAMETERS  : string path - 파일 경로
#===============================================================================
AddedLines() {
    git diff --cached --unified=0 --no-color -- "$1" 2>/dev/null | awk '
        /^@@/ { split($3, a, ","); ln = substr(a[1], 2) + 0; next }
        /^\+\+\+/ { next }
        /^\+/ { print ln "\t" substr($0, 2); ln++; next }
    '
}

#===============================================================================
# FUNCTION    : ScanFile
# DESCRIPTION : 스테이징된 파일 하나를 검사해 사유를 누적한다.
# PARAMETERS  : string path - 저장소 기준 파일 경로
#===============================================================================
ScanFile() {
    local path="$1"
    local added
    added=$(AddedLines "${path}")

    #---------------------------------------------------------------------------
    # 데이터 파일은 내용과 무관하게 확인을 받는다(픽스처 경로 제외)
    #---------------------------------------------------------------------------
    if ! IsSyntheticFile "${path}"; then
        case "${path}" in
            *.csv|*.tsv|*.xlsx|*.xls|*.parquet|*.dmp|*.dump|*.bak)
                AddAsk "데이터 파일 커밋: ${path} (고객 데이터가 아닌지 확인)" ;;
        esac
    fi
    [ -z "${added}" ] && return 0

    #---------------------------------------------------------------------------
    # 비밀값 — 허용 표식(ARACHNE-ALLOW-SECRET)이 있는 줄은 건너뛴다
    #---------------------------------------------------------------------------
    local candidates
    candidates=$(printf '%s\n' "${added}" | grep -v 'ARACHNE-ALLOW-SECRET')
    local pattern
    for pattern in "${SECRET_PATTERNS[@]}"; do
        local hits
        hits=$(printf '%s\n' "${candidates}" | grep -iE -- "${pattern}" | cut -f1 | head -"${MAX_REPORT}" | tr '\n' ',' | sed 's/,$//')
        if [ -n "${hits}" ]; then
            AddDeny "비밀값으로 보이는 문자열: ${path}:${hits}"
            break
        fi
    done

    IsSyntheticFile "${path}" && return 0

    #---------------------------------------------------------------------------
    # 개인정보 — 검증식이 맞는 번호만 차단, 연락처·이메일은 양이 많을 때 확인
    #---------------------------------------------------------------------------
    local ids
    ids=$(printf '%s\n' "${candidates}" | FindValidIds | head -"${MAX_REPORT}")
    if [ -n "${ids}" ]; then
        local rrn_lines card_lines
        rrn_lines=$(printf '%s\n' "${ids}" | grep '^rrn:' | cut -d: -f2 | tr '\n' ',' | sed 's/,$//')
        card_lines=$(printf '%s\n' "${ids}" | grep '^card:' | cut -d: -f2 | tr '\n' ',' | sed 's/,$//')
        [ -n "${rrn_lines}" ] && AddDeny "주민등록번호(검증 자리 일치): ${path}:${rrn_lines}"
        [ -n "${card_lines}" ] && AddDeny "카드번호(Luhn 일치): ${path}:${card_lines}"
    fi

    local phones emails inserts
    phones=$(printf '%s\n' "${candidates}" | grep -cE '01[016789][ -]?[0-9]{3,4}[ -]?[0-9]{4}')
    emails=$(printf '%s\n' "${candidates}" | grep -cE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
    [ "${phones}" -ge "${PHONE_ASK_MIN}" ] && AddAsk "연락처가 ${phones}건 포함된 파일: ${path}"
    [ "${emails}" -ge "${EMAIL_ASK_MIN}" ] && AddAsk "이메일이 ${emails}건 포함된 파일: ${path}"
    case "${path}" in
        *.sql)
            inserts=$(printf '%s\n' "${candidates}" | grep -ciE '^[0-9]+	[[:space:]]*insert[[:space:]]+into')
            [ "${inserts}" -ge "${SQL_INSERT_ASK_MIN}" ] \
                && AddAsk "INSERT 문이 ${inserts}건인 SQL 파일(데이터 덤프인지 확인): ${path}"
            ;;
    esac
}

#-------------------------------------------------------------------------------
# 입력 읽기 — git commit 이 아니면 관여하지 않는다
#-------------------------------------------------------------------------------
payload=$(cat 2>/dev/null || true)
[ -z "${payload}" ] && exit 0
tool_name=$(GuardJsonString "${payload}" "tool_name")
[ -n "${tool_name}" ] && [ "${tool_name}" != "Bash" ] && exit 0
command_text=$(GuardJsonString "${payload}" "command")
[ -z "${command_text}" ] && exit 0

#===============================================================================
# FUNCTION    : ResolveDir
# DESCRIPTION : 경로를 현재 추적 중인 디렉터리 기준 절대 경로로 바꾼다(~ 펼침 포함).
# PARAMETERS  : string base   - 기준 디렉터리
#               string target - cd·git -C 인자
# RETURNED    : 절대 경로를 stdout 으로
#===============================================================================
ResolveDir() {
    local base="$1"
    local target="$2"
    # 글자 그대로의 ~ 를 비교한다(셸 펼침 전 문자열)
    # shellcheck disable=SC2088
    case "${target}" in
        "~")   printf '%s' "${HOME}" ;;
        "~/"*) printf '%s/%s' "${HOME}" "${target#\~/}" ;;
        /*)    printf '%s' "${target}" ;;
        *)     printf '%s/%s' "${base}" "${target}" ;;
    esac
}

#===============================================================================
# FUNCTION    : ScanSegment
# DESCRIPTION : 명령의 한 부분을 본다. cd·pushd 면 추적 디렉터리를 옮기고,
#               git commit 이면 옵션을 해석해 커밋이 일어날 디렉터리를 기록한다.
#               (git -C <경로> 가 있으면 그 경로를 쓴다)
# PARAMETERS  : string... words - 부분을 이루는 단어들(따옴표 해석 완료)
#===============================================================================
ScanSegment() {
    local -a words=("$@")
    local ii=0
    while [ "${ii}" -lt "${#words[@]}" ]; do
        case "${words[${ii}]}" in
            *=*|sudo|env|command|exec|time|nice|nohup) ii=$((ii + 1)) ;;
            *) break ;;
        esac
    done
    [ "${ii}" -ge "${#words[@]}" ] && return 0

    case "${words[${ii}]##*/}" in
        cd|pushd)
            g_CurDir=$(ResolveDir "${g_CurDir}" "${words[$((ii + 1))]:-~}")
            return 0 ;;
        git) ;;
        *) return 0 ;;
    esac

    local -a git_args=("${words[@]:$((ii + 1))}")
    local sub_idx
    local commit_dir="${g_CurDir}"
    local jj
    sub_idx=$(GuardGitSubcommand "${git_args[@]+"${git_args[@]}"}")
    [ "${sub_idx}" -ge 0 ] || return 0
    [ "${git_args[${sub_idx}]}" = "commit" ] || return 0

    for ((jj = 0; jj < sub_idx; jj++)); do
        if [ "${git_args[${jj}]}" = "-C" ] && [ $((jj + 1)) -lt "${sub_idx}" ]; then
            commit_dir=$(ResolveDir "${commit_dir}" "${git_args[$((jj + 1))]}")
        fi
    done

    g_IsCommit=1
    g_CommitDir="${commit_dir}"
    GuardParseCommitArgs "${git_args[@]:$((sub_idx + 1))}"
    [ "${g_CommitAll}" -eq 1 ] && g_IsCommitAll=1
    return 0
}

#-------------------------------------------------------------------------------
# git commit 이 아니면 관여하지 않는다 (따옴표 해석 후 단어 단위로 판정).
# 명령 안의 cd 를 따라가며 커밋이 일어날 저장소를 정한다.
#-------------------------------------------------------------------------------
g_IsCommit=0
g_IsCommitAll=0
g_CurDir=$(GuardJsonString "${payload}" "cwd")
[ -n "${g_CurDir}" ] || g_CurDir="${PWD}"
g_CommitDir="${g_CurDir}"
GuardTokenize "${command_text}"
segment_words=()
for token in "${g_Tokens[@]+"${g_Tokens[@]}"}"; do
    if [ "${token}" = "${GUARD_SEGMENT_MARK}" ]; then
        ScanSegment "${segment_words[@]+"${segment_words[@]}"}"
        segment_words=()
    else
        segment_words+=("${token}")
    fi
done
ScanSegment "${segment_words[@]+"${segment_words[@]}"}"
[ "${g_IsCommit}" -eq 1 ] || exit 0

cd "${g_CommitDir}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

#-------------------------------------------------------------------------------
# commit -a 는 추적 중인 수정 파일도 함께 커밋하므로, 임시 인덱스에 담아 검사한다
# (GIT_INDEX_FILE 은 이 프로세스에만 적용 — 실제 인덱스는 건드리지 않는다)
#-------------------------------------------------------------------------------
if [ "${g_IsCommitAll}" -eq 1 ]; then
    tmp_index=$(mktemp)
    trap 'rm -f "${tmp_index}"' EXIT
    cp "$(git rev-parse --git-path index)" "${tmp_index}" 2>/dev/null
    export GIT_INDEX_FILE="${tmp_index}"
    git add -u >/dev/null 2>&1
fi

while IFS= read -r staged_path; do
    [ -n "${staged_path}" ] && ScanFile "${staged_path}"
done < <(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null)

if [ -n "${g_DenyReasons}" ]; then
    GuardDecide "deny" "[Arachne 가드] 커밋 중단 — ${g_DenyReasons}. 값을 환경변수·키체인으로 옮기거나 합성 데이터로 바꾸세요(테스트용이면 줄에 ARACHNE-ALLOW-SECRET, 파일에 ARACHNE-SYNTHETIC-DATA 표식)"
elif [ -n "${g_AskReasons}" ]; then
    GuardDecide "ask" "[Arachne 가드] ${g_AskReasons}"
fi
exit 0
