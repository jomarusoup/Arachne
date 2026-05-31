---
paths:
  - "**/*.c"
  - "**/*.h"
---
# C 코딩 스타일

> [common/coding-style.md](../common/coding-style.md) 를 확장한다.

## 헤더 형식

```c
/*#############################################################################
FILE NAME   : 파일명.c
DESCRIPTION : 파일 역할 한 줄 요약
DATA        : YYYY-MM-DD
Modification: YYYY-MM-DD
#############################################################################*/

/*=============================================================================
FUNCTION    : FunctionName
DESCRIPTION : 역할 설명
PARAMETERS  : type 인자명 - 설명
              type 인자명 - 설명
RETURNED    : 반환값 설명 (void면 생략)
=============================================================================*/

/*-----------------------------------------------------------------------------
특정 로직 블록 설명
-----------------------------------------------------------------------------*/
```

## 중괄호 스타일 — Allman

```c
void ProcessData(int value)
{
    if (value > 0)
    {
        printf("Positive\n");
    }
    else
    {
        printf("Non-positive\n");
    }
}
```

## 네이밍 (C 전용)

- 함수명: `PascalCase` (`OpenConnection`, `ParseHeader`)
- 전역 변수: `g_SnakeCase` (`g_ServerFd`, `g_IsRunning`)
- 상수·매크로: `SCREAMING_SNAKE_CASE` (`MAX_BUF_SIZE`, `SOCK_PATH`)
- 구조체 타입: `PascalCase` + `_t` 접미사 (`ConnInfo_t`, `MsgHeader_t`)
- 열거형: `SCREAMING_SNAKE_CASE` (`STATE_IDLE`, `STATE_RUNNING`)

## 변수 선언

```c
/* 전역 변수 — 초기값 필수, 열 맞춤 */
static int    g_ServerFd   = -1;
static int    g_ClientFd   = -1;
static bool   g_IsRunning  = false;

/* 지역 변수 — 함수 상단에 모아서 선언 */
int    ret        = 0;
char   buf[1024]  = {0};
size_t buf_len    = 0;
```

## 에러 처리

- 모든 시스템 콜·라이브러리 함수 반환값 확인
- 에러 시 즉시 반환, 자원 해제 후 반환
- `goto cleanup` 패턴으로 중복 해제 방지

```c
int OpenFile(const char *path, int *out_fd)
{
    int fd = -1;
    int ret = 0;

    fd = open(path, O_RDONLY);
    if (fd < 0)
    {
        perror("open");
        return -1;
    }

    /* ... 작업 ... */

    *out_fd = fd;
    return 0;
}
```

## 포인터

- 포인터 선언 시 `*`는 변수명 쪽에 붙임: `int *ptr` (타입 쪽 금지: `int* ptr`)
- 함수 인자로 포인터 전달 시 NULL 체크 필수
- 포인터 해제 후 `NULL` 대입

```c
free(ptr);
ptr = NULL;
```

## 인클루드 순서

```c
/* 1. 표준 라이브러리 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* 2. POSIX / 시스템 헤더 */
#include <unistd.h>
#include <sys/socket.h>
#include <sys/epoll.h>

/* 3. 서드파티 라이브러리 */
#include <openssl/ssl.h>

/* 4. 프로젝트 내부 헤더 */
#include "config.h"
#include "ipc.h"
```
