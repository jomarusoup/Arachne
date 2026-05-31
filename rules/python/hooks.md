---
paths:
  - "**/*.py"
  - "**/*.pyi"
---
# Python 훅

> [common/hooks.md](../common/hooks.md) 를 확장한다.

## PostToolUse — 편집 후 자동 실행

- **black / ruff** — `.py` 파일 편집 후 자동 포맷
- **mypy / pyright** — 편집 후 타입 검사

## 경고

- 편집된 파일에서 `print()` 감지 시 경고 (`logging` 모듈 사용 권장)

## 커밋 전 체크

```bash
black --check src/
ruff check src/
mypy src/
pytest --tb=short
```
