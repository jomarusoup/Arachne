---
description: TDD 사이클 진입점 — 실패 테스트 작성부터 메모리 검사까지. tdd 에이전트와 연동.
---
# /tdd [대상 함수·기능 설명]

TDD 워크플로 진입점. `tdd` 에이전트를 활성화하고 Red-Green-Refactor 사이클을 안내한다.

## 실행 흐름

```
1. 프로젝트 유형 감지 → 프레임워크 선택
2. 테스트 파일 위치·네이밍 확인
3. 실패 테스트 작성 (RED)
4. 테스트 실행 → 실패 확인
5. 최소 구현 (GREEN)
6. 테스트 실행 → 통과 확인
7. 리팩터링 (IMPROVE)
8. 메모리 검사 (시스템 코드)
9. 커버리지 확인
```

## 프로젝트 유형 감지

| 감지 조건 | 프레임워크 | 테스트 실행 |
|---|---|---|
| `CMakeLists.txt` + `*.cpp` | Google Test | `ctest --test-dir build` |
| `Makefile` + `*.c` | cmocka / Unity | `make test` |
| `go.mod` | go test | `go test -race ./...` |
| `package.json` | Jest / Vitest | `npm test` |
| `pyproject.toml` / `pytest.ini` | pytest | `pytest` |

## 테스트 파일 네이밍

| 언어 | 규칙 | 예시 |
|---|---|---|
| C | `test_<모듈명>.c` | `test_conn.c` |
| C++ | `<모듈명>_test.cpp` | `conn_test.cpp` |
| Go | `<파일명>_test.go` | `conn_test.go` |
| JavaScript | `<파일명>.test.js` | `conn.test.js` |
| Python | `test_<모듈명>.py` | `test_conn.py` |

## 사용 예시

```
/tdd ConnCreate — NULL 호스트 입력 시 NULL 반환 검증
/tdd ParseHeader — 유효하지 않은 매직 바이트 처리
/tdd UserService.create — 중복 이메일 입력 시 에러 반환
```

## tdd 에이전트 연동

복잡한 TDD 세션은 `tdd` 에이전트에 위임:
- 하드웨어·커널 의존성 격리 전략
- 복잡한 mock/stub 설계
- 커버리지 80%+ 달성 계획
