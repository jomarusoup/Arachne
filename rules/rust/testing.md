---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---
# Rust 테스팅

> [common/testing.md](../common/testing.md) 를 확장한다.

## 프레임워크

표준 `#[test]` + **cargo-nextest** 러너, 벤치마크는 **criterion**.

## 테스트 실행

```bash
cargo test                       # 표준 테스트
cargo nextest run                # 병렬 러너 (권장)
cargo test --doc                 # 문서 주석 예제 검증
cargo test -- --nocapture        # 출력 표시
```

## 단위 테스트 — 같은 파일 내 모듈

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn 영가격_주문시_에러_반환() {
        // Arrange
        let price = 0;
        // Act
        let result = process_tick(price);
        // Assert
        assert!(matches!(result, Err(OrderError::ZeroPrice)));
    }
}
```

## 속성 기반 테스트 (proptest)

파서·매칭 엔진 등 입력 공간이 넓은 로직에 사용:

```rust
proptest! {
    #[test]
    fn 파싱_라운드트립(tick in any::<Tick>()) {
        let bytes = encode(&tick);
        prop_assert_eq!(decode(&bytes).unwrap(), tick);
    }
}
```

## 벤치마크 (criterion)

저지연 핫패스는 회귀 감지를 위해 벤치 필수:

```rust
fn bench_match(c: &mut Criterion) {
    c.bench_function("order_book_match", |b| {
        b.iter(|| book.match_order(black_box(&order)))
    });
}
```

```bash
cargo bench                      # p50/p99 레이턴시 측정
```

> 핫패스 변경 시 벤치 결과 비교 — p99 레이턴시 회귀 시 머지 금지.
