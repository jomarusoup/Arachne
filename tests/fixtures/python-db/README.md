# python-db fixture

`docs/DATA-HANDLING.md` quality gate의 기준 프로젝트. DB·JSON 데이터 계약 회귀를
`tests/data_contract.bats`(정적 + 실행)와 자체 pytest 게이트로 검증한다.

## 구조

```
app/
├── models.py          # SQLAlchemy 2.x — unique·check 제약, Numeric 금액, tz-aware datetime
├── classification.py  # 데이터 분류표(public/internal/PII/secret)와 노출 검사
├── schemas.py         # Pydantic v2 — 입력 extra=forbid, 출력 allow-list, Decimal→str
├── contract.py        # 응답 schema 계약 추출·breaking change 검출
└── service.py         # 트랜잭션 경계·idempotency key 처리
alembic/versions/      # 2개 revision — 빈 DB·이전 revision 모두 head 도달 검증용
tests/data_contract/   # rollback·idempotency·snapshot·PII 게이트
```

## 실행

```bash
uv sync
uv run alembic upgrade head          # 기본 sqlite:///./fixture.db (DATABASE_URL로 변경)
uv run pytest tests/data_contract -q
# 또는 전체 게이트:
arachne project-check .
```

downgrade는 의도적으로 미구현 — forward-fix 원칙(`docs/DATA-HANDLING.md`)을 따른다.
fixture 데이터는 합성값만 사용한다 (`@example.com`, placeholder secret).
