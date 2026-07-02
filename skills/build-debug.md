---
name: build-debug
description: C/C++ 빌드·디버그 워크플로. make/cmake 빌드 오류 해결, GDB 디버그 세션, 바이너리 검증 절차.
triggers:
  paths: ["Makefile", "**/*.mk"]
  keywords: ["빌드 실패", "GDB", "디버그", "링크 에러", "segfault"]
---

# C/C++ 빌드·디버그 워크플로

## 언제 사용하나

- C/C++ 빌드 오류 발생 시
- GDB로 런타임 오류·세그폴트 추적 시
- 바이너리 빌드 후 초기 검증 시

## 언제 사용하지 않나

- 메모리 누수 분석 → `memory-check` 스킬 사용
- 성능 프로파일링 → `perf` 또는 `debugger` 에이전트
- 빌드와 무관한 로직 버그 → `debugger` 에이전트

---

## 빌드 워크플로

### make 기반

```bash
# 클린 빌드
make clean && make

# 디버그 심볼 포함
make CFLAGS="-g -O0 -Wall -Wextra"

# 특정 타깃만
make target_name

# 빌드 오류 첫 30줄 확인
make 2>&1 | head -30
```

### cmake 기반

```bash
# 설정
cmake -B build -S . -DCMAKE_BUILD_TYPE=Debug

# 빌드
cmake --build build --parallel

# 빌드 오류 상세 출력
cmake --build build --verbose 2>&1 | tail -30

# 클린 재빌드
cmake --build build --clean-first
```

## 빌드 오류 진단

```bash
# 문법 검사만 (컴파일 없이)
gcc -fsyntax-only -Wall -Wextra src/*.c

# 정적 분석
cppcheck --enable=all --error-exitcode=1 src/
clang-tidy src/*.cpp -- -std=c++17

# 링커 오류 — undefined reference
nm -u ./binary | head -20           # 미정의 심볼 확인
ldd ./binary                         # 동적 라이브러리 의존성
```

## GDB 디버그 세션

```bash
# 디버그 빌드
gcc -g -O0 -o binary src/*.c

# 기본 디버그
gdb ./binary

# 자주 쓰는 명령
(gdb) run [args]
(gdb) backtrace         # 크래시 후 스택 확인
(gdb) frame 2           # 특정 프레임으로 이동
(gdb) list              # 소스 코드 확인
(gdb) print var         # 변수 출력
(gdb) break func        # 브레이크포인트
(gdb) continue
(gdb) quit
```

## 바이너리 검증

```bash
# 실행 권한 확인
ls -la binary

# 공유 라이브러리 확인
ldd binary

# 심볼 확인
nm -D binary | grep " T "   # 공개 함수 목록

# 기본 실행 테스트
./binary --help 2>&1 || echo "exit: $?"
```
