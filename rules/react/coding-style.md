---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---
# React 코딩 스타일

> [javascript/coding-style.md](../javascript/coding-style.md)를 React 컴포넌트 관점으로 확장한다.
> 상세 예시는 스킬 `frontend-patterns`에 둔다.

## Hooks 규칙

- Hook은 컴포넌트·커스텀 훅의 최상위에서만 호출한다.
- `if`·`for`·조기 `return` 뒤에서 Hook을 호출하지 않는다. 호출 순서가 렌더마다 같아야 한다.
- Hook을 호출하는 함수의 이름은 `use`로 시작한다.
- 의존성 배열에는 effect 안에서 읽는 반응형 값을 모두 넣는다. 린트(`react-hooks/exhaustive-deps`) 경고를 끄지 않는다.

```tsx
/* BAD: 조건부 Hook */
if (!user) return null;
const [tab, setTab] = useState("info");

/* GOOD: Hook 먼저, 분기는 그 뒤 */
const [tab, setTab] = useState("info");
if (!user) return null;
```

## 컴포넌트 작성

- 컴포넌트 이름은 `PascalCase`, 파일 하나에 export 컴포넌트 하나를 둔다.
- props 타입은 `interface XxxProps`로 선언하고 `Readonly`로 받는다.
- 렌더 함수는 순수해야 한다. 렌더 중에 props·state·외부 변수를 변경하지 않는다.
- 리스트 `key`는 안정적인 고유 id를 쓴다. 순서가 바뀌는 리스트에 배열 인덱스를 쓰지 않는다.

```tsx
interface OrderRowProps {
    order:    Order;
    onCancel: (id: OrderId) => void;
}

export function OrderRow({ order, onCancel }: Readonly<OrderRowProps>): JSX.Element {
    return <tr>...</tr>;
}
```

## 서버·클라이언트 경계 (RSC)

- 서버 컴포넌트가 기본이다. 상호작용이 필요한 가장 작은 단위에만 `"use client"`를 붙인다.
- 서버 컴포넌트에서 브라우저 API·이벤트 핸들러·state Hook을 쓰지 않는다.
- 서버에서 클라이언트로 넘기는 props는 직렬화 가능한 값만 둔다. 함수·클래스 인스턴스를 넘기지 않는다.
- 비밀값을 읽는 모듈에는 `import "server-only"`를 둔다. 클라이언트 번들 유입을 빌드 단계에서 막는다.
- `"use server"` 함수는 공개 엔드포인트다. 입력 검증과 권한 확인을 함수 안에서 다시 한다.

## 이름 규칙

| 대상 | 형식 | 예시 |
|---|---|---|
| 컴포넌트 | `PascalCase` | `OrderBook` |
| 커스텀 훅 | `useXxx` | `useFeedStore` |
| 이벤트 핸들러 prop | `onXxx` | `onSubmit` |
| 내부 핸들러 | `handleXxx` | `handleSubmit` |
| boolean prop | `isXxx`·`hasXxx` | `isDisabled` |
