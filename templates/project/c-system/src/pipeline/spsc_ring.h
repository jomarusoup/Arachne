/*#############################################################################
FILE NAME   : spsc_ring.h
DESCRIPTION : 단일 생산자-단일 소비자(SPSC) 고정 슬롯 링버퍼 공개 인터페이스
#############################################################################*/

#ifndef SPSC_RING_H
#define SPSC_RING_H

#include <stddef.h>

/*-----------------------------------------------------------------------------
사용 규약
- 생산자 스레드 하나만 SpscRingTryPush를, 소비자 스레드 하나만 SpscRingTryPop을
  부른다. 이 규약을 어기면 동작이 정의되지 않는다.
- 슬롯은 고정 크기다. 메시지는 슬롯에 복사된다. 큰 메시지는 버퍼 풀 인덱스만 넣는다.
- 가득 차거나 비어 있으면 대기하지 않고 -EAGAIN을 돌려준다. 대기·드롭 정책은 호출자가 정한다.
-----------------------------------------------------------------------------*/

typedef struct SpscRing SpscRing;

int    SpscRingCreate(size_t capacity, size_t slot_size, SpscRing **out_ring);
void   SpscRingDestroy(SpscRing *ring);
int    SpscRingTryPush(SpscRing *ring, const void *msg);
int    SpscRingTryPop(SpscRing *ring, void *out_msg);
size_t SpscRingCount(SpscRing *ring);
size_t SpscRingCapacity(const SpscRing *ring);

#endif /* SPSC_RING_H */
