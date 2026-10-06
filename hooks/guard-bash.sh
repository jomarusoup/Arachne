#!/bin/bash
################################################################################
# FILE NAME   : guard-bash.sh
# DESCRIPTION : PreToolUse(Bash) 가드. 실행 전에 명령을 보고 세 가지를 판정한다.
#                 1) 검사 우회(--no-verify, core.hooksPath 변경) → deny
#                 2) 파괴적 명령(DB DROP/TRUNCATE, force push, reset --hard,
#                    위험 경로 rm -rf, chmod 777, ipcrm)         → ask
#                 3) 비밀 파일(.env, 키, 자격증명, 덤프)을 여는 명령 → ask
#               이 가드는 실수 방지용이다. 보안 경계는 permissions 설정이 맡는다.
################################################################################

# 훅은 자동 실행 경로라 -e 제외 (가드 오류가 도구 실행 자체를 막지 않게)
set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/lib-guard.sh
. "${HOOK_DIR}/lib-guard.sh"

#-------------------------------------------------------------------------------
# 판정 결과 누적 (deny 가 ask 보다 우선)
#-------------------------------------------------------------------------------
g_DenyReasons=""
g_AskReasons=""

AddDeny() { g_DenyReasons="${g_DenyReasons}${g_DenyReasons:+ / }$1"; }
AddAsk()  { g_AskReasons="${g_AskReasons}${g_AskReasons:+ / }$1"; }

#===============================================================================
# FUNCTION    : IsSecretPath
# DESCRIPTION : 단어가 비밀 파일 경로처럼 보이는지 판정한다.
#               .env.example 같은 예시 파일과 공개키(.pub)는 제외한다.
# PARAMETERS  : string word - 명령의 한 단어
# RETURNED    : 0(비밀 경로) / 1(아님)
#===============================================================================
IsSecretPath() {
    local word="$1"
    local base="${word##*/}"

    case "${base}" in
        *.pub|known_hosts|*.example|*.sample|*.template|*.dist) return 1 ;;
    esac
    case "${base}" in
        .env|.env.*|*.pem|*.key|*.p12|*.pfx|*.jks|*.keystore) return 0 ;;
        id_rsa*|id_ed25519*|id_ecdsa*|id_dsa*)                 return 0 ;;
        .pgpass|.netrc|tnsnames.ora|sqlnet.ora|cwallet.sso)    return 0 ;;
        *credentials*|*.dmp|*.dump)                            return 0 ;;
    esac
    case "${word}" in
        *.ssh/*|*.aws/*|*/wallet/*|*/secrets/*|*.docker/config.json) return 0 ;;
    esac
    return 1
}

#===============================================================================
# FUNCTION    : IsRiskyRmTarget
# DESCRIPTION : rm -rf 대상이 위험한 경로인지 판정한다. 임시 디렉터리 아래와
#               단순 상대 경로(build, ./dist 등)는 허용한다.
# PARAMETERS  : string target - rm 대상 단어
# RETURNED    : 0(위험) / 1(허용)
#===============================================================================
IsRiskyRmTarget() {
    local target="$1"

    # '~' 는 펼치지 않고 글자 그대로 비교한다
    # shellcheck disable=SC2088
    case "${target}" in
        /tmp/?*|/private/tmp/?*|/var/folders/?*|"${TMPDIR:-/nonexistent}"/?*) return 1 ;;
        /|/*|'~'|'~/'*|'$HOME'*|'${HOME}'*|.|..|../*|*/..|*/../*|'*'|./'*') return 0 ;;
    esac
    return 1
}

#===============================================================================
# FUNCTION    : CheckGit
# DESCRIPTION : git 호출 하나를 판정한다. 서브커맨드 앞의 전역 옵션(-c 값 등)과
#               서브커맨드별 옵션을 따로 본다.
# PARAMETERS  : string... args - git 다음 단어들(따옴표 해석 완료)
#===============================================================================
CheckGit() {
    local -a args=("$@")
    local sub_idx
    sub_idx=$(GuardGitSubcommand "$@")
    local jj

    #---------------------------------------------------------------------------
    # 전역 옵션: -c core.hooksPath=... 로 훅을 끄는 경우
    #---------------------------------------------------------------------------
    for ((jj = 0; jj < ${#args[@]}; jj++)); do
        [ "${sub_idx}" -ge 0 ] && [ "${jj}" -ge "${sub_idx}" ] && break
        case "${args[${jj}]}" in
            -c)
                case "${args[$((jj + 1))]:-}" in
                    core.hooksPath=*|core.hookspath=*)
                        AddDeny "core.hooksPath 변경으로 훅을 우회할 수 없습니다" ;;
                esac ;;
            --config-env=core.hooksPath*|--config-env=core.hookspath*)
                AddDeny "core.hooksPath 변경으로 훅을 우회할 수 없습니다" ;;
        esac
    done
    [ "${sub_idx}" -lt 0 ] && return 0

    local sub="${args[${sub_idx}]}"
    local -a rest=("${args[@]:$((sub_idx + 1))}")
    local word

    case "${sub}" in
        commit)
            GuardParseCommitArgs "${rest[@]+"${rest[@]}"}"
            [ "${g_CommitNoVerify}" -eq 1 ] \
                && AddDeny "검사 우회(git commit --no-verify / -n)는 허용하지 않습니다. 실패한 검사를 고친 뒤 다시 실행하세요"
            ;;
        push|merge|rebase|am|cherry-pick)
            local has_force=0
            for word in "${rest[@]+"${rest[@]}"}"; do
                case "${word}" in
                    --no-verify)
                        AddDeny "검사 우회(git ${sub} --no-verify)는 허용하지 않습니다" ;;
                    --force|--force=*)
                        [ "${sub}" = "push" ] && has_force=1 ;;
                    -[!-]*)
                        [ "${sub}" = "push" ] && case "${word}" in *f*) has_force=1 ;; esac ;;
                esac
            done
            [ "${has_force}" -eq 1 ] \
                && AddAsk "force push 는 원격 이력을 덮어씁니다(--force-with-lease 는 허용)"
            ;;
        config)
            local sets_hooks_path=0
            local config_read=0
            for word in "${rest[@]+"${rest[@]}"}"; do
                case "${word}" in
                    core.hooksPath|core.hookspath) sets_hooks_path=1 ;;
                    --get|--get-all|--get-regexp|--list|-l|--show-origin) config_read=1 ;;
                esac
            done
            [ "${sets_hooks_path}" -eq 1 ] && [ "${config_read}" -eq 0 ] \
                && AddDeny "core.hooksPath 변경으로 훅을 우회할 수 없습니다"
            ;;
        reset)
            for word in "${rest[@]+"${rest[@]}"}"; do
                [ "${word}" = "--hard" ] && AddAsk "git reset --hard 는 커밋하지 않은 변경을 지웁니다"
            done
            ;;
        clean)
            for word in "${rest[@]+"${rest[@]}"}"; do
                case "${word}" in
                    --force|-[!-]*f*) AddAsk "git clean -f 는 추적하지 않는 파일을 지웁니다"; break ;;
                esac
            done
            ;;
    esac
}

#===============================================================================
# FUNCTION    : CheckSegment
# DESCRIPTION : 명령의 한 부분(;·&·| 로 나눈 단위)을 판정해 사유를 누적한다.
# PARAMETERS  : string... words - 부분을 이루는 단어들(따옴표 해석 완료)
#===============================================================================
CheckSegment() {
    local -a words=("$@")
    [ "${#words[@]}" -eq 0 ] && return 0

    local ii=0
    local jj
    local word

    #---------------------------------------------------------------------------
    # 환경 변수 접두(FOO=1 cmd)·sudo·env 를 건너뛰고 실제 명령을 찾는다
    #---------------------------------------------------------------------------
    while [ "${ii}" -lt "${#words[@]}" ]; do
        case "${words[${ii}]}" in
            *=*|sudo|env|command|exec|time|nice|nohup) ii=$((ii + 1)) ;;
            *) break ;;
        esac
    done
    [ "${ii}" -ge "${#words[@]}" ] && return 0
    local cmd="${words[${ii}]##*/}"
    local -a rest=("${words[@]:$((ii + 1))}")

    case "${cmd}" in
        git)
            CheckGit "${rest[@]+"${rest[@]}"}" ;;
        rm)
            local recursive=0
            local force=0
            local -a targets=()
            for word in "${rest[@]+"${rest[@]}"}"; do
                case "${word}" in
                    --recursive) recursive=1 ;;
                    --force) force=1 ;;
                    --*) ;;
                    -?*)
                        case "${word}" in *[rR]*) recursive=1 ;; esac
                        case "${word}" in *f*) force=1 ;; esac
                        ;;
                    *) targets+=("${word}") ;;
                esac
            done
            if [ "${recursive}" -eq 1 ] && [ "${force}" -eq 1 ]; then
                local target
                for target in "${targets[@]+"${targets[@]}"}"; do
                    if IsRiskyRmTarget "${target}"; then
                        AddAsk "rm -rf 대상이 위험한 경로입니다: ${target}"
                        break
                    fi
                done
            fi
            ;;
        chmod)
            for word in "${rest[@]+"${rest[@]}"}"; do
                case "${word}" in
                    777|0777|*a+rwx*|*o+w*)
                        AddAsk "chmod 로 모든 사용자에게 쓰기 권한을 주려 합니다"; break ;;
                esac
            done
            ;;
        ipcrm)
            AddAsk "ipcrm 은 공유메모리·세마포어를 삭제합니다. 사용 중인 프로세스가 없는지 확인하세요" ;;
    esac

    #---------------------------------------------------------------------------
    # 비밀 파일을 여는 명령 (목록·존재 확인 명령과 git 은 허용)
    #---------------------------------------------------------------------------
    case "${cmd}" in
        ls|stat|test|'['|file|wc|git) return 0 ;;
    esac
    for word in "${rest[@]+"${rest[@]}"}"; do
        word="${word#[<>]}"
        if IsSecretPath "${word}"; then
            AddAsk "비밀 파일로 보이는 경로를 읽으려 합니다: ${word##*/} (내용이 대화로 유입됩니다)"
            break
        fi
    done
}

#-------------------------------------------------------------------------------
# 입력 읽기 — Bash 도구가 아니면 관여하지 않는다
#-------------------------------------------------------------------------------
payload=$(cat 2>/dev/null || true)
[ -z "${payload}" ] && exit 0
tool_name=$(GuardJsonString "${payload}" "tool_name")
[ -n "${tool_name}" ] && [ "${tool_name}" != "Bash" ] && exit 0
command_text=$(GuardJsonString "${payload}" "command")
[ -z "${command_text}" ] && exit 0

#-------------------------------------------------------------------------------
# 명령을 단어로 나누고(따옴표 해석), 부분마다 판정
#-------------------------------------------------------------------------------
GuardTokenize "${command_text}"
segment_words=()
for token in "${g_Tokens[@]+"${g_Tokens[@]}"}"; do
    if [ "${token}" = "${GUARD_SEGMENT_MARK}" ]; then
        CheckSegment "${segment_words[@]+"${segment_words[@]}"}"
        segment_words=()
    else
        segment_words+=("${token}")
    fi
done
CheckSegment "${segment_words[@]+"${segment_words[@]}"}"

#-------------------------------------------------------------------------------
# DB 파괴 명령 — DB 클라이언트를 부르는 명령에서만 본다(heredoc 포함 전체 문자열)
#-------------------------------------------------------------------------------
if printf '%s' "${command_text}" | grep -qwE 'psql|sqlplus|sqlcl|mysql|sqlite3|isql|ecpg'; then
    if printf '%s' "${command_text}" \
        | grep -qiE '(drop[[:space:]]+(table|database|schema|user|tablespace|index|view|sequence|materialized)|truncate[[:space:]]+(table[[:space:]]+)?[a-z_])'; then
        AddAsk "DB 객체 삭제(DROP/TRUNCATE)가 포함되어 있습니다. 대상 DB가 개발용인지 확인하세요"
    fi
fi

#-------------------------------------------------------------------------------
# 결정 출력
#-------------------------------------------------------------------------------
if [ -n "${g_DenyReasons}" ]; then
    GuardDecide "deny" "[Arachne 가드] ${g_DenyReasons}"
elif [ -n "${g_AskReasons}" ]; then
    GuardDecide "ask" "[Arachne 가드] ${g_AskReasons}"
fi
exit 0
