---
name: cpp-testing
description: C++ 테스트 작성·수정·수정, GoogleTest/CTest 설정, 실패·불안정 테스트 진단, 커버리지·sanitizer 추가 시에만 사용.
triggers:
  paths: ["**/*.cpp", "**/*.hpp"]
  keywords: ["GoogleTest", "CTest", "sanitizer", "C++ 테스트"]
---

# C++ 테스팅 (에이전트 스킬)

CMake/CTest와 함께 GoogleTest/GoogleMock을 사용하는 현대 C++ (C++17/20) 에이전트 중심 테스팅 워크플로.

## 언제 사용하나

- 새 C++ 테스트 작성 또는 기존 테스트 수정
- C++ 컴포넌트 단위/통합 테스트 커버리지 설계
- 테스트 커버리지, CI 게이팅, 회귀 방지 추가
- CMake/CTest 워크플로 일관된 실행 설정
- 테스트 실패 또는 불안정 동작 조사
- 메모리/레이스 진단을 위한 sanitizer 활성화

### 언제 사용하지 않나

- 테스트 변경 없는 신규 기능 구현
- 테스트 커버리지나 실패와 무관한 대규모 리팩터링
- 테스트 회귀 없는 성능 튜닝
- C++ 이외 프로젝트 또는 테스트 무관 태스크

## 핵심 개념

- **TDD 루프**: red → green → refactor (테스트 먼저, 최소 수정, 정리)
- **격리**: 전역 상태 대신 의존성 주입과 페이크 선호
- **테스트 레이아웃**: `tests/unit`, `tests/integration`, `tests/testdata`
- **목 vs 페이크**: 상호작용에는 목, 상태 있는 동작에는 페이크
- **CTest 탐색**: 안정적인 테스트 탐색을 위해 `gtest_discover_tests()` 사용

## TDD 워크플로

RED → GREEN → REFACTOR 루프:

1. **RED**: 새 동작을 포착하는 실패하는 테스트 작성
2. **GREEN**: 통과시키는 최소한의 변경 구현
3. **REFACTOR**: 테스트를 유지하면서 정리

```cpp
// tests/add_test.cpp
#include <gtest/gtest.h>

int Add(int a, int b);

TEST(AddTest, AddsTwoNumbers) {  // RED
    EXPECT_EQ(Add(2, 3), 5);
}

// src/add.cpp
int Add(int a, int b) {  // GREEN
    return a + b;
}
```

## 코드 예시

### 기본 단위 테스트 (gtest)

```cpp
#include <gtest/gtest.h>

TEST(CalculatorTest, AddsTwoNumbers) {
    EXPECT_EQ(Add(2, 3), 5);
}
```

### 픽스처 (gtest)

```cpp
class UserStoreTest : public ::testing::Test {
protected:
    void SetUp() override {
        store = std::make_unique<UserStore>(":memory:");
        store->Seed({{"alice"}, {"bob"}});
    }
    std::unique_ptr<UserStore> store;
};

TEST_F(UserStoreTest, FindsExistingUser) {
    auto user = store->Find("alice");
    ASSERT_TRUE(user.has_value());
    EXPECT_EQ(user->name, "alice");
}
```

### 목 (gmock)

```cpp
class MockNotifier : public Notifier {
public:
    MOCK_METHOD(void, Send, (const std::string &message), (override));
};

TEST(ServiceTest, SendsNotifications) {
    MockNotifier notifier;
    Service service(notifier);
    EXPECT_CALL(notifier, Send("hello")).Times(1);
    service.Publish("hello");
}
```

### CMake/CTest 빠른 시작

```cmake
cmake_minimum_required(VERSION 3.20)
project(example LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)

include(FetchContent)
set(GTEST_VERSION v1.17.0)
FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/refs/tags/${GTEST_VERSION}.zip
)
FetchContent_MakeAvailable(googletest)

add_executable(example_tests
    tests/calculator_test.cpp
    src/calculator.cpp
)
target_link_libraries(example_tests GTest::gtest GTest::gmock GTest::gtest_main)

enable_testing()
include(GoogleTest)
gtest_discover_tests(example_tests)
```

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j
ctest --test-dir build --output-on-failure
```

## 테스트 실행

```bash
ctest --test-dir build --output-on-failure
ctest --test-dir build -R ClampTest
./build/example_tests --gtest_filter=CalculatorTest.*
./build/example_tests --gtest_filter=UserStoreTest.FindsExistingUser
```

## 실패 디버깅

1. gtest 필터로 실패한 단일 테스트 재실행
2. 실패 단언 주변에 범위 로깅 추가
3. sanitizer 활성화 후 재실행
4. 근본 원인 수정 후 전체 스위트로 확장

## 커버리지

```cmake
option(ENABLE_COVERAGE "커버리지 플래그 활성화" OFF)

if(ENABLE_COVERAGE)
    target_compile_options(example_tests PRIVATE --coverage)
    target_link_options(example_tests PRIVATE --coverage)
endif()
```

GCC + gcov + lcov:

```bash
cmake -S . -B build-cov -DENABLE_COVERAGE=ON
cmake --build build-cov -j
ctest --test-dir build-cov
lcov --capture --directory build-cov --output-file coverage.info
lcov --remove coverage.info '/usr/*' --output-file coverage.info
genhtml coverage.info --output-directory coverage
```

## Sanitizer

```cmake
option(ENABLE_ASAN "AddressSanitizer 활성화" OFF)
option(ENABLE_UBSAN "UndefinedBehaviorSanitizer 활성화" OFF)
option(ENABLE_TSAN "ThreadSanitizer 활성화" OFF)

if(ENABLE_ASAN)
    add_compile_options(-fsanitize=address -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address)
endif()
if(ENABLE_UBSAN)
    add_compile_options(-fsanitize=undefined)
    add_link_options(-fsanitize=undefined)
endif()
if(ENABLE_TSAN)
    add_compile_options(-fsanitize=thread)
    add_link_options(-fsanitize=thread)
endif()
```

## 불안정 테스트 가드레일

- 동기화에 `sleep` 사용 금지; 조건 변수 또는 래치 사용
- 임시 디렉토리는 테스트별 고유하게 생성하고 항상 정리
- 단위 테스트에서 실제 시간·네트워크·파일시스템 의존성 금지
- 무작위 입력에는 결정론적 시드 사용

## 모범 사례

**해야 할 것:**
- 테스트를 결정론적이고 격리된 상태로 유지
- 전역 변수 대신 의존성 주입 선호
- 전제조건에는 `ASSERT_*`, 다중 확인에는 `EXPECT_*`
- CTest 레이블 또는 디렉토리로 단위 vs 통합 분리
- CI에서 메모리 및 레이스 감지를 위해 sanitizer 실행

**하지 말아야 할 것:**
- 단위 테스트에서 실제 시간이나 네트워크 의존
- 조건 변수를 사용할 수 있을 때 sleep 동기화
- 단순 값 객체 과도한 목킹
- 중요하지 않은 로그에 취약한 문자열 매칭

## 대안

- **Catch2**: 헤더 전용, 표현적 매처
- **doctest**: 경량, 최소 컴파일 오버헤드
- **cmocka**: 순수 C 프로젝트용
