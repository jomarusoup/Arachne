---
name: refactor
description: SRP 기반 리팩터링 절차. 역할 분석 → 분리 계획 → 단계적 이동 → 검증. 언어별 모듈 분리 패턴 포함.
origin: Harness
---

# SRP 기반 리팩터링 워크플로

## 언제 사용하나

- 함수·파일이 여러 역할을 담당할 때
- 800줄 초과 파일을 분리할 때
- 코드 재사용성을 높일 때

## 언제 사용하지 않나

- 버그 수정 — 리팩터링과 분리해서 진행
- 데드 코드 제거만 필요할 때 → `refactor-clean` 커맨드

---

## 리팩터링 원칙

**줄 수가 아닌 역할 기준으로 분리 판단.**

- 50줄 함수라도 역할이 하나면 분리 불필요
- 20줄 함수라도 역할이 셋이면 분리 필요

---

## 절차

### 1. 역할 분석

```bash
# 함수 목록 파악
sgrep "^function \|^func \|^def \|^void \|^int "

# 의존성 파악
sgrep "include\|import\|require"
```

각 함수·섹션이 담당하는 역할을 나열하고, 역할이 2개 이상인 함수를 식별.

### 2. 분리 계획 (planner 에이전트 권장)

파일 3개 이상 수정이 예상되면 `planner` 에이전트에 위임:

```
[REFACTOR PLAN]
대상: 파일명 또는 함수명
현재 역할: [역할 A], [역할 B], [역할 C]
분리 후:
  - 파일/모듈 A: 역할 A 담당
  - 파일/모듈 B: 역할 B 담당
영향 범위: 호출부 N곳 수정 필요
```

### 3. 테스트 기준선 확보

리팩터링 전 현재 동작을 검증하는 테스트 존재 확인:

```bash
make test / go test ./... / npm test / pytest
```

테스트 없으면 핵심 동작에 대한 테스트 먼저 작성.

### 4. 단계적 이동 (한 번에 하나씩)

- 한 함수/섹션씩 이동
- 이동 후 즉시 테스트 실행
- 실패 시 즉시 `git checkout -- <file>` 로 롤백

### 5. 호출부 업데이트

```bash
# 이동된 심볼 참조 전수 확인
sgrep "함수명\|타입명"
```

### 6. 검증

```bash
# 정적 검사
gcc -Wall -Wextra src/*.c / go vet ./... / tsc --noEmit

# 테스트 통과 확인
make test

# 메모리 검사 (시스템 코드)
valgrind --leak-check=full --error-exitcode=1 ./binary
```

---

## 언어별 분리 패턴

### C — 헤더·소스 분리

```
# 전: conn.c (연결 + 파싱 + 로깅 혼재)

# 후:
conn.h / conn.c       — 연결 관리만
parser.h / parser.c   — 파싱만
log.h / log.c         — 로깅만
```

### Go — 패키지 분리

```
# 전: server/server.go (라우팅 + DB + 인증 혼재)

# 후:
server/router.go      — 라우팅만
db/client.go          — DB 접근만
auth/middleware.go    — 인증만
```

### JavaScript/TypeScript — 모듈 분리

```
# 전: app.js (UI + 상태 + API 혼재)

# 후:
ui/renderer.js        — DOM 렌더링만
state/store.js        — 상태 관리만
api/client.js         — API 호출만
```

---

## 완료 체크리스트

- [ ] 각 함수·파일이 단일 역할 담당
- [ ] 모든 테스트 통과
- [ ] 메모리 검사 통과 (시스템 코드)
- [ ] 호출부 전수 업데이트
- [ ] 외부 동작 변화 없음
