#!/usr/bin/env bats
################################################################################
# FILE NAME   : objectives.bats
# DESCRIPTION : 목표·예산 정본(docs/OBJECTIVES.md, objectives/budgets.yaml) 형식 검사.
#               모든 예산 항목이 id·unit·value·status·source 를 갖고,
#               "실측 대기" 항목은 value·source 가 null, 확정·실측 항목은 값과
#               출처가 있는지 확인한다.
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
BUDGETS="${REPO_DIR}/objectives/budgets.yaml"

#===============================================================================
# FUNCTION    : CheckBudgetEntries
# DESCRIPTION : budgets: 목록의 각 "- id:" 항목을 모아 필수 필드와 상태 규칙을 검사.
#               값은 CR·인라인 주석·앞뒤 공백·따옴표를 정규화하고 ~·빈 값은 null 로 본다.
#               "- id:" 줄 수(들여쓰기 무관)와 파싱한 항목 수가 다르면 위반이다.
# RETURNED    : 위반 항목을 출력하고 위반이 있으면 1
#===============================================================================
CheckBudgetEntries() {
    awk '
        function norm(v) {
            sub(/\r$/, "", v)
            sub(/[[:space:]]+#.*$/, "", v)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            if (v ~ /^".*"$/) v = substr(v, 2, length(v) - 2)
            if (v == "" || v == "~" || tolower(v) == "null") v = "null"
            return v
        }
        function flush() {
            if (!open) return
            for (k in need) if (!(k in seen)) { print id ": " k " 없음"; bad = 1 }
            if (status != "실측 대기" && status != "확정" && status != "실측") {
                print id ": 알 수 없는 status (" status ")"; bad = 1
            }
            if (status == "실측 대기" && (value != "null" || source != "null")) {
                print id ": 실측 대기 항목은 value·source 가 null 이어야 함"; bad = 1
            }
            if ((status == "확정" || status == "실측") && (value == "null" || source == "null")) {
                print id ": 확정·실측 항목은 value·source 가 있어야 함"; bad = 1
            }
            for (k in seen) delete seen[k]
            status = ""; value = ""; source = ""; open = 0
        }
        BEGIN { need["unit"]; need["value"]; need["status"]; need["source"] }
        /^budgets:/ { inb = 1; next }
        !inb { next }
        /^[^[:space:]#]/ { flush(); inb = 0; next }
        /^[[:space:]]*- id:/ {
            flush()
            raw++
            id = $0; sub(/^[[:space:]]*- id:/, "", id); id = norm(id)
            if (id == "null") { print "빈 id 항목 (" raw "번째)"; bad = 1; id = "(빈 id)" }
            if (id in ids) { print id ": 중복 id"; bad = 1 }
            ids[id] = 1; parsed++; open = 1
            next
        }
        open && /^[[:space:]]+[a-z_]+:/ {
            key = $0; sub(/^[[:space:]]+/, "", key); sub(/:.*/, "", key)
            val = $0; sub(/^[[:space:]]+[a-z_]+:/, "", val); val = norm(val)
            seen[key] = 1
            if (key == "status") status = val
            if (key == "value")  value  = val
            if (key == "source") source = val
        }
        END {
            flush()
            if (parsed == 0) { print "예산 항목 없음"; bad = 1 }
            exit bad
        }
    ' "$BUDGETS"
}

@test "objectives: 정본 두 파일이 존재한다" {
    [ -f "${REPO_DIR}/docs/OBJECTIVES.md" ]
    [ -f "$BUDGETS" ]
}

@test "objectives: 예산 항목이 필수 필드와 상태 규칙을 지킨다" {
    run CheckBudgetEntries
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "objectives: OBJECTIVES.md 가 핵심 제약을 담는다" {
    local doc="${REPO_DIR}/docs/OBJECTIVES.md"
    grep -qF "정확성 > 장애 격리 > 성능 > 개발 효율" "$doc"
    grep -qF "Go는 핫패스 금지" "$doc"
    grep -qF "메인 ← 보조 ← 유틸" "$doc"
    grep -qF "budgets.yaml" "$doc"
    grep -qF "핫패스 할당 0" "$doc"
    grep -qF "클라이언트는 서버를 막지 않는다" "$doc"
}

@test "objectives: 확정 불변식 예산이 0 으로 고정돼 있다" {
    local id
    for id in server.main.loss server.main.hotpath_alloc client.main.server_send_block_time; do
        run awk -v want="$id" '
            /^[[:space:]]*- id:/ { cur = $0; sub(/^[[:space:]]*- id:[[:space:]]*/, "", cur); next }
            cur == want && /^[[:space:]]+value:/  { v = $2 }
            cur == want && /^[[:space:]]+status:/ { s = $2 }
            END { exit !(v == "0" && s == "확정") }
        ' "$BUDGETS"
        echo "$id"
        [ "$status" -eq 0 ]
    done
}
