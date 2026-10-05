---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---
# Rust 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.
> 아래 `async`·저지연 예제는 **애플리케이션 핫패스** 도메인이다 — 원칙은 범용이되
> 예시는 한 도메인일 뿐. **재사용 라이브러리·crate** 를 만든다면 feature flag·
> `no_std`·MSRV·최소 의존성·퍼징·배포 규율은 `skills/rust-library-crate/SKILL.md` 참고.

## 소유권·빌림

- 함수는 소유권이 필요할 때만 값으로 받고, 읽기만 하면 `&T`, 변경은 `&mut T`
- 불필요한 `.clone()` 금지 — 빌림으로 해결 가능한지 먼저 검토
- 라이프타임은 명시가 가독성을 높일 때만 표기, 나머지는 생략(elision) 활용

```rust
/* BAD: 핫패스에서 매 틱마다 복사 */
fn update(book: OrderBook, tick: Tick) -> OrderBook { ... }

/* GOOD: 제자리 변경, 할당 없음 */
fn update(book: &mut OrderBook, tick: &Tick) { ... }
```

## async/await (tokio)

```rust
async fn run(mut feed: MarketFeed, cancel: CancellationToken) -> Result<()> {
    loop {
        tokio::select! {
            _ = cancel.cancelled() => return Ok(()),
            msg = feed.next() => handle(msg?).await?,
        }
    }
}
```

- 모든 태스크에 취소 토큰·셧다운 경로 명시 (좀비 태스크 방지)
- 핫패스에서 `.await` 지점 최소화 — CPU 바운드 연산은 `spawn_blocking` 분리

## 에러 처리 (thiserror / anyhow)

```rust
/* 라이브러리 — 구체적 에러 타입 (thiserror) */
#[derive(thiserror::Error, Debug)]
pub enum OrderError {
    #[error("0 가격 주문 불가")]
    ZeroPrice,
    #[error("심볼 없음: {0}")]
    UnknownSymbol(String),
}

/* 애플리케이션 경계 — anyhow 로 컨텍스트 부착 */
let cfg = load_config(path).context("설정 로드 실패")?;
```

## RAII

소유권 기반 자동 해제 — `Drop` 으로 정리 보장:

```rust
use std::os::fd::OwnedFd;

/* OwnedFd 가 Drop 시 close 를 보장 — 직접 unsafe close 불필요 */
struct FeedGuard { fd: OwnedFd }

impl FeedGuard {
    fn new(fd: OwnedFd) -> Self { Self { fd } }
}
```

수동 `Drop`에서 `unsafe`가 불가피하면 `// SAFETY:` 주석으로 fd 단일 소유·중복 close 없음을 논증한다.

## 저지연 패턴

- **Zero-copy** — `bytes::Bytes` / 슬라이스 파싱으로 역직렬화 시 복사 제거
- **Arena / 사전 할당** — 핫패스에서 동적 할당 금지, `bumpalo` 또는 풀(pool) 재사용
- **Lock-free** — `Mutex` 회피. `crossbeam::channel::bounded`·`ArrayQueue`는 MPMC — 단일 생산자-소비자 전용이 필요하면 SPSC 전용 크레이트 또는 직접 구현
- **분기 예측** — 콜드 경로(에러 처리 등)를 `#[cold]` 함수로 분리. 분기 힌트(`likely`/`unlikely`, nightly)는 측정 근거가 있을 때만
