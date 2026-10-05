---
name: operational-logging
description: 프로그램 동작(운영) 로그 규약 — 레벨 기준(FATAL~TRACE), 한 줄 key=value 형식(µs 시각·호스트·pid·tid·모듈·함수:줄·거래 ID), 남길 것과 남기지 말 것, 성능(레벨 검사 매크로·비동기 링버퍼·주기 flush·폭주 억제), 출력 대상(파일·syslog·journald, 다중 프로세스 O_APPEND, 디스크 풀), logrotate와 SIGHUP 재오픈, 크래시 시 async-signal-safe 기록, 거래 ID 전파·logtrace 조회, 클라이언트 로그. 원칙은 언어 공통, 구현은 C 우선. 대상 경로 — **/*.c, **/*.h, **/*.pc, **/*.pgc, **/log/**, **/logrotate*.conf, **/logtrace.sh. 키워드 — 운영 로그, 로그 레벨, 구조화 로그, 거래 ID, 비동기 로깅, 폭주 억제, logrotate, SIGHUP, 로그 추적.
---

# 운영 로그

운영 로그는 새벽 장애 때 **무슨 일이, 어느 거래에서, 어디서** 일어났는지 답하는 기록이다.
한 줄에 한 사건을 `key=value`로 남기고, 거래 ID로 프로세스를 넘어 이어 붙인다.
로그 때문에 핫패스가 느려지거나 서비스가 멈추면 안 된다. 개인정보는 절대 남기지 않는다.

C 구현 골격은 `templates/project/c-system/`에 있다.

| 파일 | 역할 |
|---|---|
| `src/log/log.h`·`log.c` | 레벨 매크로, 동기/비동기 출력, 폭주 억제, 재오픈, 거래 ID, 마스킹 헬퍼 |
| `src/log/test_log.c`·`Makefile` | `make test`(ASan/UBSan)·`make test-tsan` |
| `tools/logtrace.sh` | 거래 ID 하나의 줄을 여러 파일에서 모아 시각순 출력 |
| `conf/logrotate.conf` | rename + `SIGHUP` 재오픈 방식의 회전 템플릿 |

## 언제 사용하나

- 서버 프로세스에 로그를 새로 넣거나, 로그 형식·레벨·출력 대상을 정할 때
- 핫패스의 로그 비용, 로그 폭주, 디스크 풀 대응을 설계하거나 리뷰할 때
- 여러 프로세스에 걸친 거래를 추적할 수단이 필요할 때
- `logrotate` 설정이나 시그널 처리 코드를 작성할 때

## 1. 레벨 기준

레벨은 **누가 언제 봐야 하는가**로 고른다. 운영 기본 레벨은 INFO다.

| 레벨 | 의미 | 언제 쓰나 (예) |
|---|---|---|
| FATAL | 프로세스가 곧 끝난다 | 설정 파일 손상으로 기동 불가, 공유메모리 헤더 검증 실패 후 종료 |
| ERROR | 요청·작업이 실패했고 사람이 조치해야 한다 | 주문 저장 실패(`sqlcode` 포함), 외부 연결 재시도 한도 초과 |
| WARN | 자동 복구됐거나 임계에 가깝다 | DB 재접속 성공, 큐 사용률 80% 초과, 폭주 억제 발생 |
| INFO | 상태 전환과 주기 통계 | 기동·종료, 연결 수립·끊김, 관리 명령 실행, 1분 처리량 |
| DEBUG | 개발·장애 분석용 상세 | 분기 선택 이유, 설정 해석 결과 |
| TRACE | 건별 상세. 운영에서는 꺼 둔다 | 메시지 한 건의 필드 덤프(마스킹 후) |

- 같은 사건은 한 레벨로만 남긴다. 레벨을 올려 눈에 띄게 하지 않는다.
- ERROR는 "조치가 필요하다"는 뜻이다. 클라이언트의 잘못된 입력처럼 조치가 필요 없으면 WARN이나 INFO다.
- 공통 규칙의 `[DEBUG]` 접두 출력은 **임시 디버그**다. 배포 전에 지운다.
  운영 로그는 접두 대신 이 레벨 체계로 남긴다. `printf("[DEBUG] …")`를 운영 코드에 남기지 않는다.

## 2. 형식 — 한 줄 한 사건, key=value

```
ts=2026-10-05T14:03:22.123456+09:00 host=app01 proc=orderd pid=4123 tid=4130 lvl=ERROR mod=db file=order.c fn=SaveOrder:212 txn=G01-1728104602123456-000042 msg=insert failed sqlcode=-1 stmt=ORD_INS_01
```

| 키 | 내용 |
|---|---|
| `ts` | ISO 8601, µs 정밀도. 시각 정책은 아래를 따른다 |
| `host`·`proc`·`pid`·`tid` | 어느 서버, 어느 프로세스, 어느 스레드인가. tid는 리눅스 커널 tid(`top -H`·`gdb`와 같은 값) |
| `lvl`·`mod` | 레벨과 모듈 이름 |
| `file`·`fn` | 호출 위치. `fn`은 `함수:줄` |
| `txn` | 거래/요청 ID. 없으면 `-` |
| `msg` | 마지막 필드. 공백을 포함할 수 있다. 추가 값은 `msg` 안에 `key=value`로 이어 쓴다 |

- **시각 정책**: 기본은 로컬 시각 + 숫자 오프셋(`+09:00`)이다. 사람이 읽기 쉽고 오프셋으로 모호함이 없다.
  여러 시간대에 걸친 시스템은 전 서버를 UTC(`Z`)로 맞춘다. 한 시스템 안에서는 정책을 섞지 않는다.
  `logtrace.sh`는 `ts` 문자열 순서로 정렬하기 때문이다. 서버 시계는 NTP(chrony)로 맞춘다.
- `msg`의 제어 문자(개행 포함)는 공백으로 바꾼다. 입력값의 개행으로 가짜 줄을 만드는 공격을 막는다.
- 한 줄은 1024바이트 이내다. 넘으면 자르고 `...`로 끝낸다. 큰 데이터는 로그가 아니라 별도 덤프로 남긴다.
- 이 형식은 `grep 'txn=…'`, `awk`로 바로 조회된다. JSON 수집기가 필요하면 수집 단계에서 변환한다.

## 3. 남길 것과 남기지 말 것

**남길 것**

- 기동·종료: 버전, 빌드 정보, 설정 요약. 비밀값은 키 이름만 적고 값은 빼낸다.
- 외부 연결의 수립·끊김·재접속(상대 주소, 재시도 횟수, 소요 시간)
- DB 오류: `sqlca.sqlcode`, 오류 메시지(`sqlerrm`), **SQL 식별자**(`stmt=ORD_INS_01`). 바인드 값은 남기지 않는다.
- 공유메모리 상태 전환(attach, 손상 표시, DB 재적재), 복구 실행과 결과
- 주기 처리량 통계(초당 건수, 지연 p99, 큐 길이, 로그 유실·억제 수)
- 관리 명령 실행(누가, 무엇을, 결과)

**남기지 말 것**

- 개인정보·비밀번호·토큰·키. 개인정보가 꼭 필요하면 필드 단위로 가린 값만 남긴다(`LogMaskDigits`·`LogMaskAll`).
  기준은 `sensitive-data-handling` 스킬을 따른다. 비밀값은 가리지도 말고 아예 넘기지 않는다.
- 핫패스의 건별 INFO 로그. 건별 정보는 TRACE로 내리고, INFO에는 주기 통계를 남긴다.
- 같은 오류의 중복 기록. 에러는 감지한 곳에서 맥락을 붙여 올리고, **처리하는 곳에서 한 번만** 기록한다.

```c
/* BAD: 바인드 값(고객 연락처)이 로그에 남는다 */
LOG_ERROR("insert failed phone=%s sqlcode=%ld", phone, sqlca.sqlcode);

/* GOOD: 코드·메시지·SQL 식별자만. 메시지 길이는 sqlerrml로 제한한다 */
LOG_ERROR("insert failed sqlcode=%ld stmt=%s err=%.*s", (long)sqlca.sqlcode, "ORD_INS_01",
          (int)sqlca.sqlerrm.sqlerrml, sqlca.sqlerrm.sqlerrmc);
```

## 4. 성능 — 로그가 핫패스를 늦추지 않게

**레벨 검사 매크로.** 비활성 레벨은 함수 호출과 인자 평가를 모두 건너뛴다.
검사는 원자 변수 하나를 읽는 비용뿐이다. 그래서 인자에 부작용을 두면 안 된다.

```c
#define LOG_MODULE "order"
#include "log.h"

LOG_DEBUG("book depth=%d", CountDepth(book));   /* DEBUG가 꺼져 있으면 CountDepth를 부르지 않는다 */
```

함수형 매크로는 금지(D14)지만 호출 위치(`__FILE__`·`__LINE__`·`__func__`)를 담는 로그 매크로는 예외다.
예외 매크로도 `do { } while (0)`로 감싼다. 포맷 문자열은 항상 리터럴이다(`LOG_INFO("%s", input)`).
`LogWrite`에 `format(printf)` 속성이 있어 `LOG_INFO(input)`은 `-Wformat-security`로 걸린다.

**비동기 로깅.** `/* HOTPATH */` 경로는 `LogConfig.async = true`로 쓴다.

- 기동 때 링버퍼를 미리 할당한다. 운영 중에는 할당하지 않는다.
- 생산자 스레드는 락 밖에서 줄을 만들고, 락 안에서는 칸에 복사만 한다. 락을 잡은 채 I/O를 하지 않는다.
- 로거 스레드가 최대 64줄을 묶어 `write()` 한 번으로 쓴다. 묶음이 차거나 200ms가 지나면 쓴다(주기 flush).
- **링이 가득 차면 생산자는 기다리지 않는다.** 그 줄을 버리고 유실 수만 센다.
  로거 스레드가 `msg=log ring full dropped=N` 요약을 남긴다. 거래 처리가 로그를 기다리는 일은 없다.
- FATAL은 앞선 줄을 모두 내보낸 뒤(`LogFlush`) 동기로 쓴다.
- 링버퍼 칸 수는 "최대 폭주 초당 줄 수 × flush 간격"의 두 배 이상으로 잡는다. 유실 수는 주기 통계로 감시한다.
- 측정 결과 생산자 락 경합이 병목이면, 스레드별 SPSC 링버퍼로 바꾸는 것을 검토한다(철학 11절 예외).

**폭주 억제.** 같은 호출 위치(파일·줄)는 창(`flood_window_sec`)마다 `flood_max`건만 기록한다.
나머지는 세기만 하고, 창이 바뀌거나 종료할 때 한 줄로 요약한다.

```
... lvl=WARN mod=net file=feed.c fn=OnRecv:88 txn=- msg=log flood suppressed=9997 window_sec=1
```

- 억제 판단은 포맷 전에 한다. 버릴 줄은 문자열을 만들지도 않는다.
- 운영 기본값의 예는 `flood_max=10`, `flood_window_sec=1`이다. 핫패스에서 같은 오류가 초당 1만 번 나도
  기록은 초당 10줄과 요약 1줄이다.

## 5. 출력 대상

| 대상 | 고를 때 |
|---|---|
| 프로세스별 파일 | 기본. 처리량이 크고, `grep`·`logtrace.sh`로 직접 조회하는 서버 |
| syslog·journald | 처리량이 작은 데몬, 중앙 수집이 이미 syslog 기반인 환경. 고빈도 로그는 속도 제한(`RateLimitBurst`)에 걸려 유실된다 |
| 로거 프로세스(소켓·파이프로 전달) | 여러 프로세스의 로그를 한 파일로 모아야 하고 순서를 한 곳에서 정해야 할 때 |

**다중 프로세스 쓰기.** `O_APPEND`로 연 파일에 `write()` 한 번으로 쓴 줄은 다른 프로세스 줄과 섞이지 않는다.
이 보장은 **write() 한 번**에 한정된다. 한 줄을 여러 번 나눠 쓰거나 stdio 버퍼가 줄 중간에서 끊기면 섞인다.
그래서 로거는 한 줄을 버퍼에 다 만든 뒤 `write()` 한 번으로 쓴다. 네트워크 파일시스템(NFS)에서는 이 보장도 없다.
기본은 **프로세스별 파일**(`orderd.4123.log` 또는 워커 번호별)이다. 한 파일이 꼭 필요하면 로거 프로세스를 둔다.

**디스크 풀.** 로그 쓰기가 실패해도 서비스는 계속한다.

- `write()` 실패(`ENOSPC`·`EIO`)는 재시도하지 않는다. 실패 횟수만 세고 그 줄은 버린다(`LogGetStats`).
- 동기 모드에서도 실패를 기다리지 않는다. 블록되는 출력(꽉 찬 파이프 등)에 로그를 쓰지 않는다.
- 로그 파티션을 데이터 파티션과 분리한다. 디스크 사용률 경보는 로그가 아니라 모니터링으로 받는다.

## 6. 회전·보존

| 방식 | 동작 | 판단 |
|---|---|---|
| rename + `SIGHUP` 재오픈 (기본) | logrotate가 파일을 옮기고 신호를 보낸다. 프로세스가 같은 경로로 새 파일을 연다 | 유실 없음. 재오픈 처리 코드가 필요하다 |
| `copytruncate` | 파일을 복사한 뒤 원본을 0으로 자른다 | 신호가 필요 없다. 복사와 자르기 사이의 줄이 유실되고 큰 파일은 복사 비용이 크다 |

재오픈은 시그널 핸들러에서 하지 않는다. 핸들러는 플래그만 세우고 메인 루프가 처리한다.

```c
static void OnSighup(int signo)
{
    (void)signo;
    LogRequestReopen();                 /* async-signal-safe — 플래그만 세운다 */
}

/* 메인 루프(이벤트 루프 한 바퀴마다) */
if (LogReopenIfRequested() < 0)
{
    LOG_WARN("log reopen failed — 이전 파일에 계속 기록");
}
```

- `LogReopen`은 새 파일을 연 뒤 `dup2()`로 같은 fd 번호를 원자적으로 바꾼다. 쓰는 스레드는 락이 필요 없다.
- 재오픈에 실패하면 이전 파일에 계속 쓴다. 로그 때문에 프로세스를 멈추지 않는다.
- `signalfd`로 시그널을 이벤트 루프에서 받는 구조면 핸들러 없이 루프에서 바로 `LogReopen`을 부른다.
- 보존 기간은 업무 요구와 개인정보 보존 기준 중 짧은 쪽이다. 기간이 지나면 압축본까지 파기한다.
- 회전된 파일은 `compress`·`delaycompress`로 압축한다. 직전 파일은 재오픈 전 쓰기가 있을 수 있어 한 주기 늦게 압축한다.

## 7. 장애 시

크래시 시그널(`SIGSEGV`·`SIGBUS`·`SIGABRT`) 핸들러 안에서는 **async-signal-safe 함수만** 부른다.
`printf`·`malloc`·`localtime_r`·뮤텍스는 쓸 수 없다. 핸들러에서 할 수 있는 일은 정해져 있다.

- `LogCrashNote(signo)`로 FATAL 한 줄을 남긴다. `clock_gettime`·`write`와 정수 연산만 쓴다.
  시각 오프셋은 `LogInit` 때 구해 둔 값을 쓰므로 일반 줄과 같은 형식으로 정렬된다.
- 링버퍼에 남은 줄은 기록하지 못한다. 락이 필요하기 때문이다. 그래서 FATAL·ERROR 직전 맥락이 중요하면
  해당 줄을 동기로 남기거나, 링 유실을 감수한다는 사실을 운영 문서에 적는다.
- 핸들러는 기록 뒤 기본 동작으로 되돌리고 같은 시그널을 다시 올려 코어 덤프를 남긴다.

```c
static void OnCrash(int signo)
{
    LogCrashNote(signo);
    signal(signo, SIG_DFL);            /* 기본 동작 복원 → 코어 덤프 */
    raise(signo);
}
```

코어 덤프와 로그는 시각으로 대조한다. `coredumpctl info`의 시각과 크래시 줄의 `ts`·`pid`를 맞추고,
같은 `pid`의 직전 줄과 `txn`으로 어떤 거래를 처리하다 죽었는지 찾는다.
코어 덤프의 개인정보 처리(크기 제한·보관 위치)는 `sensitive-data-handling` 스킬을 따른다.

## 8. 추적 — 거래/요청 ID

**생성.** 거래가 시스템에 처음 들어오는 곳(게이트웨이·클라이언트)에서 한 번 만든다.
형식은 충돌이 없고 정렬되는 값이 좋다. 예: `<발생지 코드>-<µs 시각>-<일련번호>`(`G01-1728104602123456-000042`)
또는 UUIDv7. ID에는 고객 번호 같은 개인정보를 넣지 않는다. 허용 문자는 영문·숫자·`._:-`다.

**전파.** 모든 경계에서 같은 ID를 넘긴다.

| 구간 | 전달 방법 |
|---|---|
| 클라이언트 → 서버 | 요청 헤더(`X-Request-Id`) 또는 전문 공통부의 고정 필드 |
| 서버 프로세스 간 | IPC 메시지·공유메모리 큐 레코드 헤더의 고정 길이 필드 |
| 스레드 | 작업을 꺼낸 스레드가 `LogSetTxnId(msg->txn_id)`, 끝나면 `LogClearTxnId()` |
| DB 작업 | 같은 ID를 로그에 남긴다. 필요하면 세션 식별 정보(Oracle `DBMS_APPLICATION_INFO.SET_CLIENT_INFO`, PostgreSQL `application_name`)에도 넣는다 |

`LogSetTxnId`는 스레드 지역 변수다. 다른 스레드로 작업을 넘길 때는 ID를 작업 데이터에 담아 넘기고, 받은 쪽에서 다시 정한다.

**조회.** `logtrace.sh`로 여러 프로세스 로그에서 한 거래를 시각순으로 모은다.

```bash
tools/logtrace.sh G01-1728104602123456-000042 /var/log/app/          # 디렉터리 전체(회전·gz 포함)
tools/logtrace.sh -l WARN G01-1728104602123456-000042 gw.log order.log  # WARN 이상만
```

- 표준 출력에는 일치한 원본 줄만 낸다. 없는 경로는 표준 에러에 경로만 알린다.
- `txn=` 필드가 정확히 같은 줄만 고른다. `msg` 안의 `txn=` 문자열은 보지 않는다.
- 종료 코드는 0(일치 있음)·1(일치 없음)·2(사용법 오류)다.

## 9. 클라이언트 로그 (Electron·웹)

- 로컬 파일 로그는 크기 기준으로 회전하고 개수를 제한한다(예: 5MB × 5개). 사용자 디스크를 채우지 않는다.
- 개인정보·토큰·입력 원문은 남기지 않는다. 서버와 같은 마스킹 헬퍼를 쓴다.
- 서버로 로그를 보내려면 사용자 동의를 받고, 보내기 전에 마스킹한다. 보낼 때 요청 ID를 함께 붙인다.
- 렌더러의 콘솔 로그는 배포 빌드에서 레벨로 줄인다. 오류 보고 도구도 같은 마스킹 규칙을 따른다.
- 대용량 데이터 수신 클라이언트의 설계는 이 스킬의 범위가 아니다.

## 10. C 템플릿 사용 예

```c
#define LOG_MODULE "main"
#include "log.h"

int main(void)
{
    LogConfig cfg = {0};
    int       ret;

    cfg.path             = "/var/log/app/orderd.log";
    cfg.proc_name        = "orderd";
    cfg.level            = LOG_LEVEL_INFO;
    cfg.async            = true;         /* 핫패스가 있는 프로세스 */
    cfg.ring_slots       = 8192;
    cfg.flood_max        = 10;
    cfg.flood_window_sec = 1;
    ret = LogInit(&cfg);
    if (ret < 0)
    {
        fprintf(stderr, "[orderd] log init failed ret=%d\n", ret);
        return 1;
    }
    LOG_INFO("start version=%s build=%s", APP_VERSION, APP_BUILD);
    /* ... 이벤트 루프: LogReopenIfRequested() 호출 포함 ... */
    LOG_INFO("stop");
    LogShutdown();
    return 0;
}
```

- 워커를 `fork`하는 서버는 각 워커에서 `fork` 뒤 `LogInit`을 부른다. 로거 스레드는 `fork`를 넘지 않는다.
- 연락처를 꼭 남겨야 하면 `LogMaskDigits(phone, buf, sizeof(buf))`로 `***-****-5678`처럼 끝 4자리만 남긴다.
  비밀번호 같은 값의 존재만 알리려면 `LogMaskAll`을 쓴다. 길이도 드러내지 않는 `****`가 된다.
- 검증: `make -C src/log test`(ASan/UBSan), `make -C src/log test-tsan`(비동기 모드 레이스 검사).

## 리뷰 체크리스트

- [ ] 레벨이 표의 의미와 맞다. ERROR는 조치가 필요한 실패에만 쓴다
- [ ] 한 줄 `key=value` 형식이고 `txn`이 채워진다. 운영 코드에 `[DEBUG]` 임시 출력이 없다
- [ ] 개인정보는 마스킹 헬퍼를 거쳤고, 비밀값·바인드 값은 없다
- [ ] 사용자 입력을 포맷 문자열로 쓰지 않는다(`LOG_INFO("%s", input)`)
- [ ] 핫패스에 건별 INFO 로그나 동기 로그가 없다. 레벨 매크로 인자에 부작용이 없다
- [ ] 같은 오류를 여러 층에서 중복 기록하지 않는다. 에러 경로에 기록 누락이 없다
- [ ] 폭주 억제가 켜져 있고, 링 유실·억제·쓰기 실패 수를 주기 통계로 남긴다
- [ ] 회전은 rename + `SIGHUP` 재오픈이고, 재오픈은 메인 루프에서 한다
- [ ] 크래시 핸들러는 async-signal-safe 함수만 부른다
- [ ] 로그 쓰기 실패가 서비스를 멈추지 않는다(디스크 풀 장애 주입으로 확인)
