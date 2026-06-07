#!/bin/bash
################################################################################
# FILE NAME   : atask-quota-warn.sh
# DESCRIPTION : 프롬프트 입력 시 atask 쿼터 상태를 확인해 사전 경고 —
#               쿨다운(소진) 중인 CLI가 있으면 impl 순서의 첫 가용 후보와 회복 시각을 알린다.
#               atask 의 상태 파일(arachne-quota-state)을 읽기만 한다(부작용 없음).
# DATA        : 2026-06-07
# Modification: 2026-06-07
################################################################################

# 훅은 자동 실행 경로라 -e 제외 (실패해도 세션을 막지 않음)
set -uo pipefail

STATE_FILE="${ARACHNE_STATE_DIR:-$HOME/.claude}/arachne-quota-state"
[ -f "${STATE_FILE}" ] || exit 0

now=$(date +%s)

#-------------------------------------------------------------------------------
# 쿨다운 중인 CLI 수집 (만료 시각이 현재보다 미래인 항목)
#-------------------------------------------------------------------------------
cooldown_msg=""
in_cooldown_claude=0
in_cooldown_codex=0
in_cooldown_gemini=0

while IFS=$'\t' read -r cli until; do
    [ -z "${cli:-}" ] && continue
    [ -z "${until:-}" ] && continue
    if [ "${now}" -lt "${until}" ]; then
        recover=$(date -d "@${until}" '+%H:%M' 2>/dev/null || echo '?')
        cooldown_msg="${cooldown_msg}  - ${cli} : 쿨다운 (회복 ~${recover})\n"
        case "${cli}" in
            claude) in_cooldown_claude=1 ;;
            codex)  in_cooldown_codex=1 ;;
            gemini) in_cooldown_gemini=1 ;;
        esac
    fi
done < "${STATE_FILE}"

# 쿨다운 항목이 없으면 조용히 종료
[ -z "${cooldown_msg}" ] && exit 0

#-------------------------------------------------------------------------------
# impl 실행 후보 판정 — 순서(claude→codex→gemini)에서 첫 가용 CLI
#-------------------------------------------------------------------------------
if [ "${in_cooldown_claude}" -eq 0 ]; then
    candidate="Claude (정상)"
elif [ "${in_cooldown_codex}" -eq 0 ]; then
    candidate="Codex wrapper (Claude 소진, tester/fixer 제약)"
elif [ "${in_cooldown_gemini}" -eq 0 ]; then
    candidate="Gemini wrapper (Claude+Codex 소진, reader/advisor 제약)"
else
    candidate="없음 (전 CLI 소진, 회복 대기)"
fi

echo "┌───────────────────────────────────────────────────────────────────────────────"
echo "│  [atask 쿼터 경고] 사용량 소진 CLI 감지"
echo -e "${cooldown_msg%\\n}"
echo "│  impl 첫 가용 후보: ${candidate}"
echo "│  → 후보 변경은 역할·커밋 권한 승계가 아님. 결과 검증 또는 /handoff 필요."
echo "└───────────────────────────────────────────────────────────────────────────────"

exit 0
