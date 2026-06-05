#!/bin/bash
################################################################################
# FILE NAME   : check_index.sh
# DESCRIPTION : 인덱스 ↔ 실제 파일 일치 검사 — 파일을 추가하고 인덱스 갱신을
#               누락하는 드리프트를 CI에서 차단한다.
# DATA        : 2026-06-05
################################################################################

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
FAIL=0

#===============================================================================
# FUNCTION    : CheckReferenced
# DESCRIPTION : src_dir 의 각 .md(README 제외) 파일명이 index_file 에 등장하는지 검사
# PARAMETERS  : string src_dir    - 검사 대상 디렉터리
#               string index_file - 파일명이 나열돼야 할 인덱스 문서
# RETURNED    : 0(모두 참조됨) / 1(누락 있음)
#===============================================================================
CheckReferenced() {
    local src_dir="$1"
    local index_file="$2"
    local missing=0

    local path
    for path in "$REPO_DIR/$src_dir"/*.md; do
        [ -e "$path" ] || continue
        local base
        base=$(basename "$path")
        [ "$base" = "README.md" ] && continue

        # 인덱스가 stem(확장자 없는 파일명)으로 참조하는 경우도 허용
        local stem="${base%.md}"
        if ! grep -qF "$base" "$REPO_DIR/$index_file" \
           && ! grep -qF "$stem" "$REPO_DIR/$index_file"; then
            echo "  [DRIFT] $src_dir/$base 가 $index_file 에 없음"
            missing=1
        fi
    done
    return "$missing"
}

#-------------------------------------------------------------------------------
# 검사 1: skills/*.md ↔ skills/README.md
#-------------------------------------------------------------------------------
echo "[index] skills/ ↔ skills/README.md"
CheckReferenced "skills" "skills/README.md" || FAIL=1

#-------------------------------------------------------------------------------
# 검사 2: commands/*.md ↔ CLAUDE.md
#-------------------------------------------------------------------------------
echo "[index] commands/ ↔ CLAUDE.md"
CheckReferenced "commands" "CLAUDE.md" || FAIL=1

#-------------------------------------------------------------------------------
# 검사 3: agents/*.md ↔ CLAUDE.md
#-------------------------------------------------------------------------------
echo "[index] agents/ ↔ CLAUDE.md"
CheckReferenced "agents" "CLAUDE.md" || FAIL=1

#-------------------------------------------------------------------------------
# 검사 4: 낡은 "(예정)" 마커 — 실제 존재하는 디렉터리를 미래형으로 표기 금지
#-------------------------------------------------------------------------------
echo "[index] 낡은 '(예정)' 마커 검사"
for stale_dir in tests mcp-configs; do
    if [ -d "$REPO_DIR/$stale_dir" ] && grep -qE "\(예정\).*$stale_dir|$stale_dir.*\(예정\)" "$REPO_DIR/CLAUDE.md"; then
        echo "  [DRIFT] CLAUDE.md 가 이미 존재하는 $stale_dir/ 를 '(예정)' 으로 표기"
        FAIL=1
    fi
done

#-------------------------------------------------------------------------------
# 결과
#-------------------------------------------------------------------------------
if [ "$FAIL" -eq 0 ]; then
    echo "[PASS] 인덱스 일치 — 드리프트 없음"
else
    echo "[FAIL] 인덱스 드리프트 발견 — 위 항목을 인덱스에 반영하세요"
fi
exit "$FAIL"
