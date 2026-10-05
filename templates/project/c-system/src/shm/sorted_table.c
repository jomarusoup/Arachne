/*#############################################################################
FILE NAME   : sorted_table.c
DESCRIPTION : 키 정렬 배열 — 정렬 유지 삽입·bsearch 조회·범위 조회·불변식 검사
#############################################################################*/

/* 1. 표준 라이브러리 */
#include <assert.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>

/* 4. 프로젝트 내부 헤더 */
#include "sorted_table.h"

void ItemTableBind(ItemTable *tbl, ItemRec *recs, uint32_t *cnt_ptr, uint32_t cap)
{
    tbl->recs    = recs;
    tbl->cnt_ptr = cnt_ptr;
    tbl->cap     = cap;
}

/* 뺄셈 비교는 넘칠 수 있으므로 (a > b) - (a < b) 형태만 쓴다 */
int ItemCmpById(const void *lhs, const void *rhs)
{
    const ItemRec *left  = lhs;
    const ItemRec *right = rhs;

    return (left->item_id > right->item_id) - (left->item_id < right->item_id);
}

int ItemCmpByGroupId(const void *lhs, const void *rhs)
{
    const ItemRec *left  = lhs;
    const ItemRec *right = rhs;

    if (left->group_id != right->group_id)
    {
        return (left->group_id > right->group_id) ? 1 : -1;
    }
    return ItemCmpById(lhs, rhs);
}

/*=============================================================================
FUNCTION    : ItemTableLowerBound
DESCRIPTION : item_id 이상인 첫 레코드 위치를 찾는다(없으면 건수)
PARAMETERS  : const ItemTable *tbl - 테이블
              uint32_t item_id     - 기준 키
RETURNED    : 0 ~ 건수 사이 인덱스
=============================================================================*/
static uint32_t ItemTableLowerBound(const ItemTable *tbl, uint32_t item_id)
{
    uint32_t lo = 0;
    uint32_t hi = *tbl->cnt_ptr;

    while (lo < hi)
    {
        uint32_t mid = lo + (hi - lo) / 2;

        if (tbl->recs[mid].item_id < item_id)
        {
            lo = mid + 1;
        }
        else
        {
            hi = mid;
        }
    }
    return lo;
}

int ItemTableFind(const ItemTable *tbl, uint32_t item_id)
{
    ItemRec        key   = { .item_id = item_id };
    const ItemRec *found = NULL;

    found = bsearch(&key, tbl->recs, *tbl->cnt_ptr, sizeof(ItemRec), ItemCmpById);
    if (found == NULL)
    {
        return -ENOENT;
    }
    return (int)(found - tbl->recs);
}

int ItemTableFindRange(const ItemTable *tbl, uint32_t lo_id, uint32_t hi_id,
                       uint32_t *out_first)
{
    uint32_t first = 0;
    uint32_t last  = 0;

    if (lo_id > hi_id || out_first == NULL)
    {
        return -EINVAL;
    }
    first = ItemTableLowerBound(tbl, lo_id);
    /* hi_id + 1 이 넘치는 경우(UINT32_MAX)는 끝까지가 구간이다 */
    last  = (hi_id == UINT32_MAX) ? *tbl->cnt_ptr : ItemTableLowerBound(tbl, hi_id + 1);
    *out_first = first;
    return (int)(last - first);
}

int ItemTableInsert(ItemTable *tbl, const ItemRec *rec)
{
    uint32_t cnt = *tbl->cnt_ptr;
    uint32_t pos = 0;

    if (rec == NULL)
    {
        return -EINVAL;
    }
    pos = ItemTableLowerBound(tbl, rec->item_id);
    if (pos < cnt && tbl->recs[pos].item_id == rec->item_id)
    {
        return -EEXIST;
    }
    if (cnt >= tbl->cap)
    {
        return -ENOSPC;
    }
    memmove(&tbl->recs[pos + 1], &tbl->recs[pos], (size_t)(cnt - pos) * sizeof(ItemRec));
    tbl->recs[pos] = *rec;
    *tbl->cnt_ptr  = cnt + 1;

    assert(ItemTableCheckSorted(tbl) == 0);     /* 디버그 빌드 불변식 */
    return (int)pos;
}

int ItemTableRemove(ItemTable *tbl, uint32_t item_id)
{
    uint32_t cnt = *tbl->cnt_ptr;
    int      idx = ItemTableFind(tbl, item_id);

    if (idx < 0)
    {
        return idx;
    }
    memmove(&tbl->recs[idx], &tbl->recs[idx + 1],
            (size_t)(cnt - (uint32_t)idx - 1) * sizeof(ItemRec));
    *tbl->cnt_ptr = cnt - 1;

    assert(ItemTableCheckSorted(tbl) == 0);
    return 0;
}

int ItemTableBulkLoad(ItemTable *tbl, const ItemRec *recs, uint32_t cnt)
{
    if (cnt > tbl->cap)
    {
        return -ENOSPC;
    }
    if (cnt > 0)
    {
        memcpy(tbl->recs, recs, (size_t)cnt * sizeof(ItemRec));
        /* 키가 유일하므로 qsort 가 불안정 정렬이어도 결과는 하나로 정해진다 */
        qsort(tbl->recs, cnt, sizeof(ItemRec), ItemCmpById);
    }
    *tbl->cnt_ptr = cnt;
    if (ItemTableCheckSorted(tbl) != 0)
    {
        *tbl->cnt_ptr = 0;      /* 중복 키 — 적재를 취소한다 */
        return -EEXIST;
    }
    return (int)cnt;
}

int ItemTableCheckSorted(const ItemTable *tbl)
{
    uint32_t ii = 0;

    if (*tbl->cnt_ptr > tbl->cap)
    {
        return -EILSEQ;
    }
    for (ii = 1; ii < *tbl->cnt_ptr; ii++)
    {
        if (tbl->recs[ii - 1].item_id >= tbl->recs[ii].item_id)
        {
            return -EILSEQ;     /* 순서 위반 또는 중복 키 */
        }
    }
    return 0;
}
