/*#############################################################################
FILE NAME   : rec_loader_db.c
DESCRIPTION : DB 원천 적재 자리표시 — Pro*C 호스트 배열 fetch 가 들어갈 위치와 계약(빌드에 Oracle 불필요)
#############################################################################*/
#define _POSIX_C_SOURCE 200809L

/* 1. 표준 라이브러리 */
#include <errno.h>
#include <stdio.h>

/* 4. 프로젝트 내부 헤더 */
#include "rec_loader.h"

/*-----------------------------------------------------------------------------
실제 프로젝트에서는 이 파일을 rec_loader_db.pc 로 바꾸고 proc 로 프리컴파일한다.
계약은 g_FileLoaderOps 와 같다. 아래는 각 함수에 들어갈 Pro*C 골격이다
(호스트 배열 크기·컨텍스트·재접속은 embedded-sql 스킬, 적재 순서는 shm-db-patterns 스킬).

  Open(src = 접속 별칭):
      EXEC SQL CONNECT :user_pass;            -- 접속 정보는 환경변수·지갑에서. 코드에 두지 않는다
      EXEC SQL DECLARE item_cur CURSOR FOR
          SELECT item_id, group_id, prc, qty, last_ts, name, flags
          FROM   item_master ORDER BY item_id;
      EXEC SQL OPEN item_cur;

  FetchBatch(buf, max_cnt):
      -- 호스트 배열 h_item_id[FETCH_ROWS] … 와 인디케이터 배열을 선언해 두고
      EXEC SQL FOR :n FETCH item_cur INTO :h_item_id, :h_group_id, :h_prc, :h_qty,
                                          :h_last_ts, :h_name:h_name_ind, :h_flags;
      fetched = sqlca.sqlerrd[2] - total;     -- Pro*C 는 누적 건수
      -- 호스트 배열 → ItemRec 로 복사(NULL 인디케이터는 0·빈 문자열로), 건수 반환
      -- sqlca.sqlcode == 1403 이고 fetched == 0 이면 0(끝) 반환
      -- sqlca.sqlcode < 0 이면 sqlcode 와 문장 ID 만 로그에 남기고 -EIO

  Close:
      EXEC SQL CLOSE item_cur;
      EXEC SQL COMMIT WORK RELEASE;           -- 읽기 전용 세션 정리

- ORDER BY 가 있어도 복구 도구는 ItemTableBulkLoad 로 다시 정렬·중복 검사를 한다.
- 개인정보 컬럼은 공유메모리에 필요한 최소 필드만 SELECT 한다(sensitive-data-handling ⑦).
-----------------------------------------------------------------------------*/

static int DbOpen(const char *src, void **out_impl)
{
    (void)src;
    (void)out_impl;
    fprintf(stderr, "[shm_recover] db 원천은 이 빌드에 없다 — rec_loader_db.pc 로 구현한다\n");
    return -ENOTSUP;
}

static int DbFetchBatch(void *impl, ItemRec *buf, uint32_t max_cnt)
{
    (void)impl;
    (void)buf;
    (void)max_cnt;
    return -ENOTSUP;
}

static void DbClose(void *impl)
{
    (void)impl;
}

const RecLoaderOps g_DbLoaderOps = { "db", DbOpen, DbFetchBatch, DbClose };
