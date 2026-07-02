---
name: api-design
description: REST API 설계 패턴 — 리소스 네이밍, HTTP 상태 코드 의미, 응답 봉투(envelope), 오프셋/커서 페이지네이션, 필터·정렬·검색, 에러 응답, 버전 전략, 레이트 리밋. 프로덕션 API 설계·리뷰 시 참조.
triggers:
  paths: []
  keywords: ["REST", "API 설계", "페이지네이션", "상태 코드", "rate limit", "versioning"]
---

# REST API 설계 패턴

일관되고 개발자 친화적인 REST API를 위한 관례와 모범 사례.
(Arachne 스타일로 작성)

## 언제 활성화하나

- 신규 API 엔드포인트 설계
- 기존 API 계약(contract) 리뷰
- 페이지네이션·필터·정렬 추가
- API 에러 처리 구현
- API 버전 전략 수립
- 공개·파트너 대상 API 구축

## 리소스 설계

### URL 구조

```
# 리소스는 명사·복수·소문자·kebab-case
GET    /api/v1/users
GET    /api/v1/users/:id
POST   /api/v1/users
PATCH  /api/v1/users/:id        # 부분 수정
DELETE /api/v1/users/:id

# 관계는 하위 리소스로
GET    /api/v1/users/:id/orders

# CRUD에 안 맞는 동작만 동사 사용 (드물게)
POST   /api/v1/orders/:id/cancel
POST   /api/v1/auth/login
```

### 네이밍 규칙

```
# GOOD
/api/v1/team-members          # 복합어는 kebab-case
/api/v1/orders?status=active  # 필터는 쿼리 파라미터
/api/v1/users/123/orders      # 소유 관계는 중첩 리소스

# BAD
/api/v1/getUsers              # URL에 동사
/api/v1/user                  # 단수 (복수 사용)
/api/v1/team_members          # URL에 snake_case
```

## HTTP 메서드와 상태 코드

| 메서드 | 멱등 | 안전 | 용도 |
|--------|:---:|:---:|------|
| GET | O | O | 조회 |
| POST | X | X | 생성·액션 트리거 |
| PUT | O | X | 전체 교체 |
| PATCH | X | X | 부분 수정 |
| DELETE | O | X | 삭제 |

### 상태 코드 — 의미대로 사용

```
# 성공
200 OK              — GET·PUT·PATCH (응답 본문 있음)
201 Created         — POST (Location 헤더 포함)
204 No Content      — DELETE·PUT (응답 본문 없음)

# 클라이언트 오류
400 Bad Request     — 검증 실패·잘못된 JSON
401 Unauthorized    — 인증 없음·무효
403 Forbidden       — 인증됐으나 권한 없음
404 Not Found       — 리소스 없음
409 Conflict        — 중복·상태 충돌
422 Unprocessable   — 의미상 무효 (JSON은 유효, 데이터가 잘못)
429 Too Many Requests — 레이트 리밋 초과

# 서버 오류
500 Internal        — 예기치 못한 실패 (상세 노출 금지)
503 Service Unavailable — 과부하 (Retry-After 포함)
```

```
# BAD: 전부 200으로 반환
{ "status": 200, "success": false, "error": "Not found" }

# GOOD: HTTP 상태 코드를 의미대로
HTTP/1.1 404 Not Found
{ "error": { "code": "not_found", "message": "User not found" } }
```

> 흔한 실수: 검증 오류에 500(→ 400/422), 생성에 200(→ 201 + Location).

## 응답 형식 — 봉투(envelope)

### 단일·컬렉션

```json
// 단일
{ "data": { "id": "abc-123", "email": "alice@example.com" } }

// 컬렉션 + 페이지네이션 메타
{
  "data": [ { "id": "abc-123", "name": "Alice" } ],
  "meta":  { "total": 142, "page": 1, "per_page": 20, "total_pages": 8 },
  "links": { "next": "/api/v1/users?page=2&per_page=20" }
}
```

### 에러 — 필드 단위 상세

```json
{
  "error": {
    "code": "validation_error",
    "message": "Request validation failed",
    "details": [
      { "field": "email", "message": "Must be a valid email", "code": "invalid_format" },
      { "field": "age",   "message": "Must be 0..150",        "code": "out_of_range" }
    ]
  }
}
```

> 공개 API는 `data` 래퍼 봉투 권장. 내부 API는 리소스 직접 반환 + 상태 코드로 구분(더 단순)도 가능.

## 페이지네이션

### 오프셋 기반 (단순)

```
GET /api/v1/users?page=2&per_page=20
SELECT * FROM users ORDER BY created_at DESC LIMIT 20 OFFSET 20;
```
- 장점: 구현 쉬움, "N페이지로 점프" 가능
- 단점: 큰 오프셋에서 느림(OFFSET 100000), 동시 삽입 시 불일치

### 커서 기반 (확장성)

```
GET /api/v1/users?cursor=eyJpZCI6MTIzfQ&limit=20
SELECT * FROM users WHERE id > :cursor_id ORDER BY id ASC LIMIT 21;  -- has_next 판별용 +1
```
```json
{ "data": [], "meta": { "has_next": true, "next_cursor": "eyJpZCI6MTQzfQ" } }
```
- 장점: 위치 무관 일정 성능, 동시 삽입에 안정
- 단점: 임의 페이지 점프 불가, 커서는 불투명

| 상황 | 페이지네이션 |
|------|------|
| 관리자 대시보드, 소규모(<10K) | 오프셋 |
| 무한 스크롤·피드·대규모 | 커서 |
| 공개 API | 커서(기본) + 오프셋(선택) |
| 검색 결과(페이지 번호 기대) | 오프셋 |

## 필터·정렬·검색·희소 필드

```
# 필터 (비교는 브래킷 표기)
GET /api/v1/products?price[gte]=10&price[lte]=100
GET /api/v1/products?category=electronics,clothing   # 다중값 콤마

# 정렬 (- 접두는 내림차순, 콤마로 다중)
GET /api/v1/products?sort=-featured,price,-created_at

# 전문 검색
GET /api/v1/products?q=wireless+headphones

# 희소 필드셋 (페이로드 축소)
GET /api/v1/users?fields=id,name,email
```

## 인증·인가

```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...   # 사용자 토큰
X-API-Key: sk_live_abc123                        # 서버-서버
```

- **리소스 레벨**: 소유권 확인 — 없으면 404, 남의 것이면 403
- **역할 레벨**: `requireRole("admin")` 같은 권한 게이트

## 레이트 리밋

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000

# 초과 시
HTTP/1.1 429 Too Many Requests
Retry-After: 60
{ "error": { "code": "rate_limit_exceeded", "message": "Try again in 60 seconds." } }
```

| 티어 | 한도 | 기준 |
|------|------|------|
| 익명 | 30/min | IP |
| 인증 | 100/min | 사용자 |
| 프리미엄 | 1000/min | API 키 |
| 내부 | 10000/min | 서비스 |

## 버전 전략

```
/api/v1/users   →   /api/v2/users     # URL 경로 버전 (권장: 명시적·캐시 가능)
```

```
1. /api/v1/ 로 시작 — 필요해지기 전엔 버전 안 만든다
2. 동시 활성 버전은 최대 2개(현재 + 직전)
3. deprecation: 공지(공개 API는 6개월) → Sunset 헤더 → 기한 후 410 Gone
4. 비파괴 변경(새 필드·새 선택 파라미터·새 엔드포인트)은 버전 불필요
5. 파괴 변경(필드 제거·타입 변경·URL 변경·인증 변경)만 새 버전
```

## 구현 예 (Next.js / Python)

```typescript
// Next.js API Route — zod 검증 + 422 + 201 Location
const schema = z.object({ email: z.string().email(), name: z.string().min(1).max(100) });

export async function POST(req: NextRequest) {
  const parsed = schema.safeParse(await req.json());
  if (!parsed.success) {
    return NextResponse.json({
      error: { code: "validation_error", message: "검증 실패",
        details: parsed.error.issues.map(i => ({ field: i.path.join("."), message: i.message, code: i.code })) },
    }, { status: 422 });
  }
  const user = await createUser(parsed.data);
  return NextResponse.json({ data: user }, { status: 201, headers: { Location: `/api/v1/users/${user.id}` } });
}
```

```python
# DRF — action별 시리얼라이저 분리 + 201 Location
class UserViewSet(viewsets.ModelViewSet):
    permission_classes = [IsAuthenticated]
    def get_serializer_class(self):
        return CreateUserSerializer if self.action == "create" else UserSerializer
    def create(self, request):
        s = CreateUserSerializer(data=request.data); s.is_valid(raise_exception=True)
        user = UserService.create(**s.validated_data)
        return Response({"data": UserSerializer(user).data},
                        status=status.HTTP_201_CREATED, headers={"Location": f"/api/v1/users/{user.id}"})
```

## 엔드포인트 출시 전 체크리스트

- [ ] URL 네이밍 규칙 준수 (복수·kebab-case·동사 없음)
- [ ] 올바른 HTTP 메서드
- [ ] 적절한 상태 코드 (전부 200 금지)
- [ ] 스키마로 입력 검증 (Zod·Pydantic)
- [ ] 표준 에러 형식 (code·message·details)
- [ ] 리스트 엔드포인트 페이지네이션 (커서/오프셋)
- [ ] 인증 필수 (또는 명시적 public)
- [ ] 인가 확인 (자기 리소스만 접근)
- [ ] 레이트 리밋 구성
- [ ] 내부 상세 미노출 (스택트레이스·SQL 에러)
- [ ] 기존 엔드포인트와 네이밍 일관성
- [ ] OpenAPI/Swagger 문서 갱신

## 참조

- 에이전트: `fastapi-reviewer`, 커맨드: `/fastapi-review`
- 스킬: `fastapi-patterns`, `backend-patterns`
- 규칙: `rules/python/fastapi.md`
