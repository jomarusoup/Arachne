#!/usr/bin/env bats
################################################################################
# FILE NAME   : statusline.bats
# DESCRIPTION : statusline-command.sh 계약 검증 — 공식 stdin 필드(context_window·rate_limits)
#               표시, rate_limits 미제공·첫 응답 전 처리, 지난 초기화 시각, 실수·문자열 필드 격리,
#               쉼표 소수점 로케일, workspace 우선, 상태 파일 미생성.
################################################################################

bats_require_minimum_version 1.5.0

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SCRIPT="${REPO_DIR}/statusline-command.sh"
    TMP_DIR=$(mktemp -d)
    export HOME="${TMP_DIR}"
    export STATUSLINE_NOW=1000000
}

teardown() {
    rm -rf "${TMP_DIR}"
}

@test "구독_계정_공식_한도와_초기화_시각_표시" {
    # 5h: 23.5% 사용, 2h 15m 뒤 초기화 / weekly: 41.2% 사용, 3d 4h 뒤 초기화
    run bash "$SCRIPT" <<EOF
{"model":{"display_name":"Opus"},"cwd":"${TMP_DIR}",
 "cost":{"total_cost_usd":0.5},
 "context_window":{"context_window_size":200000,"used_percentage":23,
   "total_input_tokens":46000,"total_output_tokens":1200,
   "current_usage":{"input_tokens":1000,"output_tokens":1200,
     "cache_creation_input_tokens":5000,"cache_read_input_tokens":40000}},
 "rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1008100},
   "seven_day":{"used_percentage":41.2,"resets_at":1273600}}}
EOF
    [ "$status" -eq 0 ]
    [ "$output" = "Opus | [██░░░░░░░░] 23% | 46K/200K tokens | session \$0.5000 | 5h 76% left (reset 2h 15m) | weekly 59% left (reset 3d 4h)" ]
}

@test "rate_limits_없으면_대시_표시" {
    run bash "$SCRIPT" <<EOF
{"model":{"display_name":"Sonnet"},"cwd":"${TMP_DIR}","cost":{"total_cost_usd":0},
 "context_window":{"context_window_size":200000,"used_percentage":null,
   "total_input_tokens":0,"current_usage":null}}
EOF
    [ "$status" -eq 0 ]
    [ "$output" = "Sonnet | [░░░░░░░░░░] 0% | 0K/200K tokens | session \$0.0000 | 5h -- | weekly --" ]
}

@test "창_하나만_있고_초기화_지났으면_시각_생략" {
    run bash "$SCRIPT" <<EOF
{"model":{"display_name":"Opus"},"cwd":"${TMP_DIR}",
 "context_window":{"context_window_size":1000000,
   "current_usage":{"input_tokens":500000}},
 "rate_limits":{"seven_day":{"used_percentage":100,"resets_at":999000}}}
EOF
    [ "$status" -eq 0 ]
    [ "$output" = "Opus | [█████░░░░░] 50% | 500K/1000K tokens | session \$0.0000 | 5h -- | weekly 0% left" ]
}

@test "빈_입력에도_실패하지_않음" {
    run bash "$SCRIPT" <<< ''
    [ "$status" -eq 0 ]
    [[ "$output" == "? | [░░░░░░░░░░] 0% | 0K/0K tokens"* ]]
}

@test "git_저장소면_브랜치_표시" {
    git -C "${TMP_DIR}" init -q -b feat/x
    git -C "${TMP_DIR}" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    run bash "$SCRIPT" <<< "{\"model\":{\"display_name\":\"Opus\"},\"cwd\":\"${TMP_DIR}\"}"
    [ "$status" -eq 0 ]
    [[ "$output" == "Opus | feat/x | "* ]]
}

@test "상태_파일을_만들지_않음" {
    local before
    local after
    before=$(find "${TMP_DIR}" | sort)
    run bash "$SCRIPT" <<< '{"model":{"display_name":"Opus"}}'
    after=$(find "${TMP_DIR}" | sort)
    [ "$status" -eq 0 ]
    [ "$before" = "$after" ]
}

@test "실수_필드도_정수화해_stderr_없이_출력" {
    run --separate-stderr bash "$SCRIPT" <<EOF
{"model":{"display_name":"Opus"},"cwd":"${TMP_DIR}","cost":{"total_cost_usd":1e-05},
 "context_window":{"context_window_size":200000.5,"total_input_tokens":1500.5},
 "rate_limits":{"five_hour":{"used_percentage":50,"resets_at":1001800.7}}}
EOF
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    [ "$output" = "Opus | [░░░░░░░░░░] 1% | 1K/200K tokens | session \$0.0000 | 5h 50% left (reset 30m) | weekly --" ]
}

@test "문자열·잘못된_타입_필드는_해당_항목만_기본값" {
    run --separate-stderr bash "$SCRIPT" <<EOF
{"model":{"display_name":"Opus"},"cwd":"${TMP_DIR}","cost":{"total_cost_usd":"x"},
 "context_window":{"context_window_size":"200000","used_percentage":"12",
   "current_usage":{"input_tokens":null,"cache_read_input_tokens":24000}},
 "rate_limits":{"five_hour":{"used_percentage":"abc"},"seven_day":{"used_percentage":150}}}
EOF
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    [ "$output" = "Opus | [█░░░░░░░░░] 12% | 24K/200K tokens | session \$0.0000 | 5h -- | weekly 0% left" ]
}

@test "쉼표_소수점_로케일에서도_비용_표시" {
    # 로케일이 설치되지 않은 러너에서는 bash 시작 경고가 stderr 로 나오므로 건너뛴다
    locale -a 2>/dev/null | grep -qix 'de_DE.utf-\?8' || skip "de_DE.UTF-8 로케일 없음"
    run --separate-stderr env LC_ALL=de_DE.UTF-8 bash "$SCRIPT" <<< '{"cost":{"total_cost_usd":0.5}}'
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
    [[ "$output" == *"session \$0.5000"* ]]
}

@test "workspace_current_dir가_cwd보다_우선" {
    git -C "${TMP_DIR}" init -q -b ws
    git -C "${TMP_DIR}" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    run bash "$SCRIPT" <<< "{\"model\":{\"display_name\":\"Opus\"},\"cwd\":\"/nonexistent\",\"workspace\":{\"current_dir\":\"${TMP_DIR}\"}}"
    [ "$status" -eq 0 ]
    [[ "$output" == "Opus | ws | "* ]]
}
