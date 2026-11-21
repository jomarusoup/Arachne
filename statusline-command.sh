#!/bin/bash
################################################################################
# FILE NAME   : statusline-command.sh
# DESCRIPTION : Claude Code 상태표시줄 — 모델·브랜치·컨텍스트·세션 비용·플랜 사용 한도 출력
#               모든 수치는 Claude Code가 stdin으로 넘기는 공식 필드에서만 읽는다
#               (code.claude.com/docs/en/statusline). 로컬 추정·상태 파일 없음.
################################################################################

# 상태표시줄은 매 렌더 실행·tolerant 경로라 -e 제외 (실패해도 출력만 비면 됨)
set -uo pipefail

# 소수점이 쉼표인 로케일에서도 printf %f 가 jq 출력(0.5)을 읽도록 숫자 로케일만 C 고정
# (LC_ALL 이 있으면 LC_NUMERIC 을 덮으므로 해제 — 나머지는 LANG·LC_* 로 그대로)
unset LC_ALL
export LC_NUMERIC=C

# 테스트에서 시각을 고정할 수 있도록 환경변수 우선
now=${STATUSLINE_NOW:-}
[[ "$now" =~ ^[0-9]+$ ]] || now=$(date +%s)

#---------------------------------------------------------------------------
# stdin 파싱 — jq 한 번 호출, 필드는 US(0x1f)로 구분해 빈 값도 보존
#   rate_limits 는 구독(Pro·Max·Ultra) 계정 + 첫 응답 이후에만 존재,
#   창별로 따로 빠질 수 있으므로 없으면 빈 문자열.
#---------------------------------------------------------------------------
IFS=$'\x1f' read -r model cwd ctx_size used_tokens used_pct session_cost \
    pct_5h reset_5h pct_7d reset_7d < <(
    jq -r '
        # 필드 하나의 타입 이상이 전체 파싱을 깨지 않도록 숫자는 모두 정규화
        def num: if type == "number" then .
                 elif type == "string" then (tonumber? // null)
                 else null end;
        def int: num | if . == null then "" else (floor | tostring) end;
        def pct: num | if . == null then "" else (. + 0.5 | floor | tostring) end;
        (.context_window // {}) as $cw
        | ($cw.current_usage // null) as $cu
        | (if ($cu | type) == "object"
              then ((($cu.input_tokens | num) // 0)
                    + (($cu.cache_creation_input_tokens | num) // 0)
                    + (($cu.cache_read_input_tokens | num) // 0))
              else (($cw.total_input_tokens | num) // 0) end | floor) as $used
        | (($cw.context_window_size | num) // 0 | floor) as $size
        | (($cw.used_percentage | num)
           // (if $size > 0 then ($used * 100 / $size) else 0 end)) as $pct
        | [ (.model.display_name // "?" | tostring),
            (.workspace.current_dir // .cwd // "" | tostring),
            ($size | tostring),
            ($used | tostring),
            ($pct | pct),
            ((.cost.total_cost_usd | num) // 0 | tostring),
            (.rate_limits.five_hour.used_percentage | pct),
            (.rate_limits.five_hour.resets_at | int),
            (.rate_limits.seven_day.used_percentage | pct),
            (.rate_limits.seven_day.resets_at | int)
          ] | join("\u001f")
    ' 2>/dev/null
)

# jq 실패(잘못된 JSON 등) 시 빈 값 → 기본값, 산술에 쓰는 값은 한 번 더 검증
model=${model:-?}
[[ "${ctx_size:-}" =~ ^[0-9]+$ ]] || ctx_size=0
[[ "${used_tokens:-}" =~ ^[0-9]+$ ]] || used_tokens=0
[[ "${used_pct:-}" =~ ^[0-9]+$ ]] || used_pct=0
[[ "${session_cost:-}" =~ ^[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]] || session_cost=0

#===========================================================================
# FUNCTION    : FormatRemain
# DESCRIPTION : 초기화 시각(epoch 초)까지 남은 시간을 "3d 4h" / "2h 15m" / "9m" 형태로
# PARAMETERS  : int reset_epoch - rate_limits.*.resets_at
# RETURNED    : 남은 시간 문자열, 값이 없거나 이미 지났으면 빈 문자열
#===========================================================================
FormatRemain() {
    local reset_epoch=$1
    local secs
    [[ "$reset_epoch" =~ ^[0-9]+$ ]] || return 0
    secs=$(( reset_epoch - now ))
    (( secs > 0 )) || return 0
    if (( secs >= 86400 )); then
        printf "%dd %dh" $(( secs / 86400 )) $(( secs % 86400 / 3600 ))
    elif (( secs >= 3600 )); then
        printf "%dh %dm" $(( secs / 3600 )) $(( secs % 3600 / 60 ))
    else
        printf "%dm" $(( secs < 60 ? 1 : secs / 60 ))
    fi
}

#===========================================================================
# FUNCTION    : FormatLimit
# DESCRIPTION : 한도 창 하나를 "5h 77% left (reset 2h 15m)" 형태로
# PARAMETERS  : string label       - 창 이름 (5h·weekly)
#               string used_pct    - 사용률 정수, 빈 값이면 미제공
#               string reset_epoch - 초기화 시각 epoch 초
# RETURNED    : 표시 문자열 — 데이터가 없으면 "<label> --"
#===========================================================================
FormatLimit() {
    local label=$1
    local pct=$2
    local reset_epoch=$3
    local remain_pct
    local remain_time
    if [[ ! "$pct" =~ ^[0-9]+$ ]]; then
        printf "%s --" "$label"
        return 0
    fi
    remain_pct=$(( 100 - pct ))
    (( remain_pct < 0 )) && remain_pct=0
    remain_time=$(FormatRemain "$reset_epoch")
    if [ -n "$remain_time" ]; then
        printf "%s %d%% left (reset %s)" "$label" "$remain_pct" "$remain_time"
    else
        printf "%s %d%% left" "$label" "$remain_pct"
    fi
}

#---------------------------------------------------------------------------
# git 브랜치 — 세션 작업 디렉터리 기준
#---------------------------------------------------------------------------
branch=""
if [ -n "${cwd:-}" ]; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi
branch_part=""
[ -n "$branch" ] && branch_part=" | $branch"

#---------------------------------------------------------------------------
# 컨텍스트 막대 (10칸)
#---------------------------------------------------------------------------
(( used_pct > 100 )) && used_pct=100
bar_filled=$(( used_pct / 10 ))
bar=""
for ((i = 0; i < 10; i++)); do
    if (( i < bar_filled )); then bar="${bar}█"; else bar="${bar}░"; fi
done

limit_5h=$(FormatLimit "5h" "${pct_5h:-}" "${reset_5h:-}")
limit_7d=$(FormatLimit "weekly" "${pct_7d:-}" "${reset_7d:-}")

printf "%s%s | [%s] %d%% | %dK/%dK tokens | session \$%.4f | %s | %s" \
    "$model" \
    "$branch_part" \
    "$bar" \
    "$used_pct" \
    "$(( used_tokens / 1000 ))" \
    "$(( ctx_size / 1000 ))" \
    "$session_cost" \
    "$limit_5h" \
    "$limit_7d"
