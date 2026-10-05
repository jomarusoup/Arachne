---
paths:
  - "**/*.py"
  - "**/*.pyi"
---
# Python 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.

## 불변성 (매우 중요)

항상 새로운 객체를 생성하고, 기존 객체를 절대 변경하지 마십시오.

```
# Pseudocode
WRONG:  modify(original, field, value) → changes original in-place
CORRECT: update(original, field, value) → returns new copy with change
```

근거: 불변 데이터는 숨겨진 부작용을 방지하고, 디버깅을 용이하게 하며, 안전한 동시성을 가능하게 합니다.

```python
# BAD: 변이
user["name"] = "new"
items.append(new_item)

# GOOD: 새 객체 생성
user  = {**user, "name": "new"}
items = [*items, new_item]

# frozen dataclass 는 dataclasses.replace() 로 갱신
updated = dataclasses.replace(config, timeout=30)
```

## Protocol (덕 타이핑)

```python
from typing import Protocol

class Repository(Protocol):
    def find_by_id(self, id: str) -> dict | None: ...
    def save(self, entity: dict) -> dict: ...
```

## Dataclass DTO

```python
from dataclasses import dataclass

@dataclass
class CreateUserRequest:
    name:  str
    email: str
    age:   int | None = None
```

## Context Manager — 자원 관리

```python
from contextlib import contextmanager

@contextmanager
def open_connection(host: str, port: int):
    conn = connect(host, port)
    try:
        yield conn
    finally:
        conn.close()

with open_connection("localhost", 8080) as conn:
    conn.send(b"hello")
```

## 제너레이터 — 지연 평가

```python
def read_lines(path: str):
    with open(path) as f:
        for line in f:
            yield line.rstrip()
```

## 의존성 주입

```python
class UserService:
    def __init__(self, repo: UserRepository, logger: logging.Logger) -> None:
        self._repo   = repo
        self._logger = logger
```
