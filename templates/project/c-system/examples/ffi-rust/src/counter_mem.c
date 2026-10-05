/*#############################################################################
FILE NAME   : counter_mem.c
DESCRIPTION : 카운터 저장소의 C 구현 — 고정 크기 배열, 동작 테이블 CounterMemOps
#############################################################################*/
#include <stdlib.h>

#include "counter.h"

typedef struct
{
    uint32_t key;
    int64_t  value;
} CounterEntry;

typedef struct
{
    CounterEntry entries[COUNTER_CAPACITY];
    size_t       count;
} CounterMem;

/* 키 위치를 찾는다. 없으면 NULL */
static CounterEntry *FindEntry(CounterMem *mem, uint32_t key)
{
    size_t ii = 0;

    for (ii = 0; ii < mem->count; ii++)
    {
        if (mem->entries[ii].key == key)
        {
            return &mem->entries[ii];
        }
    }
    return NULL;
}

/* 부호 있는 덧셈 오버플로는 UB이므로 더하기 전에 범위를 검사한다 */
static int IsAddOverflow(int64_t cur, int64_t delta)
{
    return (delta > 0 && cur > INT64_MAX - delta)
        || (delta < 0 && cur < INT64_MIN - delta);
}

static int MemAdd(void *impl, uint32_t key, int64_t delta)
{
    CounterMem   *mem   = impl;
    CounterEntry *entry = NULL;

    if (mem == NULL)
    {
        return COUNTER_ERR_NULL_PTR;
    }

    entry = FindEntry(mem, key);
    if (entry != NULL)
    {
        if (IsAddOverflow(entry->value, delta))
        {
            return COUNTER_ERR_OVERFLOW;    /* 실패 시 값을 바꾸지 않는다 */
        }
        entry->value += delta;
        return COUNTER_OK;
    }

    if (mem->count >= COUNTER_CAPACITY)
    {
        return COUNTER_ERR_FULL;
    }
    mem->entries[mem->count].key   = key;
    mem->entries[mem->count].value = delta;
    mem->count++;
    return COUNTER_OK;
}

static int MemGet(const void *impl, uint32_t key, int64_t *out)
{
    const CounterEntry *entry = NULL;

    if (impl == NULL || out == NULL)
    {
        return COUNTER_ERR_NULL_PTR;
    }

    /* FindEntry는 읽기만 하므로 const를 벗겨도 상태가 바뀌지 않는다 */
    entry = FindEntry((CounterMem *)impl, key);
    if (entry == NULL)
    {
        return COUNTER_ERR_NOT_FOUND;
    }
    *out = entry->value;
    return COUNTER_OK;
}

static void MemDestroy(void *impl)
{
    free(impl);
}

static const CounterOps g_MemOps =
{
    .version = COUNTER_OPS_VERSION,
    .add     = MemAdd,
    .get     = MemGet,
    .destroy = MemDestroy,
};

/*=============================================================================
FUNCTION    : CounterMemOps
DESCRIPTION : C 구현의 불변 동작 테이블을 돌려준다
RETURNED    : 정적 테이블 포인터 (해제하지 않는다)
=============================================================================*/
const CounterOps *CounterMemOps(void)
{
    return &g_MemOps;
}

/*=============================================================================
FUNCTION    : CounterMemNew
DESCRIPTION : 빈 C 구현 상태를 힙에 만든다
RETURNED    : 구현 상태, 실패 시 NULL (해제는 CounterMemOps()->destroy)
=============================================================================*/
void *CounterMemNew(void)
{
    return calloc(1, sizeof(CounterMem));
}
