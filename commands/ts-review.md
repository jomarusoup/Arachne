---
description: async 정확성·타입 안전성·tsconfig 엄격도·Node 보안·타입 설계·바이너리 처리 종합 TypeScript 리뷰 — typescript-reviewer 에이전트 호출
---

# /ts-review — TypeScript 코드 리뷰

**typescript-reviewer** 에이전트를 호출해 TypeScript 언어·타입 설계·Node 런타임 관점의 종합 리뷰를 수행한다.

## 동작

1. **변경 식별** — `git diff`로 수정된 `.ts`·`.tsx`·`tsconfig*.json` 탐색
2. **정적 분석** — `tsc --noEmit` · `eslint`(@typescript-eslint) 실행
3. **보안 점검** — `child_process` 명령 주입, 경로 순회, `eval`류, 비밀 하드코딩
4. **async 정확성** — floating promise, `forEach(async ...)`, unhandled rejection, 응답 경쟁
5. **타입 설계** — `any`·`as`·`!` 남용, 엄격도 약화, branded 수치 타입, 판별 유니온
6. **바이너리 처리** — `DataView` 엔디언, 64비트 정수, 핫패스 할당, 경계 검사
7. **리포트** — 심각도별 분류

## 언제 사용하나

- `.ts`·`.tsx` 모듈, Node 서버 코드, Electron main·preload 작성·수정 후, 커밋 전
- tsconfig·린트 설정 변경 시
- 바이너리 프로토콜 디코더·스트림 수신 코드 변경 시

`.tsx` 컴포넌트 변경이면 `/react-review`와 함께 실행한다. 렌더링·Hooks·a11y·XSS는 그쪽 담당이다.

## 리뷰 카테고리

### CRITICAL (반드시 수정)
- `exec`에 사용자 입력 문자열 결합 (명령 주입)
- 검증 없는 외부 경로 접근 (경로 순회)
- floating promise, `forEach(async ...)`로 실패 유실

### HIGH (수정 권장)
- 외부 입력의 `any`·검증 없는 `as`·위험한 `!`
- `strict` 계열 옵션 비활성화
- 가격·수량을 부동소수 `number`로 처리 (→ 정수 스케일·`bigint`·branded 타입)
- boolean 플래그 조합 상태 (→ 판별 유니온)
- `DataView` 엔디언 미지정, 64비트 값을 `number`로 읽음, 메시지마다 버퍼 할당

### MEDIUM (검토)
- export 함수의 반환 타입 누락, 읽기 전용 인자에 `Readonly<T>` 미사용
- 사유 없는 `@ts-ignore`, 문자열 throw, 매직 오프셋

## 자동 검사

```bash
tsc --noEmit                       # 타입 검사
eslint . --ext .ts,.tsx            # @typescript-eslint (no-floating-promises 포함 권장)
grep -rnE 'as any|: any\b|@ts-ignore' src/
```

## 흔한 수정 패턴

```typescript
// async 순회
items.forEach(async (it) => await save(it));            // BAD
await Promise.all(items.map((it) => save(it)));         // GOOD

// 명령 실행
exec(`convert ${name} out.png`);                         // BAD
execFile("convert", [name, "out.png"]);                  // GOOD

// 가격 표현
const price: number = 1234.5;                            // BAD
const price = 123450n as PriceTicks;                     // GOOD (틱 단위 정수)

// 바이너리 읽기
view.getUint32(off);                                     // BAD (빅엔디언 기본)
view.getUint32(off, true);                               // GOOD (프로토콜에 맞춰 명시)
```

## 승인 기준

| 상태 | 조건 |
| ---- | ---- |
| 승인 | CRITICAL·HIGH 없음 |
| 경고 | MEDIUM만 존재 (주의 후 머지) |
| 차단 | CRITICAL·HIGH 존재 |

## 연계

- 렌더링·Hooks·a11y·XSS는 `/react-review`
- 커밋 전 검증은 `/verify`
- 규칙 `rules/javascript/*.md`, 스킬 `error-handling` · `json-contracts` · `vite-patterns` · `react-testing`
- 에이전트: `agents/typescript-reviewer.md`
