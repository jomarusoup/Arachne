---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
---
# JavaScript / TypeScript 코딩 스타일

> [common/coding-style.md](../common/coding-style.md) 를 확장한다.

## 헤더 형식

`/* */` 블록 주석 지원 → C 스타일 그대로 사용.

```javascript
/*#############################################################################
FILE NAME   : 파일명.js
DESCRIPTION : 파일 역할 한 줄 요약
DATA        : YYYY-MM-DD
Modification: YYYY-MM-DD
#############################################################################*/

/*=============================================================================
FUNCTION    : FunctionName
DESCRIPTION : 역할 설명
PARAMETERS  : type 인자명 - 설명
RETURNED    : 반환값 설명
=============================================================================*/
```

## 중괄호 스타일 — K&R (Allman 금지)

ASI(Automatic Semicolon Insertion) 문제로 Allman 스타일 **금지**:

```javascript
/* BAD: return 뒤 ASI → undefined 반환 */
return
{
    data: "success"
};

/* GOOD */
return {
    data: "success"
};
```

## 변수 선언

```javascript
/* 전역 변수 — g_ 접두사 + 열 맞춤 */
let g_Tasks     = [];
let g_Settings  = {};
let g_EditingId = null;
```

- `const` 우선, 재할당 필요 시 `let`, `var` 금지

## 불변성

```javascript
/* BAD: 직접 변이 */
tasks.push(newTask);
task.done = true;

/* GOOD: 불변 연산 */
const tasks   = [...g_Tasks, newTask];
const updated = { ...task, done: true };
```

## 에러 처리

```typescript
async function loadData(id: string): Promise<Data> {
    try {
        return await fetchData(id);
    } catch (error: unknown) {
        if (error instanceof Error) {
            throw new Error(`loadData 실패: ${error.message}`);
        }
        throw new Error("loadData: 알 수 없는 에러");
    }
}
```

- `catch (error: unknown)` — `any` 금지, `unknown`으로 수신 후 타입 좁히기
- Promise 체인에 `.catch()` 필수

## TypeScript 타입 시스템

### interface vs type

```typescript
/* 확장·구현 가능한 객체 형태 → interface */
interface User {
    id:    string;
    email: string;
}

/* 유니온·교차·유틸리티 타입 → type */
type UserRole    = "admin" | "member";
type AdminUser   = User & { role: UserRole };
```

### `any` 금지

```typescript
/* BAD */
function parse(input: any) { return input.value; }

/* GOOD: unknown으로 수신 후 타입 가드 */
function parse(input: unknown): string {
    if (typeof input === "object" && input !== null && "value" in input) {
        return String((input as { value: unknown }).value);
    }
    throw new Error("유효하지 않은 입력");
}
```

### 입력 검증 — Zod

외부 입력(API 응답, 폼 데이터)은 Zod로 스키마 검증:

```typescript
import { z } from "zod";

const UserSchema = z.object({
    email: z.string().email(),
    age:   z.number().int().min(0).max(150),
});

type User = z.infer<typeof UserSchema>;

const user: User = UserSchema.parse(rawInput);
```

## 디버그 출력

```javascript
console.log('[DEBUG]', variable);        /* 배포 전 제거 */
console.warn('[PROJECTNAME]', message);  /* 운영 경고 */
```

프로덕션 코드에서 `console.log` 금지 — 로깅 라이브러리 사용.
