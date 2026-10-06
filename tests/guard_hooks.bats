#!/usr/bin/env bats
################################################################################
# FILE NAME   : guard_hooks.bats
# DESCRIPTION : 보안 가드 훅(guard-bash.sh·guard-secrets.sh)의 차단·확인·허용
#               판정을 고정한다. 차단돼야 할 것과 통과해야 할 것을 쌍으로 둔다.
# DATA        : 2026-10-05
# Modification: 2026-10-05
################################################################################

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
GUARD_BASH="${REPO_DIR}/hooks/guard-bash.sh"
GUARD_SECRETS="${REPO_DIR}/hooks/guard-secrets.sh"

#===============================================================================
# FUNCTION    : BashDecision
# DESCRIPTION : 명령 하나를 guard-bash.sh 에 넣고 판정(deny/ask/빈 값)을 돌려준다.
# PARAMETERS  : string command_text - 검사할 명령
#===============================================================================
BashDecision() {
    local escaped
    # JSON 문자열로 인코딩 — 역슬래시·따옴표 이스케이프, 줄바꿈은 \n
    escaped=$(printf '%s' "$1" | awk 'BEGIN { ORS = "\\n" } { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); print }')
    printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "${escaped}" \
        | bash "${GUARD_BASH}" \
        | sed -nE 's/.*"permissionDecision":"([a-z]+)".*/\1/p'
}

#===============================================================================
# FUNCTION    : SecretsDecision
# DESCRIPTION : 임시 저장소에 파일을 스테이징하고 git commit 판정을 돌려준다.
# PARAMETERS  : string file_name - 저장소 안 파일 경로
#               string content   - 파일 내용
#===============================================================================
SecretsDecision() {
    mkdir -p "${REPO}/$(dirname "$1")"
    printf '%s\n' "$2" > "${REPO}/$1"
    git -C "${REPO}" add "$1"
    printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"},"cwd":"%s"}' "${REPO}" \
        | bash "${GUARD_SECRETS}" \
        | sed -nE 's/.*"permissionDecision":"([a-z]+)".*/\1/p'
}

setup() {
    REPO=$(mktemp -d)
    git -C "${REPO}" init -q
}

teardown() {
    rm -rf "${REPO}"
}

#-------------------------------------------------------------------------------
# guard-bash: 검사 우회는 차단
#-------------------------------------------------------------------------------
@test "guard-bash: --no-verify 차단" {
    [ "$(BashDecision 'git commit --no-verify -m x')" = "deny" ]
}

@test "guard-bash: commit -n 차단" {
    [ "$(BashDecision 'git commit -n -m x')" = "deny" ]
}

@test "guard-bash: -c core.hooksPath 차단" {
    [ "$(BashDecision 'git -c core.hooksPath=/dev/null commit -m x')" = "deny" ]
}

@test "guard-bash: 짧은 옵션 결합(-nm)·따옴표로 감싼 --no-verify 도 차단" {
    [ "$(BashDecision 'git commit -nm "msg"')" = "deny" ]
    [ "$(BashDecision 'git commit "--no-verify" -m "msg"')" = "deny" ]
    [ "$(BashDecision "git commit -m 'msg' -n")" = "deny" ]
    [ "$(BashDecision 'git push origin --no-verify')" = "deny" ]
}

@test "guard-bash: 커밋 메시지·heredoc 본문 속 -n 은 옵션으로 보지 않음" {
    [ -z "$(BashDecision 'git commit -m "fix: handle -n flag"')" ]
    [ -z "$(BashDecision 'git commit -am "x"')" ]
    [ -z "$(BashDecision 'git commit -F - <<EOF
-n 은 본문
EOF')" ]
}

@test "guard-bash: core.hooksPath 읽기는 허용" {
    [ -z "$(BashDecision 'git config --get core.hooksPath')" ]
}

#-------------------------------------------------------------------------------
# guard-bash: 파괴적 명령은 확인 요청
#-------------------------------------------------------------------------------
@test "guard-bash: force push 확인, force-with-lease 허용" {
    [ "$(BashDecision 'git push --force origin main')" = "ask" ]
    [ -z "$(BashDecision 'git push --force-with-lease')" ]
}

@test "guard-bash: reset --hard 확인" {
    [ "$(BashDecision 'git reset --hard HEAD~1')" = "ask" ]
}

@test "guard-bash: 위험 경로 rm -rf 확인, 상대 경로·임시 경로 허용" {
    [ "$(BashDecision 'rm -rf /')" = "ask" ]
    [ "$(BashDecision 'rm -rf ~/work')" = "ask" ]
    [ "$(BashDecision 'rm -rf "$HOME"/work')" = "ask" ]
    [ -z "$(BashDecision 'rm -rf build')" ]
    [ -z "$(BashDecision 'rm -rf /tmp/arachne-test')" ]
}

@test "guard-bash: DB 클라이언트의 DROP 확인, 커밋 메시지 속 DROP 은 허용" {
    [ "$(BashDecision 'psql -c "DROP TABLE t"')" = "ask" ]
    [ "$(BashDecision 'sqlplus app@dev <<EOF
TRUNCATE TABLE orders;
EOF')" = "ask" ]
    [ -z "$(BashDecision 'git commit -m "DROP TABLE 문서화"')" ]
}

@test "guard-bash: ipcrm·chmod 777 확인" {
    [ "$(BashDecision 'ipcrm -m 1234')" = "ask" ]
    [ "$(BashDecision 'chmod 777 run.sh')" = "ask" ]
}

#-------------------------------------------------------------------------------
# guard-bash: 비밀 파일 읽기는 확인, 예시 파일·목록은 허용
#-------------------------------------------------------------------------------
@test "guard-bash: .env·키 파일 읽기 확인" {
    [ "$(BashDecision 'cat .env')" = "ask" ]
    [ "$(BashDecision 'grep KEY ~/.ssh/id_rsa')" = "ask" ]
    [ "$(BashDecision 'head conf/wallet/cwallet.sso')" = "ask" ]
}

@test "guard-bash: .env.example 읽기·디렉터리 목록은 허용" {
    [ -z "$(BashDecision 'cat .env.example')" ]
    [ -z "$(BashDecision 'ls ~/.ssh')" ]
    [ -z "$(BashDecision 'ls -la && npm test')" ]
}

@test "guard-bash: Bash 가 아닌 도구는 관여하지 않음" {
    run bash -c "printf '{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\".env\"}}' | bash '${GUARD_BASH}'"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

#-------------------------------------------------------------------------------
# guard-secrets: 비밀값
#-------------------------------------------------------------------------------
@test "guard-secrets: 액세스 키 리터럴 차단" {
    [ "$(SecretsDecision a.c 'const char *k = "AKIAABCDEFGHIJKLMNOP";')" = "deny" ]
}

@test "guard-secrets: 단어 안의 sk- 는 키로 보지 않음(파일명 오탐 방지)" {
    [ -z "$(SecretsDecision doc.md '[링크](2026-06-07-atask-correctness-hardening.md)')" ]
    git -C "${REPO}" reset -q
    [ "$(SecretsDecision key.txt 'token: sk-ant-abcdefghijklmnopqrstuvwx')" = "deny" ]
}

@test "guard-secrets: 비밀번호 리터럴 차단, 환경변수 참조 허용" {
    [ "$(SecretsDecision b.py 'password = "Sup3rSecret!"')" = "deny" ]
    git -C "${REPO}" reset -q
    [ -z "$(SecretsDecision c.py 'password = os.environ["APP_PW"]')" ]
}

@test "guard-secrets: Pro*C 리터럴 자격증명 차단, 호스트 변수 허용" {
    [ "$(SecretsDecision i.pc 'EXEC SQL CONNECT scott IDENTIFIED BY tiger123;')" = "deny" ]
    git -C "${REPO}" reset -q
    [ -z "$(SecretsDecision h.pc 'EXEC SQL CONNECT :user IDENTIFIED BY :pw;')" ]
}

@test "guard-secrets: 차단 사유에 값이 노출되지 않음" {
    run bash -c "true"
    out=$(mkdir -p "${REPO}" && printf 'k="AKIAABCDEFGHIJKLMNOP"\n' > "${REPO}/k.c" && git -C "${REPO}" add k.c \
        && printf '{"tool_name":"Bash","tool_input":{"command":"git commit -m x"},"cwd":"%s"}' "${REPO}" | bash "${GUARD_SECRETS}")
    [[ "$out" == *"k.c:1"* ]]
    [[ "$out" != *"AKIAABCDEFGHIJKLMNOP"* ]]
}

#-------------------------------------------------------------------------------
# guard-secrets: 개인정보 — 검증식이 맞을 때만 차단
#-------------------------------------------------------------------------------
@test "guard-secrets: Luhn 일치 카드번호 차단, 불일치 숫자열 허용" {
    [ "$(SecretsDecision e.txt 'card 4111 1111 1111 1111')" = "deny" ]
    git -C "${REPO}" reset -q
    [ -z "$(SecretsDecision f.txt 'order 4111 1111 1111 1112')" ]
}

@test "guard-secrets: 검증 자리 일치 주민등록번호 차단, 불일치 허용" {
    [ "$(SecretsDecision d.txt 'rrn 900101-1234568')" = "deny" ]
    git -C "${REPO}" reset -q
    [ -z "$(SecretsDecision g.txt 'id 900101-1234567')" ]
}

@test "guard-secrets: 픽스처 경로·합성 데이터 표식은 개인정보 검사 제외" {
    [ -z "$(SecretsDecision tests/fixtures/cards.txt 'card 4111 1111 1111 1111')" ]
    git -C "${REPO}" reset -q
    [ -z "$(SecretsDecision sample.txt '# ARACHNE-SYNTHETIC-DATA
card 4111 1111 1111 1111')" ]
}

@test "guard-secrets: 데이터 파일·연락처 다수는 확인" {
    [ "$(SecretsDecision customers.csv 'id,name')" = "ask" ]
    git -C "${REPO}" reset -q
    [ "$(SecretsDecision list.txt '010-1234-5678
010-2345-6789
010-3456-7890')" = "ask" ]
}

@test "guard-secrets: 메시지 속 -a 를 commit -a 로 오인하지 않음(스테이징 안 된 파일은 검사 밖)" {
    printf 'base\n' > "${REPO}/s.txt"
    git -C "${REPO}" add s.txt
    git -C "${REPO}" -c user.email=t@t -c user.name=t commit -qm base
    printf 'k="AKIAABCDEFGHIJKLMNOP"\n' > "${REPO}/s.txt"
    printf 'ok\n' > "${REPO}/ok.txt"
    git -C "${REPO}" add ok.txt
    run bash -c "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m \\\"fix: handle -a flag\\\"\"},\"cwd\":\"${REPO}\"}' | bash '${GUARD_SECRETS}'"
    [ -z "$output" ]
    run bash -c "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -am x\"},\"cwd\":\"${REPO}\"}' | bash '${GUARD_SECRETS}'"
    [[ "$output" == *'"deny"'* ]]
    [ "$(git -C "${REPO}" diff --cached --name-only)" = "ok.txt" ]
}

@test "guard-secrets: git commit 이 아니면 관여하지 않음" {
    printf 'k="AKIAABCDEFGHIJKLMNOP"\n' > "${REPO}/k.c"  # ARACHNE-ALLOW-SECRET (테스트용 가짜 키)
    git -C "${REPO}" add k.c
    run bash -c "printf '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git status\"},\"cwd\":\"${REPO}\"}' | bash '${GUARD_SECRETS}'"
    [ -z "$output" ]
}

#-------------------------------------------------------------------------------
# jq 가 없는 환경(Windows Git Bash 등)의 정규식 폴백 경로
#-------------------------------------------------------------------------------
@test "guard 폴백(jq 없음): 이스케이프된 따옴표가 든 명령도 같은 판정" {
    export GUARD_NO_JQ=1
    [ "$(BashDecision 'git commit --no-verify -m "a \"quoted\" msg"')" = "deny" ]
    [ "$(BashDecision 'psql -c "DROP TABLE t"')" = "ask" ]
    [ -z "$(BashDecision 'git commit -m "DROP TABLE 문서화"')" ]
    [ "$(SecretsDecision a.c 'const char *k = "AKIAABCDEFGHIJKLMNOP";')" = "deny" ]
}

#-------------------------------------------------------------------------------
# 명령 안에서 cd·git -C 로 다른 저장소에 커밋하는 경우 (2026-10-06 W5 실측에서 발견)
#-------------------------------------------------------------------------------
@test "guard-secrets: cd <저장소> && git commit 은 그 저장소의 스테이징을 검사" {
    printf 'k="AKIAABCDEFGHIJKLMNOP"\n' > "${REPO}/k.c"  # ARACHNE-ALLOW-SECRET (테스트용 가짜 키)
    git -C "${REPO}" add k.c
    other=$(mktemp -d)
    out=$(printf '{"tool_name":"Bash","tool_input":{"command":"cd %s && git commit -m x"},"cwd":"%s"}' "${REPO}" "${other}" \
        | bash "${GUARD_SECRETS}")
    rm -rf "${other}"
    printf '%s' "${out}" | grep -q '"deny"'
}

@test "guard-secrets: git -C <저장소> commit 도 그 저장소를 검사" {
    printf 'k="AKIAABCDEFGHIJKLMNOP"\n' > "${REPO}/k.c"  # ARACHNE-ALLOW-SECRET (테스트용 가짜 키)
    git -C "${REPO}" add k.c
    out=$(printf '{"tool_name":"Bash","tool_input":{"command":"git -C %s commit -m x"},"cwd":"/"}' "${REPO}" \
        | bash "${GUARD_SECRETS}")
    printf '%s' "${out}" | grep -q '"deny"'
}
