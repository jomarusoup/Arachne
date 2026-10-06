---
name: rust-testing
description: Rust 테스팅 워크플로. criterion 벤치마크로 p99 레이턴시 회귀 감지, proptest 속성 기반 테스트, rstest 파라미터화·픽스처, mockall 모킹, 문서 테스트, cargo-llvm-cov 커버리지, cargo-flamegraph 프로파일링. 대상 경로 — **/*.rs. 키워드 — criterion, proptest, rstest, mockall, doctest, cargo-llvm-cov, Rust 테스트, 벤치마크.
---

# Rust 테스팅 워크플로

## 언제 사용하나

- Rust 신규 기능 구현 (TDD)
- 핫패스 변경 후 성능 회귀 검증
- 파서·직렬화 로직의 퍼즈 테스트
- 병목 지점 프로파일링

## 언제 사용하지 않나

- 단순 타입 검사 → `cargo check` 로 충분
- 메모리 안전성 검사 → `rules/rust/security.md` 의 miri/sanitizer 참고

---

## 단위 테스트 (AAA 패턴)

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn 영가격_주문시_에러_반환() {
        // Arrange
        let price = 0u64;
        // Act
        let result = validate_price(price);
        // Assert
        assert!(matches!(result, Err(OrderError::ZeroPrice)));
    }

    #[test]
    fn 오더북_매칭_수량_감소() {
        // Arrange
        let mut book = OrderBook::new();
        book.add_bid(100, 10);
        // Act
        let fill = book.match_ask(100, 3).unwrap();
        // Assert
        assert_eq!(fill.qty, 3);
        assert_eq!(book.bid_qty(100), 7);
    }
}
```

## criterion 벤치마크

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion, Throughput};

fn bench_order_match(c: &mut Criterion) {
    let mut book = setup_book(1000);
    let order = Order::new(100, 5);

    let mut group = c.benchmark_group("order_book");
    group.throughput(Throughput::Elements(1));

    group.bench_function("match", |b| {
        b.iter(|| book.match_order(black_box(&order)))
    });
    group.finish();
}

criterion_group!(benches, bench_order_match);
criterion_main!(benches);
```

```bash
cargo bench                        # 전체 벤치
cargo bench -- order_book          # 특정 그룹만
cargo bench -- --save-baseline v1  # 기준선 저장
cargo bench -- --baseline v1       # 기준선 대비 비교
```

> **p99 회귀 기준**: 핫패스 10% 이상 증가 시 머지 금지.

## 속성 기반 테스트 (proptest)

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn 파싱_라운드트립(
        price in 1u64..=1_000_000,
        qty   in 1u64..=10_000,
    ) {
        let order = Order::new(price, qty);
        let bytes = encode(&order);
        prop_assert_eq!(decode(&bytes).unwrap(), order);
    }
}
```

## 파라미터화·픽스처 (rstest)

같은 검증을 입력만 바꿔 반복하면 `rstest`의 `#[case]`로 묶는다. 공통 준비는 `#[fixture]`로 뺀다.

```rust
use rstest::{fixture, rstest};

#[fixture]
fn book() -> OrderBook {
    let mut book = OrderBook::new();
    book.add_bid(100, 10);
    book
}

#[rstest]
#[case(3, 7)]
#[case(10, 0)]
fn 매칭_수량만큼_잔량_감소(mut book: OrderBook, #[case] qty: u64, #[case] remain: u64) {
    book.match_ask(100, qty).unwrap();
    assert_eq!(book.bid_qty(100), remain);
}
```

## 모킹 (mockall)

의존성을 trait로 받는 코드만 모킹할 수 있다(`rust-patterns`의 trait 설계).
모킹은 시계·네트워크·저장소 같은 경계에만 쓴다. 순수 로직은 실제 타입으로 테스트한다.

```rust
#[cfg_attr(test, mockall::automock)]
pub trait Transport {
    fn send(&mut self, frame: &[u8]) -> std::io::Result<usize>;
}

#[test]
fn 부분_쓰기면_남은_바이트를_재전송() {
    let mut mock = MockTransport::new();
    let mut seq = mockall::Sequence::new();
    mock.expect_send().times(1).in_sequence(&mut seq).returning(|_| Ok(2));
    mock.expect_send().times(1).in_sequence(&mut seq).returning(|frame| Ok(frame.len()));

    assert!(send_all(&mut mock, b"ABCDE").is_ok());
}
```

## 문서 테스트

공개 API의 `///` 예시는 `cargo test`가 실행한다. 예시가 곧 회귀 테스트다.

```rust
/// 가격 문자열을 틱 단위 정수로 바꾼다.
///
/// ```
/// # use mycrate::parse_price;
/// assert_eq!(parse_price("100.25", 4)?, 1_002_500);
/// # Ok::<(), mycrate::ParseError>(())
/// ```
pub fn parse_price(text: &str, scale: u32) -> Result<u64, ParseError> { ... }
```

- `#` 줄은 문서에서 숨겨지고 컴파일에는 포함된다. `?`를 쓰려면 마지막 줄에 `Ok` 타입을 적는다.
- 네트워크·파일이 필요한 예시는 `no_run`, 실패를 보여 주는 예시는 `should_panic`이나 `compile_fail`을 붙인다.
- `ignore`는 쓰지 않는다. 컴파일조차 되지 않는 예시는 금방 낡는다.

## 커버리지

```bash
cargo install cargo-llvm-cov
cargo llvm-cov --workspace --html              # target/llvm-cov/html
cargo llvm-cov --workspace --fail-under-lines 80   # 신규 모듈 게이트
```

- 80% 게이트는 신규 모듈에만 건다. 레거시 수정은 변경 라인이 테스트되는지만 본다(D21).
- `unsafe` 블록과 에러 경로가 커버되지 않으면 수치가 높아도 미완료로 본다.

## flamegraph 프로파일링

```bash
# cargo-flamegraph 설치
cargo install flamegraph

# 프로파일링 실행
cargo flamegraph --bench order_book -- --bench
# → flamegraph.svg 생성, 브라우저에서 열기

# perf 기반 (Linux)
cargo flamegraph --bin my_service
```

## 실행 순서 (TDD 사이클)

```
1. #[test] 실패 케이스 작성 (RED)
2. cargo nextest run → 실패 확인
3. 최소 구현 (GREEN)
4. cargo nextest run → 통과 확인
5. 리팩터링 후 재통과
6. 핫패스 변경 시 cargo bench 실행
7. p99 회귀 없으면 커밋
```
