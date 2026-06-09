#!/usr/bin/env bash
################################################################################
# FILE NAME   : verify.sh
# DESCRIPTION : Arachne 사용 프로젝트의 로컬·GitHub CI 공통 검증 runner
# DATA        : 2026-06-09
# Modification: 2026-06-09
################################################################################

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND_FILE="${PROJECT_DIR}/.arachne/commands"

################################################################################
# FUNCTION    : Fail
# DESCRIPTION : 프로젝트 검증 오류를 출력하고 지정 상태로 종료
# PARAMETERS  : integer status - 종료 상태
#               string message - 오류 메시지
################################################################################
Fail() {
    local status="$1"
    local message="$2"

    echo "[Arachne] [FAIL] ${message}" >&2
    exit "$status"
}

################################################################################
# FUNCTION    : ValidateStructure
# DESCRIPTION : Arachne 프로젝트 검증에 필요한 최소 구조 확인
################################################################################
ValidateStructure() {
    git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || Fail 1 "git 저장소가 아닙니다: ${PROJECT_DIR}"
    [ -f "${PROJECT_DIR}/README.md" ] \
        || Fail 1 "README.md가 없습니다"
    [ -f "$COMMAND_FILE" ] \
        || Fail 1 ".arachne/commands가 없습니다. arachne init-ci를 실행하세요"
}

################################################################################
# FUNCTION    : RunCommands
# DESCRIPTION : commands 파일의 비어 있지 않은 비주석 명령을 순서대로 실행
# RETURNED    : 성공 시 0, 실패한 명령의 종료 상태
################################################################################
RunCommands() {
    local command
    local command_count=0
    local status
    local trimmed

    while IFS= read -r command || [ -n "$command" ]; do
        trimmed="${command#"${command%%[![:space:]]*}"}"
        case "$trimmed" in
            ""|\#*) continue ;;
        esac

        command_count=$((command_count + 1))
        echo "[Arachne] [RUN ${command_count}] ${command}"
        (
            cd "$PROJECT_DIR" || exit 1
            bash -o pipefail -c "$command"
        )
        status=$?
        if [ "$status" -ne 0 ]; then
            echo "[Arachne] [FAIL] 명령 ${command_count} 종료 상태: ${status}" >&2
            return "$status"
        fi
    done < "$COMMAND_FILE"

    [ "$command_count" -gt 0 ] \
        || Fail 1 ".arachne/commands에 실행할 검증 명령이 없습니다"
    echo "[Arachne] 모든 프로젝트 검증 통과 (${command_count}개 명령)"
}

ValidateStructure
RunCommands
