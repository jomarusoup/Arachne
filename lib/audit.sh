################################################################################
# FILE NAME   : audit.sh
# DESCRIPTION : arachne --audit 도메인 — 개발 머신의 취약점·하드닝 상태를 읽기
#               전용으로 점검한다. 수정은 하지 않고 조치 명령만 안내한다.
#               기본: OS 보안 업데이트 · 재부팅/재시작 필요 · CPU 취약점 완화 ·
#                     커널 sysctl 하드닝 · SELinux · 외부 리스닝 포트
#               --full  : + Lynis 시스템 하드닝 감사 (+ trivy 가 있으면 프로젝트 의존성)
#               --binary: 빌드 결과물 하드닝 플래그 검증 (annocheck)
#               결과는 ~/.claude/arachne/audit/latest.tsv 에 저장하고, 직전 결과에
#               없던 항목은 [NEW] 로 표시한다. install.sh 에서 source 된다.
################################################################################
# shellcheck shell=bash

readonly AUDIT_DIR="${HOME}/.claude/arachne/audit"
readonly AUDIT_LATEST="${AUDIT_DIR}/latest.tsv"

#-------------------------------------------------------------------------------
# 커널 sysctl 하드닝 기준 — "키|최소값|비교(eq·ge)|설명"
# ptrace_scope 1 은 gdb 로 자식 프로세스 디버깅은 허용하고 임의 attach 만 막는다
#-------------------------------------------------------------------------------
readonly AUDIT_SYSCTL_BASELINE=(
    "kernel.randomize_va_space|2|eq|ASLR 전체 적용"
    "kernel.kptr_restrict|1|ge|커널 포인터 노출 제한"
    "kernel.dmesg_restrict|1|eq|비특권 dmesg 차단"
    "kernel.yama.ptrace_scope|1|ge|임의 프로세스 ptrace attach 차단 (gdb attach 는 sudo)"
    "kernel.unprivileged_bpf_disabled|1|ge|비특권 BPF 차단"
    "fs.protected_symlinks|1|eq|/tmp 심볼릭 링크 공격 방지"
    "fs.protected_hardlinks|1|eq|하드링크 공격 방지"
    "fs.suid_dumpable|1|ne|setuid 코어 덤프 (1=보호 없이 덤프 — 0 또는 2[systemd-coredump] 권장)"
)

AUDIT_FINDINGS=""
AUDIT_FULL=0
AUDIT_BINARIES=()

#===============================================================================
# FUNCTION    : EnsureAuditDir
# DESCRIPTION : 결과 디렉터리 생성과 권한(700) 설정을 한 번에 — 보고서가 기본 umask 로
#               먼저 쓰이는 틈을 없앤다
#===============================================================================
EnsureAuditDir() {
    mkdir -p "${AUDIT_DIR}"
    chmod 700 "${AUDIT_DIR}" 2>/dev/null || true
}

#===============================================================================
# FUNCTION    : AuditAdd
# DESCRIPTION : 점검 결과 한 건 기록 ("ID<TAB>심각도<TAB>내용<TAB>조치")
# PARAMETERS  : string id       - 기준선 비교용 고유 ID
#               string severity - CRITICAL · HIGH · MEDIUM · LOW · INFO · OK
#               string message  - 내용
#               string fix      - 조치 명령·안내 (없으면 빈 값)
#===============================================================================
AuditAdd() {
    AUDIT_FINDINGS="${AUDIT_FINDINGS}$1	$2	$3	${4:-}
"
}

#===============================================================================
# FUNCTION    : AuditOsSecurity
# DESCRIPTION : 미적용 OS 보안 업데이트를 심각도별로 집계
#               dnf: updateinfo(Rocky RLSA·RHSA) · apt: -security 저장소 업그레이드
#===============================================================================
AuditOsSecurity() {
    local list
    local sev
    local count
    local label
    local repo_errors

    case "${TOOLS_PM}" in
        dnf)
            # $( ) 서브셸에서도 같은 파일에 쌓이도록 미리 만든다
            DNF_QUERY_ERR=$(mktemp)
            if ! list=$(DnfQuery updateinfo list --security); then
                AuditAdd "os-security-query" "MEDIUM" "OS 보안 업데이트 조회 실패 — 결과를 신뢰할 수 없음" \
                    "LC_ALL=C dnf updateinfo list --security 로 직접 확인"
            fi
            repo_errors=$(DnfRepoErrors)
            if [ -n "${repo_errors}" ]; then
                AuditAdd "repo-errors" "MEDIUM" "저장소 메타데이터·서명 검증 실패 (조회에서 제외됨): ${repo_errors}" \
                    "GPG 키 교체 공지 확인 후 sudo rpm --import <공식 키>, 또는 dnf config-manager --set-disabled <저장소>"
            fi
            rm -f "${DNF_QUERY_ERR}"
            DNF_QUERY_ERR=""
            # 공지(advisory) ID 단위로 센다 — 한 공지가 패키지 여러 줄을 갖는다
            for sev in Critical Important Moderate Low Unknown; do
                count=$(printf '%s\n' "${list}" | awk -v s="${sev}/Sec." '$2 == s { print $1 }' | sort -u | grep -c . || true)
                [ "${count}" -gt 0 ] || continue
                case "${sev}" in
                    Critical)  label="CRITICAL" ;;
                    Important) label="HIGH" ;;
                    Moderate|Unknown) label="MEDIUM" ;;
                    *)         label="LOW" ;;
                esac
                AuditAdd "os-security-${sev}" "${label}" \
                    "OS 보안 공지 미적용 ${count}건 (${sev}): $(printf '%s\n' "${list}" | awk -v s="${sev}/Sec." '$2 == s { print $3 }' | sed -E 's/-[0-9].*//' | sort -u | head -6 | tr '\n' ' ')" \
                    "sudo dnf upgrade --security  (목록: dnf updateinfo info --security --sec-severity ${sev})"
            done
            ;;
        apt)
            count=$(RunWithTimeout 120 apt list --upgradable 2>/dev/null </dev/null | grep -c -- '-security' || true)
            if [ "${count}" -gt 0 ]; then
                AuditAdd "os-security-apt" "HIGH" "보안 저장소 업그레이드 미적용 ${count}건" \
                    "sudo apt-get update && sudo apt-get upgrade  (심각도별 목록: debsecan)"
            fi
            ;;
        *)
            AuditAdd "os-security-na" "INFO" "OS 보안 업데이트 점검 미지원 패키지 관리자 (${TOOLS_PM})" ""
            return 0
            ;;
    esac
    if ! printf '%s' "${AUDIT_FINDINGS}" | grep -qE '^os-security-'; then
        if printf '%s' "${AUDIT_FINDINGS}" | grep -q '^repo-errors'; then
            AuditAdd "os-security" "OK" "OS 보안 업데이트 모두 적용됨 (조회 가능한 저장소 기준)" ""
        else
            AuditAdd "os-security" "OK" "OS 보안 업데이트 모두 적용됨" ""
        fi
    fi
    return 0
}

#===============================================================================
# FUNCTION    : AuditReboot
# DESCRIPTION : 패치는 받았지만 재부팅·서비스 재시작을 안 해 실행 중인 것이 여전히
#               옛 버전인지 점검 (커널·glibc·openssl 등)
#===============================================================================
AuditReboot() {
    local running
    local newest=""
    local services

    running=$(uname -r)
    if command -v rpm >/dev/null 2>&1 && rpm -q kernel >/dev/null 2>&1; then
        newest=$(rpm -q kernel --qf '%{BUILDTIME} %{VERSION}-%{RELEASE}.%{ARCH}\n' 2>/dev/null | sort -n | tail -1 | awk '{print $2}')
    fi

    local rc=0
    local checked=1

    if command -v needs-restarting >/dev/null 2>&1; then
        needs-restarting -r >/dev/null 2>&1 </dev/null || rc=$?
        if [ "${rc}" -gt 1 ]; then
            AuditAdd "reboot-check" "INFO" "needs-restarting 오류 (rc=${rc}) — 재부팅 필요 여부 판정 불가" "sudo needs-restarting -r"
            checked=0
        elif [ "${rc}" -eq 1 ]; then
            AuditAdd "reboot-required" "HIGH" \
                "재부팅 필요 — 실행 커널 ${running}${newest:+, 설치된 최신 ${newest}} (핵심 라이브러리 갱신 반영 안 됨)" \
                "작업 저장 후 sudo reboot"
        fi
        services=$(RunWithTimeout 60 needs-restarting -s 2>/dev/null </dev/null | wc -l) || services=0
        if [ "${services}" -gt 0 ]; then
            AuditAdd "restart-services" "MEDIUM" "갱신된 라이브러리를 아직 쓰는 서비스 ${services}개" \
                "needs-restarting -s 로 목록 확인 후 sudo systemctl restart <서비스>"
        fi
    elif [ -f /var/run/reboot-required ]; then
        AuditAdd "reboot-required" "HIGH" "재부팅 필요 (/var/run/reboot-required)" "작업 저장 후 sudo reboot"
    elif [ -n "${newest}" ] && [ "${newest}" != "${running}" ]; then
        AuditAdd "reboot-required" "HIGH" "실행 커널 ${running} ≠ 설치된 최신 ${newest}" "작업 저장 후 sudo reboot"
    elif [ -z "${newest}" ]; then
        checked=0
        if [ "${TOOLS_PM}" = "dnf" ]; then
            AuditAdd "reboot-check" "INFO" "재부팅 필요 여부 점검 불가 — needs-restarting 미설치 (dnf-utils)" \
                "arachne -t --group security"
        else
            AuditAdd "reboot-check" "INFO" "재부팅 필요 여부 점검 불가 (이 플랫폼 미지원)" ""
        fi
    fi
    if [ "${checked}" -eq 1 ] && ! printf '%s' "${AUDIT_FINDINGS}" | grep -q '^reboot-required'; then
        AuditAdd "reboot" "OK" "실행 커널 ${running} — 재부팅 불필요" ""
    fi
}

#===============================================================================
# FUNCTION    : AuditCpu
# DESCRIPTION : CPU 하드웨어 취약점(Spectre·Meltdown·MDS 등) 완화 상태
# PARAMETERS  : string vuln_dir - 검사 디렉터리 (테스트 override 용, 기본 sysfs)
#===============================================================================
AuditCpu() {
    local vuln_dir="${1:-/sys/devices/system/cpu/vulnerabilities}"
    local path
    local name
    local state
    local vulnerable=0

    [ -d "${vuln_dir}" ] || { AuditAdd "cpu-na" "INFO" "CPU 취약점 정보 없음 (${vuln_dir})" ""; return 0; }
    for path in "${vuln_dir}"/*; do
        [ -r "${path}" ] || continue
        name=$(basename "${path}")
        state=$(cat "${path}" 2>/dev/null || true)
        case "${state}" in
            Vulnerable*)
                AuditAdd "cpu-${name}" "HIGH" "CPU 취약점 ${name}: ${state}" \
                    "마이크로코드·커널 업데이트 (sudo dnf upgrade microcode_ctl kernel) 후 재부팅, mitigations=off 부팅 옵션 확인"
                vulnerable=$((vulnerable + 1))
                ;;
        esac
    done
    [ "${vulnerable}" -eq 0 ] && AuditAdd "cpu" "OK" "CPU 취약점 모두 완화 또는 해당 없음" ""
    return 0
}

#===============================================================================
# FUNCTION    : AuditSysctl
# DESCRIPTION : 커널 sysctl 하드닝 값을 기준선과 비교
#===============================================================================
AuditSysctl() {
    local entry
    local key
    local want
    local cmp_op
    local desc
    local have
    local weak=0
    local checked=0
    local fix_lines=""

    for entry in "${AUDIT_SYSCTL_BASELINE[@]}"; do
        key=$(echo "${entry}" | cut -d'|' -f1)
        want=$(echo "${entry}" | cut -d'|' -f2)
        cmp_op=$(echo "${entry}" | cut -d'|' -f3)
        desc=$(echo "${entry}" | cut -d'|' -f4)
        have=$(sysctl -n "${key}" 2>/dev/null || cat "/proc/sys/${key//.//}" 2>/dev/null || true)
        [ -n "${have}" ] || continue
        checked=$((checked + 1))
        if { [ "${cmp_op}" = "eq" ] && [ "${have}" != "${want}" ]; } \
            || { [ "${cmp_op}" = "ne" ] && [ "${have}" = "${want}" ]; } \
            || { [ "${cmp_op}" = "ge" ] && [ "${have}" -lt "${want}" ]; }; then
            AuditAdd "sysctl-${key}" "MEDIUM" "sysctl ${key}=${have} — ${desc}" ""
            [ "${cmp_op}" = "ne" ] && want=0
            fix_lines="${fix_lines}${key} = ${want}\n"
            weak=$((weak + 1))
        fi
    done
    if [ "${checked}" -eq 0 ]; then
        AuditAdd "sysctl-na" "INFO" "커널 sysctl 값을 읽을 수 없음 (이 플랫폼·컨테이너 미지원)" ""
    elif [ "${weak}" -eq 0 ]; then
        AuditAdd "sysctl" "OK" "커널 sysctl 하드닝 기준 충족" ""
    else
        # 조치는 한 파일을 통째로 쓰는 한 줄 — 재실행해도 중복되지 않는다
        AuditAdd "sysctl-fix" "INFO" "sysctl 기준 미달 ${weak}건 일괄 적용 방법 (개발 편의와 상충하면 항목별로 판단)" \
            "printf '${fix_lines}' | sudo tee /etc/sysctl.d/90-arachne.conf >/dev/null && sudo sysctl --system"
    fi
    return 0
}

#===============================================================================
# FUNCTION    : AuditSelinux
# DESCRIPTION : SELinux 강제 모드 여부 (RHEL 계열 기본 보호층)
#===============================================================================
AuditSelinux() {
    local mode

    command -v getenforce >/dev/null 2>&1 || return 0
    mode=$(getenforce 2>/dev/null || true)
    if [ "${mode}" = "Enforcing" ]; then
        AuditAdd "selinux" "OK" "SELinux Enforcing" ""
    else
        AuditAdd "selinux" "MEDIUM" "SELinux ${mode:-unknown} — 강제 모드가 아님" \
            "원인 확인(ausearch -m avc) 후 /etc/selinux/config SELINUX=enforcing"
    fi
}

#===============================================================================
# FUNCTION    : AuditPorts
# DESCRIPTION : 루프백이 아닌 주소에서 리스닝 중인 포트 목록 (외부 노출면)
#===============================================================================
AuditPorts() {
    local exposed

    command -v ss >/dev/null 2>&1 || return 0
    exposed=$(ss -tulnH 2>/dev/null \
        | awk '{ print $1, $5 }' \
        | grep -vE ' (127\.[0-9.]+|\[::1\]|::1)(%[a-z0-9]+)?:' \
        | awk '{ n = split($2, a, ":"); print $1 "/" a[n] }' | sort -u | tr '\n' ' ') || exposed=""
    if [ -n "${exposed}" ]; then
        AuditAdd "ports" "INFO" "외부 주소 리스닝: ${exposed}" "불필요한 서비스는 sudo systemctl disable --now <서비스>, 필요한 것은 firewalld 로 제한"
    else
        AuditAdd "ports" "OK" "외부 주소 리스닝 포트 없음" ""
    fi
}

#===============================================================================
# FUNCTION    : AuditLynis
# DESCRIPTION : Lynis 시스템 하드닝 감사 (--full). 비특권 실행 — 결과는 날짜별 보존
#===============================================================================
AuditLynis() {
    local report
    local index
    local warnings

    report="${AUDIT_DIR}/lynis-$(date +%F).dat"
    EnsureAuditDir
    if ! command -v lynis >/dev/null 2>&1; then
        AuditAdd "lynis-missing" "INFO" "Lynis 미설치 — 시스템 하드닝 종합 감사 생략" "arachne -t --group security"
        return 0
    fi
    # 비특권 실행은 --pentest 로 권한 검사를 생략한다 (root 전용 항목은 건너뜀)
    RunWithTimeout 900 lynis audit system --quick --no-colors --pentest --report-file "${report}" \
        --logfile "${AUDIT_DIR}/lynis.log" >/dev/null 2>&1 </dev/null || true
    index=$(awk -F= '$1 == "hardening_index" { print $2 }' "${report}" 2>/dev/null || true)
    warnings=$(grep -c '^warning\[\]=' "${report}" 2>/dev/null || true)
    if [ -z "${index}" ]; then
        AuditAdd "lynis" "INFO" "Lynis 결과를 읽지 못함 (${report})" "sudo lynis audit system 으로 직접 실행"
        return 0
    fi
    if [ "${warnings:-0}" -gt 0 ]; then
        AuditAdd "lynis-warnings" "MEDIUM" "Lynis 경고 ${warnings}건 · 하드닝 지수 ${index}" "grep '^warning' ${report}"
    fi
    AuditAdd "lynis-index" "INFO" "Lynis 하드닝 지수 ${index} (권고: grep '^suggestion' ${report})" ""
}

#===============================================================================
# FUNCTION    : AuditProjectDeps
# DESCRIPTION : 프로젝트 의존성 취약점 (--full) — 설치된 스캐너만 사용
#===============================================================================
AuditProjectDeps() {
    local dir="${TOOLS_PROJECT_DIR}"
    local high

    [ -n "${dir}" ] && [ -d "${dir}" ] || return 0
    if command -v trivy >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        high=$(RunWithTimeout 900 trivy fs --quiet --scanners vuln --severity HIGH,CRITICAL --format json "${dir}" 2>/dev/null </dev/null \
            | jq '[.Results[]?.Vulnerabilities[]?] | length' 2>/dev/null || echo "")
        if [ -n "${high}" ] && [ "${high}" -gt 0 ]; then
            AuditAdd "deps-trivy" "HIGH" "프로젝트 의존성 HIGH·CRITICAL 취약점 ${high}건 (${dir})" \
                "trivy fs --severity HIGH,CRITICAL ${dir}"
        fi
    fi
    if [ -f "${dir}/go.mod" ] && command -v govulncheck >/dev/null 2>&1; then
        local vuln_rc=0
        (cd "${dir}" && RunWithTimeout 600 govulncheck ./... >/dev/null 2>&1 </dev/null) || vuln_rc=$?
        case "${vuln_rc}" in
            0) ;;
            3) AuditAdd "deps-govulncheck" "HIGH" "govulncheck 가 호출 경로상 취약점을 보고 (${dir})" "cd ${dir} && govulncheck ./..." ;;
            *) AuditAdd "deps-govulncheck-err" "INFO" "govulncheck 실행 실패 (rc=${vuln_rc}) — 빌드·네트워크 확인" "cd ${dir} && govulncheck ./..." ;;
        esac
    fi
}

#===============================================================================
# FUNCTION    : AuditBinaries
# DESCRIPTION : ELF 결과물의 하드닝 플래그 검증 (annocheck). FORTIFY_SOURCE ·
#               stack-protector · stack-clash · CET · PIE · RELRO/BIND_NOW 누락 탐지
# PARAMETERS  : 나머지 인자 - 검사할 바이너리 경로
#===============================================================================
AuditBinaries() {
    local bin
    local out

    [ "$#" -gt 0 ] || return 0
    if ! command -v annocheck >/dev/null 2>&1; then
        AuditAdd "annocheck-missing" "INFO" "annocheck 미설치 — 바이너리 하드닝 검증 생략" "arachne -t --group security"
        return 0
    fi
    for bin in "$@"; do
        if [ ! -f "${bin}" ]; then
            AuditAdd "bin-$(basename "${bin}")" "INFO" "바이너리 없음: ${bin}" ""
            continue
        fi
        out=$(annocheck "${bin}" 2>&1 </dev/null) && {
            AuditAdd "bin-$(basename "${bin}")" "OK" "${bin}: 하드닝 플래그 통과" ""
            continue
        }
        AuditAdd "bin-$(basename "${bin}")" "HIGH" \
            "${bin}: 하드닝 누락 — $(printf '%s\n' "${out}" | grep -E 'FAIL' | sed -E 's/.*FAIL: ([A-Za-z0-9_-]+).*/\1/' | sort -u | head -8 | tr '\n' ' ')" \
            "CFLAGS 에 rules/c/security.md '빌드 하드닝 플래그' 적용 후 재빌드"
    done
}

#===============================================================================
# FUNCTION    : AuditReport
# DESCRIPTION : 결과 출력 — 심각도 순, 직전 결과에 없던 항목은 [NEW]. 결과 저장.
# PARAMETERS  : int persist - 1이면 기준선·요약 저장 (--binary 는 0 — 머신 기준선 보존)
# RETURNED    : 0(HIGH 이상 없음) / 1(CRITICAL·HIGH 있음)
#===============================================================================
AuditReport() {
    local persist="${1:-1}"
    local previous=""
    local sev
    local id
    local severity
    local message
    local fix
    local mark
    local high_count=0
    local medium_count=0

    [ -f "${AUDIT_LATEST}" ] && previous=$(cut -f1,2 "${AUDIT_LATEST}")
    ArachneSection "점검 결과 (직전 대비 새 항목은 [NEW])"
    for sev in CRITICAL HIGH MEDIUM LOW INFO OK; do
        while IFS=$'\t' read -r id severity message fix; do
            [ "${severity}" = "${sev}" ] || continue
            mark=""
            if [ -n "${previous}" ] && [ "${sev}" != "OK" ] && [ "${sev}" != "INFO" ] \
                && ! printf '%s\n' "${previous}" | grep -qxF "${id}	${severity}"; then
                mark="[NEW] "
            fi
            printf '  %-8s %s%s\n' "${sev}" "${mark}" "${message}"
            [ -n "${fix}" ] && [ "${sev}" != "OK" ] && printf '           └ 조치: %s\n' "${fix}"
            case "${sev}" in
                CRITICAL|HIGH) high_count=$((high_count + 1)) ;;
                MEDIUM)        medium_count=$((medium_count + 1)) ;;
            esac
        done <<< "${AUDIT_FINDINGS}"
    done

    if [ "${persist}" -eq 1 ]; then
        EnsureAuditDir
        printf '%s' "${AUDIT_FINDINGS}" > "${AUDIT_LATEST}"
        printf '# %s high=%s medium=%s\n' "$(date +%s)" "${high_count}" "${medium_count}" > "${AUDIT_DIR}/summary"
    fi

    if [ "${high_count}" -gt 0 ]; then
        ArachneLog "WARN" "audit: CRITICAL·HIGH ${high_count}건 · MEDIUM ${medium_count}건 — 자동 수정 없음, 위 조치를 검토하세요"
        return 1
    fi
    ArachneLog "OK" "audit: CRITICAL·HIGH 없음 (MEDIUM ${medium_count}건)"
    return 0
}

#===============================================================================
# FUNCTION    : AuditUsage
# DESCRIPTION : arachne --audit 사용법
#===============================================================================
AuditUsage() {
    echo "Usage: arachne -a|--audit [--full] [--project DIR] [--binary FILE...]"
    echo ""
    echo "  읽기 전용 보안 점검 — 수정은 하지 않고 조치 명령만 안내한다."
    echo "  기본    OS 보안 업데이트 · 재부팅/재시작 필요 · CPU 취약점 · sysctl 하드닝 · SELinux · 리스닝 포트"
    echo "  --full  + Lynis 하드닝 감사, 프로젝트 의존성(trivy·govulncheck — 설치된 것만)"
    echo "  --binary FILE...  빌드 결과물 하드닝 플래그 검증 (annocheck)"
    echo "  결과: ~/.claude/arachne/audit/latest.tsv (직전 대비 [NEW] 표시) · 종료코드 1 = CRITICAL·HIGH 존재"
}

#===============================================================================
# FUNCTION    : AuditCommand
# DESCRIPTION : arachne --audit 진입점
# PARAMETERS  : 나머지 인자 - --full · --project DIR · --binary FILE...
# RETURNED    : AuditReport 의 결과
#===============================================================================
AuditCommand() {
    AUDIT_FINDINGS=""
    AUDIT_FULL=0
    AUDIT_BINARIES=()
    TOOLS_PROJECT_DIR=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --full)       AUDIT_FULL=1 ;;
            --project)    shift || true; TOOLS_PROJECT_DIR="${1:-}" ;;
            --project=*)  TOOLS_PROJECT_DIR="${1#--project=}" ;;
            --binary)
                shift || true
                while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do
                    AUDIT_BINARIES+=("$1")
                    shift
                done
                if [ "${#AUDIT_BINARIES[@]}" -eq 0 ]; then
                    ArachneLog "ERROR" "audit: --binary 뒤에 검사할 파일이 필요합니다"
                    return 2
                fi
                continue
                ;;
            -h|--help)    AuditUsage; return 0 ;;
            *)            ArachneLog "ERROR" "audit: 알 수 없는 인자 '$1'"; AuditUsage >&2; return 2 ;;
        esac
        shift || true
    done
    [ -n "${TOOLS_PROJECT_DIR}" ] || TOOLS_PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || true)

    DetectToolsPlatform
    ArachneSection "보안 점검 (읽기 전용 · $(uname -r) · ${TOOLS_OS_ID})"

    if [ "${#AUDIT_BINARIES[@]}" -gt 0 ]; then
        AuditBinaries "${AUDIT_BINARIES[@]}"
        AuditReport 0
        return $?
    else
        AuditOsSecurity
        AuditReboot
        AuditCpu "${ARACHNE_AUDIT_CPU_DIR:-}"
        AuditSysctl
        AuditSelinux
        AuditPorts
        if [ "${AUDIT_FULL}" -eq 1 ]; then
            AuditLynis
            AuditProjectDeps
        fi
    fi
    AuditReport
}
