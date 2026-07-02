---
paths:
  - "**/*.py"
  - "**/*.pyi"
---
# Python 데이터 처리 경계 규칙

> JSON 직렬화·DB 트랜잭션·민감 데이터의 **항상 적용되는 짧은 경계 규칙**.
> 상세 예시와 선택 기준은 스킬 `json-contracts` · `database-migrations` · `postgres-patterns` 참고.
> 분류표·노출 표면·암호화 경계·quality gate 정본은 `docs/DATA-HANDLING.md` 참고.

## JSON 경계

- **datetime은 timezone-aware만** 직렬화 — naive datetime을 API 경계로 내보내지 않는다 (RFC 3339, UTC 기본).
- **금액·정밀 수치는 `Decimal` → 문자열** — float 직렬화 금지 (손실·반올림 오차).
- **missing과 null을 구분** — PATCH는 "보내지 않음 = 유지, null = 삭제" 의미를 깨지 않는다.
- **unknown field 정책을 모델에 명시** — 입력은 거부(`extra="forbid"`) 또는 의도적 허용, 묵묵한 drop 금지.
- 응답 스키마에 raw ORM 객체·내부 필드를 노출하지 않는다 (`response_model` 필수).

## SQLAlchemy 세션·트랜잭션

- 세션 수명은 **요청·작업 단위 하나** — 전역 세션·핸들러 인라인 생성 금지.
- **commit/rollback 책임은 서비스(use-case) 경계 한 곳** — repository·라우터에서 commit 금지.
- **트랜잭션 안에서 외부 네트워크 I/O 금지** (HTTP 호출, 메시지 발행) — 락 보유 시간이 외부 지연에 묶인다.
- 중첩 작업은 임의 commit 대신 **savepoint(`begin_nested`)** 로 격리한다. savepoint는 부분 실패를
  복구해야 하는 좁은 구간에만 쓰고, 일반 흐름 제어로 남용하지 않는다.
- serialization failure·deadlock 같은 retry 가능 DB 오류는 **idempotency key 또는 고유 제약**이
  있는 작업만 재시도한다. 재시도 전 rollback, 지수 backoff, 최대 횟수를 명시한다.
- 중복 방지는 애플리케이션 검사가 아니라 **unique constraint + idempotency key**로 보장한다.
- 컬렉션 순회 전 N+1 여부 확인 — 의도적 eager loading(`selectinload`)을 명시한다.

## Migration

- **배포된 revision은 수정하지 않는다** — 잘못됐으면 forward-fix revision을 추가한다.
- schema 변경과 data backfill은 **revision을 분리**한다.
- DDL 전 `lock_timeout`을 설정하고, 되돌릴 수 없는 migration은 파일에 명시한다.

## 민감 데이터

- PII·secret 필드는 **응답·로그·metric·cache에 기본 비노출** — 허용 필드는 분류표로 관리한다.
- 비밀번호는 해싱(argon2/bcrypt), 복호화가 필요한 PII만 field-level encryption — 경계를 혼동하지 않는다.
- 테스트 fixture에 실제 개인정보를 넣지 않는다 — 합성 데이터만 사용.
