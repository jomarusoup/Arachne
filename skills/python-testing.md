---
name: python-testing
description: pytest 기반 Python 테스트 전략 — TDD, 픽스처, 모킹, 파라미터화, async 테스트, 커버리지 80%+ 기준. 신규 코드·버그 수정·리팩터링 시 활용.
triggers:
  paths: ["**/test_*.py", "**/tests/**/*.py"]
  keywords: ["pytest", "fixture", "autospec 모킹", "async 테스트"]
---

# Python 테스트 패턴

pytest와 TDD 방법론에 기반한 Python 테스트 전략.

## 언제 활성화하나

- 새 Python 코드 작성 (RED → GREEN → REFACTOR)
- 테스트 스위트 설계
- 테스트 커버리지 검토
- 테스트 인프라 구성

## 핵심 철학 — TDD

```
1. RED      — 원하는 동작에 대한 실패 테스트 작성
2. GREEN    — 통과시킬 최소 구현
3. REFACTOR — 테스트 녹색 유지하며 개선
```

```python
# 1. 실패 테스트 (RED)
def test_add_numbers():
    assert add(2, 3) == 5

# 2. 최소 구현 (GREEN)
def add(a: int, b: int) -> int:
    return a + b
```

### 커버리지 기준

- **목표**: 80%+
- **핵심 경로**: 100% 필수

```bash
pytest --cov=mypackage --cov-report=term-missing --cov-report=html
```

## pytest 기본

### 구조 — AAA 패턴

```python
def test_string_uppercase():
    text = "hello"            # Arrange
    result = text.upper()     # Act
    assert result == "HELLO"  # Assert
```

### 예외 테스트

```python
# 예외 발생 확인
with pytest.raises(ValueError):
    validate_input("invalid")

# 메시지 매칭
with pytest.raises(ValueError, match="invalid input"):
    validate_input("invalid")

# 예외 속성 확인
with pytest.raises(CustomError) as exc_info:
    raise CustomError("error", code=400)
assert exc_info.value.code == 400
```

## 픽스처

### 기본 + setup/teardown

```python
import pytest

@pytest.fixture
def database():
    # setup
    db = Database(":memory:")
    db.create_tables()
    yield db          # 테스트에 제공
    # teardown
    db.close()

def test_database_query(database):
    result = database.query("SELECT * FROM users")
    assert len(result) > 0
```

### 스코프 — 비용에 맞춰 선택

```python
@pytest.fixture                      # function (기본) — 테스트마다
def temp_file(): ...

@pytest.fixture(scope="module")      # 모듈당 1회
def module_db(): ...

@pytest.fixture(scope="session")     # 세션당 1회 — 고비용 자원
def shared_resource(): ...
```

### autouse + conftest.py 공유 픽스처

```python
# tests/conftest.py — 모든 테스트가 공유
import pytest

@pytest.fixture(autouse=True)
def reset_config():
    """매 테스트 전 자동 실행 — 테스트 간 상태 격리."""
    Config.reset()
    yield
    Config.cleanup()

@pytest.fixture
def client():
    app = create_app(testing=True)
    with app.test_client() as client:
        yield client
```

## 파라미터화 — 테이블 드리븐

```python
@pytest.mark.parametrize("text,expected", [
    ("hello", "HELLO"),
    ("world", "WORLD"),
    ("PyThOn", "PYTHON"),
])
def test_uppercase(text, expected):
    assert text.upper() == expected

# 읽기 쉬운 ID 부여
@pytest.mark.parametrize("email,valid", [
    ("valid@email.com", True),
    ("invalid", False),
    ("@no-domain.com", False),
], ids=["valid-email", "missing-at", "missing-domain"])
def test_email_validation(email, valid):
    assert is_valid_email(email) is valid
```

## 마커와 테스트 선택

```python
@pytest.mark.slow
def test_slow_operation(): ...

@pytest.mark.integration
def test_api_integration(): ...
```

```bash
pytest -m "not slow"            # 빠른 테스트만
pytest -m integration          # 통합 테스트만
pytest -m "unit and not slow"  # 조합
```

```ini
# pytest.ini — 마커 등록
[pytest]
markers =
    slow: 느린 테스트
    integration: 통합 테스트
    unit: 단위 테스트
```

## 모킹과 패칭

### 함수·반환값·예외 모킹

```python
from unittest.mock import patch, Mock

@patch("mypackage.external_api_call")
def test_with_mock(api_mock):
    api_mock.return_value = {"status": "success"}
    result = my_function()
    api_mock.assert_called_once()
    assert result["status"] == "success"

# 예외 주입
@patch("mypackage.api_call")
def test_api_error(api_mock):
    api_mock.side_effect = ConnectionError("Network error")
    with pytest.raises(ConnectionError):
        api_call()
```

### autospec — API 오용 탐지

```python
# 실제 시그니처와 다른 호출을 잡아냄
@patch("mypackage.DBConnection", autospec=True)
def test_autospec(db_mock):
    db = db_mock.return_value
    db.query("SELECT * FROM users")
    db_mock.assert_called_once()
```

> 모킹 원칙: **외부 의존성만** 모킹한다. 내부 구현을 모킹하면 리팩터링에 깨지는 brittle 테스트가 된다.

## async 코드 테스트

```python
import pytest

@pytest.mark.asyncio
async def test_async_function():
    result = await async_add(2, 3)
    assert result == 5

# async 모킹 — assert_awaited_once
@pytest.mark.asyncio
@patch("mypackage.async_api_call")
async def test_async_mock(api_mock):
    api_mock.return_value = {"status": "ok"}
    result = await my_async_function()
    api_mock.assert_awaited_once()
```

## 파일·임시 경로 — 내장 픽스처 사용

```python
# 올바름: tmp_path — 자동 정리, 수동 cleanup 불필요
def test_with_tmp_path(tmp_path):
    test_file = tmp_path / "test.txt"
    test_file.write_text("hello world")
    assert process_file(str(test_file)) == "hello world"
```

## 테스트 조직

```
tests/
├── conftest.py        # 공유 픽스처
├── unit/              # 단위 — 격리된 로직
├── integration/       # 통합 — API·DB·IPC
└── e2e/               # 핵심 사용자 플로우
```

```python
# 클래스로 관련 테스트 그룹화
class TestUserService:
    @pytest.fixture(autouse=True)
    def setup(self):
        self.service = UserService()

    def test_create_user(self):
        user = self.service.create_user("Alice")
        assert user.name == "Alice"
```

## 모범 사례

**DO**
- TDD 준수 (RED → GREEN → REFACTOR)
- 한 테스트는 한 동작만 검증
- 서술적 이름: `test_login_with_invalid_credentials_fails`
- 픽스처로 중복 제거, 외부 의존성 모킹
- 엣지 케이스 테스트 (빈 입력·None·경계값)
- 80%+ 커버리지, 마커로 느린 테스트 분리

**DON'T**
- 구현이 아닌 동작 테스트
- 테스트 간 상태 공유 금지 (독립성 유지)
- 서드파티 코드 테스트 금지
- 테스트에서 예외 catch 대신 `pytest.raises`
- 과도하게 구체적인 모킹(brittle) 금지

## 흔한 패턴

### API 엔드포인트 (FastAPI/Flask)

```python
@pytest.fixture
def client():
    app = create_app(testing=True)
    return app.test_client()

def test_create_user(client):
    response = client.post("/api/users", json={
        "name": "Alice", "email": "alice@example.com",
    })
    assert response.status_code == 201
    assert response.json["name"] == "Alice"
```

### DB 연산 — 롤백 격리

```python
@pytest.fixture
def db_session():
    session = Session(bind=engine)
    session.begin_nested()
    yield session
    session.rollback()   # 테스트 간 격리
    session.close()
```

## 실행 명령

```bash
pytest                       # 전체
pytest tests/test_utils.py   # 특정 파일
pytest -v                    # 상세 출력
pytest -x                    # 첫 실패에서 중단
pytest --lf                  # 마지막 실패만 재실행
pytest -k "test_user"        # 패턴 매칭
pytest --pdb                 # 실패 시 디버거
pytest --cov=mypackage --cov-report=html   # 커버리지
```

## 빠른 참조

| 패턴 | 용도 |
| ---- | ---- |
| `pytest.raises()` | 예외 테스트 |
| `@pytest.fixture` | 재사용 픽스처 |
| `@pytest.mark.parametrize` | 다중 입력 테이블 드리븐 |
| `@patch(autospec=True)` | API 오용 탐지 모킹 |
| `tmp_path` | 자동 정리 임시 경로 |
| `@pytest.mark.asyncio` | async 테스트 |
| `pytest --cov` | 커버리지 리포트 |

> **기억할 것**: 테스트도 코드다. 깨끗하고 읽기 쉽게 유지한다. 좋은 테스트는 버그를 잡고, 훌륭한 테스트는 버그를 예방한다.
