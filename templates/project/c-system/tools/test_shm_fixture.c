/*#############################################################################
FILE NAME   : test_shm_fixture.c
DESCRIPTION : 도구 테스트용 고정물 — 기존 생성 API 로 세그먼트를 만들어 합성 레코드를 채우고 손상을 주입한다
#############################################################################*/
#define _POSIX_C_SOURCE 200809L

/* 1. 표준 라이브러리 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* 2. POSIX / 시스템 헤더 */
#include <unistd.h>

/* 4. 프로젝트 내부 헤더 */
#include "shm_segment.h"
#include "shm_tool.h"
#include "sorted_table.h"

#define FIXTURE_KEY_STEP    10u
#define FIXTURE_MODE        0600

/*-----------------------------------------------------------------------------
  fill /<이름> <용량> <건수>  : ShmSegCreate → 합성 레코드 적재 → 체크섬 → INIT→READY
                                item_id = 10, 20, 30 …  name = "cust-0001" …(합성 값)
  corrupt-magic /<이름>       : 매직을 0xdeadbeef 로 덮어쓴다
  hold /<이름> <초>           : 읽기 전용으로 attach 한 채 기다린다(attach 수 검사용)
-----------------------------------------------------------------------------*/
static int Fill(const char *name, uint32_t cap, uint32_t cnt)
{
    ShmLayout layout = { ITEM_LAYOUT_VER, (uint32_t)sizeof(ItemRec), cap };
    ShmSeg   *seg    = NULL;
    ItemRec  *rows   = calloc(cnt ? cnt : 1, sizeof(ItemRec));
    ShmHdr   *hdr    = NULL;
    ItemTable tbl;
    uint32_t  ii     = 0;
    int       ret    = (rows == NULL) ? -ENOMEM : ShmSegCreate(name, &layout, FIXTURE_MODE, &seg);

    if (ret != 0)
    {
        free(rows);
        return ret;
    }
    for (ii = 0; ii < cnt; ii++)
    {
        /* 역순으로 넣어 BulkLoad 의 정렬을 거치게 한다 */
        ItemRec *rec = &rows[cnt - 1 - ii];

        rec->item_id  = (ii + 1) * FIXTURE_KEY_STEP;
        rec->group_id = ii % 3;
        rec->prc      = 1000 + (int64_t)ii;
        rec->qty      = (int64_t)ii * 2;
        rec->last_ts  = 1700000000000000LL + (int64_t)ii;
        snprintf(rec->name, sizeof(rec->name), "cust-%04u", ii + 1);
    }
    hdr = ShmSegHdr(seg);
    ItemTableBind(&tbl, ShmSegData(seg), &hdr->rec_cnt, hdr->rec_cap);
    ret = ShmSegLock(seg, NULL, NULL);
    if (ret == 0)
    {
        ret = ItemTableBulkLoad(&tbl, rows, cnt);
        hdr->load_seq = 1;
        ShmSegUpdateChecksum(seg);
        ShmSegUnlock(seg);
    }
    ret = (ret < 0) ? ret : ShmSegSetState(seg, SHM_STATE_INIT, SHM_STATE_READY);
    ShmSegDetach(seg);
    free(rows);
    return ret;
}

static int CorruptMagic(const char *name)
{
    ShmHdr    peek;
    ShmLayout layout;
    ShmSeg   *seg = NULL;
    int       ret = ShmSegPeekHdr(name, &peek);

    ret = (ret == 0) ? ShmToolLayout(&peek, 0, &layout) : ret;
    ret = (ret == 0) ? ShmSegAttach(name, &layout, SHM_ATTACH_NO_CHECK, &seg) : ret;
    if (ret == 0)
    {
        atomic_store(&ShmSegHdr(seg)->magic, 0xdeadbeefu);
        ShmSegDetach(seg);
    }
    return ret;
}

static int Hold(const char *name, unsigned secs)
{
    ShmHdr    peek;
    ShmLayout layout;
    ShmSeg   *seg = NULL;
    int       ret = ShmSegPeekHdr(name, &peek);

    ret = (ret == 0) ? ShmToolLayout(&peek, 0, &layout) : ret;
    ret = (ret == 0) ? ShmSegAttach(name, &layout, SHM_ATTACH_RDONLY, &seg) : ret;
    if (ret == 0)
    {
        printf("holding\n");
        fflush(stdout);
        while (secs > 0)
        {
            secs = sleep(secs);     /* 시그널로 깨면 남은 시간만큼 다시 잔다 */
        }
        ShmSegDetach(seg);
    }
    return ret;
}

int main(int argc, char **argv)
{
    int ret = -EINVAL;

    if (argc == 5 && strcmp(argv[1], "fill") == 0 && ShmToolNameValid(argv[2]))
    {
        ret = Fill(argv[2], (uint32_t)strtoul(argv[3], NULL, 10),
                   (uint32_t)strtoul(argv[4], NULL, 10));
    }
    else if (argc == 3 && strcmp(argv[1], "corrupt-magic") == 0 && ShmToolNameValid(argv[2]))
    {
        ret = CorruptMagic(argv[2]);
    }
    else if (argc == 4 && strcmp(argv[1], "hold") == 0 && ShmToolNameValid(argv[2]))
    {
        ret = Hold(argv[2], (unsigned)strtoul(argv[3], NULL, 10));
    }
    if (ret != 0)
    {
        fprintf(stderr, "[test_shm_fixture] 실패: %s\n", strerror(ret < 0 ? -ret : ret));
        return 1;
    }
    return 0;
}
