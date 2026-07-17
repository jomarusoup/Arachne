#!/bin/bash
################################################################################
# FILE NAME   : check_index.sh
# DESCRIPTION : 인덱스 ↔ 실제 파일 일치 검사 — 파일을 추가하고 인덱스 갱신을
#               누락하는 드리프트를 CI에서 차단한다.
# DATA        : 2026-06-05
# Modification: 2026-07-17
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

        # 인덱스가 stem(확장자 없는 파일명)으로 참조하는 경우도 허용.
        # #35: 부분일치 오탐 방지 — 단어 경계(-w)로 매칭해 더 긴 단어의 일부로 우연히
        #      통과하는 false-negative 를 막는다 (예: 'api-design' 이 'api-designer' 에 매칭 X).
        local stem="${base%.md}"
        if ! grep -qwF "$base" "$REPO_DIR/$index_file" \
           && ! grep -qwF "$stem" "$REPO_DIR/$index_file"; then
            echo "  [DRIFT] $src_dir/$base 가 $index_file 에 없음"
            missing=1
        fi
    done
    return "$missing"
}

#-------------------------------------------------------------------------------
# 검사 1: skills/*.md ↔ skills/README.md · docs/USAGE.md
#-------------------------------------------------------------------------------
echo "[index] skills/ ↔ skills/README.md"
CheckReferenced "skills" "skills/README.md" || FAIL=1
echo "[index] skills/ ↔ docs/USAGE.md"
CheckReferenced "skills" "docs/USAGE.md" || FAIL=1

#-------------------------------------------------------------------------------
# 검사 2: commands/*.md ↔ CLAUDE.md · docs/USAGE.md
#-------------------------------------------------------------------------------
echo "[index] commands/ ↔ CLAUDE.md"
CheckReferenced "commands" "CLAUDE.md" || FAIL=1
echo "[index] commands/ ↔ docs/USAGE.md"
CheckReferenced "commands" "docs/USAGE.md" || FAIL=1

#-------------------------------------------------------------------------------
# 검사 3: agents/*.md ↔ CLAUDE.md · docs/USAGE.md
#-------------------------------------------------------------------------------
echo "[index] agents/ ↔ CLAUDE.md"
CheckReferenced "agents" "CLAUDE.md" || FAIL=1
echo "[index] agents/ ↔ docs/USAGE.md"
CheckReferenced "agents" "docs/USAGE.md" || FAIL=1

#-------------------------------------------------------------------------------
# 검사 4: rules/<하위디렉터리> ↔ CLAUDE.md (언어 규칙 트리 누락 차단)
#-------------------------------------------------------------------------------
echo "[index] rules/ 하위디렉터리 ↔ CLAUDE.md"
for dir in "$REPO_DIR"/rules/*/; do
    name=$(basename "$dir")
    if ! grep -qE "(^|[^a-z])$name/" "$REPO_DIR/CLAUDE.md"; then
        echo "  [DRIFT] rules/$name/ 가 CLAUDE.md 트리에 없음"
        FAIL=1
    fi
done

#-------------------------------------------------------------------------------
# 검사 5: 낡은 "(예정)" 마커 — 실제 존재하는 디렉터리를 미래형으로 표기 금지
#-------------------------------------------------------------------------------
echo "[index] 낡은 '(예정)' 마커 검사"
for stale_dir in tests mcp-configs; do
    if [ -d "$REPO_DIR/$stale_dir" ] && grep -qE "\(예정\).*$stale_dir|$stale_dir.*\(예정\)" "$REPO_DIR/CLAUDE.md"; then
        echo "  [DRIFT] CLAUDE.md 가 이미 존재하는 $stale_dir/ 를 '(예정)' 으로 표기"
        FAIL=1
    fi
done

#===============================================================================
# FUNCTION    : CheckCount
# DESCRIPTION : 문서 속 "라벨 (N개)" 개수 표기가 실제 파일 개수와 일치하는지 검사.
#               표기가 없는 문서는 통과 (숫자를 쓰면 반드시 실제와 일치해야 함).
# PARAMETERS  : string label  - 표기 라벨 (스킬·커맨드·서브에이전트)
#               int    actual - 실제 파일 개수
#               string doc    - 검사할 문서 (REPO_DIR 상대 경로)
#               string regex  - 개수 표기를 찾는 grep -oE 패턴
# RETURNED    : 0(일치 또는 표기 없음) / 1(불일치 있음)
#===============================================================================
CheckCount() {
    local label="$1"
    local actual="$2"
    local doc="$3"
    local regex="$4"
    local bad=0

    [ -f "$REPO_DIR/$doc" ] || return 0

    local num
    while read -r num; do
        [ -z "$num" ] && continue
        if [ "$num" -ne "$actual" ]; then
            echo "  [DRIFT] $doc 의 ${label} 개수 표기 ${num} ≠ 실제 ${actual} — 문서 숫자를 ${actual}(으)로 갱신하세요"
            bad=1
        fi
    done < <(grep -oE "$regex" "$REPO_DIR/$doc" | grep -oE '[0-9]+')
    return "$bad"
}

#-------------------------------------------------------------------------------
# 검사 6: 문서 개수 표기 ↔ 실제 파일 개수 (skills·commands·agents)
#         파일을 추가/삭제하고 문서의 "(N개)" 표기 갱신을 누락하는 드리프트 차단.
#         개수 기준: 각 디렉터리 최상위 *.md (README.md 제외)
#-------------------------------------------------------------------------------
echo "[index] 문서 개수 표기 ↔ 실제 파일 개수"
SKILL_COUNT=$(find "$REPO_DIR/skills"   -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
CMD_COUNT=$(find "$REPO_DIR/commands"   -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')
AGENT_COUNT=$(find "$REPO_DIR/agents"   -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l | tr -d ' ')

# 라벨 뒤 12바이트 이내의 "(숫자" 표기만 개수 선언으로 간주 — "다음 3요소" 류 오탐 방지
for doc in README.md CLAUDE.md AGENTS.md docs/ARCHITECTURE.md docs/USAGE.md docs/README.md skills/README.md; do
    CheckCount "스킬"         "$SKILL_COUNT" "$doc" '스킬[^()]{0,12}\([0-9]+개?'          || FAIL=1
    CheckCount "커맨드"       "$CMD_COUNT"   "$doc" '커맨드[^()]{0,12}\([0-9]+개?'        || FAIL=1
    CheckCount "서브에이전트" "$AGENT_COUNT" "$doc" '서브에이전트[^0-9()]{0,6}\(?[0-9]+개' || FAIL=1
done

#===============================================================================
# FUNCTION    : CheckRelativeLinks
# DESCRIPTION : 디렉터리 내 .md 파일의 상대 .md 링크가 실제 파일로 해소되는지
#               검사 — 파일 이동(아카이브 등) 후 링크 갱신 누락을 차단한다.
#               외부 URL·절대 경로·Obsidian 볼트 경로(NNN.%20 접두)는 제외.
# PARAMETERS  : string scan_dir - 검사 대상 디렉터리 (REPO_DIR 상대)
# RETURNED    : 0(모두 해소) / 1(깨진 링크 있음)
#===============================================================================
CheckRelativeLinks() {
    local scan_dir="$1"
    local bad=0
    local md_file
    local link
    local target

    while IFS= read -r md_file; do
        while IFS= read -r link; do
            [ -z "$link" ] && continue
            target="${link%%#*}"
            case "$target" in
                ''|http://*|https://*|mailto:*|/*) continue ;;
                [0-9]*.%20*) continue ;;   # Obsidian 볼트 경로 — 저장소 밖
            esac
            if [ ! -e "$(dirname "$md_file")/$target" ]; then
                echo "  [DRIFT] ${md_file#"$REPO_DIR"/}: 깨진 링크 → $target"
                bad=1
            fi
        done < <(grep -oE '\]\([^)]+\.md(#[^)]*)?\)' "$md_file" 2>/dev/null \
                     | sed -E 's/^\]\(//; s/\)$//')
    done < <(find "$REPO_DIR/$scan_dir" -name '*.md')
    return "$bad"
}

#-------------------------------------------------------------------------------
# 검사 7: 상대 .md 링크 해소 — rules·skills·agents·commands·docs
#         (A-32/A-35: 스킬 아카이브 이동 후 링크 깨짐 재발 방지)
#-------------------------------------------------------------------------------
echo "[index] 상대 .md 링크 해소 검사"
for link_dir in rules skills agents commands docs; do
    CheckRelativeLinks "$link_dir" || FAIL=1
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
