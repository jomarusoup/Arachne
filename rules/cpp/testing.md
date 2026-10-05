---
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.hh"
  - "**/*.cxx"
---
# C++ 테스팅

> [common/testing.md](../common/testing.md) 를 확장한다.

## 프레임워크

**GoogleTest** (gtest/gmock) + **CMake/CTest**.

## 테스트 실행

```bash
cmake --build build && ctest --test-dir build --output-on-failure
```

## Sanitizer 포함 테스트

```bash
cmake -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined" ..
cmake --build build
ctest --test-dir build --output-on-failure
```

## 커버리지

```bash
cmake -DCMAKE_CXX_FLAGS="--coverage" -DCMAKE_EXE_LINKER_FLAGS="--coverage" ..
cmake --build .
ctest --output-on-failure
lcov --capture --directory . --output-file coverage.info
genhtml coverage.info --output-directory coverage_html
```

## GoogleTest 예시

```cpp
#include <gtest/gtest.h>
#include <gmock/gmock.h>

class MockTransport : public ITransport
{
public:
    MOCK_METHOD(int, Send, (const void *data, size_t len), (override));
};

TEST(ServerTest, SendReturnZeroOnSuccess)
{
    auto mock = std::make_unique<MockTransport>();
    EXPECT_CALL(*mock, Send(testing::_, testing::_)).WillOnce(testing::Return(0));

    Server server(std::move(mock), nullptr);
    EXPECT_EQ(server.Send("hello", 5), 0);
}
```

## 퍼징 (libFuzzer)

외부 입력을 해석하는 코드는 퍼징이 필수다. 프레임 디코더·프로토콜 파서·설정 파서가 해당한다.

- 진입점은 `extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)`이다.
- 하네스 안에서 예외를 삼키지 않는다. 파서가 예외를 던지는 설계면 예상한 예외 타입만 잡는다.
- ASan·UBSan과 함께 빌드하고, 찾은 크래시 입력은 코퍼스에 넣어 회귀 테스트로 남긴다.

```bash
clang++ -g -O1 -std=c++20 -fsanitize=fuzzer,address,undefined \
    -o fuzz_frame tests/fuzz_frame.cpp src/frame_codec.cpp
./fuzz_frame -max_total_time=60 tests/corpus/frame/
```

## 차분 테스트

같은 입력 벡터를 두 구현에 넣고 출력을 비교한다.

- 비교 대상은 참조 구현 vs 최적화 구현, 변경 전 vs 변경 후, C vs C++ vs Rust 구현이다.
- 입력 벡터는 `tests/vectors/` 파일로 고정한다. GoogleTest의 `TEST_P`로 벡터마다 한 케이스를 만든다.
- 퍼징 하네스에서 두 구현의 결과가 다르면 `abort()`한다. 이것이 차분 퍼징이다.

## 장애 주입

에러 경로는 장애를 주입해 검증한다. 정상 경로만 통과한 테스트는 미완료다.

- 1순위는 인터페이스 주입이다. 전송·파일 계층을 인터페이스로 받고 gmock으로 실패를 돌려준다.
- libc 호출을 직접 쓰는 코드는 링커 `-Wl,--wrap=write`로 감싼다(GNU ld 전용).
- 반드시 다룰 장애: 부분 쓰기, `EINTR`, `ENOSPC`, 할당 실패(`std::bad_alloc`), 연결 끊김.
- 예시는 `cpp-testing` 스킬의 "퍼징·차분·장애 주입" 절에 있다.
