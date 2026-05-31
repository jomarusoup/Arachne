---
name: python-patterns
description: 강력하고 효율적이며 유지 보수하기 쉬운 Python 애플리케이션을 구축하기 위한 파이썬닉 이디엄·PEP 8 표준·타입 힌트·모범 사례.
origin: ECC
---

# Python 개발 패턴

깔끔하고 유지 보수하기 쉬운 Python 코드를 위한 파이썬닉 이디엄과 모범 사례.

## 언제 활성화하나

- 새 Python 코드 작성
- Python 코드 검토
- 더 파이썬닉하게 리팩터링
- Python 프로젝트 구조 설정

## 핵심 원칙

### 1. PEP 8 및 PEP 20 (Zen of Python) 준수

```python
# 올바름: 명확하고, 명시적이고, 읽기 쉬움
def calculate_total(items: list[Item]) -> Decimal:
    return sum(item.price * item.quantity for item in items)

# 잘못됨: 불명확하고 암묵적
def calc(x):
    return sum(i.p * i.q for i in x)
```

### 2. 타입 힌트 사용 (PEP 484+)

```python
# 올바름: 완전히 타입화
def process_user(user_id: int, name: str) -> dict[str, Any]:
    return {"id": user_id, "name": name}

# 현대 유니온 구문 (Python 3.10+)
def find_user(id: int) -> User | None:
    ...
```

### 3. 컴포지션과 명시성 선호

```python
# 올바름: 명시적 의존성
class OrderService:
    def __init__(self, db: Database, cache: Cache) -> None:
        self._db = db
        self._cache = cache
```

## 타입 힌트

### 포괄적 타입 힌트

```python
from typing import Any, Callable, TypeVar
from collections.abc import Sequence, Mapping, Iterator

# 기본 타입
def greet(name: str) -> str:
    return f"Hello, {name}"

# 컬렉션 (Python 3.9+)
def process(items: list[int]) -> dict[str, int]:
    return {"count": len(items)}

# Optional과 Union (3.10+ 구문)
def find(id: int) -> User | None:
    ...

# Callable
Handler = Callable[[Request], Response]

# 제네릭을 위한 TypeVar
T = TypeVar("T")
def first(items: Sequence[T]) -> T | None:
    return items[0] if items else None
```

### 제네릭 (Python 3.12+)

```python
# 새로운 제네릭 구문
class Container[T]:
    def __init__(self, item: T) -> None:
        self._item = item

    def get(self) -> T:
        return self._item

def first[T](items: list[T]) -> T | None:
    return items[0] if items else None
```

## 데이터클래스와 모델

### 데이터클래스

```python
from dataclasses import dataclass, field

@dataclass
class Point:
    x: float
    y: float

    def distance(self, other: "Point") -> float:
        return ((self.x - other.x) ** 2 + (self.y - other.y) ** 2) ** 0.5

@dataclass(frozen=True)  # 불변
class Config:
    debug: bool = False
    timeout: int = 30
    tags: list[str] = field(default_factory=list)
```

### Pydantic 모델

```python
from pydantic import BaseModel, Field, validator

class User(BaseModel):
    id: int
    name: str = Field(..., min_length=1, max_length=100)
    email: str
    age: int = Field(ge=0, le=150)

    @validator("email")
    def validate_email(cls, v: str) -> str:
        if "@" not in v:
            raise ValueError("유효하지 않은 이메일")
        return v
```

## 에러 처리

### 예외 계층

```python
class AppError(Exception):
    """기본 애플리케이션 예외."""

class NotFoundError(AppError):
    """리소스 없음."""

class ValidationError(AppError):
    """검증 실패."""

# 사용
def get_user(id: int) -> User:
    user = db.query(id)
    if user is None:
        raise NotFoundError(f"User {id} not found")
    return user
```

### 컨텍스트별 예외

```python
try:
    result = risky_operation()
except (ValueError, KeyError) as e:
    logger.error(f"작업 실패: {e}")
    raise ProcessingError("처리 실패") from e
finally:
    cleanup()
```

## 비동기 패턴

### Async/Await

```python
import asyncio

async def fetch_data(url: str) -> dict:
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.json()

async def fetch_all(urls: list[str]) -> list[dict]:
    tasks = [fetch_data(url) for url in urls]
    return await asyncio.gather(*tasks)
```

### 비동기 컨텍스트 매니저

```python
class AsyncResource:
    async def __aenter__(self):
        await self.connect()
        return self

    async def __aexit__(self, *args):
        await self.disconnect()

async def use_resource():
    async with AsyncResource() as res:
        await res.process()
```

## 함수형 패턴

### 컴프리헨션

```python
# 리스트 컴프리헨션
squares = [x**2 for x in range(10)]

# 딕셔너리 컴프리헨션
user_map = {user.id: user for user in users}

# 셋 컴프리헨션
unique_tags = {tag for post in posts for tag in post.tags}

# 제너레이터 표현식 (메모리 효율적)
total = sum(x**2 for x in range(1000000))
```

### 고차 함수

```python
from functools import reduce, partial, lru_cache

# 메모이제이션을 위한 lru_cache
@lru_cache(maxsize=128)
def fibonacci(n: int) -> int:
    if n < 2:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

# 부분 적용을 위한 partial
def multiply(x: int, y: int) -> int:
    return x * y

double = partial(multiply, 2)
```

## 컨텍스트 매니저

```python
from contextlib import contextmanager

@contextmanager
def timer(name: str):
    start = time.time()
    try:
        yield
    finally:
        elapsed = time.time() - start
        print(f"{name} took {elapsed:.2f}s")

# 사용
with timer("processing"):
    process_data()
```

## 테스팅 패턴

포괄적인 테스팅 패턴은 `python-testing` 스킬 참고.

## 성능

### 내장 함수 사용

```python
# 올바름: 내장 함수는 최적화되어 있음
total = sum(numbers)
maximum = max(numbers)

# 잘못됨: 수동 루프
total = 0
for n in numbers:
    total += n
```

## 패키지 구조

```
mypackage/
├── __init__.py
├── __main__.py          # python -m mypackage 진입점
├── core/
│   ├── __init__.py
│   ├── models.py
│   └── services.py
├── utils/
│   ├── __init__.py
│   └── helpers.py
└── tests/
    ├── __init__.py
    └── test_core.py
```

## 빠른 참조

| 패턴 | 사용 케이스 |
|---|---|
| Dataclass | 단순 데이터 컨테이너 |
| Pydantic | 검증 및 직렬화 |
| Protocol | 구조적 타이핑/인터페이스 |
| Context manager | 자원 관리 |
| Generator | 메모리 효율적 반복 |
| `lru_cache` | 메모이제이션 |
| Comprehension | 컬렉션 변환 |

## 피해야 할 안티패턴

```python
# 잘못됨: 가변 기본 인자
def add_item(item, items=[]):  # 위험!
    items.append(item)
    return items

# 올바름: None 사용
def add_item(item, items: list | None = None):
    if items is None:
        items = []
    items.append(item)
    return items

# 잘못됨: 빈 except
try:
    risky()
except:  # KeyboardInterrupt까지 모든 것을 잡음
    pass

# 올바름: 특정 예외
try:
    risky()
except ValueError as e:
    handle(e)

# 잘못됨: type()으로 타입 검사
if type(obj) == dict:  # isinstance 사용
    ...

# 올바름: isinstance
if isinstance(obj, dict):
    ...
```

---

**기억**: 명시적이고, 읽기 쉽고, 커뮤니티 컨벤션을 따르는 파이썬닉 코드를 작성한다. 의심스러울 때는 PEP 8과 Zen of Python을 따른다.
