---
name: rust-testing
description: Rust 테스팅 워크플로. criterion 벤치마크로 p99 레이턴시 회귀 감지, proptest 속성 기반 테스트, cargo-flamegraph 프로파일링.
origin: Harness
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
