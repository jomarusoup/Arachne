#!/bin/bash
################################################################################
# FILE NAME   : gemini-task.sh
# DESCRIPTION : Gemini CLI 작업 위임 래퍼 (gemini-task / 짧은 별칭 gask) —
#               Claude Code가 별도 터미널 전환 없이 직접 호출해 설계·조사·요약을
#               Gemini(reader/advisor 레인)에 위임하고 깨끗한 답변만 받는다.
#               (gemini -p 의 경고/노이즈를 걸러 stdout 오염 방지)
# DATA        : 2026-06-04
# Modification: 2026-06-06
################################################################################

set -euo pipefail

#-------------------------------------------------------------------------------
# gemini CLI 가 stderr 로 뱉는 비본질 노이즈 — Claude 컨텍스트 오염 방지용 필터
#-------------------------------------------------------------------------------
readonly NOISE_PATTERN='True color|Ripgrep is not available|^Warning:|^Loaded|^Data collection'

#===============================================================================
# FUNCTION    : Usage
# DESCRIPTION : 사용법 출력 후 지정 코드로 종료
# PARAMETERS  : int code - 종료 코드 (기본 0)
#===============================================================================
Usage() {
    cat >&2 << 'USAGE'
Usage: gemini-task [-m MODEL] "프롬프트..."   (짧은 별칭: gask)
       cat file | gask "이 입력을 요약해줘"

  Gemini CLI 비대화(headless) 작업 위임 래퍼. 답변만 stdout 으로 출력한다.
  레인: reader/advisor — 대용량 읽기·요약·설계 탐색·1차 리뷰 (구현은 위임 안 함).

Options:
  -m MODEL   사용할 Gemini 모델 (미지정 시 gemini 기본값 / 환경변수 GASK_MODEL)
  -h         이 도움말 출력

Examples:
  gask "이 함수 설계 검토해줘: $(cat module.c)"   # 자문 → 답변 stdout
  gask "이 로그 에러 원인만 요약: $(cat app.log)" # 요약 → 답변 stdout
  gask "README 초안 작성" > README.md             # 생성 → 파일로 (내용 재독 금지)
USAGE
    exit "${1:-0}"
}

#-------------------------------------------------------------------------------
# 인자 파싱
#-------------------------------------------------------------------------------
model="${GASK_MODEL:-}"

while getopts ":m:h" opt; do
    case "${opt}" in
        m)  model="${OPTARG}" ;;
        h)  Usage 0 ;;
        :)  echo "[gask] -${OPTARG} 옵션은 값이 필요합니다" >&2; Usage 1 ;;
        \?) echo "[gask] 알 수 없는 옵션: -${OPTARG}" >&2; Usage 1 ;;
    esac
done
shift $((OPTIND - 1))

prompt="$*"
if [ -z "${prompt}" ]; then
    echo "[gask] 프롬프트가 비어 있습니다" >&2
    Usage 1
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
trap 'rm -f "${err_file}"' EXIT

status=0
"${cmd[@]}" 2> "${err_file}" || status=$?

grep -vE "${NOISE_PATTERN}" "${err_file}" >&2 || true

exit "${status}"
