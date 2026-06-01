---
name: trading-systems
description: 실시간 트레이딩 시스템 도메인 패턴. FIX 프로토콜, 오더북, 마켓 데이터 피드, rdtsc 레이턴시 측정, CPU 어피니티. C/C++·Rust·Go 공통 적용.
origin: Harness
---

# 실시간 트레이딩 시스템 패턴

저지연 트레이딩 인프라 설계·구현 시 참고하는 도메인 패턴 모음.

## 언제 사용하나

- 오더북·매칭 엔진 구현
- 마켓 데이터 피드 수신·처리
- 레이턴시 측정·튜닝
- FIX 프로토콜 메시지 파싱

## 언제 사용하지 않나

- 저지연 시스템 공통 기법 → `latency-critical-systems` 스킬
- Rust 특화 구현 → `rust-patterns` 스킬

---

## 레이턴시 측정

```c
/* rdtsc — 나노초 단위 핫패스 측정 (C/C++) */
static inline uint64_t rdtsc(void)
{
    uint32_t lo, hi;
    __asm__ volatile ("rdtsc" : "=a"(lo), "=d"(hi));
    return ((uint64_t)hi << 32) | lo;
}

uint64_t t0 = rdtsc();
process_tick(&tick);
uint64_t cycles = rdtsc() - t0;
```

```rust
// Rust: std::time::Instant (ns 정밀도)
let t0 = std::time::Instant::now();
process_tick(&tick);
let elapsed_ns = t0.elapsed().as_nanos();
```

- **측정 지표**: p50, p95, p99, p999 별도 추적 (평균값 의존 금지)
- **히스토그램**: `hdrhistogram` crate 또는 HDR Histogram C 라이브러리

## 오더북 자료구조

```
핵심 요구사항:
- Add/Cancel/Modify: O(1)
- Best bid/ask 조회: O(1)
- 가격 레벨 순회: O(레벨 수)

권장 구조:
- 가격 → 큐 매핑: BTreeMap (정렬) 또는 배열 (가격 범위 제한 시)
- 오더 ID → 노드: HashMap<u64, OrderNode>
- 가격 레벨: 이중 연결 리스트 (cancel O(1))
```

```rust
pub struct OrderBook {
    bids: BTreeMap<u64, PriceLevel>,  // 내림차순
    asks: BTreeMap<u64, PriceLevel>,  // 오름차순
    orders: HashMap<u64, OrderRef>,
}
```

## 마켓 데이터 피드

```
수신 패턴:
- UDP multicast: 시퀀스 번호로 갭 감지 → TCP 재요청
- TCP: 재연결 로직 필수 (백오프 포함)
- 메시지 경계: 4바이트 길이 프리픽스 또는 FIX 구분자
```

```rust
async fn recv_loop(sock: UdpSocket, tx: Sender<Bytes>, cancel: CancellationToken) {
    let mut expected_seq = 0u64;
    let mut buf = BytesMut::with_capacity(65536);

    loop {
        tokio::select! {
            biased;
            _ = cancel.cancelled() => return,
            Ok(n) = sock.recv_buf(&mut buf) => {
                let msg = buf.split_to(n).freeze();
                let seq = parse_seq(&msg);
                if seq != expected_seq {
                    request_retransmit(expected_seq, seq).await;
                }
                expected_seq = seq + 1;
                let _ = tx.try_send(msg);  // 핫패스: 블로킹 금지
            }
        }
    }
}
```

## FIX 프로토콜 파싱

```
FIX 메시지 구조:
  8=FIX.4.4|9=길이|35=타입|...|10=체크섬|
  구분자: SOH (0x01)

핵심 태그:
  35 = MsgType (D=NewOrder, 8=ExecutionReport, X=MarketData)
  49 = SenderCompID
  56 = TargetCompID
  11 = ClOrdID
  55 = Symbol
  54 = Side (1=Buy, 2=Sell)
  38 = OrderQty
  44 = Price
```

```rust
/* Zero-copy FIX 파서 */
fn parse_fix(data: &[u8]) -> impl Iterator<Item = (u32, &[u8])> {
    data.split(|&b| b == 0x01)
        .filter_map(|field| {
            let eq = field.iter().position(|&b| b == b'=')?;
            let tag: u32 = std::str::from_utf8(&field[..eq]).ok()?.parse().ok()?;
            Some((tag, &field[eq + 1..]))
        })
}
```

## CPU 어피니티 / NUMA

```c
/* 핫패스 스레드를 특정 코어에 고정 (C) */
cpu_set_t cpuset;
CPU_ZERO(&cpuset);
CPU_SET(core_id, &cpuset);
pthread_setaffinity_np(pthread_self(), sizeof(cpuset), &cpuset);
```

```bash
# 실행 시 지정
taskset -c 2,3 ./trading_engine

# NUMA 노드 지정
numactl --cpunodebind=0 --membind=0 ./trading_engine
```

## 핫패스 설계 원칙

| 금지 | 대안 |
|---|---|
| 동적 할당 (`malloc`/`Box`) | 사전 할당 풀, arena |
| 시스템 콜 (lock, condvar) | lock-free 큐, 스핀락 |
| 블로킹 I/O | 비동기 (tokio, epoll, io_uring) |
| 예외·패닉 | Result, 에러 코드 |
| 로그 출력 | 비동기 로그 버퍼, 후처리 |
