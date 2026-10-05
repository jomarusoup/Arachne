/*#############################################################################
FILE NAME   : counter.c
DESCRIPTION : 카운터 핸들 — 공개 함수가 검사 후 동작 테이블로 위임한다
#############################################################################*/
#include <stdlib.h>

#include "counter.h"

struct Counter
{
    const CounterOps *ops;      /* 구현별 불변 테이블 — 공유, 핸들이 소유하지 않음 */
    void             *impl;     /* 구현 상태 — 핸들이 소유, ops->destroy로 해제 */
};

/*=============================================================================
FUNCTION    : CounterCreate
DESCRIPTION : 동작 테이블을 검증하고 핸들을 만든다
PARAMETERS  : const CounterOps *ops  - 구현 동작 테이블
              void             *impl - 구현 상태 (성공 시 소유권 이전)
RETURNED    : 핸들, 실패 시 NULL (impl 소유권은 호출자에 남는다)
=============================================================================*/
Counter *CounterCreate(const CounterOps *ops, void *impl)
{
    Counter *ctr = NULL;

    if (ops == NULL || impl == NULL)
    {
        return NULL;
    }

    /* 버전이 다른 테이블은 필드 배치가 다를 수 있으므로 거부한다 */
    if (ops->version != COUNTER_OPS_VERSION
        || ops->add == NULL || ops->get == NULL || ops->destroy == NULL)
    {
        return NULL;
    }

    ctr = malloc(sizeof(*ctr));
    if (ctr == NULL)
    {
        return NULL;
    }
    ctr->ops  = ops;
    ctr->impl = impl;
    return ctr;
}

/*=============================================================================
FUNCTION    : CounterAdd
DESCRIPTION : 키의 값에 delta를 더한다. 없는 키는 delta로 새로 만든다
PARAMETERS  : Counter  *ctr   - 핸들
              uint32_t  key   - 키
              int64_t   delta - 더할 값
RETURNED    : COUNTER_OK 또는 음수 CounterErr
=============================================================================*/
int CounterAdd(Counter *ctr, uint32_t key, int64_t delta)
{
    if (ctr == NULL)
    {
        return COUNTER_ERR_NULL_PTR;
    }
    return ctr->ops->add(ctr->impl, key, delta);
}

/*=============================================================================
FUNCTION    : CounterGet
DESCRIPTION : 키의 현재 값을 읽는다. 실패하면 out을 건드리지 않는다
PARAMETERS  : const Counter *ctr - 핸들
              uint32_t       key - 키
              int64_t       *out - 결과
RETURNED    : COUNTER_OK 또는 음수 CounterErr
=============================================================================*/
int CounterGet(const Counter *ctr, uint32_t key, int64_t *out)
{
    if (ctr == NULL || out == NULL)
    {
        return COUNTER_ERR_NULL_PTR;
    }
    return ctr->ops->get(ctr->impl, key, out);
}

/*=============================================================================
FUNCTION    : CounterDestroy
DESCRIPTION : 구현 상태를 ops->destroy로 해제한 뒤 핸들을 해제한다. NULL은 무시한다
PARAMETERS  : Counter *ctr - 핸들
=============================================================================*/
void CounterDestroy(Counter *ctr)
{
    if (ctr == NULL)
    {
        return;
    }
    ctr->ops->destroy(ctr->impl);
    free(ctr);
}
