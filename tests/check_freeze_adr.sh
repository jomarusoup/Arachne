#!/bin/bash
################################################################################
# FILE NAME   : check_freeze_adr.sh
# DESCRIPTION : 동결 해제 절차 강제 — 기준 커밋 대비 objectives/freeze-manifest.txt 에
#               항목 행이 추가됐는데 같은 diff 에 docs/decisions/NNNN-*.md 신규 파일이
#               없으면 실패한다 (docs/OBJECTIVES.md §5, ADR-0007 결정 4).
#               행 삭제(아카이브)·주석 변경만 있는 diff 는 통과한다.
# USAGE       : bash tests/check_freeze_adr.sh <base-ref>
#               base-ref 와 HEAD 의 merge-base 부터 HEAD 까지를 검사한다.
#               base-ref 가 전부 0 인 SHA(새 브랜치 push)면 검사할 기준이 없어 건너뛴다.
################################################################################

set -euo pipefail

MANIFEST_PATH="objectives/freeze-manifest.txt"
ADR_DIR="docs/decisions"

#===============================================================================
# FUNCTION    : ListAddedEntries
# DESCRIPTION : diff 의 추가 행 중 매니페스트 항목(주석·빈 줄 제외)만 정규화해 출력
# PARAMETERS  : string merge_base - 비교 기준 커밋
#===============================================================================
ListAddedEntries() {
    local merge_base="$1"
    git diff --no-color --unified=0 "$merge_base" HEAD -- "$MANIFEST_PATH" \
        | awk '/^\+\+\+ / { next }
               /^\+/ {
                   line = substr($0, 2)
                   sub(/\r$/, "", line)
                   gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
                   if (line != "" && line !~ /^#/) print line
               }'
}

#===============================================================================
# FUNCTION    : ListAddedAdrs
# DESCRIPTION : diff 에서 새로 추가된 ADR 파일(NNNN-*.md) 경로를 출력
# PARAMETERS  : string merge_base - 비교 기준 커밋
#===============================================================================
ListAddedAdrs() {
    local merge_base="$1"
    git diff --no-color --name-only --diff-filter=A "$merge_base" HEAD -- "$ADR_DIR" \
        | awk -v dir="$ADR_DIR/" 'index($0, dir) == 1 {
               name = substr($0, length(dir) + 1)
               if (name ~ /^[0-9][0-9][0-9][0-9]-[^\/]+\.md$/) print
           }'
}

base_ref="${1:-}"
if [ -z "$base_ref" ]; then
    echo "[freeze-adr] 사용법: $0 <base-ref>" >&2
    exit 2
fi
if [[ "$base_ref" =~ ^0+$ ]]; then
    echo "[freeze-adr] 기준 커밋 없음(새 브랜치) — 건너뜀"
    exit 0
fi
if ! git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
    # 기준을 못 찾으면 통과시키지 않는다 (얕은 clone 등 — fetch-depth: 0 필요)
    echo "[freeze-adr] 기준 커밋을 찾을 수 없음: $base_ref" >&2
    exit 2
fi

merge_base="$(git merge-base "$base_ref" HEAD)"
added_entries="$(ListAddedEntries "$merge_base")"
if [ -z "$added_entries" ]; then
    echo "[freeze-adr] 매니페스트 항목 추가 없음 — 통과"
    exit 0
fi

added_adrs="$(ListAddedAdrs "$merge_base")"
if [ -z "$added_adrs" ]; then
    echo "[freeze-adr] 동결 위반 — 매니페스트에 항목이 추가됐지만 ${ADR_DIR}/ 신규 ADR 이 없음:" >&2
    printf '%s\n' "$added_entries" | sed 's/^/  + /' >&2
    exit 1
fi

echo "[freeze-adr] 매니페스트 항목 $(printf '%s\n' "$added_entries" | wc -l | tr -d ' ')건 추가 — 동반 ADR:"
printf '%s\n' "$added_adrs" | sed 's/^/  /'
