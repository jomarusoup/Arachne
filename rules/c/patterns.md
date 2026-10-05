---
paths:
  - "**/*.c"
  - "**/*.h"
---
# C 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.

## 자원 관리 — goto 단일 정리 경로

여러 자원을 순서대로 획득하면 정리 레이블 하나로 모아 역순으로 해제한다.
중간 `return`으로 정리를 건너뛰지 않는다. 실패는 음수 errno로 반환한다.

```c
int ProcessFile(const char *path)
{
    int    ret = -EIO;
    int    fd  = -1;
    char  *buf = NULL;

    fd = open(path, O_RDONLY);
    if (fd < 0) { ret = -errno; goto cleanup; }

    buf = malloc(BUF_SIZE);
    if (!buf) { ret = -ENOMEM; goto cleanup; }

    /* ... 작업 ... */
    ret = 0;

cleanup:
    free(buf);                      /* 획득의 역순으로 해제 */
    if (fd >= 0) { close(fd); }
    return ret;
}
```

## 시스템 콜 — EINTR·부분 I/O 루프

`read`·`write`는 요청보다 적게 처리하거나 시그널로 `EINTR`을 반환할 수 있다.
블로킹 fd는 끝까지 반복하고, 논블로킹 fd는 `EAGAIN`에서 진행량을 호출자에 돌려준다.

```c
ssize_t WriteAll(int fd, const void *buf, size_t len)
{
    const char *pos  = buf;
    size_t      left = len;

    while (left > 0)
    {
        ssize_t written = write(fd, pos, left);

        if (written < 0)
        {
            if (errno == EINTR) { continue; }
            if (errno == EAGAIN && left < len) { break; }   /* 부분 진행 보고 */
            return -errno;
        }
        pos  += written;
        left -= (size_t)written;
    }
    return (ssize_t)(len - left);
}
```

## 불투명 포인터 (Opaque Pointer)

구현 세부사항 은닉:

```c
/* header: conn.h */
typedef struct Conn Conn;
Conn *ConnCreate(const char *host, int port);
void  ConnDestroy(Conn *conn);
int   ConnSend(Conn *conn, const void *data, size_t len);

/* source: conn.c */
struct Conn {
    int    fd;
    char   host[256];
    int    port;
};
```

## 함수 포인터 인터페이스

불투명 핸들에 동작 테이블을 붙이면 C에서 다형성을 얻는다
(표준 패턴 — [systems/philosophy.md](../systems/philosophy.md) 4절).

```c
/* header: transport.h */
typedef struct Transport Transport;

typedef struct
{
    ssize_t (*send)(void *impl, const void *buf, size_t len);
    void    (*destroy)(void *impl);
} TransportOps;

Transport *TransportCreate(const TransportOps *ops, void *impl);
ssize_t    TransportSend(Transport *tp, const void *buf, size_t len);
void       TransportDestroy(Transport *tp);

/* source: transport.c */
struct Transport
{
    const TransportOps *ops;    /* 구현별 static const 테이블 — 공유·불변 */
    void               *impl;   /* 구현 상태 — 핸들이 소유 */
};

ssize_t TransportSend(Transport *tp, const void *buf, size_t len)
{
    return tp->ops->send(tp->impl, buf, len);
}

/* source: tcp_transport.c — 구현 하나에 테이블 하나 */
static const TransportOps g_TcpOps = { TcpSend, TcpDestroy };
```

## 에러 코드 패턴

성공은 0, 실패는 음수다. 시스템 콜 실패는 `-errno`를 그대로 올리고, 도메인 에러는 errno와
겹치지 않는 음수 열거형을 쓴다. 포인터 반환 함수는 NULL + 출력 인자로 원인을 전달한다.

```c
/* 도메인 에러 — errno 범위(-1 ~ -4095)와 겹치지 않게 */
typedef enum
{
    ERR_OK           =  0,
    ERR_NULL_PTR     = -10001,
    ERR_BAD_FORMAT   = -10002,
    ERR_OUT_OF_RANGE = -10003,
} ErrCode;

ErrCode ParseData(const char *input, Data *out)
{
    if (!input || !out) { return ERR_NULL_PTR; }
    /* ... */
    return ERR_OK;
}
```

## 콜백 패턴

함수 포인터로 동작 주입:

```c
typedef void (*EventHandler)(int event, void *ctx);

typedef struct
{
    EventHandler   on_connect;
    EventHandler   on_disconnect;
    void          *ctx;
} EventLoop;
```

## 싱글톤 (프로세스 전역 상태)

```c
/* 모듈 내부에서만 접근 가능한 전역 상태 */
static ServerState g_State = {0};
static bool        g_Initialized = false;

int ServerInit(const Config *cfg)
{
    if (g_Initialized) { return -1; }
    /* ... 초기화 ... */
    g_Initialized = true;
    return 0;
}
```
