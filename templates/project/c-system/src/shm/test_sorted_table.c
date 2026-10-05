/*#############################################################################
FILE NAME   : test_sorted_table.c
DESCRIPTION : 키 정렬 배열 단위 테스트 — 정렬 불변식·경계 키·반환 규약 검증
#############################################################################*/

/* 1. 표준 라이브러리 */
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

/* 4. 프로젝트 내부 헤더 */
#include "sorted_table.h"

#define TEST_TABLE_CAP  8u

static ItemRec  g_TestRecs[TEST_TABLE_CAP];
static uint32_t g_TestCnt = 0;

/* 테이블을 비우고 뷰를 다시 연결한다 */
static void ResetTable(ItemTable *tbl)
{
    memset(g_TestRecs, 0, sizeof(g_TestRecs));
    g_TestCnt = 0;
    ItemTableBind(tbl, g_TestRecs, &g_TestCnt, TEST_TABLE_CAP);
}

static ItemRec MakeRec(uint32_t item_id)
{
    ItemRec rec = { .item_id = item_id, .group_id = item_id % 3u, .prc = (int64_t)item_id * 10 };

    return rec;
}

static void TestFindOnEmptyReturnsEnoent(void)
{
    ItemTable tbl;
    uint32_t  first = 99;

    ResetTable(&tbl);                                       /* Arrange */
    assert(ItemTableFind(&tbl, 1) == -ENOENT);              /* Act·Assert */
    assert(ItemTableFindRange(&tbl, 0, UINT32_MAX, &first) == 0);
    assert(first == 0);
}

static void TestInsertOutOfOrderKeepsSorted(void)
{
    static const uint32_t ids[] = { 50, 10, 40, 20, 30 };
    ItemTable tbl;
    size_t    ii = 0;

    ResetTable(&tbl);
    for (ii = 0; ii < sizeof(ids) / sizeof(ids[0]); ii++)
    {
        ItemRec rec = MakeRec(ids[ii]);

        assert(ItemTableInsert(&tbl, &rec) >= 0);
    }
    assert(g_TestCnt == 5);
    assert(ItemTableCheckSorted(&tbl) == 0);
    assert(ItemTableFind(&tbl, 10) == 0);
    assert(ItemTableFind(&tbl, 30) == 2);
    assert(ItemTableFind(&tbl, 50) == 4);
    assert(ItemTableFind(&tbl, 35) == -ENOENT);
}

static void TestBoundaryKeysFound(void)
{
    ItemTable tbl;
    ItemRec   rec_min = MakeRec(0);
    ItemRec   rec_max = MakeRec(UINT32_MAX);
    ItemRec   rec_mid = MakeRec(7);
    uint32_t  first   = 0;

    ResetTable(&tbl);
    assert(ItemTableInsert(&tbl, &rec_max) == 0);
    assert(ItemTableInsert(&tbl, &rec_min) == 0);
    assert(ItemTableInsert(&tbl, &rec_mid) == 1);
    assert(ItemTableFind(&tbl, 0) == 0);
    assert(ItemTableFind(&tbl, UINT32_MAX) == 2);
    /* 상한이 UINT32_MAX 여도 넘치지 않는다 */
    assert(ItemTableFindRange(&tbl, 0, UINT32_MAX, &first) == 3);
    assert(first == 0);
    assert(ItemTableFindRange(&tbl, UINT32_MAX, UINT32_MAX, &first) == 1);
    assert(first == 2);
}

static void TestDuplicateAndFullRejected(void)
{
    ItemTable tbl;
    ItemRec   rec = MakeRec(1);
    uint32_t  ii  = 0;

    ResetTable(&tbl);
    assert(ItemTableInsert(&tbl, &rec) == 0);
    assert(ItemTableInsert(&tbl, &rec) == -EEXIST);
    for (ii = 2; ii <= TEST_TABLE_CAP; ii++)
    {
        rec = MakeRec(ii);
        assert(ItemTableInsert(&tbl, &rec) >= 0);
    }
    rec = MakeRec(100);
    assert(ItemTableInsert(&tbl, &rec) == -ENOSPC);
    assert(g_TestCnt == TEST_TABLE_CAP);
}

static void TestRemoveShiftsRecords(void)
{
    ItemTable tbl;
    uint32_t  ii = 0;

    ResetTable(&tbl);
    for (ii = 1; ii <= 4; ii++)
    {
        ItemRec rec = MakeRec(ii * 10);

        assert(ItemTableInsert(&tbl, &rec) >= 0);
    }
    assert(ItemTableRemove(&tbl, 10) == 0);     /* 맨 앞 */
    assert(ItemTableRemove(&tbl, 40) == 0);     /* 맨 뒤 */
    assert(ItemTableRemove(&tbl, 99) == -ENOENT);
    assert(g_TestCnt == 2);
    assert(ItemTableFind(&tbl, 20) == 0);
    assert(ItemTableFind(&tbl, 30) == 1);
    assert(ItemTableCheckSorted(&tbl) == 0);
}

static void TestFindRangeInclusiveBounds(void)
{
    ItemTable tbl;
    uint32_t  first = 0;
    uint32_t  ii    = 0;

    ResetTable(&tbl);
    for (ii = 1; ii <= 5; ii++)
    {
        ItemRec rec = MakeRec(ii * 10);         /* 10 20 30 40 50 */

        assert(ItemTableInsert(&tbl, &rec) >= 0);
    }
    assert(ItemTableFindRange(&tbl, 20, 40, &first) == 3);
    assert(first == 1);
    assert(ItemTableFindRange(&tbl, 21, 29, &first) == 0);      /* 빈 구간 */
    assert(ItemTableFindRange(&tbl, 0, 9, &first) == 0);        /* 앞쪽 밖 */
    assert(first == 0);
    assert(ItemTableFindRange(&tbl, 51, 60, &first) == 0);      /* 뒤쪽 밖 */
    assert(first == 5);
    assert(ItemTableFindRange(&tbl, 40, 20, &first) == -EINVAL);
}

static void TestBulkLoadSortsAndRejectsDuplicate(void)
{
    ItemTable tbl;
    ItemRec   unsorted[4] = { MakeRec(9), MakeRec(3), MakeRec(7), MakeRec(1) };
    ItemRec   dup[3]      = { MakeRec(5), MakeRec(2), MakeRec(5) };
    ItemRec   too_many[TEST_TABLE_CAP + 1];

    ResetTable(&tbl);
    assert(ItemTableBulkLoad(&tbl, unsorted, 4) == 4);
    assert(ItemTableCheckSorted(&tbl) == 0);
    assert(g_TestRecs[0].item_id == 1);
    assert(g_TestRecs[3].item_id == 9);

    assert(ItemTableBulkLoad(&tbl, dup, 3) == -EEXIST);
    assert(g_TestCnt == 0);                     /* 적재 취소 */

    memset(too_many, 0, sizeof(too_many));
    assert(ItemTableBulkLoad(&tbl, too_many, TEST_TABLE_CAP + 1) == -ENOSPC);
}

static void TestCheckSortedDetectsCorruption(void)
{
    ItemTable tbl;
    ItemRec   recs[3] = { MakeRec(1), MakeRec(2), MakeRec(3) };
    ItemRec   tmp;

    ResetTable(&tbl);
    assert(ItemTableBulkLoad(&tbl, recs, 3) == 3);
    tmp           = g_TestRecs[0];              /* 순서를 일부러 깨뜨린다 */
    g_TestRecs[0] = g_TestRecs[2];
    g_TestRecs[2] = tmp;
    assert(ItemTableCheckSorted(&tbl) == -EILSEQ);
    g_TestCnt = TEST_TABLE_CAP + 1;             /* 건수가 용량을 넘는 손상 */
    assert(ItemTableCheckSorted(&tbl) == -EILSEQ);
}

static void TestGroupComparatorOrdersByGroupThenId(void)
{
    ItemRec lhs = { .item_id = 9, .group_id = 1 };
    ItemRec rhs = { .item_id = 1, .group_id = 2 };
    ItemRec same_group = { .item_id = 10, .group_id = 1 };

    assert(ItemCmpByGroupId(&lhs, &rhs) < 0);
    assert(ItemCmpByGroupId(&lhs, &same_group) < 0);
    assert(ItemCmpByGroupId(&lhs, &lhs) == 0);
}

int main(void)
{
    TestFindOnEmptyReturnsEnoent();
    TestInsertOutOfOrderKeepsSorted();
    TestBoundaryKeysFound();
    TestDuplicateAndFullRejected();
    TestRemoveShiftsRecords();
    TestFindRangeInclusiveBounds();
    TestBulkLoadSortsAndRejectsDuplicate();
    TestCheckSortedDetectsCorruption();
    TestGroupComparatorOrdersByGroupThenId();
    printf("test_sorted_table: 9개 통과\n");
    return 0;
}
