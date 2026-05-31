---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
---
# JavaScript / TypeScript 보안

> [common/security.md](../common/security.md) 를 확장한다.

## 비밀값 관리

```typescript
/* BAD: 하드코딩 */
const apiKey = "sk-proj-xxxxx";

/* GOOD: 환경변수 */
const apiKey = process.env.API_KEY;
if (!apiKey) {
    throw new Error("API_KEY 환경변수 필요");
}
```

## XSS 방지

```typescript
/* BAD: innerHTML에 사용자 입력 직접 삽입 */
element.innerHTML = userInput;

/* GOOD: textContent 또는 DOMPurify */
element.textContent = userInput;
element.innerHTML = DOMPurify.sanitize(userInput);
```

## SQL 인젝션 방지

```typescript
/* BAD */
const query = `SELECT * FROM users WHERE id = ${userId}`;

/* GOOD: 파라미터화 쿼리 */
const query  = "SELECT * FROM users WHERE id = $1";
const result = await db.query(query, [userId]);
```

## 입력 검증 (Zod)

```typescript
import { z } from "zod";

const Schema = z.object({
    email: z.string().email(),
    age:   z.number().int().min(0).max(150),
});

const validated = Schema.parse(rawInput); /* 실패 시 throw */
```

## 정적 보안 분석

```bash
npm audit
npx snyk test
```
