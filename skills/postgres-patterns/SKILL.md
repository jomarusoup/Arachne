---
name: postgres-patterns
description: PostgreSQL 설계·운영 기준 — 타입·제약·ON DELETE, composite/partial/covering/GIN/BRIN 인덱스 선택, JSONB vs 정규화, EXPLAIN(ANALYZE, BUFFERS) 증거 기록, pool·timeout 산정, 대량 적재(COPY·unlogged 스테이징·시간 범위 파티셔닝·synchronous_commit), RLS·least privilege. 대상 경로 — **/*.sql. 키워드 — PostgreSQL, 인덱스 선택, EXPLAIN, RLS, 제약, COPY, 파티셔닝, 대량 적재.
---

# PostgreSQL Patterns — 증거 기반 설계 기준

schema·인덱스·운영 파라미터를 데이터 규모와 쿼리 증거로 결정하는 기준.

## 언제 활성화하나

- 테이블·컬럼·제약·인덱스 설계와 리뷰
- JSONB 컬럼 도입 여부 판단
- 느린 쿼리 분석과 인덱스 추가 결정
- 커넥션 풀·timeout 설정
- multi-tenant 데이터 격리 설계
- 대량 적재 경로(`COPY`·스테이징·파티셔닝) 설계

## 핵심 사고

절대 규칙보다 **증거 요구 trigger**로 판단한다. "인덱스를 항상 추가"가 아니라 "이 쿼리의
EXPLAIN이 Seq Scan이고 호출 빈도가 높으면 추가"처럼, 데이터 규모·쿼리 패턴이라는 증거가
설계를 정당화해야 한다. 증거 없는 선제 최적화는 쓰기 비용과 유지보수 부담만 늘린다.

## 타입 기준

| 용도 | 사용 | 금지·주의 |
| --- | --- | --- |
| 시각 | `timestamptz` | `timestamp`(naive) — 변환 사고 |
| 문자열 | `text` + CHECK 길이 | `varchar(n)` 습관적 사용 |
| 금액 | `numeric(p, s)` | `float`/`real` — 손실 |
| ID | `uuid` 또는 `bigint identity` | `serial`(legacy), `int` PK 고갈 |
| 불리언 | `boolean not null default` | nullable boolean 3-state |

## 제약 — DB가 마지막 방어선

- 모든 테이블에 PK. 자연키가 흔들리면 surrogate + unique.
- FK는 명시적 `ON DELETE` 와 함께 — 기본(NO ACTION)을 암묵적으로 두지 않는다.

| ON DELETE | 쓰는 경우 |
| --- | --- |
| `RESTRICT` | 참조가 남아 있으면 삭제 자체가 오류여야 할 때 (기본 권장) |
| `CASCADE` | 자식이 부모 없이는 무의미한 소유 관계만 — 범위 검토 필수 |
| `SET NULL` | 참조가 끊겨도 행 자체는 유효할 때 |

- not-null 기본, nullable은 의미를 주석으로. CHECK로 도메인 제약(양수·enum 범위)을 DB에 내린다.
- 애플리케이션 검증은 UX용, **무결성은 제약이 보장**한다 — 동시 요청은 코드 검사를 뚫는다.

## 인덱스 선택 — 증거 trigger

| 종류 | 트리거 (이 증거가 있을 때) |
| --- | --- |
| 단일 b-tree | WHERE/JOIN/ORDER BY 단일 컬럼, EXPLAIN에 Seq Scan |
| composite | 같은 컬럼 조합 필터 반복 — 등호 컬럼 먼저, 범위 컬럼 뒤 |
| partial | 행 일부만 조회 (`WHERE deleted_at IS NULL` 등 고정 조건) |
| covering (`INCLUDE`) | Index Only Scan으로 hot query의 heap 접근 제거 |
| GIN | JSONB containment·배열·full-text 검색 |
| BRIN | 시계열 append-only 대형 테이블의 범위 스캔 |

- 쓰기 비중이 높은 테이블의 인덱스 추가는 쓰기 비용 증가와 교환 — 사용되지 않는 인덱스는
  `pg_stat_user_indexes`로 주기 점검 후 제거.
- 운영 테이블 인덱스 생성은 `CONCURRENTLY` (스킬 `database-migrations` 참고).

## JSONB vs 정규화

| 신호 | 선택 |
| --- | --- |
| 필드를 WHERE·JOIN·집계에 쓴다 | 정규화된 컬럼·테이블 |
| 키 집합이 행마다 다르고 통째로 읽고 쓴다 | JSONB |
| 외부 시스템 원문 보존 (webhook payload) | JSONB + 추출 컬럼 |
| 제약·FK가 필요한 관계 | 정규화 — JSONB에는 FK가 없다 |

- JSONB 내부 필드에 비즈니스 무결성이 생기기 시작하면 컬럼으로 승격한다.
- 자주 조회하는 JSONB 키는 expression index 또는 generated column으로 노출.

## EXPLAIN — 증거 기록 형식

인덱스·쿼리 변경 PR에는 전후 계획을 증거로 남긴다.

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT ... ;
```

```text
변경 전: Seq Scan on orders (actual time=0.3..412.5 rows=18 loops=1), Buffers: shared read=51200
변경 후: Index Scan using ix_orders_user_id (actual time=0.04..0.6 rows=18), Buffers: shared hit=22
근거 데이터: orders 1,200만 행 / 해당 쿼리 p95 호출 320/min
```

- `ANALYZE` 없는 EXPLAIN은 추정치다 — 실측으로 판단한다.
- 운영 데이터 규모와 다른 개발 DB의 계획은 증거로 쓰지 않는다.

## Pool·Timeout 산정

- pool 크기는 워커 합산으로 계산: `workers × pool_size + 여유 ≤ max_connections`.
- 합산이 초과하면 외부 pooler(PgBouncer)를 검토한다.

| 파라미터 | 기준 |
| --- | --- |
| `statement_timeout` | 엔드포인트 SLA보다 약간 크게 — 무한 쿼리 차단 |
| `lock_timeout` | DDL·운영 작업 전 짧게 (예: 5s) |
| `idle_in_transaction_session_timeout` | 트랜잭션 열고 방치한 세션 회수 |

- timeout은 세션·role 단위로 설정하고, 값과 근거를 설정 파일에 주석으로 남긴다.

## 대량 적재

**행 단위 `INSERT` 루프는 대량 경로가 아니다.** 행마다 왕복·파싱·커밋 비용이 붙는다.
경로는 `COPY` → 스테이징 → 최종 테이블 순서로 설계하고, 처리량은 측정으로 확인한다.

### `COPY` — 텍스트·CSV vs binary

| 형식 | 쓰는 경우 | 주의 |
| --- | --- | --- |
| 텍스트·CSV | 기본 선택, 외부 파일 적재 | 탭·개행·역슬래시 이스케이프, NULL 표기 통일 |
| binary | 생산자가 같은 C 서버이고 파싱 비용까지 줄일 때 | 컬럼 타입이 정확히 일치해야 한다(`int4` ≠ `int8`), 네트워크 바이트 순서, 버전 헤더 |

- C 서버는 libpq `PQputCopyData`·`PQputCopyEnd`로 보낸다. ecpg에는 `COPY FROM STDIN`이 없다(`embedded-sql`).
- 초기 대량 적재는 인덱스·FK를 나중에 만들면 빠르다. 운영 중 적재는 인덱스를 유지하고 배치 크기로 조절한다.
- 적재 후 `ANALYZE`를 실행한다. 통계가 낡으면 다음 쿼리의 계획이 틀린다.

### unlogged 스테이징 → 최종 테이블

```sql
CREATE UNLOGGED TABLE orders_stage (LIKE orders INCLUDING DEFAULTS);

COPY orders_stage (id, cust_id, amt, ord_ts) FROM STDIN (FORMAT binary);   -- libpq 에서 전송

BEGIN;
INSERT INTO orders (id, cust_id, amt, ord_ts)
SELECT id, cust_id, amt, ord_ts FROM orders_stage
ON CONFLICT (id) DO NOTHING;                 -- 재적재에도 멱등
TRUNCATE orders_stage;
COMMIT;
```

- unlogged 테이블은 WAL을 쓰지 않아 빠르다. 대신 **비정상 종료 후 비워지고 스탠바이에 복제되지 않는다.**
  스테이징 전용으로만 쓰고, 최종 데이터는 반드시 일반 테이블로 옮긴다.
- 검증(범위·중복·참조)은 스테이징에서 SQL로 한 번에 하고, 불량 행은 오류 테이블로 분리한다.

### 시간 범위 파티셔닝

```sql
CREATE TABLE ticks (sym text NOT NULL, ts timestamptz NOT NULL, px numeric(18,6) NOT NULL)
PARTITION BY RANGE (ts);
CREATE TABLE ticks_20261005 PARTITION OF ticks
    FOR VALUES FROM ('2026-10-05 00:00+00') TO ('2026-10-06 00:00+00');
```

- 파티션은 미리 만들어 둔다. 범위 밖 행은 오류가 나므로 생성 작업을 스케줄로 돌린다.
- **보존 기간 삭제는 `DELETE`가 아니라 파티션 분리·삭제로 한다.** `ALTER TABLE ... DETACH PARTITION ... CONCURRENTLY` 후 `DROP`.
- 쿼리에 파티션 키 조건이 있어야 프루닝된다. EXPLAIN으로 스캔 파티션 수를 확인한다.
- 파티션 수는 수백 개 수준으로 유지한다. 수천 개를 넘으면 계획 시간이 늘어난다.
- 미리 채운 테이블을 붙일 때는 범위와 같은 `CHECK` 제약을 먼저 걸어 `ATTACH PARTITION`의 전체 검사를 피한다.

### `synchronous_commit` 트레이드오프

| 설정 | 효과 | 쓰는 경우 |
| --- | --- | --- |
| `on`(기본) | 커밋 응답 전 WAL fsync | 원장·결제 등 유실 불가 데이터 |
| `off` | fsync를 기다리지 않음 — 비정상 종료 시 최근 커밋 일부 유실(손상은 없음) | 재생성 가능한 시세·로그 적재 |

- 서버 전체가 아니라 **트랜잭션 단위로** 바꾼다: `SET LOCAL synchronous_commit = off;`
- 유실 범위는 대략 `wal_writer_delay`의 3배 이내다. 유실을 허용한다는 결정을 데이터 손실 정책에 적는다.

### libpq 파이프라인 모드

`COPY`를 쓸 수 없는 행 단위 upsert가 대량이면 libpq 파이프라인 모드(PostgreSQL 14+)를 검토한다.
`PQenterPipelineMode`로 여러 문장을 결과를 기다리지 않고 보내 왕복 대기를 없앤다.
오류가 나면 다음 동기화 지점까지의 문장이 모두 취소되므로, 동기화 단위를 트랜잭션 경계와 맞춘다.

## 보안 — RLS·least privilege (선택)

- 애플리케이션 role은 소유 schema의 DML만 — DDL·superuser 금지.
- migration 전용 role을 분리해 배포 파이프라인만 DDL 권한을 가진다.
- multi-tenant 행 격리가 요구되면 RLS policy를 검토 — 단, 모든 쿼리 경로에서 tenant
  컨텍스트가 설정되는지 테스트로 보장한다. RLS는 코드 필터 누락의 안전망이지 대체재가 아니다.

## 참조

- 규칙: `rules/python/data-handling.md`
- 스킬: `database-migrations`, `backend-patterns`, `json-contracts`, `embedded-sql`(ecpg·COPY 예외 경로), `oracle-patterns`(Oracle 대응)
- 리뷰: 에이전트 `database-reviewer`, 커맨드 `/database-review`
