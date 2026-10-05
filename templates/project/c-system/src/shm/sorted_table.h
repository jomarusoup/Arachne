/*#############################################################################
FILE NAME   : sorted_table.h
DESCRIPTION : 고정 크기 품목 레코드 레이아웃·키 정의와 키 정렬 배열 조회 API
#############################################################################*/
#ifndef SORTED_TABLE_H
#define SORTED_TABLE_H

#include <stddef.h>
#include <stdint.h>

/*-----------------------------------------------------------------------------
레이아웃 정의 — 레코드 필드·키·버전은 이 헤더 하나에만 둔다.
필드를 추가·삭제·이동하면 ITEM_LAYOUT_VER 를 올린다. 공유메모리 헤더의
layout_ver 와 대조되므로, 버전이 다른 프로세스는 attach 단계에서 거부된다.
-----------------------------------------------------------------------------*/
#define ITEM_LAYOUT_VER   1u
#define ITEM_NAME_LEN     16u

/*-----------------------------------------------------------------------------
품목 레코드 — 64바이트 고정. 키 필드를 앞에 두고, 패딩을 명시 필드로 적는다.
포인터는 두지 않는다(공유메모리에 그대로 올라간다).
정렬 키: item_id 오름차순, 중복 없음.
-----------------------------------------------------------------------------*/
typedef struct ItemRec
{
    uint32_t item_id;               /* 주 키 — 테이블 정렬 기준 */
    uint32_t group_id;              /* 보조 키 — 보조 인덱스 후보 */
    int64_t  prc;                   /* 가격(최소 호가 단위 정수) */
    int64_t  qty;                   /* 수량 */
    int64_t  last_ts;               /* 마지막 갱신 시각(에포크 마이크로초) */
    char     name[ITEM_NAME_LEN];   /* 표시 이름(NUL 종료 보장 안 함) */
    uint32_t flags;                 /* 상태 비트 — ITEM_FLAG_* */
    uint8_t  reserved[12];          /* 명시 패딩 — 0 으로 둔다 */
} ItemRec;

_Static_assert(sizeof(ItemRec) == 64, "ItemRec 크기가 바뀌면 ITEM_LAYOUT_VER 를 올린다");
_Static_assert(offsetof(ItemRec, item_id) == 0, "주 키는 레코드 맨 앞에 둔다");

#define ITEM_FLAG_DIRTY   0x1u      /* DB 반영 대기 */

/*-----------------------------------------------------------------------------
필드 정의 X-매크로 테이블(D14 예외) — 조회 도구(tools/shm_view)가 이 목록으로
필드 이름·오프셋·크기·출력 종류·마스킹 여부 표를 만든다. 레코드 필드를 바꾸면
이 목록도 같은 변경에서 고친다. 목록이 레코드 전체 바이트를 덮는지는
tools/item_field.c 의 _Static_assert 가 검사한다.
  X(필드 이름, 출력 종류, 마스킹)
  출력 종류: U32 · I64 · HEX32 · TEXT(NUL 종료 보장 없는 고정 길이 문자열) · PAD(출력 안 함)
  마스킹  : NONE · ALL(값 전체 "****") · DIGITS(마지막 4자리만 남김)
예제에서는 name 을 고객명 같은 개인정보 필드로 가정해 기본 마스킹한다.
-----------------------------------------------------------------------------*/
#define ITEM_FIELD_LIST(X)                  \
    X(item_id,  U32,   NONE)                \
    X(group_id, U32,   NONE)                \
    X(prc,      I64,   NONE)                \
    X(qty,      I64,   NONE)                \
    X(last_ts,  I64,   NONE)                \
    X(name,     TEXT,  ALL)                 \
    X(flags,    HEX32, NONE)                \
    X(reserved, PAD,   NONE)

/*-----------------------------------------------------------------------------
테이블 뷰 — 프로세스 지역 구조체다. 레코드 배열과 건수는 공유메모리에 있을 수
있지만, 이 뷰 자체(포인터)는 공유메모리에 두지 않는다.
-----------------------------------------------------------------------------*/
typedef struct ItemTable
{
    ItemRec  *recs;     /* 레코드 배열 시작 */
    uint32_t *cnt_ptr;  /* 현재 건수 위치(예: ShmHdr.rec_cnt) */
    uint32_t  cap;      /* 최대 건수 */
} ItemTable;

/*-----------------------------------------------------------------------------
반환 규약(모든 조회·변경 함수 공통): 0 이상은 성공(인덱스·건수), 음수는 -errno.
  -ENOENT 없음 · -EEXIST 중복 키 · -ENOSPC 가득 참 · -EINVAL 잘못된 인자
-----------------------------------------------------------------------------*/

/* 뷰를 저장 공간에 연결한다. 건수는 *cnt_ptr 값을 그대로 쓴다 */
void ItemTableBind(ItemTable *tbl, ItemRec *recs, uint32_t *cnt_ptr, uint32_t cap);

/* 비교 함수 — 키 하나에 하나. qsort·bsearch 서명과 같다 */
int ItemCmpById(const void *lhs, const void *rhs);
/* 다중 키: group_id 오름차순 → item_id 오름차순 (보조 인덱스 정렬용) */
int ItemCmpByGroupId(const void *lhs, const void *rhs);

/*=============================================================================
FUNCTION    : ItemTableFind
DESCRIPTION : item_id 로 정확 일치 조회한다(bsearch, O(log n))
PARAMETERS  : const ItemTable *tbl - 테이블
              uint32_t item_id     - 찾을 키
RETURNED    : 레코드 인덱스, 없으면 -ENOENT
=============================================================================*/
int ItemTableFind(const ItemTable *tbl, uint32_t item_id);

/*=============================================================================
FUNCTION    : ItemTableFindRange
DESCRIPTION : lo_id 이상 hi_id 이하(양끝 포함) 레코드 구간을 찾는다
PARAMETERS  : const ItemTable *tbl - 테이블
              uint32_t lo_id       - 하한(포함)
              uint32_t hi_id       - 상한(포함)
              uint32_t *out_first  - 구간 첫 인덱스
RETURNED    : 구간 건수(0 이상), lo_id > hi_id 이면 -EINVAL
=============================================================================*/
int ItemTableFindRange(const ItemTable *tbl, uint32_t lo_id, uint32_t hi_id,
                       uint32_t *out_first);

/*=============================================================================
FUNCTION    : ItemTableInsert
DESCRIPTION : 정렬 순서를 유지하며 한 건을 삽입한다(memmove, O(n))
PARAMETERS  : ItemTable *tbl     - 테이블
              const ItemRec *rec - 삽입할 레코드
RETURNED    : 삽입 위치 인덱스, -EEXIST 중복, -ENOSPC 가득 참
=============================================================================*/
int ItemTableInsert(ItemTable *tbl, const ItemRec *rec);

/* 한 건을 지우고 뒤를 당긴다. 0 성공, -ENOENT 없음 */
int ItemTableRemove(ItemTable *tbl, uint32_t item_id);

/*=============================================================================
FUNCTION    : ItemTableBulkLoad
DESCRIPTION : 정렬되지 않은 레코드를 통째로 적재한 뒤 qsort 로 한 번에 정렬한다
              (DB 전량 적재용). 중복 키가 있으면 적재를 취소한다(건수 0)
PARAMETERS  : ItemTable *tbl      - 테이블(기존 내용은 덮어쓴다)
              const ItemRec *recs - 적재할 레코드
              uint32_t cnt        - 레코드 수
RETURNED    : 적재 건수, -ENOSPC 용량 초과, -EEXIST 중복 키
=============================================================================*/
int ItemTableBulkLoad(ItemTable *tbl, const ItemRec *recs, uint32_t cnt);

/* 정렬 불변식 검사: 0 정상, -EILSEQ 순서 위반·중복 */
int ItemTableCheckSorted(const ItemTable *tbl);

#endif /* SORTED_TABLE_H */
