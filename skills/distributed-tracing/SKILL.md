---
name: distributed-tracing
description: 클라이언트 → C 서버 프로세스 → 워커 → DB 작업까지 한 요청을 따라가는 경량 분산 추적. C 서버는 거래·요청 ID 생성과 전파(전문 고정 필드·IPC 레코드 헤더·스레드 지역 값·DB 세션 정보), 구조화 로그(operational-logging)와 logtrace.sh 조회로 추적하고 OTel C SDK를 강제하지 않는다. TypeScript 클라이언트(웹·Node·Electron)는 OpenTelemetry 기본 설정(traceparent 전파, OTLP 내보내기, Jaeger 로컬 확인)과 거래 ID 연결. 대용량 스트림은 표본 추출(헤드 비율·오류 우선·대표 거래 고정). 대상 경로 — **/*.c, **/*.h, **/*.pc, **/*.pgc, **/*.ts, **/*.tsx, **/logtrace.sh. 키워드 — 분산 추적, 거래 ID, 요청 ID, traceparent, OpenTelemetry, OTLP, Jaeger, 표본 추출, sampling, 추적 전파.
---

# 분산 추적 (경량)

한 요청이 여러 프로세스를 지나갈 때 같은 ID 하나로 모든 구간을 찾을 수 있게 한다.
C 서버는 거래 ID와 구조화 로그로 추적한다.
TypeScript 클라이언트는 OpenTelemetry를 쓰고, 서버로 넘어가는 지점에서 거래 ID를 함께 보낸다.
C 서버에 OpenTelemetry C SDK를 넣으라고 요구하지 않는다.

## 언제 사용하나

- 클라이언트 요청 하나가 게이트웨이, 처리 프로세스, 워커, DB를 거치는 구조를 만들 때
- "이 요청이 어디서 느려졌나"를 로그만으로 답해야 할 때
- TypeScript 클라이언트에 OpenTelemetry를 처음 붙일 때
- 초당 수만 건 스트림에서 추적 비용을 정할 때

### 언제 사용하지 않나

- 로그 한 줄의 형식·레벨·회전 → `operational-logging` 스킬
- 원격 서버에서 로그를 모아 오는 절차 → `remote-linux-analysis` 스킬
- 단일 프로세스 내부의 핫패스 지연 → `latency-critical-systems` 스킬

## 1. 왜 C 서버에 OTel SDK를 강제하지 않나

- OpenTelemetry는 C용 공식 SDK가 없다. C++ SDK를 쓰려면 C++ 런타임과 의존성이 서버에 들어온다.
- 스팬마다 할당과 내보내기 스레드가 생긴다. 초당 수만 건 경로에서는 그 비용이 처리 시간보다 클 수 있다.
- 오프라인 서버는 수집기로 내보낼 곳이 없다. 로그 파일은 어디서나 남는다.

그래서 C 서버의 추적 단위는 **로그 줄**이다.
한 거래의 줄들을 `txn=`으로 모으면 구간별 시각 차이가 곧 스팬 길이다.
수집기가 생기면 이 로그를 수집 단계에서 스팬으로 바꾼다. 서버 코드는 바꾸지 않는다.

## 2. ID 생성 — 들어오는 곳에서 한 번

거래 ID는 요청이 시스템에 처음 들어오는 곳에서 한 번 만든다.
클라이언트가 만들었으면 서버는 그 값을 검증해 그대로 쓴다.

| 항목 | 규칙 |
|---|---|
| 형식 | `<발생지 코드>-<µs 시각>-<일련번호>` 예: `G01-1728104602123456-000042`, 또는 UUIDv7 |
| 문자 | 영문·숫자·`._:-`만. 길이는 64자 이하 |
| 내용 | 고객 번호·계좌 같은 개인정보를 넣지 않는다 |
| 검증 | 받은 값이 규칙에 맞지 않으면 버리고 새로 만든다. 새로 만든 사실을 WARN으로 남긴다 |

정렬되는 형식을 쓰면 `logtrace.sh` 결과와 DB 조회 결과를 시각 순서로 맞춰 보기 쉽다.

## 3. 전파 — 모든 경계에서 같은 ID

```text
클라이언트 ──(X-Request-Id 헤더 / 전문 공통부 txn 필드)──▶ 게이트웨이 프로세스
게이트웨이 ──(IPC 메시지·공유메모리 큐 레코드 헤더의 고정 필드)──▶ 처리 프로세스
처리 프로세스 ──(작업 구조체의 txn_id 필드)──▶ 워커 스레드
워커 스레드 ──(로그 txn= · DB 세션 정보)──▶ DB 작업
```

| 경계 | 방법 |
|---|---|
| 클라이언트 → 서버 | HTTP는 `X-Request-Id`와 `traceparent`. 바이너리 전문은 공통부의 고정 길이 `txn_id` 필드 |
| 프로세스 간 | IPC 메시지·큐 레코드 헤더에 `char txn_id[64]`. 레이아웃은 계약으로 고정한다(`api-contracts`) |
| 스레드 | 작업을 꺼낸 스레드가 `LogSetTxnId()`, 끝나면 `LogClearTxnId()` |
| DB | 로그에 같은 ID를 남긴다. 필요하면 Oracle `DBMS_APPLICATION_INFO.SET_CLIENT_INFO`, PostgreSQL `application_name` |
| 응답 | 오류 응답 본문과 헤더에 거래 ID만 돌려준다. 사용자 문의 때 이 값으로 찾는다 |

C 워커에서는 작업을 꺼낼 때 ID를 정하고, 끝날 때 반드시 지운다.
지우지 않으면 다음 작업의 로그에 이전 ID가 붙는다.

```c
/*---------------------------------------------------------------------------
 작업 하나를 처리하는 동안만 거래 ID 를 스레드 지역 값으로 둔다
---------------------------------------------------------------------------*/
static void HandleJob(const job_t *job)
{
    LogSetTxnId(job->txn_id);
    LOG_INFO("job start kind=%d", job->kind);
    ProcessOrder(job);                 /* 이 안의 모든 LOG_* 에 txn= 이 붙는다 */
    LOG_INFO("job done");
    LogClearTxnId();
}
```

다른 스레드나 프로세스로 넘길 때는 스레드 지역 값이 따라가지 않는다.
작업 데이터에 ID를 복사해 넘기고, 받은 쪽에서 다시 `LogSetTxnId()`를 부른다.

## 4. 구간 시각 — 로그로 스팬 만들기

구간의 시작과 끝을 로그 줄로 남기면 스팬과 같은 정보가 된다.

```text
ts=...000100 proc=gw    lvl=INFO txn=G01-...-000042 msg=recv bytes=512
ts=...000180 proc=order lvl=INFO txn=G01-...-000042 msg=job start kind=1
ts=...004950 proc=order lvl=INFO txn=G01-...-000042 msg=db done stmt=ORD_INS_01 elapsed_us=4700
ts=...005010 proc=gw    lvl=INFO txn=G01-...-000042 msg=reply status=0
```

- 외부 호출(DB·다른 서버)은 끝 줄에 `elapsed_us=`를 남긴다. 시계가 다른 서버끼리도 구간 길이는 정확하다.
- 서버 시계는 NTP(chrony)로 맞춘다. `logtrace.sh`는 `ts` 문자열 순서로 정렬한다.

조회는 `logtrace.sh` 하나로 한다.

```bash
tools/logtrace.sh G01-1728104602123456-000042 /var/log/app/
tools/logtrace.sh -l WARN G01-1728104602123456-000042 gw.log order.log
```

운영 서버의 로그 조회는 읽기 전용이라 허용된다. 오프라인 서버는 `collect.sh`로 로그 꼬리를 회수해 로컬에서 같은 명령을 돌린다.

## 5. TypeScript 클라이언트 — OpenTelemetry 기본

클라이언트(웹·Node·Electron)는 OpenTelemetry로 스팬을 만든다.
서버로 나가는 요청에는 `traceparent`와 거래 ID를 함께 실어, 서버 로그와 클라이언트 스팬을 같은 ID로 잇는다.

### 5.1 Node(Electron 메인 프로세스 포함)

```ts
/*===========================================================================
 FUNCTION    : StartTracing
 DESCRIPTION : Node SDK 를 시작한다. 수집기 주소는 환경 설정에서 받는다.
===========================================================================*/
import { NodeSDK } from "@opentelemetry/sdk-node";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { TraceIdRatioBasedSampler, ParentBasedSampler } from "@opentelemetry/sdk-trace-base";

export function StartTracing(serviceName: string, collectorUrl: string, ratio: number): NodeSDK {
    const sdk = new NodeSDK({
        serviceName,
        traceExporter: new OTLPTraceExporter({ url: `${collectorUrl}/v1/traces` }),
        sampler: new ParentBasedSampler({ root: new TraceIdRatioBasedSampler(ratio) }),
        instrumentations: [getNodeAutoInstrumentations()],
    });
    sdk.start();
    return sdk;
}
```

### 5.2 웹 브라우저

```ts
import { WebTracerProvider, BatchSpanProcessor } from "@opentelemetry/sdk-trace-web";
import { OTLPTraceExporter } from "@opentelemetry/exporter-trace-otlp-http";
import { registerInstrumentations } from "@opentelemetry/instrumentation";
import { FetchInstrumentation } from "@opentelemetry/instrumentation-fetch";

const provider = new WebTracerProvider({
    spanProcessors: [new BatchSpanProcessor(new OTLPTraceExporter({ url: "/otel/v1/traces" }))],
});
provider.register();
registerInstrumentations({
    instrumentations: [new FetchInstrumentation({ propagateTraceHeaderCorsUrls: [/\/api\//] })],
});
```

- 브라우저는 수집기로 직접 보내지 않고 같은 출처의 프록시 경로(`/otel/...`)로 보낸다. CORS와 수집기 노출을 피한다.
- `propagateTraceHeaderCorsUrls`는 우리 API로만 한정한다. 외부 도메인에 `traceparent`를 보내지 않는다.
- 스팬 속성에 입력값·토큰·개인정보를 넣지 않는다. URL의 쿼리 문자열도 지운다(`sensitive-data-handling`).

### 5.3 거래 ID 연결

```ts
// 요청마다 거래 ID 를 만들어 헤더와 현재 스팬 속성에 함께 넣는다
import { trace } from "@opentelemetry/api";

export async function CallApi(path: string, body: unknown, txnId: string): Promise<Response> {
    trace.getActiveSpan()?.setAttribute("app.txn_id", txnId);
    return fetch(path, {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Request-Id": txnId },
        body: JSON.stringify(body),
    });
}
```

C 서버가 `traceparent`를 직접 해석하지 않아도 된다.
게이트웨이가 받은 `traceparent`의 trace-id를 로그에 `trace=` 필드로 한 번 남기면, Jaeger의 클라이언트 스팬에서 서버 로그로 건너갈 수 있다.

### 5.4 로컬 확인 — Jaeger

`templates/project/compose-3tier`의 `tracing` 프로필이 Jaeger를 띄운다.
Node·Electron은 `http://127.0.0.1:4318`로 보내고, UI(`http://127.0.0.1:16686`)에서 서비스 이름으로 찾는다.

## 6. 대용량 스트림의 표본 추출

초당 수만 건 스트림의 모든 메시지를 추적하지 않는다.
추적 비용이 처리 비용을 넘기 때문이다.

| 방법 | 규칙 | 쓰는 곳 |
|---|---|---|
| 헤드 비율 | 거래 ID 해시의 끝자리로 고른다(예: `hash % 1000 == 0`이면 0.1%). 같은 ID는 모든 프로세스에서 같은 판정을 받는다 | 시세·체결 스트림의 INFO 구간 로그 |
| 오류 우선 | WARN 이상은 표본과 무관하게 모두 남긴다 | 모든 경로 |
| 대표 거래 고정 | 운영자가 지정한 ID 접두(예: `T99-`)는 항상 추적한다 | 장애 재현·점검용 합성 거래 |
| 느린 거래 | 끝 시점에 `elapsed_us`가 기준을 넘으면 그 거래의 요약 줄을 WARN으로 남긴다 | 지연 꼬리 분석 |

- 표본 판정은 ID에서 결정적으로 계산한다. 난수로 고르면 프로세스마다 다른 거래가 남아 이어 볼 수 없다.
- 표본 비율은 설정 파일 값으로 두고, SIGHUP 재적재로 바꿀 수 있게 한다.
- OpenTelemetry 쪽도 `ParentBasedSampler`로 상위 판정을 따른다. 클라이언트와 서버의 비율을 같은 설정에서 정한다.

## 체크리스트

- [ ] 거래 ID는 들어오는 곳에서 한 번 만들고, 형식이 맞지 않는 값은 버린다
- [ ] 프로세스·스레드·DB 경계마다 같은 ID를 넘기고, 워커는 작업이 끝나면 ID를 지운다
- [ ] 외부 호출 끝 줄에 `elapsed_us`가 있다
- [ ] C 서버에 OTel SDK를 넣지 않고, 클라이언트 스팬과는 `X-Request-Id`·`trace=`로 잇는다
- [ ] 스팬 속성과 로그에 개인정보·토큰이 없다
- [ ] 대용량 경로는 ID 기반 결정적 표본 추출을 쓰고, 오류는 모두 남긴다
