/*#############################################################################
FILE NAME   : test_spsc_ring.c
DESCRIPTION : SPSC 링버퍼 경계 조건 단위 테스트와 2스레드 생산자-소비자 정확성 테스트
#############################################################################*/

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <pthread.h>
#include <sched.h>

#include "spsc_ring.h"

#define STRESS_MSG_COUNT 1000000u   /* 2스레드 테스트 메시지 수 */
#define STRESS_CAPACITY  1024u      /* 작게 잡아 가득 참·비어 있음 경로를 자주 지나게 한다 */

static int g_FailCount = 0;

/*-----------------------------------------------------------------------------
검사 실패를 기록하고 계속 진행한다. 위치를 남기려고 함수로 감싼다.
-----------------------------------------------------------------------------*/
static void Check(int cond, const char *what, int line)
{
    if (!cond)
    {
        fprintf(stderr, "[FAIL] line %d: %s\n", line, what);
        g_FailCount++;
    }
}

/*-----------------------------------------------------------------------------
테스트: 2의 거듭제곱이 아닌 용량·0 슬롯·NULL 출력 인자는 거부된다
-----------------------------------------------------------------------------*/
static void TestCreateRejectsBadArgs(void)
{
    SpscRing *ring = NULL;

    Check(SpscRingCreate(0, 8, &ring) == -EINVAL, "용량 0 거부", __LINE__);
    Check(SpscRingCreate(3, 8, &ring) == -EINVAL, "용량 3 거부", __LINE__);
    Check(SpscRingCreate(4, 0, &ring) == -EINVAL, "슬롯 0 거부", __LINE__);
    Check(SpscRingCreate(4, 8, NULL) == -EINVAL, "NULL 출력 거부", __LINE__);
    Check(ring == NULL, "실패 시 출력 미변경", __LINE__);
}

/*-----------------------------------------------------------------------------
테스트: 빈 링 pop은 -EAGAIN, 가득 찬 링 push는 -EAGAIN, 감싸기 후에도 순서 유지
-----------------------------------------------------------------------------*/
static void TestFullEmptyAndWrap(void)
{
    SpscRing *ring  = NULL;
    uint32_t  value = 0;
    uint32_t  ii    = 0;
    uint32_t  round = 0;

    /* Arrange */
    Check(SpscRingCreate(4, sizeof(uint32_t), &ring) == 0, "생성", __LINE__);
    if (ring == NULL)
    {
        return;
    }

    /* Act·Assert: 비어 있음 */
    Check(SpscRingTryPop(ring, &value) == -EAGAIN, "빈 링 pop", __LINE__);

    /* 여러 바퀴를 돌며 가득 참과 감싸기를 확인한다 */
    for (round = 0; round < 3; round++)
    {
        for (ii = 0; ii < 4; ii++)
        {
            value = round * 100 + ii;
            Check(SpscRingTryPush(ring, &value) == 0, "push", __LINE__);
        }
        Check(SpscRingCount(ring) == 4, "가득 찬 개수", __LINE__);
        Check(SpscRingTryPush(ring, &value) == -EAGAIN, "가득 찬 링 push", __LINE__);

        for (ii = 0; ii < 4; ii++)
        {
            Check(SpscRingTryPop(ring, &value) == 0, "pop", __LINE__);
            Check(value == round * 100 + ii, "FIFO 순서", __LINE__);
        }
        Check(SpscRingTryPop(ring, &value) == -EAGAIN, "다시 비어 있음", __LINE__);
    }

    SpscRingDestroy(ring);
}

/*-----------------------------------------------------------------------------
2스레드 테스트: 생산자는 0..N-1을 차례로 넣고, 소비자는 같은 순서로 받는지 확인한다.
가득 차거나 비어 있으면 양보 후 재시도한다(테스트 전용 대기 정책).
-----------------------------------------------------------------------------*/
typedef struct
{
    SpscRing *ring;
    uint64_t  received;     /* 소비자가 받은 개수 */
    uint64_t  mismatches;   /* 순서가 어긋난 횟수 */
} StressCtx;

static void *ProducerMain(void *arg)
{
    StressCtx *ctx = arg;
    uint64_t   seq = 0;

    for (seq = 0; seq < STRESS_MSG_COUNT; seq++)
    {
        while (SpscRingTryPush(ctx->ring, &seq) == -EAGAIN)
        {
            sched_yield();
        }
    }
    return NULL;
}

static void *ConsumerMain(void *arg)
{
    StressCtx *ctx      = arg;
    uint64_t   expected = 0;
    uint64_t   value    = 0;

    while (expected < STRESS_MSG_COUNT)
    {
        if (SpscRingTryPop(ctx->ring, &value) == -EAGAIN)
        {
            sched_yield();
            continue;
        }
        if (value != expected)
        {
            ctx->mismatches++;
        }
        expected++;
    }
    ctx->received = expected;
    return NULL;
}

static void TestProducerConsumerTwoThreads(void)
{
    StressCtx ctx      = {0};
    pthread_t producer;
    pthread_t consumer;

    /* Arrange */
    Check(SpscRingCreate(STRESS_CAPACITY, sizeof(uint64_t), &ctx.ring) == 0, "생성", __LINE__);
    if (ctx.ring == NULL)
    {
        return;
    }

    /* Act */
    Check(pthread_create(&consumer, NULL, ConsumerMain, &ctx) == 0, "소비자 시작", __LINE__);
    Check(pthread_create(&producer, NULL, ProducerMain, &ctx) == 0, "생산자 시작", __LINE__);
    pthread_join(producer, NULL);
    pthread_join(consumer, NULL);

    /* Assert */
    Check(ctx.received == STRESS_MSG_COUNT, "전량 수신", __LINE__);
    Check(ctx.mismatches == 0, "순서·값 일치", __LINE__);
    Check(SpscRingCount(ctx.ring) == 0, "종료 후 비어 있음", __LINE__);

    SpscRingDestroy(ctx.ring);
}

int main(void)
{
    TestCreateRejectsBadArgs();
    TestFullEmptyAndWrap();
    TestProducerConsumerTwoThreads();

    if (g_FailCount != 0)
    {
        fprintf(stderr, "test_spsc_ring: %d건 실패\n", g_FailCount);
        return EXIT_FAILURE;
    }
    printf("test_spsc_ring: 통과 (2스레드 %u건)\n", STRESS_MSG_COUNT);
    return EXIT_SUCCESS;
}
