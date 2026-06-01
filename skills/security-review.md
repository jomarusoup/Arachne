---
name: security-review
description: 인증 추가·사용자 입력 처리·비밀값 작업·API 엔드포인트 생성·결제/민감한 기능 구현 시 사용. 포괄적인 보안 체크리스트와 패턴 제공.
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
await db.query('SELECT * FROM users WHERE email = $1', [userEmail])
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

### 9. 의존성 보안

```bash
# 취약점 확인
npm audit

# 자동으로 수정 가능한 이슈 수정
npm audit fix

# 오래된 패키지 확인
npm outdated
```

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

---

**기억**: 보안은 선택사항이 아니다. 하나의 취약점이 전체 플랫폼을 위협할 수 있다. 의심스러울 때는 더 안전한 쪽을 선택한다.
