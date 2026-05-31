---
description: SRP 기반 리팩터링 — 역할 분석 → planner 설계 → 단계적 이동 → 검증. 언어별 모듈 분리 패턴.
---
# /refactor [대상 파일·함수·모듈]

SRP(단일 책임 원칙) 기반 리팩터링 워크플로.
**줄 수가 아닌 역할로 분리 여부를 판단한다.**

## 실행 흐름

```
1. 역할 분석 — 대상의 책임 목록 작성
2. 분리 계획 — 파일 3개 이상 수정 시 planner 에이전트 연동
3. 테스트 기준선 확보
4. 단계적 이동 — 한 번에 하나씩
5. 검증 — 정적 검사 + 테스트 + 메모리 검사
```

## 분리 판단 기준

```bash
# 역할 파악: 함수 목록 확인
sgrep "^function \|^func \|^void \|^int \|^static "

# 의존성 파악
sgrep "#include\|import\|require"
```

**분리 필요:** 함수·파일이 2개 이상의 관심사(데이터 접근 + 비즈니스 로직, 렌더링 + 상태 관리 등)를 담당할 때

## planner 에이전트 연동

파일 3개 이상 수정이 예상되면 먼저 계획 수립:

```
[REFACTOR PLAN]
대상: 파일명
현재 역할: [역할 A], [역할 B]
분리 후:
  - 신규 파일 A: 역할 A
  - 신규 파일 B: 역할 B
호출부 수정: N곳
```

## 테스트 기준선 확보

```bash
make test / go test ./... / npm test / pytest
```

테스트 없으면 핵심 동작에 대한 테스트 먼저 작성 (`/tdd` 사용).

## 단계적 이동

- 한 함수·섹션씩 이동
- 이동 후 즉시 테스트 실행
- 실패 시 즉시 롤백: `git checkout -- <file>`

## 언어별 분리 패턴

### C — 헤더·소스 분리

```
전: conn.c (연결 + 파싱 + 로깅)
후:
  conn.h / conn.c     — 연결 관리
  parser.h / parser.c — 메시지 파싱
  log.h / log.c       — 로깅
```

### Go — 패키지 분리

```
전: server/server.go (라우팅 + DB + 인증)
후:
  server/router.go    — 라우팅
  db/client.go        — DB 접근
  auth/middleware.go  — 인증
```

### JavaScript / TypeScript — 모듈 분리

```
전: app.js (UI + 상태 + API)
후:
  ui/renderer.js   — DOM 렌더링
  state/store.js   — 상태 관리
  api/client.js    — API 호출
```

## 검증

```bash
# 정적 검사
gcc -Wall -Wextra src/*.c / go vet ./... / tsc --noEmit

# 테스트 통과
make test / go test ./... / npm test

# 메모리 검사 (시스템 코드)
valgrind --leak-check=full --error-exitcode=1 ./binary

# 호출부 전수 확인
sgrep "이동된함수명\|이동된타입명"
```

## 완료 체크리스트

- [ ] 각 함수·파일이 단일 역할만 담당
- [ ] 모든 테스트 통과
- [ ] 호출부 전수 업데이트 완료
- [ ] 외부 동작 변화 없음
- [ ] 메모리 검사 통과 (시스템 코드)
