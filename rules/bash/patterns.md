---
paths:
  - "**/*.sh"
  - "**/*.bash"
---
# Bash 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.

## 안전 옵션 — 스크립트 상단 필수

```bash
set -euo pipefail
```

## 함수로 로직 분리

```bash
#===============================================================================
# FUNCTION    : CheckDependency
# DESCRIPTION : 필수 명령어 존재 여부 확인
# PARAMETERS  : string cmd - 확인할 명령어명
# RETURNED    : 0(존재) / 1(없음)
#===============================================================================
CheckDependency() {
    local cmd="$1"
    if ! command -v "${cmd}" &>/dev/null; then
        echo "[ERROR] ${cmd} 가 설치되어 있지 않습니다" >&2
        return 1
    fi
}
```

## 임시 파일 관리

```bash
TMP_FILE=$(mktemp)
trap 'rm -f "${TMP_FILE}"' EXIT  /* 스크립트 종료 시 자동 삭제 */

echo "data" > "${TMP_FILE}"
ProcessFile "${TMP_FILE}"
```

## 에러 처리 패턴

```bash
RunCommand() {
    local cmd="$1"
    if ! ${cmd}; then
        echo "[ERROR] 명령 실패: ${cmd}" >&2
        return 1
    fi
}

RunCommand "make build" || exit 1
```

## 로그 함수

```bash
readonly LOG_PREFIX="[SCRIPT]"

LogInfo()  { echo "${LOG_PREFIX} INFO:  $*"; }
LogWarn()  { echo "${LOG_PREFIX} WARN:  $*" >&2; }
LogError() { echo "${LOG_PREFIX} ERROR: $*" >&2; }
