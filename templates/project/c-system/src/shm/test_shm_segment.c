/*#############################################################################
FILE NAME   : test_shm_segment.c
DESCRIPTION : 공유메모리 세그먼트 단위 테스트 — 헤더 검증·상태 전이·락·체크섬·EOWNERDEAD
#############################################################################*/
#define _POSIX_C_SOURCE 200809L

/* 1. 표준 라이브러리 */
#include <assert.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>

/* 2. POSIX / 시스템 헤더 */
#include <sys/wait.h>
#include <unistd.h>

/* 4. 프로젝트 내부 헤더 */
#include "shm_segment.h"
#include "sorted_table.h"

#define TEST_REC_CAP   16u
#define TEST_MODE      0600

static char g_TestShmName[32] = "";
static int  g_RepairCallCnt   = 0;

static ShmLayout MakeLayout(void)
{
    ShmLayout layout = { ITEM_LAYOUT_VER, (uint32_t)sizeof(ItemRec), TEST_REC_CAP };

    return layout;
}

/* 테스트마다 같은 이름을 쓰므로 남은 세그먼트를 먼저 지운다 */
static ShmSeg *CreateFresh(void)
{
    ShmLayout layout = MakeLayout();
    ShmSeg   *seg    = NULL;

    (void)ShmSegRemove(g_TestShmName);
    assert(ShmSegCreate(g_TestShmName, &layout, TEST_MODE, &seg) == 0);
    return seg;
}

static int RepairOk(ShmSeg *seg, void *ctx)
{
    (void)seg;
    (void)ctx;
    g_RepairCallCnt++;
    return 0;
}

static void TestCreateThenAttachValidatesHeader(void)
{
    ShmLayout layout = MakeLayout();
    ShmSeg   *owner  = CreateFresh();
    ShmSeg   *reader = NULL;
    ShmSeg   *dup    = NULL;

    assert(ShmSegHdr(owner)->magic == SHM_MAGIC);
    assert(ShmSegHdr(owner)->state == SHM_STATE_INIT);
    assert(!ShmSegIsReady(owner));
    assert(ShmSegAttach(g_TestShmName, &layout, SHM_ATTACH_RDONLY, &reader) == 0);
    assert(ShmSegHdr(reader)->rec_cap == TEST_REC_CAP);
    assert(ShmSegLock(reader, NULL, NULL) == -EINVAL);  /* 읽기 전용은 락 불가 */
    assert(ShmSegCreate(g_TestShmName, &layout, TEST_MODE, &dup) == -EEXIST);

    ShmSegDetach(reader);
    ShmSegDetach(owner);
    assert(ShmSegRemove(g_TestShmName) == 0);
}

static void TestAttachRejectsMismatchedLayout(void)
{
    ShmLayout layout = MakeLayout();
    ShmSeg   *owner  = CreateFresh();
    ShmSeg   *other  = NULL;

    layout.layout_ver = ITEM_LAYOUT_VER + 1;            /* 다른 버전의 프로그램 */
    assert(ShmSegAttach(g_TestShmName, &layout, 0, &other) == -EPROTO);
    layout = MakeLayout();
    layout.rec_size = 32;
    assert(ShmSegAttach(g_TestShmName, &layout, 0, &other) == -EPROTO);
    layout = MakeLayout();
    layout.rec_cap = TEST_REC_CAP * 2;
    assert(ShmSegAttach(g_TestShmName, &layout, 0, &other) == -EINVAL);
    assert(other == NULL);

    ShmSegDetach(owner);
    assert(ShmSegRemove(g_TestShmName) == 0);
}

static void TestHdrCheckDetectsBadMagicAndCorrupt(void)
{
    ShmLayout layout = MakeLayout();
    size_t    size   = ShmSegCalcSize(&layout);
    ShmHdr    hdr;

    memset(&hdr, 0, sizeof(hdr));
    hdr.layout_ver = layout.layout_ver;
    hdr.rec_size   = layout.rec_size;
    hdr.rec_cap    = layout.rec_cap;
    atomic_store(&hdr.state, SHM_STATE_READY);

    assert(ShmHdrCheck(&hdr, &layout, size, 0) == -EAGAIN);    /* 매직 0 = 초기화 중 */
    hdr.magic = 0xdeadbeefu;
    assert(ShmHdrCheck(&hdr, &layout, size, 0) == -EBADMSG);
    hdr.magic = SHM_MAGIC;
    assert(ShmHdrCheck(&hdr, &layout, size, 0) == 0);
    assert(ShmHdrCheck(&hdr, &layout, size - 1, 0) == -EINVAL);
    hdr.rec_cnt = TEST_REC_CAP + 1;
    assert(ShmHdrCheck(&hdr, &layout, size, 0) == -EINVAL);
    hdr.rec_cnt = 0;
    atomic_store(&hdr.state, SHM_STATE_CORRUPT);
    assert(ShmHdrCheck(&hdr, &layout, size, 0) == -EIO);
    assert(ShmHdrCheck(&hdr, &layout, size, SHM_ATTACH_ALLOW_CORRUPT) == 0);
}

static void TestStateTransitionsFollowTable(void)
{
    ShmSeg *seg = CreateFresh();

    assert(ShmSegSetState(seg, SHM_STATE_INIT, SHM_STATE_RECOVERING) == -EINVAL);
    assert(ShmSegSetState(seg, SHM_STATE_READY, SHM_STATE_RECOVERING) == -EAGAIN);
    assert(ShmSegSetState(seg, SHM_STATE_INIT, SHM_STATE_READY) == 0);
    assert(ShmSegIsReady(seg));
    assert(ShmSegSetState(seg, SHM_STATE_READY, SHM_STATE_RECOVERING) == 0);
    assert(ShmSegSetState(seg, SHM_STATE_RECOVERING, SHM_STATE_CORRUPT) == 0);
    assert(ShmSegSetState(seg, SHM_STATE_CORRUPT, SHM_STATE_READY) == -EINVAL);
    assert(ShmSegSetState(seg, SHM_STATE_CORRUPT, SHM_STATE_RECOVERING) == 0);
    assert(ShmSegSetState(seg, SHM_STATE_RECOVERING, SHM_STATE_READY) == 0);

    ShmSegDetach(seg);
    assert(ShmSegRemove(g_TestShmName) == 0);
}

/* DB 적재를 흉내 낸다: INIT 에서 일괄 적재 → 체크섬 → READY 전환 */
static void TestLoadIntoSegmentThenVerifyChecksum(void)
{
    ShmSeg   *seg     = CreateFresh();
    ShmHdr   *hdr     = ShmSegHdr(seg);
    ItemRec   rows[3] = { { .item_id = 30 }, { .item_id = 10 }, { .item_id = 20 } };
    ItemRec   extra   = { .item_id = 15 };
    ItemTable tbl;

    ItemTableBind(&tbl, ShmSegData(seg), &hdr->rec_cnt, hdr->rec_cap);
    assert(ShmSegLock(seg, RepairOk, NULL) == 0);
    assert(ItemTableBulkLoad(&tbl, rows, 3) == 3);
    hdr->load_seq = 1;
    ShmSegUpdateChecksum(seg);
    assert(ShmSegUnlock(seg) == 0);
    assert(ShmSegSetState(seg, SHM_STATE_INIT, SHM_STATE_READY) == 0);
    assert(ShmSegVerifyChecksum(seg) == 0);
    assert(ItemTableFind(&tbl, 20) == 1);

    /* 갱신 후 체크섬을 다시 계산하지 않으면 불일치로 보인다 */
    assert(ShmSegLock(seg, RepairOk, NULL) == 0);
    assert(ItemTableInsert(&tbl, &extra) == 1);
    assert(ShmSegUnlock(seg) == 0);
    assert(ShmSegVerifyChecksum(seg) == -EBADMSG);

    ShmSegDetach(seg);
    assert(ShmSegRemove(g_TestShmName) == 0);
}

#ifdef __linux__
static int RepairFail(ShmSeg *seg, void *ctx)
{
    (void)seg;
    (void)ctx;
    g_RepairCallCnt++;
    return -EBADMSG;
}

/* 자식 프로세스가 락을 쥔 채 죽으면 부모는 EOWNERDEAD 경로를 탄다 */
static void KillChildHoldingLock(void)
{
    ShmLayout layout = MakeLayout();
    pid_t     pid    = fork();
    int       status = 0;

    assert(pid >= 0);
    if (pid == 0)
    {
        ShmSeg *child = NULL;

        if (ShmSegAttach(g_TestShmName, &layout, 0, &child) != 0 ||
            ShmSegLock(child, NULL, NULL) != 0)
        {
            _exit(1);
        }
        _exit(0);       /* 락을 풀지 않고 종료 */
    }
    assert(waitpid(pid, &status, 0) == pid);
    assert(WIFEXITED(status) && WEXITSTATUS(status) == 0);
}

static void TestOwnerDeadRepairedThenConsistent(void)
{
    ShmSeg *seg = CreateFresh();

    KillChildHoldingLock();
    g_RepairCallCnt = 0;
    assert(ShmSegLock(seg, RepairOk, NULL) == SHM_LOCK_RECOVERED);
    assert(g_RepairCallCnt == 1);
    assert(ShmSegUnlock(seg) == 0);
    assert(ShmSegLock(seg, RepairOk, NULL) == 0);       /* 다시 정상 락 */
    assert(ShmSegUnlock(seg) == 0);

    ShmSegDetach(seg);
    assert(ShmSegRemove(g_TestShmName) == 0);
}

static void TestOwnerDeadRepairFailMarksCorrupt(void)
{
    ShmSeg *seg = CreateFresh();

    KillChildHoldingLock();
    assert(ShmSegLock(seg, RepairFail, NULL) == -ENOTRECOVERABLE);
    assert(ShmSegHdr(seg)->state == SHM_STATE_CORRUPT);
    assert(ShmSegLock(seg, RepairOk, NULL) == -ENOTRECOVERABLE);  /* 재적재 전까지 사용 불가 */

    ShmSegDetach(seg);
    assert(ShmSegRemove(g_TestShmName) == 0);
}
#endif /* __linux__ */

int main(void)
{
    int test_cnt = 5;

    snprintf(g_TestShmName, sizeof(g_TestShmName), "/arachne_t%ld", (long)getpid());
    TestCreateThenAttachValidatesHeader();
    TestAttachRejectsMismatchedLayout();
    TestHdrCheckDetectsBadMagicAndCorrupt();
    TestStateTransitionsFollowTable();
    TestLoadIntoSegmentThenVerifyChecksum();
#ifdef __linux__
    TestOwnerDeadRepairedThenConsistent();
    TestOwnerDeadRepairFailMarksCorrupt();
    test_cnt += 2;
#else
    printf("test_shm_segment: robust 뮤텍스 테스트 2개 건너뜀(리눅스 전용)\n");
#endif
    printf("test_shm_segment: %d개 통과\n", test_cnt);
    return 0;
}
