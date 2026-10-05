#!/usr/bin/env bats
################################################################################
# FILE NAME   : naming_check.bats
# DESCRIPTION : lib/naming-check.sh 계약 검증 — 미등록 약어·동의어 혼용·금지 동의어·
#               30자 초과 보고, 허용 약어 통과, --strict 종료 코드, --changed 범위,
#               사전 없음 처리. 정규식 추출(ctags 미사용)로 결정론을 보장하고,
#               ctags 경로는 설치된 경우에만 따로 확인한다.
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SCRIPT="${REPO_DIR}/lib/naming-check.sh"
    TMP_DIR=$(mktemp -d)
    PROJ="${TMP_DIR}/proj"
    mkdir -p "${PROJ}/.arachne" "${PROJ}/src"
    cp "${REPO_DIR}/templates/project/naming-dict.tsv" "${PROJ}/.arachne/naming-dict.tsv"
    export NAMING_CHECK_NO_CTAGS=1
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#-------------------------------------------------------------------------------
# 헬퍼: 프로젝트 디렉터리에서 검사 실행
#-------------------------------------------------------------------------------
run_check() {
    cd "${PROJ}" || return 1
    run bash "${SCRIPT}" "$@"
}

@test "naming: 사전 템플릿은 머리글과 20~30개 항목을 가진 5열 TSV" {
    local dict="${REPO_DIR}/templates/project/naming-dict.tsv"
    head -1 "${dict}" | grep -q "^표준 단어	허용 약어	의미	금지 동의어	분류$"
    local entries
    entries=$(grep -vE '^(#|표준)' "${dict}" | grep -c .)
    [ "${entries}" -ge 20 ] && [ "${entries}" -le 30 ]
    local bad
    bad=$(grep -vE '^(#|표준)' "${dict}" | awk -F '\t' 'NF != 5' | wc -l | tr -d ' ')
    [ "${bad}" -eq 0 ]
}

@test "naming: 미등록 약어 보고 (Usr)" {
    printf 'int GetUsrName(void);\n' > "${PROJ}/src/a.c"
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"미등록약어"*"GetUsrName"*"'Usr'"* ]]
}

@test "naming: 허용 약어는 통과 (Cnt·Buf·Msg·g_ 접두)" {
    printf 'static int g_MsgCnt = 0;\nint GetBufLen(char *msg_buf, int max_len);\n' > "${PROJ}/src/a.c"
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"경고 0건"* ]]
}

@test "naming: 같은 표준 단어의 전체 단어와 약어 혼용 보고 (Count + Cnt)" {
    printf 'int g_TaskCnt = 0;\nint GetTaskCount(void);\n' > "${PROJ}/src/a.c"
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"동의어혼용"*"count"*"GetTaskCount"*"g_TaskCnt"* ]]
}

@test "naming: 금지 동의어 보고 (resp → response/Rsp)" {
    printf 'int SendResp(int conn_fd);\n' > "${PROJ}/src/a.pc"
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"금지동의어"*"SendResp"*"'response'"*"'Rsp'"* ]]
}

@test "naming: 30자 초과 식별자 보고, 30자 이하는 통과" {
    # 31자, 30자
    printf 'int OrdQtyPrcTsSeqRecAddrPtrSegA;\nint OrdQtyPrcTsSeqRecAddrPtrSeg1;\n' > "${PROJ}/src/a.c"
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"길이초과"*"OrdQtyPrcTsSeqRecAddrPtrSegA"*"31자"* ]]
    [[ "$output" != *"OrdQtyPrcTsSeqRecAddrPtrSeg1 —"* ]]
}

@test "naming: --strict 는 경고가 있으면 1, 없으면 0" {
    printf 'int GetUsrName(void);\n' > "${PROJ}/src/a.c"
    run_check --all --strict
    [ "$status" -eq 1 ]

    printf 'int GetOrdCnt(void);\n' > "${PROJ}/src/a.c"
    run_check --all --strict
    [ "$status" -eq 0 ]
}

@test "naming: 주석·문자열·EXEC SQL 안의 이름은 검사하지 않음" {
    cat > "${PROJ}/src/a.pc" <<'EOF'
/* int GetUsrName(void); */
// int GetUsrAddr(void);
const char *kMsg = "int GetUsrPwd(void);";
EXEC SQL SELECT usr_nm INTO :name_buf FROM usr_tbl;
EOF
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" != *"GetUsr"* ]]
    [[ "$output" != *"usr_nm"* ]]
}

@test "naming: Rust·TypeScript 선언도 검사" {
    printf 'fn get_usr_name() -> String { String::new() }\n' > "${PROJ}/src/a.rs"
    printf 'export function getUsrId(): number { return 0; }\n' > "${PROJ}/src/b.ts"
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"get_usr_name"* ]]
    [[ "$output" == *"getUsrId"* ]]
}

@test "naming: --changed 는 git diff 로 추가된 줄의 식별자만 검사" {
    cd "${PROJ}"
    git init -q
    git config user.email t@example.com
    git config user.name t
    printf 'int GetUsrOld(void);\n' > src/a.c
    git add -A
    git commit -qm init
    printf 'int GetUsrOld(void);\nint GetUsrNew(void);\n' > src/a.c
    printf 'int GetUsrFresh(void);\n' > src/b.c
    run_check --changed
    [ "$status" -eq 0 ]
    [[ "$output" == *"GetUsrNew"* ]]
    [[ "$output" == *"GetUsrFresh"* ]]
    [[ "$output" != *"GetUsrOld"* ]]
}

@test "naming: 기본 사전이 없으면 검사 생략, --dict 로 준 사전이 없으면 오류" {
    rm -f "${PROJ}/.arachne/naming-dict.tsv"
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"사전 없음"* ]]

    run_check --all --dict "${PROJ}/missing.tsv"
    [ "$status" -eq 2 ]
}

@test "naming: universal-ctags 가 있으면 ctags 추출로도 같은 경고" {
    command -v ctags > /dev/null 2>&1 && ctags --version 2> /dev/null | grep -q "Universal Ctags" \
        || skip "universal-ctags 미설치"
    unset NAMING_CHECK_NO_CTAGS
    printf 'int GetUsrName(void) { return 0; }\n' > "${PROJ}/src/a.c"
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" == *"추출=ctags"* ]]
    [[ "$output" == *"미등록약어"*"GetUsrName"* ]]
}

@test "naming: C 관용 짧은 이름(ret·env·fp·cb·sig·fd)은 미등록 약어로 보지 않음" {
    printf 'int RunTask(int fd, int sig)\n{\n    int ret = 0;\n    char *env = 0;\n    void *fp = 0;\n    void *cb = 0;\n    return ret;\n}\n' > "${PROJ}/src/a.c"
    run_check --all
    [ "$status" -eq 0 ]
    [[ "$output" != *"'ret'"* ]]
    [[ "$output" != *"'env'"* ]]
    [[ "$output" != *"'sig'"* ]]
}

@test "naming: 여러 파일을 한 번에 검사해도 파일·줄 위치가 정확함" {
    printf 'int Ok(void);\n' > "${PROJ}/src/a.c"
    printf '\n\nint GetUsrName(void);\n' > "${PROJ}/src/b.c"
    run_check --all
    [[ "$output" == *"src/b.c:3"* ]]
}
