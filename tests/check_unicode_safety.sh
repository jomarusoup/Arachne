#!/bin/bash
################################################################################
# FILE NAME   : check_unicode_safety.sh
# DESCRIPTION : 지시 파일(rules·agents·commands·skills·hooks·CLAUDE.md·AGENTS.md)에
#               눈에 보이지 않는 유니코드가 섞였는지 검사한다. 폭 없는 문자와
#               양방향 제어 문자는 사람 눈에는 안 보이지만 모델에게는 읽혀서
#               숨은 지시(프롬프트 인젝션)의 통로가 될 수 있다.
# DATA        : 2026-10-05
# Modification: 2026-10-05
################################################################################

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_DIR}" || exit 1

echo "[unicode] 폭 없는 문자·양방향 제어 문자"
hits=$(git ls-files rules agents commands skills hooks templates CLAUDE.md AGENTS.md \
    | grep -v '^skills/archive/' \
    | xargs perl -CSD -ne '
        if (/[\x{200B}-\x{200F}\x{2060}\x{FEFF}\x{202A}-\x{202E}\x{2066}-\x{2069}]/) {
            printf "%s:%d\n", $ARGV, $.;
        }
        close ARGV if eof;
    ' 2>/dev/null || true)

if [ -n "${hits}" ]; then
    printf '%s\n' "${hits}" | while IFS= read -r location; do
        echo "  [FAIL] 숨은 유니코드: ${location}"
    done
    echo "[FAIL] 숨은 유니코드 발견 — 해당 문자를 지우세요"
    exit 1
fi
echo "[PASS] 숨은 유니코드 없음"
