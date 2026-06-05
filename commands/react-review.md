---
description: 렌더링 정확성·Hooks 규칙·접근성·XSS·성능 종합 React/Next 리뷰 — react-reviewer 에이전트 호출
---

# /react-review — React/Next 코드 리뷰

**react-reviewer** 에이전트를 호출해 웹 프론트엔드 특화 종합 리뷰를 수행한다.

## 동작

1. **변경 식별** — `git diff`로 수정된 `.jsx`·`.tsx`·`.ts`·`.js` 탐색
2. **정적 분석** — `eslint`(react-hooks·jsx-a11y) · `tsc --noEmit` · `prettier --check` 실행
3. **보안 점검** — XSS(`dangerouslySetInnerHTML`), 클라이언트 번들 비밀 노출, Server Action 입력 검증
4. **렌더링·Hooks** — 조건부 Hook, 의존성 배열, 파생 상태, key 안정성
5. **접근성** — alt·라벨·키보드·포커스 관리
6. **리포트** — 심각도별 분류

## 언제 사용하나

- React/Next 컴포넌트 작성·수정 후, 커밋 전
- 프론트엔드 코드가 포함된 PR 리뷰
- 새 웹 코드베이스 온보딩

## 리뷰 카테고리

### CRITICAL (반드시 수정)
- 미살균 `dangerouslySetInnerHTML` (XSS)
- 클라이언트 번들(`NEXT_PUBLIC_`/`VITE_`)에 비밀 노출
- Server Action·API 입력 미검증 (서버 경계)
- 조건부 Hook 호출 (`if`/`for`/조기 return 뒤)

### HIGH (수정 권장)
- `useEffect`로 파생 상태 저장, 배열 인덱스 key
- 의존성 배열 누락·과잉
- 접근성: alt 누락, `div onClick`, 라벨 없는 입력, 포커스 미복원
- 성능: 데이터 워터폴(→ `Promise.all`), 긴 리스트 비가상화

### MEDIUM (검토)
- 측정 없는 과잉 메모이제이션, cleanup 누락 구독·타이머
- 컴포넌트 과대, prop drilling 과다, 매직 값

## 자동 검사

```bash
eslint . --ext .js,.jsx,.ts,.tsx   # react-hooks·jsx-a11y 플러그인 권장
tsc --noEmit                       # 타입 검사
prettier --check .                 # 포맷
npx @axe-core/cli <url>            # 접근성 자동 점검 (가능 시)
npm run build                      # 번들·빌드 오류
```

## 흔한 수정 패턴

```jsx
// 파생 상태: effect 대신 직접 계산
useEffect(() => setFull(`${first} ${last}`), [first, last]);  // BAD
const full = `${first} ${last}`;                              // GOOD

// 데이터 워터폴 제거
const a = await getA(); const b = await getB();               // BAD (직렬)
const [a, b] = await Promise.all([getA(), getB()]);           // GOOD

// 접근성: 버튼은 button
<div onClick={f}>저장</div>                                   // BAD
<button onClick={f}>저장</button>                             // GOOD
```

## 승인 기준

| 상태 | 조건 |
| ---- | ---- |
| 승인 | CRITICAL·HIGH 없음 |
| 경고 | MEDIUM만 존재 (주의 후 머지) |
| 차단 | CRITICAL·HIGH 존재 |

## 연계

- Python·백엔드 관심사는 `/python-review`·`/fastapi-review`
- 커밋 전 검증은 `/verify`
- 상세 패턴은 스킬 `frontend-patterns` · `make-interfaces-feel-better`, 규칙 `rules/web/design-quality.md`
- 에이전트: `agents/react-reviewer.md`
