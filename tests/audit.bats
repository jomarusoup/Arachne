#!/usr/bin/env bats
################################################################################
# FILE NAME   : audit.bats
# DESCRIPTION : arachne --audit (lib/audit.sh) 읽기 전용 보안 점검 검증.
#               실제 시스템 대신 스텁(dnf·annocheck)과 가짜 sysfs 로 판정을 고정한다.
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    TMP_DIR=$(mktemp -d)
    export HOME="${TMP_DIR}"
    STUB="${TMP_DIR}/bin"
    mkdir -p "${STUB}"
    ArachneLog() { printf '[Arachne][%s] %s\n' "$1" "$2"; }
    ArachneSection() { printf '[Arachne] %s\n' "$1"; }
    # shellcheck source=/dev/null
    source "${REPO_DIR}/lib/toolchain.sh"
    # shellcheck source=/dev/null
    source "${REPO_DIR}/lib/toolchain-update.sh"
    # shellcheck source=/dev/null
    source "${REPO_DIR}/lib/audit.sh"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#===============================================================================
# FUNCTION    : make_stub
# DESCRIPTION : STUB 디렉터리에 실행 스크립트 생성
# PARAMETERS  : string name - 명령 이름
#               string body - 스크립트 본문
#===============================================================================
make_stub() {
    printf '#!/bin/bash\n%s\n' "$2" > "${STUB}/$1"
    chmod +x "${STUB}/$1"
}

@test "AuditOsSecurity: C 로캘 updateinfo 를 공지 ID 단위로 심각도별 집계" {
    make_stub dnf 'cat <<EOF
RLSA-2026:1 Critical/Sec. ca-certificates-2026.1-1.el9.noarch
RLSA-2026:2 Important/Sec. acl-2.3.1-5.el9.x86_64
RLSA-2026:2 Important/Sec. libacl-2.3.1-5.el9.x86_64
RLSA-2026:3 Important/Sec. bubblewrap-0.4.1-8.el9.x86_64
EOF'
    PATH="${STUB}:${PATH}"
    TOOLS_PM=dnf
    AuditOsSecurity
    [[ "${AUDIT_FINDINGS}" == *"os-security-Critical	CRITICAL	OS 보안 공지 미적용 1건"* ]] || false
    [[ "${AUDIT_FINDINGS}" == *"os-security-Important	HIGH	OS 보안 공지 미적용 2건"* ]] || false
}

@test "AuditOsSecurity: 거절된 GPG 키 가져오기는 저장소 오류로 보고, OK 로 숨기지 않음" {
    make_stub dnf 'printf "Importing GPG key 0xABCD1234:\n Userid     : \"Example Repo <x@y>\"\n" >&2; exit 0'
    PATH="${STUB}:${PATH}"
    TOOLS_PM=dnf
    AuditOsSecurity
    [[ "${AUDIT_FINDINGS}" == *"repo-errors	MEDIUM"*"GPG키 0xABCD1234"* ]] || false
}

@test "AuditOsSecurity: 조회 실패는 MEDIUM 으로 보고" {
    make_stub dnf 'exit 1'
    PATH="${STUB}:${PATH}"
    TOOLS_PM=dnf
    AuditOsSecurity
    [[ "${AUDIT_FINDINGS}" == *"os-security-query	MEDIUM"* ]] || false
}

@test "AuditCpu: Vulnerable 은 HIGH, 완화·해당없음만 있으면 OK" {
    mkdir -p "${TMP_DIR}/vuln"
    echo "Mitigation: PTI" > "${TMP_DIR}/vuln/meltdown"
    echo "Not affected" > "${TMP_DIR}/vuln/l1tf"
    AuditCpu "${TMP_DIR}/vuln"
    [[ "${AUDIT_FINDINGS}" == *"cpu	OK"* ]] || false
    AUDIT_FINDINGS=""
    echo "Vulnerable: Clear CPU buffers attempted, no microcode" > "${TMP_DIR}/vuln/mds"
    AuditCpu "${TMP_DIR}/vuln"
    [[ "${AUDIT_FINDINGS}" == *"cpu-mds	HIGH"* ]] || false
}

@test "AuditReport: 직전에 없던 항목만 [NEW], HIGH 있으면 종료코드 1, 결과 저장" {
    AuditAdd "a" "HIGH" "첫 발견" "조치"
    run AuditReport
    [ "$status" -eq 1 ]
    [ -f "${HOME}/.claude/arachne/audit/latest.tsv" ]
    AUDIT_FINDINGS=""
    AuditAdd "a" "HIGH" "첫 발견" "조치"
    AuditAdd "b" "MEDIUM" "새 발견" ""
    run AuditReport
    [[ "$output" == *"HIGH     첫 발견"* ]] || false
    [[ "$output" == *"MEDIUM   [NEW] 새 발견"* ]] || false
    grep -q 'high=1' "${HOME}/.claude/arachne/audit/summary"
}

@test "AuditBinaries: annocheck FAIL 항목을 HIGH 로, 통과는 OK" {
    make_stub annocheck 'if [ "$1" = "${PWD}/good" ] || [ "$(basename "$1")" = good ]; then exit 0; fi
echo "Hardened: $1: FAIL: fortify test because no -D_FORTIFY_SOURCE"
echo "Hardened: $1: FAIL: bind-now test because not linked with -z now"
exit 1'
    touch "${TMP_DIR}/good" "${TMP_DIR}/bad"
    PATH="${STUB}:${PATH}"
    AuditBinaries "${TMP_DIR}/good" "${TMP_DIR}/bad"
    [[ "${AUDIT_FINDINGS}" == *"bin-good	OK"* ]] || false
    [[ "${AUDIT_FINDINGS}" == *"bin-bad	HIGH"*"bind-now fortify"* ]] || false
}

@test "audit CLI: 도움말·알 수 없는 인자" {
    run bash "${REPO_DIR}/install.sh" --audit --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"읽기 전용 보안 점검"* ]] || false
    run bash "${REPO_DIR}/install.sh" -a --bogus
    [ "$status" -eq 2 ]
}

@test "session-start: 저장된 점검에 HIGH 가 있으면 한 줄 안내, 최근·무결점이면 침묵" {
    mkdir -p "${HOME}/.claude/arachne/audit"
    printf '# %s high=3 medium=1\n' "$(date +%s)" > "${HOME}/.claude/arachne/audit/summary"
    run bash "${REPO_DIR}/hooks/session-start.sh"
    [[ "$output" == *"[보안 점검] CRITICAL·HIGH 3건"* ]] || false
    printf '# %s high=0 medium=0\n' "$(date +%s)" > "${HOME}/.claude/arachne/audit/summary"
    run bash "${REPO_DIR}/hooks/session-start.sh"
    [ -z "$output" ]
    printf '# %s high=0 medium=0\n' "$(( $(date +%s) - 9 * 86400 ))" > "${HOME}/.claude/arachne/audit/summary"
    run bash "${REPO_DIR}/hooks/session-start.sh"
    [[ "$output" == *"마지막 점검 9일 전"* ]] || false
}

#-------------------------------------------------------------------------------
# 리뷰 후속 회귀 — 점 없는 버전, 연속 되돌리기
#-------------------------------------------------------------------------------
@test "VersionLevel: 점 없는 버전도 올바르게 비교" {
    [ "$(VersionLevel 7 7.1)" = "minor" ]
    [ "$(VersionLevel 3 3.0.1)" = "patch" ]
    VersionMatches 2.4.1 stable
}

@test "rollback: 되돌리기 기록 줄은 다음 되돌리기 근거에서 제외" {
    mkdir -p "${HOME}/.claude/arachne"
    printf '%s\n' \
        "2026-11-14 10:00:00	staticcheck	v0.7.0	v0.8.2	go:honnef.co/go/tools/cmd/staticcheck@latest" \
        "2026-11-14 11:00:00	staticcheck	v0.8.2	v0.7.0	rollback:go:honnef.co/go/tools/cmd/staticcheck@latest" \
        > "${HOME}/.claude/arachne/toolchain-history.log"
    ARACHNE_TOOLS_DRYRUN=1 run bash "${REPO_DIR}/install.sh" -t --rollback staticcheck
    [ "$status" -eq 0 ]
    [[ "$output" == *"staticcheck@v0.7.0"* ]] || false
    [[ "$output" != *"@rollback"* ]] || false
}

@test "audit --binary: 머신 기준선·요약을 덮어쓰지 않음, 파일 없으면 사용법 오류" {
    mkdir -p "${HOME}/.claude/arachne/audit"
    printf '# 1 high=2 medium=0\n' > "${HOME}/.claude/arachne/audit/summary"
    make_stub annocheck 'exit 0'
    touch "${TMP_DIR}/app"
    PATH="${STUB}:${PATH}" run bash "${REPO_DIR}/install.sh" -a --binary "${TMP_DIR}/app"
    [ "$status" -eq 0 ]
    grep -q 'high=2' "${HOME}/.claude/arachne/audit/summary"
    run bash "${REPO_DIR}/install.sh" -a --binary
    [ "$status" -eq 2 ]
}

@test "AuditSysctl: 읽을 수 있는 키가 없으면 OK 대신 INFO" {
    sysctl() { return 1; }
    cat() { return 1; }
    AuditSysctl
    [[ "${AUDIT_FINDINGS}" == *"sysctl-na	INFO"* ]] || false
    [[ "${AUDIT_FINDINGS}" != *"sysctl	OK"* ]] || false
}

@test "AuditSysctl: 미달 항목은 한 파일을 통째로 쓰는 일괄 조치 (재실행해도 중복 없음)" {
    sysctl() { echo 0; }
    AuditSysctl
    [[ "${AUDIT_FINDINGS}" == *"sysctl-kernel.randomize_va_space	MEDIUM"* ]] || false
    printf '%s' "${AUDIT_FINDINGS}" | grep '^sysctl-fix' | grep -q 'sudo tee /etc/sysctl.d/90-arachne.conf >/dev/null'
    printf '%s' "${AUDIT_FINDINGS}" | grep '^sysctl-fix' | grep -vq 'tee -a'
    # suid_dumpable 0 은 허용값 — 미달로 잡지 않음
    [[ "${AUDIT_FINDINGS}" != *"sysctl-fs.suid_dumpable"* ]] || false
}

@test "session-start: 손상된 요약은 무시" {
    mkdir -p "${HOME}/.claude/arachne/audit"
    printf '# abc high=\n' > "${HOME}/.claude/arachne/audit/summary"
    run bash "${REPO_DIR}/hooks/session-start.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
