/*#############################################################################
FILE NAME   : shm_segment.h
DESCRIPTION : 공유메모리 세그먼트 헤더 구조와 생성·attach·락·상태 전환 API
#############################################################################*/
#ifndef SHM_SEGMENT_H
#define SHM_SEGMENT_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdatomic.h>
#include <sys/types.h>

#include <pthread.h>

/*-----------------------------------------------------------------------------
세그먼트 레이아웃 상수
- SHM_MAGIC 은 세그먼트 종류를 식별한다. 0 은 "아직 초기화 중"을 뜻하므로 쓰지 않는다.
- 헤더 크기는 128바이트로 고정한다. 레코드 영역은 헤더 바로 뒤(64바이트 정렬)에서 시작한다.
-----------------------------------------------------------------------------*/
#define SHM_MAGIC           0x41524331u     /* "ARC1" */
#define SHM_HDR_SIZE        128u
#define SHM_LOCK_RAW_SIZE   64u
#define SHM_LOCK_RECOVERED  1               /* ShmSegLock: 죽은 소유자의 락을 복구해 획득 */

/* 세그먼트 상태 플래그 — 0 은 쓰지 않는다(빈 메모리와 구분) */
typedef enum ShmState
{
    SHM_STATE_INIT       = 1,   /* 생성 직후·적재 중 — 조회 금지 */
    SHM_STATE_READY      = 2,   /* 정상 — 조회·갱신 가능 */
    SHM_STATE_RECOVERING = 3,   /* 복구·재적재 중 — 조회 금지 */
    SHM_STATE_CORRUPT    = 4,   /* 손상 — DB 재적재 전까지 사용 금지 */
} ShmState;

/* attach 옵션 비트 */
#define SHM_ATTACH_RDONLY         0x1u  /* 읽기 전용 매핑(조회 도구용) */
#define SHM_ATTACH_ALLOW_CORRUPT  0x2u  /* CORRUPT 상태도 attach 허용(복구 도구용) */
#define SHM_ATTACH_NO_CHECK       0x4u  /* 헤더 검증 생략 — 진단·복구 도구 전용.
                                           호출자가 ShmHdrCheck 를 직접 부르고 판정한다 */

/*-----------------------------------------------------------------------------
락 영역 — pthread_mutex_t 크기는 플랫폼마다 다르므로 고정 크기 공간 안에 둔다.
-----------------------------------------------------------------------------*/
typedef union ShmLock
{
    pthread_mutex_t mutex;
    uint8_t         raw[SHM_LOCK_RAW_SIZE];
} ShmLock;

_Static_assert(sizeof(pthread_mutex_t) <= SHM_LOCK_RAW_SIZE,
               "pthread_mutex_t 가 락 영역보다 크다");

/*-----------------------------------------------------------------------------
세그먼트 헤더 — 공유메모리 맨 앞에 놓인다. 포인터 필드는 두지 않는다.
필드를 바꾸면 SHM_HDR_SIZE 와 레이아웃 버전을 함께 검토한다.
-----------------------------------------------------------------------------*/
typedef struct ShmHdr
{
    _Atomic uint32_t  magic;        /* SHM_MAGIC — 초기화 완료 후 마지막에 release 로 기록 */
    uint32_t          layout_ver;   /* 레코드 레이아웃 버전 */
    uint32_t          rec_size;     /* 레코드 1건 바이트 크기 */
    uint32_t          rec_cap;      /* 최대 레코드 수 */
    uint32_t          rec_cnt;      /* 현재 레코드 수 — 락 안에서만 변경 */
    _Atomic uint32_t  state;        /* ShmState */
    int64_t           created_ts;   /* 생성 시각(에포크 초) */
    uint64_t          load_seq;     /* 마지막 DB 적재·반영 시퀀스 */
    uint64_t          checksum;     /* 레코드 영역 체크섬(FNV-1a 64) */
    uint8_t           reserved[16]; /* 확장 예비 — 0 으로 둔다 */
    ShmLock           lock;         /* 프로세스 공유 뮤텍스 */
} ShmHdr;

_Static_assert(sizeof(ShmHdr) == SHM_HDR_SIZE, "ShmHdr 크기가 바뀌었다");
_Static_assert(offsetof(ShmHdr, lock) == 64, "락 영역 오프셋이 바뀌었다");

/* 호출자가 기대하는 레이아웃 — attach 시 헤더와 대조한다 */
typedef struct ShmLayout
{
    uint32_t layout_ver;
    uint32_t rec_size;
    uint32_t rec_cap;
} ShmLayout;

/* 불투명 핸들 — 프로세스 지역 정보(매핑 주소·크기)를 숨긴다 */
typedef struct ShmSeg ShmSeg;

/*-----------------------------------------------------------------------------
EOWNERDEAD 복구 콜백 — 보호 대상(레코드 영역)을 검증·복구한다.
0 을 반환하면 복구 성공으로 보고 pthread_mutex_consistent 를 호출한다.
음수를 반환하면 세그먼트를 CORRUPT 로 표시한다. NULL 이면 항상 실패로 본다.
-----------------------------------------------------------------------------*/
typedef int (*ShmRepairFn)(ShmSeg *seg, void *ctx);

/*=============================================================================
FUNCTION    : ShmSegCalcSize
DESCRIPTION : 헤더 + 레코드 영역의 전체 바이트 크기를 계산한다
PARAMETERS  : const ShmLayout *layout - 레코드 크기·개수
RETURNED    : 전체 크기, 넘침이면 0
=============================================================================*/
size_t ShmSegCalcSize(const ShmLayout *layout);

/*=============================================================================
FUNCTION    : ShmHdrCheck
DESCRIPTION : 헤더를 기대 레이아웃·매핑 크기와 대조한다(순수 함수)
PARAMETERS  : const ShmHdr *hdr       - 검사할 헤더
              const ShmLayout *layout - 기대 레이아웃
              size_t map_size         - 실제 매핑 크기
              uint32_t flags          - SHM_ATTACH_* 비트
RETURNED    : 0 정상, -EAGAIN 초기화 중, -EBADMSG 매직 불일치,
              -EPROTO 버전·레코드 크기 불일치, -EINVAL 크기 불일치, -EIO 손상 상태
=============================================================================*/
int ShmHdrCheck(const ShmHdr *hdr, const ShmLayout *layout, size_t map_size,
                uint32_t flags);

/*=============================================================================
FUNCTION    : ShmSegCreate
DESCRIPTION : 세그먼트를 새로 만들고 헤더·뮤텍스를 초기화한다(상태 INIT)
PARAMETERS  : const char *name        - POSIX 이름("/" 로 시작, 31자 이하 권장)
              const ShmLayout *layout - 레코드 레이아웃
              mode_t mode             - 권한(0600 또는 0640)
              ShmSeg **out            - 생성된 핸들
RETURNED    : 0 성공, 음수 errno(이미 있으면 -EEXIST)
=============================================================================*/
int ShmSegCreate(const char *name, const ShmLayout *layout, mode_t mode, ShmSeg **out);

/*=============================================================================
FUNCTION    : ShmSegAttach
DESCRIPTION : 기존 세그먼트를 매핑하고 헤더를 검증한다. 검증 실패면 매핑을 풀고 실패한다
PARAMETERS  : const char *name        - POSIX 이름
              const ShmLayout *layout - 기대 레이아웃
              uint32_t flags          - SHM_ATTACH_* 비트
              ShmSeg **out            - attach 된 핸들
RETURNED    : 0 성공, 음수 errno(ShmHdrCheck 반환값 포함)
=============================================================================*/
int ShmSegAttach(const char *name, const ShmLayout *layout, uint32_t flags, ShmSeg **out);

/*=============================================================================
FUNCTION    : ShmSegPeekHdr
DESCRIPTION : 헤더 128바이트만 읽기 전용으로 매핑해 사본을 돌려준다(검증하지 않음).
              조회·복구 도구가 rec_cap 을 알아내 레이아웃을 만들 때 쓴다
PARAMETERS  : const char *name - POSIX 이름
              ShmHdr *out      - 헤더 사본(락 영역 사본은 쓰지 않는다)
RETURNED    : 0 성공, -EAGAIN 생성 중(크기 부족), 그 밖의 음수 errno
=============================================================================*/
int ShmSegPeekHdr(const char *name, ShmHdr *out);

/*=============================================================================
FUNCTION    : ShmSegResetHdr
DESCRIPTION : 손상된 헤더를 레이아웃대로 다시 쓰고 상태를 RECOVERING 으로 둔다.
              뮤텍스도 다시 초기화한다. 매직은 맨 마지막에 쓴다.
              복구 도구 전용 — 다른 프로세스가 attach 하지 않은 상태에서만 부른다
PARAMETERS  : ShmSeg *seg             - 쓰기 매핑 핸들(SHM_ATTACH_NO_CHECK 로 attach)
              const ShmLayout *layout - 다시 쓸 레이아웃(매핑 크기와 같아야 한다)
RETURNED    : 0 성공, -EINVAL 읽기 전용·크기 불일치, 그 밖의 음수 errno
=============================================================================*/
int ShmSegResetHdr(ShmSeg *seg, const ShmLayout *layout);

/* 매핑을 풀고 핸들을 해제한다. 세그먼트 자체는 남는다. NULL 허용 */
void ShmSegDetach(ShmSeg *seg);

/* 세그먼트 이름을 제거한다. 이미 attach 한 프로세스의 매핑은 detach 까지 유지된다 */
int ShmSegRemove(const char *name);

ShmHdr *ShmSegHdr(ShmSeg *seg);
size_t  ShmSegMapSize(const ShmSeg *seg);
void   *ShmSegData(ShmSeg *seg);
bool    ShmSegIsReady(const ShmSeg *seg);

/*=============================================================================
FUNCTION    : ShmSegLock
DESCRIPTION : 세그먼트 뮤텍스를 잡는다. 소유 프로세스가 죽었으면(EOWNERDEAD)
              repair_fn 으로 복구한 뒤 일관 상태로 되돌린다(리눅스 전용)
PARAMETERS  : ShmSeg *seg            - 세그먼트
              ShmRepairFn repair_fn  - 복구 콜백(NULL 이면 복구 불가로 처리)
              void *ctx              - 콜백 문맥
RETURNED    : 0 획득, SHM_LOCK_RECOVERED 복구 후 획득,
              -ENOTRECOVERABLE 복구 실패(CORRUPT 로 표시됨), 그 밖의 음수 errno
=============================================================================*/
int ShmSegLock(ShmSeg *seg, ShmRepairFn repair_fn, void *ctx);
int ShmSegUnlock(ShmSeg *seg);

/*=============================================================================
FUNCTION    : ShmSegSetState
DESCRIPTION : 허용된 전이만 원자적으로 수행한다(compare-and-swap)
PARAMETERS  : ShmSeg *seg   - 세그먼트
              ShmState from - 기대하는 현재 상태
              ShmState to   - 바꿀 상태
RETURNED    : 0 성공, -EINVAL 허용되지 않은 전이, -EAGAIN 현재 상태가 from 이 아님
=============================================================================*/
int ShmSegSetState(ShmSeg *seg, ShmState from, ShmState to);

/* 레코드 영역(rec_cnt 건) 체크섬 — 락 안에서 호출한다 */
uint64_t ShmChecksum(const void *data, size_t len);
void     ShmSegUpdateChecksum(ShmSeg *seg);
int      ShmSegVerifyChecksum(const ShmSeg *seg);  /* 0 일치, -EBADMSG 불일치 */

#endif /* SHM_SEGMENT_H */
