---
name: api-design
description: 리소스 네이밍·상태 코드·페이지네이션·필터링·에러 응답·버전 관리·레이트 리미팅을 포함한 운영 REST API 설계 패턴.
origin: ECC
---

# API 설계 패턴

일관되고 개발자 친화적인 REST API를 설계하기 위한 컨벤션과 모범 사례.

## 언제 활성화하나

- 새 API 엔드포인트 설계
- 기존 API 계약 검토
- 페이지네이션·필터링·정렬 추가
- API 에러 처리 구현
- API 버전 관리 전략 계획
- 공개 또는 파트너 대상 API 개발

## 리소스 설계

### URL 구조

```
# 리소스는 명사, 복수, 소문자, kebab-case
GET    /api/v1/users
GET    /api/v1/users/:id
POST   /api/v1/users
PUT    /api/v1/users/:id
PATCH  /api/v1/users/:id
DELETE /api/v1/users/:id

# 관계를 위한 하위 리소스
GET    /api/v1/users/:id/orders
POST   /api/v1/users/:id/orders

# CRUD에 매핑되지 않는 액션 (동사는 최소화)
POST   /api/v1/orders/:id/cancel
POST   /api/v1/auth/login
```

### 네이밍 규칙

```
# 올바름
/api/v1/team-members          # 복수 단어는 kebab-case
/api/v1/orders?status=active  # 필터링은 쿼리 파라미터
/api/v1/users/123/orders      # 소유 관계는 중첩 리소스

# 잘못됨
/api/v1/getUsers              # URL에 동사
/api/v1/user                  # 단수 (복수 사용)
/api/v1/team_members          # URL에 snake_case
```

## HTTP 메서드 및 상태 코드

### 메서드 의미론

| 메서드 | 멱등성 | 안전 | 사용 |
|---|---|---|---|
| GET | 예 | 예 | 리소스 조회 |
| POST | 아니오 | 아니오 | 리소스 생성, 액션 트리거 |
| PUT | 예 | 아니오 | 리소스 전체 교체 |
| PATCH | 아니오* | 아니오 | 리소스 부분 업데이트 |
| DELETE | 예 | 아니오 | 리소스 제거 |

### 상태 코드 참조

```
# 성공
200 OK                    — GET, PUT, PATCH (응답 바디 포함)
201 Created               — POST (Location 헤더 포함)
204 No Content            — DELETE, PUT (응답 바디 없음)

# 클라이언트 에러
400 Bad Request           — 검증 실패, 잘못된 JSON
401 Unauthorized          — 인증 없음 또는 유효하지 않음
403 Forbidden             — 인증됐지만 인가 없음
404 Not Found             — 리소스 없음
409 Conflict              — 중복 항목, 상태 충돌
422 Unprocessable Entity  — 의미론적으로 유효하지 않음
429 Too Many Requests     — 레이트 리밋 초과

# 서버 에러
500 Internal Server Error — 예기치 않은 실패 (절대 세부사항 노출 금지)
503 Service Unavailable   — 일시적 과부하, Retry-After 포함
```

## 응답 형식

### 성공 응답

```json
{
  "data": {
    "id": "abc-123",
    "email": "alice@example.com",
    "name": "Alice",
    "created_at": "2025-01-15T10:30:00Z"
  }
}
```

### 컬렉션 응답 (페이지네이션 포함)

```json
{
  "data": [
    { "id": "abc-123", "name": "Alice" },
    { "id": "def-456", "name": "Bob" }
  ],
  "meta": {
    "total": 142,
    "page": 1,
    "per_page": 20,
    "total_pages": 8
  },
  "links": {
    "self": "/api/v1/users?page=1&per_page=20",
    "next": "/api/v1/users?page=2&per_page=20"
  }
}
```

### 에러 응답

```json
{
  "error": {
    "code": "validation_error",
    "message": "요청 검증 실패",
    "details": [
      { "field": "email", "message": "유효한 이메일 주소여야 합니다", "code": "invalid_format" },
      { "field": "age", "message": "0~150 사이여야 합니다", "code": "out_of_range" }
    ]
  }
}
```

## 페이지네이션

### 오프셋 기반 (단순)

```
GET /api/v1/users?page=2&per_page=20

SELECT * FROM users ORDER BY created_at DESC LIMIT 20 OFFSET 20;
```

**장점:** 구현 쉬움, N페이지로 이동 가능
**단점:** 큰 오프셋에서 느림, 동시 삽입 시 불일치

### 커서 기반 (확장 가능)

```
GET /api/v1/users?cursor=eyJpZCI6MTIzfQ&limit=20

SELECT * FROM users WHERE id > :cursor_id ORDER BY id ASC LIMIT 21;
```

```json
{
  "data": [],
  "meta": { "has_next": true, "next_cursor": "eyJpZCI6MTQzfQ" }
}
```

**장점:** 위치와 무관한 일관된 성능
**단점:** 임의 페이지로 이동 불가

### 언제 어떤 것을 사용하나

| 사용 케이스 | 페이지네이션 유형 |
|---|---|
| 어드민 대시보드, 소규모 데이터셋 | 오프셋 |
| 무한 스크롤, 피드, 대규모 데이터셋 | 커서 |
| 공개 API | 커서 (기본) |
| 검색 결과 | 오프셋 (사용자가 페이지 번호 기대) |

## 필터링·정렬·검색

```
# 단순 동등 필터
GET /api/v1/orders?status=active&customer_id=abc-123

# 비교 연산자
GET /api/v1/products?price[gte]=10&price[lte]=100

# 정렬 (- 접두사는 내림차순)
GET /api/v1/products?sort=-created_at

# 전문 검색
GET /api/v1/products?q=wireless+headphones
```

## 인증 및 인가

```
# Bearer 토큰
GET /api/v1/users
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...

# API 키 (서버 간)
GET /api/v1/data
X-API-Key: sk_live_abc123
```

## 레이트 리미팅

```
HTTP/1.1 200 OK
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000

# 초과 시
HTTP/1.1 429 Too Many Requests
Retry-After: 60
```

## 버전 관리

### URL 경로 버전 관리 (권장)

```
/api/v1/users
/api/v2/users
```

**버전 관리 전략:**
1. `/api/v1/`로 시작 — 필요할 때까지 버전 관리 안 함
2. 최대 2개 활성 버전 유지 (현재 + 이전)
3. 하위 호환 변경은 새 버전 불필요 (새 필드 추가, 새 엔드포인트 추가)
4. 파괴적 변경은 새 버전 필요 (필드 제거/이름 변경, 타입 변경)

## 구현 패턴

### TypeScript (Next.js)

```typescript
import { z } from "zod"
import { NextRequest, NextResponse } from "next/server"

const createUserSchema = z.object({
    email: z.string().email(),
    name: z.string().min(1).max(100),
})

export async function POST(req: NextRequest) {
    const body = await req.json()
    const parsed = createUserSchema.safeParse(body)

    if (!parsed.success) {
        return NextResponse.json({
            error: {
                code: "validation_error",
                message: "요청 검증 실패",
                details: parsed.error.issues.map(i => ({
                    field: i.path.join("."),
                    message: i.message,
                })),
            },
        }, { status: 422 })
    }

    const user = await createUser(parsed.data)
    return NextResponse.json(
        { data: user },
        { status: 201, headers: { Location: `/api/v1/users/${user.id}` } }
    )
}
```

### Go

```go
func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
    var req CreateUserRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        writeError(w, http.StatusBadRequest, "invalid_json", "유효하지 않은 요청 바디")
        return
    }

    user, err := h.service.Create(r.Context(), req)
    if err != nil {
        switch {
        case errors.Is(err, domain.ErrEmailTaken):
            writeError(w, http.StatusConflict, "email_taken", "이미 등록된 이메일")
        default:
            writeError(w, http.StatusInternalServerError, "internal_error", "내부 오류")
        }
        return
    }

    w.Header().Set("Location", fmt.Sprintf("/api/v1/users/%s", user.ID))
    writeJSON(w, http.StatusCreated, map[string]any{"data": user})
}
```

## API 설계 체크리스트

새 엔드포인트 출시 전:

- [ ] 리소스 URL이 네이밍 컨벤션 따름 (복수, kebab-case, 동사 없음)
- [ ] 올바른 HTTP 메서드 사용
- [ ] 적절한 상태 코드 반환 (모든 것에 200 금지)
- [ ] 스키마로 입력 검증 (Zod, Pydantic)
- [ ] 에러 응답이 코드와 메시지가 있는 표준 형식
- [ ] 목록 엔드포인트에 페이지네이션 구현
- [ ] 인증 필요 (또는 명시적으로 공개로 표시)
- [ ] 인가 확인 (사용자는 자신의 리소스만 접근)
- [ ] 레이트 리미팅 설정
- [ ] 응답에 내부 세부사항 노출 없음
- [ ] OpenAPI/Swagger 스펙 업데이트
