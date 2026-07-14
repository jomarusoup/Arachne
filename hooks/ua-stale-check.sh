#!/bin/bash
################################################################################
# FILE NAME   : ua-stale-check.sh
# DESCRIPTION : SessionStart Hook — Understand-Anything 지식그래프의 분석 기준
#               커밋(.understand-anything/meta.json 의 gitCommitHash)이 HEAD보다
#               뒤처졌는지 감지해 경고한다. 분석을 자동 재실행하지는 않는다 —
#               재분석은 비용이 커서 "/understand 재실행" 안내만 한다.
#               임계값은 UA_STALE_THRESHOLD(기본 1커밋)로 조정.
#               같은 기준 커밋에 대한 경고는 UA_STALE_SNOOZE_DAYS(기본 7일) 동안
#               1회만 출력한다 — 재분석을 미루는 동안 매 세션 배너가 반복되는
#               피로(및 컨텍스트 토큰 낭비)를 막는다.
# DATA        : 2026-07-02
# Modification: 2026-07-14
################################################################################

# 훅은 자동 실행 경로라 -e 제외 (실패해도 세션을 막지 않음)
set -uo pipefail

#-------------------------------------------------------------------------------
# UA 산출물·git 저장소가 없는 프로젝트는 조용히 통과
# UA_STALE_REPO 는 테스트용 오버라이드 (기본: 현재 작업 디렉터리)
#-------------------------------------------------------------------------------
REPO_DIR="${UA_STALE_REPO:-$PWD}"
META_FILE="$REPO_DIR/.understand-anything/meta.json"

[ -f "$META_FILE" ] || exit 0
git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

#-------------------------------------------------------------------------------
# meta.json 에서 분석 기준 커밋·분석 시각 추출 (jq 비의존)
#-------------------------------------------------------------------------------
base_hash=$(grep -oE '"gitCommitHash"[[:space:]]*:[[:space:]]*"[^"]*"' "$META_FILE" | head -1 \
    | sed -E 's/.*"gitCommitHash"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
[ -z "$base_hash" ] && exit 0

analyzed_at=$(grep -oE '"lastAnalyzedAt"[[:space:]]*:[[:space:]]*"[^"]*"' "$META_FILE" | head -1 \
    | sed -E 's/.*"lastAnalyzedAt"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')

#-------------------------------------------------------------------------------
# 기준 커밋이 저장소에 없으면(리베이스·shallow clone 등) 개수 비교 불가 안내
#-------------------------------------------------------------------------------
if ! git -C "$REPO_DIR" cat-file -e "${base_hash}^{commit}" 2>/dev/null; then
    echo "[UA-stale] 지식그래프 기준 커밋(${base_hash:0:7})을 저장소에서 찾을 수 없습니다"
    echo "  → 리베이스·shallow clone 가능성 — /understand 재실행을 고려하세요."
    exit 0
fi

behind_count=$(git -C "$REPO_DIR" rev-list --count "${base_hash}..HEAD" 2>/dev/null || echo 0)

#-------------------------------------------------------------------------------
# 임계값 미만이면 침묵 (기본 1 — 1커밋이라도 뒤처지면 알림)
#-------------------------------------------------------------------------------
THRESHOLD="${UA_STALE_THRESHOLD:-1}"
if [ "$behind_count" -lt "$THRESHOLD" ] 2>/dev/null; then
    exit 0
fi

#-------------------------------------------------------------------------------
# 스누즈 — 같은 기준 커밋에 대한 경고는 UA_STALE_SNOOZE_DAYS(기본 7일) 동안 1회만.
# /understand 재실행으로 기준 커밋이 바뀌면 스탬프가 무효화돼 다시 알린다.
# 0이면 스누즈 없이 매 세션 알림 (기존 동작).
#-------------------------------------------------------------------------------
SNOOZE_DAYS="${UA_STALE_SNOOZE_DAYS:-7}"
SNOOZE_STAMP="$REPO_DIR/.claude/ua-stale-warned"
if [ "$SNOOZE_DAYS" -gt 0 ] 2>/dev/null \
    && [ -f "$SNOOZE_STAMP" ] \
    && [ "$(cat "$SNOOZE_STAMP" 2>/dev/null)" = "$base_hash" ] \
    && [ -z "$(find "$SNOOZE_STAMP" -mtime +"$SNOOZE_DAYS" 2>/dev/null)" ]; then
    exit 0
fi
mkdir -p "$REPO_DIR/.claude" 2>/dev/null || true
printf '%s\n' "$base_hash" > "$SNOOZE_STAMP" 2>/dev/null || true

echo "┌───────────────────────────────────────────────────────────────────────────────"
echo "│  [UA-stale] Understand-Anything 지식그래프가 HEAD보다 ${behind_count}커밋 뒤처짐"
echo "│  기준 커밋: ${base_hash:0:7}${analyzed_at:+  (분석 시각: ${analyzed_at})}"
echo "│  → /understand 재실행으로 그래프를 갱신할 수 있습니다"
if [ "$SNOOZE_DAYS" -gt 0 ] 2>/dev/null; then
    echo "│  → 이 알림은 같은 기준 커밋에 대해 ${SNOOZE_DAYS}일간 다시 표시되지 않습니다"
fi
echo "└───────────────────────────────────────────────────────────────────────────────"
exit 0
