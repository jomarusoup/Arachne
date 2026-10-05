---
name: stream-pipeline-patterns
description: 대용량 스트림 서버 파이프라인 구현 패턴(C 우선, Rust 대응 병기). 큐 선택(SPSC·MPSC·MPMC), C11 원자 연산 SPSC 링버퍼(acquire/release·캐시라인 패딩·2의 거듭제곱 마스크), I/O 묶음(recvmmsg·sendmmsg·writev·io_uring 판단·TCP_NODELAY), 버퍼 풀·슬랩으로 복사·할당 제거, 길이 prefix 프레이밍(부분 수신 재조립·최대 프레임 상한), 팬아웃(구독 관리·클라이언트별 송신 큐 상한·느린 클라이언트 강등·차단·묶음 송신), 스레드 고정·NUMA, tokio bounded mpsc·Semaphore·spawn_blocking 이식. 대상 경로 — **/*.c, **/*.h, **/*.rs, **/pipeline/**. 키워드 — 링버퍼, SPSC, 백프레셔, 프레이밍, 팬아웃, writev, recvmmsg, io_uring, TCP_NODELAY, 버퍼 풀, NUMA, tokio mpsc.
---

# 스트림 파이프라인 패턴

수신 → 해석 → 변환 → 저장·팬아웃으로 이어지는 서버 파이프라인을 C로 구현할 때 쓴다.
Rust 대응은 각 절 끝과 8절에 둔다. 처리량 산정·손실 정책 같은 원칙은 `data-throughput-accelerator`가 정본이다.

컴파일되는 예제가 `templates/project/c-system/src/pipeline/`에 있다.

| 파일 | 내용 |
|---|---|
| `spsc_ring.h/.c` | C11 원자 연산 SPSC 링버퍼 |
| `frame_codec.h/.c` | 길이 prefix 프레이밍, 부분 수신 재조립, 최대 프레임 상한 |
| `test_spsc_ring.c` | 경계 조건 + 2스레드 생산자·소비자 100만 건 정확성 테스트 |
| `test_frame_codec.c` | 1바이트씩·임의 조각 입력, 상한 초과, 처리기 중단 테스트 |
| `Makefile` | `make test`(ASan+UBSan), `make tsan`(TSan) |

## 역할 경계

| 질문 | 스킬 |
|---|---|
| 요청 하나의 지연을 어떻게 줄이나 (핫패스 분기·할당·busy-poll 기법) | `latency-critical-systems` |
| 초당 처리량을 어떻게 올리고, 넘칠 때 어떻게 흐름을 제어하나 | **이 스킬** (원칙은 `data-throughput-accelerator`) |
| 공유 상태를 어디에 두고 DB와 어떻게 맞추나 | `shm-db-patterns` |
| 키 조회 자료구조를 무엇으로 하나 | `c-data-structures` |
| 와이어 형식과 채널 명세를 어디에 적나 | `api-contracts` |

## 언제 사용하나

- 단계 사이에 큐를 두고 스레드를 나눌 때
- 소켓 수신·송신의 시스템 콜 횟수를 줄여야 할 때
- TCP 스트림에서 메시지 경계를 복원하는 코드를 쓸 때
- 한 메시지를 여러 클라이언트로 내보내는 팬아웃을 만들 때

## 1. 큐 선택

기본은 메시지 패싱이다. 단계 사이에는 상한 있는 큐를 둔다(`rules/systems/philosophy.md` 11절).

| 큐 | 생산자·소비자 | 고를 때 | C 구현 |
|---|---|---|---|
| SPSC | 1 : 1 | 단계가 스레드 하나씩이다. 가장 빠르고 검증이 쉽다 | 원자 연산 링버퍼(2절) |
| MPSC | N : 1 | 여러 수신 스레드가 저장 스레드 하나로 모은다 | 생산자별 SPSC N개를 소비자가 차례로 비운다. 또는 뮤텍스 + 조건 변수 링버퍼 |
| MPMC | N : M | 작업 분배가 동적이어야 한다 | 뮤텍스 + 조건 변수 링버퍼 |

- 락프리 직접 구현은 SPSC만 허용한다. MPSC·MPMC는 SPSC 조합이나 락 기반 큐로 만든다.
- MPSC가 필요해 보이면 먼저 SPSC N개로 바꿀 수 있는지 본다. 생산자별 순서가 그대로 유지된다.
- MPMC가 필요해 보이면 키 파티셔닝(파티션마다 SPSC)으로 바꿀 수 있는지 본다. 키 순서가 유지된다.
- 큐 원소는 고정 크기다. 큰 메시지는 버퍼 풀 인덱스만 넣는다(4절).

Rust 대응: SPSC는 `rtrb`, MPMC 고정 용량은 `crossbeam::queue::ArrayQueue`, 비동기 경계는 `tokio::sync::mpsc::channel(cap)`.

## 2. C11 SPSC 링버퍼

핵심은 네 가지다. 각자 쓰는 인덱스를 다른 캐시라인에 둔다. 인덱스는 감싸지 않고 증가시킨다.
슬롯 위치는 `인덱스 & mask`로 구한다. 쓰기 공개는 release, 읽기 확인은 acquire로 한다.

```c
#define SPSC_CACHE_LINE 128   /* x86 인접 라인 프리페치·Apple Silicon 모두 덮는 값 */

struct SpscRing
{
    _Alignas(SPSC_CACHE_LINE) _Atomic size_t head;   /* 생산자만 증가 */
    size_t                     cached_tail;           /* 생산자 지역 사본 */
    _Alignas(SPSC_CACHE_LINE) _Atomic size_t tail;   /* 소비자만 증가 */
    size_t                     cached_head;           /* 소비자 지역 사본 */
    _Alignas(SPSC_CACHE_LINE) size_t mask;           /* capacity - 1, 이후 읽기 전용 */
    size_t                     capacity;
    size_t                     slot_size;
    unsigned char             *slots;
};

int SpscRingTryPush(SpscRing *ring, const void *msg)
{
    /* HOTPATH */
    size_t head = atomic_load_explicit(&ring->head, memory_order_relaxed);   /* 자기 값 */

    if (head - ring->cached_tail == ring->capacity)
    {
        /* acquire: 소비자가 다 읽은 슬롯만 덮어쓴다 */
        ring->cached_tail = atomic_load_explicit(&ring->tail, memory_order_acquire);
        if (head - ring->cached_tail == ring->capacity)
        {
            return -EAGAIN;   /* 가득 참 — 대기·드롭·병합은 호출자 정책 */
        }
    }
    memcpy(ring->slots + (head & ring->mask) * ring->slot_size, msg, ring->slot_size);
    /* release: 슬롯 쓰기가 head 증가보다 먼저 보이게 한다 */
    atomic_store_explicit(&ring->head, head + 1, memory_order_release);
    return 0;
}
```

- 캐시된 반대편 인덱스는 가득 차거나 비어 보일 때만 갱신한다. 상대 캐시라인을 덜 건드린다.
- 오더링을 seq_cst보다 약하게 쓴 근거는 위 주석처럼 코드에 남긴다.
- 가득 참은 `-EAGAIN`으로 돌려주고 기다리지 않는다. 대기 방법(양보·`eventfd` 알림·busy-poll)은
  호출 단계가 정한다. 소비자가 잠들어야 하면 `eventfd`로 깨우고, 깨우기는 빈 → 비어 있지 않음 전환에만 한다.
- 검증: `make test`와 `make tsan`. macOS TSan은 libc `memcpy` 내부 접근을 보지 못한다.
  예제는 TSan 빌드에서만 바이트 복사로 바꿔 슬롯 경쟁을 잡는다. 최종 판정은 Linux TSan으로 한다.

## 3. I/O 묶음

시스템 콜 한 번에 여러 메시지를 처리한다. 호출 횟수가 처리량 상한을 정하는 경우가 많다.

- **UDP 수신·송신**: `recvmmsg`·`sendmmsg`로 한 번에 최대 수십 개 데이터그램을 처리한다.
  `recvmmsg`는 `MSG_WAITFORONE`과 함께 쓰면 하나라도 오면 바로 돌아온다. 리눅스 전용이므로 I/O 모듈 하나에 격리한다.
- **TCP 송신**: 여러 프레임을 `sendmsg`(iovec 배열)로 한 번에 보낸다. `writev`와 같지만
  `MSG_NOSIGNAL`로 끊긴 연결의 `SIGPIPE`를 막을 수 있다. 부분 송신을 처리한다.
- **TCP 수신**: 큰 버퍼(예: 64KiB)로 한 번에 읽고 디코더에 통째로 넣는다(5절).
  에지 트리거 epoll이면 `EAGAIN`까지 읽되, 연결당 읽기 예산을 두어 한 연결이 루프를 독점하지 않게 한다.
  예산을 다 쓴 연결은 준비 목록에 남겨 다음 반복에서 이어 읽는다.
- **`TCP_NODELAY`**: 스트림 송신 소켓에는 켠다. Nagle 알고리즘은 작은 쓰기를 모아 보내느라
  지연을 만든다. 대신 애플리케이션이 직접 묶어서(6절 묶음 송신) 작은 쓰기를 없앤다.
  `TCP_NODELAY`만 켜고 프레임마다 `send`하면 패킷 수와 시스템 콜이 폭증한다.
- **소켓 버퍼**: `SO_SNDBUF`·`SO_RCVBUF`는 대역폭 × 왕복 시간 이상으로 잡는다. 커널 상한(`net.core.rmem_max`)도 함께 확인한다.
- **io_uring 판단**: 다음이 모두 맞을 때만 검토한다. epoll + 묶음 I/O로 측정한 결과 시스템 콜이
  CPU의 상당 부분을 차지한다. 대상 커널 버전이 고정돼 있다. 보안 정책이 io_uring을 허용한다.
  도입하면 별도 모듈로 격리하고 epoll 경로를 대체 경로로 남긴다.

```c
/* 송신 큐의 앞부분 프레임을 한 번의 시스템 콜로 보낸다 */
static int FlushSendQueue(Client *cli)
{
    struct iovec  iov[SEND_IOV_MAX];
    struct msghdr msg = {0};
    int           cnt = SendQueuePeek(cli->sendq, iov, SEND_IOV_MAX);
    ssize_t       sent;

    if (cnt == 0)
    {
        return 0;
    }
    msg.msg_iov    = iov;
    msg.msg_iovlen = (size_t)cnt;
    sent = sendmsg(cli->fd, &msg, MSG_NOSIGNAL | MSG_DONTWAIT);
    if (sent < 0)
    {
        if (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK)
        {
            return 0;   /* EPOLLOUT을 기다린다 */
        }
        return -errno;
    }
    SendQueueAdvance(cli->sendq, (size_t)sent);   /* 부분 송신: 프레임 중간부터 이어 보낸다 */
    return 0;
}
```

Rust 대응: `tokio::io::AsyncWriteExt::write_vectored`, UDP 묶음은 `quinn-udp` 같은 검증된 crate를 먼저 찾는다.

## 4. 복사·할당 제거

핫패스에서는 `malloc`·`free`를 부르지 않는다. 메모리는 시작할 때 확보하고 재사용한다.

- **버퍼 풀**: 같은 크기 블록 N개를 한 번에 할당하고, 빈 블록 인덱스를 스택(배열)으로 관리한다.
  풀은 한 스레드가 소유한다. 다른 스레드로 넘긴 블록은 반환 큐(SPSC)로 돌려받는다.
- **슬랩**: 크기 등급(예: 256B·1KiB·4KiB·64KiB)별로 풀을 둔다. 등급을 넘는 메시지는 프레이밍 상한으로 막는다.
- **인덱스 전달**: 큐에는 블록 인덱스와 길이만 넣는다. 공유메모리와 같은 원칙이다(포인터 대신 인덱스).
- **무복사 경계**: 복사는 경계마다 한 번만 한다. 수신 버퍼 → 디코딩(완성 프레임이면 복사 없이 포인터 전달)
  → 내부 레코드 → 송신 인코딩(팬아웃이면 **한 번만** 인코딩해 모든 클라이언트가 같은 블록을 참조).
- **참조 계수**: 팬아웃 공유 블록은 참조 수를 들고, 마지막 송신이 끝나면 풀로 돌아간다.
  여러 스레드가 해제하면 `atomic_fetch_sub`(acq_rel)로 센다. 한 스레드만 해제하면 일반 정수로 충분하다.
- 파일·공유메모리에서 소켓으로 그대로 보내는 경로는 `sendfile`·`splice`를 검토한다.

Rust 대응: `bytes::Bytes`(참조 계수 무복사 슬라이스), `BytesMut` 재사용, 객체 풀은 측정 근거가 있을 때만.

## 5. 프레이밍 코덱

TCP는 바이트 스트림이다. `recv` 한 번이 프레임 하나와 일치한다고 가정하지 않는다.

- 형식은 `[길이 4바이트][payload]`다. 길이 필드의 엔디언·최대값·버전 필드는 `api-contracts`의 채널 명세가 정본이다.
- **부분 수신 재조립**: 디코더는 "헤더 수집 중 / 본문 수집 중" 상태를 연결마다 들고 있다.
  어떤 크기의 조각이 와도(1바이트라도) 같은 프레임이 나와야 한다. 테스트로 1바이트씩 넣어 확인한다.
- **최대 프레임 상한**: 길이 필드를 읽는 즉시 상한과 비교하고, 넘으면 본문을 기다리지 않고 연결을 끊는다.
  상한이 없으면 거짓 길이 하나로 메모리를 고갈시킬 수 있다(DoS). 재조립 버퍼는 상한 크기로 미리 할당한다.
- 본문 전체가 이번 입력 안에 있으면 복사하지 않고 입력 포인터를 그대로 넘긴다.
- 오류 후 디코더는 오류 상태로 남는다. 스트림 동기를 잃었으므로 다시 맞추지 말고 연결을 끊는다.
- 디코더는 퍼징 대상이다(libFuzzer로 `FrameDecoderFeed`에 임의 바이트를 넣는다).

```c
/* HOTPATH — 에지 트리거 수신: EAGAIN까지 읽고 디코더에 넘긴다 */
static int OnReadable(Client *cli)
{
    uint8_t buf[RECV_CHUNK];
    int     budget = RECV_BUDGET;   /* 한 연결의 루프 독점 방지 */

    while (budget-- > 0)
    {
        ssize_t got = recv(cli->fd, buf, sizeof(buf), 0);

        if (got > 0)
        {
            int rc = FrameDecoderFeed(cli->dec, buf, (size_t)got, OnFrame, cli);
            if (rc < 0)
            {
                return rc;   /* -EMSGSIZE 상한 초과 등 → 호출자가 연결 종료 */
            }
            continue;
        }
        if (got == 0)
        {
            return -ECONNRESET;   /* 상대가 연결을 닫았다 */
        }
        if (errno == EINTR)
        {
            continue;
        }
        return (errno == EAGAIN || errno == EWOULDBLOCK) ? 0 : -errno;
    }
    return 1;   /* 예산 소진 — 준비 목록에 남긴다 */
}
```

Rust 대응: `tokio_util::codec::LengthDelimitedCodec::builder().max_frame_length(MAX)`로 같은 규칙을 얻는다.

## 6. 팬아웃

한 메시지를 많은 클라이언트에 보낸다. 느린 클라이언트 하나가 나머지를 막지 않게 하는 것이 핵심이다.

- **구독 관리**: 채널(또는 키)별 구독자 목록을 연속 배열로 둔다. 구독 변경은 팬아웃 스레드 하나만 한다.
  다른 스레드의 구독 요청은 제어 큐로 받아 팬아웃 루프 사이에 반영한다.
- **한 번 인코딩**: 메시지를 프레임으로 한 번 인코딩하고, 구독자마다 참조만 송신 큐에 넣는다(4절).
- **클라이언트별 송신 큐 상한**: 건수와 바이트 둘 다 상한을 둔다. 상한 산정은 허브의 버스트 계산을 따른다.
- **느린 클라이언트 단계 처리**: 송신 큐 깊이로 상태를 바꾼다.

| 상태 | 들어가는 조건 | 동작 |
|---|---|---|
| 정상 | 큐 < 높은 수위(예: 50%) | 모든 메시지를 큐에 넣는다 |
| 강등 | 큐 ≥ 높은 수위 | 최신값 병합 채널은 키별 최신값만 남긴다. 샘플링 채널은 버린다. 전량 보존 채널은 그대로 넣는다 |
| 차단 | 큐 가득 참, 또는 강등이 T초 이상 지속 | 연결을 끊고 사유를 기록한다. 재접속 시 스냅샷 + 증분으로 재동기화한다 |
| 복귀 | 큐 < 낮은 수위(예: 20%) | 정상으로 돌아간다(높은·낮은 수위를 달리해 상태가 떨리지 않게 한다) |

- **묶음 송신**: 팬아웃 루프 한 바퀴 동안 클라이언트별로 쌓인 프레임을 3절의 `sendmsg` 한 번으로 보낸다.
  묶음은 "N 프레임 또는 T 마이크로초"로 닫는다.
- 송신 실패(`EPIPE`·`ECONNRESET`)는 그 클라이언트만 정리한다. 팬아웃 루프를 멈추지 않는다.
- 클라이언트 쪽 수신·병합은 `desktop-data-client`를 따른다.

Rust 대응: 채널당 `tokio::sync::broadcast`는 느린 수신자에게 `Lagged`를 돌려준다. 이것이 드롭 정책이다.
전량 보존이 필요하면 클라이언트별 `mpsc::channel(cap)`과 `try_send` 실패 시 강등·차단으로 같은 표를 구현한다.

## 7. 스레드 고정과 NUMA

측정으로 문맥 전환·캐시 미스가 확인된 뒤에 적용한다.

- 단계 스레드를 코어에 고정한다(`pthread_setaffinity_np`). 같은 SPSC를 공유하는 생산자·소비자는
  같은 소켓의 다른 물리 코어에 둔다. 하이퍼스레드 형제 코어는 캐시를 나눠 써 서로 방해한다.
- 커널 쪽 방해를 줄인다. `isolcpus`·`nohz_full`로 핫패스 코어를 떼어 두고, NIC 인터럽트(IRQ 친화성)는
  수신 스레드와 같은 NUMA 노드의 다른 코어로 보낸다.
- 메모리는 처음 쓰는 스레드의 노드에 배치된다(first-touch). 링버퍼·버퍼 풀은 그 스레드가 초기화한다.
  `numactl --hardware`로 노드를 확인하고, NIC가 붙은 노드(`/sys/class/net/<인터페이스>/device/numa_node`)에 수신 경로를 둔다.
- 친화성 코드는 리눅스 전용이므로 한 모듈에 격리한다. 예제와 테스트는 고정 없이도 동작해야 한다.

Rust 대응: `core_affinity` crate로 고정한다. 핫패스는 tokio 런타임 밖의 전용 스레드로 둔다(D13).

## 8. Rust 이식 대응표

C 모듈을 Rust로 옮길 때 같은 흐름 제어를 유지한다. 주변부는 tokio, 핫패스는 전용 스레드다.

| C 구성 | Rust 대응 | 주의 |
|---|---|---|
| SPSC 링버퍼 | `rtrb::RingBuffer` | 전용 스레드 사이에서만. async 안에서 바쁜 대기 금지 |
| 상한 있는 단계 큐 | `tokio::sync::mpsc::channel(cap)` | `send().await`가 대기(백프레셔), `try_send`가 드롭·강등 지점 |
| 동시 처리 상한 | `tokio::sync::Semaphore` | 진행 중 DB 배치·요청 수를 제한한다 |
| 블로킹 DB·FFI 호출 | `tokio::task::spawn_blocking` 또는 전용 스레드 | Pro*C·ecpg FFI는 스레드별 컨텍스트를 지킨다 |
| 프레이밍 디코더 | `LengthDelimitedCodec` + `max_frame_length` | 상한을 반드시 지정한다 |
| 팬아웃 | `broadcast`(드롭) 또는 클라이언트별 `mpsc`(보존) | 6절 표와 같은 상태 전환 |
| 공유 블록 | `bytes::Bytes` | 참조 계수 무복사 |

```rust
// 저장 단계: 상한 있는 채널 + 배치 + 동시 커밋 수 제한
let (tx, mut rx) = tokio::sync::mpsc::channel::<Record>(STORE_QUEUE_CAP);
let permits = Arc::new(Semaphore::new(MAX_INFLIGHT_BATCH));

tokio::spawn(async move {
    let mut batch = Vec::with_capacity(BATCH_ROWS);
    while rx.recv_many(&mut batch, BATCH_ROWS).await > 0 {
        let permit = permits.clone().acquire_owned().await.expect("semaphore closed");
        let rows = std::mem::take(&mut batch);
        tokio::task::spawn_blocking(move || {
            let _permit = permit;          // 배치가 끝나면 반환된다
            store_rows(&rows)              // 블로킹 DB 적재 — 런타임 스레드를 막지 않는다
        });
    }
});
// 수신 측: tx.send(rec).await 는 큐가 차면 기다린다 = 백프레셔 전파
```

## 9. 검증

- 단위 테스트: 빈 큐·가득 찬 큐·감싸기, 1바이트씩 입력, 상한 정확히·상한+1, 길이 0 프레임.
- 동시성: 2스레드 생산자·소비자로 순서와 전량 수신을 확인하고 TSan으로 돌린다. TSan 통과 전에는 미완료다.
- 오더링을 약하게 바꾸면 테스트가 잡는지 한 번 확인한다(release → relaxed로 바꾸면 TSan이 경쟁을 보고해야 한다).
- 부하: 목표 레이트의 1배·2배·버스트에서 큐 깊이·드롭·p99를 기록한다(`load-testing`).
- 장시간: 1시간 이상 돌려 메모리·큐 깊이가 평탄한지 본다.

```bash
make -C templates/project/c-system/src/pipeline test
make -C templates/project/c-system/src/pipeline tsan
```
