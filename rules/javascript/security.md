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

## 프로토타입 오염 방지

사용자 객체를 깊은 병합하면 `__proto__` 키가 `Object.prototype`을 바꿔 모든 객체에 공격자 속성이 생긴다.

```typescript
/* BAD: 파싱한 JSON을 그대로 깊은 병합 */
deepMerge(config, JSON.parse(raw));   /* {"__proto__":{"isAdmin":true}} 로 오염 */

/* GOOD: 스키마로 허용 키만 통과시킨 뒤 새 객체를 만든다 */
const Patch   = z.object({ theme: z.enum(["light", "dark"]) }).strict();
const patch   = Patch.parse(JSON.parse(raw));
const updated = { ...config, ...patch };
```

- 직접 만든 병합·경로 설정 함수는 `__proto__`·`constructor`·`prototype` 키를 거부한다. 동적 키 맵은 `Map`이나 `Object.create(null)`을 쓴다.
- 파싱한 JSON을 스프레드(`{...parsed}`)로 펼치는 것은 안전하지만, 그 결과를 다시 깊은 병합에 넘기면 위험하다.

## 빌드 산출물과 SSR

- **운영 소스맵은 공개하지 않는다.** 소스맵은 원본 코드와 내부 경로를 드러낸다. 에러 추적 서비스에만 올린다
  (Next `productionBrowserSourceMaps: false`, Vite `build.sourcemap: "hidden"`).
- **SSR 템플릿 인젝션을 막는다.** 상태를 `<script>`에 `JSON.stringify` 그대로 심으면 `</script>`로 탈출할 수 있다.
  `serialize-javascript`를 쓰거나 `<`를 `\u003c`로 바꾼다. `dangerouslySetInnerHTML`·`v-html`에는 소독한 값만 넣는다.
- 브라우저 번들에 들어가는 환경변수(`NEXT_PUBLIC_*`, `VITE_*`)에는 비밀값을 두지 않는다. 번들은 누구나 읽는다.

## 서드파티 컴포넌트 감사

- UI 컴포넌트·위젯을 추가하기 전에 유지 상태, 설치 스크립트(`postinstall`), 네트워크 호출 여부를 확인한다.
- 리치 텍스트 에디터·마크다운 렌더러는 XSS 표면이다. 소독 옵션이 기본으로 켜져 있는지 확인한다. 잠금 파일을 커밋하고 CI는 `npm ci`를 쓴다.
- 브라우저 쪽 헤더·CSP·SRI 기준은 [web/security.md](../web/security.md)를 따른다.

## 민감정보

- 로그에는 비밀값을 남기지 않고 개인정보는 마스킹한 값만 남긴다(기준: `skills/sensitive-data-handling/SKILL.md`).
- `localStorage`·`sessionStorage`에는 토큰·비밀값·개인정보를 두지 않는다. Electron은 `safeStorage`(OS 키체인 연동)를 쓴다.

## 정적 보안 분석

`npm audit`, `npx snyk test`로 의존성 취약점을 확인한다.
