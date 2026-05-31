---
paths:
  - "**/*.c"
  - "**/*.h"
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

## cmocka 예시

```c
#include <stdarg.h>
#include <stddef.h>
#include <setjmp.h>
#include <cmocka.h>

/*=============================================================================
FUNCTION    : test_ConnCreate_NullHost
DESCRIPTION : NULL 호스트 입력 시 NULL 반환 검증
=============================================================================*/
static void test_ConnCreate_NullHost(void **state)
{
    (void)state;
    Conn_t *conn = ConnCreate(NULL, 8080);
    assert_null(conn);
}

/*=============================================================================
FUNCTION    : test_ConnSend_ValidData
DESCRIPTION : 유효한 데이터 전송 시 성공 반환 검증
=============================================================================*/
static void test_ConnSend_ValidData(void **state)
{
    Conn_t *conn = (Conn_t *)*state;
    const char msg[] = "hello";
    int ret = ConnSend(conn, msg, sizeof(msg));
    assert_int_equal(ret, 0);
}

int main(void)
{
    const struct CMUnitTest tests[] = {
        cmocka_unit_test(test_ConnCreate_NullHost),
        cmocka_unit_test_setup_teardown(
            test_ConnSend_ValidData, setup, teardown),
    };
    return cmocka_run_group_tests(tests, NULL, NULL);
}
```

## 커버리지

```bash
gcc --coverage -o test_binary tests/*.c src/*.c
./test_binary
gcov src/*.c
lcov --capture --directory . --output-file coverage.info
genhtml coverage.info --output-directory coverage_html
```
