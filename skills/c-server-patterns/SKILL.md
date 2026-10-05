---
name: c-server-patterns
description: Linux C 서버 골격 — epoll 이벤트 루프(LT·ET 선택, 논블로킹 fd, EINTR·EAGAIN), 모듈 수명(불투명 핸들 + ops 테이블, 초기화 순서와 역순 해제), signalfd 시그널 처리(SIGTERM 종료·SIGHUP 재적재와 로그 재오픈·SIGCHLD 회수), 마스터·워커 fork 구조와 fork 후 정리(DB 연결·스레드·공유메모리), 무중단 설정 재적재, graceful shutdown 순서, 공유메모리·DB·로그 모듈 경계. 대상 경로 — **/*.c, **/*.h, **/*.pc, **/*.pgc. 키워드 — C 서버, epoll 루프, signalfd, graceful shutdown, 마스터 워커, fork 후 정리, 설정 재적재.
---

# C 서버 구조 (Linux)

C 데몬 서버를 짜는 표준 골격이다. 핵심은 세 가지다.
첫째, 모든 이벤트(소켓·시그널·타이머)를 fd로 바꿔 epoll 루프 하나에서 처리한다.
둘째, 서버는 모듈의 조립이고, 모듈은 불투명 핸들과 ops 테이블로 만든다.
셋째, 시작 순서와 종료 순서를 코드 한 곳에 적고, 종료는 시작의 정확한 역순이다.

## 언제 사용하나

- 소켓 서버·데몬·수집 프로세스를 새로 만들거나 구조를 고칠 때
- 시그널 처리, 설정 재적재, 종료 절차가 흩어져 있어 정리가 필요할 때
- 마스터·워커 프로세스 구조와 `fork` 후 자원 처리를 설계할 때

### 언제 사용하지 않나

- 소켓·epoll API 자체의 체크리스트 → [linux-system-network-programming](../linux-system-network-programming/SKILL.md)
- 지연 예산·핫패스 튜닝 → [latency-critical-systems](../latency-critical-systems/SKILL.md)
- 공유메모리 세그먼트·DB 동기화 세부 → `shm-db-patterns` 스킬
- Rust로 옮길지 판단 → [c-to-rust-migration](../c-to-rust-migration/SKILL.md)

## 1. 전체 구조

```
master (단일 스레드, 업무 로직 없음)
 ├─ 설정 적재·검증, listen 소켓 생성, 공유메모리 생성·초기화
 ├─ signalfd: SIGTERM·SIGHUP·SIGCHLD
 └─ fork × N ──> worker
                  ├─ 상속 fd 정리 → 자기 epoll·signalfd·timerfd 생성
                  ├─ 모듈 시작: log → config → shm attach → DB connect → net
                  └─ epoll 루프: listen·conn·signalfd·timerfd
```

master는 감독만 한다. DB 연결·업무 처리·스레드 생성을 하지 않는다.
그래야 `fork`가 안전하고, worker가 죽어도 master가 다시 띄울 수 있다.

## 2. 모듈 — 불투명 핸들 + ops 테이블

모든 모듈은 같은 수명 인터페이스를 따른다. 패턴 자체의 정의와 예시는
[rules/c/patterns.md](../../rules/c/patterns.md)의 "불투명 포인터"·"함수 포인터 인터페이스" 절이 정본이다.
이 절은 서버 조립에 필요한 부분만 다룬다.

```c
/* module.h — 서버가 모듈을 다루는 공통 수명 인터페이스 */
typedef struct
{
    uint32_t    version;
    const char *name;
    int  (*start)(void *impl, const Config *cfg);      /* 자원 획득 */
    int  (*reload)(void *impl, const Config *cfg);     /* NULL 허용 — 재적재 불필요 */
    void (*stop)(void *impl);                          /* 자원 반납, 멱등 */
    void (*destroy)(void *impl);
} ModuleOps;
```

서버는 모듈 배열을 순서대로 시작하고, 실패하면 이미 시작한 모듈만 역순으로 멈춘다.

```c
/*=============================================================================
FUNCTION    : ServerStartModules
DESCRIPTION : 모듈을 선언 순서로 시작한다. 실패하면 시작한 것만 역순으로 멈춘다
PARAMETERS  : Server       *srv - 서버 핸들
              const Config *cfg - 검증된 설정
RETURNED    : 0 또는 음수 에러
=============================================================================*/
int ServerStartModules(Server *srv, const Config *cfg)
{
    size_t ii  = 0;
    int    ret = 0;

    for (ii = 0; ii < srv->module_cnt; ii++)
    {
        Module *mod = &srv->modules[ii];

        ret = mod->ops->start(mod->impl, cfg);
        if (ret < 0)
        {
            LOG_ERROR("모듈 시작 실패 name=%s ret=%d", mod->ops->name, ret);
            goto rollback;
        }
    }
    srv->started_cnt = srv->module_cnt;
    return 0;

rollback:
    while (ii-- > 0)                        /* 실패한 모듈은 제외하고 역순 */
    {
        srv->modules[ii].ops->stop(srv->modules[ii].impl);
    }
    return ret;
}
```

### 초기화 순서

| 순서 | 모듈 | 이유 |
|---|---|---|
| 1 | log | 이후 모든 실패를 기록해야 한다 |
| 2 | config | 나머지 모듈의 입력이다 |
| 3 | shm attach | 헤더 검증 실패면 DB를 열 이유가 없다 |
| 4 | db connect | 공유메모리 적재·동기화의 원천이다 |
| 5 | worker 스레드·큐 | 처리 경로를 먼저 준비한다 |
| 6 | net (listen 등록) | 마지막에 연다 — 준비 전 요청을 받지 않는다 |

종료는 이 표의 역순이다. "받는 입구를 가장 늦게 열고 가장 먼저 닫는다"가 규칙이다.

## 3. epoll 이벤트 루프

### LT와 ET 선택

| 기준 | Level-triggered (기본) | Edge-triggered |
|---|---|---|
| 읽기 방식 | 한 번에 일부만 읽어도 다음 `epoll_wait`가 다시 알린다 | `EAGAIN`까지 반드시 다 읽어야 한다 |
| 실수 비용 | 낮다 — 덜 읽어도 멈추지 않는다 | 높다 — 덜 읽으면 연결이 영원히 멈춘다 |
| 적합 | 대부분의 서버, 공정성이 필요한 경우 | 연결당 이벤트가 많고 시스템 콜을 줄여야 하는 경우 |
| listen 소켓 | LT 권장 | 쓰면 `accept`를 `EAGAIN`까지 반복 |

기본은 LT다. ET는 측정으로 `epoll_wait` 비용이 확인될 때만 쓴다.
ET를 쓰면 한 연결이 루프를 독점하지 않게 회당 처리량 상한을 두고, 남은 일은 다음 회차로 넘긴다.

### 규칙

- 모든 fd는 논블로킹이다. `accept4(fd, ..., SOCK_NONBLOCK | SOCK_CLOEXEC)`를 쓴다.
- `epoll_wait`가 `EINTR`로 돌아오면 그냥 다시 부른다. 에러가 아니다.
- `read`·`write`의 `EAGAIN`은 "지금은 끝"이라는 뜻이다. 상태를 저장하고 루프로 돌아간다.
- `EPOLLOUT`은 보낼 데이터가 남았을 때만 켜고, 다 보내면 끈다. 항상 켜 두면 루프가 계속 깨어난다.
- `EPOLLRDHUP`·`EPOLLHUP`·`EPOLLERR`는 연결 종료로 처리한다. 상대의 정상 종료도 이벤트다.
- `SIGPIPE`는 무시하거나 `send(..., MSG_NOSIGNAL)`을 쓴다. 끊긴 소켓 쓰기는 `EPIPE`로 받는다.
- 주기 작업은 `timerfd`, 스레드에서 루프를 깨울 때는 `eventfd`를 쓴다.
- `epoll_event.data.ptr`에는 fd 종류를 아는 공통 헤더(`FdKind`)를 둔 구조체를 넣는다.

```c
/*=============================================================================
FUNCTION    : EventLoopRun
DESCRIPTION : 종료 요청이 오고 처리 중인 연결이 비거나 기한이 지날 때까지 이벤트를 처리한다
PARAMETERS  : Server *srv - 서버 핸들 (epoll·signalfd·listen fd 준비 완료)
RETURNED    : 0 또는 음수 errno
=============================================================================*/
int EventLoopRun(Server *srv)
{
    struct epoll_event events[MAX_EVENTS];
    int                nready = 0;
    int                ii     = 0;

    while (!ServerCanExit(srv))
    {
        nready = epoll_wait(srv->epoll_fd, events, MAX_EVENTS, LOOP_TIMEOUT_MS);
        if (nready < 0)
        {
            if (errno == EINTR) { continue; }
            return -errno;
        }

        for (ii = 0; ii < nready; ii++)
        {
            FdHeader *hdr = events[ii].data.ptr;

            switch (hdr->kind)
            {
                case FD_LISTEN: AcceptAll(srv); break;
                case FD_SIGNAL: HandleSignals(srv); break;
                case FD_TIMER:  HandleTimer(srv); break;
                case FD_CONN:   HandleConn(srv, (Conn *)hdr, events[ii].events); break;
            }
        }
    }
    return 0;
}
```

`AcceptAll`은 `EAGAIN`이 나올 때까지 `accept4`를 반복한다.
`EMFILE`·`ENFILE`이면 로그를 남기고 listen fd를 잠시 epoll에서 빼서 루프가 헛돌지 않게 한다.

## 4. 시그널 — signalfd

시그널은 비동기 핸들러에서 처리하지 않는다. `signalfd`로 fd 이벤트로 바꿔 루프에서 동기로 처리한다.

1. 스레드를 만들기 전에 `sigprocmask`(스레드가 있으면 `pthread_sigmask`)로 대상 시그널을 막는다.
   막지 않은 스레드가 하나라도 있으면 시그널이 그쪽으로 배달되어 signalfd가 놓친다.
2. 같은 집합으로 `signalfd(-1, &mask, SFD_NONBLOCK | SFD_CLOEXEC)`를 만들고 epoll에 등록한다.
3. 읽을 수 있으면 `struct signalfd_siginfo`를 `EAGAIN`까지 읽는다.

| 시그널 | 동작 |
|---|---|
| `SIGTERM`·`SIGINT` | 종료 단계로 전환한다 (6절). 두 번째 수신은 drain 기한을 0으로 줄인다 |
| `SIGHUP` | 설정 재적재(5절)와 로그 파일 재오픈을 한다 |
| `SIGCHLD` | `waitpid(-1, &status, WNOHANG)`를 0이 나올 때까지 반복한다 |
| `SIGPIPE` | `SIG_IGN` — 소켓 에러는 `EPIPE`로 받는다 |

`SIGCHLD`는 여러 번 와도 한 번으로 합쳐질 수 있다. 그래서 신호 한 번에 자식 하나가 아니라 "더 없을 때까지" 회수한다.

### self-pipe 대안

signalfd를 쓸 수 없거나 라이브러리가 핸들러를 요구하면 self-pipe를 쓴다.
핸들러는 `errno`를 저장하고, 논블로킹 파이프에 1바이트를 쓰고, `errno`를 복원하는 일만 한다.
`write`는 async-signal-safe이고, 파이프가 가득 차서 실패해도 이미 깨울 바이트가 있으므로 무시한다.
읽는 쪽은 루프에서 파이프를 비우고 `volatile sig_atomic_t` 플래그를 확인한다.

## 5. 설정 재적재 (재시작 없이)

재적재는 "새로 만들고 검증한 뒤 교체"다. 실행 중인 설정을 제자리에서 고치지 않는다.

1. 새 파일을 새 `Config`로 끝까지 파싱한다.
2. 검증한다. 실패하면 기존 설정을 유지하고 원인을 로그에 남긴다. 서버는 멈추지 않는다.
3. 재시작이 필요한 항목(listen 포트, 공유메모리 크기, worker 수)이 바뀌었으면 적용하지 않고 경고한다.
4. 각 모듈의 `reload`를 시작 순서대로 부른다. 실패한 모듈은 이전 값을 유지한다.
5. 모든 모듈이 끝나면 전역 설정 포인터를 새 것으로 바꾸고 이전 것을 해제한다.

설정 포인터를 다른 스레드도 읽으면 교체는 원자적 포인터 교환으로 하고,
이전 설정은 읽는 스레드가 모두 다음 회차로 넘어간 뒤 해제한다.
로그 재오픈은 같은 SIGHUP에서 한다. 로그 순환(logrotate)이 파일을 옮긴 뒤 새 파일을 열기 위해서다.
master는 자기 설정을 재적재한 뒤 worker에 `SIGHUP`을 전달한다.

## 6. graceful shutdown 순서

종료는 시작의 역순이고, 각 단계에 기한이 있다.

1. **입구 닫기**: listen fd를 epoll에서 빼고 닫는다. 새 연결을 받지 않는다.
2. **drain**: 처리 중인 요청을 끝낸다. 새 요청은 읽지 않는다. `timerfd`로 drain 기한을 건다.
3. **flush**: 보낼 응답 버퍼와 DB 배치(미커밋 묶음)를 비운다. 기한을 넘기면 남은 양을 로그에 남긴다.
4. **worker 스레드·큐 정지**: 큐에 종료 표지를 넣고 `pthread_join`한다.
5. **DB 연결 해제**: 커밋할지 롤백할지 정책대로 끝내고 연결을 닫는다.
6. **공유메모리 detach**: 자기 슬롯·하트비트를 "종료"로 표시한 뒤 detach한다. 삭제는 소유자(master)만 한다.
7. **로그 flush·close**: 마지막으로 종료 사유와 처리 건수를 남기고 닫는다.

master의 순서는 다르다.
worker 전원에 `SIGTERM`을 보내고, 기한까지 `SIGCHLD`로 회수하고, 남은 worker에만 `SIGKILL`을 보낸다.
그 뒤 정책에 따라 공유메모리를 보존하거나 삭제한다.
보존하면 재시작 시 헤더 검증으로 재사용 여부를 정한다.

## 7. 프로세스 구조 — 마스터·워커와 fork 후 정리

### listen 소켓 공유

- **하나를 공유**: master가 만든 listen fd를 worker가 상속한다. epoll 등록 시 `EPOLLEXCLUSIVE`로 thundering herd를 줄인다.
- **worker별 소켓**: 각 worker가 `SO_REUSEPORT`로 같은 포트에 bind한다. 커널이 분배한다.

### fork 직후 worker가 할 일

| 대상 | 처리 | 이유 |
|---|---|---|
| stdio 버퍼 | `fork` 직전 master가 `fflush(NULL)` | 버퍼가 복제되어 같은 출력이 두 번 나간다 |
| epoll·signalfd·timerfd | 상속한 것을 닫고 새로 만든다 | epoll 인스턴스는 fork 후에도 공유되어 이벤트가 섞인다 |
| 시그널 마스크 | 상속된다. worker 집합으로 다시 정한다 | exec하는 자식은 마스크를 풀어야 한다 |
| DB 연결 | worker가 `fork` 뒤 새로 연결한다 | 연결 소켓을 두 프로세스가 공유하면 프로토콜이 깨진다 |
| 스레드 | master는 스레드를 만들지 않는다 | `fork`는 호출 스레드만 복제한다. 다른 스레드가 잡은 락은 영원히 잠긴다 |
| 공유메모리 | worker가 직접 attach하고 헤더를 검증한다 | 상속도 가능하지만 검증·통계 경계가 흐려진다 |
| 난수 상태·PID 캐시 | 다시 초기화한다 | 같은 시드면 worker들이 같은 값을 만든다 |
| 로그 fd | 상속해도 되지만 `O_APPEND`여야 한다 | 줄이 섞이지 않게 한 번의 `write`로 한 줄을 쓴다 |

임베디드 SQL에서는 "master는 `EXEC SQL CONNECT`를 하지 않는다"가 가장 중요한 규칙이다.
master가 이미 연결했다면 worker는 그 연결을 쓰지도, `COMMIT WORK RELEASE`로 닫지도 않는다.
연결 컨텍스트와 멀티스레드 사용은 [embedded-sql](../embedded-sql/SKILL.md)을 따른다.

### worker 감독

- `SIGCHLD`로 회수한 뒤 종료 상태(`WIFEXITED`·`WIFSIGNALED`)를 로그에 남긴다.
- 비정상 종료한 worker는 다시 띄우되, 짧은 시간에 반복되면 백오프를 건다(예: 1초에서 시작해 두 배, 상한 60초).
- worker가 공유메모리 robust 뮤텍스를 잡은 채 죽으면 다음 잠금에서 `EOWNERDEAD`가 온다.
  복구 절차는 [rules/systems/philosophy.md](../../rules/systems/philosophy.md) 11절과 `shm-db-patterns` 스킬을 따른다.

## 8. 다른 모듈과의 경계

서버 코어(루프·시그널·수명)는 업무 데이터를 직접 다루지 않는다. 경계는 ops 인터페이스 하나다.

| 경계 | 서버 코어가 하는 일 | 세부 정본 |
|---|---|---|
| 공유메모리 | attach·detach 순서, 종료 시 슬롯 표시 | `shm-db-patterns` 스킬 |
| DB | 연결·해제 순서, 종료 시 커밋 정책 | [embedded-sql](../embedded-sql/SKILL.md), `shm-db-patterns` 스킬 |
| 로그 | 가장 먼저 열고 가장 늦게 닫기, SIGHUP 재오픈 | `operational-logging` 스킬 |
| 처리량 | 큐 깊이·배치 크기 설정 전달 | `stream-pipeline-patterns` 스킬 |

- 서버 코어 파일에 `EXEC SQL`을 쓰지 않는다. DB 접근은 `*.pc`·`*.pgc` 모듈 안에만 둔다.
- DB 호출은 블로킹이다. 지연이 중요한 epoll 스레드에서 직접 부르지 않는다.
  전용 스레드나 프로세스로 넘기고, 결과는 `eventfd`로 루프에 알린다.
- 공유메모리 갱신과 DB 반영의 순서·일관성 규칙은 서버 코어가 정하지 않는다. 데이터 계층 모듈이 정한다.

## 9. 점검 체크리스트

- [ ] 모듈 시작 순서가 코드 한 곳(모듈 배열)에 있고, 종료는 그 역순이다.
- [ ] 시작 중 실패하면 이미 시작한 모듈만 역순으로 멈춘다.
- [ ] 모든 fd가 논블로킹이고 `CLOEXEC`다.
- [ ] `epoll_wait`·`read`·`write`의 `EINTR`과 `EAGAIN`을 구분해 처리한다.
- [ ] ET를 썼다면 `EAGAIN`까지 읽고, 회당 처리량 상한이 있다.
- [ ] 시그널은 스레드 생성 전에 막고 signalfd로 받는다. 핸들러 안에서 로그를 쓰지 않는다.
- [ ] `SIGCHLD`에서 `WNOHANG` 회수를 반복한다.
- [ ] 설정 재적재가 실패해도 기존 설정으로 계속 동작한다.
- [ ] master는 DB에 연결하지 않고 스레드를 만들지 않는다.
- [ ] fork 후 worker가 epoll·signalfd를 새로 만들고, DB 연결과 공유메모리 attach를 스스로 한다.
- [ ] 종료 각 단계에 기한이 있고, 기한 초과 시 남은 작업량을 로그에 남긴다.
- [ ] ASan·TSan 빌드로 시작·재적재·종료 경로를 한 번씩 돌렸다.

## 관련 스킬

- [linux-system-network-programming](../linux-system-network-programming/SKILL.md) — 소켓·epoll·시그널 API 체크리스트
- [embedded-sql](../embedded-sql/SKILL.md) — Pro*C·ecpg 연결·트랜잭션
- [c-testing](../c-testing/SKILL.md) — 시스템 콜 테스트 더블, 새니타이저 게이팅
- [c-to-rust-migration](../c-to-rust-migration/SKILL.md) — 이 구조를 Rust로 옮길 때의 대응표
- `shm-db-patterns` · `operational-logging` · `stream-pipeline-patterns` 스킬 — 데이터 계층·로그·처리량
