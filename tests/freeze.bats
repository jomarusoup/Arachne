#!/usr/bin/env bats
################################################################################
# FILE NAME   : freeze.bats
# DESCRIPTION : 규칙·스킬 추가 동결 강제 — rules/ 아래 모든 파일과 skills/ 최상위
#               항목이 objectives/freeze-manifest.txt 에 있는 항목만 존재하는지 검사한다.
#               삭제(아카이브)는 허용, 추가는 ADR + 매니페스트 갱신으로만 한다
#               (docs/OBJECTIVES.md §5).
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MANIFEST="${REPO_DIR}/objectives/freeze-manifest.txt"

#===============================================================================
# FUNCTION    : ListCurrentAssets
# DESCRIPTION : 현재 트리의 규칙 파일·스킬 최상위 항목을 매니페스트 형식으로 출력
#               (디렉터리는 끝에 /, 숨김 항목 포함. skills/archive/ 와 gitignore
#               대상 skills/synced/ 는 제외)
#===============================================================================
ListCurrentAssets() {
    (
        cd "$REPO_DIR" || exit 1
        find skills -mindepth 1 -maxdepth 1 -type d \
            ! -name archive ! -name synced | sed 's|$|/|'
        find skills -mindepth 1 -maxdepth 1 ! -type d
        find rules -type f
    )
}

#===============================================================================
# FUNCTION    : ListManifest
# DESCRIPTION : 매니페스트에서 주석·빈 줄을 빼고 CR·앞뒤 공백을 정규화해 출력
#===============================================================================
ListManifest() {
    awk '{ sub(/\r$/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
         $0 != "" && $0 !~ /^#/ { print }' "$MANIFEST"
}

@test "freeze: 매니페스트가 존재하고 비어 있지 않다" {
    [ -f "$MANIFEST" ]
    [ "$(ListManifest | wc -l)" -gt 0 ]
}

@test "freeze: 매니페스트 밖의 규칙·스킬이 없다" {
    local current
    local listed
    current="$(ListCurrentAssets)"
    listed="$(ListManifest)"
    # 목록 생성이 실패해 빈 결과로 통과하는 것을 막는다
    [ -n "$current" ]
    [ -n "$listed" ]

    # 집합 차이는 awk 로 계산한다 (grep -f 의 빈 패턴·BSD 차이 회피)
    local unlisted
    unlisted="$(awk 'NR == FNR { ok[$0] = 1; next } !($0 in ok)' \
        <(printf '%s\n' "$listed") <(printf '%s\n' "$current"))"
    if [ -n "$unlisted" ]; then
        echo "동결 위반 — 매니페스트에 없는 항목 (ADR 없이 추가 금지):"
        echo "$unlisted"
        return 1
    fi
}
