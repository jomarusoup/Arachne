---
paths:
  - "**/*.py"
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

## 포매팅

- `black` 포매터 적용 — 커밋 전 `black <파일>` 실행
- `isort` 임포트 정렬

## 중괄호 스타일 — 해당 없음 (들여쓰기로 블록 구분)

- 들여쓰기: **4 스페이스** (공통 규칙 준수, 탭 금지)

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
- `Exception` 만 캐치하고 무시하는 패턴 금지

## 타입 힌트

- 함수 시그니처에 타입 힌트 필수
- `mypy` 또는 `pyright` 로 정적 검사

```python
def connect(host: str, port: int) -> bool:
    ...
```

## 디버그 출력

```python
print(f"[DEBUG] value={value}")        # 배포 전 제거
logging.warning(f"[PROJ] msg={msg}")   # 운영 경고
```
