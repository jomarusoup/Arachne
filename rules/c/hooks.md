---
paths:
  - "**/*.c"
  - "**/*.h"
---
# C 훅

> [common/hooks.md](../common/hooks.md) 를 확장한다.

## PostToolUse — 편집 후 자동 실행

```bash
# 포맷 (clang-format)
clang-format -i "$FILE"

# 정적 분석
cppcheck --enable=warning,style "$FILE"

# 빌드 확인 (Makefile 존재 시)
[ -f Makefile ] && make -n 2>&1 | head -5
```

## 커밋 전 체크

```bash
# 문법 검사
gcc -fsyntax-only -Wall -Wextra "$FILE"

# 정적 분석
cppcheck --enable=all --error-exitcode=1 src/

# 빌드
make clean && make

# 테스트
make test
```

## 권장 CI 파이프라인

1. `gcc -Wall -Wextra` — 경고 검사
2. `cppcheck` — 정적 분석
3. `make` — 빌드
4. `valgrind` — 메모리 검사
5. `make test` — 테스트 실행
