---
name: python-patterns
description: 강력하고 효율적이며 유지 보수하기 쉬운 Python 애플리케이션을 위한 이디엄틱 패턴·PEP 8·타입 힌트·모범 사례. 서버를 시스템 프로그래밍으로 전환하기 전 메모리·자원 관리 사고를 Python에서 미리 익히는 데 활용.
triggers:
  paths: ["**/*.py"]
  keywords: ["Python", "이디엄", "타입 힌트", "컨텍스트 매니저", "EAFP"]
---

# Python 개발 패턴

강력하고 효율적이며 유지 보수하기 쉬운 애플리케이션을 위한 이디엄틱 Python 패턴.

## 언제 활성화하나

- 새 Python 코드 작성
- Python 코드 검토·리팩터링
- Python 패키지/모듈 설계
- Python 서버를 시스템(C/Rust)으로 전환하기 전 자원·메모리 패턴 학습

## 핵심 원칙

### 1. 가독성이 최우선

Python은 영리함보다 명확함을 선호한다. 코드는 보면 바로 이해돼야 한다.

```python
# 올바름: 명확하고 읽기 쉬움
def get_active_users(users: list[User]) -> list[User]:
    """활성 사용자만 반환한다."""
    return [user for user in users if user.is_active]

# 잘못됨: 영리하지만 혼란스러움
def get_active_users(u):
    return [x for x in u if x.a]
```

### 2. 명시가 암시보다 낫다

마법을 피하고, 코드가 무엇을 하는지 분명히 한다.

```python
# 올바름: 명시적 설정
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

# 잘못됨: 숨겨진 부작용
import some_module
some_module.setup()   # 이게 뭘 하는지 알 수 없음
```

### 3. EAFP — 허락보다 용서가 쉽다

Python은 조건 검사보다 예외 처리를 선호한다.

```python
# 올바름: EAFP 스타일
def get_value(dictionary: dict, key: str, default: Any) -> Any:
    try:
        return dictionary[key]
    except KeyError:
        return default

# 잘못됨: LBYL (검사 먼저) 스타일 — TOCTOU 레이스 가능
def get_value(dictionary: dict, key: str, default: Any) -> Any:
    if key in dictionary:
        return dictionary[key]
    return default
```

## 타입 힌트

### 기본 애너테이션

```python
from typing import Any, Optional

def process_user(
    user_id: str,
    data: dict[str, Any],
    active: bool = True,
) -> Optional[User]:
    """사용자를 처리하고 갱신된 User 또는 None을 반환한다."""
    if not active:
        return None
    return User(user_id, data)
```

### 모던 타입 힌트 (Python 3.9+)

```python
# Python 3.9+ — 내장 제네릭 사용
def process_items(items: list[str]) -> dict[str, int]:
    return {item: len(item) for item in items}

# Python 3.10+ — 유니온은 | 로
def first(items: list[str]) -> str | None:
    return items[0] if items else None
```

### 타입 별칭과 TypeVar

```python
from typing import TypeVar, Union

# 복잡한 타입에 별칭 부여
JSON = Union[dict[str, Any], list[Any], str, int, float, bool, None]

def parse_json(data: str) -> JSON:
    return json.loads(data)

# 제네릭
T = TypeVar("T")

def first(items: list[T]) -> T | None:
    return items[0] if items else None
```

### Protocol 기반 덕 타이핑

```python
from typing import Protocol

class Renderable(Protocol):
    def render(self) -> str: ...

def render_all(items: list[Renderable]) -> str:
    """Renderable 프로토콜을 구현한 항목을 모두 렌더링한다."""
    return "\n".join(item.render() for item in items)
```

## 에러 처리 패턴

### 구체적 예외 처리

```python
# 올바름: 구체적 예외 캐치 + 컨텍스트 체이닝
def load_config(path: str) -> Config:
    try:
        with open(path) as f:
            return Config.from_json(f.read())
    except FileNotFoundError as err:
        raise ConfigError(f"설정 파일 없음: {path}") from err
    except json.JSONDecodeError as err:
        raise ConfigError(f"설정 JSON 오류: {path}") from err

# 잘못됨: bare except — 조용한 실패
def load_config(path: str) -> Config:
    try:
        with open(path) as f:
            return Config.from_json(f.read())
    except:
        return None   # 무엇이 왜 실패했는지 알 수 없음
```

### 커스텀 예외 계층

```python
class AppError(Exception):
    """모든 애플리케이션 에러의 베이스."""

class ValidationError(AppError):
    """입력 검증 실패."""

class NotFoundError(AppError):
    """요청한 리소스가 없음."""

def get_user(user_id: str) -> User:
    user = db.find_user(user_id)
    if not user:
        raise NotFoundError(f"사용자 없음: {user_id}")
    return user
```

## 컨텍스트 매니저 — 자원 관리

`with`는 시스템 프로그래밍의 `goto cleanup`/RAII에 대응한다. 모든 경로에서 자원 해제를 보장하는 사고를 Python에서 먼저 익힌다.

```python
# 올바름: 컨텍스트 매니저 — 예외 경로에서도 close 보장
def process_file(path: str) -> str:
    with open(path) as f:
        return f.read()

# 잘못됨: 수동 관리 — 예외 시 누수
def process_file(path: str) -> str:
    f = open(path)
    data = f.read()
    f.close()       # 위에서 예외 나면 도달 안 함
    return data
```

### 커스텀 컨텍스트 매니저

```python
from contextlib import contextmanager
import time

@contextmanager
def timer(name: str):
    """코드 블록 실행 시간을 측정한다."""
    start = time.perf_counter()
    try:
        yield
    finally:
        elapsed = time.perf_counter() - start
        print(f"{name}: {elapsed:.4f}s")

with timer("data processing"):
    process_large_dataset()
```

### 트랜잭션 컨텍스트 매니저

```python
class DatabaseTransaction:
    def __init__(self, connection):
        self.connection = connection

    def __enter__(self):
        self.connection.begin_transaction()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if exc_type is None:
            self.connection.commit()
        else:
            self.connection.rollback()
        return False   # 예외를 삼키지 않음

with DatabaseTransaction(conn):
    user = conn.create_user(user_data)
    conn.create_profile(user.id, profile_data)
```

## 컴프리헨션과 제너레이터

### 컴프리헨션은 단순할 때만

```python
# 올바름: 단순 변환
names = [user.name for user in users if user.is_active]

# 잘못됨: 과도하게 복잡 → 제너레이터 함수로
result = [x * 2 for x in items if x > 0 if x % 2 == 0]
```

### 제너레이터 — 지연 평가·대용량 데이터

대용량을 한 번에 메모리에 올리지 않는 사고는 시스템 코드의 스트리밍 처리와 동일하다.

```python
# 잘못됨: 100만 항목 중간 리스트 생성
total = sum([x * x for x in range(1_000_000)])

# 올바름: 제너레이터 — 메모리 일정
total = sum(x * x for x in range(1_000_000))

# 올바름: 파일을 한 줄씩 — 메모리 일정
def read_large_file(path: str) -> Iterator[str]:
    with open(path) as f:
        for line in f:
            yield line.strip()
```

## 데이터 클래스와 NamedTuple

### 불변 데이터 클래스

```python
from dataclasses import dataclass, field
from datetime import datetime

@dataclass(frozen=True)   # 불변 — 숨은 부작용 방지
class User:
    id: str
    name: str
    email: str
    created_at: datetime = field(default_factory=datetime.now)
    is_active: bool = True
```

### 검증이 있는 데이터 클래스

```python
@dataclass(frozen=True)
class UserInput:
    email: str
    age: int

    def __post_init__(self):
        if "@" not in self.email:
            raise ValueError(f"잘못된 이메일: {self.email}")
        if not 0 <= self.age <= 150:
            raise ValueError(f"잘못된 나이: {self.age}")
```

### NamedTuple — 가벼운 불변 구조체

```python
from typing import NamedTuple

class Point(NamedTuple):
    x: float
    y: float

    def distance(self, other: "Point") -> float:
        return ((self.x - other.x) ** 2 + (self.y - other.y) ** 2) ** 0.5
```

## 데코레이터

### 함수 데코레이터 — `functools.wraps` 필수

```python
import functools
import time
from typing import Callable

def timer(func: Callable) -> Callable:
    @functools.wraps(func)   # 메타데이터 보존
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        print(f"{func.__name__}: {time.perf_counter() - start:.4f}s")
        return result
    return wrapper
```

### 파라미터화 데코레이터

```python
def repeat(times: int):
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            return [func(*args, **kwargs) for _ in range(times)]
        return wrapper
    return decorator

@repeat(times=3)
def greet(name: str) -> str:
    return f"Hello, {name}!"
```

## 동시성 패턴 — 작업 종류로 선택

| 작업 종류 | 도구 | 이유 |
| --------- | ---- | ---- |
| I/O 바운드 | `ThreadPoolExecutor` / `asyncio` | GIL 해제 구간이라 병렬 효과 |
| CPU 바운드 | `ProcessPoolExecutor` | GIL 우회 — 별도 프로세스 |
| 다수 동시 I/O | `asyncio.gather` | 단일 스레드 이벤트 루프 |

```python
import asyncio

# 다수 동시 I/O — async/await
async def fetch_all(urls: list[str]) -> dict[str, str]:
    tasks = [fetch_async(url) for url in urls]
    results = await asyncio.gather(*tasks, return_exceptions=True)
    return dict(zip(urls, results))
```

```python
import concurrent.futures

# CPU 바운드 — 멀티프로세싱
def process_all(datasets: list[list[int]]) -> list[int]:
    with concurrent.futures.ProcessPoolExecutor() as executor:
        return list(executor.map(process_data, datasets))
```

## 메모리·성능

### `__slots__` — 메모리 절약

대량 인스턴스 시 `__dict__`를 제거해 메모리를 줄인다. 시스템 코드의 구조체 패킹 사고와 같다.

```python
# 올바름: __slots__ 로 인스턴스당 메모리 절감
class Point:
    __slots__ = ("x", "y")

    def __init__(self, x: float, y: float):
        self.x = x
        self.y = y
```

### 루프 내 문자열 결합 금지

```python
# 잘못됨: 문자열 불변성 때문에 O(n²)
result = ""
for item in items:
    result += str(item)

# 올바름: O(n) — join
result = "".join(str(item) for item in items)
```

## 패키지 구성

### 표준 레이아웃

```
myproject/
├── src/mypackage/
│   ├── __init__.py
│   ├── main.py
│   ├── api/routes.py
│   ├── models/user.py
│   └── utils/helpers.py
├── tests/
│   ├── conftest.py
│   └── test_*.py
├── pyproject.toml
└── README.md
```

### 임포트 순서 (isort 자동화)

```python
# 1. 표준 라이브러리
import os
from pathlib import Path

# 2. 서드파티
import requests
from fastapi import FastAPI

# 3. 프로젝트 내부
from mypackage.models import User
from mypackage.utils import format_name
```

## 도구 통합

```bash
black .            # 포매팅
isort .            # 임포트 정렬
ruff check .       # 린팅
mypy .             # 타입 검사
bandit -r .        # 보안 스캔
pip-audit          # 의존성 취약점
pytest --cov=mypackage --cov-report=term-missing   # 테스트·커버리지
```

```toml
# pyproject.toml 핵심 설정
[tool.black]
line-length = 88

[tool.ruff]
line-length = 88
select = ["E", "F", "I", "N", "W"]

[tool.mypy]
warn_return_any = true
disallow_untyped_defs = true
```

## 피해야 할 안티패턴

```python
# 가변 기본 인자 → 호출 간 상태 공유
def append_to(item, items=[]):       # BAD
    items.append(item)
    return items

def append_to(item, items=None):     # GOOD
    if items is None:
        items = []
    items.append(item)
    return items

# type() 비교 → isinstance
if type(obj) == list:    # BAD
    ...
if isinstance(obj, list):  # GOOD
    ...

# None 비교 → is
if value == None:   # BAD
    ...
if value is None:   # GOOD
    ...

# from module import * → 명시적 임포트
from os.path import *          # BAD
from os.path import join, exists   # GOOD
```

## 빠른 참조

| 이디엄 | 용도 |
| ------ | ---- |
| EAFP | 조건 검사보다 예외 처리 |
| 컨텍스트 매니저 | `with`로 자원 관리 (RAII 대응) |
| 컴프리헨션 | 단순 변환 |
| 제너레이터 | 지연 평가·대용량 스트리밍 |
| dataclass(frozen) | 불변 데이터 컨테이너 |
| `__slots__` | 메모리 최적화 |
| f-string | 문자열 포매팅 (3.6+) |
| `pathlib.Path` | 경로 연산 |

> **기억할 것**: Python 코드는 읽기 쉽고 명시적이며 "최소 놀람 원칙"을 따라야 한다. 의심스러우면 영리함보다 명확함을 택한다.
