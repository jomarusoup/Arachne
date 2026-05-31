---
paths:
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.ts"
  - "**/*.tsx"
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

ASI(Automatic Semicolon Insertion) 문제로 Allman 스타일 **금지**.

```javascript
/* BAD: ASI가 return 뒤 세미콜론 삽입 → undefined 반환 */
return
{
    data: "success"
};

/* GOOD: K&R */
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
- 한 줄에 변수 하나 (공통 규칙 준수)

## 네이밍 (JS 전용)

- 함수·메서드: `PascalCase` (`RenderList`, `FetchData`)
- 지역 변수·인자: `snake_case`
- 객체 속성·JSON 키: `camelCase`
- 전역 변수: `g_SnakeCase` (공통 규칙 준수)
- 상수: `SCREAMING_SNAKE_CASE`
- 클래스: `PascalCase`

## 불변성

```javascript
/* BAD: 직접 변이 */
tasks.push(newTask);
task.done = true;

/* GOOD: 불변 연산 */
const tasks    = [...g_Tasks, newTask];
const updated  = { ...task, done: true };
```

## 에러 처리

- `async/await` 에 `try/catch` 필수
- Promise 체인에 `.catch()` 필수
- `console.error` 로 에러 로깅 (조용히 무시 금지)

## 디버그 출력

```javascript
console.log('[DEBUG]', variable);       /* 배포 전 제거 */
console.warn('[PROJECTNAME]', message); /* 운영 경고 */
```

## TypeScript 추가 규칙

- `any` 타입 금지 (부득이한 경우 `// eslint-disable-line` 주석 필수)
- 인터페이스 이름: `I` 접두사 없이 `PascalCase`
- `as` 타입 단언 최소화 — 타입 가드 우선
