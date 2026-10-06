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

파일 헤더에는 날짜 필드를 두지 않는다(이력은 git이 정본). 함수 헤더는 공개 API와
동작이 자명하지 않은 함수에만 둔다.

```javascript
/*#############################################################################
FILE NAME   : 파일명.js
DESCRIPTION : 파일 역할 한 줄 요약
#############################################################################*/

/*=============================================================================
FUNCTION    : FunctionName
DESCRIPTION : 역할 설명
PARAMETERS  : type 인자명 - 설명
RETURNED    : 반환값 설명
=============================================================================*/
```

## 중괄호 스타일 — K&R (Allman 금지)

Allman 스타일은 **금지**한다. `return` 다음 줄에 `{`를 두면 ASI(Automatic Semicolon
Insertion)가 `return;`으로 끊어 `undefined`를 반환하기 때문이다. 여는 중괄호는 같은 줄에 둔다.

```javascript
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

배열·객체를 직접 변이하지 않고 스프레드로 새 값을 만든다. 규칙과 핫패스 예외는
[patterns.md](patterns.md)의 "불변성" 절이 정본이다.

## 에러 처리

```typescript
try {
    return await fetchData(id);
} catch (error: unknown) {
    if (error instanceof Error) { throw new Error(`loadData 실패: ${error.message}`); }
    throw new Error("loadData: 알 수 없는 에러");
}
```

- `catch (error: unknown)` — `any` 금지, `unknown`으로 수신 후 타입 좁히기
- Promise 체인에 `.catch()` 필수

## TypeScript 타입 시스템

### interface vs type

확장·구현할 객체 형태는 `interface`로, 유니온·교차·유틸리티 타입은 `type`으로 정의한다.

```typescript
interface User { id: string; email: string; }
type AdminUser = User & { role: "admin" | "member" };
```

### `any` 금지

타입을 모르는 값은 `any` 대신 `unknown`으로 받고, 타입 가드로 좁힌 뒤 쓴다.

```typescript
function parse(input: unknown): string {              /* `input: any` 금지 */
    if (typeof input === "object" && input !== null && "value" in input) {
        return String((input as { value: unknown }).value);
    }
    throw new Error("유효하지 않은 입력");
}
```

### 공개 API — 반환 타입 명시

export하는 함수·메서드에는 반환 타입을 적는다.
추론에 맡기면 구현 변경이 호출부 계약을 조용히 바꾼다.
모듈 내부 함수는 추론에 맡겨도 된다.

```typescript
export function ParseHeader(view: DataView): FrameHeader { ... }   /* `: FrameHeader` 생략 금지 */
```

### 읽기 전용 인자 — `Readonly<T>`

함수가 바꾸지 않는 객체·배열 인자는 `Readonly<T>`·`readonly T[]`로 받는다.
호출자는 인자가 변하지 않는다는 보장을 타입으로 얻는다.

```typescript
export function TotalQty(orders: readonly Order[]): Quantity { ... }
export function Render(config: Readonly<ViewConfig>): string { ... }
```

`Readonly<T>`는 얕은 보장이다. 중첩 객체까지 막아야 하면 별도 `DeepReadonly` 타입을 쓴다.
핫패스에서 재사용하는 버퍼는 이 규칙의 예외다. 기준은 [patterns.md](patterns.md)의 핫패스 예외를 따른다.

### 입력 검증 — Zod

외부 입력(API 응답, 폼 데이터)은 Zod 스키마로 검증하고, 타입은 `z.infer<typeof Schema>`로 스키마에서 얻는다.
예시는 [security.md](security.md)의 "입력 검증 (Zod)" 절에 있다.

## 디버그 출력

```javascript
console.log('[DEBUG]', variable);        /* 배포 전 제거 */
console.warn('[PROJECTNAME]', message);  /* 운영 경고 */
```

프로덕션 코드에서 `console.log` 금지 — 로깅 라이브러리 사용.
