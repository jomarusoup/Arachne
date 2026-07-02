---
name: json-contracts
description: Python(Pydantic v2)·TypeScript 간 JSON wire contract — datetime RFC 3339, Decimal 문자열, UUID·enum·bytes·big int 매핑, missing vs null·PATCH 의미, unknown field·payload 한계, schema versioning과 OpenAPI breaking-change 검출.
triggers:
  paths: []
  keywords: ["JSON 계약", "wire contract", "직렬화", "datetime", "schema versioning"]
---

# JSON Wire Contract — Python ↔ TypeScript

API 경계를 넘는 JSON의 타입·의미 계약. 직렬화 손실과 양쪽 해석 차이를 설계 단계에서 차단한다.

## 언제 활성화하나

- Pydantic 스키마·API 응답 모델 설계·수정
- TypeScript 클라이언트가 소비하는 JSON 필드 추가·변경
- 날짜·금액·ID·이진 데이터를 API로 내보내는 코드 작성
- PATCH 엔드포인트의 부분 수정 의미 결정
- OpenAPI schema 변경이 하위 호환인지 판정

## 핵심 사고

JSON에는 datetime·Decimal·UUID·bytes 타입이 없다. **양쪽 언어가 같은 문자열 표현을 같은 의미로
해석하도록 명문화한 것**이 wire contract다. 표현이 암묵적이면 직렬화는 동작해도 의미가 어긋난다.

## 타입 매핑 표

| Python | JSON wire | TypeScript | 규칙 |
| --- | --- | --- | --- |
| `datetime` (aware) | `"2026-06-10T12:00:00Z"` | `string` | RFC 3339·UTC 기본, naive 금지 |
| `Decimal` | `"1234.50"` | `string` | float·number 변환 금지 |
| `UUID` | `"6fa4..."` (소문자) | `string` | canonical 형식 고정 |
| `Enum` | `"active"` | string union | 정수 enum 노출 금지 |
| `bytes` | base64 `string` | `string` | 크기 상한 명시 |
| `int` > 2^53-1 | `"9007199254740993"` | `string`/`bigint` | JS Number 정밀도 경계 |
| 빈 값 | 필드 생략 vs `null` | `undefined` vs `null` | 의미 구분 (아래 PATCH) |

## datetime — timezone-aware RFC 3339

```python
from datetime import datetime, timezone
from pydantic import AwareDatetime, BaseModel

class EventResponse(BaseModel):
    occurred_at: AwareDatetime          # naive datetime 입력은 검증 실패

def now_utc() -> datetime:
    return datetime.now(timezone.utc)   # datetime.utcnow() 금지 — naive 반환
```

- 저장·연산·직렬화는 UTC, 표시 시점에만 로컬 변환.
- TypeScript는 `new Date(value)` 파싱 후 표시 포맷만 로컬라이즈.

## Decimal — 금액은 문자열

```python
from decimal import Decimal
from pydantic import BaseModel, field_serializer

class Money(BaseModel):
    amount: Decimal
    currency: str

    @field_serializer("amount")
    def serialize_amount(self, value: Decimal) -> str:
        return format(value, "f")       # 지수 표기 없이 고정 소수점
```

```typescript
// BAD: parseFloat(res.amount) — 0.1 + 0.2 문제 재도입
// GOOD: 문자열 그대로 보관, 연산은 decimal 라이브러리(big.js 등)
interface Money { amount: string; currency: string; }
```

## missing vs null — PATCH 의미

| wire | 의미 | Pydantic 판별 |
| --- | --- | --- |
| 필드 생략 | 변경하지 않음 | `model_fields_set`에 없음 |
| `"field": null` | 값을 비움 | `exclude_unset=True` dump에 `None`으로 포함 |

```python
from pydantic import BaseModel, ConfigDict

class UserPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    full_name: str | None = None
    nickname: str | None = None

    def changes(self) -> dict:
        return self.model_dump(exclude_unset=True)   # 보낸 필드만
```

- PUT은 전체 교체, PATCH는 보낸 필드만 — 혼용 금지.
- `exclude_none`과 `exclude_unset`을 혼동하면 "null로 비우기"가 사라진다.

## unknown field·payload 한계

- 입력 모델은 `extra="forbid"` 기본 — 오타 필드를 묵묵히 버리지 않는다.
- 의도적으로 통과시키는 proxy·webhook 모델만 `extra="allow"`를 명시.
- 최대 payload 크기(예: 1 MiB)·중첩 깊이(예: 32)·배열 길이 상한을 경계 미들웨어에서 검증.
- duplicate key는 JSON 파서가 마지막 값을 취한다 — 보안 판단에 쓰는 필드면 직접 거부 검증.

## schema versioning — 호환 변경 기준

| 변경 | 호환성 | 처리 |
| --- | --- | --- |
| optional 필드 추가 (default 있음) | backward-compatible | 그대로 배포 |
| 응답 필드 추가 | 호환 (클라이언트는 unknown 무시) | 그대로 배포 |
| 필드 제거·이름 변경 | **breaking** | deprecation 기간 + 버전 분리 |
| 타입·포맷·의미 변경 | **breaking** | 새 필드 추가 후 구 필드 단계 제거 |
| enum 값 추가 | 소비자 따라 다름 | 클라이언트 default 분기 합의 필요 |

- 클라이언트는 모르는 응답 필드를 **무시하고 통과**시켜야 한다 (tolerant reader).
- breaking change는 expand-contract — 새 필드 추가 → 양쪽 전환 → 구 필드 제거.

## OpenAPI snapshot·breaking-change 검출

선정 도구: **OpenAPI snapshot 커밋 + oasdiff breaking 검사**.

```bash
# 스키마 추출 후 저장소의 snapshot과 비교
python -c "import json, app.main; print(json.dumps(app.main.app.openapi(), indent=2, sort_keys=True))" > openapi.json
oasdiff breaking docs/openapi.snapshot.json openapi.json   # breaking이면 비0 종료
```

- snapshot은 코드와 같은 PR에서 갱신 — diff 자체가 리뷰 대상이 된다.
- oasdiff가 없는 환경은 snapshot diff 비어 있음만 검사해도 무단 변경은 잡는다.

## 참조

- 규칙: `rules/python/data-handling.md` (항상 적용되는 경계 규칙)
- 스킬: `api-design`, `fastapi-patterns`, `database-migrations`
- 민감 데이터 분류: [docs/DATA-HANDLING.md](../docs/DATA-HANDLING.md)
