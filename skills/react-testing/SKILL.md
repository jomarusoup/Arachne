---
name: react-testing
description: React 컴포넌트·훅 테스트 — Testing Library 쿼리 우선순위, userEvent 상호작용, MSW 네트워크 모킹, 커스텀 훅 테스트(renderHook), 비동기 대기, 외부 스토어 테스트, 스냅샷 남용 방지. Vitest·Jest 공통. 대상 경로 — **/*.test.tsx, **/*.spec.tsx, **/__tests__/**. 키워드 — React Testing Library, RTL, userEvent, MSW, renderHook, 컴포넌트 테스트.
---

# React 테스트

사용자가 보는 결과를 검증하는 React 테스트 작성법이다.
규칙 요약은 `rules/react/testing.md`에 있고, 이 스킬은 예시와 설정을 담는다.

## 언제 사용하나

- React 컴포넌트·커스텀 훅의 테스트를 새로 쓰거나 고칠 때
- 테스트가 구현 변경마다 깨지는 원인을 찾을 때
- 네트워크·타이머·외부 스토어에 의존하는 컴포넌트를 테스트할 때

### 언제 사용하지 않나

- 브라우저 전체 흐름 → `/e2e` (Playwright)
- 순수 함수·도메인 로직 → 일반 단위 테스트 (`rules/javascript/testing.md`)

## 어떻게

### 1. 설정 (Vitest 기준)

```typescript
// vitest.config.ts
export default defineConfig({
    test: {
        environment: "jsdom",
        setupFiles:  ["./src/test/setup.ts"],
        globals:     true,
    },
});

// src/test/setup.ts
import "@testing-library/jest-dom/vitest";
import { afterAll, afterEach, beforeAll } from "vitest";
import { server } from "./msw-server";

beforeAll(() => server.listen({ onUnhandledRequest: "error" }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

`onUnhandledRequest: "error"`는 모킹하지 않은 요청을 실패로 만든다. 실제 네트워크 유출을 막는다.

### 2. 쿼리 우선순위

| 순위 | 쿼리 | 비고 |
|---|---|---|
| 1 | `getByRole("button", { name: "저장" })` | 접근성 트리 기준. 가장 먼저 시도한다 |
| 2 | `getByLabelText("이메일")` | 폼 입력 |
| 3 | `getByPlaceholderText` | 라벨이 없을 때만 |
| 4 | `getByText` | 비상호작용 텍스트 |
| 5 | `getByDisplayValue` | 채워진 입력 |
| 6 | `getByAltText`·`getByTitle` | 이미지·보조 텍스트 |
| 7 | `getByTestId` | 최후 수단 |

변형 선택:

| 접두사 | 없을 때 | 용도 |
|---|---|---|
| `getBy*` | 예외 | 지금 있어야 하는 요소 |
| `queryBy*` | `null` | 없음을 확인할 때 |
| `findBy*` | 시간 초과 예외 | 비동기로 나타날 요소 |

`screen`을 통해 쿼리한다. `render`가 반환한 구조 분해 쿼리보다 일관된다.

### 3. userEvent

`fireEvent`는 이벤트 하나만 보낸다. `userEvent`는 포커스·키 입력·클릭 순서를 실제처럼 재현한다.

```typescript
const user = userEvent.setup();          // 테스트마다 render 전에 생성
await user.click(screen.getByRole("button", { name: "열기" }));
await user.type(screen.getByLabelText("수량"), "100");
await user.keyboard("{Escape}");
await user.tab();                        // 키보드 내비게이션 검증
```

가짜 타이머와 함께 쓰면 `userEvent.setup({ advanceTimers: vi.advanceTimersByTime })`를 지정한다.

### 4. MSW — 네트워크 모킹

fetch 함수를 모킹하지 않고 요청을 네트워크 계층에서 가로챈다.
컴포넌트의 실제 페칭 코드가 그대로 실행된다.

```typescript
// src/test/msw-server.ts
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

export const handlers = [
    http.get("/api/orders", () => HttpResponse.json([{ id: "o1", qty: "100" }])),
];
export const server = setupServer(...handlers);
```

테스트별로 응답을 바꿀 때는 `server.use`로 덮어쓴다. `afterEach`의 `resetHandlers`가 원복한다.

```typescript
test("주문_조회_실패시_오류_메시지_표시", async () => {
    /* Arrange */
    server.use(http.get("/api/orders", () => new HttpResponse(null, { status: 500 })));
    render(<OrderList />);

    /* Act + Assert */
    expect(await screen.findByRole("alert")).toHaveTextContent("주문을 불러오지 못했습니다");
});
```

### 5. 커스텀 훅 테스트

UI 없이 훅만 검증할 때 `renderHook`을 쓴다. Provider가 필요하면 `wrapper`로 감싼다.

```typescript
test("디바운스_지연_전에는_이전_값_유지", () => {
    /* Arrange */
    vi.useFakeTimers();
    const { result, rerender } = renderHook(
        ({ value }) => useDebounce(value, 300),
        { initialProps: { value: "a" } },
    );

    /* Act */
    rerender({ value: "ab" });
    act(() => { vi.advanceTimersByTime(299); });

    /* Assert */
    expect(result.current).toBe("a");
    act(() => { vi.advanceTimersByTime(1); });
    expect(result.current).toBe("ab");
    vi.useRealTimers();
});
```

훅이 사용자에게 보이는 동작을 만든다면 훅 단독 테스트보다 그 훅을 쓰는 컴포넌트 테스트를 우선한다.

### 6. 외부 스토어·스트림 구독 컴포넌트

`useSyncExternalStore`로 구독하는 컴포넌트는 테스트용 스토어를 주입하고 값을 밀어 넣는다.

```typescript
test("가격_갱신시_셀_표시값_변경", async () => {
    /* Arrange */
    const store = CreateFeedStore();
    render(<PriceCell symbol="AAA" store={store} />);

    /* Act */
    act(() => { store.Push({ symbol: "AAA", priceTicks: 12345n }); });

    /* Assert */
    expect(screen.getByText("123.45")).toBeInTheDocument();
});
```

스토어가 `requestAnimationFrame`으로 묶어 알린다면 가짜 타이머로 프레임을 진행시킨다.

### 7. 스냅샷 남용 방지

- 컴포넌트 트리 전체 스냅샷은 쓰지 않는다. 의미 없는 마크업 변경에도 깨지고, 리뷰어는 `-u`로 갱신해 버린다.
- 검증하려는 속성을 명시적으로 단언한다 (`toHaveTextContent`, `toBeDisabled`, `toHaveAttribute`).
- 스냅샷은 작고 안정적인 직렬화 결과(포맷 함수 출력)에만 `toMatchInlineSnapshot`으로 쓴다.

## 예시 — 폼 제출 흐름

```typescript
test("유효한_입력으로_제출시_성공_메시지", async () => {
    /* Arrange */
    const user = userEvent.setup();
    server.use(http.post("/api/orders", () => HttpResponse.json({ id: "o2" }, { status: 201 })));
    render(<OrderForm />);

    /* Act */
    await user.type(screen.getByLabelText("수량"), "10");
    await user.click(screen.getByRole("button", { name: "주문" }));

    /* Assert */
    expect(await screen.findByRole("status")).toHaveTextContent("주문이 접수되었습니다");
    expect(screen.getByRole("button", { name: "주문" })).toBeEnabled();
});
```

## 흔한 실수

| 증상 | 원인 | 해결 |
|---|---|---|
| `act(...)` 경고 | 비동기 갱신을 기다리지 않음 | `findBy*`·`await user.*`로 끝까지 기다린다 |
| 테스트 간 상태 누출 | MSW 핸들러·스토어 미초기화 | `resetHandlers`, 테스트마다 새 스토어 |
| `getByRole` 실패 | 접근 가능한 이름 없음 | 마크업에 라벨·`aria-label`을 추가한다 |
| 간헐 실패 | 고정 `setTimeout` 대기 | `findBy*`·가짜 타이머로 바꾼다 |
| `waitFor` 안 클릭 | 재시도마다 부수효과 반복 | 동작은 밖에서, 단언만 `waitFor` 안에 둔다 |
