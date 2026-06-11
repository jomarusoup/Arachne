#!/bin/bash
################################################################################
# FILE NAME   : arachne-task.sh
# DESCRIPTION : 자동 폴백 캐스케이드 디스패처 (arachne-task / 짧은 별칭 atask) —
#               역할별 우선순위 사슬을 따라 CLI를 시도하고, 쿼터 소진(rate limit)을
#               감지하면 다음 CLI로 자동 전환한다. 소진된 CLI는 쿨다운 동안 건너뛴다.
#                 impl  : claude → codex → gemini  (실행 후보 폴백; 하위 래퍼 역할 유지)
#                 read  : gemini → codex → claude  (비용 오프로드)
#                 test  : codex  → claude → gemini (검증 우선)
#                 review: gemini → codex → claude  (저비용 1차 리뷰)
#               헤드리스 호출 전용. 대화형 세션 중간 구제는 못 한다(README 참고).
# DATA        : 2026-06-07
# Modification: 2026-06-08
################################################################################

set -euo pipefail

#-------------------------------------------------------------------------------
# 쿼터·rate limit 소진으로 판단할 출력 패턴. 이 패턴이면 폴백, 아니면 일반 에러로
# 보고 후 중단(잘못된 입력까지 폴백하면 세 CLI 토큰을 낭비하므로 구분한다).
# 오판 방지(#31): bare 'quota'·'429' 대신 API 소진 신호에 가까운 표현만 매칭하고,
# 명백한 일반 오류(NON_QUOTA)는 쿼터 토큰이 섞여 있어도 폴백에서 제외한다.
#-------------------------------------------------------------------------------
readonly QUOTA_PATTERN='rate.?limit|rate_limit|usage limit reached|usage limit|429|too many requests|overloaded_error|overloaded|resource.?exhausted|RESOURCE_EXHAUSTED|insufficient_quota|quota exceeded|exceeded your[^.]{0,20}quota'

# 명백한 일반 오류 신호 — 위 패턴이 우연히 매칭돼도 쿼터 소진으로 보지 않는다.
# (예: "disk quota exceeded"는 API 쿼터가 아니라 디스크 문제)
readonly NON_QUOTA_PATTERN='syntax error|command not found|no such file|permission denied|parse error|compil|undefined reference|disk quota|inode|invalid argument'

#-------------------------------------------------------------------------------
# 상태 파일 — 소진된 CLI의 쿨다운 만료 시각(epoch)을 기록해 반복 재시도를 막는다.
# 형식(탭 구분): <cli>\t<cooldown_until_epoch>
#-------------------------------------------------------------------------------
readonly STATE_DIR="${ARACHNE_STATE_DIR:-$HOME/.claude}"
readonly STATE_FILE="${STATE_DIR}/arachne-quota-state"

# 쿨다운 기본값(초). Claude 쿼터 창은 길어 5h, 나머지는 1h. 환경변수로 조정.
readonly COOLDOWN_CLAUDE="${ATASK_COOLDOWN_CLAUDE:-18000}"
readonly COOLDOWN_DEFAULT="${ATASK_COOLDOWN_DEFAULT:-3600}"

#===============================================================================
# FUNCTION    : Usage
# DESCRIPTION : 사용법 출력 후 지정 코드로 종료
# PARAMETERS  : int code - 종료 코드 (기본 0)
#===============================================================================
Usage() {
    cat >&2 << 'USAGE'
Usage: arachne-task [-R ROLE] [-w] [--dry-run] "프롬프트..."   (짧은 별칭: atask)

  자동 폴백 캐스케이드 디스패처. 역할별 우선순위로 CLI를 시도하고,
  쿼터 소진을 감지하면 다음 CLI로 자동 전환한다. 결과만 stdout 으로 출력.

Roles (-R):
  impl     (기본) claude → codex → gemini   실행 후보 순서 (역할 자동 승계 아님)
  read            gemini → codex → claude   읽기·요약·자문 (비용 오프로드)
  test            codex  → claude → gemini  테스트·버그 수정
  review          gemini → codex → claude   저비용 1차 리뷰

Options:
  -R ROLE    캐스케이드 역할 (기본 impl)
  -w         codex 단계를 workspace-write 로 실행 (테스트 직접 수정)
  --dry-run  실제 호출 없이 해석된 순서·쿨다운 상태만 출력
  -h         이 도움말 출력

  ※ 모델 지정 옵션은 없다(#32): 어느 CLI가 실행될지 미리 알 수 없어 단일 모델명이
     서로 다른 CLI 모델 공간을 혼합하기 때문. CLI별 모델은 각 래퍼의 환경변수로 지정한다
     (Gemini=GTASK_MODEL, Codex=CTASK_MODEL). 특정 모델이 꼭 필요하면 atask 대신
     해당 래퍼(gtask/ctask)를 직접 호출한다.

Examples:
  atask "결제 모듈 재시도 로직 구현"                 # impl: claude 먼저, 소진 시 제한된 래퍼 폴백
  atask -R read "이 로그 에러 원인 요약: $(cat app.log)"
  atask -R test -w "실패하는 test_auth 를 green 까지"
  atask --dry-run -R impl "..."                       # 순서·쿨다운만 확인

Env:
  ATASK_COOLDOWN_CLAUDE   Claude 쿨다운 초 (기본 18000=5h)
  ATASK_COOLDOWN_DEFAULT  그 외 CLI 쿨다운 초 (기본 3600=1h)
  ARACHNE_STATE_DIR       상태 파일 디렉터리 (기본 ~/.claude)
USAGE
    exit "${1:-0}"
}

#===============================================================================
# FUNCTION    : Warn
# DESCRIPTION : 진단 메시지를 stderr 로 출력 (stdout 결과 오염 방지)
# PARAMETERS  : string msg - 출력할 메시지
#===============================================================================
Warn() {
    echo "[atask] $*" >&2
}

#===============================================================================
# FUNCTION    : OrderForRole
# DESCRIPTION : 역할에 맞는 캐스케이드 순서(공백 구분)를 stdout 으로 반환
# PARAMETERS  : string role - impl | read | test | review
# RETURNED    : "cli1 cli2 cli3"
#===============================================================================
OrderForRole() {
    local role="$1"
    case "${role}" in
        impl)   echo "claude codex gemini" ;;
        read)   echo "gemini codex claude" ;;
        test)   echo "codex claude gemini" ;;
        review) echo "gemini codex claude" ;;
        *)      echo "" ;;
    esac
}

#===============================================================================
# FUNCTION    : CliBin
# DESCRIPTION : 논리적 CLI 이름을 실제 실행 명령으로 매핑
# PARAMETERS  : string cli - claude | codex | gemini
# RETURNED    : 실행 명령명
#===============================================================================
CliBin() {
    case "$1" in
        claude) echo "claude" ;;
        codex)  echo "codex-task" ;;
        gemini) echo "gemini-task" ;;
        *)      echo "" ;;
    esac
}

#===============================================================================
# FUNCTION    : CooldownSeconds
# DESCRIPTION : CLI별 쿨다운 기본 초를 반환
# PARAMETERS  : string cli - claude | codex | gemini
# RETURNED    : 초(int)
#===============================================================================
CooldownSeconds() {
    case "$1" in
        claude) echo "${COOLDOWN_CLAUDE}" ;;
        *)      echo "${COOLDOWN_DEFAULT}" ;;
    esac
}

#===============================================================================
# FUNCTION    : CooldownUntil
# DESCRIPTION : 상태 파일에서 해당 CLI의 쿨다운 만료 epoch 를 반환 (없으면 0)
# PARAMETERS  : string cli - 조회할 CLI
# RETURNED    : epoch(int) 또는 0
#===============================================================================
CooldownUntil() {
    local cli="$1"
    [ -f "${STATE_FILE}" ] || { echo 0; return; }
    local until
    until=$(grep -E "^${cli}	" "${STATE_FILE}" 2>/dev/null | head -1 | cut -f2)
    echo "${until:-0}"
}

#===============================================================================
# FUNCTION    : InCooldown
# DESCRIPTION : 현재 시각이 CLI의 쿨다운 만료 이전인지 검사
# PARAMETERS  : string cli - 검사할 CLI
# RETURNED    : 0(쿨다운 중) / 1(가용)
#===============================================================================
InCooldown() {
    local cli="$1"
    local until
    until=$(CooldownUntil "${cli}")
    [ "$(date +%s)" -lt "${until}" ]
}

#===============================================================================
# FUNCTION    : SetCooldown
# DESCRIPTION : CLI를 쿨다운 상태로 기록 (기존 항목은 교체)
# PARAMETERS  : string cli - 소진된 CLI
#===============================================================================
SetCooldown() {
    local cli="$1"
    local until
    until=$(( $(date +%s) + $(CooldownSeconds "${cli}") ))
    mkdir -p "${STATE_DIR}"
    local tmp
    tmp=$(mktemp)
    if [ -f "${STATE_FILE}" ]; then
        grep -vE "^${cli}	" "${STATE_FILE}" > "${tmp}" 2>/dev/null || true
    fi
    printf '%s\t%s\n' "${cli}" "${until}" >> "${tmp}"
    mv "${tmp}" "${STATE_FILE}"
}

#===============================================================================
# FUNCTION    : IsQuotaError
# DESCRIPTION : 두 출력 파일에서 쿼터·rate limit 패턴을 탐지
# PARAMETERS  : string out_file - stdout 캡처
#               string err_file - stderr 캡처
# RETURNED    : 0(쿼터 소진) / 1(아님)
#===============================================================================
IsQuotaError() {
    # 명백한 일반 오류면 쿼터로 보지 않는다 (#31 오판 방지)
    if grep -qiE "${NON_QUOTA_PATTERN}" "$1" "$2" 2>/dev/null; then
        return 1
    fi
    grep -qiE "${QUOTA_PATTERN}" "$1" "$2" 2>/dev/null
}

#===============================================================================
# FUNCTION    : FmtCooldown
# DESCRIPTION : 쿨다운 만료 epoch 를 플랫폼 무관한 상대 시간으로 표시 (#37)
#               GNU 전용 `date -d @N` 대신 epoch 차이를 분 단위로 환산한다.
# PARAMETERS  : int until - 만료 epoch
# RETURNED    : "~Nm" (N분 후) 또는 "now"
#===============================================================================
FmtCooldown() {
    local until="$1"
    local now diff
    now=$(date +%s)
    diff=$(( until - now ))
    if [ "${diff}" -le 0 ]; then
        echo "now"
    else
        echo "~$(( diff / 60 ))m"
    fi
}

#-------------------------------------------------------------------------------
# 인자 파싱 (--dry-run 은 getopts 전에 분리)
#-------------------------------------------------------------------------------
role="impl"
write_mode=0
dry_run=0

args=()
for arg in "$@"; do
    if [ "${arg}" = "--dry-run" ]; then
        dry_run=1
    else
        args+=("${arg}")
    fi
done
set -- "${args[@]:-}"

while getopts ":R:wh" opt; do
    case "${opt}" in
        R)  role="${OPTARG}" ;;
        w)  write_mode=1 ;;
        h)  Usage 0 ;;
        :)  echo "[atask] -${OPTARG} 옵션은 값이 필요합니다" >&2; Usage 1 ;;
        \?) echo "[atask] 알 수 없는 옵션: -${OPTARG} (모델 지정은 GTASK_MODEL/CTASK_MODEL 환경변수 사용)" >&2; Usage 1 ;;
    esac
done
shift $((OPTIND - 1))

order=$(OrderForRole "${role}")
if [ -z "${order}" ]; then
    echo "[atask] 알 수 없는 역할: ${role}" >&2
    Usage 1
fi

prompt="$*"

#-------------------------------------------------------------------------------
# --dry-run : 해석된 순서와 각 CLI의 가용/쿨다운 상태만 출력
#-------------------------------------------------------------------------------
if [ "${dry_run}" -eq 1 ]; then
    echo "role=${role}"
    echo "order=${order}"
    for cli in ${order}; do
        if InCooldown "${cli}"; then
            echo "  ${cli}: cooldown ($(FmtCooldown "$(CooldownUntil "${cli}")") 후 회복)"
        else
            echo "  ${cli}: available"
        fi
    done
    exit 0
fi

if [ -z "${prompt}" ]; then
    echo "[atask] 프롬프트가 비어 있습니다" >&2
    Usage 1
fi

#-------------------------------------------------------------------------------
# 캐스케이드 실행 — 가용 CLI를 순서대로 시도, 쿼터 소진 시 다음으로 폴백
#-------------------------------------------------------------------------------
out_file=$(mktemp)
err_file=$(mktemp)
trap 'rm -f "${out_file}" "${err_file}"' EXIT

for cli in ${order}; do
    bin=$(CliBin "${cli}")

    if ! command -v "${bin}" >/dev/null 2>&1; then
        Warn "skip ${cli} (미설치)"
        continue
    fi
    if InCooldown "${cli}"; then
        Warn "skip ${cli} (쿨다운 $(FmtCooldown "$(CooldownUntil "${cli}")") 후 회복)"
        continue
    fi

    Warn "시도: ${cli}"
    : > "${out_file}"
    : > "${err_file}"

    #---------------------------------------------------------------------------
    # CLI별 호출. codex/gemini 는 위임 래퍼(codex-task/gemini-task)를 통해 호출.
    #---------------------------------------------------------------------------
    # 모델은 각 래퍼의 환경변수(GTASK_MODEL/CTASK_MODEL)로 지정 — atask는 모델을 섞지 않는다(#32)
    rc=0
    case "${cli}" in
        claude)
            claude -p "${prompt}" > "${out_file}" 2> "${err_file}" || rc=$?
            ;;
        codex)
            codex_cmd=(codex-task)
            [ "${write_mode}" -eq 1 ] && codex_cmd+=(-w)
            codex_cmd+=("${prompt}")
            "${codex_cmd[@]}" > "${out_file}" 2> "${err_file}" || rc=$?
            ;;
        gemini)
            gemini-task "${prompt}" > "${out_file}" 2> "${err_file}" || rc=$?
            ;;
    esac

    if [ "${rc}" -eq 0 ]; then
        cat "${out_file}"
        Warn "처리 완료: ${cli}"
        #-----------------------------------------------------------------------
        # #26: impl 역할에서 claude 가 아닌 후보가 처리하면 역할·커밋 권한이
        # 자동 승계되지 않음을 경고한다. 하위 래퍼(codex-task/gemini-task)의
        # tester/reader 제약이 유지되며, 종료코드 0 이 구현 완료를 보장하지 않는다.
        #-----------------------------------------------------------------------
        if [ "${role}" = "impl" ] && [ "${cli}" != "claude" ]; then
            Warn "주의: ${cli}는 역할 제한(tester/reader) 래퍼로 실행됨 — 결과·diff를 사람이 검증하고"
            Warn "      커밋은 Claude가. 종료코드 0이 구현 완료를 보장하지 않음(역할·커밋 자동 승계 아님)."
        fi
        exit 0
    fi

    #---------------------------------------------------------------------------
    # 종료코드 127 = 하위 CLI 미설치(래퍼 솔로 모드 가드 또는 command not found).
    # 쿼터가 아니므로 쿨다운 없이 다음 후보로 건너뛴다 (Claude 단독 환경 지원).
    #---------------------------------------------------------------------------
    if [ "${rc}" -eq 127 ]; then
        Warn "skip ${cli} (하위 CLI 미설치)"
        continue
    fi

    if IsQuotaError "${out_file}" "${err_file}"; then
        SetCooldown "${cli}"
        Warn "${cli} 쿼터 소진 감지 → 쿨다운 등록, 다음으로 폴백"
        continue
    fi

    #---------------------------------------------------------------------------
    # 쿼터가 아닌 일반 에러 — 폴백하지 않고 그대로 보고 후 중단(토큰 낭비 방지)
    #---------------------------------------------------------------------------
    cat "${err_file}" >&2
    Warn "${cli} 실패(쿼터 아님, rc=${rc}) — 폴백 중단"
    exit "${rc}"
done

Warn "전 CLI 소진 또는 불가 — 쿼터 회복 대기 후 재시도하세요 (atask --dry-run 으로 상태 확인)"
exit 1
