#!/usr/bin/env bash
################################################################################
# FILE NAME   : collect.sh
# DESCRIPTION : 인터넷 없는 서버에서 분석 자료를 모아 tar.gz 하나로 묶는다.
#               시스템 정보·IPC·프로세스·소켓 요약·지정 로그 꼬리를 모으고,
#               --allow-profile 과 개발·스테이징 표시가 함께 있을 때만 perf 를 돈다.
#               환경변수·셸 이력·지정하지 않은 파일은 모으지 않는다.
#               로그 꼬리는 카드번호·주민등록번호 모양의 숫자를 가리고 담는다.
#               bash 3.2 호환, 외부 다운로드 없음. 규약 정본: skills/remote-linux-analysis/SKILL.md
################################################################################
# 사용법:
#   collect.sh [--name <프로세스명>] [--log <파일>]... [--tail <줄수>]
#              [--env dev|staging|prod] [--allow-profile] [--profile-sec <초>]
#              [--out <디렉터리>] [--dry-run]
#     --name          이 이름의 프로세스만 상세 수집 (pgrep -x 기준)
#     --log           꼬리를 담을 로그 파일. 여러 번 줄 수 있다
#     --tail          로그 꼬리 줄 수 (기본 2000)
#     --env           이 서버의 환경. prod 이면 프로파일링을 거부한다
#     --allow-profile perf record -g 를 --profile-sec 초 동안 돈다 (dev·staging 만)
#     --out           결과 tar.gz 를 둘 디렉터리 (기본 현재 디렉터리)
#     --dry-run       무엇을 모을지만 출력하고 아무것도 만들지 않는다
#   운영 표시 파일: COLLECT_ENV_MARKER(기본 /etc/app-env)에 prod 가 있으면 --env 와
#   무관하게 운영으로 본다.
#   종료 코드: 0 성공 · 2 사용법 오류 · 3 프로파일링 거부
################################################################################

set -euo pipefail
umask 077

readonly EXIT_USAGE=2
readonly EXIT_PROFILE_REFUSED=3
readonly MAX_PROFILE_SEC=120
readonly NAME_RE='^[A-Za-z0-9._-]+$'
readonly NUM_RE='^[0-9]+$'

g_ProcName=""
g_LogFiles=()
g_TailLines=2000
g_EnvName=""
g_AllowProfile=0
g_ProfileSec=10
g_OutDir="."
g_DryRun=0
g_WorkDir=""
g_BundleName=""

#===============================================================================
# FUNCTION    : Die
# DESCRIPTION : 오류 메시지를 표준 에러로 내고 지정 코드로 끝낸다.
# PARAMETERS  : int    code    - 종료 코드
#               string message - 메시지
#===============================================================================
Die() {
    echo "[collect] ERROR: $2" >&2
    exit "$1"
}

#===============================================================================
# FUNCTION    : Usage
# DESCRIPTION : 파일 머리의 사용법 블록을 출력한다.
#===============================================================================
Usage() {
    sed -n '/^# 사용법:/,/^######/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'
}

#===============================================================================
# FUNCTION    : ParseArgs
# DESCRIPTION : 명령행 인자를 해석해 전역 설정에 반영하고 값을 검증한다.
# PARAMETERS  : string args... - 스크립트 인자 전체
#===============================================================================
ParseArgs() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --name)          [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--name 값 필요"; g_ProcName="$2"; shift ;;
            --log)           [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--log 값 필요"; g_LogFiles+=("$2"); shift ;;
            --tail)          [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--tail 값 필요"; g_TailLines="$2"; shift ;;
            --env)           [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--env 값 필요"; g_EnvName="$2"; shift ;;
            --allow-profile) g_AllowProfile=1 ;;
            --profile-sec)   [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--profile-sec 값 필요"; g_ProfileSec="$2"; shift ;;
            --out)           [ $# -ge 2 ] || Die "${EXIT_USAGE}" "--out 값 필요"; g_OutDir="$2"; shift ;;
            --dry-run)       g_DryRun=1 ;;
            -h|--help)       Usage; exit 0 ;;
            *)               Usage >&2; Die "${EXIT_USAGE}" "알 수 없는 인자: $1" ;;
        esac
        shift
    done

    case "${g_EnvName}" in
        ""|dev|staging|prod) ;;
        *) Die "${EXIT_USAGE}" "--env 는 dev, staging, prod 중 하나" ;;
    esac
    if [ -n "${g_ProcName}" ] && ! printf '%s\n' "${g_ProcName}" | grep -Eq "${NAME_RE}"; then
        Die "${EXIT_USAGE}" "--name 은 영문·숫자·._- 만 허용"
    fi
    printf '%s\n' "${g_TailLines}" | grep -Eq "${NUM_RE}" || Die "${EXIT_USAGE}" "--tail 은 숫자"
    printf '%s\n' "${g_ProfileSec}" | grep -Eq "${NUM_RE}" || Die "${EXIT_USAGE}" "--profile-sec 은 숫자"
    if [ "${g_ProfileSec}" -lt 1 ] || [ "${g_ProfileSec}" -gt "${MAX_PROFILE_SEC}" ]; then
        Die "${EXIT_USAGE}" "--profile-sec 은 1~${MAX_PROFILE_SEC}"
    fi
    [ -d "${g_OutDir}" ] || Die "${EXIT_USAGE}" "출력 디렉터리 없음: ${g_OutDir}"
}

#===============================================================================
# FUNCTION    : IsProduction
# DESCRIPTION : --env prod 이거나 운영 표시 파일에 prod 가 적혀 있으면 운영으로 본다.
# RETURNED    : 운영이면 0, 아니면 1
#===============================================================================
IsProduction() {
    local marker="${COLLECT_ENV_MARKER:-/etc/app-env}"

    [ "${g_EnvName}" = "prod" ] && return 0
    if [ -r "${marker}" ] && grep -Eqi '^[[:space:]]*(prod|production)[[:space:]]*$' "${marker}"; then
        return 0
    fi
    return 1
}

#===============================================================================
# FUNCTION    : CheckProfilePolicy
# DESCRIPTION : 프로파일링 요청을 정책(D-09)과 대조한다. 운영이면 거부하고,
#               환경을 밝히지 않았으면 운영일 수 있으므로 역시 거부한다.
#===============================================================================
CheckProfilePolicy() {
    [ "${g_AllowProfile}" -eq 1 ] || return 0
    if IsProduction; then
        Die "${EXIT_PROFILE_REFUSED}" "운영 서버에서는 프로파일링하지 않는다 — 스테이징에서 재현한다"
    fi
    if [ -z "${g_EnvName}" ]; then
        Die "${EXIT_PROFILE_REFUSED}" "--allow-profile 은 --env dev 또는 --env staging 과 함께만 쓴다"
    fi
}

#===============================================================================
# FUNCTION    : MaskDigits
# DESCRIPTION : 표준 입력의 카드번호·주민등록번호 모양 숫자를 가려 표준 출력으로 낸다.
#               주민등록번호 모양(6자리-7자리)은 앞 7자리만 남긴다.
#               구분자(공백·-) 포함 13~19자리 숫자열은 끝 4자리만 남긴다.
#               필드 단위 마스킹을 대신하지 못하는 보조 필터다. 넘치게 가리는 쪽을 택한다.
#===============================================================================
MaskDigits() {
    LC_ALL=C awk '
        function digits_of(s) { gsub(/[^0-9]/, "", s); return s }
        function is_rrn(s,   parts) {
            if (split(s, parts, "-") != 2) return 0
            return length(parts[1]) == 6 && length(parts[2]) == 7 && parts[2] ~ /^[1-4]/
        }
        function mask_run(s,   total, pieces, count, ii, out) {
            if (is_rrn(s)) return substr(s, 1, 8) "******"
            total = length(digits_of(s))
            if (total >= 13 && total <= 19) return mask_digits(s, total)
            if (index(s, " ") == 0) return s
            # 공백으로 이어진 서로 다른 숫자(카드번호 + 금액 등)는 조각마다 다시 본다
            count = split(s, pieces, / /); out = ""
            for (ii = 1; ii <= count; ii++) {
                out = out ((ii > 1) ? " " : "") mask_piece(pieces[ii])
            }
            return out
        }
        function mask_piece(s,   total) {
            if (is_rrn(s)) return substr(s, 1, 8) "******"
            total = length(digits_of(s))
            if (total >= 13 && total <= 19) return mask_digits(s, total)
            return s
        }
        function mask_digits(s, total,   seen, out, ii, ch) {
            out = ""; seen = 0
            for (ii = 1; ii <= length(s); ii++) {
                ch = substr(s, ii, 1)
                if (ch ~ /[0-9]/) {
                    seen++
                    out = out ((seen <= total - 4) ? "*" : ch)
                } else {
                    out = out ch
                }
            }
            return out
        }
        {
            line = $0; result = ""
            while (match(line, /[0-9][0-9 -]*[0-9]/)) {
                result = result substr(line, 1, RSTART - 1) mask_run(substr(line, RSTART, RLENGTH))
                line = substr(line, RSTART + RLENGTH)
            }
            print result line
        }'
}

#===============================================================================
# FUNCTION    : RunTo
# DESCRIPTION : 명령 하나를 실행해 결과를 파일에 덧붙인다. 명령이 없거나 실패해도
#               멈추지 않고 그 사실을 파일에 적는다.
# PARAMETERS  : string file - 결과 파일 (작업 디렉터리 기준)
#               string cmd  - 실행할 명령과 인자
#===============================================================================
RunTo() {
    local file="${g_WorkDir}/${g_BundleName}/$1"
    shift

    printf '### %s\n' "$*" >> "${file}"
    if ! command -v "$1" > /dev/null 2>&1; then
        printf '(명령 없음: %s)\n\n' "$1" >> "${file}"
        return 0
    fi
    "$@" >> "${file}" 2>&1 || printf '(종료 코드 %s)\n' "$?" >> "${file}"
    printf '\n' >> "${file}"
}

#===============================================================================
# FUNCTION    : CatTo
# DESCRIPTION : 읽을 수 있는 시스템 파일 하나를 결과 파일에 덧붙인다.
# PARAMETERS  : string file - 결과 파일 (작업 디렉터리 기준)
#               string src  - 읽을 파일
#===============================================================================
CatTo() {
    local file="${g_WorkDir}/${g_BundleName}/$1"

    printf '### %s\n' "$2" >> "${file}"
    if [ -r "$2" ]; then
        cat -- "$2" >> "${file}" 2>&1 || true
    else
        printf '(읽을 수 없음)\n' >> "${file}"
    fi
    printf '\n' >> "${file}"
}

#===============================================================================
# FUNCTION    : CollectSystem
# DESCRIPTION : 커널·가동 시간·CPU·메모리·자원 한도·IPC 를 모은다.
#===============================================================================
CollectSystem() {
    RunTo system.txt uname -a
    RunTo system.txt uptime
    CatTo system.txt /etc/os-release
    RunTo system.txt nproc
    CatTo system.txt /proc/meminfo
    CatTo system.txt /proc/loadavg
    RunTo system.txt free -m
    RunTo system.txt vmstat 1 3
    RunTo system.txt df -h
    RunTo system.txt sysctl kernel.shmmax kernel.shmall kernel.sem fs.file-max
    printf '### ulimit -a (수집 셸 기준)\n' >> "${g_WorkDir}/${g_BundleName}/system.txt"
    ulimit -a >> "${g_WorkDir}/${g_BundleName}/system.txt" 2>&1 || true
    RunTo ipc.txt ipcs -a
    RunTo ipc.txt ipcs -l
}

#===============================================================================
# FUNCTION    : FindPids
# DESCRIPTION : --name 과 이름이 정확히 같은 프로세스의 PID 를 한 줄에 하나씩 낸다.
#===============================================================================
FindPids() {
    [ -n "${g_ProcName}" ] || return 0
    command -v pgrep > /dev/null 2>&1 || return 0
    pgrep -x -- "${g_ProcName}" 2>/dev/null || true
}

#===============================================================================
# FUNCTION    : CollectProcesses
# DESCRIPTION : 프로세스 목록(명령 인자 제외)과 대상 프로세스의 스레드·fd 수·한도를 모은다.
#               명령 인자와 /proc/<pid>/environ 은 비밀값이 섞일 수 있어 읽지 않는다.
#===============================================================================
CollectProcesses() {
    local file="${g_WorkDir}/${g_BundleName}/process.txt"
    local pid
    local fd_count

    RunTo process.txt ps -eo pid,ppid,user,etime,pcpu,pmem,rss,vsz,comm
    for pid in $(FindPids); do
        printf '### pid %s\n' "${pid}" >> "${file}"
        if [ -r "/proc/${pid}/status" ]; then
            grep -E '^(Name|State|Threads|VmRSS|VmHWM|voluntary_ctxt_switches|nonvoluntary_ctxt_switches):' \
                "/proc/${pid}/status" >> "${file}" 2>&1 || true
        fi
        if [ -d "/proc/${pid}/fd" ]; then
            fd_count=$(find "/proc/${pid}/fd" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
            printf 'fd_count: %s\n' "${fd_count}" >> "${file}"
        fi
        CatTo process.txt "/proc/${pid}/limits"
    done
}

#===============================================================================
# FUNCTION    : CollectSockets
# DESCRIPTION : 소켓 상태 요약과 대기 중인 TCP 포트를 모은다. ss 가 없으면 netstat 을 쓴다.
#===============================================================================
CollectSockets() {
    if command -v ss > /dev/null 2>&1; then
        RunTo socket.txt ss -s
        RunTo socket.txt ss -tnl
    else
        RunTo socket.txt netstat -an
    fi
}

#===============================================================================
# FUNCTION    : CollectLogs
# DESCRIPTION : 지정한 로그 파일의 꼬리를 마스킹해 logs/ 아래에 담는다.
#               같은 이름이 겹치지 않게 순번을 앞에 붙인다.
#===============================================================================
CollectLogs() {
    local dest_dir="${g_WorkDir}/${g_BundleName}/logs"
    local path
    local index=0

    mkdir -p "${dest_dir}"
    for path in ${g_LogFiles[@]+"${g_LogFiles[@]}"}; do
        index=$((index + 1))
        if [ ! -f "${path}" ] || [ ! -r "${path}" ]; then
            printf '읽을 수 없음: %s\n' "${path}" >> "${dest_dir}/MISSING.txt"
            continue
        fi
        tail -n "${g_TailLines}" -- "${path}" | MaskDigits \
            > "${dest_dir}/${index}-$(basename -- "${path}").masked"
    done
}

#===============================================================================
# FUNCTION    : CollectProfile
# DESCRIPTION : perf record -g 로 대상 프로세스(없으면 전체)를 정해진 초만큼 기록하고
#               보고서와 build-id 목록을 남긴다. 정책 검사는 CheckProfilePolicy 가 먼저 한다.
#===============================================================================
CollectProfile() {
    local dir="${g_WorkDir}/${g_BundleName}"
    local pid_list

    [ "${g_AllowProfile}" -eq 1 ] || return 0
    if ! command -v perf > /dev/null 2>&1; then
        printf '(명령 없음: perf)\n' > "${dir}/perf-report.txt"
        return 0
    fi
    pid_list=$(FindPids | paste -sd, -)
    if [ -n "${pid_list}" ]; then
        perf record -g -F 99 -p "${pid_list}" -o "${dir}/perf.data" -- sleep "${g_ProfileSec}" \
            > "${dir}/perf-record.log" 2>&1 || true
    else
        perf record -g -F 99 -a -o "${dir}/perf.data" -- sleep "${g_ProfileSec}" \
            > "${dir}/perf-record.log" 2>&1 || true
    fi
    if [ -f "${dir}/perf.data" ]; then
        perf report --stdio --no-children -i "${dir}/perf.data" 2>/dev/null | head -n 300 \
            > "${dir}/perf-report.txt" || true
        perf buildid-list -i "${dir}/perf.data" > "${dir}/perf-buildid.txt" 2>/dev/null || true
    fi
}

#===============================================================================
# FUNCTION    : WriteManifest
# DESCRIPTION : 수집 조건과 담긴 파일 목록을 MANIFEST.txt 로 남긴다.
#===============================================================================
WriteManifest() {
    local dir="${g_WorkDir}/${g_BundleName}"

    {
        echo "bundle=${g_BundleName}"
        echo "env=${g_EnvName:-unspecified}"
        echo "process=${g_ProcName:--}"
        echo "log_count=${#g_LogFiles[@]}"
        echo "tail_lines=${g_TailLines}"
        echo "profile=${g_AllowProfile}"
        echo "masking=card_rrn_digits"
        echo "files:"
        (cd "${dir}" && find . -type f ! -name MANIFEST.txt | LC_ALL=C sort)
    } > "${dir}/MANIFEST.txt"
}

#===============================================================================
# FUNCTION    : PrintPlan
# DESCRIPTION : --dry-run 에서 무엇을 모을지 출력한다.
#===============================================================================
PrintPlan() {
    local path

    echo "[collect] dry-run — 아무것도 만들지 않는다"
    echo "  출력: ${g_OutDir}/${g_BundleName}.tar.gz"
    echo "  system.txt  uname·uptime·os-release·CPU·메모리·vmstat·df·sysctl·ulimit"
    echo "  ipc.txt     ipcs -a·ipcs -l"
    echo "  process.txt ps(명령 인자 제외)${g_ProcName:+ · ${g_ProcName} 상세}"
    echo "  socket.txt  ss -s·ss -tnl (없으면 netstat -an)"
    for path in ${g_LogFiles[@]+"${g_LogFiles[@]}"}; do
        echo "  logs/       ${path} 꼬리 ${g_TailLines}줄 (마스킹)"
    done
    if [ "${g_AllowProfile}" -eq 1 ]; then
        echo "  perf        perf record -g ${g_ProfileSec}초 (env=${g_EnvName})"
    fi
}

#===============================================================================
# FUNCTION    : Cleanup
# DESCRIPTION : 임시 작업 디렉터리를 지운다.
#===============================================================================
Cleanup() {
    if [ -n "${g_WorkDir}" ] && [ -d "${g_WorkDir}" ]; then
        rm -rf "${g_WorkDir}"
    fi
}

#===============================================================================
# FUNCTION    : Main
# DESCRIPTION : 인자 해석 → 정책 검사 → 수집 → 묶음 순서로 진행한다.
# PARAMETERS  : string args... - 스크립트 인자 전체
#===============================================================================
Main() {
    local host
    local stamp
    local tarball

    ParseArgs "$@"
    CheckProfilePolicy

    host=$(hostname 2>/dev/null | cut -d. -f1 | tr -c 'A-Za-z0-9_-' '_' | sed 's/_*$//')
    stamp=$(date +%Y%m%d-%H%M%S)
    g_BundleName="collect-${host:-host}-${stamp}"

    if [ "${g_DryRun}" -eq 1 ]; then
        PrintPlan
        return 0
    fi

    g_WorkDir=$(mktemp -d "${TMPDIR:-/tmp}/collect.XXXXXX")
    trap Cleanup EXIT
    mkdir -p "${g_WorkDir}/${g_BundleName}"

    CollectSystem
    CollectProcesses
    CollectSockets
    CollectLogs
    CollectProfile
    WriteManifest

    tarball="${g_OutDir}/${g_BundleName}.tar.gz"
    tar -czf "${tarball}" -C "${g_WorkDir}" "${g_BundleName}"
    chmod 600 "${tarball}"
    echo "[collect] 완료: ${tarball}"
}

Main "$@"
