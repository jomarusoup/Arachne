/*#############################################################################
FILE NAME   : test_counter.c
DESCRIPTION : 같은 테스트 벡터를 C·Rust 구현에 동작 테이블로 돌려 결과를 비교한다
#############################################################################*/
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "counter.h"
#ifdef WITH_RUST
#include "counter_rs.h"
#endif

typedef enum
{
    STEP_ADD,
    STEP_GET,
} StepKind;

typedef struct
{
    StepKind kind;
    uint32_t key;
    int64_t  delta;     /* STEP_ADD에서만 사용 */
    int      want_ret;
    int64_t  want_val;  /* STEP_GET 성공에서만 사용 */
} TestStep;

/* 결과 기록 — 구현 간 비교에 쓴다 */
typedef struct
{
    int     ret;
    int64_t val;
} StepResult;

/* 경계 조건 위주 벡터: 빈 키, 음수, 최대·최소값 오버플로, 용량 초과 */
static const TestStep g_Steps[] =
{
    { STEP_GET, 1, 0,         COUNTER_ERR_NOT_FOUND, 0 },
    { STEP_ADD, 1, 5,         COUNTER_OK,            0 },
    { STEP_ADD, 1, -7,        COUNTER_OK,            0 },
    { STEP_GET, 1, 0,         COUNTER_OK,            -2 },
    { STEP_ADD, 2, INT64_MAX, COUNTER_OK,            0 },
    { STEP_ADD, 2, 1,         COUNTER_ERR_OVERFLOW,  0 },
    { STEP_GET, 2, 0,         COUNTER_OK,            INT64_MAX },
    { STEP_ADD, 3, INT64_MIN, COUNTER_OK,            0 },
    { STEP_ADD, 3, -1,        COUNTER_ERR_OVERFLOW,  0 },
    { STEP_ADD, 4, 0,         COUNTER_OK,            0 },
    { STEP_ADD, 5, 1,         COUNTER_ERR_FULL,      0 },
    { STEP_GET, 5, 0,         COUNTER_ERR_NOT_FOUND, 0 },
    { STEP_ADD, 4, 9,         COUNTER_OK,            0 },
    { STEP_GET, 4, 0,         COUNTER_OK,            9 },
};

#define STEP_COUNT (sizeof(g_Steps) / sizeof(g_Steps[0]))

static int g_FailCount = 0;

static void Check(int cond, const char *what, const char *impl_name, size_t idx)
{
    if (!cond)
    {
        fprintf(stderr, "[FAIL] %s: %s (step %zu)\n", impl_name, what, idx);
        g_FailCount++;
    }
}

/*=============================================================================
FUNCTION    : RunSteps
DESCRIPTION : 벡터를 한 구현에 적용하고 기대값과 비교하며 결과를 기록한다
PARAMETERS  : const char       *impl_name - 보고용 구현 이름
              const CounterOps *ops       - 구현 동작 테이블
              void             *impl      - 구현 상태 (소유권 이전)
              StepResult       *results   - 단계별 결과 (STEP_COUNT개)
=============================================================================*/
static void RunSteps(const char *impl_name, const CounterOps *ops, void *impl,
                     StepResult *results)
{
    Counter *ctr = CounterCreate(ops, impl);
    size_t   ii  = 0;

    if (ctr == NULL)
    {
        Check(0, "CounterCreate 실패", impl_name, 0);
        if (impl != NULL)
        {
            ops->destroy(impl);     /* 생성 실패 시 impl 소유권은 호출자에 남는다 */
        }
        return;
    }

    for (ii = 0; ii < STEP_COUNT; ii++)
    {
        const TestStep *step = &g_Steps[ii];

        results[ii].val = 0;
        if (step->kind == STEP_ADD)
        {
            results[ii].ret = CounterAdd(ctr, step->key, step->delta);
        }
        else
        {
            results[ii].ret = CounterGet(ctr, step->key, &results[ii].val);
        }

        Check(results[ii].ret == step->want_ret, "반환값 불일치", impl_name, ii);
        if (step->kind == STEP_GET && step->want_ret == COUNTER_OK)
        {
            Check(results[ii].val == step->want_val, "값 불일치", impl_name, ii);
        }
    }
    CounterDestroy(ctr);
}

/* 공개 함수의 경계 검사 — 구현과 무관하게 핸들 계층에서 막는다 */
static void TestBoundary(void)
{
    static const CounterOps bad_ops = { COUNTER_OPS_VERSION + 1, NULL, NULL, NULL };
    int64_t                 val     = 0;
    void                   *impl    = CounterMemNew();

    Check(CounterAdd(NULL, 1, 1) == COUNTER_ERR_NULL_PTR, "NULL 핸들 add", "handle", 0);
    Check(CounterGet(NULL, 1, &val) == COUNTER_ERR_NULL_PTR, "NULL 핸들 get", "handle", 0);
    Check(CounterCreate(&bad_ops, impl) == NULL, "버전 불일치 거부", "handle", 0);
    Check(CounterCreate(NULL, impl) == NULL, "NULL ops 거부", "handle", 0);
    CounterDestroy(NULL);
    CounterMemOps()->destroy(impl);     /* 생성 실패였으므로 호출자가 해제 */
}

int main(void)
{
    StepResult c_results[STEP_COUNT];

    memset(c_results, 0, sizeof(c_results));
    TestBoundary();
    RunSteps("c", CounterMemOps(), CounterMemNew(), c_results);

#ifdef WITH_RUST
    {
        StepResult rs_results[STEP_COUNT];
        size_t     ii = 0;

        memset(rs_results, 0, sizeof(rs_results));
        Check(counter_rs_ops_size() == sizeof(CounterOps), "CounterOps 크기 불일치", "layout", 0);
        RunSteps("rust", &COUNTER_RS_OPS, counter_rs_new(), rs_results);

        /* 차분 비교 — 기대값이 틀려도 두 구현이 같은지 따로 확인한다 */
        for (ii = 0; ii < STEP_COUNT; ii++)
        {
            Check(c_results[ii].ret == rs_results[ii].ret
                  && c_results[ii].val == rs_results[ii].val,
                  "C·Rust 결과 불일치", "diff", ii);
        }
        printf("[ffi-rust] C·Rust 비교 %zu단계 완료\n", (size_t)STEP_COUNT);
    }
#else
    printf("[ffi-rust] C 구현만 검사 %zu단계 완료 (Rust 비교 생략)\n", (size_t)STEP_COUNT);
#endif

    if (g_FailCount > 0)
    {
        fprintf(stderr, "[ffi-rust] 실패 %d건\n", g_FailCount);
        return 1;
    }
    printf("[ffi-rust] PASS\n");
    return 0;
}
