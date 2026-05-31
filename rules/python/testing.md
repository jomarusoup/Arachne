---
paths:
  - "**/*.py"
  - "**/*.pyi"
---
# Python 테스팅

> [common/testing.md](../common/testing.md) 를 확장한다.

## 프레임워크

**pytest** 사용.

## 테스트 실행

```bash
pytest                                      # 전체 테스트
pytest --cov=src --cov-report=term-missing  # 커버리지
pytest -x                                   # 첫 실패 시 중단
pytest -k "test_connect"                    # 특정 테스트
```

## 테스트 분류

```python
import pytest

@pytest.mark.unit
def test_parse_header():
    ...

@pytest.mark.integration
def test_database_connection():
    ...
```

## Fixture

```python
@pytest.fixture
def server(tmp_path):
    cfg = Config(sock_path=str(tmp_path / "test.sock"))
    srv = Server(cfg)
    yield srv
    srv.stop()

def test_server_accepts_connection(server):
    conn = connect(server.sock_path)
    assert conn is not None
```

## 모킹

```python
from unittest.mock import MagicMock, patch

def test_send_calls_transport():
    mock_transport = MagicMock()
    service = Service(transport=mock_transport)
    service.send(b"data")
    mock_transport.write.assert_called_once_with(b"data")
```
