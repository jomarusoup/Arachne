---
paths:
  - "**/*.c"
  - "**/*.h"
---
# C 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.

## 자원 관리 — goto cleanup 패턴

여러 자원을 순서대로 획득할 때 해제를 보장:

```c
int ProcessFile(const char *path)
{
    int    ret = -1;
    int    fd  = -1;
    char  *buf = NULL;

    fd = open(path, O_RDONLY);
    if (fd < 0) { goto cleanup; }

    buf = malloc(BUF_SIZE);
    if (!buf) { goto cleanup; }

    /* ... 작업 ... */
    ret = 0;

cleanup:
    free(buf);
    if (fd >= 0) { close(fd); }
    return ret;
}
```

## 불투명 포인터 (Opaque Pointer)

구현 세부사항 은닉:

```c
/* header: conn.h */
typedef struct Conn_t Conn_t;
Conn_t *ConnCreate(const char *host, int port);
void    ConnDestroy(Conn_t *conn);
int     ConnSend(Conn_t *conn, const void *data, size_t len);

/* source: conn.c */
struct Conn_t {
    int    fd;
    char   host[256];
    int    port;
};
```

## 에러 코드 패턴

```c
/* 반환값으로 성공/실패 구분 */
typedef enum
{
    ERR_OK        =  0,
    ERR_NULL_PTR  = -1,
    ERR_NO_MEM    = -2,
    ERR_IO        = -3,
} ErrCode_t;

ErrCode_t ParseData(const char *input, Data_t *out)
{
    if (!input || !out) { return ERR_NULL_PTR; }
    /* ... */
    return ERR_OK;
}
```

## 콜백 패턴

함수 포인터로 동작 주입:

```c
typedef void (*EventHandler_t)(int event, void *ctx);

typedef struct
{
    EventHandler_t  on_connect;
    EventHandler_t  on_disconnect;
    void           *ctx;
} EventLoop_t;
```

## 싱글톤 (프로세스 전역 상태)

```c
/* 모듈 내부에서만 접근 가능한 전역 상태 */
static ServerState_t g_State = {0};
static bool          g_Initialized = false;

int ServerInit(const Config_t *cfg)
{
    if (g_Initialized) { return -1; }
    /* ... 초기화 ... */
    g_Initialized = true;
    return 0;
}
```
