---
name: rust-patterns
description: 저지연 시스템용 이디엄틱 Rust 패턴. 소유권, tokio 비동기, 에러 타입(thiserror·non_exhaustive), enum 상태 표현·newtype, trait 설계(정적·동적 디스패치·sealed·From/TryFrom), 빌더, lock-free, zero-copy. 대상 경로 — **/*.rs. 키워드 — Rust, tokio, lock-free, zero-copy, 소유권, 에러 enum, trait, 빌더, API Guidelines.
---

# Rust 개발 패턴

저지연 트레이딩·실시간 데이터 파이프라인을 위한 이디엄틱 Rust 패턴.

## 언제 사용하나

- 새 Rust 코드 작성 (서비스, 라이브러리, CLI)
- 기존 Rust 코드 리팩터링
- 저지연 핫패스 설계 시
- async/await 구조 설계 시

## 언제 사용하지 않나

- 벤치마크·프로파일링 → `performance-profiling` 스킬
- 트레이딩 도메인 로직 → `trading-systems` 스킬

---

## 소유권 설계

함수 시그니처 우선순위: `&T` → `&mut T` → `T` (소유권 이전은 마지막 수단)

```rust
/* BAD: 매 호출마다 클론 */
fn process(book: OrderBook) -> OrderBook { ... }

/* GOOD: 제자리 변경, 할당 없음 */
fn process(book: &mut OrderBook, tick: &Tick) { ... }
```

## tokio 비동기 패턴

```rust
/* 취소 토큰으로 graceful shutdown */
async fn run_feed(mut rx: Receiver<Tick>, cancel: CancellationToken) -> Result<()> {
    loop {
        tokio::select! {
            biased;                          // 취소 우선 확인
            _ = cancel.cancelled() => break,
            Some(tick) = rx.recv() => handle(&tick)?,
        }
    }
    Ok(())
}
```

- `biased` — 취소 경로를 항상 먼저 폴링
- CPU 바운드 → `spawn_blocking`, I/O → `spawn`
- 핫패스에서 `.await` 지점 최소화

## 에러 처리

```rust
/* 라이브러리: 구체적 타입 (thiserror) */
#[derive(thiserror::Error, Debug)]
pub enum FeedError {
    #[error("연결 끊김: {addr}")]
    Disconnected { addr: SocketAddr },
    #[error("파싱 실패: {0}")]
    Parse(#[from] ParseError),
}

/* 애플리케이션: 컨텍스트 체인 (anyhow) */
let feed = connect(addr).await.context("마켓 피드 연결 실패")?;
```

에러 타입은 Rust API Guidelines의 C-GOOD-ERR를 따른다.

- 공개 에러 타입은 `Error + Send + Sync + 'static`을 만족시킨다. `thiserror`가 이를 맞춰 준다.
- 공개 에러 enum에는 `#[non_exhaustive]`를 붙인다. 변형을 추가해도 호환이 깨지지 않는다.
- 원인 에러는 `#[source]`나 `#[from]`으로 연결한다. 메시지에 원인 문자열을 다시 붙이지 않는다.
- 메시지는 소문자로 시작하고 마침표를 붙이지 않는다. 상위에서 맥락이 덧붙기 때문이다.
- `()`나 `String`을 에러 타입으로 쓰지 않는다. 호출자가 분기할 수 없다.

## enum으로 상태 표현

플래그 조합 대신 상태별 enum을 쓴다. 불가능한 상태를 표현할 수 없게 된다(`rules/systems/philosophy.md` 4절).

```rust
/* BAD: is_connected·is_authed 조합 4가지 중 하나는 불가능한 상태 */
struct Session { is_connected: bool, is_authed: bool, token: Option<Token> }

/* GOOD: 상태마다 필요한 데이터만 가진다 */
enum Session {
    Disconnected,
    Connected { stream: TcpStream },
    Authed { stream: TcpStream, token: Token },
}
```

- 경계에서 한 번 파싱해 newtype으로 만든다. `struct Price(u64)`는 `TryFrom<u64>`에서만 검증한다.
- `match`는 와일드카드 `_` 대신 변형을 모두 적는다. 변형이 늘면 컴파일러가 알려 준다.
- 바이트·정수 코드는 `TryFrom<u8>`으로 enum에 매핑한다. `as` 캐스트로 enum을 만들지 않는다.

## trait 설계

| 상황 | 선택 |
|---|---|
| 구현이 컴파일 타임에 정해지고 핫패스다 | 제네릭 `impl Trait` (정적 디스패치) |
| 런타임에 구현을 고르거나 이종 컬렉션이 필요하다 | `Box<dyn Trait>` (동적 디스패치) |
| 외부에서 구현하면 안 된다 | sealed trait (비공개 모듈의 `Sealed` 상위 trait) |
| 외부 타입에 메서드를 더한다 | 확장 trait (`FooExt`) |

- 변환은 표준 trait로 한다. 실패 없는 변환은 `From`, 실패 가능한 변환은 `TryFrom`이다(C-CONV-TRAITS).
- 공개 타입은 의미가 있는 한 `Debug`·`Clone`·`PartialEq`·`Default`를 미리 구현한다(C-COMMON-TRAITS).
- 테스트에서 바꿔 끼울 의존성(시계·전송·저장소)은 trait로 받는다. `rust-testing`의 mockall과 맞물린다.

## 빌더

선택 인자가 많은 생성자는 빌더로 바꾼다(C-BUILDER).

```rust
pub struct FeedConfig { addr: SocketAddr, recv_buf: usize, timeout: Duration }

#[derive(Default)]
pub struct FeedConfigBuilder { addr: Option<SocketAddr>, recv_buf: Option<usize>, timeout: Option<Duration> }

impl FeedConfigBuilder {
    pub fn addr(mut self, addr: SocketAddr) -> Self { self.addr = Some(addr); self }
    pub fn recv_buf(mut self, size: usize) -> Self { self.recv_buf = Some(size); self }

    pub fn build(self) -> Result<FeedConfig, ConfigError> {
        Ok(FeedConfig {
            addr: self.addr.ok_or(ConfigError::MissingAddr)?,
            recv_buf: self.recv_buf.unwrap_or(DEFAULT_RECV_BUF),
            timeout: self.timeout.unwrap_or(DEFAULT_TIMEOUT),
        })
    }
}
```

- 필수 인자 누락은 `build()`의 `Result`로 알린다. 필수 인자가 하나면 빌더 생성자의 인자로 받는다.
- 필수 인자 누락을 컴파일 타임에 막아야 하면 typestate 빌더를 검토한다. 타입이 늘어나므로 공개 API에만 쓴다.

## Lock-free 패턴

```rust
use crossbeam::queue::SegQueue;      // MPMC, 무제한 크기
use crossbeam::queue::ArrayQueue;    // MPMC, 고정 크기, 핫패스용

/* 고정 용량 MPMC 채널 — 단일 생산자-소비자 전용 큐가 아니다 */
let (tx, rx) = crossbeam::channel::bounded(4096);
```

- 단일 생산자-소비자 전용 큐가 필요하면 SPSC 전용 크레이트 또는 직접 구현을 검토한다
  (조건: 단일 작성자·acquire/release·캐시라인 패딩·loom 검증 — [systems/philosophy.md 11절](../../rules/systems/philosophy.md#11-동시성))

- `Mutex<T>` 대신 채널 또는 `Atomic*` 우선
- 공유 상태가 불가피하면 `parking_lot::RwLock` (표준보다 빠름)

## Zero-copy 파싱

```rust
use bytes::Bytes;

/* BAD: 매번 Vec 할당 */
fn parse(data: &[u8]) -> Vec<Field> { ... }

/* GOOD: 슬라이스 뷰만 반환, 할당 없음 */
fn parse(data: &Bytes) -> impl Iterator<Item = &[u8]> { ... }
```

## 저지연 핫패스 규칙

- 동적 할당(`Box`, `Vec::push`) — 핫패스 진입 전 사전 할당 완료
- `#[inline]` — 소규모 핫패스 함수에 명시
- `#[cold]` — 에러 등 콜드 경로 함수에 명시 (안정 채널의 분기 배치 힌트). `likely`/`unlikely`류 분기 힌트는 측정 근거가 있을 때만
- `black_box` — 벤치마크에서 최적화 방지

```rust
#[inline]
fn match_order(book: &mut OrderBook, order: &Order) -> Option<Fill> { ... }

#[cold]
fn handle_disconnect(addr: SocketAddr) { ... }
```
