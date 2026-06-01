---
name: memory-check
description: valgrind·AddressSanitizer·ThreadSanitizer 메모리 검사 실행 절차. 메모리 누수·오염·레이스 컨디션 검출.
---

# 메모리 검사 워크플로

## 언제 사용하나

- 메모리 누수·Use-After-Free 의심 시
- 레이스 컨디션 의심 시
- 커밋 전 메모리 안전성 검증 시
- CI 파이프라인 메모리 검사 단계

## 언제 사용하지 않나

- 웹/Python 코드 → 해당 언어 도구 사용
- 성능 프로파일링 → `massif` 또는 `perf`

---

## valgrind memcheck — 메모리 누수·오염

```bash
valgrind \
    --leak-check=full \
    --track-origins=yes \
    --show-leak-kinds=all \
    --error-exitcode=1 \
    ./binary [args]
```

### 출력 해석

| 메시지 | 의미 | 조치 |
|---|---|---|
| `definitely lost` | 명확한 메모리 누수 | 즉시 수정 |
| `possibly lost` | 잠재적 누수 | 확인 후 수정 |
| `Invalid read/write` | 범위 밖 접근 | 즉시 수정 |
| `Use of uninitialised` | 미초기화 변수 | 즉시 수정 |
| `All heap blocks freed` | 누수 없음 | 통과 |

## AddressSanitizer (ASan) — 빠른 컴파일 타임 검사

```bash
# 빌드 시 활성화
gcc -fsanitize=address -fsanitize=undefined -g -o binary src/*.c

# 실행 (자동 오류 감지)
./binary [args]

# CMake 통합
cmake -DCMAKE_C_FLAGS="-fsanitize=address,undefined" -B build
cmake --build build
ctest --test-dir build
```

## ThreadSanitizer (TSan) — 레이스 컨디션

```bash
# 빌드
gcc -fsanitize=thread -g -o binary src/*.c

# 실행
./binary [args]

# ASan과 동시 사용 불가 (별도 빌드 필요)
```

## valgrind helgrind — 레이스 컨디션 (대안)

```bash
valgrind --tool=helgrind ./binary [args]
```

## valgrind massif — 힙 프로파일링

```bash
valgrind --tool=massif ./binary [args]
ms_print massif.out.PID | head -60
```

## 검사 체크리스트

```bash
# 1. ASan 빠른 검사
gcc -fsanitize=address,undefined -g -o binary src/*.c && ./binary

# 2. valgrind 상세 검사
valgrind --leak-check=full --error-exitcode=1 ./binary

# 3. 레이스 컨디션 (멀티스레드 코드만)
gcc -fsanitize=thread -g -o binary src/*.c && ./binary

# 4. 테스트 전체에 적용
valgrind --leak-check=full --error-exitcode=1 ./test_binary
```
