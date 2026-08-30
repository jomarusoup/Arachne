---
name: c-testing
description: cmocka 기반 C 테스트 전략 — TDD, 링커 --wrap 모킹, 시스템 콜 테스트 더블, valgrind·ASan/TSan 게이팅, Makefile/CMake 통합. C 코드 신규·수정·리팩터링 시 활용.
triggers:
  paths: ["**/*.c", "**/*.h", "**/test_*.c", "**/tests/**/*.c"]
  keywords: ["cmocka", "C 테스트", "--wrap 모킹", "테스트 더블", "valgrind 게이팅"]
---

# C 테스팅 (에이전트 스킬)

cmocka와 링커 트릭(`--wrap`)을 사용하는 C 전용 테스트 워크플로.
GoogleTest 전제인 `cpp-testing`이 커버하지 못하는 순수 C 영역을 담당한다.

> 실행 명령·프레임워크 선정 요약은 `rules/c/testing.md`(자동 로드)가 정본 —
> 이 스킬은 모킹·격리·빌드 통합의 심화 레퍼런스다.

## 언제 사용하나

- 새 C 테스트 작성 또는 기존 테스트 수정
- 시스템 콜·하드웨어 의존 코드의 테스트 더블 설계
- valgrind/ASan/TSan을 CI 게이트로 연결
- 테스트 실패·불안정(flaky) 동작 진단
- Makefile/CMake 테스트 타깃 구성

### 언제 사용하지 않나

- C++ 프로젝트 → `cpp-testing` (GoogleTest/CTest)
- 테스트 변경 없는 기능 구현·리팩터링
- 메모리 도구 자체 사용법 → `memory-check`

## 핵심 개념

- **TDD 루프**: RED → GREEN → REFACTOR (`rules/common/testing.md`의 커버리지 80% 기준 적용)
- **격리 수단 3종**: 함수 포인터 주입 > 링커 `--wrap` > 조건부 컴파일(최후 수단)
- **AAA 패턴**: Arrange-Act-Assert — 테스트 이름은 동작 서술 (`NULL_입력시_에러_반환`)
- **메모리 게이팅**: 단위 테스트 통과 ≠ 완료 — valgrind/ASan 무오류까지가 GREEN

## cmocka 기본

```c
/* tests/test_config.c */
#include <stdarg.h>
#include <stddef.h>
#include <setjmp.h>
#include <cmocka.h>

#include "config.h"

/*=== NULL 입력시 에러 반환 ===*/
static void test_ParseConfig_null_returns_error(void **state)
{
    (void)state;

    /* Arrange-Act */
    int ret = ParseConfig(NULL);

    /* Assert */
    assert_int_equal(ret, CONFIG_ERR_NULL);
}

/*=== setup/teardown 픽스처 ===*/
static int setup_tmpfile(void **state)
{
    /* 테스트별 고유 경로 — 고정 경로 사용 금지 (flaky 원인) */
    char *path = strdup("/tmp/cfg_XXXXXX");
    int fd = mkstemp(path);
    if (fd < 0) { free(path); return -1; }
    close(fd);
    *state = path;
    return 0;
}

static int teardown_tmpfile(void **state)
{
    char *path = *state;
    unlink(path);
    free(path);
    return 0;
}

static void test_LoadConfig_file_ok(void **state)
{
    char *path = *state;
    assert_int_equal(LoadConfig(path), CONFIG_OK);
}

int main(void)
{
    const struct CMUnitTest tests[] = {
        cmocka_unit_test(test_ParseConfig_null_returns_error),
        cmocka_unit_test_setup_teardown(test_LoadConfig_file_ok,
                                        setup_tmpfile, teardown_tmpfile),
    };
    return cmocka_run_group_tests(tests, NULL, NULL);
}
```

## 모킹 전략

### 1순위 — 함수 포인터 주입 (설계 단계에서 격리)

```c
/* 소스가 의존성을 인터페이스로 받게 설계 */
typedef ssize_t (*SendFn)(int fd, const void *buf, size_t len);

int SendMessage(SendFn send_fn, int fd, const char *msg);

/* 테스트: 가짜 구현 주입 */
static ssize_t FakeSendOk(int fd, const void *buf, size_t len)
{
    (void)fd; (void)buf;
    return (ssize_t)len;
}

static void test_SendMessage_ok(void **state)
{
    (void)state;
    assert_int_equal(SendMessage(FakeSendOk, 3, "ping"), 0);
}
```

### 2순위 — 링커 `--wrap` (기존 코드 비침습 모킹)

```c
/* __wrap_malloc: cmocka mock()으로 실패 시나리오 주입 */
void *__real_malloc(size_t size);

void *__wrap_malloc(size_t size)
{
    if (mock_type(int)) {           /* will_return()으로 지정한 값 */
        return NULL;                /* 할당 실패 시뮬레이션 */
    }
    return __real_malloc(size);
}

static void test_CreateNode_malloc_fail_returns_null(void **state)
{
    (void)state;
    will_return(__wrap_malloc, 1);              /* 다음 malloc 실패 */
    assert_null(CreateNode("key"));
}
```

```makefile
# Makefile: wrap 대상 심볼 지정
test_node: test_node.o node.o
	$(CC) -o $@ $^ -lcmocka -Wl,--wrap=malloc -Wl,--wrap=socket
```

### 시스템 콜 더블 — 호출 검증

```c
/* 상호작용 검증: expect_*() + check_expected() */
int __wrap_close(int fd)
{
    check_expected(fd);
    return mock_type(int);
}

static void test_Cleanup_closes_fd(void **state)
{
    (void)state;
    expect_value(__wrap_close, fd, 7);
    will_return(__wrap_close, 0);
    Cleanup(7);
}
```

## 빌드 통합

### Makefile

```makefile
CFLAGS      = -std=c11 -Wall -Wextra -Werror -g
TEST_LIBS   = -lcmocka
TESTS       = test_config test_node

.PHONY: test test-mem
test: $(TESTS)
	@for tt in $(TESTS); do ./$$tt || exit 1; done

# 메모리 게이트 — CI 필수 단계
test-mem: $(TESTS)
	@for tt in $(TESTS); do \
	    valgrind --leak-check=full --error-exitcode=1 ./$$tt || exit 1; \
	done

test_%: tests/test_%.c src/%.c
	$(CC) $(CFLAGS) -Isrc -o $@ $^ $(TEST_LIBS)
```

### CMake/CTest

```cmake
enable_testing()
find_package(cmocka REQUIRED)

add_executable(test_config tests/test_config.c src/config.c)
target_link_libraries(test_config cmocka::cmocka)
add_test(NAME config COMMAND test_config)

# sanitizer 옵션 — 별도 빌드 디렉터리로 (ASan과 TSan은 동시 불가)
option(ENABLE_ASAN "AddressSanitizer" OFF)
if(ENABLE_ASAN)
    add_compile_options(-fsanitize=address -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address)
endif()
```

```bash
ctest --test-dir build --output-on-failure
ctest --test-dir build -R config            # 단일 테스트 재실행
```

## 메모리·동시성 게이팅 (필수)

```bash
# 1) valgrind — 누수·오염 (릴리스 게이트)
valgrind --leak-check=full --error-exitcode=1 ./test_config

# 2) ASan — 힙·스택 오버플로, UAF (개발 중 상시)
gcc -fsanitize=address,undefined -fno-omit-frame-pointer -g -o test_config ...

# 3) TSan — 멀티스레드 코드만 (ASan과 별도 빌드)
gcc -fsanitize=thread -g -o test_config ...
```

순서: **ASan/UBSan 빌드로 개발 → 커밋 전 valgrind → 스레드 코드는 TSan 추가**.
sanitizer 오류가 하나라도 있으면 GREEN이 아니다.

## 커버리지

```bash
gcc --coverage -o test_config tests/test_config.c src/config.c -lcmocka
./test_config
gcov src/config.c                     # 라인 커버리지 (기준 80%+)
lcov --capture --directory . --output-file coverage.info
genhtml coverage.info --output-directory coverage
```

## Flaky 방지 가드레일

- `sleep` 동기화 금지 → 조건 변수·`sem_wait`·파이프 신호 사용
- 임시 파일은 `mkstemp`로 테스트별 고유 생성, teardown에서 반드시 정리
- 단위 테스트에서 실제 시간·네트워크·전역 상태 의존 금지 — 시계는 함수 포인터로 주입
- 랜덤 입력은 고정 시드 (`srand(42)`)
- `--wrap` 모킹은 테스트 바이너리별로 심볼 충돌 확인 (한 바이너리에 한 wrap 정의)

## 실패 진단 절차

1. 실패 테스트 단독 재실행 (`ctest -R <이름>` 또는 단일 바이너리)
2. ASan/UBSan 빌드로 재실행 — 어서션 이전의 메모리 오염 여부 확인
3. cmocka `--verbose` + 어서션 주변 로그 추가
4. 근본 원인 수정 후 전체 스위트 + valgrind 재확인
5. 반복 실패 시 `debugger` 에이전트 활용 (GDB·strace)
