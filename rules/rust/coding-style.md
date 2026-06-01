---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---
# Rust 코딩 스타일

> [common/coding-style.md](../common/coding-style.md) 를 확장한다.

## 헤더 형식

Rust는 `/* */` 블록 주석 지원 → C 스타일 그대로 사용.

```rust
/*#############################################################################
FILE NAME   : 파일명.rs
DESCRIPTION : 파일 역할 한 줄 요약
DATA        : YYYY-MM-DD
Modification: YYYY-MM-DD
#############################################################################*/

/*=============================================================================
FUNCTION    : function_name
DESCRIPTION : 역할 설명
PARAMETERS  : type 인자명 - 설명
RETURNED    : 반환값 설명
=============================================================================*/
```

> 공개 API에는 `///` 문서 주석 병행 — `cargo doc` 으로 추출된다.

## 포매팅

- **rustfmt** 필수 — 커밋 전 `cargo fmt` 자동 실행 (탭 금지, 4 스페이스)
- **Clippy** 린트 통과 필수 — `cargo clippy -- -D warnings`
- 한 줄 100자 제한 (rustfmt 기본값 준수)

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

- 함수·메서드·변수·모듈: `snake_case` (`parse_header`, `order_book`)
- 타입·트레이트·열거형: `CamelCase` (`OrderBook`, `MarketEvent`)
- 상수·static: `SCREAMING_SNAKE_CASE` (`MAX_DEPTH`, `TICK_SIZE`)
- 단일 문자 금지 — `i` → `ii`, 임시값은 `tmp`, `len` 허용

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
