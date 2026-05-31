---
paths:
  - "**/*.py"
  - "**/*.pyi"
---
# Python 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.

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
