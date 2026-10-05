---
name: latency-critical-systems
description: 프로세스 내부 핫패스의 지연과 꼬리 지연을 줄이는 C·C++·Rust 스킬. 꼬리 지연 측정 조건(p99·p99.9·max, 워밍업, coordinated omission, HDR 히스토그램, 주파수·코어 고정), 캐시라인 정렬과 거짓 공유(perf c2c), 단일 작성자 원칙, 코어 고정·isolcpus·nohz_full·IRQ 분리, busy-poll vs 블로킹 판단(스핀 후 대기), 사전 할당과 핫패스 할당 금지(mlockall·프리폴트·할당 계수 테스트), 분기 힌트·cold 속성은 측정이 있을 때만. stream-pipeline-patterns·shm-db-patterns와의 역할 경계 포함. 대상 경로 — **/*.c, **/*.h, **/*.cpp, **/*.hpp, **/*.cc, **/*.rs. 키워드 — 저지연, 핫패스, HOTPATH, 꼬리 지연, p99.9, coordinated omission, 거짓 공유, 캐시라인, 단일 작성자, 코어 고정, isolcpus, busy-poll, 사전 할당, cold.
---

# 저지연 핫패스 (프로세스 내부)

한 프로세스 안에서 이벤트 하나가 들어와 처리되고 나갈 때까지의 지연을 줄인다.
대상은 나노초~마이크로초 단위의 핫패스와 그 꼬리 지연(p99·p99.9)이다.
원칙은 `rules/systems/philosophy.md`가 정본이다. 8절(성능)과 11절(동시성)을 다시 적지 않고, 이 스킬은 적용 방법만 다룬다.

## 역할 경계

| 질문 | 스킬 |
|---|---|
| 이벤트 하나의 지연과 꼬리 지연을 어떻게 줄이나 (캐시라인·코어·busy-poll·할당) | **이 스킬** |
| 초당 처리량을 어떻게 올리고 넘칠 때 흐름을 어떻게 제어하나 (큐·묶음 I/O·백프레셔·팬아웃) | `stream-pipeline-patterns` (원칙은 `data-throughput-accelerator`) |
| 여러 프로세스가 공유하는 상태를 어디에 두고 DB와 어떻게 맞추나 (공유메모리·robust 뮤텍스·적재) | `shm-db-patterns` |
| 서비스 경로(API·큐·캐시·엣지·브라우저) 구간별 지연 | `service-latency` |
| 병목을 찾는 프로파일러 사용법과 변형 승격 게이트 | `performance-profiling` |
| 트레이딩 도메인(오더북·피드·리스크 게이트) | `trading-systems` |

경계가 겹치는 지점은 이렇게 나눈다.

- SPSC 링버퍼의 **구현**은 `stream-pipeline-patterns`가 맡는다. 이 스킬은 링버퍼 인덱스를 캐시라인으로 나누는 **이유와 검증**만 다룬다.
- 공유메모리 레코드의 **동기화 방식**은 `shm-db-patterns`가 맡는다. 이 스킬은 핫패스가 그 레코드를 읽을 때의 거짓 공유만 다룬다.

## 언제 사용하나

- `/* HOTPATH */`·`// HOTPATH`로 표시한 경로를 설계하거나 고칠 때
- p50은 괜찮은데 p99·p99.9가 튈 때
- 스레드를 늘렸더니 오히려 느려질 때(거짓 공유 의심)
- 코어 고정·busy-poll을 도입할지 판단할 때

### 언제 사용하지 않나

- 처리량이 목표이고 개별 지연 목표가 없다 → `stream-pipeline-patterns`
- 밀리초 단위 서비스 응답 시간 → `service-latency`
- 핫패스가 아닌 코드 → 측정으로 병목이 확인될 때만 최적화한다(philosophy 8절, D06)

## 1. 측정 조건부터 고정한다

꼬리 지연은 측정 조건이 조금만 달라도 크게 바뀐다. 조건을 고정하지 않은 수치는 비교하지 않는다.

### 무엇을 기록하나

- p50·p99·p99.9·max를 함께 기록한다. 평균과 표준편차는 꼬리를 숨기므로 판정에 쓰지 않는다.
- 히스토그램은 HDR Histogram(C 라이브러리·Rust `hdrhistogram`)으로 남긴다. 고정 버킷 히스토그램은 꼬리 해상도가 낮다.
- 표본 수는 백분위에 비례해야 한다. p99.9 꼬리에 표본 100개가 들어가려면 최소 10만 건이 필요하다.

### 어떤 조건에서 재나

- **워밍업**: 캐시·분기 예측기·페이지 테이블이 데워질 때까지의 구간을 버린다. 버린 건수를 결과에 적는다.
- **CPU**: 주파수 거버너를 `performance`로 고정하고 터보 변동을 기록한다. 측정 스레드는 격리 코어에 고정한다.
- **시계**: 구간 측정은 `clock_gettime(CLOCK_MONOTONIC)`을 기본으로 한다. `rdtsc`는 `constant_tsc`·`nonstop_tsc` 플래그를 확인한 뒤에만 쓴다.
- **부하**: 운영과 비슷한 도착률·버스트·데이터 분포에서 잰다. 빈 시스템의 지연은 하한일 뿐이다.

### coordinated omission

닫힌 루프 부하 생성기는 응답을 기다린 뒤 다음 요청을 보낸다.
시스템이 멈춘 동안 보냈어야 할 요청을 보내지 않으므로, 꼬리 지연이 실제보다 작게 나온다.

- 부하는 열린 루프로 만든다. 요청마다 예정 시각을 정하고, 늦어도 예정 시각 기준으로 지연을 잰다.
- 열린 루프가 어려우면 HDR Histogram의 보정 기록(`hdr_record_corrected_value`)에 예정 간격을 넘긴다.

```c
/* 열린 루프: 지연의 시작점은 실제 송신 시각이 아니라 예정 시각이다 */
uint64_t intended_ns = start_ns + seq * interval_ns;
WaitUntilNs(intended_ns);
SendProbe(conn, seq, intended_ns);

/* 응답 처리에서 */
hdr_record_value(g_LatencyHist, (int64_t)(recv_ns - probe->intended_ns));
```

## 2. 캐시라인 정렬과 거짓 공유

서로 다른 스레드가 쓰는 변수가 같은 캐시라인에 있으면, 논리적으로 공유하지 않아도 라인이 코어 사이를 오간다.
이것이 거짓 공유이고, 스레드를 늘릴수록 느려지는 전형적인 원인이다.

- 다른 스레드가 쓰는 필드는 서로 다른 캐시라인에 둔다. 라인 크기는 이름 있는 상수로 둔다.
- x86-64는 64바이트다. Apple M 계열 등 128바이트인 플랫폼이 있으므로, 인접 라인 프리페치까지 막으려면 128을 쓴다.
- 구조체 크기와 필드 오프셋은 `_Static_assert`·`static_assert`로 고정한다.
- C++17 `std::hardware_destructive_interference_size`는 컴파일러마다 값과 ABI 경고가 달라 공개 구조체에는 쓰지 않는다.

```c
#include <stdalign.h>
#include <stdatomic.h>

#define CACHE_LINE_SIZE 64

/* 생산자와 소비자가 쓰는 인덱스를 다른 라인에 둔다 */
typedef struct RingIndex {
    alignas(CACHE_LINE_SIZE) _Atomic uint64_t head;   /* 생산자만 쓴다 */
    alignas(CACHE_LINE_SIZE) _Atomic uint64_t tail;   /* 소비자만 쓴다 */
} RingIndex;

_Static_assert(sizeof(RingIndex) == 2 * CACHE_LINE_SIZE, "RingIndex 레이아웃 고정");
```

```rust
use crossbeam_utils::CachePadded;
use std::sync::atomic::AtomicU64;

/// 생산자·소비자 인덱스를 다른 캐시라인에 둔다.
pub struct RingIndex {
    head: CachePadded<AtomicU64>, // 생산자만 쓴다
    tail: CachePadded<AtomicU64>, // 소비자만 쓴다
}
```

**검증**: `perf c2c record`·`perf c2c report`로 HITM(다른 코어의 수정된 라인 접근)이 많은 라인을 찾는다.
정렬을 바꾼 뒤 같은 조건에서 HITM과 p99가 함께 줄었는지 확인한다.

## 3. 단일 작성자 원칙

하나의 데이터는 하나의 스레드만 쓴다(philosophy 11절). 작성자가 하나면 락도, 쓰기 경합도 없다.

- 다른 스레드가 바꿔야 할 일이 있으면 직접 쓰지 않고 소유 스레드에 메시지를 보낸다.
- 통계 카운터는 스레드별로 두고, 수집 스레드가 주기적으로 읽어 합친다. 공유 카운터에 `atomic_fetch_add`를 하지 않는다.
- 작성자 하나·독자 여럿이면 작성자는 `memory_order_release`로 쓰고 독자는 `memory_order_acquire`로 읽는다. 오더링을 약화한 근거는 주석으로 남긴다.

```c
/* 스레드별 통계 — 작성자는 소유 워커 하나, 독자는 수집 스레드 */
typedef struct WorkerStats {
    alignas(CACHE_LINE_SIZE) _Atomic uint64_t processed;
    _Atomic uint64_t dropped;
} WorkerStats;

static WorkerStats g_WorkerStats[MAX_WORKERS];

/* HOTPATH — 소유 워커만 호출한다 */
static inline void CountProcessed(WorkerStats *stats)
{
    uint64_t cur = atomic_load_explicit(&stats->processed, memory_order_relaxed);
    /* 작성자가 하나라 RMW가 필요 없다. 독자는 찢어지지 않은 값만 보면 된다 */
    atomic_store_explicit(&stats->processed, cur + 1, memory_order_relaxed);
}
```

## 4. 코어 고정과 격리

핫패스 스레드가 다른 작업에 밀리거나 코어를 옮겨 다니면 꼬리 지연이 튄다.

| 설정 | 목적 | 확인 방법 |
|---|---|---|
| `isolcpus=` (또는 cgroup v2 cpuset의 `isolated` 파티션) | 일반 스케줄링에서 코어를 뺀다 | `cat /sys/devices/system/cpu/isolated` |
| `nohz_full=`·`rcu_nocbs=` | 격리 코어의 타이머 틱·RCU 콜백을 줄인다 | `/proc/interrupts`의 LOC 증가량 |
| IRQ 어피니티(`/proc/irq/*/smp_affinity_list`) | 장치 인터럽트를 격리 코어 밖으로 보낸다 | `/proc/interrupts` |
| `pthread_setaffinity_np`·`taskset` | 핫패스 스레드를 격리 코어에 고정한다 | `ps -eLo tid,psr,comm` |

- 핫패스 스레드 둘을 같은 물리 코어의 하이퍼스레드 형제에 두지 않는다. 형제 목록은 `thread_siblings_list`로 확인한다.
- NIC가 붙은 NUMA 노드의 코어와 메모리를 쓴다(`numactl --cpunodebind --membind`).
- 커널 파라미터는 호스트 설정이다. 코드 변경과 분리해 운영 런북에 적는다.

## 5. busy-poll과 블로킹

busy-poll은 대기 중 깨어나는 시간(수~수십 µs)을 없애는 대신 코어 하나를 계속 쓴다.

| 조건 | 선택 |
|---|---|
| 지연 목표가 수 µs 이하이고 격리 코어가 있다 | busy-poll |
| 지연 목표가 수백 µs 이상이거나 코어 여유가 없다 | 블로킹(`epoll_wait`·조건 변수) |
| 버스트 사이 유휴가 길고 목표는 수십 µs다 | 스핀 후 대기(일정 횟수 스핀 → 블로킹) |

- 격리되지 않은 코어에서 busy-poll을 하지 않는다. 같은 코어의 다른 스레드를 굶긴다.
- 스핀 루프에는 `_mm_pause()`(C·C++)나 `std::hint::spin_loop()`(Rust)를 넣는다. 형제 하이퍼스레드와 전력을 덜 빼앗는다.
- 소켓 수신은 `SO_BUSY_POLL`·`epoll_wait`의 타임아웃 0 루프를 검토한다. 커널 바이패스는 별도 설계 결정이다.
- Rust 핫패스는 Tokio 런타임 밖의 전용 스레드에서 돈다(D13). async 태스크 안에서 스핀하지 않는다.

## 6. 사전 할당 — 핫패스에서 할당하지 않는다

할당자는 락·페이지 폴트·`mmap` 시스템 콜을 숨기고 있다. 핫패스의 할당은 꼬리 지연의 흔한 원인이다.

- 버퍼·메시지·노드는 초기화 단계에서 풀로 만들어 두고, 핫패스는 풀에서 꺼내 쓰고 돌려준다.
- 풀이 비면 할당하지 않고 정해진 손실 정책(드롭·거부·백프레셔)을 따른다. 정책은 `data-throughput-accelerator` 4절에 적는다.
- 시작 시 `mlockall(MCL_CURRENT | MCL_FUTURE)`로 스왑을 막고, 풀 메모리를 한 번씩 써서 페이지 폴트를 미리 일으킨다.
- 핫패스에서 숨은 할당을 만드는 호출을 피한다: `printf` 계열, 동기 로그, C++ `std::string`·`std::function` 생성, Rust `format!`·`clone()`·`Vec::push`(용량 초과 시).
- 필요하면 huge page로 TLB 미스를 줄인다. 효과는 `perf stat -e dTLB-load-misses`로 확인한다.

**검증**: 할당이 없다는 것을 테스트로 고정한다.

- C: 테스트 빌드에서 `-Wl,--wrap=malloc`으로 호출 수를 세고, 워밍업 이후 핫패스 루프에서 0인지 단언한다(`c-testing`).
- Rust: 테스트용 `#[global_allocator]`로 할당 횟수를 세고, 같은 방식으로 단언한다.
- 운영 바이너리에서는 `perf stat -e page-faults`와 `ltrace`/`bpftrace`의 `malloc` 호출 수로 확인한다.

## 7. 분기 힌트·`#[cold]`·인라인 — 측정이 있을 때만

컴파일러의 판단을 힌트로 뒤집으면, 틀렸을 때 오히려 느려진다. 힌트는 측정 근거가 있을 때만 단다(philosophy 8절).

| 수단 | 쓰는 곳 |
|---|---|
| `__builtin_expect`·C++20 `[[likely]]`·`[[unlikely]]` | 측정으로 한쪽이 압도적인 분기 |
| `__attribute__((cold))`·Rust `#[cold]` | 에러 처리·재연결처럼 거의 실행되지 않는 함수 |
| `__attribute__((noinline))`·`#[inline(never)]` | 콜드 경로를 핫 함수 밖으로 빼 명령어 캐시를 아낄 때 |
| `inline`·`#[inline]` | 크레이트·번역 단위 경계를 넘는 작은 핫 함수 |

- 힌트를 달기 전후로 `perf stat -e branch-misses,instructions,cycles`와 p99를 같은 조건에서 비교한다. 차이가 분산보다 작으면 힌트를 뺀다.
- 중요한 경로는 생성된 어셈블리를 본다(`objdump -d`·`cargo asm`). 힌트가 실제로 배치를 바꿨는지 확인한다.
- PGO(`-fprofile-use`)가 가능하면 수동 힌트보다 PGO를 먼저 검토한다.

## 완료 전 체크리스트

- [ ] 핫패스에 `HOTPATH` 표시가 있고, 지연 목표(p99·p99.9)가 숫자로 적혀 있다.
- [ ] 측정 조건(워밍업·주파수·코어·부하 모델·표본 수)이 결과와 함께 기록돼 있다.
- [ ] 부하가 열린 루프이거나 coordinated omission을 보정했다.
- [ ] 스레드마다 쓰는 필드가 다른 캐시라인에 있고, 레이아웃이 정적 단언으로 고정돼 있다.
- [ ] 각 데이터의 작성자가 하나이고, 오더링 약화에 근거 주석이 있다.
- [ ] busy-poll 스레드는 격리 코어에 고정돼 있다.
- [ ] 워밍업 이후 핫패스 할당이 0임을 테스트로 확인했다.
- [ ] 분기 힌트·`cold`·인라인 지정마다 전후 측정 수치가 있다.
- [ ] 변경을 `performance-profiling`의 승격 게이트로 판정했다.

## 가드레일

- 안전 검사(경계·리스크 한도·입력 검증)를 빼서 지연을 줄이지 않는다.
- 측정하지 않은 개선을 커밋 메시지에 주장하지 않는다.
- 커널 파라미터·IRQ 설정을 코드 변경에 섞지 않는다. 호스트 설정은 런북으로 따로 관리한다.
- 동시성 변경은 TSan(Rust는 loom)을 통과하기 전까지 완료로 보지 않는다.
