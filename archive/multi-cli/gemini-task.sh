#!/bin/bash
################################################################################
# FILE NAME   : gemini-task.sh
# DESCRIPTION : Gemini CLI 작업 위임 래퍼 (gemini-task / 짧은 별칭 gtask) —
#               Claude Code가 별도 터미널 전환 없이 직접 호출해 설계·조사·요약을
#               Gemini(reader/advisor 레인)에 위임하고 깨끗한 답변만 받는다.
#               (gemini -p 의 경고/노이즈를 걸러 stdout 오염 방지)
# DATA        : 2026-06-04
# Modification: 2026-06-08
################################################################################

set -euo pipefail

#-------------------------------------------------------------------------------
# gemini CLI 가 stderr 로 뱉는 비본질 노이즈 — Claude 컨텍스트 오염 방지용 필터
#-------------------------------------------------------------------------------
readonly NOISE_PATTERN='True color|Ripgrep is not available|^Warning:|^Loaded|^Data collection'

#--- METRICS-BLOCK-BEGIN (동기화 필수 — codex-task.sh/gemini-task.sh/arachne-task.sh 3파일 동일, tests/metrics.bats 가 검증) ---
#-------------------------------------------------------------------------------
# 계측(ADR-0003 기준선 수집): 래퍼 호출·쿨다운 진입을 append-only 로 남긴다.
# 관찰 전용 — 이 로그를 읽고 동작을 결정하는 코드는 없다(경합 영향 반경 격리).
# 동시 쓰기 안전성은 flock 없이 O_APPEND + 단일 write 로 보장한다:
#   '>>' 는 O_APPEND 로 열려 오프셋 이동·쓰기가 원자적으로 파일 끝에 붙고(유실 없음),
#   한 줄(~60B)을 printf 1회 = write(2) 1회로 방출하므로 PIPE_BUF 하한(512B)보다
#   작아 로컬 파일시스템에서 라인이 분할·교차되지 않는다. 한계: NFS 는 O_APPEND
#   원자성이 보장되지 않음(대상 경로 $HOME/.claude 는 로컬 전제).
#   flock(1) 은 macOS(BSD)·Git Bash 에 명령이 없어 도입하지 않는다.
# 실패는 전부 무시한다 — 계측이 본작업(위임·폴백)을 막지 않는다.
#-------------------------------------------------------------------------------
readonly METRICS_DIR="${ARACHNE_STATE_DIR:-$HOME/.claude}/metrics"

#===============================================================================
# FUNCTION    : MetricAppend
# DESCRIPTION : 계측 이벤트 1줄 append — 실패 무시, 호출측 종료코드 불오염
# PARAMETERS  : string kind - call(래퍼 호출) / cooldown(쿨다운 진입)
#               call:     $2 wrapper  $3 lane  $4 mode(suggest|write)  $5 rc
#               cooldown: $2 cli      $3 lane
#===============================================================================
MetricAppend() {
    {
        local kind="$1"
        local ts
        local month
        local line
        local file
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        month="${ts:0:7}"
        if [ "${kind}" = "call" ]; then
            file="${METRICS_DIR}/wrapper-calls-${month}.log"
            line=$(printf '%s\t%s\t%s\t%s\t%s\t%s' "${ts}" "$2" "$3" "$4" "$5" "$$")
        else
            file="${METRICS_DIR}/cooldown-entries-${month}.log"
            line=$(printf '%s\t%s\t%s\t%s' "${ts}" "$2" "$3" "$$")
        fi
        mkdir -p "${METRICS_DIR}"
        # 보존 90일(기준선 4주 + 여유) — 월 파일 단위 삭제라 B-11 식 덮어쓰기 없음
        find "${METRICS_DIR}" -name '*.log' -mtime +90 -delete
        # 한 줄 전체를 printf 1회로 방출 — 원자성 근거는 블록 상단 주석
        printf '%s\n' "${line}" >> "${file}"
    } 2>/dev/null || true
}
#--- METRICS-BLOCK-END ---

#===============================================================================
# FUNCTION    : Usage
# DESCRIPTION : 사용법 출력 후 지정 코드로 종료
# PARAMETERS  : int code - 종료 코드 (기본 0)
#===============================================================================
Usage() {
    cat >&2 << 'USAGE'
Usage: gemini-task [-m MODEL] "프롬프트..."   (짧은 별칭: gtask)
       cat file | gtask "이 입력을 요약해줘"

  Gemini CLI 비대화(headless) 작업 위임 래퍼. 답변만 stdout 으로 출력한다.
  레인: reader/advisor — 대용량 읽기·요약·설계 탐색·1차 리뷰 (구현은 위임 안 함).

Options:
  -m MODEL   사용할 Gemini 모델 (미지정 시 gemini 기본값 / 환경변수 GTASK_MODEL)
  -h         이 도움말 출력

Security:
  - reader/advisor(읽기 전용)라 파일을 쓰지 않지만, 신뢰할 수 없는 콘텐츠를 요약·자문에
    직접 넣으면 답변이 조종될 수 있다(간접 프롬프트 인젝션). 외부 로그·이슈·웹은
    "<<UNTRUSTED ... UNTRUSTED>>" 같은 구획에 담아 데이터임을 표시하고, 받은 답변은
    Claude가 검토 후 사용한다(특히 링크·명령은 그대로 실행 금지).

Examples:
  gtask "이 함수 설계 검토해줘: $(cat module.c)"   # 자문 → 답변 stdout
  gtask "이 로그 에러 원인만 요약: $(cat app.log)" # 요약 → 답변 stdout
  gtask "README 초안 작성" > README.md             # 생성 → 파일로 (내용 재독 금지)
USAGE
    exit "${1:-0}"
}

#-------------------------------------------------------------------------------
# 인자 파싱
#-------------------------------------------------------------------------------
model="${GTASK_MODEL:-}"

while getopts ":m:h" opt; do
    case "${opt}" in
        m)  model="${OPTARG}" ;;
        h)  Usage 0 ;;
        :)  echo "[gtask] -${OPTARG} 옵션은 값이 필요합니다" >&2; Usage 1 ;;
        \?) echo "[gtask] 알 수 없는 옵션: -${OPTARG}" >&2; Usage 1 ;;
    esac
done
shift $((OPTIND - 1))

prompt="$*"
if [ -z "${prompt}" ]; then
    echo "[gtask] 프롬프트가 비어 있습니다" >&2
    Usage 1
fi

#-------------------------------------------------------------------------------
# 솔로 모드 가드 — Gemini CLI 미설치 환경(Claude 단독)에서는 위임 불가를 명확히
# 알리고 127 로 종료한다. atask 는 127 을 쿨다운 없이 다음 후보로 건너뛴다.
#-------------------------------------------------------------------------------
if ! command -v gemini >/dev/null 2>&1; then
    echo "[gtask] Gemini CLI 미설치 — reader/advisor 위임 불가." >&2
    echo "        Claude가 직접 수행하거나, 설치 후 'arachne -i --target gemini' 로 연결하세요." >&2
    MetricAppend call gemini-task read suggest 127
    exit 127
fi

#-------------------------------------------------------------------------------
# gemini 호출 — 답변은 stdout, 노이즈 걸러낸 진단은 stderr
#   (stdin 으로 들어온 입력은 gemini 가 프롬프트에 자동 append)
#-------------------------------------------------------------------------------
# --skip-trust: 헤드리스 호출이라 임의 디렉터리(신뢰 미설정)에서도 동작해야 함.
# 미전달 시 신뢰 안 된 cwd 에서 gemini 가 거부 → 빈 응답. (공식 headless 권장값)
cmd=(gemini --skip-trust -p "${prompt}")
if [ -n "${model}" ]; then
    cmd=(gemini --skip-trust -m "${model}" -p "${prompt}")
fi

err_file=$(mktemp)
# rc=$? 를 첫 문장으로 캡처하고 이후 모든 명령을 실패 무시로 두어, 트랩이 래퍼의
# 종료코드를 오염시키지 않는다 (atask 가 이 값으로 폴백을 판정 — tests/metrics.bats T5)
trap 'rc=$?; MetricAppend call gemini-task read suggest "${rc}"; rm -f "${err_file}" 2>/dev/null || true' EXIT

status=0
"${cmd[@]}" 2> "${err_file}" || status=$?

grep -vE "${NOISE_PATTERN}" "${err_file}" >&2 || true

exit "${status}"
