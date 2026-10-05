//! C 경계 — `include/counter.h`의 `CounterOps`와 같은 레이아웃의 테이블을 내보낸다.
//!
//! 규칙: NULL은 경계에서 검사한다. panic은 `catch_unwind`로 잡아 에러 코드로 바꾼다.
//! 구현 상태의 소유권은 `counter_rs_new`가 C로 넘기고 `destroy`가 돌려받아 해제한다.

use std::ffi::{c_int, c_void};
use std::mem::size_of;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ptr;

use crate::{Counter, CounterError, MemCounter};

/// C의 `COUNTER_OPS_VERSION`.
pub const OPS_VERSION: u32 = 1;

// C의 CounterErr 값 — 헤더와 한 곳이라도 다르면 비교 테스트가 실패한다
const COUNTER_OK: c_int = 0;
const COUNTER_ERR_NULL_PTR: c_int = -10001;
const COUNTER_ERR_NOT_FOUND: c_int = -10002;
const COUNTER_ERR_FULL: c_int = -10003;
const COUNTER_ERR_OVERFLOW: c_int = -10004;
const COUNTER_ERR_INTERNAL: c_int = -10005;

/// C의 `CounterOps`와 필드 순서·타입이 같은 동작 테이블.
#[repr(C)]
#[derive(Debug)]
pub struct CounterOps {
    /// 테이블 버전.
    pub version: u32,
    /// 키에 값을 더한다.
    pub add: unsafe extern "C" fn(*mut c_void, u32, i64) -> c_int,
    /// 키의 값을 읽는다.
    pub get: unsafe extern "C" fn(*const c_void, u32, *mut i64) -> c_int,
    /// 구현 상태를 해제한다.
    pub destroy: unsafe extern "C" fn(*mut c_void),
}

// C의 _Static_assert와 같은 조건 — 컴파일 시점에 레이아웃 어긋남을 막는다
const _: () = assert!(size_of::<CounterOps>() == 4 * size_of::<usize>());

/// C가 `extern const CounterOps COUNTER_RS_OPS;`로 참조하는 불변 테이블.
#[no_mangle]
pub static COUNTER_RS_OPS: CounterOps = CounterOps {
    version: OPS_VERSION,
    add: rs_add,
    get: rs_get,
    destroy: rs_destroy,
};

fn error_code(err: CounterError) -> c_int {
    match err {
        CounterError::NotFound => COUNTER_ERR_NOT_FOUND,
        CounterError::Full => COUNTER_ERR_FULL,
        CounterError::Overflow => COUNTER_ERR_OVERFLOW,
    }
}

/// 빈 구현 상태를 힙에 만들어 소유권을 C로 넘긴다. panic이면 NULL을 돌려준다.
///
/// 할당 실패(OOM)는 panic이 아니라 abort라서 `catch_unwind`로 잡히지 않는다.
#[no_mangle]
pub extern "C" fn counter_rs_new() -> *mut c_void {
    catch_unwind(|| Box::into_raw(Box::new(MemCounter::new())).cast::<c_void>())
        .unwrap_or(ptr::null_mut())
}

/// Rust에서 본 `CounterOps` 크기. C의 `sizeof(CounterOps)`와 비교한다.
#[no_mangle]
pub extern "C" fn counter_rs_ops_size() -> usize {
    size_of::<CounterOps>()
}

unsafe extern "C" fn rs_add(impl_ptr: *mut c_void, key: u32, delta: i64) -> c_int {
    if impl_ptr.is_null() {
        return COUNTER_ERR_NULL_PTR;
    }
    // SAFETY: impl_ptr는 counter_rs_new가 만든 MemCounter이고(NULL 아님은 위에서 검사),
    // C 핸들이 단일 소유하므로 이 호출 동안 다른 참조가 없다.
    let store = unsafe { &mut *impl_ptr.cast::<MemCounter>() };
    match catch_unwind(AssertUnwindSafe(|| store.add(key, delta))) {
        Ok(Ok(())) => COUNTER_OK,
        Ok(Err(err)) => error_code(err),
        Err(_) => COUNTER_ERR_INTERNAL,
    }
}

unsafe extern "C" fn rs_get(impl_ptr: *const c_void, key: u32, out: *mut i64) -> c_int {
    if impl_ptr.is_null() || out.is_null() {
        return COUNTER_ERR_NULL_PTR;
    }
    // SAFETY: impl_ptr는 counter_rs_new가 만든 MemCounter이고 읽기만 한다.
    let store = unsafe { &*impl_ptr.cast::<MemCounter>() };
    match catch_unwind(AssertUnwindSafe(|| store.get(key))) {
        Ok(Ok(value)) => {
            // SAFETY: out은 NULL이 아니며 호출자가 i64 하나를 쓸 수 있는 공간을 넘긴다.
            unsafe { out.write(value) };
            COUNTER_OK
        }
        Ok(Err(err)) => error_code(err),
        Err(_) => COUNTER_ERR_INTERNAL,
    }
}

unsafe extern "C" fn rs_destroy(impl_ptr: *mut c_void) {
    if impl_ptr.is_null() {
        return;
    }
    // SAFETY: impl_ptr는 counter_rs_new의 Box::into_raw 결과이고, 핸들이 destroy를
    // 한 번만 부르므로 소유권을 정확히 한 번 돌려받는다.
    drop(unsafe { Box::from_raw(impl_ptr.cast::<MemCounter>()) });
}
