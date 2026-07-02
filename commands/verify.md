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

---

## STEP 3 — 리포트 기록 (`.arachne/reports/`)

판정 후 결과를 프로젝트에 영속화한다. **통과·실패와 무관하게 기록한다** —
실패 리포트가 회귀 비교에 가장 가치 있다. 정책 정본은 `docs/PROJECT-CI.md`.

- **대상**: `.arachne/` 디렉터리가 있는 프로젝트만. 없으면 기록을 생략하고
  `리포트 미기록 (arachne init-ci 로 활성화)` 한 줄만 보고한다.
- **경로**: `.arachne/reports/$(date +%F-%H%M)-verify.md` (`mkdir -p` 로 생성)
- **불변**: 기존 리포트는 수정·삭제하지 않는다. 정리는 사람이 별도 커밋으로.
- **커밋**: 리포트는 커밋 대상이다 — 다음 `/git`에서 코드 변경과 함께 커밋된다.

### 리포트 형식 (frontmatter 필드 고정)

```markdown
---
Title: "[verify] <검증 범위 한 줄>"
creation: YYYY-MM-DD
type: verify
result: pass | fail
branch: <git branch --show-current>
commit: <git rev-parse --short HEAD — 검증 시점 HEAD>
scope: "<검증한 변경 파일·기능 요약>"
---

# [verify] <검증 범위 한 줄>

## STEP 1 — 정적 검증

| 명령 | 결과 |
| --- | --- |
| <실행한 명령> | pass / fail |

## STEP 2 — 동작 검증

| 항목 | 결과 |
| --- | --- |
| <확인한 동작> | pass / fail |

## 실패·조치 (실패 시에만)

- 원인:
- 조치:
- 재검증: <수정 후 재실행한 리포트 파일명>
```
