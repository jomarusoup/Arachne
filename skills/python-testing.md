---
name: python-testing
description: pytest·TDD 방법론·픽스처·모킹·파라미터화·커버리지 요구사항을 활용한 Python 테스팅 전략.
origin: ECC
---

# Python 테스팅 패턴

TDD 방법론을 따르는 pytest 기반 포괄적 Python 테스팅.

## 언제 활성화하나

- Python 코드 테스트 작성
- pytest 인프라 설정
- 픽스처 또는 목 추가
- 테스트 커버리지 개선
- 비동기 코드 테스트

## 핵심 원칙

### 1. 테스트 구조 (AAA 패턴)

```python
def test_calculate_total():
    # Arrange (준비)
    items = [Item(price=10, quantity=2), Item(price=5, quantity=3)]

    # Act (실행)
    total = calculate_total(items)

    # Assert (검증)
    assert total == 35
```

### 2. 테스트 네이밍

```python
# 패턴: test_<함수>_<시나리오>
def test_parse_config_valid_file():
    ...

def test_parse_config_missing_file():
    ...

def test_parse_config_invalid_json():
    ...
```

## Pytest 픽스처

```python
import pytest

@pytest.fixture
def sample_user() -> User:
    return User(id=1, name="Alice", email="alice@example.com")

@pytest.fixture
def db_session():
    session = create_session()
    yield session
    session.rollback()
    session.close()

# 파라미터가 있는 픽스처
@pytest.fixture(params=["sqlite", "postgres"])
def database(request):
    db = create_db(request.param)
    yield db
    db.cleanup()

# 사용
def test_user_creation(sample_user, db_session):
    db_session.add(sample_user)
    assert db_session.query(User).count() == 1
```

### 픽스처 스코프

```python
@pytest.fixture(scope="function")  # 기본값: 테스트마다
def function_fixture():
    ...

@pytest.fixture(scope="module")  # 모듈당 한 번
def module_fixture():
    ...

@pytest.fixture(scope="session")  # 테스트 세션당 한 번
def session_fixture():
    ...
```

## 모킹과 패칭

```python
from unittest.mock import Mock, patch, MagicMock

# Mock 객체
def test_with_mock():
    mock_db = Mock()
    mock_db.query.return_value = [User(id=1)]

    service = UserService(mock_db)
    users = service.get_all()

    assert len(users) == 1
    mock_db.query.assert_called_once()

# Patch 데코레이터
@patch("mymodule.external_api")
def test_with_patch(mock_api):
    mock_api.return_value = {"status": "ok"}
    result = call_external()
    assert result["status"] == "ok"

# Patch 컨텍스트 매니저
def test_with_context():
    with patch("mymodule.get_time") as mock_time:
        mock_time.return_value = 12345
        assert get_timestamp() == 12345
```

### 비동기 함수 모킹

```python
from unittest.mock import AsyncMock

@pytest.mark.asyncio
async def test_async_service():
    mock_client = AsyncMock()
    mock_client.fetch.return_value = {"data": "value"}

    service = DataService(mock_client)
    result = await service.get_data()

    assert result == {"data": "value"}
    mock_client.fetch.assert_awaited_once()
```

## 파라미터화 테스트

```python
@pytest.mark.parametrize("input,expected", [
    (2, 4),
    (3, 9),
    (4, 16),
    (5, 25),
])
def test_square(input, expected):
    assert square(input) == expected

# 여러 파라미터
@pytest.mark.parametrize("a,b,expected", [
    (1, 2, 3),
    (0, 0, 0),
    (-1, 1, 0),
])
def test_add(a, b, expected):
    assert add(a, b) == expected

# id가 있는 파라미터
@pytest.mark.parametrize("value,expected", [
    pytest.param(1, True, id="positive"),
    pytest.param(0, False, id="zero"),
    pytest.param(-1, False, id="negative"),
])
def test_is_positive(value, expected):
    assert is_positive(value) == expected
```

## 비동기 테스팅

```python
import pytest

@pytest.mark.asyncio
async def test_async_fetch():
    result = await fetch_data("http://example.com")
    assert result is not None

# 비동기 픽스처
@pytest.fixture
async def async_client():
    client = await create_client()
    yield client
    await client.close()
```

## 커버리지

```bash
# 커버리지 포함 실행
pytest --cov=mypackage

# HTML 리포트 생성
pytest --cov=mypackage --cov-report=html

# 임계값 미만 시 실패
pytest --cov=mypackage --cov-fail-under=80

# 누락된 라인 표시
pytest --cov=mypackage --cov-report=term-missing
```

## 테스트 구성

```
tests/
├── conftest.py          # 공유 픽스처
├── unit/
│   ├── test_models.py
│   └── test_services.py
├── integration/
│   └── test_api.py
└── e2e/
    └── test_workflows.py
```

## 데이터베이스 테스팅

```python
@pytest.fixture
def test_db():
    """깨끗한 테스트 데이터베이스 제공."""
    db = create_test_database()
    yield db
    db.drop_all()
```

## 속성 기반 테스팅

```python
from hypothesis import given, strategies as st

@given(st.lists(st.integers()))
def test_sort_idempotent(lst):
    assert sorted(sorted(lst)) == sorted(lst)

@given(st.text())
def test_encode_decode_roundtrip(s):
    assert decode(encode(s)) == s
```

## 빠른 참조

| 명령 | 용도 |
|---|---|
| `pytest` | 전체 테스트 실행 |
| `pytest -v` | 상세 출력 |
| `pytest -k "name"` | 일치하는 테스트 실행 |
| `pytest -x` | 첫 실패 시 중단 |
| `pytest --lf` | 마지막 실패 재실행 |
| `pytest -m marker` | 마크된 테스트 실행 |
| `pytest --cov` | 커버리지 포함 |
| `pytest -n auto` | 병렬 (pytest-xdist) |

## 피해야 할 안티패턴

```python
# 잘못됨: 구현 세부사항 테스트
def test_internal_state():
    obj = MyClass()
    assert obj._private_var == 5  # private 상태 테스트 금지

# 올바름: 공개 동작 테스트
def test_public_behavior():
    obj = MyClass()
    assert obj.calculate() == 10

# 잘못됨: 상호 의존적인 테스트
def test_step_one():
    global state
    state = setup()

# 올바름: 픽스처로 독립적인 테스트
def test_independent(fixture):
    result = process(fixture)
    assert result.valid

# 잘못됨: 과도한 모킹
def test_overmocked():
    # 모든 것을 모킹하면 테스트가 무의미해짐
    ...
```

---

**기억**: 구현이 아닌 동작을 테스트한다. 테스트를 독립적이고, 빠르고, 읽기 쉽게 유지한다.
