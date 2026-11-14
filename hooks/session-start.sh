#!/bin/bash
################################################################################
# FILE NAME   : session-start.sh
# DESCRIPTION : SessionStart Hook — 최근 세션 파일 경로 안내 + 마지막 보안 점검
#               (arachne --audit) 결과 한 줄 요약. 점검을 새로 실행하지 않고
#               저장된 요약만 읽는다 (세션 시작 지연 없음).
################################################################################

# 훅은 자동 실행·의도적 continue 경로라 -e 제외 (실패해도 세션을 막지 않음)
set -uo pipefail

SESSION_DIR="$HOME/.claude/sessions"
AUDIT_SUMMARY="$HOME/.claude/arachne/audit/summary"
AUDIT_STALE_DAYS=7

#===============================================================================
# FUNCTION    : PrintSessionHint
# DESCRIPTION : 최근 세션 파일 안내 (수동 저장 세션 우선, 없으면 auto 포함)
#===============================================================================
PrintSessionHint() {
    local latest

    [ -d "$SESSION_DIR" ] || return 0
    latest=$(ls -t "$SESSION_DIR"/[0-9]*.md 2>/dev/null | head -1)
    if [ -z "$latest" ]; then
        latest=$(ls -t "$SESSION_DIR"/*.md 2>/dev/null | head -1)
    fi
    [ -n "$latest" ] || return 0

    echo "┌───────────────────────────────────────────────────────────────────────────────"
    echo "│  [세션 이어받기] "
    echo "│  최근 세션: $(basename "$latest")"
    echo "│  → cat $latest"
    echo "└───────────────────────────────────────────────────────────────────────────────"
}

#===============================================================================
# FUNCTION    : PrintAuditHint
# DESCRIPTION : 저장된 보안 점검 요약에 HIGH 이상이 있거나 오래됐으면 한 줄 안내
#===============================================================================
PrintAuditHint() {
    local stamp
    local high
    local age_days

    [ -f "$AUDIT_SUMMARY" ] || return 0
    stamp=$(awk '{print $2}' "$AUDIT_SUMMARY" 2>/dev/null)
    high=$(sed -n 's/.*high=\([0-9]*\).*/\1/p' "$AUDIT_SUMMARY" 2>/dev/null)
    # 손상된 요약(숫자가 아닌 값)은 무시
    [[ "$stamp" =~ ^[0-9]+$ ]] && [[ "$high" =~ ^[0-9]+$ ]] || return 0
    age_days=$(( ($(date +%s) - stamp) / 86400 ))

    if [ "$high" -gt 0 ]; then
        echo "[보안 점검] CRITICAL·HIGH ${high}건 (${age_days}일 전 점검) → arachne --audit"
    elif [ "$age_days" -ge "$AUDIT_STALE_DAYS" ]; then
        echo "[보안 점검] 마지막 점검 ${age_days}일 전 → arachne --audit"
    fi
}

PrintSessionHint
PrintAuditHint
exit 0
