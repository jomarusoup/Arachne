---
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/pyproject.toml"
  - "**/requirements.txt"
---
# Python 코딩 스타일

> [common/coding-style.md](../common/coding-style.md) 를 확장한다.

## 헤더 형식

`/* */` 미지원 → `#` 문자로 동일한 박스 구조 구성.

```python
################################################################################
# FILE NAME   : 파일명.py
# DESCRIPTION : 파일 역할 한 줄 요약
# DATA        : YYYY-MM-DD
# Modification: YYYY-MM-DD
################################################################################

#===============================================================================
# FUNCTION    : function_name
# DESCRIPTION : 역할 설명
# PARAMETERS  : type 인자명 - 설명
# RETURNED    : 반환값 설명 (없으면 생략)
#===============================================================================

#-------------------------------------------------------------------------------
# 특정 로직 블록 설명
#-------------------------------------------------------------------------------
```

## 표준 및 포매팅

- **PEP 8** 준수
- **black** — 코드 포매팅
- **isort** — 임포트 정렬
- **ruff** — 린팅
- 들여쓰기: **4 스페이스** (공통 규칙 준수)

## 타입 힌트

모든 함수 시그니처에 타입 힌트 필수:

```python
def connect(host: str, port: int) -> bool:
    ...
```

## 불변성

불변 데이터 구조 우선 사용:

```python
from dataclasses import dataclass
from typing import NamedTuple

# 불변 클래스
@dataclass(frozen=True)
class ServerConfig:
    host: str
    port: int

# 불변 튜플 기반 구조체
class Point(NamedTuple):
    x: float
    y: float
```

## 네이밍 (Python 전용)

- 함수·메서드·변수: `snake_case`
- 클래스: `PascalCase`
- 상수: `SCREAMING_SNAKE_CASE`
- 전역 변수: `g_SnakeCase` (공통 규칙 준수)
- private 멤버: `_snake_case` (단일 언더스코어)

## 에러 처리

```python
#-----------------------------------------------------------------------
# 에러 컨텍스트 추가 — raise from
#-----------------------------------------------------------------------
try:
    result = parse_config(path)
except FileNotFoundError as err:
    raise RuntimeError(f"설정 파일 없음: {path}") from err
```

- 빈 `except` 절 금지
- `Exception` 캐치 후 무시 금지

## 디버그 출력

```python
print(f"[DEBUG] value={value}")          # 배포 전 제거
logging.warning(f"[PROJ] msg={msg}")     # 운영 경고
```
