# 테스팅 규칙

## 최소 커버리지: 80%

## 테스트 유형 (모두 필요)

1. **단위 테스트** — 함수·모듈 단위 격리 검증
2. **통합 테스트** — API, DB, IPC 등 연동 검증
3. **E2E 테스트** — 핵심 사용자 플로우·시스템 시나리오
4. **메모리 테스트** — 누수·오염·레이스 컨디션 검증 (시스템 프로그래밍)

## TDD 워크플로 (필수)

```
1. 실패하는 테스트 작성 (RED)
2. 테스트 실행 → 실패 확인
3. 최소 구현으로 통과 (GREEN)
4. 테스트 실행 → 통과 확인
5. 리팩터링 (IMPROVE)
6. 커버리지 80%+ 확인
```

## AAA 패턴

테스트는 Arrange-Act-Assert 구조로 작성:

```
// Arrange: 테스트 조건 설정
// Act: 동작 실행
// Assert: 결과 검증
```

## 테스트 네이밍

동작을 설명하는 이름 사용:

- `연결_실패시_재시도_3회`
- `NULL_입력시_에러_반환`
- `버퍼_초과시_경계_보호`

## 메모리·동시성 테스트

시스템 프로그래밍 코드에서 필수:

```bash
# valgrind — 메모리 누수·오염
valgrind --leak-check=full --error-exitcode=1 ./test_binary

# AddressSanitizer — 컴파일 타임 메모리 검사
gcc -fsanitize=address -o test_binary test.c && ./test_binary

# ThreadSanitizer — 레이스 컨디션
gcc -fsanitize=thread -o test_binary test.c && ./test_binary
```

## 테스트 실패 대응

1. `tdd` 에이전트 활용
2. 테스트 격리 확인
3. 모킹 정확성 검증
4. 구현 수정 (테스트는 마지막 수단으로만 수정)
