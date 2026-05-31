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

## 판정 기준

| 결과           | 조치                                  |
| -------------- | ------------------------------------- |
| 모두 통과      | `/git` 진행 가능                      |
| 일부 실패      | 로그 수집 후 `debugger` 에이전트 활용 |
| 데몬 미기동    | 빌드 오류 확인 → `build-debug` 스킬   |
| 소켓 연결 실패 | `strace` 로 시스템 콜 추적            |
