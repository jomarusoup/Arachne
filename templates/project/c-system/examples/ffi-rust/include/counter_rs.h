/*#############################################################################
FILE NAME   : counter_rs.h
DESCRIPTION : Rust 구현(libcounter_rs.a)이 내보내는 심볼 선언 — cbindgen 출력에 해당
#############################################################################*/
#ifndef COUNTER_RS_H
#define COUNTER_RS_H

#include <stddef.h>

#include "counter.h"

/* Rust가 #[no_mangle] static으로 내보내는 동작 테이블 — C 테이블과 같은 레이아웃 */
extern const CounterOps COUNTER_RS_OPS;

/* Rust 구현 상태를 힙에 만든다. panic은 NULL로 바꾸지만, 할당 실패(OOM)는 Rust 기본
   할당자가 abort한다. 해제는 COUNTER_RS_OPS.destroy로 한다. */
void   *counter_rs_new(void);

/* Rust 쪽에서 본 CounterOps 크기 — C의 sizeof와 비교하는 레이아웃 검사용 */
size_t  counter_rs_ops_size(void);

#endif /* COUNTER_RS_H */
