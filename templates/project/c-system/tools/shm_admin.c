/*#############################################################################
FILE NAME   : shm_admin.c
DESCRIPTION : shmctl.sh 보조 실행 파일 — POSIX 세그먼트 존재 확인·생성·삭제·attach 프로세스 수
#############################################################################*/
#define _POSIX_C_SOURCE 200809L

/* 1. 표준 라이브러리 */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* 4. 프로젝트 내부 헤더 */
#include "shm_segment.h"
#include "shm_tool.h"
#include "sorted_table.h"

/*-----------------------------------------------------------------------------
안전 조건(dry-run 기본·확인 프롬프트·소유 프로세스 확인)은 shmctl.sh 가 맡는다.
이 프로그램은 요청받은 한 가지 동작만 하고 결과를 종료 코드로 돌려준다.
  exists       : 0 있음, 1 없음
  attach-count : 표준 출력에 수, 셀 수 없으면 "unknown"
  create       : ShmSegCreate(상태 INIT, 레코드 0건). 이미 있으면 1
  remove       : ShmSegRemove
-----------------------------------------------------------------------------*/
#define ADMIN_MODE_DEFAULT  0600

static void PrintUsage(void)
{
    fprintf(stderr,
            "사용법: shm_admin exists|attach-count|remove /<이름>\n"
            "        shm_admin create /<이름> <레코드 수> [권한 8진수, 기본 0600]\n");
}

static int CmdCreate(const char *name, const char *cap_text, const char *mode_text)
{
    ShmSeg       *seg    = NULL;
    ShmLayout     layout = { ITEM_LAYOUT_VER, (uint32_t)sizeof(ItemRec), 0 };
    char         *end    = NULL;
    unsigned long cap    = strtoul(cap_text, &end, 10);
    unsigned long mode   = ADMIN_MODE_DEFAULT;
    int           ret    = 0;

    if (*end != '\0' || cap == 0 || cap > UINT32_MAX)
    {
        return -EINVAL;
    }
    if (mode_text != NULL)
    {
        mode = strtoul(mode_text, &end, 8);
        /* 0600·0640 처럼 그룹 쓰기·다른 사용자 권한이 없는 값만 받는다 */
        if (*end != '\0' || (mode & ~0640ul) != 0)
        {
            return -EINVAL;
        }
    }
    layout.rec_cap = (uint32_t)cap;
    ret = ShmSegCreate(name, &layout, (mode_t)mode, &seg);
    if (ret == 0)
    {
        printf("created=%s rec_cap=%lu size=%zu state=INIT\n", name, cap, ShmSegCalcSize(&layout));
        ShmSegDetach(seg);
    }
    return ret;
}

int main(int argc, char **argv)
{
    const char *cmd  = (argc > 1) ? argv[1] : "";
    const char *name = (argc > 2) ? argv[2] : NULL;
    ShmHdr      peek;
    int         ret  = 0;

    if (!ShmToolNameValid(name))
    {
        PrintUsage();
        return TOOL_EXIT_ERROR;
    }
    if (strcmp(cmd, "exists") == 0)
    {
        ret = ShmSegPeekHdr(name, &peek);
        return (ret == 0 || ret == -EAGAIN) ? TOOL_EXIT_OK : TOOL_EXIT_ERROR;
    }
    if (strcmp(cmd, "attach-count") == 0)
    {
        ret = ShmToolAttachCount(name);
        if (ret < 0) { printf("unknown\n"); }
        else         { printf("%d\n", ret); }
        return TOOL_EXIT_OK;
    }
    if (strcmp(cmd, "create") == 0 && argc >= 4 && argc <= 5)
    {
        ret = CmdCreate(name, argv[3], argc == 5 ? argv[4] : NULL);
    }
    else if (strcmp(cmd, "remove") == 0 && argc == 3)
    {
        ret = ShmSegRemove(name);
    }
    else
    {
        PrintUsage();
        return TOOL_EXIT_ERROR;
    }
    if (ret != 0)
    {
        fprintf(stderr, "[shm_admin] %s %s 실패: %s\n", cmd, name, strerror(-ret));
        return TOOL_EXIT_ERROR;
    }
    return TOOL_EXIT_OK;
}
