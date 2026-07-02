---
name: redis-patterns
description: Redis 운영 패턴 — key namespace/version, TTL jitter, stampede·negative cache, Lua/MULTI 원자성, distributed lock token, Streams delivery, eviction·persistence·fallback, 큰 JSON blob 제한.
triggers:
  paths: []
  keywords: ["Redis", "TTL", "stampede", "negative cache", "Streams", "분산 lock"]
---

# Redis Patterns — 캐시·락·스트림 운영 기준

Redis는 빠른 저장소가 아니라 **휘발 가능하고 장애 모드가 별도인 외부 시스템**이다. 캐시는
정합성 완화 범위를 먼저 정하고, 락과 스트림은 전달 보장과 중복 처리 계약을 먼저 정한다.

## 언제 활성화하나

- cache-aside, write-through, negative cache를 도입할 때
- distributed lock, rate limit, idempotency token을 Redis에 둘 때
- Redis Streams, Pub/Sub, queue 성격의 처리를 설계할 때
- eviction, persistence, 장애 fallback이 사용자 동작에 영향을 줄 때

## Key Namespace

```text
<app>:<env>:v<schema>:<domain>:<id>[:<field>]
```

- key에는 PII를 넣지 않는다. 이메일·전화번호 대신 내부 ID 또는 hash prefix를 사용한다.
- version은 값 구조가 바뀔 때 올린다. 기존 key를 즉시 삭제하지 않아도 자연 만료되게 한다.
- wildcard 삭제(`KEYS`, broad `SCAN`)가 필요한 설계는 배포 전에 key 범위를 다시 나눈다.

## TTL·Stampede·Negative Cache

- 모든 cache key에는 TTL을 둔다. 영구 key가 필요하면 이유와 owner를 문서화한다.
- 동일 TTL 대량 만료를 피하려고 jitter를 둔다. 예: 기본 300초 + 무작위 0~60초.
- hot key 재계산은 single-flight, short lock, stale-while-revalidate 중 하나로 막는다.
- miss 비용이 큰 조회는 negative cache를 쓸 수 있지만 TTL은 짧게 둔다. 권한·존재 여부가 자주
  바뀌는 데이터는 negative cache 금지 또는 explicit invalidation 필요.

## 원자성 — MULTI·Lua

| 상황 | 기준 |
| --- | --- |
| 단일 key read-modify-write | Lua script 또는 atomic command (`INCR`, `SET NX EX`) |
| 여러 key를 함께 변경 | MULTI/EXEC, 실패 시 재시도 기준 명시 |
| DB row와 Redis를 함께 갱신 | DB commit 후 invalidation 또는 outbox. Redis 성공을 DB transaction 안에 넣지 않는다 |

Lua script는 입력 key와 argv를 명시하고, script body를 코드 리뷰 대상으로 둔다.

## Distributed Lock

- lock value는 고유 token이어야 한다. 해제할 때 token이 일치할 때만 삭제한다.
- lease 시간은 최악 실행 시간보다 길고, 장애 시 자동 해제될 만큼 짧아야 한다.
- lock 획득 실패는 사용자 오류인지 재시도 가능한 상태인지 구분한다.
- 정확성이 반드시 필요한 상호배제는 DB unique constraint나 row lock을 우선 검토한다.

## Pub/Sub vs Streams

| 기능 | 쓰는 경우 | 주의 |
| --- | --- | --- |
| Pub/Sub | 온라인 구독자에게만 즉시 알림 | 구독자가 내려가면 메시지 유실 |
| Streams | consumer group, pending, replay 필요 | 중복 처리와 ack timeout 설계 필요 |

Streams consumer는 메시지 ID, idempotency key, retry 횟수, dead-letter 기준을 기록한다.

## Eviction·Persistence·Pool

- `maxmemory-policy`가 어떤 데이터를 버릴 수 있는지 앱 관점에서 문서화한다.
- cache 전용이면 RDB/AOF persistence를 요구하지 않는다. queue·lock·stream 용도면 재시작 후
  손실 허용 여부를 결정한다.
- pool 크기는 worker 수와 timeout을 합산해 정한다. Redis 장애가 thread/process 고갈로 번지지
  않게 짧은 connect/read timeout을 둔다.
- Redis 장애 시 fallback을 명시한다: fail open, fail closed, stale data, degraded mode 중 하나.

## 큰 JSON Blob 제한

- 큰 JSON blob을 Redis에 넣으면 network I/O, memory fragmentation, eviction 충격이 커진다.
- 100KB 이상이 반복 저장되면 object storage 또는 DB row로 옮기고 Redis에는 key/index만 둔다.
- 부분 조회·검색이 필요해지면 JSON blob 대신 정규화된 저장소를 사용한다.

## 리뷰 체크

- key namespace와 TTL이 문서화됐는가?
- PII가 key·value·log에 노출되지 않는가?
- cache miss·Redis down·eviction 상황의 사용자 동작이 정의됐는가?
- 락은 token 검증으로 해제되는가?
- Streams consumer는 중복 처리와 dead-letter 기준이 있는가?
