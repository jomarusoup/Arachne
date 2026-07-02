#!/usr/bin/env bats
################################################################################
# FILE NAME   : feedback.bats
# DESCRIPTION : Arachne 피드백 초안·목록·제출 계약 검증
# DATA        : 2026-07-01
# Modification: 2026-07-01
################################################################################

setup() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    TMP_DIR=$(mktemp -d)
    PROJECT_DIR="${TMP_DIR}/project"
    MOCK_BIN="${TMP_DIR}/bin"
    mkdir -p "${PROJECT_DIR}" "${MOCK_BIN}"
}

teardown() {
    rm -rf "${TMP_DIR}"
}

#===============================================================================
# FUNCTION    : install_mock_gh
# DESCRIPTION : feedback submit 테스트용 gh mock 설치
# PARAMETERS  : string mode - success|fail
#===============================================================================
install_mock_gh() {
    local mode="$1"

    cat > "${MOCK_BIN}/gh" <<GH
#!/usr/bin/env bash
set -euo pipefail
case "\${1:-} \${2:-}" in
  "auth status") exit 0 ;;
  "repo view") exit 0 ;;
  "issue create")
    if [ "${mode}" = "fail" ]; then
      echo "mock failure" >&2
      exit 9
    fi
    echo "https://github.com/example/arachne/issues/123"
    ;;
  *) exit 2 ;;
esac
GH
    chmod +x "${MOCK_BIN}/gh"
}

@test "feedback: new 는 날짜 기반 초안을 생성하고 list 에 표시" {
    cd "${PROJECT_DIR}"

    run bash "${REPO_DIR}/install.sh" feedback new "설치 개선"
    [ "$status" -eq 0 ]
    feedback_file=$(printf '%s\n' "$output" | tail -n 1)
    [ -f "$feedback_file" ]
    [[ "$(basename "$feedback_file")" == *"-arachne-feedback.md" ]]
    grep -qF 'Title: "설치 개선"' "$feedback_file"
    grep -qF 'status: "draft"' "$feedback_file"

    run bash "${REPO_DIR}/install.sh" feedback list
    [ "$status" -eq 0 ]
    [[ "$output" == *"draft"*"설치 개선"* ]]
}

@test "feedback: submit 은 민감정보 후보를 기본 차단" {
    cd "${PROJECT_DIR}"
    bash "${REPO_DIR}/install.sh" feedback new "secret leak" >/dev/null
    feedback_file=$(find docs/feedback -type f -name '*.md')
    printf '\nsk-1234567890abcdefghijklmnop\n' >> "$feedback_file"

    run bash "${REPO_DIR}/install.sh" feedback submit "$feedback_file"
    [ "$status" -ne 0 ]
    [[ "$output" == *"민감정보"* || "$output" == *"토큰"* ]]
    grep -qF 'status: "draft"' "$feedback_file"
}

@test "feedback: submit 성공 시 Issue URL 과 제출 시각을 기록" {
    cd "${PROJECT_DIR}"
    install_mock_gh success
    bash "${REPO_DIR}/install.sh" feedback new "submit ok" >/dev/null
    feedback_file=$(find docs/feedback -type f -name '*.md')

    run env PATH="${MOCK_BIN}:$PATH" ARACHNE_FEEDBACK_YES=1 \
        bash "${REPO_DIR}/install.sh" feedback submit "$feedback_file"
    [ "$status" -eq 0 ]
    [[ "$output" == *"https://github.com/example/arachne/issues/123"* ]]
    grep -qF 'status: "submitted"' "$feedback_file"
    grep -qF "https://github.com/example/arachne/issues/123" "$feedback_file"
    grep -qF -- "- **제출 시각**:" "$feedback_file"
}

@test "feedback: gh 제출 실패 시 원본 초안을 보존" {
    cd "${PROJECT_DIR}"
    install_mock_gh fail
    bash "${REPO_DIR}/install.sh" feedback new "submit fail" >/dev/null
    feedback_file=$(find docs/feedback -type f -name '*.md')
    before_text=$(cat "$feedback_file")

    run env PATH="${MOCK_BIN}:$PATH" ARACHNE_FEEDBACK_YES=1 \
        bash "${REPO_DIR}/install.sh" feedback submit "$feedback_file"
    [ "$status" -eq 9 ]
    [ "$(cat "$feedback_file")" = "$before_text" ]
}
