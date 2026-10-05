/*#############################################################################
FILE NAME   : counter.h
DESCRIPTION : 카운터 저장소 인터페이스 — 불투명 핸들 + 함수 포인터 동작 테이블
#############################################################################*/
#ifndef COUNTER_H
#define COUNTER_H

#include <stddef.h>
#include <stdint.h>

/* 동작 테이블 버전 — 테이블 필드를 바꾸면 올린다 */
#define COUNTER_OPS_VERSION 1u

/* 구현 하나가 담을 수 있는 키 개수 — C·Rust 구현이 같은 값을 쓴다 */
#define COUNTER_CAPACITY 4

/* 도메인 에러 — errno 범위(-1 ~ -4095)와 겹치지 않게 */
typedef enum
{
    COUNTER_OK            =  0,
    COUNTER_ERR_NULL_PTR  = -10001,
    COUNTER_ERR_NOT_FOUND = -10002,
    COUNTER_ERR_FULL      = -10003,
    COUNTER_ERR_OVERFLOW  = -10004,
    COUNTER_ERR_INTERNAL  = -10005,  /* 구현 내부 실패(Rust panic 포함) */
} CounterErr;

/* 구현이 채우는 동작 테이블 — 구현마다 불변 테이블 하나를 공유한다.
   세 함수 포인터 모두 필수이며 NULL을 허용하지 않는다. */
typedef struct
{
    uint32_t version;                                         /* COUNTER_OPS_VERSION */
    int    (*add)(void *impl, uint32_t key, int64_t delta);
    int    (*get)(const void *impl, uint32_t key, int64_t *out);
    void   (*destroy)(void *impl);
} CounterOps;

/* 64비트·32비트 모두 version(포인터 정렬로 패딩) + 함수 포인터 3개 */
_Static_assert(sizeof(CounterOps) == 4 * sizeof(void *), "CounterOps 레이아웃 변경");

/* 스레드 안전성: 핸들은 단일 스레드 전용이다. 여러 스레드에서 쓰면 호출자가 직렬화한다. */
typedef struct Counter Counter;

/* 성공하면 impl의 소유권이 핸들로 넘어간다. 실패(NULL)하면 impl은 호출자가 계속 소유한다. */
Counter *CounterCreate(const CounterOps *ops, void *impl);
int      CounterAdd(Counter *ctr, uint32_t key, int64_t delta);
int      CounterGet(const Counter *ctr, uint32_t key, int64_t *out);
void     CounterDestroy(Counter *ctr);

/* C 구현 — counter_mem.c */
const CounterOps *CounterMemOps(void);
void             *CounterMemNew(void);

#endif /* COUNTER_H */
