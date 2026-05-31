---
description: 수정 후 문법·동작 2단계 검증 — 커밋 전 필수 실행
---
# /verify — 수정 후 검증

수정할 때마다 반드시 실행. 2단계로 검증한다.

---

## STEP 1 — 정적 검증

프로젝트 유형에 따라 해당 명령 실행:

```bash
# C/C++
gcc -fsyntax-only -Wall -Wextra src/*.c
cppcheck --enable=warning src/

# Go
go build ./... && go vet ./...

# JavaScript / TypeScript
node --check src/js/*.js
tsc --noEmit          # TypeScript

# Python
python -m py_compile src/*.py
ruff check src/

# 공통 — 테스트 실행
make test / go test ./... / npm test / pytest
```

오류가 있으면 STEP 2 진행하지 않고 즉시 수정.

---

## STEP 2 — 런타임 검증

### 웹 프로젝트
`chrome-devtools-mcp` 사용:
1. 파일 열기 / 개발 서버 접속
2. 콘솔 에러 확인 (`list_console_messages`)
3. 핵심 기능 동작 확인
4. 스크린샷

### 시스템 프로그래밍
```bash
# 빌드 후 실행
make && ./binary

# 메모리 검사
valgrind --leak-check=full --error-exitcode=1 ./binary

# 기능 테스트
make test
```

---

## 판정 기준

| 결과               | 조치                   |
| ------------------ | ---------------------- |
| STEP 1 오류        | 즉시 수정 후 재실행    |
| STEP 2 런타임 오류 | 에러 로그 확인 후 수정 |
| 메모리 오류        | valgrind 출력 분석     |
| 모두 통과          | `/git` 진행 가능       |
