---
name: trading-systems
description: 실시간 트레이딩 시스템 도메인 패턴. FIX 프로토콜, 오더북, 마켓 데이터 피드, rdtsc 레이턴시 측정, CPU 어피니티. C/C++·Rust·Go 공통 적용. 키워드 — FIX 프로토콜, 오더북, 마켓 데이터, rdtsc, 트레이딩, 리스크 한도, 킬스위치.
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
| 시스템 콜 (lock, condvar) | 단일 작성자 설계·SPSC 큐 우선 (유저스페이스 스핀락은 보유 스레드 선점 시 지연 폭증 — 코어 격리 없이는 금지) |
| 블로킹 I/O | 비동기 (tokio, epoll, io_uring) |
| 예외·패닉 | Result, 에러 코드 |
| 로그 출력 | 비동기 로그 버퍼, 후처리 |

## 고위험 자동 작업 안전장치

자동 주문은 버그 하나가 몇 초 만에 큰 손실로 이어진다. 그래서 **전략 코드가 무엇을 출력하든 넘을 수 없는
한도**를 전략 밖에 둔다. 안전장치는 지연보다 우선한다.

### 원칙

- **독립 하드 한도**: 주문 1건, 하루 누적, 종목별 포지션 한도를 리스크 게이트 모듈(가능하면 별도 프로세스)에 둔다.
  한도 값은 시작 시 읽기 전용 설정에서 읽고, 전략 코드는 이 값을 바꿀 수 없다. 한도 변경은 2인 검토를 거친다.
- **실행 전 사전 검증**: 모든 주문은 전송 직전에 게이트를 통과해야 한다. 종목 거래 가능 여부, 장 운영 시간,
  호가 단위·수량 단위, 잔고, 중복 ClOrdID, 시세 신선도(마지막 시세가 기준 시간보다 오래되면 거부)를 확인한다.
- **입력 오류(fat-finger) 한도**: 수량 상한, 기준가 대비 가격 괴리 상한, 주문 금액 상한, 초당 주문 수 상한을 둔다.
- **서킷 브레이커와 킬스위치**: 거부·오류율이나 당일 손실이 한도를 넘으면 킬스위치를 켠다. 킬스위치는 신규 주문을
  막고, 미체결 주문을 일괄 취소(FIX `35=q` OrderMassCancelRequest)하고, 담당자에게 알린다. **자동 해제는 없다.**
  사람이 원인을 확인하고 감사 로그를 남긴 뒤에만 해제한다.
- **외부 킬스위치**: 프로세스 밖에서도 멈출 수 있어야 한다. 관리 명령, 시그널, 거래소·브로커 측 킬스위치를 함께 준비한다.
- **전 결정 감사 로그**: 신호, 리스크 판정(통과·거부 사유), 주문 전송, 체결·거부 응답, 취소, 킬스위치 조작을
  모두 시각·전략 버전·입력값과 함께 추가 전용(append-only)으로 남긴다. 핫패스에서는 링 버퍼에 쓰고 별도 스레드가 파일로 내린다.

### 예시 — 주문 전 리스크 게이트 (C)

```c
/*#############################################################################
FILE NAME   : risk_gate.c
DESCRIPTION : 전략과 독립된 주문 전 하드 한도 검사와 서킷 브레이커·킬스위치
#############################################################################*/
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#define MAX_SYMBOLS            1024
#define MAX_ORDER_QTY          10000LL           /* 주문 1건 수량 */
#define MAX_ORDER_PRICE        10000000000LL     /* 주문 가격 상한 (오버플로 방지 겸용) */
#define MAX_ORDER_NOTIONAL     500000000LL       /* 주문 1건 금액 */
#define MAX_DAILY_NOTIONAL     20000000000LL     /* 하루 누적 금액 */
#define MAX_POSITION_QTY       50000LL           /* 종목별 순포지션 */
#define MAX_PRICE_DEVIATION_BP 300LL             /* 기준가 대비 괴리 3% */
#define MAX_REJECT_PER_MIN     20
#define MAX_DAILY_LOSS         100000000LL

typedef enum
{
    RISK_OK = 0,
    RISK_KILLED,
    RISK_INVALID,
    RISK_QTY,
    RISK_PRICE,
    RISK_NOTIONAL,
    RISK_DAILY,
    RISK_POSITION
} RiskResult;

typedef struct
{
    int     symbol_id;
    int     side;           /* +1 매수, -1 매도 */
    int64_t qty;
    int64_t price;
} Order;

typedef struct
{
    int64_t daily_notional;
    int64_t position[MAX_SYMBOLS];
    int64_t ref_price[MAX_SYMBOLS];  /* 기준가: 직전 체결가 또는 전일 종가 */
} RiskState;

typedef struct
{
    int64_t window_start;
    int     reject_count;
} BreakerState;

static atomic_bool g_KillSwitch = false;

/*=============================================================================
FUNCTION    : CheckOrder
DESCRIPTION : 주문 하나가 하드 한도를 모두 지키는지 검사한다. 상태는 바꾸지 않는다.
              통과한 주문만 전송하고, 판정 결과는 통과·거부 모두 감사 로그에 남긴다.
PARAMETERS  : const RiskState *state - 현재 누적·포지션 상태
              const Order     *order - 검사할 주문
RETURNED    : RISK_OK 또는 거부 사유
=============================================================================*/
RiskResult CheckOrder(const RiskState *state, const Order *order)
{
    int64_t ref      = 0;
    int64_t notional = 0;
    int64_t new_pos  = 0;

    if (atomic_load(&g_KillSwitch))
    {
        return RISK_KILLED;
    }
    if (order->symbol_id < 0 || order->symbol_id >= MAX_SYMBOLS
        || (order->side != 1 && order->side != -1))
    {
        return RISK_INVALID;
    }
    if (order->qty <= 0 || order->qty > MAX_ORDER_QTY)
    {
        return RISK_QTY;
    }
    ref = state->ref_price[order->symbol_id];
    if (order->price <= 0 || order->price > MAX_ORDER_PRICE || ref <= 0
        || llabs(order->price - ref) * 10000 > ref * MAX_PRICE_DEVIATION_BP)
    {
        return RISK_PRICE;
    }
    notional = order->qty * order->price;   /* 위 상한 덕분에 int64 범위 안 */
    if (notional > MAX_ORDER_NOTIONAL)
    {
        return RISK_NOTIONAL;
    }
    if (state->daily_notional + notional > MAX_DAILY_NOTIONAL)
    {
        return RISK_DAILY;
    }
    new_pos = state->position[order->symbol_id] + order->side * order->qty;
    if (llabs(new_pos) > MAX_POSITION_QTY)
    {
        return RISK_POSITION;
    }
    return RISK_OK;
}

/*=============================================================================
FUNCTION    : UpdateBreaker
DESCRIPTION : 1분 창의 거부·오류 수와 당일 손익을 보고 한도를 넘으면 킬스위치를 켠다.
              킬스위치는 여기서 끄지 않는다. 해제는 사람이 관리 명령으로만 한다.
PARAMETERS  : BreakerState *brk       - 서킷 브레이커 상태
              int64_t       now_sec   - 현재 시각(초)
              bool          is_reject - 이번 이벤트가 거부·오류인지
              int64_t       daily_pnl - 당일 실현·평가 손익
=============================================================================*/
void UpdateBreaker(BreakerState *brk, int64_t now_sec, bool is_reject, int64_t daily_pnl)
{
    if (now_sec - brk->window_start >= 60)
    {
        brk->window_start = now_sec;
        brk->reject_count = 0;
    }
    if (is_reject)
    {
        brk->reject_count++;
    }
    if (brk->reject_count > MAX_REJECT_PER_MIN || daily_pnl < -MAX_DAILY_LOSS)
    {
        atomic_store(&g_KillSwitch, true);   /* 이후 CheckOrder 는 모두 RISK_KILLED */
    }
}
```

- 게이트를 통과한 주문을 보낸 뒤에만 `daily_notional`과 `position`을 갱신한다. 체결 응답으로 포지션을 다시 맞춘다.
- 한도 값은 예시다. 실제 값은 운용 부서가 정하고 설정 파일로 관리한다.
- 테스트는 각 거부 사유마다 경계값(한도 정확히, 한도 + 1)을 넣어 확인하고, 킬스위치가 켜진 뒤 모든 주문이 거부되는지 확인한다.
