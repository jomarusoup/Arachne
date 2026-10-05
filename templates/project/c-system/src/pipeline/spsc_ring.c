/*#############################################################################
FILE NAME   : spsc_ring.c
DESCRIPTION : C11 원자 연산 기반 SPSC 링버퍼 구현 (acquire/release, 캐시라인 패딩)
#############################################################################*/

#include <errno.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "spsc_ring.h"

/*-----------------------------------------------------------------------------
캐시라인 크기
x86-64는 64바이트지만 인접 라인 프리페치가 두 줄을 함께 가져온다.
Apple Silicon은 128바이트다. 두 경우 모두 거짓 공유를 막도록 128로 둔다.
-----------------------------------------------------------------------------*/
#define SPSC_CACHE_LINE 128

/*-----------------------------------------------------------------------------
메모리 배치
생산자가 쓰는 필드와 소비자가 쓰는 필드를 서로 다른 캐시라인에 둔다.
head·tail은 감싸지 않고 계속 증가하는 카운터다. 슬롯 위치는 (카운터 & mask)다.
size_t 카운터가 넘쳐도 부호 없는 뺄셈이라 개수 계산(head - tail)은 맞다.
-----------------------------------------------------------------------------*/
struct SpscRing
{
    /* 생산자 전용 캐시라인 */
    _Alignas(SPSC_CACHE_LINE) _Atomic size_t head;   /* 다음에 쓸 위치 — 생산자만 증가 */
    size_t                     cached_tail;           /* 생산자가 마지막으로 본 tail */

    /* 소비자 전용 캐시라인 */
    _Alignas(SPSC_CACHE_LINE) _Atomic size_t tail;   /* 다음에 읽을 위치 — 소비자만 증가 */
    size_t                     cached_head;           /* 소비자가 마지막으로 본 head */

    /* 생성 후 바뀌지 않는 읽기 전용 필드 */
    _Alignas(SPSC_CACHE_LINE) size_t mask;
    size_t                     capacity;
    size_t                     slot_size;
    unsigned char             *slots;
};

/*-----------------------------------------------------------------------------
TSan 빌드 감지
macOS의 TSan은 libc memcpy 내부 접근을 계측하지 못해 슬롯 경쟁을 놓친다.
TSan 빌드에서만 바이트 복사로 바꿔 슬롯 접근을 계측 대상으로 만든다.
-----------------------------------------------------------------------------*/
#if defined(__SANITIZE_THREAD__)
#define SPSC_VISIBLE_COPY 1
#elif defined(__has_feature)
#if __has_feature(thread_sanitizer)
#define SPSC_VISIBLE_COPY 1
#endif
#endif

static void CopySlot(void *dst, const void *src, size_t len)
{
#if defined(SPSC_VISIBLE_COPY)
    unsigned char       *out = dst;
    const unsigned char *in  = src;
    size_t               ii  = 0;

    for (ii = 0; ii < len; ii++)
    {
        out[ii] = in[ii];
    }
#else
    memcpy(dst, src, len);
#endif
}

/*-----------------------------------------------------------------------------
2의 거듭제곱 판정. 0은 거듭제곱이 아니다.
-----------------------------------------------------------------------------*/
static int IsPowerOfTwo(size_t value)
{
    return value != 0 && (value & (value - 1)) == 0;
}

/*=============================================================================
FUNCTION    : SpscRingCreate
DESCRIPTION : 링버퍼를 할당한다. 해제 책임은 호출자에게 있다(SpscRingDestroy).
PARAMETERS  : size_t    capacity  - 슬롯 개수 (2의 거듭제곱)
              size_t    slot_size - 슬롯 하나의 바이트 수 (1 이상)
              SpscRing **out_ring - 생성된 핸들을 받을 위치
RETURNED    : 0 성공, -EINVAL 잘못된 인자, -ENOMEM 할당 실패
=============================================================================*/
int SpscRingCreate(size_t capacity, size_t slot_size, SpscRing **out_ring)
{
    SpscRing *ring = NULL;

    if (out_ring == NULL || !IsPowerOfTwo(capacity) || slot_size == 0)
    {
        return -EINVAL;
    }
    if (capacity > SIZE_MAX / slot_size)
    {
        return -EINVAL;   /* 슬롯 영역 크기 계산 넘침 */
    }

    /* sizeof(SpscRing)은 정렬 때문에 SPSC_CACHE_LINE의 배수다. aligned_alloc 조건을 만족한다. */
    ring = aligned_alloc(SPSC_CACHE_LINE, sizeof(*ring));
    if (ring == NULL)
    {
        return -ENOMEM;
    }
    memset(ring, 0, sizeof(*ring));

    ring->slots = malloc(capacity * slot_size);
    if (ring->slots == NULL)
    {
        free(ring);
        return -ENOMEM;
    }

    atomic_init(&ring->head, 0);
    atomic_init(&ring->tail, 0);
    ring->cached_tail = 0;
    ring->cached_head = 0;
    ring->mask        = capacity - 1;
    ring->capacity    = capacity;
    ring->slot_size   = slot_size;

    *out_ring = ring;
    return 0;
}

/*=============================================================================
FUNCTION    : SpscRingDestroy
DESCRIPTION : 링버퍼를 해제한다. 두 스레드가 모두 사용을 마친 뒤에만 부른다.
PARAMETERS  : SpscRing *ring - 해제할 핸들 (NULL 허용)
=============================================================================*/
void SpscRingDestroy(SpscRing *ring)
{
    if (ring == NULL)
    {
        return;
    }
    free(ring->slots);
    ring->slots = NULL;
    free(ring);
}

/*=============================================================================
FUNCTION    : SpscRingTryPush
DESCRIPTION : 메시지 하나를 슬롯에 복사해 넣는다. 생산자 스레드 전용이다.
PARAMETERS  : SpscRing   *ring - 링버퍼
              const void *msg  - slot_size 바이트 메시지
RETURNED    : 0 성공, -EAGAIN 가득 참
=============================================================================*/
int SpscRingTryPush(SpscRing *ring, const void *msg)
{
    /* HOTPATH */
    size_t head = 0;

    /* head는 생산자만 쓰므로 자기 값은 relaxed로 읽어도 된다. */
    head = atomic_load_explicit(&ring->head, memory_order_relaxed);

    /*-------------------------------------------------------------------------
    가득 참 판정은 먼저 캐시된 tail로 한다. 가득 차 보일 때만 공유 tail을 다시 읽어
    소비자 캐시라인으로의 접근 횟수를 줄인다.
    acquire: 소비자가 슬롯을 다 읽은 뒤 tail을 올렸으므로, 그 슬롯을 덮어써도 안전하다.
    -------------------------------------------------------------------------*/
    if (head - ring->cached_tail == ring->capacity)
    {
        ring->cached_tail = atomic_load_explicit(&ring->tail, memory_order_acquire);
        if (head - ring->cached_tail == ring->capacity)
        {
            return -EAGAIN;
        }
    }

    CopySlot(ring->slots + (head & ring->mask) * ring->slot_size, msg, ring->slot_size);

    /* release: 슬롯 쓰기가 head 증가보다 먼저 소비자에게 보이게 한다. */
    atomic_store_explicit(&ring->head, head + 1, memory_order_release);
    return 0;
}

/*=============================================================================
FUNCTION    : SpscRingTryPop
DESCRIPTION : 메시지 하나를 꺼내 복사한다. 소비자 스레드 전용이다.
PARAMETERS  : SpscRing *ring    - 링버퍼
              void     *out_msg - slot_size 바이트를 받을 버퍼
RETURNED    : 0 성공, -EAGAIN 비어 있음
=============================================================================*/
int SpscRingTryPop(SpscRing *ring, void *out_msg)
{
    /* HOTPATH */
    size_t tail = 0;

    tail = atomic_load_explicit(&ring->tail, memory_order_relaxed);

    /* acquire: 생산자가 head를 올리기 전에 쓴 슬롯 내용이 보이게 한다. */
    if (tail == ring->cached_head)
    {
        ring->cached_head = atomic_load_explicit(&ring->head, memory_order_acquire);
        if (tail == ring->cached_head)
        {
            return -EAGAIN;
        }
    }

    CopySlot(out_msg, ring->slots + (tail & ring->mask) * ring->slot_size, ring->slot_size);

    /* release: 슬롯 읽기가 끝난 뒤에 생산자가 그 슬롯을 재사용하게 한다. */
    atomic_store_explicit(&ring->tail, tail + 1, memory_order_release);
    return 0;
}

/*=============================================================================
FUNCTION    : SpscRingCount
DESCRIPTION : 현재 적재 개수의 근사값을 돌려준다. 관측(큐 깊이 지표) 용도다.
PARAMETERS  : SpscRing *ring - 링버퍼
RETURNED    : 적재 개수 (다른 스레드가 동시에 바꾸므로 순간값)
=============================================================================*/
size_t SpscRingCount(SpscRing *ring)
{
    size_t tail  = atomic_load_explicit(&ring->tail, memory_order_acquire);
    size_t head  = atomic_load_explicit(&ring->head, memory_order_acquire);
    size_t count = head - tail;

    /* 두 값을 읽는 사이에 생산자가 앞서 나가면 capacity를 넘겨 보일 수 있다. */
    return count > ring->capacity ? ring->capacity : count;
}

/*=============================================================================
FUNCTION    : SpscRingCapacity
DESCRIPTION : 슬롯 개수를 돌려준다.
PARAMETERS  : const SpscRing *ring - 링버퍼
RETURNED    : 생성 시 지정한 capacity
=============================================================================*/
size_t SpscRingCapacity(const SpscRing *ring)
{
    return ring->capacity;
}
