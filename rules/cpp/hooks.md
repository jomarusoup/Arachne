---
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.hh"
  - "**/*.cxx"
---
# C++ 훅

> [common/hooks.md](../common/hooks.md) 를 확장한다.

## 커밋 전 체크

```bash
# 포맷 검사
clang-format --dry-run --Werror src/*.cpp src/*.hpp

# 정적 분석
clang-tidy src/*.cpp -- -std=c++17
cppcheck --enable=all src/

# 빌드
cmake --build build

# 테스트 (sanitizer 포함)
ctest --test-dir build --output-on-failure
```

## 권장 CI 파이프라인

1. `clang-format` — 포맷 검사
2. `clang-tidy` — 정적 분석
3. `cppcheck` — 추가 분석
4. `cmake build` — 컴파일
5. `ctest` — sanitizer 포함 테스트 실행
