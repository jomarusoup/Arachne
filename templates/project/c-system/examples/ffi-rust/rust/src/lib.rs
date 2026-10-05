//! C 카운터 저장소(`counter_mem.c`)와 같은 동작을 Rust로 구현한 예제 crate.
//!
//! C의 불투명 핸들은 비공개 필드 구조체 [`MemCounter`]로, 함수 포인터 테이블은
//! 트레이트 [`Counter`]로 옮겼다. C에 노출하는 경계는 [`ffi`] 모듈 하나에 모은다.

// Rust 2024와 같은 규칙 — unsafe fn 안에서도 unsafe 연산마다 블록과 SAFETY 주석을 요구한다
#![deny(unsafe_op_in_unsafe_fn)]
#![deny(missing_docs)]
#![warn(missing_debug_implementations)]

use std::fmt;

pub mod ffi;

/// 구현 하나가 담을 수 있는 키 개수. C의 `COUNTER_CAPACITY`와 같아야 한다.
pub const CAPACITY: usize = 4;

/// 카운터 연산의 실패 원인.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CounterError {
    /// 키가 없다.
    NotFound,
    /// 저장소가 가득 차 새 키를 만들 수 없다.
    Full,
    /// 덧셈 결과가 `i64` 범위를 벗어난다.
    Overflow,
}

impl fmt::Display for CounterError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let msg = match self {
            Self::NotFound => "키 없음",
            Self::Full => "저장소 가득 참",
            Self::Overflow => "값 범위 초과",
        };
        f.write_str(msg)
    }
}

impl std::error::Error for CounterError {}

/// C의 `CounterOps` 동작 테이블에 대응하는 인터페이스.
///
/// 소멸(`destroy`)은 메서드가 아니라 `Drop`이 맡는다.
pub trait Counter {
    /// 키의 값에 `delta`를 더한다. 없는 키는 `delta`로 새로 만든다.
    ///
    /// # Errors
    /// 범위를 넘으면 [`CounterError::Overflow`], 새 키를 넣을 자리가 없으면
    /// [`CounterError::Full`]을 반환한다. 실패하면 상태를 바꾸지 않는다.
    fn add(&mut self, key: u32, delta: i64) -> Result<(), CounterError>;

    /// 키의 현재 값을 읽는다.
    ///
    /// # Errors
    /// 키가 없으면 [`CounterError::NotFound`]를 반환한다.
    fn get(&self, key: u32) -> Result<i64, CounterError>;
}

/// 고정 용량 카운터 저장소. 필드는 비공개라 생성 경로는 [`MemCounter::new`]뿐이다.
#[derive(Debug, Default)]
pub struct MemCounter {
    entries: Vec<(u32, i64)>,
}

impl MemCounter {
    /// 빈 저장소를 만든다. 용량을 미리 잡아 이후 재할당이 없다.
    #[must_use]
    pub fn new() -> Self {
        Self {
            entries: Vec::with_capacity(CAPACITY),
        }
    }
}

impl Counter for MemCounter {
    fn add(&mut self, key: u32, delta: i64) -> Result<(), CounterError> {
        if let Some(entry) = self.entries.iter_mut().find(|(k, _)| *k == key) {
            entry.1 = entry.1.checked_add(delta).ok_or(CounterError::Overflow)?;
            return Ok(());
        }
        if self.entries.len() >= CAPACITY {
            return Err(CounterError::Full);
        }
        self.entries.push((key, delta));
        Ok(())
    }

    fn get(&self, key: u32) -> Result<i64, CounterError> {
        self.entries
            .iter()
            .find(|(k, _)| *k == key)
            .map(|(_, v)| *v)
            .ok_or(CounterError::NotFound)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_key_returns_not_found() {
        let store = MemCounter::new();
        assert_eq!(store.get(1), Err(CounterError::NotFound));
    }

    #[test]
    fn overflow_keeps_previous_value() {
        let mut store = MemCounter::new();
        store.add(2, i64::MAX).unwrap();
        assert_eq!(store.add(2, 1), Err(CounterError::Overflow));
        assert_eq!(store.get(2), Ok(i64::MAX));
    }

    #[test]
    fn full_store_rejects_new_key_but_updates_existing() {
        let mut store = MemCounter::new();
        for key in 0..CAPACITY as u32 {
            store.add(key, 1).unwrap();
        }
        assert_eq!(store.add(99, 1), Err(CounterError::Full));
        assert_eq!(store.add(0, 1), Ok(()));
        assert_eq!(store.get(0), Ok(2));
    }
}
