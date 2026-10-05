---
name: desktop-data-client
description: TypeScript 데스크톱 클라이언트(Electron)·웹 클라이언트가 C 서버의 고정 레이아웃 바이너리 스트림을 대량으로 받아 밀집 화면에 보여 주는 구조. utilityProcess·worker_threads에서 Node net 직접 수신(pause/resume 백프레셔), 웹은 Worker + WebSocket(수신 백프레셔 없음 → 서버 송신 상한 필수), 재사용 버퍼·DataView 프레임 재조립(메시지별 할당 없음·최대 프레임 상한), 화면 주기(약 16ms) 키별 최신값 병합과 MessagePort + transferable ArrayBuffer 전달, SharedArrayBuffer 링(COOP/COEP·같은 프로세스 한정), GC 억제, 수치 정밀도(정수 스케일·bigint·branded 타입·표시 시점 포맷), 키 정렬 배열 + 인덱스 맵 자료구조, 가상화 그리드 + canvas·갱신률 상한, Rust → WASM·napi-rs 판단, 장시간 메모리 추세 감시, Playwright _electron E2E. 예제는 templates/project/desktop-data-client. 대상 경로 — **/*.ts, **/*.tsx, **/*.mjs, **/main/**, **/preload/**, **/workers/**, **/desktop-data-client/**. 키워드 — 클라이언트 대용량 수신, Electron 수신, utilityProcess, worker_threads, 프레임 재조립, DataView, 병합, coalescing, MessagePort, Transferable, SharedArrayBuffer, useSyncExternalStore, bigint, branded, 가상화 그리드, canvas, WASM, napi-rs.
---

# 데스크톱 클라이언트 대용량 수신

C 서버가 TCP로 보내는 길이 prefix 고정 레이아웃 바이너리를 초당 수만 건 이상 받아,
밀집 그리드로 보여 주고 사용자 동작을 다시 보내는 TS 클라이언트를 만들 때 쓴다.
핵심은 세 가지다. **renderer 밖에서 받고, 메시지마다 할당하지 않고, 화면 주기마다 한 번만 그린다.**

실행 가능한 예제가 `templates/project/desktop-data-client/`에 있다(의존성 없음, `node --test`로 실행).

| 파일 | 내용 |
|---|---|
| `frame-reader.mjs` | 재사용 버퍼·`DataView` 재조립기, 부분 수신, 최대 프레임 상한, 실패 상태 고정 |
| `coalescing-store.mjs` | 키별 최신값 병합, 주기당 한 번 통지, `useSyncExternalStore` 호환 |
| `*.test.mjs` | 1바이트 조각·임의 분할·상한 초과·버퍼 재사용·병합 건수 테스트 |

## 역할 경계

| 질문 | 스킬·규칙 |
|---|---|
| 처리량 산정, 손실 정책, 시퀀스 갭·재동기화 원칙 | `data-throughput-accelerator` (정본) |
| 서버 쪽 프레이밍·클라이언트별 송신 큐 상한 | `stream-pipeline-patterns` 5·6절 |
| 와이어 레이아웃·엔디언·테스트 벡터 정본 | `api-contracts` |
| 정렬 배열·인덱스 설계 원칙 | `c-data-structures` |
| Electron 창 설정·IPC 보안·프로세스 역할 | `rules/electron/security.md`, `rules/electron/patterns.md` |
| renderer 번들 구성 | `vite-patterns` 4절 |

## 언제 사용하나

- Electron 앱이 C 서버와 TCP로 직접 연결해 초당 수천 건 이상을 받을 때
- 웹 클라이언트가 WebSocket으로 같은 스트림을 받을 때
- 그리드가 버벅이거나, 메모리가 시간이 갈수록 오르거나, 가격이 소수점 오차로 틀어질 때

### 언제 사용하지 않나

- 초당 수십 건 이하의 요청·응답 화면 → `frontend-patterns`
- JSON REST 응답 처리 → `json-contracts`

## 전체 구조

```
C 서버 ─TCP─▶ [utility process]  net 수신 → FrameReader → 디코드 → 키별 병합
                                     │ 16ms마다 묶음 1개 (ArrayBuffer transfer)
                                     ▼ MessagePort (main을 거치지 않음)
              [renderer]           스토어 반영 → 보이는 행만 그리기 (가상화·canvas)
              사용자 동작 ◀── preload 최소 API ── ipcMain(허용 목록) ── 수신 프로세스가 송신
```

## 1. 수신 — utility process와 Node `net`

수신은 renderer가 아닌 utility process(또는 `worker_threads`)에서 한다. renderer 메인 스레드에서
디코딩하면 GC와 그리기가 서로를 막는다. Node `net`은 **수신 백프레셔가 동작한다.**
`socket.pause()`로 읽기를 멈추면 커널 수신 버퍼가 차고, TCP 윈도가 줄어 서버 송신이 늦춰진다.

```typescript
// feed.ts — utility process 진입점
import net from "node:net";

const sock   = net.connect({ host: cfg.host, port: cfg.port });
const reader = new FrameReader({ maxFrame: MAX_FRAME });
sock.setNoDelay(true);

sock.on("data", (chunk: Buffer) => {
    try {
        reader.Push(chunk, OnFrame);   // OnFrame은 디코드 후 store.Put 또는 보존 큐에 넣는다
    } catch (error: unknown) {
        sock.destroy(error instanceof Error ? error : undefined);   // 동기를 잃었다 → 재연결 + 스냅샷
        return;
    }
    if (g_KeepQueue.length > KEEP_HIGH_WATER) sock.pause();
});

function OnKeepDrained(): void {              // 보존 큐를 renderer로 넘긴 뒤 부른다
    if (sock.isPaused() && g_KeepQueue.length < KEEP_LOW_WATER) sock.resume();
}
```

- **채널마다 손실 정책을 정한다.** 시세처럼 최신값만 의미 있는 채널은 병합한다. 병합 저장소는 키 수만큼만 커지므로 멈출 일이 없다.
- 체결·주문 응답처럼 전량 보존 채널은 상한 있는 큐에 넣고, 상한(high water)에서 `pause`, 하한(low water)에서 `resume`한다.
- 멈춘 시간이 길면 서버가 그 클라이언트를 강등하거나 끊는다. 재연결 후에는 스냅샷 + 증분으로 다시 맞춘다.
- 시퀀스 번호로 갭을 검사한다. 갭이 나면 추측해서 메우지 않고 재동기화를 요청한다.
- 연결 상태는 판별 유니온(`idle`·`connecting`·`open`·`closed`)으로 두고 지수 백오프로 재연결한다.

## 2. 웹 변형 — Worker와 WebSocket

브라우저 WebSocket의 `onmessage`에는 **수신 백프레셔가 없다.** 처리가 늦어도 메시지는 계속 쌓여 메모리가 오른다.

- 수신은 Dedicated Worker에서 한다. `ws.binaryType = "arraybuffer"`로 두어 `Blob` 변환을 피한다.
- WebSocket은 메시지 경계를 지켜 준다. 서버가 메시지 하나에 프레임 여러 개를 묶어 보내면 같은 `FrameReader`로 푼다.
- **서버 송신 상한이 필수다.** 서버는 클라이언트별 송신 큐 상한과 느린 클라이언트 강등·차단을 둔다(`stream-pipeline-patterns` 6절).
- 클라이언트는 처리 지연(수신 시각과 반영 시각의 차)을 재서 서버에 알리고, 서버가 그 클라이언트의 전송률을 낮춘다.
- `WebSocketStream`은 백프레셔를 주지만 지원 브라우저가 제한적이다. 쓸 때는 기능 감지 후 폴백을 둔다.

## 3. 프레임 재조립 — 재사용 버퍼, 메시지별 할당 없음

TCP `data` 한 번이 프레임 하나와 맞는다고 가정하지 않는다. 재조립기는 버퍼 하나를 재사용하고,
완성된 프레임을 **내부 버퍼의 위치(offset·length)로** 넘긴다. 메시지마다 `slice`·`new`를 하지 않는다.

```typescript
export class FrameReader {
    private buf:   Uint8Array;
    private view:  DataView;
    private read   = 0;
    private write  = 0;
    private failed = false;

    constructor(private readonly maxFrame: number, capacity = 64 * 1024) {
        this.buf  = new Uint8Array(Math.min(capacity, maxFrame + 4));
        this.view = new DataView(this.buf.buffer);
    }

    // onFrame의 view·offset은 콜백 동안만 유효하다. 보관하려면 필요한 필드만 읽어 둔다.
    Push(chunk: Uint8Array, onFrame: (view: DataView, offset: number, length: number) => void): void {
        if (this.failed) throw new Error("실패 상태 — 연결을 끊는다");
        let pos = 0;
        try {
            while (pos < chunk.length) {
                if (this.read > 0) {                       // 소비한 앞부분을 버린다
                    this.buf.copyWithin(0, this.read, this.write);
                    this.write -= this.read;
                    this.read   = 0;
                }
                if (this.write === this.buf.length) this.Grow();   // 부분 프레임이 버퍼를 채웠을 때만
                const take = Math.min(this.buf.length - this.write, chunk.length - pos);
                this.buf.set(chunk.subarray(pos, pos + take), this.write);
                this.write += take;
                pos        += take;
                while (this.write - this.read >= 4) {
                    const len = this.view.getUint32(this.read, false);   // 엔디언은 계약대로 명시
                    if (len > this.maxFrame) throw new Error(`프레임 ${len} > 상한`);
                    if (this.write - this.read - 4 < len) break;
                    onFrame(this.view, this.read + 4, len);
                    this.read += 4 + len;
                }
            }
        } catch (error: unknown) {
            this.failed = true;
            throw error;
        }
    }

    private Grow(): void { /* 2배, 단 maxFrame + 4를 넘지 않는다 — 예제 frame-reader.mjs 참고 */ }
}
```

- 길이 필드는 읽는 즉시 상한과 비교한다. 본문을 기다리지 않는다. 거짓 길이 하나로 메모리를 고갈시킬 수 있다.
- 오류 뒤에는 스트림 동기를 잃었으므로 다시 맞추지 않는다. 연결을 끊고 새 리더로 재연결한다.
- 버퍼는 부분 프레임 하나가 버퍼를 채울 때만 키운다. 정상 상태에서는 크기가 변하지 않는다(예제 테스트로 확인).

### 고정 레이아웃 디코딩

오프셋은 C 헤더 구조체에서 생성한 상수로 둔다. 손으로 쓴 오프셋은 레이아웃이 바뀌면 조용히 틀린다.

```typescript
// 생성 파일: C 헤더(정본)에서 만든다. 손으로 고치지 않는다.
export const QUOTE = { SIZE: 32, KEY: 0, SEQ: 4, PRICE: 8, QTY: 16, FLAGS: 24 } as const;

function OnFrame(view: DataView, off: number, len: number): void {
    if (len !== QUOTE.SIZE) { g_Stats.badLength++; return; }
    const key   = view.getUint32(off + QUOTE.KEY, true);
    const price = view.getBigInt64(off + QUOTE.PRICE, true) as PriceTicks;   // 64비트는 bigint로
    const qty   = view.getBigInt64(off + QUOTE.QTY, true) as Quantity;
    g_Table.Upsert(key, price, qty);   // 열 배열에 쓰고 바뀐 키로 표시한다. 행 객체는 만들지 않는다
}
```

- 엔디언 인자를 항상 적는다. `DataView`의 기본값은 빅엔디언이다.
- 수신 프로세스의 병합은 열 배열 + 바뀐 키 표시로 한다. 행 객체는 renderer에서 주기마다 바뀐 키에 대해서만 만든다.
- C ↔ TS 디코더는 같은 테스트 벡터 파일로 상호 검증한다(`api-contracts`).

## 4. renderer 전달 — 화면 주기 병합

renderer에 메시지마다 보내지 않는다. 수신 쪽에서 키별 최신값으로 병합하고, 약 16ms마다 바뀐 행만 묶어 한 번 보낸다.

- 묶음은 고정 레이아웃 `ArrayBuffer` 하나로 만들고 `port.postMessage(buf, [buf])`로 **transfer**한다. 복사가 없다.
- transfer한 버퍼는 보낸 쪽에서 분리(detached)된다. renderer가 다 쓴 버퍼를 돌려보내 풀로 재사용한다.
- 객체 배열을 보내지 않는다. 구조화 복제는 객체 수에 비례해 느리고 받는 쪽 GC를 늘린다.
- utility process와 renderer는 `MessageChannelMain`으로 직접 잇는다. preload는 받은 포트를 `window.postMessage(..., [port])`로 페이지에 넘긴다.

### `SharedArrayBuffer` 링 — 같은 프로세스 안에서만

`SharedArrayBuffer`는 **같은 프로세스의 스레드끼리만** 공유된다. utility process와 renderer 사이에는 쓸 수 없다.
renderer 안 Worker가 수신·디코딩하고 메인 스레드가 읽는 구조(웹 변형 포함)에서 복사를 없앨 때 쓴다.

- 페이지가 교차 출처 격리(`crossOriginIsolated`)되어야 한다. 응답 헤더 `Cross-Origin-Opener-Policy: same-origin`과
  `Cross-Origin-Embedder-Policy: require-corp`가 필요하다. Electron은 앱 프로토콜 핸들러에서 붙인다.
- 링은 단일 생산자·단일 소비자로 두고 머리·꼬리 인덱스는 `Atomics.load`·`Atomics.store`로 읽고 쓴다(원리는 `stream-pipeline-patterns` 2절).
- 소비자는 rAF마다 쌓인 만큼 읽는다. `Atomics.wait`는 메인 스레드에서 쓸 수 없다.

### 병합 스토어와 `useSyncExternalStore`

```typescript
export class CoalescingStore<K, V> {
    private pending   = new Map<K, V>();
    private values    = new Map<K, V>();
    private listeners = new Set<() => void>();
    private version   = 0;
    private scheduled = false;
    merged = 0;   // 병합으로 버린 건수 — 손실 정책의 관측 지표

    Put(key: K, value: V): void {          // value는 불변 객체로 넘긴다
        if (this.pending.has(key)) this.merged++;
        this.pending.set(key, value);
        if (!this.scheduled) {
            this.scheduled = true;
            requestAnimationFrame(this.Flush);
        }
    }
    Get = (key: K): V | undefined => this.values.get(key);
    Subscribe = (listener: () => void): (() => void) => {
        this.listeners.add(listener);
        return () => this.listeners.delete(listener);
    };
    GetSnapshot = (): number => this.version;   // 반영이 없으면 같은 값 → 불필요한 렌더 없음

    private Flush = (): void => {
        this.scheduled = false;
        if (this.pending.size === 0) return;
        for (const [key, value] of this.pending) this.values.set(key, value);
        this.pending.clear();
        this.version++;
        this.listeners.forEach((listener) => listener());
    };
}

// 행 하나만 구독한다. 그 행 객체가 바뀔 때만 다시 그린다.
export function useRow(store: CoalescingStore<number, Row>, key: number): Row | undefined {
    return useSyncExternalStore(store.Subscribe, () => store.Get(key));
}
```

- 스냅샷 함수는 바뀌지 않았으면 같은 값을 돌려줘야 한다. 매번 새 객체를 만들면 무한 렌더가 난다.
- 값 객체를 제자리에서 고치지 않는다. 바뀐 행은 새 객체로 `Put`한다.

## 5. GC 억제

초당 수만 건에서 메시지마다 객체 하나를 만들면 GC 정지가 화면 끊김으로 보인다.

- 핫루프에서 클로저·문자열 연결·템플릿 리터럴·`JSON.parse`·구조 분해를 쓰지 않는다. 모두 할당한다.
- 디코딩 결과는 객체가 아니라 열 단위 타입 배열(`Int32Array`·`BigInt64Array`)에 바로 쓴다.
- `getBigInt64`도 bigint 값을 힙에 만든다. 초당 수십만 건이면 하위 32비트는 `getUint32`, 상위 32비트는 `getInt32`로 읽어
  `Uint32Array`·`Int32Array` 열에 나눠 두고, 계산·표시 시점에만 bigint로 합친다.
- 꼭 객체가 필요하면 풀에서 꺼내 쓰고 돌려준다. 풀은 상한을 둔다.
- 문자열 필드(고정 길이 `char[N]`)는 화면에 보일 때만 `TextDecoder`로 바꾸고 키별로 캐시한다.
- 측정은 Chrome DevTools Performance의 GC 표시와 Memory 탭 할당 타임라인으로 한다. 수신 프로세스는 `--inspect`로 붙는다.

## 6. 수치 정밀도 — 가격·수량은 JS 실수가 아니다

`number`는 64비트 실수다. `0.1 + 0.2`가 `0.30000000000000004`가 되고, 2^53을 넘는 정수는 손상된다.

- 와이어에서는 **정수 스케일**(최소 단위 틱 수)로 받는다. 스케일(소수 자릿수)은 계약에 적는다.
- 64비트 필드는 `getBigInt64`로 읽어 `bigint`로 다룬다. 범위가 2^53 미만임이 계약으로 보장되면 정수 `number`도 된다.
  이때 디코드에서 `Number.isSafeInteger`로 검사한다.
- 단위가 다른 정수를 섞지 못하게 branded 타입을 쓴다.
- 문자열 변환은 **표시할 때 한 번만** 한다. 계산·비교·정렬은 정수로 한다. `parseFloat`·`toFixed`로 계산하지 않는다.
- 사용자 입력은 문자열에서 바로 스케일 정수로 바꾼다. 실수를 거치지 않는다.

```typescript
type PriceTicks = bigint & { readonly __brand: "PriceTicks" };
type Quantity   = bigint & { readonly __brand: "Quantity" };

// 표시 전용: 1234567n, scale 2 → "12345.67"
export function FormatScaled(value: bigint, scale: number): string {
    const sign = value < 0n ? "-" : "";
    const abs  = value < 0n ? -value : value;
    const base = 10n ** BigInt(scale);
    const frac = (abs % base).toString().padStart(scale, "0");
    return scale === 0 ? `${sign}${abs}` : `${sign}${abs / base}.${frac}`;
}

// 입력 전용: "12345.67", scale 2 → 1234567n. 자릿수 초과·형식 오류는 거부한다.
export function ParseScaled(text: string, scale: number): bigint {
    const match = /^(-?)(\d+)(?:\.(\d+))?$/.exec(text.trim());
    if (match === null || (match[3] ?? "").length > scale) throw new RangeError("형식 오류");
    const digits = match[2] + (match[3] ?? "").padEnd(scale, "0");
    return (match[1] === "-" ? -1n : 1n) * BigInt(digits);
}
```

## 7. 클라이언트 자료구조 — 키 정렬 배열과 인덱스 맵

원칙은 `c-data-structures`와 같다. **찾는 방법을 먼저 적고, 자료구조는 그 답에서 고른다.**

| 접근 패턴 | 구조 |
|---|---|
| 키로 행 찾기 | `Map<key, rowIndex>` 인덱스 맵 + 열 단위 타입 배열 저장소 |
| 키 순서 표시·범위 조회 | 키 정렬 배열 + 이분 탐색, 삽입은 `copyWithin`으로 밀기 |
| 다른 열 기준 정렬 화면 | 저장소는 그대로 두고 행 번호 배열(뷰)만 정렬 |
| 최근 N건 | 고정 용량 링버퍼 |

- 저장소와 표시 순서를 분리한다. 정렬·필터는 행 번호 배열만 바꾼다. 저장소 행은 옮기지 않는다.
- 정렬 뷰는 갱신마다 다시 정렬하지 않는다. 정렬 키 열이 바뀐 행만 위치를 고치거나, 주기(예: 250ms)마다 다시 정렬한다.
- 정렬 불변식 검사(`CheckSorted`)를 테스트와 개발 빌드에 둔다.

## 8. 밀집 표시 — 가상화와 canvas

- 그리드는 가상화한다. 보이는 행과 위아래 여유 몇 행만 DOM에 둔다.
- 셀 수천 개가 초당 여러 번 바뀌면 DOM 대신 canvas로 그린다. rAF마다 스토어의 바뀐 행만 다시 그린다.
- 갱신률에 상한을 둔다. 같은 셀은 초당 10~30회면 충분하다. 사람이 그 이상은 읽지 못한다.
- 깜빡임(변경 강조)은 CSS 애니메이션 클래스가 아니라 그리기 루프의 시각 비교로 한다.
- React는 레이아웃·입력·패널에 쓰고, 고빈도 셀 그리기는 React 렌더 밖에서 한다.

## 9. 계산 오프로드 — Rust → WASM 또는 napi-rs

먼저 프로파일로 병목을 확인한다. JS 디코딩은 대부분 충분히 빠르다. 경계를 넘는 복사 비용이 이득을 지우기 쉽다.

| 조건 | 선택 |
|---|---|
| 디코딩·집계가 프레임 예산(16ms)의 절반을 넘고 웹 변형도 필요 | Rust → WASM (Worker 안, 선형 메모리에 직접 쓰기) |
| 수신 프로세스에서 OS 기능·SIMD·대용량 계산이 필요 | napi-rs 네이티브 모듈 (utility process에서만) |
| 측정 전, 또는 JS로 예산 안에 든다 | 옮기지 않는다 |

- napi-rs는 플랫폼별(Windows x64·arm64, macOS universal) 빌드와 서명이 늘어난다. 배포 비용까지 함께 따진다.
- WASM은 선형 메모리 위에 링을 두고 JS는 그 위의 타입 배열 뷰로 읽는다. 호출마다 복사하지 않는다.

## 10. 장시간 안정성

- 수신 프로세스는 분 단위로 `heapUsed`·`arrayBuffers`·`rss`, 큐 깊이, 병합 건수, 처리 지연 p99를 기록한다.
- 같은 부하에서 1시간 동안 메모리가 계속 오르면 힙 스냅샷 두 장을 비교한다. 흔한 원인은 닫힌 창의 리스너, 끝없이 커지는 키 맵, 해제하지 않은 포트다.
- 키 맵에는 만료 정책을 둔다(거래 종료·구독 해제 시 삭제).
- 수신 프로세스·창은 각각 재시작할 수 있어야 한다. 재시작 후에는 스냅샷 + 증분으로 복원한다(`rules/electron/patterns.md`).

## 11. 테스트와 E2E

- 재조립기는 1바이트 조각, 임의 분할, 상한 초과, 콜백 예외를 테스트한다(예제 `frame-reader.test.mjs`).
- 디코더는 C와 같은 테스트 벡터로 검증한다. 64비트 경계값(2^53 ± 1, 음수)을 넣는다.
- E2E는 Playwright `_electron`으로 한다. 송신 시뮬레이터(작은 Node `net` 서버)로 정해진 프레임을 보낸다.

```typescript
import { _electron as electron, expect, test } from "@playwright/test";

test("수신한 행이 그리드에 보이고 IPC 노출이 최소다", async () => {
    const app  = await electron.launch({ args: ["dist/main/index.js"], env: { FEED_PORT: "47001" } });
    const page = await app.firstWindow();

    await expect(page.getByRole("row", { name: /KEY-0001/ })).toBeVisible();
    expect(await page.evaluate(() => Object.keys((window as any).api).sort()))
        .toEqual(["SubmitAction", "Subscribe"]);                 // 허용 목록과 같아야 한다
    expect(await page.evaluate(() => typeof (window as any).require)).toBe("undefined");
    expect(await app.evaluate(({ BrowserWindow }) =>
        BrowserWindow.getAllWindows()[0].webContents.getLastWebPreferences()?.sandbox)).toBe(true);
    await app.close();
});
```

## 점검 목록

- [ ] 수신·디코딩이 renderer 메인 스레드 밖에 있다
- [ ] 채널마다 손실 정책(병합·전량 보존)이 정해져 있고 병합 건수를 센다
- [ ] 전량 보존 채널은 상한 큐 + `pause`/`resume`, 웹은 서버 송신 상한이 있다
- [ ] 재조립기가 최대 프레임 상한을 헤더 단계에서 검사하고, 오류 후 연결을 끊는다
- [ ] 핫루프에 메시지별 할당(`slice`·객체·문자열·클로저)이 없다
- [ ] renderer 전달은 화면 주기당 한 번, transfer로 넘긴다
- [ ] 가격·수량이 `number` 실수가 아니다. 문자열 변환은 표시 시점에만 한다
- [ ] 그리드는 가상화되어 있고 셀 갱신률 상한이 있다
- [ ] 메모리 추세를 기록하고 1시간 부하에서 평탄함을 확인했다
- [ ] Playwright `_electron` E2E가 IPC 노출 목록과 `sandbox`를 확인한다
