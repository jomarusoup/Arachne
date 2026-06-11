---
Title: "[task] DB·JSON 데이터 처리 하드닝"
creation: 2026-06-09
modification: 2026-06-09
tags:
 - "arachne"
 - "task"
 - "database"
 - "json"
 - "priority/high"
aliases:
 - "data-handling-hardening"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-09-ecc-data-handling-gap]]

# [task] DB·JSON 데이터 처리 하드닝

- **상태**: in-progress (P0 자산 작성·인덱스 연결 완료)
- **우선순위**: high
- **담당**: unassigned
- **관련 문서**: [[2026-06-09-ecc-data-handling-gap]], [[0001-python-web-profile]]

## 목표

Python/Web profile에 DB·JSON 데이터 처리의 명시적 계약과 독립 검토 경로를 추가한다. 단순 CRUD를
넘어 migration, transaction, PostgreSQL, JSON 호환성, 개인정보, Redis를 위험도에 따라 검증하고,
로컬과 GitHub CI에서 같은 품질 게이트를 실행할 수 있게 한다.

## 영향도와 실행 순서

| 단계 | 영향도 | 작업 묶음 | 선행 조건 |
| --- | --- | --- | --- |
| P0 | critical | JSON wire contract와 민감 데이터 기준 | 없음 |
| P0 | critical | SQLAlchemy transaction/session과 migration 안전성 | 없음 |
| P0 | high | PostgreSQL schema·constraint·index 기준 | DB 기준 |
| P1 | high | database reviewer와 review command | P0 rules/skills |
| P1 | high | DB fixture와 migration/OpenAPI CI gate | P0 계약 |
| P2 | medium | Redis 운영 패턴 | 캐시 사용 프로젝트 |
| P2 | medium | backup/restore와 데이터 관측 | 실제 운영 프로젝트 |

```mermaid
gantt
    title DB·JSON 데이터 처리 하드닝 순서
    dateFormat  YYYY-MM-DD
    axisFormat  %m-%d

    section Contract
    JSON wire·PII 계약              :p0a, 2026-06-10, 2d
    SQLAlchemy session·transaction   :p0b, 2026-06-10, 2d
    Migration·PostgreSQL             :p0c, after p0b, 3d

    section Execution
    Database reviewer·command        :p1a, after p0a, 2d
    DB/OpenAPI quality gate          :p1b, after p0c, 3d

    section Optional
    Redis production patterns        :p2a, after p1b, 2d
    Backup·restore·observability      :p2b, after p1b, 3d
```

## 범위

- 포함:
  - Python JSON 직렬화와 API schema 호환 계약
  - SQLAlchemy 2.x async session/transaction 규칙
  - Alembic migration과 대용량 backfill 안전성
  - PostgreSQL schema, constraint, index, RLS, timeout 기준
  - DB 전문 reviewer와 review command
  - Python profile의 선택적 DB·contract 검증 방법
  - PII 분류·로그·응답·캐시·retention 기준
  - Redis 사용 시 원자성·TTL·장애 처리 기준
- 제외:
  - 특정 클라우드 DB나 Supabase 강제
  - 사용자 프로젝트의 실제 schema 작성
  - 모든 프로젝트에 PostgreSQL/Redis service 자동 추가
  - 운영 backup 인프라 자체 구축
  - ECC 자산의 무검토 복사

## Phase 0: 데이터 계약

### 0-1. JSON wire contract

- [ ] `rules/python/data-handling.md`에 항상 필요한 짧은 경계 규칙을 작성한다.
- [ ] `skills/json-contracts.md`에 Pydantic v2와 TypeScript 간 직렬화 계약을 작성한다.
- [ ] datetime은 timezone-aware RFC 3339, 금액은 `Decimal` 손실 방지 형식을 결정한다.
- [ ] UUID, enum, bytes, large integer, missing/null, PATCH semantics를 명시한다.
- [ ] unknown field, 최대 payload, 중첩 깊이, duplicate key 처리 정책을 명시한다.
- [ ] schema version과 backward-compatible 변경 기준을 정의한다.
- [ ] OpenAPI schema snapshot 또는 breaking-change 검출 도구를 선정한다.

### 0-2. 개인정보와 민감 데이터

- [ ] public/internal/PII/secret 데이터 분류표를 만든다.
- [ ] 응답·로그·metric·cache별 허용 필드를 정의한다.
- [ ] field-level encryption과 password hashing의 적용 경계를 구분한다.
- [ ] retention, deletion, backup 잔존, audit trail 기준을 작성한다.
- [ ] 테스트 fixture가 실제 개인정보를 포함하지 않도록 검사 기준을 둔다.

## Phase 1: DB 정확성과 Migration

### 1-1. SQLAlchemy 2.x

- [ ] 요청·worker 단위 async session 수명주기를 규칙으로 고정한다.
- [ ] commit/rollback 책임을 service/use-case 경계 한 곳에 둔다.
- [ ] transaction 안에서 외부 네트워크 I/O를 금지한다.
- [ ] nested transaction, savepoint, retry 가능한 DB 오류 기준을 정한다.
- [ ] idempotency key와 unique constraint의 역할을 문서화한다.
- [ ] lazy loading과 N+1, eager loading 선택 기준을 작성한다.

### 1-2. Alembic migration

- [ ] `skills/database-migrations.md`를 Arachne 구조로 작성한다.
- [ ] schema와 data migration을 분리한다.
- [ ] expand-contract, concurrent index, batch backfill을 포함한다.
- [ ] 배포된 revision 수정 금지와 forward-fix 원칙을 명시한다.
- [ ] lock timeout, 예상 실행 시간, irreversible 표시, 복구 계획을 요구한다.
- [ ] empty DB upgrade와 기존 DB upgrade를 모두 테스트한다.

### 1-3. PostgreSQL

- [ ] `skills/postgres-patterns.md`를 선별 작성한다.
- [ ] type, PK, FK, unique, check, not-null, `ON DELETE` 기준을 정의한다.
- [ ] composite/partial/covering/GIN/BRIN index 선택 기준을 작성한다.
- [ ] JSONB와 정규화된 column/table 선택 기준을 명시한다.
- [ ] `EXPLAIN (ANALYZE, BUFFERS)` 사용 조건과 증거 기록 형식을 정한다.
- [ ] pool, statement/lock/idle transaction timeout과 worker 합산 기준을 작성한다.
- [ ] multi-tenant RLS와 least privilege를 선택 보안 규칙으로 둔다.
- [ ] ECC의 절대 규칙은 데이터 규모와 쿼리 증거를 요구하는 trigger로 완화한다.

## Phase 2: 실행 경로

### 2-1. 전문 Reviewer와 Command

- [ ] `agents/database-reviewer.md`를 read-first 전문 reviewer로 추가한다.
- [ ] migration, SQL, ORM model, repository 변경 시 활성화 조건을 정의한다.
- [ ] `/database-review` command로 schema→query→migration→security→test 순서를 고정한다.
- [ ] CRITICAL/HIGH/MEDIUM severity와 파일·line 근거 형식을 기존 reviewer와 맞춘다.
- [ ] ECC provenance와 가져온 원칙의 출처를 기록한다.

### 2-2. Quality Gate

- [ ] Python DB project fixture를 테스트 자산으로 만든다.
- [ ] `alembic upgrade head`를 빈 DB와 기존 revision DB에서 실행한다.
- [ ] migration downgrade 대신 forward recovery가 필요한 경우를 표시한다.
- [ ] transaction rollback, unique/idempotency, concurrency 회귀 테스트를 추가한다.
- [ ] OpenAPI/JSON schema snapshot과 breaking-change 검사를 추가한다.
- [ ] `pip-audit` 외에 SQL/migration/data contract 검증을 profile에 선택적으로 연결한다.
- [ ] PostgreSQL service가 필요한 검증은 opt-in 확장 workflow로 분리한다.

## Phase 3: 선택 운영 Pack

### 3-1. Redis

- [ ] `skills/redis-patterns.md`를 실제 사용 프로젝트가 생길 때 추가한다.
- [ ] namespace/version, TTL jitter, stampede, negative cache를 정의한다.
- [ ] MULTI/Lua, distributed lock token, Streams delivery 계약을 작성한다.
- [ ] eviction, persistence, pool, timeout, 장애 fallback을 정의한다.
- [ ] 큰 JSON blob 저장 제한과 object storage 전환 기준을 둔다.

### 3-2. Backup·Restore·관측

- [ ] backup 성공이 아니라 restore 성공을 검증하는 절차를 작성한다.
- [ ] RPO/RTO, PITR, migration 전 snapshot 기준을 프로젝트 결정으로 둔다.
- [ ] slow query, pool exhaustion, deadlock, replication lag 지표를 정의한다.
- [ ] 데이터 품질 지표와 silent corruption 탐지 방법을 정한다.

## 예상 산출물

```text
rules/python/data-handling.md
skills/json-contracts.md
skills/database-migrations.md
skills/postgres-patterns.md
agents/database-reviewer.md
commands/database-review.md
tests/data_contract*.bats
tests/fixtures/python-db/
docs/DATA-HANDLING.md
```

Redis는 실제 사용이 결정되기 전까지 예상 산출물에서 제외하고 Phase 3 선택 항목으로 유지한다.

## 검증

```bash
bash -n install.sh templates/project/verify.sh
shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh templates/project/verify.sh
bats tests/*.bats
bash tests/validate_settings.sh
bash tests/check_index.sh
bash tests/check_convention_sync.sh
arachne project-check tests/fixtures/python-db
```

DB fixture 검증에는 별도로 다음 결과가 필요하다.

```text
empty database -> migration head 성공
previous revision -> migration head 성공
실패한 service operation -> rollback 확인
동일 idempotency key -> 중복 row 없음
OpenAPI schema breaking change -> gate 실패
PII field response/log/cache 포함 -> gate 실패
```

## 완료 조건

- JSON 날짜·금액·null·PATCH·schema evolution 계약이 Python과 TypeScript 예제로 검증된다.
- SQLAlchemy session·transaction·idempotency 기준이 rule과 test에 반영된다.
- Alembic migration이 빈 DB와 기존 DB에서 자동 검증된다.
- PostgreSQL schema·index·security 변경을 database reviewer가 독립 검토한다.
- 민감 필드는 응답·로그·캐시에 기본 노출되지 않는다.
- DB 없는 Python 프로젝트는 추가 service 없이 기존 profile을 계속 사용할 수 있다.
- 신규 자산이 skills/agents/commands/USAGE 인덱스와 GitHub CI에 연결된다.

## 진행 기록

### 2026-06-11

- P0 산출물 5종(`rules/python/data-handling.md`, `skills/{json-contracts,database-migrations,postgres-patterns}.md`,
  `agents/database-reviewer.md`)을 커밋하고 skills/agents/rules 인덱스와 USAGE·CLAUDE.md에 연결했다
  (아키텍처 감사 A-02). `docs/DATA-HANDLING.md`·`/database-review` command·CI gate는 미착수.

### 2026-06-09

- ECC revision `e3a25791f8a2`와 Arachne의 DB·JSON 자산을 비교했다.
- ECC의 장점은 전문 reviewer와 migration/PostgreSQL/Redis 책임 분리로 확인했다.
- JSON 계약은 ECC도 독립 정본이 약하므로 Arachne가 별도 skill로 보강하기로 계획했다.
- 전체 복사 대신 P0 데이터 계약·migration부터 구현하고 Redis는 실제 사용 시 선택 도입하기로 했다.
