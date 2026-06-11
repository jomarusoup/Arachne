#!/bin/bash
################################################################################
# FILE NAME   : doc-drift-check.sh
# DESCRIPTION : 기능 파일(스크립트·rules·agents·commands·skills·hooks·설정)이
#               수정되면 README/docs 갱신을 상기시키는 PostToolUse 훅.
#               문서를 자동 생성하지는 않는다 — 자동 작성은 드리프트·노이즈·비용
#               위험이 커서, 여기서는 "갱신 필요" 알림만 한다(세션당 1회로 스로틀).
#               초안이 필요하면 안내대로 gemini-task(gtask)로 위임한다.
# DATA        : 2026-06-07
# Modification: 2026-06-07
################################################################################

# 훅은 자동 실행 경로라 -e 제외 (실패해도 세션·도구를 막지 않음)
set -uo pipefail

#-------------------------------------------------------------------------------
# PostToolUse 는 stdin 으로 JSON 을 받는다. jq 없이 file_path·session_id 추출.
#-------------------------------------------------------------------------------
payload=$(cat 2>/dev/null || true)
[ -z "${payload}" ] && exit 0

file_path=$(echo "${payload}" | grep -oE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"file_path"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
session_id=$(echo "${payload}" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"session_id"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')
[ -z "${file_path}" ] && exit 0

#-------------------------------------------------------------------------------
# 문서 자체(docs/·*.md)·테스트 변경은 제외. 기능 파일만 대상.
#-------------------------------------------------------------------------------
case "${file_path}" in
    */docs/*|*.md|*/tests/*) exit 0 ;;
esac

is_functional=0
case "${file_path}" in
    */rules/*|*/agents/*|*/commands/*|*/skills/*|*/hooks/*) is_functional=1 ;;
    *.sh|*/settings.template.json)                          is_functional=1 ;;
esac
[ "${is_functional}" -eq 0 ] && exit 0

#-------------------------------------------------------------------------------
# 세션당 1회로 스로틀 (반복 편집 시 매번 알리지 않도록)
#-------------------------------------------------------------------------------
state_dir="${ARACHNE_STATE_DIR:-$HOME/.claude}"
marker="${state_dir}/.docdrift-seen-${session_id:-nosession}"
[ -f "${marker}" ] && exit 0
mkdir -p "${state_dir}" 2>/dev/null || true
touch "${marker}" 2>/dev/null || true

# F-09: 세션마다 쌓이는 마커의 무한 누적 방지 — 7일 지난 마커는 정리
find "${state_dir}" -maxdepth 1 -name '.docdrift-seen-*' -mtime +7 -delete 2>/dev/null || true

base=$(basename "${file_path}")
echo "[문서 드리프트] 기능 파일 변경 감지: ${base}"
echo "  → README.md·docs/ 반영이 필요한지 확인하세요 (구조·명령·동작 변경 시)."
echo "  → 초안은 gemini-task(gtask)로 위임 가능. 인덱스 누락은 tests/check_index.sh 가 잡습니다."

exit 0
