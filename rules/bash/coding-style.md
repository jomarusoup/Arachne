---
paths:
  - "**/*.sh"
  - "**/*.bash"
  - "**/Makefile"
---
# Bash / Shell 코딩 스타일

> [common/coding-style.md](../common/coding-style.md) 를 확장한다.

## 헤더 형식

`/* */` 미지원 → `#` 80개로 동일한 박스 구조 구성.

```bash
################################################################################
# FILE NAME   : 파일명.sh
# DESCRIPTION : 파일 역할 한 줄 요약
# DATA        : YYYY-MM-DD
# Modification: YYYY-MM-DD
################################################################################

#===============================================================================
# FUNCTION    : function_name
# DESCRIPTION : 역할 설명
# PARAMETERS  : type 인자명 - 설명
#               type 인자명 - 설명
# RETURNED    : 반환값 설명 (없으면 생략)
#===============================================================================

#-------------------------------------------------------------------------------
# 특정 로직 블록 설명
#-------------------------------------------------------------------------------
```

## 안전 옵션

스크립트 상단에 항상 선언:

```bash
set -e          # 에러 시 즉시 종료
set -u          # 미선언 변수 사용 시 에러
set -o pipefail # 파이프 중간 실패 감지
```

## 네이밍 (Bash 전용)

- 함수명: `PascalCase` (`InstallDeps`, `CheckDependency`)
- 지역 변수: `snake_case` + `local` 키워드
- 전역 변수: `SCREAMING_SNAKE_CASE` (환경변수 충돌 방지)
- 상수: `readonly SCREAMING_SNAKE_CASE`

```bash
readonly MAX_RETRY=3
readonly LOG_DIR="/var/log/myapp"

InstallDeps() {
    local pkg_name="$1"
    local install_path="$2"
    # ...
}
```

## 변수 참조

- 변수는 항상 `"${VAR}"` 형식으로 따옴표 감싸기 (단어 분리·글로빙 방지)
- 명령 치환: `$(command)` 사용 (백틱 금지)

```bash
/* BAD */
echo $HOME
result=`ls -la`

/* GOOD */
echo "${HOME}"
result=$(ls -la)
```

## 에러 처리

```bash
#-----------------------------------------------------------------------
# 함수 반환값으로 성공/실패 구분
#-----------------------------------------------------------------------
CheckFile() {
    local path="$1"

    if [ ! -f "${path}" ]; then
        echo "[ERROR] 파일 없음: ${path}" >&2
        return 1
    fi
    return 0
}

CheckFile "${config_path}" || { echo "설정 파일 필요"; exit 1; }
```

## 디버그 출력

```bash
echo "[DEBUG] var=${var}"          # 배포 전 제거
echo "[PROJECTNAME] msg=${msg}" >&2  # 운영 경고 (stderr)
```
