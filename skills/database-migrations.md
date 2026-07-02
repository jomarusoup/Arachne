---
name: database-migrations
description: Alembic migration 안전 운영 — schema/data revision 분리, expand-contract, CONCURRENTLY 인덱스, batch backfill, 배포 revision 불변·forward-fix, lock timeout, 빈 DB·기존 DB 이중 검증.
triggers:
  paths: ["**/alembic/**", "**/migrations/**"]
  keywords: ["migration", "Alembic", "스키마 변경", "backfill", "expand-contract"]
---

# Database Migrations — Alembic 안전 운영

운영 DB를 멈추지 않고 schema를 진화시키는 migration 작성·검증 절차.

## 언제 활성화하나

- Alembic revision 작성·리뷰
- 컬럼 추가·제거·타입 변경, 인덱스·제약 추가
- 대량 데이터 backfill·이관
- migration 실패·복구 계획 수립
- CI에 migration 검증 추가

## 핵심 사고

migration은 **한 번 배포되면 수정할 수 없는 불변 이력**이다. 잘못된 revision은 고치는 것이 아니라
**forward-fix revision을 추가**한다. 모든 DDL은 락을 잡는다 — 락 보유 시간을 설계하는 것이 곧
무중단 migration 설계다.

## Schema와 Data revision 분리

| 종류 | 내용 | 실행 특성 |
| --- | --- | --- |
| schema migration | DDL — 테이블·컬럼·인덱스·제약 | 짧게, 트랜잭션 안에서 |
| data migration | DML — backfill·변환 | 길게, batch로, 재시도 가능하게 |

- 한 revision에 DDL과 대량 DML을 섞지 않는다 — 실패 시 복구 지점이 사라진다.
- data migration은 **멱등하게** 작성 — 중단 후 재실행해도 안전해야 한다.

## Expand-Contract — 무중단 변경 절차

컬럼 이름 변경·타입 변경은 단일 ALTER가 아니라 3단계로 나눈다.

```text
1. expand   : 새 컬럼 추가 (nullable·default) + 양쪽 쓰기 (dual write)
2. migrate  : batch backfill로 기존 행 채움 + 읽기 경로 전환
3. contract : 구 컬럼 쓰기 제거 → 다음 배포에서 컬럼 drop
```

- 각 단계는 **독립 배포** — 한 배포에 expand와 contract를 함께 넣지 않는다.
- 롤백 대상은 코드 배포지 schema가 아니다 — 구 코드가 새 schema에서 동작하는지 확인.

## 인덱스 — CONCURRENTLY

```python
def upgrade() -> None:
    # CONCURRENTLY는 트랜잭션 밖에서만 동작
    with op.get_context().autocommit_block():
        op.create_index(
            "ix_orders_user_id",
            "orders",
            ["user_id"],
            postgresql_concurrently=True,
        )
```

- 운영 테이블 인덱스는 `CONCURRENTLY` 기본 — 일반 CREATE INDEX는 쓰기를 블로킹한다.
- 실패 시 INVALID 인덱스가 남는다 — drop 후 재생성하는 복구 절차를 주석으로 남긴다.

## Batch backfill

```python
BATCH_SIZE = 5000

def upgrade() -> None:
    conn = op.get_bind()
    while True:
        result = conn.execute(
            sa.text(
                "UPDATE orders SET status_v2 = status "
                "WHERE id IN (SELECT id FROM orders WHERE status_v2 IS NULL LIMIT :n)"
            ),
            {"n": BATCH_SIZE},
        )
        if result.rowcount == 0:
            break
```

- 전체 테이블 단일 UPDATE 금지 — 장시간 락·WAL 폭증·replica lag.
- batch 사이 커밋으로 락을 풀고, 진행률을 로그로 남긴다.

## 배포 revision 불변·forward-fix

- 배포된 revision 파일 수정 금지 — 환경마다 다른 schema가 생긴다.
- 결함은 새 revision으로 고친다. downgrade는 로컬 개발 편의일 뿐 운영 복구 수단이 아니다.
- 되돌릴 수 없는 migration(컬럼 drop, 데이터 파괴)은 docstring에 `IRREVERSIBLE`을 명시하고
  사전 snapshot 등 복구 계획을 함께 적는다.

## Lock timeout·실행 시간

```python
def upgrade() -> None:
    op.execute("SET lock_timeout = '5s'")        # 락 대기로 서비스 정지 방지
    op.execute("SET statement_timeout = '60s'")  # 예상 밖 장기 실행 차단
```

- DDL 전 lock_timeout 설정 — 락을 못 잡으면 migration이 실패하는 쪽이 안전하다.
- revision 주석에 예상 실행 시간과 근거(행 수·인덱스 크기)를 남긴다.

## 검증 — 빈 DB와 기존 DB 모두

```bash
# 1. 빈 DB에서 전체 이력 적용
alembic upgrade head

# 2. 직전 배포 시점 DB에서 신규 revision만 적용
alembic downgrade -1 && alembic upgrade head   # 로컬 검증용

# 3. 모델과 schema 드리프트 검사
alembic check   # autogenerate 차이가 있으면 실패
```

- 빈 DB 성공만 믿지 않는다 — 운영은 항상 "기존 revision → head" 경로다.
- 같은 branch에 revision이 두 갈래면 merge revision으로 정리한다.

## 체크리스트

- [ ] schema와 data revision 분리
- [ ] 운영 테이블 인덱스 CONCURRENTLY
- [ ] backfill batch·멱등·재시도 가능
- [ ] lock_timeout·statement_timeout 설정
- [ ] IRREVERSIBLE 표시와 복구 계획
- [ ] 빈 DB·기존 DB 양쪽 upgrade 검증

## 참조

- 규칙: `rules/python/data-handling.md`
- 스킬: `postgres-patterns`, `backend-patterns`
- 리뷰: 에이전트 `database-reviewer`, 커맨드 `/database-review`
