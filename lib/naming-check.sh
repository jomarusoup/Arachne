#!/usr/bin/env bash
################################################################################
# FILE NAME   : naming-check.sh
# DESCRIPTION : 프로젝트 네이밍 사전(.arachne/naming-dict.tsv)으로 식별자를 검사해
#               보고한다. C·C++·Pro*C·ecpg·Rust·TypeScript 소스에서 선언된 식별자를
#               뽑고(universal-ctags 우선, 없으면 정규식), 표기법대로 단어로 나눈 뒤
#               사전과 대조한다. 보고 항목은 미등록 약어·금지 동의어·동의어 혼용·
#               30자 초과다. 기본은 보고만 하고 0으로 끝난다(--strict 일 때만 실패).
#               규약 정본: skills/naming-dictionary/SKILL.md
################################################################################
# 사용법:
#   naming-check.sh [--changed | --all] [--dict <파일>] [--base <ref>] [--strict] [경로...]
#     --changed     git diff 로 추가·변경된 줄의 식별자만 검사 (기본)
#                   비교 기준은 --base (기본 HEAD), 추적되지 않은 새 파일은 전체를 본다
#     --all         추적 중인 소스 전체 검사 (경로를 주면 그 경로만)
#     --dict        사전 경로 (기본 .arachne/naming-dict.tsv)
#     --strict      경고가 하나라도 있으면 종료 코드 1
#   환경변수: NAMING_CHECK_NO_CTAGS=1 이면 ctags 를 쓰지 않고 정규식만 쓴다
#   종료 코드: 0 보고 완료 · 1 --strict 경고 · 2 사용법·사전 오류
################################################################################

set -euo pipefail

readonly EXIT_STRICT=1
readonly EXIT_USAGE=2
readonly MAX_NAME_LEN=30
readonly SOURCE_EXT_RE='\.(c|h|cc|cpp|cxx|hpp|hh|pc|pgc|rs|ts|tsx)$'

MODE="changed"
DICT_PATH=".arachne/naming-dict.tsv"
DICT_GIVEN=0
BASE_REF="HEAD"
STRICT=0
WORK_DIR=""
PATH_ARGS_FILE=""

#===============================================================================
# FUNCTION    : Die
# DESCRIPTION : 오류 메시지를 stderr 로 출력하고 지정 코드로 종료한다.
# PARAMETERS  : int    code    - 종료 코드
#               string message - 출력할 메시지
#===============================================================================
Die() {
    echo "[naming] ERROR: $2" >&2
    exit "$1"
}

Usage() {
    sed -n '/^# 사용법:/,/^######/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'
}

Cleanup() {
    if [ -n "${WORK_DIR}" ]; then
        rm -rf "${WORK_DIR}"
    fi
}

#===============================================================================
# FUNCTION    : ParseArgs
# DESCRIPTION : 명령행 인자를 해석한다. 경로 인자는 작업 파일에 모은다.
# PARAMETERS  : string args... - 스크립트 인자 전체
#===============================================================================
ParseArgs() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --changed) MODE="changed" ;;
            --all)     MODE="all" ;;
            --strict)  STRICT=1 ;;
            --dict)    [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--dict 값 필요"; DICT_PATH="$2"; DICT_GIVEN=1; shift ;;
            --base)    [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--base 값 필요"; BASE_REF="$2"; shift ;;
            -h|--help) Usage; exit 0 ;;
            -*)        Usage >&2; Die "${EXIT_USAGE}" "알 수 없는 옵션: $1" ;;
            *)         printf '%s\n' "$1" >> "${PATH_ARGS_FILE}" ;;
        esac
        shift
    done
}

#===============================================================================
# FUNCTION    : ListTargets
# DESCRIPTION : 검사 대상 소스 파일 목록과 (changed 모드) 추가된 줄 목록을 만든다.
#               targets: 파일 경로 한 줄씩
#               added  : "<파일>\t<줄>" (changed 모드에서만 사용)
#===============================================================================
ListTargets() {
    local raw="${WORK_DIR}/targets.raw"

    : > "${raw}"
    : > "${WORK_DIR}/added"
    if [ "${MODE}" = "all" ]; then
        if [ -s "${PATH_ARGS_FILE}" ]; then
            while IFS= read -r path; do
                if [ -d "${path}" ]; then
                    find "${path}" -type f >> "${raw}"
                else
                    printf '%s\n' "${path}" >> "${raw}"
                fi
            done < "${PATH_ARGS_FILE}"
        elif git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
            git ls-files >> "${raw}"
        else
            find . -type f >> "${raw}"
        fi
    else
        git rev-parse --is-inside-work-tree > /dev/null 2>&1 \
            || Die "${EXIT_USAGE}" "--changed 는 git 저장소 안에서만 동작한다 (--all 사용)"
        # 추가된 줄: diff 헤더에서 파일, @@ 헤더에서 새 줄 번호를 추적한다
        { git diff -U0 --no-color --no-ext-diff --relative "${BASE_REF}" -- 2> /dev/null || true; } | awk '
            /^\+\+\+ / { file = substr($0, 5); sub(/^b\//, "", file); next }
            /^@@ / {
                split($3, part, ",")
                line = substr(part[1], 2) + 0
                next
            }
            /^\+/ { if (file != "/dev/null") print file "\t" line; line++; next }
        ' > "${WORK_DIR}/added"
        git ls-files --others --exclude-standard > "${WORK_DIR}/untracked"
        while IFS= read -r path; do
            [ -f "${path}" ] || continue
            awk -v f="${path}" '{ print f "\t" NR }' "${path}" >> "${WORK_DIR}/added"
        done < "${WORK_DIR}/untracked"
        cut -f1 "${WORK_DIR}/added" | sort -u >> "${raw}"
    fi

    grep -E "${SOURCE_EXT_RE}" "${raw}" | sed 's|^\./||' | sort -u > "${WORK_DIR}/targets" || true
}

#===============================================================================
# FUNCTION    : ExtractWithCtags
# DESCRIPTION : universal-ctags 로 선언 식별자를 뽑는다. Pro*C·ecpg 는 C 로 본다.
# RETURNED    : stdout 에 "<파일>\t<줄>\t<식별자>"
#===============================================================================
ExtractWithCtags() {
    local path

    # 파일 목록을 한 번에 넘겨 ctags 를 한 번만 실행한다(큰 저장소에서 프로세스 기동 비용 절감)
    ctags -x --_xformat=$'%F\t%n\t%N' --langmap=C:+.pc.pgc \
        --kinds-C=+lpz --kinds-C++=+lpz -L "${WORK_DIR}/targets" -o - 2> /dev/null || true
}

#===============================================================================
# FUNCTION    : ExtractWithRegex
# DESCRIPTION : ctags 가 없을 때 정규식으로 선언 식별자를 뽑는다.
#               "타입 이름 [=;,()[{:<]" 꼴과 #define, fn·let·const·class 등을 잡는다.
#               주석·문자열·EXEC SQL 문은 건너뛴다.
# RETURNED    : stdout 에 "<파일>\t<줄>\t<식별자>"
#===============================================================================
ExtractWithRegex() {
    # 파일 목록 전체를 awk 한 번에 넘긴다(파일마다 프로세스를 띄우지 않음)
    tr '\n' '\000' < "${WORK_DIR}/targets" | xargs -0 awk '
            BEGIN {
                n = split("return else case goto sizeof new delete throw typeof instanceof " \
                          "await yield use mod impl for in as if while switch do not and or " \
                          "import export from package namespace using template typename default", w, " ")
                for (i = 1; i <= n; i++) stop_first[w[i]] = 1
                n = split("int char short long float double void unsigned signed const " \
                          "volatile static extern struct union enum bool auto register " \
                          "inline restrict mut pub self Self true false null NULL " \
                          "string number boolean any unknown never undefined", w, " ")
                for (i = 1; i <= n; i++) stop_second[w[i]] = 1
            }
            FNR == 1 { f = FILENAME; in_comment = 0; in_sql = 0 }
            {
                s = $0
                sub(/\r$/, "", s)
                # 블록 주석 상태
                if (in_comment) {
                    if (index(s, "*/") == 0) next
                    s = substr(s, index(s, "*/") + 2); in_comment = 0
                }
                gsub(/\/\*([^*]|\*+[^*\/])*\*+\//, " ", s)
                if (index(s, "/*") > 0) { s = substr(s, 1, index(s, "/*") - 1); in_comment = 1 }
                sub(/\/\/.*$/, "", s)
                # EXEC SQL 문은 세미콜론까지 건너뛴다
                if (in_sql) { if (index(s, ";") > 0) in_sql = 0; next }
                if (s ~ /EXEC[ \t]+SQL/) {
                    if (s ~ /DECLARE[ \t]+SECTION/) next
                    if (index(s, ";") == 0) in_sql = 1
                    next
                }
                gsub(/"([^"\\]|\\.)*"/, "\"\"", s)
                gsub(/\047([^\047\\]|\\.)*\047/, "\047\047", s)
                gsub(/`[^`]*`/, "``", s)

                if (match(s, /^[ \t]*#[ \t]*define[ \t]+[A-Za-z_][A-Za-z0-9_]*/)) {
                    d = substr(s, RSTART, RLENGTH); sub(/^[ \t]*#[ \t]*define[ \t]+/, "", d)
                    print f "\t" FNR "\t" d
                    next
                }
                while (match(s, /[A-Za-z_][A-Za-z0-9_]*[ \t*&]+[A-Za-z_][A-Za-z0-9_]*[ \t]*[=;,(){:<[]/)) {
                    m = substr(s, RSTART, RLENGTH)
                    match(m, /^[A-Za-z_][A-Za-z0-9_]*/); first = substr(m, 1, RLENGTH)
                    rest = substr(m, RLENGTH + 1)
                    match(rest, /[A-Za-z_][A-Za-z0-9_]*/); second = substr(rest, RSTART, RLENGTH)
                    if (!(first in stop_first) && !(second in stop_second) && !(second in stop_first))
                        print f "\t" FNR "\t" second
                    # 첫 식별자만 건너뛰고 이어서 찾는다 (매개변수 목록 처리)
                    s = substr(s, index(s, m) + length(first))
                }
            }
        ' 2> /dev/null || true
}

#===============================================================================
# FUNCTION    : ExtractIdentifiers
# DESCRIPTION : 식별자를 뽑고, changed 모드면 추가된 줄의 것만 남긴다.
#               SQL 키워드(ctags 가 EXEC SQL 안에서 잘못 잡는 것)는 버린다.
#===============================================================================
ExtractIdentifiers() {
    if [ "${NAMING_CHECK_NO_CTAGS:-0}" != "1" ] \
        && command -v ctags > /dev/null 2>&1 \
        && ctags --version 2> /dev/null | grep -q "Universal Ctags"; then
        EXTRACTOR="ctags"
        ExtractWithCtags > "${WORK_DIR}/idents.raw"
    else
        EXTRACTOR="regex"
        ExtractWithRegex > "${WORK_DIR}/idents.raw"
    fi

    awk -F '\t' -v mode="${MODE}" -v added="${WORK_DIR}/added" '
        BEGIN {
            n = split("SELECT INTO FROM WHERE INSERT UPDATE DELETE VALUES SET AND OR ORDER BY " \
                      "GROUP HAVING JOIN ON FETCH OPEN CLOSE CURSOR DECLARE COMMIT ROLLBACK EXEC SQL", w, " ")
            for (i = 1; i <= n; i++) sqlkw[w[i]] = 1
            if (mode == "changed")
                while ((getline line < added) > 0) keep[line] = 1
        }
        ($3 in sqlkw) { next }
        mode == "changed" && !(($1 "\t" $2) in keep) { next }
        { print }
    ' "${WORK_DIR}/idents.raw" > "${WORK_DIR}/idents"
}

#===============================================================================
# FUNCTION    : Analyze
# DESCRIPTION : 사전과 대조해 경고를 출력한다.
#               사전 열: 표준 단어 · 허용 약어 · 의미 · 금지 동의어 · 분류
#               (허용 약어·금지 동의어는 쉼표로 여러 개 가능, 대소문자 무시)
# RETURNED    : stdout 에 보고, 마지막 줄 "WARN_COUNT <n>"
#===============================================================================
Analyze() {
    awk -F '\t' -v dict="${DICT_PATH}" -v maxlen="${MAX_NAME_LEN}" '
        function trim(x) { gsub(/^[ \t]+|[ \t]+$/, "", x); return x }
        function add_list(field, kind, std,    n, arr, i, t) {
            n = split(field, arr, ",")
            for (i = 1; i <= n; i++) {
                t = tolower(trim(arr[i]))
                if (t == "") continue
                if (kind == "abbr") abbr_of[t] = std
                else banned_of[t] = std
            }
        }
        function is_upper(ch) { return ch ~ /[A-Z]/ }
        function is_lower(ch) { return ch ~ /[a-z0-9]/ }
        # 식별자를 단어로 나눈다: g_/m_ 접두 제거 → _ 분리 → PascalCase·camelCase 분리
        function split_words(id, words,    s, n, parts, i, p, j, ch, prev, next_ch, cur, cnt) {
            s = id
            sub(/^_+/, "", s)
            sub(/^[gm]_/, "", s)
            n = split(s, parts, "_")
            cnt = 0
            for (i = 1; i <= n; i++) {
                p = parts[i]; cur = ""
                for (j = 1; j <= length(p); j++) {
                    ch = substr(p, j, 1); prev = substr(p, j - 1, 1); next_ch = substr(p, j + 1, 1)
                    if (cur != "" && ((is_upper(ch) && prev ~ /[a-z0-9]/) \
                        || (is_upper(ch) && is_upper(prev) && next_ch ~ /[a-z]/) \
                        || (ch ~ /[0-9]/ && prev ~ /[A-Za-z]/) \
                        || (ch ~ /[A-Za-z]/ && prev ~ /[0-9]/))) {
                        words[++cnt] = cur; cur = ""
                    }
                    cur = cur ch
                }
                if (cur != "") words[++cnt] = cur
            }
            return cnt
        }
        function warn(kind, loc, id, msg) {
            printf "[naming] WARN %-10s %s  %s — %s\n", kind, loc, id, msg
            warn_count++
        }
        BEGIN {
            # 사전 읽기 (첫 열이 "표준 단어"·"#" 로 시작하는 줄은 머리글·주석)
            while ((getline line < dict) > 0) {
                sub(/\r$/, "", line)
                if (line ~ /^[ \t]*$/ || line ~ /^#/ || line ~ /^표준/) continue
                split(line, col, "\t")
                std = tolower(trim(col[1]))
                if (std == "") continue
                std_word[std] = 1
                std_order[++std_total] = std
                abbr_list[std] = trim(col[2])
                add_list(col[2], "abbr", std)
                add_list(col[4], "banned", std)
                dict_count++
            }
            # 일반 영어 단어·널리 쓰는 기술 약어 (최소 목록, 미등록 약어 오탐 방지)
            n = split("a an as at be by do go if in is it of on or to up we no ok id " \
                "add all and any app are arg args ask bad bit bits body bool byte call can " \
                "case cell char check child chunk class clear clock close code copy core " \
                "count create data date day dead del diff dir disk done down drop dump each " \
                "edge empty end entry error event exit fail false fast field file fill find " \
                "first flag flags flush free from front full get go good group handle has " \
                "hash head heap hit hold home host hour image index info input item items " \
                "job join key keys kind last left level limit line link list load local lock " \
                "log long loop low main make map mark match merge mode month move name new " \
                "next node none not null off old one only open order out owner page pair " \
                "parse part path peek pick pool pop port post price print push put query " \
                "queue quit range rate raw read ready reply reset right root round route row " \
                "rows rule run safe save scan seek send set shift side sign size skip sleep " \
                "slot sort source space span split start state stop store sub sum swap sync " \
                "table tag tail take task test text then time timer to token top total trace " \
                "tree true try type unit use user valid value view wait walk week word work " \
                "write year zero with without over under after before old new base kill " \
                "io db ui os ip fd tx rx tcp udp http https url uri sql api cpu gpu ram json " \
                "xml html csv utf ascii tls ssl uuid crc pid tid uid gid eof shm ipc sem mutex " \
                "posix epoll errno ctx min max str src dst cmd fmt ii jj kk " \
                "ret rc obj env fp cb sig fn opt arg argc argv len pos val var buf", eng, " ")
            for (i = 1; i <= n; i++) common[eng[i]] = 1
        }
        {
            id = $3; loc = $1 ":" $2
            if (id in seen) next
            seen[id] = 1

            if (length(id) > maxlen)
                warn("길이초과", loc, id, length(id) "자 > " maxlen "자")

            delete words
            cnt = split_words(id, words)
            for (k = 1; k <= cnt; k++) {
                w = tolower(words[k])
                if (w !~ /^[a-z]+$/ || length(w) < 2) continue
                if (w in banned_of) {
                    s = banned_of[w]
                    warn("금지동의어", loc, id, "\047" words[k] "\047 대신 \047" s "\047" \
                        (abbr_list[s] != "" ? " 또는 \047" abbr_list[s] "\047" : ""))
                    continue
                }
                if (w in std_word) {
                    if (abbr_list[w] != "" && !(w in full_use)) full_use[w] = id " (" loc ")"
                    continue
                }
                if (w in abbr_of) {
                    s = abbr_of[w]
                    if (!(s in abbr_use)) abbr_use[s] = id " (" loc ")"
                    continue
                }
                if (w in common) continue
                # 약어 후보: 3자 이하, 또는 첫 글자 뒤에 모음이 없는 4~5자 (usr·hdr·acct)
                if (length(w) <= 3 || (length(w) <= 5 && substr(w, 2) !~ /[aeiouy]/))
                    warn("미등록약어", loc, id, "\047" words[k] "\047 이 사전에 없다 (등록하거나 표준 단어로 쓴다)")
            }
        }
        END {
            for (i = 1; i <= std_total; i++) {
                s = std_order[i]
                if ((s in full_use) && (s in abbr_use))
                    warn("동의어혼용", "-", s, "전체 단어 " full_use[s] " 와 약어 " abbr_use[s] " 가 함께 쓰인다 (사전 약어 \047" abbr_list[s] "\047 로 통일)")
            }
            print "DICT_COUNT " dict_count + 0
            print "WARN_COUNT " warn_count + 0
        }
    ' "${WORK_DIR}/idents"
}

Main() {
    local report
    local warn_count
    local dict_count
    local ident_count

    WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/naming-check.XXXXXX")
    trap Cleanup EXIT
    PATH_ARGS_FILE="${WORK_DIR}/path-args"
    : > "${PATH_ARGS_FILE}"
    ParseArgs "$@"

    if [ ! -f "${DICT_PATH}" ]; then
        if [ "${DICT_GIVEN}" -eq 1 ]; then
            Die "${EXIT_USAGE}" "사전 파일 없음: ${DICT_PATH}"
        fi
        echo "[naming] 사전 없음 (${DICT_PATH}) — 검사 생략"
        return 0
    fi

    ListTargets
    ExtractIdentifiers
    report=$(Analyze)
    dict_count=$(printf '%s\n' "${report}" | awk '$1 == "DICT_COUNT" { print $2 }')
    warn_count=$(printf '%s\n' "${report}" | awk '$1 == "WARN_COUNT" { print $2 }')
    ident_count=$(wc -l < "${WORK_DIR}/idents" | tr -d ' ')

    echo "[naming] 모드=${MODE} 추출=${EXTRACTOR} 사전=${DICT_PATH}(${dict_count}개) 식별자=${ident_count}개"
    printf '%s\n' "${report}" | grep -v -E '^(DICT_COUNT|WARN_COUNT) ' || true
    echo "[naming] 결과: 경고 ${warn_count}건 (보고만 — 차단하지 않는다)"

    if [ "${STRICT}" -eq 1 ] && [ "${warn_count}" -gt 0 ]; then
        exit "${EXIT_STRICT}"
    fi
    return 0
}

EXTRACTOR=""
Main "$@"
