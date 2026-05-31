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
