---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---
# Rust 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.

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
struct FeedGuard { fd: RawFd }

impl Drop for FeedGuard {
    fn drop(&mut self) { unsafe { libc::close(self.fd); } }
}
```

## 저지연 패턴

- **Zero-copy** — `bytes::Bytes` / 슬라이스 파싱으로 역직렬화 시 복사 제거
- **Arena / 사전 할당** — 핫패스에서 동적 할당 금지, `bumpalo` 또는 풀(pool) 재사용
- **Lock-free** — 단일 생산자-소비자 큐는 `crossbeam` 링버퍼 사용, `Mutex` 회피
- **분기 예측** — 핫패스 조건문에 `likely`/`unlikely` 힌트, 에러 경로는 `#[cold]`
