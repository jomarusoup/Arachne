---
Title: "데이터 분류·처리 기준"
creation: 2026-06-11
modification: 2026-06-11
tags:
 - "arachne"
 - "database"
 - "json"
 - "security"
aliases:
 - "arachne-data-handling"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-09-data-handling-hardening]]

# 데이터 분류·처리 기준

DB·JSON 데이터를 다루는 프로젝트가 따르는 **분류표와 운영 기준의 정본**.
항상 적용되는 짧은 경계 규칙은 `rules/python/data-handling.md`, 상세 패턴은
스킬 `json-contracts` · `database-migrations` · `postgres-patterns` · `redis-patterns`,
독립 검토는 `agents/database-reviewer.md`(`/database-review`)가 담당한다.

## 데이터 분류표

| 등급 | 정의 | 예시 | 저장 |
| --- | --- | --- | --- |
| **public** | 외부 공개돼도 무해 | 게시글 제목, 공개 프로필명 | 평문 |
| **internal** | 비공개지만 개인 식별 불가 | 내부 ID, 집계 수치, 상태 코드 | 평문 |
| **PII** | 개인 식별 가능 정보 | 이메일, 전화번호, 실명, 주소, IP | 평문 또는 field-level encryption |
| **secret** | 인증·암호 자료 | 비밀번호, API 키, 토큰, 세션 ID | 해시 또는 시크릿 매니저 |

프로젝트는 자기 schema의 필드를 이 4등급으로 분류해 모델 정의 옆(주석 또는 별도 표)에 기록한다.
분류가 없는 신규 필드는 `/database-review`에서 HIGH로 보고된다.

## 노출 표면별 허용 등급

| 표면 | public | internal | PII | secret |
| --- | --- | --- | --- | --- |
| API 응답 | ✅ | ✅ (인가된 사용자) | ⚠️ 소유자·인가 범위만 | ❌ 절대 금지 |
| 로그 | ✅ | ✅ | ❌ 마스킹 필수 | ❌ 절대 금지 |
| metric·trace | ✅ | ✅ (집계만) | ❌ 라벨 사용 금지 | ❌ 절대 금지 |
| cache | ✅ | ✅ | ⚠️ TTL 명시 + key에 미포함 | ❌ 절대 금지 |
| 테스트 fixture | ✅ | ✅ 합성값 | ❌ 합성 데이터만 | ❌ 더미 placeholder만 |

- **응답** — raw ORM 객체 직렬화 금지, `response_model`(출력 스키마)로 허용 필드를 명시한다.
- **로그** — PII는 마스킹(`u***@example.com`) 또는 내부 ID로 대체한다. 예외 스택트레이스에
  요청 본문을 통째로 남기지 않는다.
- **cache** — cache key에 PII를 넣지 않는다 (key는 로그·모니터링에 노출된다).

## 암호화 경계 — hashing vs encryption

| 질문 | 답 | 적용 |
| --- | --- | --- |
| 원문 복원이 필요한가? | 아니오 | **hashing** (argon2id 권장, bcrypt 허용) — 비밀번호 |
| 원문 복원이 필요한가? | 예 | **field-level encryption** — 주민번호·계좌 등 표시해야 하는 PII |
| 전송 구간인가? | — | TLS (필드 암호화의 대체재 아님) |

비밀번호를 암호화(복호 가능)하거나 PII를 해싱(복원 불가)하는 혼동이 흔한 결함이다.
경계를 바꾸는 변경은 `/database-review` security 단계에서 CRITICAL로 본다.

## 보존·삭제·감사

- **retention** — PII 필드는 보존 기한을 schema 기록에 명시한다. "무기한"도 명시적 결정이다.
- **삭제** — 사용자 삭제 요청 시 PII는 hard delete 또는 비가역 익명화. soft delete 플래그만으로
  PII를 남기지 않는다.
- **backup 잔존** — 삭제된 PII는 backup에 retention 기간만큼 남는다. 삭제 절차 문서에
  backup 만료 시점을 함께 기록한다.
- **audit trail** — PII 접근·수정은 누가·언제·무엇을 단위로 기록하되, audit 로그 자체에
  PII 원문을 복사하지 않는다 (필드명·레코드 ID만).

## 테스트 fixture 기준

- 실제 개인정보 복사 금지 — 합성 데이터만 사용 (`user1@example.com`, `010-0000-0000`).
- 운영 DB dump를 fixture로 쓰지 않는다. 필요하면 익명화 파이프라인을 거친 데이터만.
- secret은 명백한 placeholder만 (`test-password`, `dummy-token`) — 실제 형식과 우연히
  일치하는 키 패턴(`sk-...`, `ghp_...`)도 금지 (시크릿 스캐너 오탐·실탐 모두 방지).

## Quality Gate — 검증 자산

데이터 계약 회귀는 `tests/fixtures/python-db/` 기준 프로젝트와 `tests/data_contract.bats`가 막는다.

| 게이트 | 검증 내용 | 실패 조건 |
| --- | --- | --- |
| migration | 빈 DB → `alembic upgrade head` 성공 | revision 체인 손상, head 분기 |
| migration | 이전 revision DB → head 성공 | 배포 revision 수정, 비호환 변경 |
| transaction | 실패한 service operation → rollback | 부분 커밋 잔존 row |
| idempotency | 동일 idempotency key 재시도 | 중복 row 발생 |
| schema 계약 | JSON schema snapshot 비교 | breaking change (필드 제거·타입 변경) |
| PII | 응답·로그 직렬화 검사 | PII·secret 필드 노출 |

- bats는 fixture의 **정적 계약**(파일 구조·revision 체인·snapshot 존재)을 모든 CI 플랫폼에서
  검사하고, **실행 검증**(alembic·pytest)은 `uv`가 있는 환경에서만 수행한다 (없으면 skip).
- snapshot 갱신은 의도적 변경일 때만: `uv run pytest --snapshot-update` 후 diff를 리뷰에 포함.

## 프로젝트 연결 — 선택적 DB 게이트

DB를 쓰는 프로젝트는 `.arachne/commands`(python profile)에 DB 게이트를 추가한다.
DB 없는 프로젝트는 기존 profile을 그대로 사용한다 — 추가 service 불필요.

```bash
# .arachne/commands 에 추가 (SQLite 기반 — 별도 service 불필요)
uv run alembic upgrade head
uv run pytest tests/data_contract/
```

### PostgreSQL service가 필요한 검증 (opt-in)

PostgreSQL 고유 기능(CONCURRENTLY, JSONB 인덱스, RLS) 검증은 기본 workflow에 넣지 않고,
필요한 프로젝트만 `.github/workflows/arachne.yml`의 job에 service를 추가한다.

```yaml
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready --health-interval 5s
          --health-timeout 5s --health-retries 5
```

`DATABASE_URL=postgresql+psycopg://postgres:postgres@localhost:5432/postgres`를
검증 명령 환경변수로 주입한다. SQLite로 검증 가능한 게이트는 SQLite를 유지한다 (빠르고 이식성 높음).

## Redis 운영 기준

Redis를 cache, lock, stream에 쓰는 프로젝트는 스킬 `redis-patterns`를 기준으로 다음 항목을
설계 문서나 코드 주석에 남긴다.

| 영역 | 필수 결정 |
| --- | --- |
| namespace | `<app>:<env>:v<schema>:<domain>:<id>` 형태, key에 PII 금지 |
| TTL | 모든 cache key TTL, jitter, hot key stampede 방지 방식 |
| negative cache | 짧은 TTL, 권한·존재 변경 데이터의 invalidation |
| 원자성 | `SET NX EX`, Lua, MULTI/EXEC 중 선택과 재시도 기준 |
| lock | 고유 token, token 일치 삭제, lease 만료, 획득 실패 의미 |
| Streams | idempotency key, ack timeout, retry, dead-letter 기준 |
| 장애 | fail open/closed, stale data, degraded mode 중 하나 |
| 큰 JSON blob | 100KB 이상 반복 저장 시 object storage 또는 DB row 전환 |

Redis 작업은 DB transaction 안에 넣지 않는다. DB commit 후 invalidation 또는 outbox로 연결한다.

## Backup·Restore·관측

운영 DB 프로젝트는 backup 성공이 아니라 **restore 성공**을 검증 기준으로 둔다.

| 항목 | 기준 |
| --- | --- |
| restore drill | 정기적으로 별도 DB에 복원하고 애플리케이션 smoke test를 실행 |
| RPO/RTO | 허용 데이터 손실 시간(RPO)과 복구 시간(RTO)을 프로젝트 결정으로 기록 |
| PITR | point-in-time recovery 사용 여부, WAL 보존 기간, 복구 절차 |
| migration 전 snapshot | irreversible 또는 대량 backfill 전 snapshot/rollback 계획 |
| slow query | p95/p99 latency, `EXPLAIN (ANALYZE, BUFFERS)` 증거 링크 |
| pool exhaustion | pool 사용률, wait time, timeout, worker 합산 |
| deadlock | deadlock count, lock wait, lock ordering 위반 사례 |
| replication lag | read replica 사용 시 lag와 stale read 허용 범위 |
| 데이터 품질 | row count drift, orphan row, enum 범위, null 비율, 중복률 |
| silent corruption | checksum/hash 샘플링, reconciliation job, 감사 쿼리 |

복구 절차와 관측 지표는 실제 운영 프로젝트에서 구체 값을 정한다. Arachne 기본 profile은 DB 없는
프로젝트에 backup 인프라나 PostgreSQL service를 강제하지 않는다.

## 참조

- 경계 규칙(자동 로드): `rules/python/data-handling.md`
- 직렬화 계약: 스킬 `json-contracts` / migration: `database-migrations` / schema·인덱스: `postgres-patterns` / Redis: `redis-patterns`
- 독립 리뷰: `agents/database-reviewer.md` · `/database-review`
- 추진 경위: [[2026-06-09-data-handling-hardening]], [[2026-06-09-ecc-data-handling-gap]]
