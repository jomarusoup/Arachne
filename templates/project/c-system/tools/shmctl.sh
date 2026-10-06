#!/usr/bin/env bash
################################################################################
# FILE NAME   : shmctl.sh
# DESCRIPTION : 공유메모리 세그먼트 목록·상태·생성·삭제 운영 스크립트.
#               파괴 동작(기존 세그먼트 위 create, remove)은 기본 dry-run 이고 --apply 가 있어야
#               실행한다. 모든 동작은 실행 로그(--log)에 한 줄씩 남긴다. 세그먼트 내용은 출력하지 않는다.
#               규약 정본: skills/shm-db-patterns/SKILL.md "운영" 절
################################################################################
# 사용법:
#   shmctl.sh list
#   shmctl.sh status <대상>
#   shmctl.sh create /<이름> <레코드 수> [--mode 0600|0640] [--apply] [--yes] [--pidfile <경로>]
#   shmctl.sh remove <대상> [--apply] [--yes] [--pidfile <경로>]
#   공통 옵션: --log <경로>(기본 ./shmctl.log) · --bin-dir <디렉터리>(기본: 이 스크립트 위치,
#              환경변수 SHM_TOOLS_BIN_DIR 로도 지정)
#   <대상>: POSIX 이름 "/<이름>" 또는 SysV 세그먼트 "sysv:<shmid>"
#   remove 안전 조건: --pidfile 의 프로세스가 살아 있으면 거부, attach 프로세스가 있으면 거부,
#                     둘 다 확인할 수 없으면(macOS 에서 --pidfile 없음) 거부. --apply 는 확인
#                     프롬프트(세그먼트 이름 재입력)를 거치고, --yes 일 때만 생략한다.
#   종료 코드: 0 성공·dry-run · 1 오류 · 3 안전 조건으로 거부
# bash 3.2(macOS 기본)에서 동작한다 — 연관 배열·mapfile·${var,,} 를 쓰지 않는다.
################################################################################

set -euo pipefail

readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_REFUSED=3
readonly POSIX_NAME_RE='^/[A-Za-z0-9._-]{1,30}$'
readonly SYSV_TARGET_RE='^sysv:[0-9]+$'
readonly CAP_RE='^[1-9][0-9]{0,9}$'
readonly MODE_RE='^0?6[04]0$'

LOG_FILE="./shmctl.log"
BIN_DIR="${SHM_TOOLS_BIN_DIR:-$(cd "$(dirname "$0")" && pwd)}"
PIDFILE=""
MODE="0600"
IS_APPLY=0
ASSUME_YES=0
CMD=""
ARG1=""
ARG2=""

#===============================================================================
# FUNCTION    : Usage
# DESCRIPTION : 사용법을 표준 에러로 출력하고 오류로 끝낸다.
#===============================================================================
Usage() {
    sed -n '/^# 사용법:/,/^# bash 3.2/p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit "${EXIT_ERROR}"
}

#===============================================================================
# FUNCTION    : LogAction
# DESCRIPTION : 실행 로그에 한 줄(시각·사용자·동작·대상·결과)을 덧붙인다.
#               기록할 수 없으면 오류로 끝낸다(기록 없는 운영 조치는 하지 않는다).
# PARAMETERS  : string action - 동작(list·status·create·remove)
#               string target - 대상
#               string result - 결과(ok·dry-run·refused:<사유>·fail:<사유>)
#===============================================================================
LogAction() {
    local action="$1"
    local target="$2"
    local result="$3"
    local line

    line="ts=$(date '+%Y-%m-%dT%H:%M:%S%z') user=$(id -un) host=$(hostname) pid=$$"
    line="${line} action=${action} target=${target} result=${result}"
    if ! (umask 077 && printf '%s\n' "${line}" >> "${LOG_FILE}") 2>/dev/null; then
        echo "[shmctl] 실행 로그 기록 실패: ${LOG_FILE}" >&2
        exit "${EXIT_ERROR}"
    fi
}

#===============================================================================
# FUNCTION    : RequireBin
# DESCRIPTION : 보조 실행 파일이 있는지 확인한다. 없으면 make 안내 후 오류로 끝낸다.
# PARAMETERS  : string bin_name - 실행 파일 이름
#===============================================================================
RequireBin() {
    local bin_name="$1"

    if [ ! -x "${BIN_DIR}/${bin_name}" ]; then
        echo "[shmctl] ${BIN_DIR}/${bin_name} 없음 — tools 디렉터리에서 make 를 먼저 실행한다" >&2
        exit "${EXIT_ERROR}"
    fi
}

#===============================================================================
# FUNCTION    : CheckTarget
# DESCRIPTION : 대상 형식을 검사한다. POSIX 이름 또는 sysv:<shmid> 만 받는다.
# PARAMETERS  : string target - 대상
#===============================================================================
CheckTarget() {
    local target="$1"

    if [[ ! "${target}" =~ ${POSIX_NAME_RE} ]] && [[ ! "${target}" =~ ${SYSV_TARGET_RE} ]]; then
        echo "[shmctl] 대상 형식 오류: /<이름>(영문·숫자·._- 30자 이하) 또는 sysv:<shmid>" >&2
        exit "${EXIT_ERROR}"
    fi
}

IsSysv() {
    case "$1" in
        sysv:*) return 0 ;;
        *)      return 1 ;;
    esac
}

#===============================================================================
# FUNCTION    : SysvNattch
# DESCRIPTION : SysV 세그먼트의 attach 수(nattch)를 출력한다. 없으면 빈 문자열.
# PARAMETERS  : string shmid - 세그먼트 ID
#===============================================================================
SysvNattch() {
    local shmid="$1"

    if [ "$(uname -s)" = "Linux" ]; then
        ipcs -m 2>/dev/null | awk -v id="${shmid}" '$2 == id { print $6 }'
    else
        ipcs -m -a 2>/dev/null | awk -v id="${shmid}" '$1 == "m" && $2 == id { print $9 }'
    fi
}

#===============================================================================
# FUNCTION    : AttachCount
# DESCRIPTION : attach 프로세스 수를 출력한다. 셀 수 없으면 "unknown".
# PARAMETERS  : string target - 대상
#===============================================================================
AttachCount() {
    local target="$1"
    local cnt

    if IsSysv "${target}"; then
        cnt=$(SysvNattch "${target#sysv:}")
        echo "${cnt:-unknown}"
    else
        RequireBin shm_admin
        "${BIN_DIR}/shm_admin" attach-count "${target}"
    fi
}

#===============================================================================
# FUNCTION    : TargetExists
# DESCRIPTION : 대상 세그먼트가 있는지 확인한다.
# PARAMETERS  : string target - 대상
# RETURNED    : 0 있음 · 1 없음
#===============================================================================
TargetExists() {
    local target="$1"

    if IsSysv "${target}"; then
        [ -n "$(SysvNattch "${target#sysv:}")" ]
    else
        RequireBin shm_admin
        "${BIN_DIR}/shm_admin" exists "${target}"
    fi
}

#===============================================================================
# FUNCTION    : OwnerState
# DESCRIPTION : --pidfile 의 소유 프로세스 상태를 출력한다(running·stopped·none).
#===============================================================================
OwnerState() {
    local pid

    if [ -z "${PIDFILE}" ]; then
        echo "none"
        return 0
    fi
    pid=$(head -n 1 "${PIDFILE}" 2>/dev/null | tr -d '[:space:]' || true)
    if [[ "${pid}" =~ ^[1-9][0-9]*$ ]] && kill -0 "${pid}" 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

#===============================================================================
# FUNCTION    : CheckRemovable
# DESCRIPTION : 삭제 안전 조건을 검사하고 판정을 출력한다. 거부 사유가 있으면 1.
# PARAMETERS  : string target - 대상
# RETURNED    : 0 삭제 가능 · 1 거부(사유는 REFUSE_REASON)
#===============================================================================
REFUSE_REASON=""
CheckRemovable() {
    local target="$1"
    local owner
    local attach

    owner=$(OwnerState)
    attach=$(AttachCount "${target}")
    echo "owner_process=${owner}"
    echo "attach_count=${attach}"
    if [ "${owner}" = "running" ]; then
        REFUSE_REASON="owner-running"
    elif [ "${attach}" != "unknown" ] && [ "${attach}" -gt 0 ]; then
        REFUSE_REASON="attached"
    elif [ "${attach}" = "unknown" ] && [ "${owner}" = "none" ]; then
        REFUSE_REASON="unverifiable(--pidfile 필요)"
    else
        REFUSE_REASON=""
        return 0
    fi
    return 1
}

#===============================================================================
# FUNCTION    : Confirm
# DESCRIPTION : --yes 가 없으면 터미널에서 대상 이름을 다시 입력받는다. 터미널이 아니면 거부.
# PARAMETERS  : string target - 대상
# RETURNED    : 0 확인됨 · 1 거부
#===============================================================================
Confirm() {
    local target="$1"
    local answer=""

    if [ "${ASSUME_YES}" -eq 1 ]; then
        return 0
    fi
    if [ ! -t 0 ]; then
        echo "[shmctl] 터미널이 아니다 — 확인 후 --yes 로 다시 실행한다" >&2
        return 1
    fi
    printf '%s 를 삭제한다. 계속하려면 대상을 그대로 입력: ' "${target}" >&2
    read -r answer || return 1
    [ "${answer}" = "${target}" ]
}

#===============================================================================
# FUNCTION    : DoRemoveTarget
# DESCRIPTION : 실제 삭제를 수행한다(안전 조건·확인은 호출자가 끝냈다).
# PARAMETERS  : string target - 대상
#===============================================================================
DoRemoveTarget() {
    local target="$1"

    if IsSysv "${target}"; then
        ipcrm -m "${target#sysv:}"
    else
        "${BIN_DIR}/shm_admin" remove "${target}"
    fi
}

#===============================================================================
# FUNCTION    : GuardedRemove
# DESCRIPTION : 안전 조건 → dry-run 또는 확인 → 삭제 순서를 공통으로 처리한다.
# PARAMETERS  : string action - 로그에 남길 동작 이름(remove·create)
#               string target - 대상
# RETURNED    : 0 삭제함 · 10 dry-run(삭제 안 함). 거부·실패는 여기서 종료한다
#===============================================================================
GuardedRemove() {
    local action="$1"
    local target="$2"

    if ! CheckRemovable "${target}"; then
        echo "result=refused reason=${REFUSE_REASON}"
        LogAction "${action}" "${target}" "refused:${REFUSE_REASON}"
        exit "${EXIT_REFUSED}"
    fi
    if [ "${IS_APPLY}" -eq 0 ]; then
        echo "plan=삭제 ${target} (안전 조건 통과)"
        echo "result=dry-run 변경 없음 — 실행은 --apply"
        LogAction "${action}" "${target}" "dry-run"
        return 10
    fi
    if ! Confirm "${target}"; then
        echo "result=refused reason=not-confirmed"
        LogAction "${action}" "${target}" "refused:not-confirmed"
        exit "${EXIT_REFUSED}"
    fi
    if ! DoRemoveTarget "${target}"; then
        LogAction "${action}" "${target}" "fail:remove"
        exit "${EXIT_ERROR}"
    fi
    echo "removed=${target}"
    return 0
}

CmdList() {
    if [ -d /dev/shm ]; then
        echo "## POSIX (/dev/shm)"
        ls -l /dev/shm
    else
        echo "## POSIX — 이 플랫폼(macOS 등)은 POSIX 공유메모리 이름 목록을 볼 수 없다."
        echo "##         세그먼트 이름은 docs/shm-layout.md 표에서 확인하고 status 로 하나씩 본다."
    fi
    echo "## SysV (ipcs -m)"
    if command -v ipcs >/dev/null 2>&1; then
        ipcs -m || true
    else
        echo "ipcs 없음"
    fi
    LogAction list "-" ok
}

CmdStatus() {
    local target="$1"
    local rc=0

    CheckTarget "${target}"
    if IsSysv "${target}"; then
        if [ "$(uname -s)" = "Linux" ]; then
            ipcs -m -i "${target#sysv:}" || rc=$?
        else
            ipcs -m -a | awk -v id="${target#sysv:}" 'NR <= 3 || ($1 == "m" && $2 == id)' || rc=$?
        fi
    else
        RequireBin shm_view
        "${BIN_DIR}/shm_view" --name "${target}" --header || rc=$?
    fi
    echo "attach_count=$(AttachCount "${target}")"
    echo "owner_process=$(OwnerState)"
    LogAction status "${target}" "rc=${rc}"
    return "${rc}"
}

CmdCreate() {
    local target="$1"
    local cap="$2"
    local rc=0

    if [[ ! "${target}" =~ ${POSIX_NAME_RE} ]] || [[ ! "${cap}" =~ ${CAP_RE} ]] || \
       [[ ! "${MODE}" =~ ${MODE_RE} ]]; then
        echo "[shmctl] create 는 /<이름> <레코드 수> 와 --mode 0600|0640 만 받는다" >&2
        exit "${EXIT_ERROR}"
    fi
    RequireBin shm_admin
    if TargetExists "${target}"; then
        echo "existing=${target} — 기존 세그먼트를 지우고 다시 만든다(파괴 동작)"
        GuardedRemove create "${target}" || rc=$?
        if [ "${rc}" -eq 10 ]; then
            echo "plan=재생성 ${target} rec_cap=${cap} mode=${MODE}"
            return 0
        fi
        LogAction create "${target}" "ok:removed-existing"
    fi
    if ! "${BIN_DIR}/shm_admin" create "${target}" "${cap}" "${MODE}"; then
        LogAction create "${target}" "fail:create"
        exit "${EXIT_ERROR}"
    fi
    LogAction create "${target}" "ok:rec_cap=${cap},mode=${MODE}"
}

CmdRemove() {
    local target="$1"
    local rc=0

    CheckTarget "${target}"
    if ! TargetExists "${target}"; then
        echo "[shmctl] 대상 없음: ${target}" >&2
        LogAction remove "${target}" "fail:not-found"
        exit "${EXIT_ERROR}"
    fi
    GuardedRemove remove "${target}" || rc=$?
    if [ "${rc}" -eq 0 ]; then
        LogAction remove "${target}" ok
    fi
}

#-------------------------------------------------------------------------------
# 인자 해석 — 위치 인자는 최대 두 개(대상, 레코드 수)
#-------------------------------------------------------------------------------
ParseArgs() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --apply)   IS_APPLY=1 ;;
            --yes)     ASSUME_YES=1 ;;
            --log)     [ "$#" -ge 2 ] || Usage; LOG_FILE="$2"; shift ;;
            --pidfile) [ "$#" -ge 2 ] || Usage; PIDFILE="$2"; shift ;;
            --bin-dir) [ "$#" -ge 2 ] || Usage; BIN_DIR="$2"; shift ;;
            --mode)    [ "$#" -ge 2 ] || Usage; MODE="$2"; shift ;;
            -h|--help) Usage ;;
            -*)        Usage ;;
            *)
                if [ -z "${CMD}" ]; then CMD="$1"
                elif [ -z "${ARG1}" ]; then ARG1="$1"
                elif [ -z "${ARG2}" ]; then ARG2="$1"
                else Usage
                fi
                ;;
        esac
        shift
    done
}

Main() {
    ParseArgs "$@"
    case "${CMD}" in
        list)   CmdList ;;
        status) [ -n "${ARG1}" ] || Usage; CmdStatus "${ARG1}" ;;
        create) [ -n "${ARG2}" ] || Usage; CmdCreate "${ARG1}" "${ARG2}" ;;
        remove) [ -n "${ARG1}" ] || Usage; CmdRemove "${ARG1}" ;;
        *)      Usage ;;
    esac
}

Main "$@"
exit "${EXIT_OK}"
