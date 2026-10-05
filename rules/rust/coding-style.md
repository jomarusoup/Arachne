---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---
# Rust 코딩 스타일

> [common/coding-style.md](../common/coding-style.md) 를 확장한다.

## 헤더 형식 — 문서 주석

Rust는 `/*###*/`·`/*===*/` 헤더 블록 대신 rustdoc 문서 주석을 쓴다. 날짜 필드는 두지 않는다(이력은 git이 정본).

```rust
//! 파일(모듈) 역할 한 줄 요약.
//!
//! 필요하면 설계 의도·불변식을 문단으로 덧붙인다.

/// 호가 틱을 검증해 주문을 만든다.
///
/// # Errors
/// 가격이 0이면 `OrderError::ZeroPrice`를 반환한다.
pub fn process_tick(price: u64) -> Result<Order, OrderError> {
    if price == 0 {
        return Err(OrderError::ZeroPrice);
    }
    Ok(Order::new(price))
}
```

- 모듈·파일 헤더는 `//!`, 공개 항목은 `///`로 작성한다. `cargo doc`으로 추출된다.
- 함수 문서는 공개 API와 동작이 자명하지 않은 함수에만 둔다.

## 포매팅

- **rustfmt** 필수 — 커밋 전 `cargo fmt` 자동 실행 (탭 금지, 4 스페이스)
- **Clippy** 린트 통과 필수 — `cargo clippy -- -D warnings`
- 한 줄 100자 제한 (rustfmt 기본값 준수)
- 프로젝트 규약은 **`rustfmt.toml` 을 저장소에 커밋**해 고정한다 (예: `max_width`,
  `use_small_heuristics`) — 편집기·기여자마다 다른 결과가 나오지 않도록.

## crate-root 린트 게이트

라이브러리 crate 는 lib.rs 최상단에 품질 게이트를 강제한다:

```rust
#![deny(missing_docs)]                    // 모든 공개 API 문서 강제
#![warn(missing_debug_implementations)]   // 모든 타입에 Debug 권장
```

> 재사용 라이브러리·crate 저작 전반(feature flag·no_std·MSRV·퍼징·배포)은
> `skills/rust-library-crate/SKILL.md` 참고.

## "왜" 주석

비자명한 결정(플랫폼 분기, feature 게이트, 성능 트레이드오프, 우회책)에는
**무엇이 아니라 왜**를 남긴다 — regex 코드베이스의 `cfg_attr` 블록처럼 판단 근거를
문단으로 기록해 다음 사람이 되돌리지 않게 한다.

## 중괄호 스타일 — K&R

rustfmt가 K&R 강제 → Allman **금지**.

```rust
fn process_tick(price: u64) -> Result<Order, OrderError> {
    if price == 0 {
        return Err(OrderError::ZeroPrice);
    }
    Ok(Order::new(price))
}
```

## 네이밍 (Rust 전용)

C/C++ 하우스 스타일(PascalCase 함수·`g_` 전역)을 적용하지 않는다. Rust API Guidelines를 따른다.

- 함수·메서드·변수·모듈: `snake_case` (`parse_header`, `order_book`)
- 타입·트레이트·열거형: `CamelCase` (`OrderBook`, `MarketEvent`)
- 상수·static: `SCREAMING_SNAKE_CASE` (`MAX_DEPTH`, `TICK_SIZE`)
- 이름 길이는 스코프에 비례한다. 짧은 루프 인덱스 `i`·`j`는 허용한다.

## 에러 처리

- `unwrap()` / `expect()` 는 테스트·초기화 외 핫패스에서 금지
- 함수 경계에서 `Result<T, E>` 반환, `?` 연산자로 전파
- 패닉은 복구 불가능한 불변식 위반에만 사용

## 디버그 출력

```rust
println!("[DEBUG] price={}", price);      // 배포 전 제거
log::warn!("[PROJ] latency_us={}", us);   // 운영 경고 (구조적 로깅 권장)
```

> 저지연 핫패스에서는 `println!`·할당성 로깅 금지 — `tracing` span 또는 사전 할당 버퍼 사용.
