---
name: rust-patterns
description: 저지연 시스템용 이디엄틱 Rust 패턴. tokio 비동기, lock-free 자료구조, zero-copy, 트레이딩·실시간 데이터 컨텍스트에 최적화. 대상 경로 — **/*.rs. 키워드 — Rust, tokio, lock-free, zero-copy, 소유권.
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

## Lock-free 패턴

```rust
use crossbeam::queue::SegQueue;      // MPMC, 무제한 크기
use crossbeam::queue::ArrayQueue;    // MPMC, 고정 크기, 핫패스용

/* 고정 용량 MPMC 채널 — 단일 생산자-소비자 전용 큐가 아니다 */
let (tx, rx) = crossbeam::channel::bounded(4096);
```

- 단일 생산자-소비자 전용 큐가 필요하면 SPSC 전용 크레이트 또는 직접 구현을 검토한다
  (P3에서 `rules/systems/philosophy.md` 동시성 절로 연결 예정)

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
