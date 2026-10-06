#!/bin/bash
################################################################################
# FILE NAME   : check_sensitive_text.sh
# DESCRIPTION : 추적 중인 문서·스크립트에 개인 경로와 비밀값·개인정보가 섞이지
#               않았는지 검사한다. 세션 요약·handoff·issue 문서처럼 모델이 쓰는
#               산출물이 새는 경로가 되지 않게 하는 마지막 확인이다.
#                 - 개인 경로: /Users/<계정>/, /home/<계정>/ (예시용 계정 이름은 허용)
#                 - 비밀값·개인정보: hooks/guard-secrets.sh 와 같은 패턴을 쓴다
#               보고에는 파일:줄만 남기고 값은 출력하지 않는다.
################################################################################

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_DIR}" || exit 1

# 예시로 쓰는 계정 이름 (문서의 경로 예시에서 허용)
readonly ALLOWED_ACCOUNTS='Arachne|user|username|me|you|alice|bob|example|runner|vagrant|ubuntu|ec2-user|name|<[^>]+>|\$USER|\$\{USER\}'

g_FailCount=0

#===============================================================================
# FUNCTION    : ReportHits
# DESCRIPTION : grep -n 결과에서 파일:줄만 뽑아 출력하고 실패를 누적한다.
# PARAMETERS  : string label - 검사 이름
#               string hits  - "파일:줄:내용" 줄 목록
#===============================================================================
ReportHits() {
    local label="$1"
    local hits="$2"
    [ -z "${hits}" ] && return 0
    printf '%s\n' "${hits}" | cut -d: -f1,2 | while IFS= read -r location; do
        echo "  [FAIL] ${label}: ${location}"
    done
    g_FailCount=$((g_FailCount + $(printf '%s\n' "${hits}" | wc -l)))
}

#-------------------------------------------------------------------------------
# 검사 대상: 추적 파일 중 텍스트. archive/ 와 테스트 픽스처는 제외
#-------------------------------------------------------------------------------
targets=$(git ls-files | grep -vE '^(archive/|tests/fixtures/)' | grep -vE '\.(png|jpg|jpeg|gif|ico|pdf|xlsx|zip|gz)$')

echo "[sensitive] 개인 경로 (/Users/<계정>/, /home/<계정>/)"
hits=$(printf '%s\n' "${targets}" | xargs grep -nE '/(Users|home)/[A-Za-z0-9._-]+/' 2>/dev/null \
    | grep -vE "/(Users|home)/(${ALLOWED_ACCOUNTS})/" || true)
ReportHits "개인 경로" "${hits}"

echo "[sensitive] 비밀값 패턴"
hits=$(printf '%s\n' "${targets}" | grep -v '^tests/guard_hooks.bats$' | xargs grep -nE \
    '(^|[^A-Za-z0-9])(AKIA|ASIA)[0-9A-Z]{16}|(^|[^A-Za-z0-9_-])sk-ant-[A-Za-z0-9_-]{20,}|(^|[^A-Za-z0-9])gh[pousr]_[A-Za-z0-9]{36}|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----' \
    2>/dev/null | grep -v 'ARACHNE-ALLOW-SECRET' || true)
ReportHits "비밀값" "${hits}"

echo "[sensitive] 주민등록번호(검증 자리 일치)·카드번호(Luhn 일치)"
hits=$(printf '%s\n' "${targets}" | grep -v '^tests/guard_hooks.bats$' | xargs awk '
    function rrn_ok(s,   w, sum, i) {
        split("2 3 4 5 6 7 8 9 2 3 4 5", w, " "); sum = 0
        for (i = 1; i <= 12; i++) sum += substr(s, i, 1) * w[i]
        return ((11 - (sum % 11)) % 10) == substr(s, 13, 1) + 0
    }
    function luhn_ok(s,   n, i, d, sum, alt) {
        n = length(s); sum = 0; alt = 0
        for (i = n; i >= 1; i--) { d = substr(s, i, 1) + 0; if (alt) { d *= 2; if (d > 9) d -= 9 }; sum += d; alt = !alt }
        return (sum % 10) == 0
    }
    /ARACHNE-SYNTHETIC-DATA|ARACHNE-ALLOW-SECRET/ { next }
    match($0, /[0-9]{6}-[1-4][0-9]{6}/) {
        x = substr($0, RSTART, RLENGTH); gsub(/-/, "", x)
        if (rrn_ok(x)) print FILENAME ":" FNR ":rrn"
    }
    match($0, /[3-6][0-9]{3}[ -][0-9]{4}[ -][0-9]{4}[ -][0-9]{1,7}/) {
        x = substr($0, RSTART, RLENGTH); gsub(/[ -]/, "", x)
        if (length(x) >= 13 && luhn_ok(x)) print FILENAME ":" FNR ":card"
    }' 2>/dev/null || true)
ReportHits "개인정보" "${hits}"

if [ "${g_FailCount}" -gt 0 ]; then
    echo "[FAIL] 민감 텍스트 ${g_FailCount}건 — 값을 지우거나 예시 표기(~/, <계정>, 합성 데이터)로 바꾸세요"
    exit 1
fi
echo "[PASS] 민감 텍스트 없음"
