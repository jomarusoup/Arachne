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
cargo test --doc                 # 문서 주석 예제 검증 (nextest 는 doc 미실행 — 별도 필수)
cargo test -- --nocapture        # 출력 표시
```

> **doc 테스트는 별도로 반드시 실행** — 공개 API 의 `///` 예제가 컴파일·통과해야
> 문서가 거짓말을 하지 않는다. `cargo nextest run` 은 doc 테스트를 돌리지 않는다.

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

## 퍼징 (파서·역직렬화·바이트 처리 필수)

임의 바이트 입력을 다루는 코드는 proptest 만으로 부족하다 — **cargo-fuzz** 로
패닉·UB·무한루프를 잡는다. proptest 는 구조적 불변식, 퍼징은 적대적 임의 입력 담당.

```bash
cargo install cargo-fuzz
cargo fuzz run fuzz_parse -- -max_total_time=60   # 크래시까지 실행
```

```rust
// fuzz/fuzz_targets/fuzz_parse.rs — 패닉·크래시가 없어야 한다
#![no_main]
libfuzzer_sys::fuzz_target!(|data: &[u8]| { let _ = mycrate::parse(data); });
```

> 재현 코퍼스(`fuzz/regressions/`)는 커밋해 회귀로 재실행. 상세는
> `skills/rust-library-crate.md`.

## feature-matrix·크로스 플랫폼

라이브러리는 feature 조합·타깃별로 깨진다 — 대표 조합을 스크립트로 고정한다:

```bash
cargo test --no-default-features --lib                    # no_std 경로
cargo test --no-default-features --features "std,perf"    # 대표 조합
cross test --target aarch64-unknown-linux-gnu             # 크로스/빅엔디안
cargo +1.65.0 build                                       # MSRV
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
