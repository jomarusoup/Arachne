#!/bin/bash
################################################################################
# FILE NAME   : statusline-command.sh
# DESCRIPTION : Claude Code 상태표시줄 — 모델·컨텍스트·비용·예산 잔여량 출력
# DATA        : 2026-05-05
# Modification: 2026-05-05
################################################################################

# 상태표시줄은 매 렌더 실행·tolerant 경로라 -e 제외 (실패해도 출력만 비면 됨)
set -uo pipefail

input=$(cat)

# --- stdin 파싱 ---
model=$(echo "$input" | jq -r '.model.display_name // "?"')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
max_tokens=$(echo "$input" | jq -r '.context_window.max_tokens // 0')
session_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

NOW=$(date +%s)

LIMITS_FILE=~/.claude/usage_limits.json
TRACK_FILE=~/.claude/usage_track.json
LAST_FILE=~/.claude/usage_last.json

LIMIT_5H=5.00
LIMIT_WEEKLY=35.00
if [ -f "$LIMITS_FILE" ]; then
  LIMIT_5H=$(jq -r '.limit_5h // 5.00' "$LIMITS_FILE")
  LIMIT_WEEKLY=$(jq -r '.limit_weekly // 35.00' "$LIMITS_FILE")
fi

# --- 비용 추적 (세션 간 델타 기록) ---
last_cost=0
if [ -f "$LAST_FILE" ]; then
  last_cost=$(jq -r '.cost // 0' "$LAST_FILE")
fi

delta=$(awk "BEGIN { d = $session_cost - $last_cost; if (d < 0) d = $session_cost; if (d < 0) d = 0; printf \"%.6f\", d }")
echo "{\"cost\": $session_cost, \"ts\": $NOW}" > "$LAST_FILE"

if awk "BEGIN { exit ($delta > 0.00001) ? 0 : 1 }"; then
  [ ! -f "$TRACK_FILE" ] && echo "[]" > "$TRACK_FILE"
  # 7일 이전 항목 제거 + 새 항목 추가
  # 임시 파일은 mktemp 사용 — 고정 /tmp 경로는 공유 시스템에서 심볼릭 공격에 취약 (CHANGELOG-AUDIT A-04)
  CUTOFF=$((NOW - 604800))
  track_tmp=$(mktemp) \
    && jq "[.[] | select(.ts >= $CUTOFF)] + [{\"ts\": $NOW, \"cost\": $delta}]" "$TRACK_FILE" > "$track_tmp" \
    && mv "$track_tmp" "$TRACK_FILE"
fi

# --- 5h window cost ---
WINDOW_5H=$((NOW - 18000))
cost_5h=0
[ -f "$TRACK_FILE" ] && cost_5h=$(jq "[.[] | select(.ts >= $WINDOW_5H) | .cost] | add // 0" "$TRACK_FILE")

# --- weekly window: since last Saturday noon ---
dow=$(date +%u)   # 1=Mon .. 7=Sun
hour=$(date +%H)
days_since_sat=$(( (dow - 6 + 7) % 7 ))
[ "$days_since_sat" -eq 0 ] && [ "$hour" -lt 12 ] && days_since_sat=7
LAST_SAT_NOON=$(date -d "${days_since_sat} days ago 12:00:00" +%s)
cost_7d=0
[ -f "$TRACK_FILE" ] && cost_7d=$(jq "[.[] | select(.ts >= $LAST_SAT_NOON) | .cost] | add // 0" "$TRACK_FILE")

# --- time until next Saturday noon ---
days_to_next_sat=$(( (6 - dow + 7) % 7 ))
[ "$days_to_next_sat" -eq 0 ] && [ "$hour" -ge 12 ] && days_to_next_sat=7
NEXT_SAT_NOON=$(date -d "+${days_to_next_sat} days 12:00:00" +%s)
secs_until=$(( NEXT_SAT_NOON - NOW ))
hours_total=$(( secs_until / 3600 ))
reset_days=$(( hours_total / 24 ))
reset_hours=$(( hours_total % 24 ))

# --- git branch ---
branch=$(git -C "$PWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# --- context progress bar ---
pct_int=$(printf "%.0f" "$used_pct")
used_tokens=$((total_input + total_output))

bar_filled=$((pct_int / 10))
bar_empty=$((10 - bar_filled))
bar=""
for ((i=0; i<bar_filled; i++)); do bar="${bar}█"; done
for ((i=0; i<bar_empty; i++)); do bar="${bar}░"; done

# --- remaining as percentage ---
remain_5h_pct=$(awk "BEGIN { r = ($LIMIT_5H - $cost_5h) / $LIMIT_5H * 100; if (r < 0) r = 0; if (r > 100) r = 100; printf \"%.0f\", r }")
remain_7d_pct=$(awk "BEGIN { r = ($LIMIT_WEEKLY - $cost_7d) / $LIMIT_WEEKLY * 100; if (r < 0) r = 0; if (r > 100) r = 100; printf \"%.0f\", r }")

# --- output ---
branch_part=""
[ -n "$branch" ] && branch_part=" | $branch"

printf "%s%s | [%s] %d%% | %dK/%dK tokens | session \$%.4f | 5h %s%% left | weekly %s%% left (reset %dd %dh)" \
  "$model" \
  "$branch_part" \
  "$bar" \
  "$pct_int" \
  "$(( used_tokens / 1000 ))" \
  "$(( max_tokens / 1000 ))" \
  "$session_cost" \
  "$remain_5h_pct" \
  "$remain_7d_pct" \
  "$reset_days" \
  "$reset_hours"
