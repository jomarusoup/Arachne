---
paths:
  - "**/*.c"
  - "**/*.h"
  - "**/*.pc"
  - "**/*.pgc"
---
# C 테스팅

> [common/testing.md](../common/testing.md) 를 확장한다.

## 프레임워크

**cmocka** (단위 테스트 + 모킹) 또는 **Unity** 사용.

## 테스트 실행

```bash
# 빌드 및 테스트
make test

# valgrind — 메모리 누수 검사
valgrind --leak-check=full --track-origins=yes --error-exitcode=1 ./test_binary

# AddressSanitizer
gcc -fsanitize=address -o test_binary tests/*.c && ./test_binary

# ThreadSanitizer (멀티스레드 코드)
gcc -fsanitize=thread -o test_binary tests/*.c && ./test_binary
```

## cmocka·커버리지

- 테스트 함수는 `test_<대상>_<조건>` 이름으로 짓고, 픽스처는 `cmocka_unit_test_setup_teardown`으로 건다.
- 커버리지는 `gcc --coverage` 빌드 후 `gcov`·`lcov`로 측정한다.
- 예시 코드(픽스처·`--wrap` 모킹·커버리지 명령)는 `c-testing` 스킬의 "cmocka 기본"·"커버리지" 절에 있다.

## 퍼징 (libFuzzer)

외부 입력을 해석하는 코드는 퍼징이 필수다. 프레임 디코더·프로토콜 파서·설정 파서가 해당한다.

- 하네스 하나가 공개 함수 하나를 부른다. 판정 기준은 크래시와 새니타이저 보고다.
- ASan·UBSan과 함께 빌드한다. 찾은 크래시 입력은 코퍼스에 넣어 회귀 테스트로 남긴다.
- CI는 짧게 돌리고(`-max_total_time=60`), 긴 실행은 야간 작업으로 돌린다.

```bash
clang -g -O1 -fsanitize=fuzzer,address,undefined \
    -o fuzz_frame tests/fuzz_frame.c src/frame_codec.c
./fuzz_frame -max_total_time=60 -max_len=65536 tests/corpus/frame/
```

## 차분 테스트

같은 입력 벡터를 두 구현에 넣고 출력을 비교한다.

- 비교 대상은 참조 구현 vs 최적화 구현, 변경 전 vs 변경 후, C vs Rust 이식본이다.
- 입력 벡터는 `tests/vectors/` 파일로 고정해 두 구현이 공유한다. 퍼징 코퍼스를 재사용해도 된다.
- 퍼징 하네스에서 두 구현을 함께 부르고 결과가 다르면 `abort()`한다. 이것이 차분 퍼징이다.

## 장애 주입

에러 경로는 장애를 주입해 검증한다. 정상 경로만 통과한 테스트는 미완료다.

| 장애 | 주입 방법 | 확인할 동작 |
|---|---|---|
| 부분 쓰기 | `__wrap_write`가 요청보다 적게 씀 | 남은 바이트를 이어서 씀 |
| `EINTR` | 첫 호출이 -1·`EINTR` | 재시도하고 데이터를 잃지 않음 |
| `ENOSPC` | `__wrap_write`·`__wrap_fsync` 실패 | 에러를 반환하고 부분 파일을 정리 |
| 할당 실패 | `__wrap_malloc`이 N번째 호출에 NULL | 누수 없이 정리 경로를 탐 |

- 래퍼는 링커 `-Wl,--wrap=write`로 건다. GNU ld 전용이므로 macOS에서는 함수 포인터 주입을 쓴다.
- 하네스·래퍼 예시는 `c-testing` 스킬의 "퍼징·차분·장애 주입" 절에 있다.
