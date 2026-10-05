---
paths:
  - "**/main/**"
  - "**/preload/**"
  - "**/electron*.ts"
  - "**/electron*.js"
  - "**/electron.vite.config.*"
---
# Electron 구조 패턴

> 보안 설정은 [security.md](security.md)가 정본이다. 대용량 수신 구현은 `skills/desktop-data-client/SKILL.md`에 둔다.

## 프로세스 역할 — 한 프로세스에 한 책임

| 프로세스 | 맡는 일 | 하지 않는 일 |
|---|---|---|
| main | 창 수명, 메뉴, IPC 중계, 업데이트, 자식 프로세스 감독 | 소켓 수신·디코딩, 무거운 계산 |
| utility process | 서버 연결, 프레임 재조립·디코딩, 병합, 로컬 저장 | 화면 그리기 |
| renderer | 화면 그리기, 사용자 입력 받기 | Node API, 원시 소켓, 대량 디코딩 |
| preload | renderer에 최소 API 노출 | 상태 보관, 업무 로직 |

- main 이벤트 루프가 막히면 모든 창의 입력과 IPC가 함께 멈춘다. main에는 가벼운 일만 둔다.
- 데이터 수신은 `utilityProcess.fork`로 띄운 별도 프로세스에 둔다. 죽어도 창은 살아 있다.
- 같은 프로세스 안에서 충분하면 `worker_threads`도 된다. 장애 격리가 필요하면 utility process를 고른다.
- renderer는 수신 프로세스와 `MessageChannelMain`으로 직접 연결한다. main을 데이터 경로에 두지 않는다.

```typescript
// main: 수신 프로세스를 띄우고 renderer와 직접 잇는다
const feed = utilityProcess.fork(path.join(__dirname, "feed.js"), [], { serviceName: "feed" });
const { port1, port2 } = new MessageChannelMain();
feed.postMessage({ type: "attach" }, [port1]);
win.webContents.postMessage("feed:port", null, [port2]);
feed.on("exit", (code) => ScheduleFeedRestart(code));   // 지수 백오프로 재기동
```

## 장애 격리와 창별 재시작

- 창마다 `render-process-gone`을 처리한다. 그 창만 다시 로드하고 나머지 창은 건드리지 않는다.
- 수신 프로세스가 죽으면 지수 백오프(1s → 2s → … 최대 30s)로 재기동하고 스냅샷부터 다시 받는다.
- 재시작 횟수가 짧은 시간에 상한을 넘으면 재시작을 멈추고 사용자에게 상태를 보여 준다.
- 응답 없는 창(`unresponsive`)은 시간을 재서 로그로 남긴다. 자동 강제 종료는 사용자 확인 뒤에 한다.
- 화면 상태(열린 창·레이아웃·선택 키)는 주기적으로 저장해 재시작 후 복원한다.

## 장시간 실행 — 메모리 추세 감시

하루 이상 켜 두는 앱은 누수가 장애가 된다. 값 하나가 아니라 **추세**를 본다.

- main에서 `app.getAppMetrics()`로 프로세스별 메모리를 분 단위로 기록한다.
- 수신 프로세스는 `process.memoryUsage()`의 `heapUsed`·`arrayBuffers`·`rss`를 함께 기록한다.
- 같은 부하에서 1시간 동안 계속 오르면 누수로 보고 힙 스냅샷 두 장을 비교한다.
- 임계치를 넘으면 경고를 남기고, 해당 창이나 수신 프로세스를 계획 재시작한다.
- 이벤트 리스너·타이머·`MessagePort`는 창을 닫을 때 해제한다. 닫힌 창을 잡고 있는 참조가 흔한 누수다.

## 화면 갱신 예산

- renderer로 보내는 갱신은 화면 주기(약 16ms)에 한 번으로 묶는다. 메시지마다 보내지 않는다.
- IPC로 큰 객체 그래프를 보내지 않는다. 구조화 복제 비용이 크다. `ArrayBuffer`를 transfer로 넘긴다.
- 동기 IPC(`sendSync`)와 `@electron/remote`는 쓰지 않는다. 둘 다 main을 막는다.

## 빌드·서명·배포

- main·preload·renderer는 진입점별로 빌드한다(`skills/vite-patterns/SKILL.md` 4절).
- macOS는 Developer ID로 서명하고 hardened runtime을 켠 뒤 notarization을 거친다. 서명하지 않은 빌드는 배포하지 않는다.
- Windows는 코드 서명 인증서(EV 또는 클라우드 서명)로 설치 파일과 실행 파일을 모두 서명한다.
- 업데이트 채널(안정·베타)을 나누고, 단계 배포 비율을 둔다. 문제가 생기면 이전 버전으로 되돌린다.
- 서명 키와 notarization 자격 증명은 CI 비밀값으로만 둔다. 저장소에 넣지 않는다.
- 패키지에 소스맵·테스트·개발 의존성을 넣지 않는다. asar 무결성 검증과 함께 배포한다.
