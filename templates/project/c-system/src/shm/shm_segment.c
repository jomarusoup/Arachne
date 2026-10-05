/*#############################################################################
FILE NAME   : shm_segment.c
DESCRIPTION : POSIX 공유메모리 세그먼트 생성·attach 검증·robust 뮤텍스·상태 전환 구현
#############################################################################*/
#define _POSIX_C_SOURCE 200809L

/* 1. 표준 라이브러리 */
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* 2. POSIX / 시스템 헤더 */
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

/* 4. 프로젝트 내부 헤더 */
#include "shm_segment.h"

#define SHM_NAME_MAX_LEN   64u
#define FNV_OFFSET_BASIS   0xcbf29ce484222325ull
#define FNV_PRIME          0x100000001b3ull

/* 프로세스 지역 핸들 — 공유메모리 밖에 있으므로 포인터를 담아도 된다 */
struct ShmSeg
{
    ShmHdr   *hdr;                          /* 매핑 시작 = 헤더 */
    size_t    map_size;                     /* 매핑 바이트 크기 */
    bool      is_rdonly;                    /* 읽기 전용 매핑 여부 */
    char      name[SHM_NAME_MAX_LEN];       /* 진단용 이름 사본 */
};

/*-----------------------------------------------------------------------------
허용된 상태 전이표 — [from][to]. 표에 없는 전이는 거부한다.
INIT → READY(적재 완료) · READY ⇄ RECOVERING(재적재) · 어디서든 → CORRUPT ·
CORRUPT → RECOVERING(복구 시작)
-----------------------------------------------------------------------------*/
static const bool g_ShmStateEdge[5][5] =
{
    /*            -      INIT   READY  RECOV  CORRUPT */
    /* -     */ { false, false, false, false, false },
    /* INIT  */ { false, false, true,  false, true  },
    /* READY */ { false, false, false, true,  true  },
    /* RECOV */ { false, false, true,  false, true  },
    /* CORR  */ { false, false, false, true,  false },
};

size_t ShmSegCalcSize(const ShmLayout *layout)
{
    size_t data_size = 0;

    if (layout == NULL || layout->rec_size == 0 || layout->rec_cap == 0)
    {
        return 0;
    }
    if ((size_t)layout->rec_cap > (SIZE_MAX - SHM_HDR_SIZE) / layout->rec_size)
    {
        return 0;   /* 넘침 */
    }
    data_size = (size_t)layout->rec_size * layout->rec_cap;
    return SHM_HDR_SIZE + data_size;
}

int ShmHdrCheck(const ShmHdr *hdr, const ShmLayout *layout, size_t map_size,
                uint32_t flags)
{
    uint32_t magic = 0;
    uint32_t state = 0;

    if (hdr == NULL || layout == NULL)
    {
        return -EINVAL;
    }
    /* acquire — 생성자가 매직 앞에 쓴 필드가 모두 보인다 */
    magic = (map_size < SHM_HDR_SIZE) ? 0 : atomic_load_explicit(&hdr->magic, memory_order_acquire);
    if (magic == 0)
    {
        return -EAGAIN;     /* 생성자가 아직 초기화 중 */
    }
    if (magic != SHM_MAGIC)
    {
        return -EBADMSG;
    }
    if (hdr->layout_ver != layout->layout_ver || hdr->rec_size != layout->rec_size)
    {
        return -EPROTO;     /* 다른 버전의 프로그램이 만든 세그먼트 */
    }
    if (hdr->rec_cap != layout->rec_cap || ShmSegCalcSize(layout) != map_size ||
        hdr->rec_cnt > hdr->rec_cap)
    {
        return -EINVAL;
    }
    state = atomic_load(&hdr->state);
    if (state < SHM_STATE_INIT || state > SHM_STATE_CORRUPT)
    {
        return -EIO;
    }
    if (state == SHM_STATE_CORRUPT && (flags & SHM_ATTACH_ALLOW_CORRUPT) == 0)
    {
        return -EIO;
    }
    return 0;
}

/*=============================================================================
FUNCTION    : ShmLockInit
DESCRIPTION : 프로세스 공유 뮤텍스를 초기화한다. 리눅스는 robust 속성을 켠다
PARAMETERS  : pthread_mutex_t *mutex - 공유메모리 안의 뮤텍스
RETURNED    : 0 성공, 음수 errno
=============================================================================*/
static int ShmLockInit(pthread_mutex_t *mutex)
{
    pthread_mutexattr_t attr;
    int                 rc = 0;

    rc = pthread_mutexattr_init(&attr);
    if (rc != 0)
    {
        return -rc;
    }
    rc = pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
#ifdef __linux__
    /* 리눅스 전용: 소유 프로세스 사망을 EOWNERDEAD 로 알린다 */
    if (rc == 0)
    {
        rc = pthread_mutexattr_setrobust(&attr, PTHREAD_MUTEX_ROBUST);
    }
#endif
    if (rc == 0)
    {
        rc = pthread_mutex_init(mutex, &attr);
    }
    pthread_mutexattr_destroy(&attr);
    return -rc;
}

/*=============================================================================
FUNCTION    : ShmMapFd
DESCRIPTION : fd 를 매핑해 핸들을 만든다. fd 는 호출자가 닫는다
PARAMETERS  : int fd            - shm_open 결과
              size_t map_size   - 매핑 크기
              bool is_rdonly    - 읽기 전용 여부
              const char *name  - 세그먼트 이름
              ShmSeg **out      - 생성된 핸들
RETURNED    : 0 성공, 음수 errno
=============================================================================*/
static int ShmMapFd(int fd, size_t map_size, bool is_rdonly, const char *name, ShmSeg **out)
{
    ShmSeg *seg  = NULL;
    void   *addr = MAP_FAILED;
    int     prot = is_rdonly ? PROT_READ : (PROT_READ | PROT_WRITE);

    seg = calloc(1, sizeof(*seg));
    if (seg == NULL)
    {
        return -ENOMEM;
    }
    addr = mmap(NULL, map_size, prot, MAP_SHARED, fd, 0);
    if (addr == MAP_FAILED)
    {
        int saved_errno = errno;

        free(seg);
        return -saved_errno;
    }
    seg->hdr       = addr;
    seg->map_size  = map_size;
    seg->is_rdonly = is_rdonly;
    strncpy(seg->name, name, sizeof(seg->name) - 1);
    *out = seg;
    return 0;
}

int ShmSegCreate(const char *name, const ShmLayout *layout, mode_t mode, ShmSeg **out)
{
    int     ret      = -EIO;
    int     fd       = -1;
    size_t  map_size = ShmSegCalcSize(layout);
    ShmSeg *seg      = NULL;
    ShmHdr *hdr      = NULL;

    if (name == NULL || out == NULL || map_size == 0 || strlen(name) >= SHM_NAME_MAX_LEN)
    {
        return -EINVAL;
    }
    fd = shm_open(name, O_RDWR | O_CREAT | O_EXCL, mode);
    if (fd < 0)
    {
        return -errno;
    }
    if (ftruncate(fd, (off_t)map_size) != 0)
    {
        ret = -errno;
        goto cleanup;
    }
    ret = ShmMapFd(fd, map_size, false, name, &seg);
    if (ret != 0)
    {
        goto cleanup;
    }

    /*-------------------------------------------------------------------------
    헤더 초기화 — 매직은 맨 마지막에 쓴다. attach 하는 쪽은 매직이 0 이면
    초기화 중(-EAGAIN)으로 보고 다시 시도한다.
    -------------------------------------------------------------------------*/
    hdr = seg->hdr;
    memset(hdr, 0, SHM_HDR_SIZE);
    hdr->layout_ver = layout->layout_ver;
    hdr->rec_size   = layout->rec_size;
    hdr->rec_cap    = layout->rec_cap;
    hdr->rec_cnt    = 0;
    hdr->created_ts = (int64_t)time(NULL);
    atomic_store(&hdr->state, SHM_STATE_INIT);
    ret = ShmLockInit(&hdr->lock.mutex);
    if (ret != 0)
    {
        goto cleanup;
    }
    /* release — 앞의 헤더 초기화가 매직보다 먼저 보이게 한다 */
    atomic_store_explicit(&hdr->magic, SHM_MAGIC, memory_order_release);

    *out = seg;
    seg  = NULL;
    ret  = 0;

cleanup:
    if (seg != NULL)
    {
        ShmSegDetach(seg);
        shm_unlink(name);       /* 반쯤 만든 세그먼트는 남기지 않는다 */
    }
    else if (ret != 0)
    {
        shm_unlink(name);
    }
    close(fd);
    return ret;
}

int ShmSegAttach(const char *name, const ShmLayout *layout, uint32_t flags, ShmSeg **out)
{
    int         ret       = -EIO;
    int         fd        = -1;
    bool        is_rdonly = (flags & SHM_ATTACH_RDONLY) != 0;
    size_t      map_size  = 0;
    struct stat st;
    ShmSeg     *seg       = NULL;

    if (name == NULL || layout == NULL || out == NULL || strlen(name) >= SHM_NAME_MAX_LEN)
    {
        return -EINVAL;
    }
    fd = shm_open(name, is_rdonly ? O_RDONLY : O_RDWR, 0);
    if (fd < 0)
    {
        return -errno;
    }
    if (fstat(fd, &st) != 0)
    {
        ret = -errno;
        goto cleanup;
    }
    if ((size_t)st.st_size < SHM_HDR_SIZE)
    {
        ret = -EAGAIN;          /* ftruncate 전 — 생성 중 */
        goto cleanup;
    }
    /*-------------------------------------------------------------------------
    기대 크기만 매핑한다. macOS 는 st_size 를 페이지 단위로 올려 보고하므로
    "실제 크기 >= 기대 크기" 만 확인하고, 정확한 크기는 헤더로 검증한다.
    -------------------------------------------------------------------------*/
    map_size = ShmSegCalcSize(layout);
    if (map_size == 0 || (size_t)st.st_size < map_size)
    {
        ret = -EINVAL;
        goto cleanup;
    }
    ret = ShmMapFd(fd, map_size, is_rdonly, name, &seg);
    if (ret != 0)
    {
        goto cleanup;
    }
    ret = ShmHdrCheck(seg->hdr, layout, seg->map_size, flags);
    if (ret != 0)
    {
        ShmSegDetach(seg);      /* 검증 실패한 매핑은 쓰지 않는다 */
        goto cleanup;
    }
    *out = seg;

cleanup:
    close(fd);
    return ret;
}

void ShmSegDetach(ShmSeg *seg)
{
    if (seg == NULL)
    {
        return;
    }
    munmap(seg->hdr, seg->map_size);
    free(seg);
}

int ShmSegRemove(const char *name)
{
    if (name == NULL)
    {
        return -EINVAL;
    }
    return (shm_unlink(name) == 0) ? 0 : -errno;
}

ShmHdr *ShmSegHdr(ShmSeg *seg)
{
    return seg->hdr;
}

void *ShmSegData(ShmSeg *seg)
{
    return (uint8_t *)seg->hdr + SHM_HDR_SIZE;
}

bool ShmSegIsReady(const ShmSeg *seg)
{
    return atomic_load(&seg->hdr->state) == SHM_STATE_READY;
}

int ShmSegLock(ShmSeg *seg, ShmRepairFn repair_fn, void *ctx)
{
    int rc = 0;

    if (seg == NULL || seg->is_rdonly)
    {
        return -EINVAL;         /* 읽기 전용 매핑은 락을 잡을 수 없다 */
    }
    rc = pthread_mutex_lock(&seg->hdr->lock.mutex);
    if (rc == 0)
    {
        return 0;
    }
#ifdef __linux__
    /*-------------------------------------------------------------------------
    EOWNERDEAD — 이전 소유 프로세스가 락을 쥔 채 죽었다. 락은 지금 우리가 가졌다.
    보호 대상을 검증·복구한 뒤 consistent 로 되돌린다. 복구할 수 없으면
    CORRUPT 로 표시하고 consistent 없이 푼다(이후 락은 ENOTRECOVERABLE).
    -------------------------------------------------------------------------*/
    if (rc == EOWNERDEAD)
    {
        if (repair_fn != NULL && repair_fn(seg, ctx) == 0)
        {
            rc = pthread_mutex_consistent(&seg->hdr->lock.mutex);
            if (rc == 0)
            {
                return SHM_LOCK_RECOVERED;
            }
        }
        atomic_store(&seg->hdr->state, SHM_STATE_CORRUPT);
        pthread_mutex_unlock(&seg->hdr->lock.mutex);
        return -ENOTRECOVERABLE;
    }
#else
    /* 비리눅스(macOS 등)는 robust 뮤텍스가 없다 — 개발 빌드 확인용 폴백 */
    (void)repair_fn;
    (void)ctx;
#endif
    return -rc;
}

int ShmSegUnlock(ShmSeg *seg)
{
    if (seg == NULL || seg->is_rdonly)
    {
        return -EINVAL;
    }
    return -pthread_mutex_unlock(&seg->hdr->lock.mutex);
}

int ShmSegSetState(ShmSeg *seg, ShmState from, ShmState to)
{
    uint32_t expected = (uint32_t)from;

    if (seg == NULL || seg->is_rdonly ||
        from < SHM_STATE_INIT || from > SHM_STATE_CORRUPT ||
        to < SHM_STATE_INIT || to > SHM_STATE_CORRUPT || !g_ShmStateEdge[from][to])
    {
        return -EINVAL;
    }
    if (!atomic_compare_exchange_strong(&seg->hdr->state, &expected, (uint32_t)to))
    {
        return -EAGAIN;
    }
    return 0;
}

uint64_t ShmChecksum(const void *data, size_t len)
{
    const uint8_t *pos  = data;
    uint64_t       hash = FNV_OFFSET_BASIS;
    size_t         ii   = 0;

    for (ii = 0; ii < len; ii++)
    {
        hash ^= pos[ii];
        hash *= FNV_PRIME;
    }
    return hash;
}

void ShmSegUpdateChecksum(ShmSeg *seg)
{
    ShmHdr *hdr = seg->hdr;

    hdr->checksum = ShmChecksum(ShmSegData(seg), (size_t)hdr->rec_cnt * hdr->rec_size);
}

int ShmSegVerifyChecksum(const ShmSeg *seg)
{
    const ShmHdr *hdr  = seg->hdr;
    const void   *data = (const uint8_t *)hdr + SHM_HDR_SIZE;
    uint64_t      sum  = ShmChecksum(data, (size_t)hdr->rec_cnt * hdr->rec_size);

    return (sum == hdr->checksum) ? 0 : -EBADMSG;
}
