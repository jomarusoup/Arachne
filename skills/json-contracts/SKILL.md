---
name: json-contracts
description: Python(Pydantic v2)·C 서버·TypeScript 간 JSON wire contract — datetime RFC 3339, Decimal 문자열, UUID·enum·bytes·big int 매핑, C 구조체 필드(int64·스케일 정수·고정 길이 char[N]·존재 비트)의 JSON 표현, missing vs null·PATCH 의미, unknown field·payload 한계, schema versioning과 OpenAPI breaking-change 검출. 대상 경로 — **/openapi*.yaml, **/openapi*.json, **/schemas/**/*.py, **/api/**/*.ts. 키워드 — JSON 계약, wire contract, 직렬화, datetime, int64 정밀도, 스케일 정수, schema versioning.
---

# JSON Wire Contract — Python·C ↔ TypeScript

API 경계를 넘는 JSON의 타입·의미 계약. 직렬화 손실과 양쪽 해석 차이를 설계 단계에서 차단한다.
경계 전체의 정본·변경 절차·검증 흐름은 `api-contracts`가 다룬다. 이 스킬은 필드 하나의 표현을 정한다.

## 언제 활성화하나

- Pydantic 스키마·API 응답 모델 설계·수정
- C 서버가 구조체를 JSON 응답으로 내보내는 코드 작성
- TypeScript 클라이언트가 소비하는 JSON 필드 추가·변경
- 날짜·금액·ID·이진 데이터를 API로 내보내는 코드 작성
- PATCH 엔드포인트의 부분 수정 의미 결정
- OpenAPI schema 변경이 하위 호환인지 판정

## 핵심 사고

JSON에는 datetime·Decimal·UUID·bytes 타입이 없다. **양쪽 언어가 같은 문자열 표현을 같은 의미로
해석하도록 명문화한 것**이 wire contract다. 표현이 암묵적이면 직렬화는 동작해도 의미가 어긋난다.

## 타입 매핑 표

| Python | C 구조체 | JSON wire | TypeScript | 규칙 |
| --- | --- | --- | --- | --- |
| `datetime` (aware) | `int64_t` epoch ns(UTC) | `"2026-06-10T12:00:00Z"` | `string` | RFC 3339·UTC 기본, naive 금지 |
| `Decimal` | `int64_t` 스케일 정수 | `"1234.50"` | `string` | float·`double`·number 변환 금지 |
| `UUID` | `uint8_t[16]` | `"6fa4..."` (소문자) | `string` | canonical 형식 고정 |
| `Enum` | `#define`·`enum` 정수 | `"active"` | string union | 정수 enum 노출 금지 |
| `bytes` | `uint8_t[]` + 길이 | base64 `string` | `string` | 크기 상한 명시 |
| `int` > 2^53-1 | `int64_t`·`uint64_t` | `"9007199254740993"` | `string`/`bigint` | JS Number 정밀도 경계 |
| `str` (길이 상한) | `char[N]` NUL 패딩 | `"ALPHA"` | `string` | 첫 NUL에서 자름, 패딩 미노출 |
| 빈 값 | 존재 비트·플래그 | 필드 생략 vs `null` | `undefined` vs `null` | 의미 구분 (아래 PATCH) |

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

## C 서버 → JSON — 구조체 필드 내보내기

C에는 Decimal·null·가변 문자열이 없다. 그래서 C 쪽 표현을 JSON 표현으로 바꾸는 규칙을 고정한다.

- **64비트 정수는 문자열로 낸다.** ID·시퀀스·나노초 시각은 `"%" PRId64`로 따옴표 안에 쓴다.
  2^53 이하만 나온다는 보장이 없으면 숫자로 내지 않는다. TS는 `BigInt(value)`로 읽는다.
- **스케일 정수는 고정 소수점 문자열로 낸다.** `price = 1234500`, 스케일 10^4면 `"123.4500"`이다.
  `(double)price / 10000`을 `%f`로 찍지 않는다. 정수 몫과 나머지로 문자열을 만든다.
- **`char[N]`은 첫 NUL까지만 낸다.** 꽉 찬 필드는 NUL이 없으므로 `strnlen(field, N)`으로 길이를 잰다.
  패딩·쓰레기 바이트를 그대로 내지 않는다. JSON 문자열 이스케이프(`"`·`\`·제어 문자)를 반드시 한다.
- **없음과 비움을 존재 비트로 구분한다.** C 구조체는 null이 없다. `present_mask` 같은 비트로
  "값 없음"을 표시하고, 비트가 꺼진 필드는 JSON에서 생략한다. 0을 "없음"으로 쓰지 않는다.
- **시각은 경계에서 한 번 바꾼다.** 내부는 `int64_t` epoch ns(UTC)로 두고, JSON에는 RFC 3339
  문자열로 낸다. 나노초가 필요하면 `"2026-06-10T12:00:00.123456789Z"`처럼 소수 9자리로 쓴다.

```c
/* 스케일 정수 → "123.4500" — 부동소수점을 거치지 않는다 */
int FormatScaled(int64_t value, int64_t scale, int digits, char *out, size_t cap)
{
    uint64_t mag   = value < 0 ? (uint64_t)0 - (uint64_t)value : (uint64_t)value;
    uint64_t whole = mag / (uint64_t)scale;
    uint64_t frac  = mag % (uint64_t)scale;
    int      len   = snprintf(out, cap, "%s%" PRIu64 ".%0*" PRIu64,
                              value < 0 ? "-" : "", whole, digits, frac);

    return (len < 0 || (size_t)len >= cap) ? -ENOSPC : len;
}
```

```typescript
// 소비자 — 문자열로 받은 64비트 값은 bigint 나 decimal 라이브러리로만 다룬다
interface QuoteDto { key: string; price: string; seq: string; }
const seq: bigint = BigInt(dto.seq);          // Number(dto.seq) 금지
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
- 스킬: `api-contracts`(정본·변경 절차·스트림 계약), `api-design`, `fastapi-patterns`, `database-migrations`
- 민감 데이터 분류: [docs/DATA-HANDLING.md](../../docs/DATA-HANDLING.md)
