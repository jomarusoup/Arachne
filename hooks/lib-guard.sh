#!/bin/bash
# shellcheck disable=SC2034  # g_Tokens·g_Commit* 는 이 파일을 source 하는 가드가 읽는 결과 변수
################################################################################
# FILE NAME   : lib-guard.sh
# DESCRIPTION : 보안 가드 훅(guard-bash.sh·guard-secrets.sh) 공용 함수.
#               PreToolUse 입력 JSON 에서 값을 꺼내고, 결정 JSON 을 출력한다.
#               jq 가 있으면 쓰고, 없으면(Windows Git Bash 등) 정규식으로 폴백한다.
# DATA        : 2026-10-05
# Modification: 2026-10-05
################################################################################

#===============================================================================
# FUNCTION    : GuardJsonString
# DESCRIPTION : JSON 문자열 필드 값을 꺼낸다(이스케이프 해제 포함).
#               같은 이름의 필드가 여러 개면 첫 번째를 쓴다.
# PARAMETERS  : string payload - 훅 입력 JSON
#               string key     - 필드 이름 (예: command, cwd)
# RETURNED    : 필드 값을 stdout 으로. 없으면 빈 문자열
#===============================================================================
GuardJsonString() {
    local payload="$1"
    local key="$2"

    # GUARD_NO_JQ=1 이면 폴백 경로를 강제한다(테스트용)
    if [ -z "${GUARD_NO_JQ:-}" ] && command -v jq >/dev/null 2>&1; then
        printf '%s' "${payload}" \
            | jq -r --arg k "${key}" '[.. | objects | .[$k]? | strings] | first // empty' 2>/dev/null
        return 0
    fi

    #---------------------------------------------------------------------------
    # 폴백: "key":"..." 에서 이스케이프된 따옴표를 포함한 값을 잡고 해제한다
    #---------------------------------------------------------------------------
    printf '%s' "${payload}" \
        | grep -oE "\"${key}\"[[:space:]]*:[[:space:]]*\"(\\\\.|[^\"\\\\])*\"" \
        | head -1 \
        | sed -E "s/^\"${key}\"[[:space:]]*:[[:space:]]*\"//; s/\"\$//" \
        | sed -E 's/\\n/ /g; s/\\t/ /g; s/\\"/"/g; s/\\\\/\\/g'
}

#===============================================================================
# FUNCTION    : GuardJsonEscape
# DESCRIPTION : 문자열을 JSON 문자열 리터럴 안에 넣을 수 있게 이스케이프한다.
# PARAMETERS  : string text - 원문
# RETURNED    : 이스케이프된 문자열을 stdout 으로
#===============================================================================
GuardJsonEscape() {
    # 역슬래시·따옴표를 이스케이프하고, 그 밖의 제어 문자는 공백으로 바꾼다
    printf '%s' "$1" | sed -E 's/\\/\\\\/g; s/"/\\"/g' | tr '\000-\037' ' '
}

#===============================================================================
# FUNCTION    : GuardDecide
# DESCRIPTION : PreToolUse 결정 JSON 을 출력한다. Claude 와 사용자에게 사유가 보인다.
# PARAMETERS  : string decision - deny | ask
#               string reason   - 사유(한 줄 권장)
#===============================================================================
GuardDecide() {
    local decision="$1"
    local reason
    reason=$(GuardJsonEscape "$2")
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' \
        "${decision}" "${reason}"
}

#-------------------------------------------------------------------------------
# 셸 명령 토큰화 — 따옴표·이스케이프를 해석하고 명령 구분자에서 부분을 나눈다
#-------------------------------------------------------------------------------
readonly GUARD_SEGMENT_MARK=$'\x1e'

#===============================================================================
# FUNCTION    : GuardTokenize
# DESCRIPTION : 셸 명령 문자열을 셸이 보는 것과 비슷하게 단어로 나눈다.
#               작은따옴표·큰따옴표·역슬래시를 해석해 따옴표를 벗기고,
#               ; & | 와 줄바꿈에서 부분(segment)을 나눠 GUARD_SEGMENT_MARK 를 넣는다.
#               heredoc(<<) 을 만나면 그 뒤 본문은 단어로 보지 않는다.
#               결과는 전역 배열 g_Tokens 에 담는다.
# PARAMETERS  : string text - 셸 명령 문자열
#===============================================================================
GuardTokenize() {
    local text="$1"
    local len=${#text}
    local cur=""
    local has_cur=0
    local in_single=0
    local in_double=0
    local escaped=0
    local ii
    local ch

    g_Tokens=()
    for ((ii = 0; ii < len; ii++)); do
        ch="${text:ii:1}"
        if [ "${escaped}" -eq 1 ]; then
            cur="${cur}${ch}"; has_cur=1; escaped=0; continue
        fi
        if [ "${in_single}" -eq 1 ]; then
            if [ "${ch}" = "'" ]; then in_single=0; else cur="${cur}${ch}"; fi
            continue
        fi
        if [ "${in_double}" -eq 1 ]; then
            case "${ch}" in
                \\) escaped=1 ;;
                '"')  in_double=0 ;;
                *)    cur="${cur}${ch}" ;;
            esac
            continue
        fi
        case "${ch}" in
            "'") in_single=1; has_cur=1 ;;
            '"') in_double=1; has_cur=1 ;;
            \\) escaped=1 ;;
            ' '|$'\t')
                if [ "${has_cur}" -eq 1 ]; then g_Tokens+=("${cur}"); cur=""; has_cur=0; fi ;;
            ';'|'&'|'|'|$'\n')
                if [ "${has_cur}" -eq 1 ]; then g_Tokens+=("${cur}"); cur=""; has_cur=0; fi
                g_Tokens+=("${GUARD_SEGMENT_MARK}") ;;
            '<')
                if [ "${text:ii+1:1}" = "<" ]; then
                    if [ "${has_cur}" -eq 1 ]; then g_Tokens+=("${cur}"); fi
                    return 0
                fi
                cur="${cur}${ch}"; has_cur=1 ;;
            *)
                cur="${cur}${ch}"; has_cur=1 ;;
        esac
    done
    if [ "${has_cur}" -eq 1 ]; then g_Tokens+=("${cur}"); fi
    return 0
}

#===============================================================================
# FUNCTION    : GuardParseCommitArgs
# DESCRIPTION : git commit 뒤의 인자를 해석해 검사 우회(-n·--no-verify)와
#               전체 추가(-a·--all) 여부를 찾는다. 짧은 옵션을 붙여 쓴 형태(-nm)와
#               인자를 받는 옵션(-m 메시지 등)을 구분해, 메시지 안의 글자를
#               옵션으로 오인하지 않는다. 결과는 g_CommitNoVerify·g_CommitAll.
# PARAMETERS  : string... args - commit 서브커맨드 뒤의 단어들
#===============================================================================
GuardParseCommitArgs() {
    local word
    local skip_next=0
    local kk
    local ch

    g_CommitNoVerify=0
    g_CommitAll=0
    for word in "$@"; do
        if [ "${skip_next}" -eq 1 ]; then skip_next=0; continue; fi
        case "${word}" in
            --) return 0 ;;
            --no-verify) g_CommitNoVerify=1 ;;
            --all) g_CommitAll=1 ;;
            --author|--message|--file|--reuse-message|--reedit-message|--fixup|--squash|--template|--cleanup|--date|--trailer|--pathspec-from-file)
                skip_next=1 ;;
            --*) ;;
            -?*)
                for ((kk = 1; kk < ${#word}; kk++)); do
                    ch="${word:kk:1}"
                    case "${ch}" in
                        n) g_CommitNoVerify=1 ;;
                        a) g_CommitAll=1 ;;
                        m|F|C|c|t)
                            # 인자를 받는 옵션: 뒤에 글자가 남아 있으면 그게 인자, 없으면 다음 단어
                            [ $((kk + 1)) -ge ${#word} ] && skip_next=1
                            break ;;
                    esac
                done ;;
        esac
    done
    return 0
}

#===============================================================================
# FUNCTION    : GuardGitSubcommand
# DESCRIPTION : git 호출 단어들에서 전역 옵션(-c 값, -C 경로 등)을 건너뛰고
#               서브커맨드 위치를 찾는다.
# PARAMETERS  : string... words - git 다음 단어들
# RETURNED    : 서브커맨드의 0 기반 위치를 stdout 으로(없으면 -1)
#===============================================================================
GuardGitSubcommand() {
    local idx=0
    local word
    local skip_next=0
    for word in "$@"; do
        if [ "${skip_next}" -eq 1 ]; then skip_next=0; idx=$((idx + 1)); continue; fi
        case "${word}" in
            -c|-C|--git-dir|--work-tree|--namespace|--exec-path) skip_next=1 ;;
            -*) ;;
            *) echo "${idx}"; return 0 ;;
        esac
        idx=$((idx + 1))
    done
    echo "-1"
}

