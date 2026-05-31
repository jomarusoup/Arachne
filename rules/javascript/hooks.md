---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
---
# JavaScript / TypeScript 훅

> [common/hooks.md](../common/hooks.md) 를 확장한다.

## PostToolUse — 편집 후 자동 실행

- **Prettier** — JS/TS 파일 편집 후 자동 포맷
- **tsc** — `.ts`/`.tsx` 편집 후 타입 검사
- **console.log 경고** — 편집된 파일에서 `console.log` 감지 시 경고

## Stop 훅

- **console.log 감사** — 세션 종료 전 수정된 파일 전체의 `console.log` 점검

## 커밋 전 체크

```bash
prettier --check src/
tsc --noEmit
eslint src/
npm test -- --passWithNoTests
```
