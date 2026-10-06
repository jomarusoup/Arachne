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

파일 헤더에는 날짜 필드를 두지 않는다(이력은 git이 정본). 함수 헤더는 공개 API와
동작이 자명하지 않은 함수에만 둔다.

```python
################################################################################
# FILE NAME   : 파일명.py
# DESCRIPTION : 파일 역할 한 줄 요약
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

@dataclass(frozen=True)
class ServerConfig:
    host: str
    port: int

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

예외를 바꿔 던질 때는 `raise ... from err`로 원인 컨텍스트를 남긴다.

```python
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
