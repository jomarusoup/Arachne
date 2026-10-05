---
name: security-review
description: 인증 추가·사용자 입력 처리·비밀값 작업·API 엔드포인트 생성·결제/민감한 기능 구현 시 사용. 포괄적인 보안 체크리스트와 패턴 제공. 키워드 — 보안 리뷰, 취약점, 인젝션, 비밀값, 인증 인가.
---

# 보안 리뷰 스킬

모든 코드가 보안 모범 사례를 따르고 잠재적 취약점을 식별하도록 보장한다.

## 언제 활성화하나

- 인증 또는 인가 구현
- 사용자 입력 또는 파일 업로드 처리
- 새 API 엔드포인트 생성
- 비밀값 또는 자격증명 작업
- 결제 기능 구현
- 민감한 데이터 저장 또는 전송
- 서드파티 API 연동

## 보안 체크리스트

### 1. 비밀값 관리

```typescript
/* 잘못됨: 하드코딩된 비밀값 */
const apiKey = "sk-proj-xxxxx"
const dbPassword = "password123"

/* 올바름: 환경변수 사용 */
const apiKey = process.env.OPENAI_API_KEY
if (!apiKey) {
    throw new Error('OPENAI_API_KEY가 설정되지 않았습니다')
}
```

확인 항목:
- [ ] 하드코딩된 API 키, 토큰, 비밀번호 없음
- [ ] 모든 비밀값은 환경변수에
- [ ] `.env.local`이 .gitignore에 있음
- [ ] git 히스토리에 비밀값 없음

### 2. 입력 검증

```typescript
import { z } from 'zod'

const CreateUserSchema = z.object({
    email: z.string().email(),
    name: z.string().min(1).max(100),
    age: z.number().int().min(0).max(150)
})

export async function createUser(input: unknown) {
    try {
        const validated = CreateUserSchema.parse(input)
        return await db.users.create(validated)
    } catch (error) {
        if (error instanceof z.ZodError) {
            return { success: false, errors: error.errors }
        }
        throw error
    }
}
```

파일 업로드 검증:

```typescript
function validateFileUpload(file: File) {
    const maxSize = 5 * 1024 * 1024  /* 5MB */
    if (file.size > maxSize) throw new Error('파일이 너무 큼 (최대 5MB)')

    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif']
    if (!allowedTypes.includes(file.type)) throw new Error('허용되지 않는 파일 형식')
}
```

### 3. SQL 인젝션 방지

```typescript
/* 잘못됨: SQL 직접 연결 */
const query = `SELECT * FROM users WHERE email = '${userEmail}'`

/* 올바름: 파라미터화 쿼리 */
await db.query('SELECT * FROM users WHERE email = \$1', [userEmail])
```

### 4. 인증·인가

```typescript
/* JWT 토큰 처리 */
/* 잘못됨: localStorage (XSS 취약) */
localStorage.setItem('token', token)

/* 올바름: httpOnly 쿠키 */
res.setHeader('Set-Cookie',
    `token=${token}; HttpOnly; Secure; SameSite=Strict; Max-Age=3600`)

/* 인가 확인 */
export async function deleteUser(userId: string, requesterId: string) {
    const requester = await db.users.findUnique({ where: { id: requesterId } })
    if (requester.role !== 'admin') {
        return NextResponse.json({ error: '권한 없음' }, { status: 403 })
    }
    await db.users.delete({ where: { id: userId } })
}
```

RLS (Row Level Security):

```sql
-- 모든 테이블에 RLS 활성화
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 데이터만 조회 가능
CREATE POLICY "Users view own data"
    ON users FOR SELECT
    USING (auth.uid() = id);
```

### 5. XSS 방지

```typescript
import DOMPurify from 'isomorphic-dompurify'

function renderUserContent(html: string) {
    const clean = DOMPurify.sanitize(html, {
        ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'p'],
        ALLOWED_ATTR: []
    })
    return <div dangerouslySetInnerHTML={{ __html: clean }} />
}
```

CSP (Content Security Policy):

```typescript
const securityHeaders = [
    {
        key: 'Content-Security-Policy',
        value: `
            default-src 'self';
            script-src 'self';
            style-src 'self';
            img-src 'self' data: https:;
            object-src 'none';
            frame-ancestors 'none';
        `.replace(/\s{2,}/g, ' ').trim()
    }
]
```

### 6. CSRF 방지

```typescript
export async function POST(request: Request) {
    const token = request.headers.get('X-CSRF-Token')
    if (!csrf.verify(token)) {
        return NextResponse.json({ error: '유효하지 않은 CSRF 토큰' }, { status: 403 })
    }
}
```

### 7. 레이트 리미팅

```typescript
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,  /* 15분 */
    max: 100,                    /* 창당 100 요청 */
    message: '요청이 너무 많습니다'
})

app.use('/api/', limiter)
```

### 8. 민감한 데이터 노출

```typescript
/* 잘못됨: 민감한 데이터 로깅 */
console.log('사용자 로그인:', { email, password })

/* 올바름: 민감한 데이터 제외 */
console.log('사용자 로그인:', { email, userId })

/* 잘못됨: 내부 오류 노출 */
return NextResponse.json({ error: error.message, stack: error.stack }, { status: 500 })

/* 올바름: 일반 오류 메시지 */
console.error('내부 오류:', error)
return NextResponse.json({ error: '오류가 발생했습니다. 다시 시도해 주세요.' }, { status: 500 })
```

개인정보 마스킹·비밀번호 해시·코어 덤프·합성 테스트 데이터 기준은 `sensitive-data-handling` 스킬을 따른다.

### 9. 의존성 보안

```bash
# 취약점 확인
npm audit

# 자동으로 수정 가능한 이슈 수정
npm audit fix

# 오래된 패키지 확인
npm outdated
```

## 보안 자동 테스트

보안 동작은 리뷰만으로 지켜지지 않는다. **거부해야 하는 요청이 실제로 거부되는지** 테스트로 고정한다.
엔드포인트를 추가할 때마다 아래 네 가지 응답을 확인하는 테스트를 함께 추가한다.

| 상황 | 기대 응답 | 확인할 것 |
|---|---|---|
| 인증 없음·만료 토큰 | `401 Unauthorized` | 본문에 내부 정보가 없고, 데이터가 바뀌지 않았다 |
| 인증은 됐지만 권한 없음 (다른 사용자 리소스, 관리자 기능) | `403 Forbidden` | 리소스 존재 여부를 숨겨야 하면 `404`로 통일한다 |
| 잘못된 입력 (타입·범위·길이·누락 필드) | `400 Bad Request` | 어떤 필드가 틀렸는지만 알려 주고 스택·SQL은 없다 |
| 한도 초과 요청 | `429 Too Many Requests` | `Retry-After` 헤더가 있고 한도가 지나면 다시 허용된다 |

- 테스트 계정과 토큰은 합성 데이터로 만든다. 운영 계정을 테스트에 쓰지 않는다 (`sensitive-data-handling`).
- 성공 경로(200) 테스트와 같은 파일에 둔다. 거부 테스트가 없는 엔드포인트는 리뷰에서 지적한다.

### C·Rust HTTP 서버 — curl 기반 셸 테스트

서버 구현 언어와 상관없이 실행 중인 서버에 요청을 보내 응답 코드를 확인한다. CI에서는 서버를 띄운 뒤 실행한다.

```bash
#!/bin/bash
################################################################################
# FILE NAME   : test_security_status.sh
# DESCRIPTION : 인증·인가·입력 검증·레이트 리밋 응답 코드를 검사한다
################################################################################
set -uo pipefail

readonly BASE_URL="${BASE_URL:-http://127.0.0.1:8080}"
readonly USER_TOKEN="${TEST_USER_TOKEN:?TEST_USER_TOKEN 필요 (합성 일반 사용자 토큰)}"
readonly RATE_LIMIT="${RATE_LIMIT:-100}"

g_FailCount=0

#-------------------------------------------------------------------------------
# 케이스 표: 기대코드|메서드|경로|인증(none/user)|본문
#-------------------------------------------------------------------------------
while IFS='|' read -r expected method path auth body; do
    [ -z "${expected}" ] && continue
    args=(-s -o /dev/null -w '%{http_code}' -X "${method}")
    [ "${auth}" = "user" ] && args+=(-H "Authorization: Bearer ${USER_TOKEN}")
    [ -n "${body}" ] && args+=(-H 'Content-Type: application/json' -d "${body}")
    actual=$(curl "${args[@]}" "${BASE_URL}${path}")
    if [ "${actual}" != "${expected}" ]; then
        echo "[FAIL] ${method} ${path}: ${actual} (기대 ${expected})"
        g_FailCount=$((g_FailCount + 1))
    fi
done <<'CASES'
401|GET|/api/orders|none|
403|GET|/api/admin/users|user|
400|POST|/api/orders|user|{"qty":-1}
400|POST|/api/orders|user|{"qty":"abc"}
CASES

#-------------------------------------------------------------------------------
# 레이트 리밋: 한도까지 보낸 뒤 다음 요청은 429 여야 한다
#-------------------------------------------------------------------------------
for ((ii = 0; ii < RATE_LIMIT; ii++)); do
    curl -s -o /dev/null -H "Authorization: Bearer ${USER_TOKEN}" "${BASE_URL}/api/orders"
done
actual=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${USER_TOKEN}" "${BASE_URL}/api/orders")
if [ "${actual}" != "429" ]; then
    echo "[FAIL] 레이트 리밋: ${actual} (기대 429)"
    g_FailCount=$((g_FailCount + 1))
fi

[ "${g_FailCount}" -eq 0 ] && echo "[PASS] 보안 응답 코드" || exit 1
```

- 레이트 리밋 테스트는 다른 테스트와 같은 한도를 공유하지 않도록 맨 마지막에 두거나 전용 계정을 쓴다.
- Rust 서버는 같은 표를 `axum` 라우터에 `tower::ServiceExt::oneshot`으로 보내는 통합 테스트로 옮겨도 된다.

### TypeScript 클라이언트·API 테스트 (vitest)

```typescript
import { describe, expect, it } from "vitest";

const BASE_URL   = process.env.BASE_URL ?? "http://127.0.0.1:8080";
const USER_TOKEN = process.env.TEST_USER_TOKEN ?? "";

/*=============================================================================
FUNCTION    : StatusOf
DESCRIPTION : 요청을 보내고 응답 코드만 돌려준다.
PARAMETERS  : string      path - API 경로
              RequestInit init - fetch 옵션
RETURNED    : HTTP 응답 코드
=============================================================================*/
async function StatusOf(path: string, init: RequestInit = {}): Promise<number> {
    const res = await fetch(`${BASE_URL}${path}`, init);
    return res.status;
}

const asUser = { Authorization: `Bearer ${USER_TOKEN}` };

describe("보안 응답 코드", () => {
    it("인증_없으면_401", async () => {
        expect(await StatusOf("/api/orders")).toBe(401);
    });

    it("권한_없으면_403", async () => {
        expect(await StatusOf("/api/admin/users", { headers: asUser })).toBe(403);
    });

    it("잘못된_입력이면_400", async () => {
        const status = await StatusOf("/api/orders", {
            method:  "POST",
            headers: { ...asUser, "Content-Type": "application/json" },
            body:    JSON.stringify({ qty: -1 }),
        });
        expect(status).toBe(400);
    });

    it("한도_초과면_429", async () => {
        const statuses = await Promise.all(
            Array.from({ length: 101 }, () => StatusOf("/api/orders", { headers: asUser })),
        );
        expect(statuses).toContain(429);
    });
});
```

- 클라이언트 코드는 401을 받으면 토큰을 지우고 로그인으로 보내고, 429를 받으면 `Retry-After`만큼 기다리는지 함께 테스트한다.

## 배포 전 보안 체크리스트

- [ ] **비밀값**: 하드코딩 없음, 모두 환경변수
- [ ] **입력 검증**: 모든 사용자 입력 검증
- [ ] **SQL 인젝션**: 모든 쿼리 파라미터화
- [ ] **XSS**: 사용자 콘텐츠 소독
- [ ] **CSRF**: 보호 활성화
- [ ] **인증**: 적절한 토큰 처리
- [ ] **인가**: 역할 확인 적용
- [ ] **레이트 리미팅**: 모든 엔드포인트에 활성화
- [ ] **HTTPS**: 운영 환경에서 강제
- [ ] **보안 헤더**: CSP, X-Frame-Options 설정
- [ ] **에러 처리**: 오류에 민감한 데이터 없음
- [ ] **로깅**: 민감한 데이터 로깅 없음
- [ ] **의존성**: 최신 상태, 취약점 없음
- [ ] **보안 자동 테스트**: 401·403·400·429 거부 테스트가 있다

---

**기억**: 보안은 선택사항이 아니다. 하나의 취약점이 전체 플랫폼을 위협할 수 있다. 의심스러울 때는 더 안전한 쪽을 선택한다.
