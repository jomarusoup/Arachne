#!/usr/bin/env bats
################################################################################
# FILE NAME   : freeze_adr.bats
# DESCRIPTION : tests/check_freeze_adr.sh 동작 검사 — 임시 git 저장소에서 매니페스트
#               행 추가·삭제·주석 변경과 ADR 동반 여부 조합별로 판정을 확인한다.
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
SCRIPT="${REPO_DIR}/tests/check_freeze_adr.sh"

#===============================================================================
# FUNCTION    : GitQuiet
# DESCRIPTION : 사용자 설정과 무관하게 커밋 가능한 git 호출 (서명·훅 비활성)
#===============================================================================
GitQuiet() {
    git -c user.name=freeze-test -c user.email=freeze-test@example.invalid \
        -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"
}

setup() {
    WORK="${BATS_TEST_TMPDIR}/repo"
    mkdir -p "${WORK}/objectives" "${WORK}/docs/decisions"
    cd "$WORK" || return 1
    GitQuiet init -q -b main .
    printf '# header\nrules/a.md\nskills/b/\n' > objectives/freeze-manifest.txt
    printf 'idx\n' > docs/decisions/README.md
    GitQuiet add -A
    GitQuiet commit -q -m base
    GitQuiet checkout -q -b work
}

@test "freeze-adr: 매니페스트 행 추가 + ADR 없음 → 실패" {
    printf 'agents/new.md\n' >> objectives/freeze-manifest.txt
    GitQuiet commit -q -am add
    run bash "$SCRIPT" main
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"agents/new.md"* ]]
}

@test "freeze-adr: 매니페스트 행 추가 + 신규 ADR → 통과" {
    printf 'agents/new.md\n' >> objectives/freeze-manifest.txt
    printf 'adr\n' > docs/decisions/0099-unfreeze-agent.md
    GitQuiet add -A
    GitQuiet commit -q -m add
    run bash "$SCRIPT" main
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0099-unfreeze-agent.md"* ]]
}

@test "freeze-adr: 기존 ADR 수정·README 추가만으로는 ADR 로 치지 않는다" {
    printf 'agents/new.md\n' >> objectives/freeze-manifest.txt
    printf 'more\n' >> docs/decisions/README.md
    printf 'note\n' > docs/decisions/notes.md
    GitQuiet add -A
    GitQuiet commit -q -m add
    run bash "$SCRIPT" main
    [ "$status" -eq 1 ]
}

@test "freeze-adr: 행 삭제(아카이브)만 → 통과" {
    sed -i.bak '/skills\/b\//d' objectives/freeze-manifest.txt && rm -f objectives/freeze-manifest.txt.bak
    GitQuiet commit -q -am archive
    run bash "$SCRIPT" main
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "freeze-adr: 주석·빈 줄 추가만 → 통과" {
    printf '\n# 주석\n   \n' >> objectives/freeze-manifest.txt
    GitQuiet commit -q -am comment
    run bash "$SCRIPT" main
    [ "$status" -eq 0 ]
}

@test "freeze-adr: 행 교체(삭제 1 + 추가 1)도 ADR 이 필요하다" {
    sed -i.bak 's|skills/b/|skills/c/|' objectives/freeze-manifest.txt && rm -f objectives/freeze-manifest.txt.bak
    GitQuiet commit -q -am swap
    run bash "$SCRIPT" main
    [ "$status" -eq 1 ]
}

@test "freeze-adr: 기준 커밋을 못 찾으면 통과시키지 않는다" {
    run bash "$SCRIPT" no-such-ref
    [ "$status" -eq 2 ]
}

@test "freeze-adr: 기준이 0 SHA(새 브랜치 push)면 건너뛴다" {
    run bash "$SCRIPT" 0000000000000000000000000000000000000000
    [ "$status" -eq 0 ]
}
