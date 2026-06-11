---
description: schema→query→migration→security→test 순서 고정 DB 종합 리뷰 — database-reviewer 에이전트 호출
---

# /database-review — 데이터베이스 코드 리뷰

**database-reviewer** 에이전트를 호출해 DB 변경 종합 리뷰를 수행한다.
Python 일반 이디엄은 `/python-review`, API 경계는 `/fastapi-review`와 겹치므로
**schema·쿼리·migration·데이터 보안** 고유 문제에 집중한다.

## 동작 — 순서 고정

1. **schema** — `git diff`로 모델·DDL 변경 확인: 타입·제약·ON DELETE·nullable 적정성
2. **query** — 변경·신규 쿼리의 N+1, full scan 가능성, 파라미터 바인딩
3. **migration** — revision 분리, CONCURRENTLY, lock_timeout, 배포 revision 수정 여부, 복구 계획
4. **security** — SQL 인젝션, PII 필드의 응답·로그·캐시 노출, 권한 범위
5. **test** — 빈 DB·기존 DB upgrade 검증, rollback·idempotency 회귀 테스트 존재
6. **리포트** — 심각도별 분류 (단계 × CRITICAL/HIGH/MEDIUM 요약표)

## 언제 사용하나

- `alembic/`·`migrations/` revision 파일 작성·수정 후, 커밋 전
- ORM 모델·repository·raw SQL 변경이 포함된 PR 리뷰
- 인덱스·제약·schema 정의 또는 DB 설정(pool·timeout) 변경 시

## 리뷰 카테고리

### CRITICAL (반드시 수정)
- 배포된 revision 수정 (환경 간 schema 분기)
- 단일 트랜잭션 대량 backfill (장시간 락·복구 불가 중단)
- SQL 인젝션 (f-string·문자열 결합 쿼리)
- 데이터 파괴 DDL(drop·truncate)에 복구 계획 없음
- PII 필드의 응답·로그·캐시 노출 (`docs/DATA-HANDLING.md` 분류표 기준)

### HIGH (수정 권장)
- 운영 테이블 인덱스를 CONCURRENTLY 없이 생성
- FK에 ON DELETE 미지정, unique 제약 없는 중복 방지 로직
- 트랜잭션 안 외부 네트워크 I/O, 커밋 책임 분산
- naive datetime·float 금액 컬럼
- N+1 패턴 (루프 내 단건 조회)

### MEDIUM (검토)
- lock_timeout·statement_timeout 미설정 DDL
- nullable 의미 불명 컬럼, 증거 없는 인덱스 추가
- JSONB 내부 필드에 비즈니스 무결성 누적

## 자동 검사

```bash
alembic check                                       # 모델·schema 드리프트
alembic upgrade head                                # 빈 DB 기준 적용 (재현 환경)
grep -rn "execute(f\"" --include="*.py" .           # f-string SQL 의심
uv run pytest tests/ -k "rollback or idempotency"   # 회귀 테스트 존재 확인
```

## 흔한 수정 패턴

```python
# 운영 테이블 인덱스 — 쓰기 블로킹 방지
op.create_index("ix_orders_user_id", "orders", ["user_id"])          # BAD
with op.get_context().autocommit_block():                            # GOOD
    op.create_index("ix_orders_user_id", "orders", ["user_id"],
                    postgresql_concurrently=True)

# 중복 방지 — 애플리케이션 체크가 아닌 DB 제약
if not db.query(Order).filter_by(key=key).first(): ...              # BAD (레이스)
sa.UniqueConstraint("idempotency_key")                               # GOOD

# 금액 — float 금지
amount = sa.Column(sa.Float)                                         # BAD
amount = sa.Column(sa.Numeric(18, 2))                                # GOOD
```

## 승인 기준

| 상태 | 조건 |
| ---- | ---- |
| 승인 | CRITICAL·HIGH 없음 |
| 경고 | MEDIUM만 존재 (주의 후 머지) |
| 차단 | CRITICAL·HIGH 존재 |

## 연계

- Python 일반 리뷰는 `/python-review`, API 경계는 `/fastapi-review`
- 커밋 전 검증은 `/verify`
- 상세 패턴은 스킬 `database-migrations`·`postgres-patterns`·`json-contracts`,
  규칙 `rules/python/data-handling.md`, 분류표 `docs/DATA-HANDLING.md`
- 에이전트: `agents/database-reviewer.md`
