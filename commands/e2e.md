---
description: E2E 테스트 실행 — 시스템(데몬·IPC) 및 웹(Playwright) 프로젝트 공통 지원.
---
# /e2e [테스트 시나리오]

프로젝트 유형에 따라 적합한 E2E 테스트 플로우를 안내한다.

## 프로젝트 유형 감지

| 감지 조건                         | E2E 방식                  |
| --------------------------------- | ------------------------- |
| `Makefile` / `CMakeLists.txt`     | 시스템 E2E (프로세스·IPC) |
| `playwright.config.*`             | Playwright                |
| `cypress.config.*`                | Cypress                   |
| `package.json` + `"e2e"` 스크립트 | npm e2e                   |

---

## 시스템 E2E — 데몬·IPC

### 절차

```bash
# 1. 빌드 확인
make clean && make

# 2. 데몬 기동
./daemon --config test.conf &
DAEMON_PID=$!

# 3. 준비 대기 (소켓·포트 열릴 때까지)
timeout 10 bash -c 'until [ -S /tmp/test.sock ]; do sleep 0.1; done'

# 4. 기능 검증
./client --test-scenario basic_connect
./client --test-scenario send_receive
./client --test-scenario graceful_shutdown

# 5. 종료 및 정리
kill $DAEMON_PID
wait $DAEMON_PID
rm -f /tmp/test.sock
```

### 실패 시 로그 수집

```bash
# 데몬 로그
cat /var/log/daemon.log || journalctl -u daemon-service -n 50

# 코어 덤프 확인
ls /tmp/core.* 2>/dev/null && gdb ./daemon /tmp/core.* -batch -ex bt

# 시스템 콜 추적
strace -f -o /tmp/e2e_strace.log ./client --test-scenario basic_connect
```

---

## 웹 E2E — Playwright

### 절차

```bash
# 개발 서버 시작 (필요 시)
npm run dev &
DEV_PID=$!

# E2E 실행
npx playwright test

# 특정 시나리오만
npx playwright test tests/auth.spec.ts

# UI 모드 (디버깅)
npx playwright test --ui

# 종료
kill $DEV_PID 2>/dev/null
```

### 실패 시 로그 수집

```bash
# 스크린샷·비디오 (playwright.config에서 설정)
ls test-results/

# 상세 리포트
npx playwright show-report

# 특정 테스트 디버그
npx playwright test --debug tests/failing.spec.ts
```

---

## 3티어 시나리오 — 클라이언트 → C 서버 → DB

클라이언트(웹·Electron), C 서버, DB를 한 번에 검증한다.
환경은 `templates/project/compose-3tier`를 쓴다. 거래 ID 하나로 모든 구간을 확인하는 것이 핵심이다.

```bash
# 1. 기동 — .env 는 .env.example 에서 만들고 값은 로컬 전용으로 바꾼다
docker compose config --quiet
docker compose up c-build                       # C 모듈 테스트(Linux)
docker compose up -d postgres                   # Oracle 도 보려면 --profile oracle

# 2. 스키마 적용 — 미적용 버전만 적용, 실패하면 여기서 멈춘다 (sql-schema-versioning)
docker compose run --rm schema-pg
docker compose --profile server --profile tracing up -d c-server jaeger

# 3. Playwright — 테스트가 요청마다 고정 거래 ID 를 X-Request-Id 로 보낸다
E2E_TXN_PREFIX=T99-E2E npx playwright test                  # 웹
npx playwright test --config playwright.electron.config.ts  # Electron(_electron.launch)

# 4. 거래 ID 로 로그·추적 확인
docker compose logs --no-color c-server > e2e-server.log
tools/logtrace.sh T99-E2E-0001 e2e-server.log   # 서버 구간이 시각순으로 이어지는지
# Jaeger UI(127.0.0.1:16686)에서 app.txn_id=T99-E2E-0001 스팬을 찾는다

# 5. 정리 — 볼륨은 남긴다 (초기화가 필요할 때만 down -v)
docker compose --profile server --profile tracing down
```

- 실패한 테스트의 거래 ID를 보고서에 남긴다. 그 ID로 `logtrace.sh`를 돌리면 어느 구간에서 끊겼는지 보인다.
- 테스트 데이터는 합성 데이터만 쓴다. 운영 덤프를 넣지 않는다.
- 추적 규약은 `distributed-tracing` 스킬, 로그 형식은 `operational-logging` 스킬이 정본이다.

---

## 판정 기준

| 결과           | 조치                                  |
| -------------- | ------------------------------------- |
| 모두 통과      | `/git` 진행 가능                      |
| 일부 실패      | 로그 수집 후 `debugger` 에이전트 활용 |
| 데몬 미기동    | 빌드 오류 확인 → `build-debug` 스킬   |
| 소켓 연결 실패 | `strace` 로 시스템 콜 추적            |
