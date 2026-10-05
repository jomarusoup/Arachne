---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---
# React 패턴

> [javascript/patterns.md](../javascript/patterns.md)를 확장한다.
> 상세 예시는 스킬 `frontend-patterns`에 둔다.

## useEffect를 쓰지 않아도 되는 경우

effect는 React 바깥 시스템(네트워크·구독·DOM·타이머)과 동기화할 때만 쓴다.

| 하려는 일 | effect 대신 |
|---|---|
| props·state로 계산되는 값 | 렌더 중에 직접 계산한다. 비싸면 `useMemo` |
| 사용자 이벤트에 대한 반응 | 이벤트 핸들러 안에서 처리한다 |
| props가 바뀔 때 state 초기화 | 부모에서 `key`를 바꿔 다시 마운트한다 |
| 부모에 변경 알림 | 같은 핸들러에서 부모 콜백을 호출한다 |
| 데이터 페칭 | 서버 컴포넌트·TanStack Query 같은 페칭 계층을 쓴다 |

## cleanup

- 구독·타이머·이벤트 리스너·소켓을 여는 effect는 반드시 정리 함수를 반환한다.
- 비동기 요청은 `AbortController`로 취소한다. 언마운트 뒤 늦게 온 응답이 state를 덮지 않게 한다.
- 개발 모드 StrictMode는 effect를 두 번 실행한다. 두 번 실행해도 결과가 같아야 정리가 올바른 것이다.

```tsx
useEffect(() => {
    const ctrl = new AbortController();
    fetchQuote(symbol, { signal: ctrl.signal }).then(setQuote).catch(IgnoreAbort);
    return () => ctrl.abort();
}, [symbol]);
```

## stale closure

- effect·콜백이 캡처한 값은 그 렌더 시점의 값이다. 타이머·구독 안에서 오래된 state를 읽기 쉽다.
- 이전 값에 기반한 갱신은 함수형 업데이트(`setCount((prev) => prev + 1)`)로 쓴다.
- 최신 값만 필요하고 재구독은 원하지 않으면 `useRef`에 최신 값을 담아 읽는다.

## 외부 스토어 — `useSyncExternalStore`

React 바깥에서 갱신되는 데이터(데이터 스트림 수신 버퍼·WebSocket·브라우저 API)는
`useSyncExternalStore`로 구독한다. `useEffect` + `setState` 조합은 tearing과 누락 갱신을 만든다.

```tsx
const price = useSyncExternalStore(
    feedStore.subscribe,                      // (onChange) => unsubscribe
    () => feedStore.getPrice(symbol),         // 같은 값이면 같은 참조를 반환
);
```

- `getSnapshot`은 값이 그대로면 같은 참조를 반환해야 한다. 매번 새 객체를 만들면 무한 렌더가 된다.
- 고빈도 스트림은 스토어 안에서 묶어(프레임당 1회 등) 알린다. 메시지마다 알리지 않는다.
- 선택자로 필요한 조각만 구독한다. 전체 스냅샷 구독은 모든 소비자를 리렌더한다.

## 상태 위치

| 사용 범위 | 위치 |
|---|---|
| 한 컴포넌트 | 그 컴포넌트의 `useState`·`useReducer` |
| 부모와 일부 자손 | 가장 가까운 공통 조상 |
| 먼 가지·저빈도 갱신(테마·인증·로캘) | Context |
| 고빈도 갱신·스트림 데이터 | 외부 스토어 + `useSyncExternalStore` 선택자 |
| 서버에서 온 데이터 | 서버 상태 계층(RSC·TanStack Query) |
| URL로 공유할 상태(필터·페이지) | 검색 파라미터 |

같은 데이터를 두 곳에 저장하지 않는다. 하나에서 파생한다.
