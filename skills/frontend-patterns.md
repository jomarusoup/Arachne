---
name: frontend-patterns
description: React·Next.js 프론트엔드 패턴 — 컴포넌트 합성, 상태 관리, 데이터 페칭, 성능 최적화(메모이제이션·가상화·코드 분할), 폼, 에러 바운더리, 접근성. 컴포넌트·상태·성능 원칙은 독립 데스크톱 UI로도 이식된다.
---

# 프론트엔드 개발 패턴

React·Next.js와 성능 좋은 UI를 위한 모던 패턴.

> 코드 예시는 React 기준이지만, **컴포넌트 합성·단방향 상태·메모이제이션·가상화·에러 경계** 같은
> 구조적 원칙은 프레임워크에 종속되지 않는다. 웹 클라이언트를 독립 데스크톱 프로그램(Tauri·Qt 등)으로
> 전환해도 동일한 사고가 적용된다.

## 언제 활성화하나

- React 컴포넌트 구축 (합성·props·렌더링)
- 상태 관리 (useState·useReducer·Context·Zustand)
- 데이터 페칭 (SWR·React Query·서버 컴포넌트)
- 성능 최적화 (메모이제이션·가상화·코드 분할)
- 폼 처리 (검증·제어 입력·Zod 스키마)
- 접근성 있는 반응형 UI 패턴

## 컴포넌트 패턴

### 상속보다 합성

```tsx
// 올바름: 컴포넌트 합성
interface CardProps {
    children: React.ReactNode;
    variant?: "default" | "outlined";
}

export function Card({ children, variant = "default" }: CardProps) {
    return <div className={`card card-${variant}`}>{children}</div>;
}

export function CardHeader({ children }: { children: React.ReactNode }) {
    return <div className="card-header">{children}</div>;
}

// 사용
<Card>
    <CardHeader>Title</CardHeader>
    <CardBody>Content</CardBody>
</Card>
```

### 컴파운드 컴포넌트 — Context로 암묵적 상태 공유

```tsx
const TabsContext = createContext<TabsContextValue | undefined>(undefined);

export function Tabs({ children, defaultTab }: TabsProps) {
    const [activeTab, setActiveTab] = useState(defaultTab);
    return (
        <TabsContext.Provider value={{ activeTab, setActiveTab }}>
            {children}
        </TabsContext.Provider>
    );
}

export function Tab({ id, children }: TabProps) {
    const context = useContext(TabsContext);
    if (!context) throw new Error("Tab must be used within Tabs");
    return (
        <button
            className={context.activeTab === id ? "active" : ""}
            onClick={() => context.setActiveTab(id)}
        >
            {children}
        </button>
    );
}
```

## 커스텀 훅 패턴

### 비동기 데이터 페칭 훅

```tsx
export function useQuery<T>(
    key: string,
    fetcher: () => Promise<T>,
    options?: UseQueryOptions<T>,
) {
    const [data, setData] = useState<T | null>(null);
    const [error, setError] = useState<Error | null>(null);
    const [loading, setLoading] = useState(false);

    const refetch = useCallback(async () => {
        setLoading(true);
        setError(null);
        try {
            const result = await fetcher();
            setData(result);
            options?.onSuccess?.(result);
        } catch (err) {
            const error = err as Error;
            setError(error);
            options?.onError?.(error);
        } finally {
            setLoading(false);
        }
    }, [fetcher, options]);

    useEffect(() => {
        if (options?.enabled !== false) refetch();
    }, [key, refetch, options?.enabled]);

    return { data, error, loading, refetch };
}
```

### 디바운스 훅 — 정리(cleanup) 필수

```tsx
export function useDebounce<T>(value: T, delay: number): T {
    const [debounced, setDebounced] = useState<T>(value);
    useEffect(() => {
        const handler = setTimeout(() => setDebounced(value), delay);
        return () => clearTimeout(handler);   // 정리 — 누수·중복 방지
    }, [value, delay]);
    return debounced;
}
```

## 상태 관리 — Context + Reducer

전역 상태는 불변 업데이트로. 시스템 코드의 단방향 데이터 흐름·불변 메시지 패싱과 같은 원리다.

```tsx
type Action =
    | { type: "SET_MARKETS"; payload: Market[] }
    | { type: "SELECT_MARKET"; payload: Market };

function reducer(state: State, action: Action): State {
    switch (action.type) {
        case "SET_MARKETS":
            return { ...state, markets: action.payload };   // 불변 — 새 객체
        case "SELECT_MARKET":
            return { ...state, selectedMarket: action.payload };
        default:
            return state;
    }
}

export function useMarkets() {
    const context = useContext(MarketContext);
    if (!context) throw new Error("useMarkets must be used within MarketProvider");
    return context;
}
```

## 성능 최적화

### 메모이제이션 — 측정 후 적용

```tsx
// 고비용 계산 메모
const sortedMarkets = useMemo(
    () => [...markets].sort((a, b) => b.volume - a.volume),  // 원본 불변
    [markets],
);

// 자식에 넘기는 함수 메모
const handleSearch = useCallback((query: string) => setSearchQuery(query), []);

// 순수 컴포넌트 메모
export const MarketCard = React.memo<MarketCardProps>(({ market }) => (
    <div className="market-card">
        <h3>{market.name}</h3>
    </div>
));
```

> 메모이제이션은 공짜가 아니다. 실제 리렌더 비용이 측정될 때만 적용한다 — 무분별한 `useMemo`는 노이즈다.

### 코드 분할·지연 로딩

```tsx
import { lazy, Suspense } from "react";

const HeavyChart = lazy(() => import("./HeavyChart"));

export function Dashboard() {
    return (
        <Suspense fallback={<ChartSkeleton />}>
            <HeavyChart data={data} />
        </Suspense>
    );
}
```

### 긴 리스트 가상화 — 보이는 것만 렌더

대용량 리스트는 화면에 보이는 행만 렌더한다. 시스템 코드의 윈도잉·페이지 캐시와 같은 사고다.

```tsx
import { useVirtualizer } from "@tanstack/react-virtual";

export function VirtualMarketList({ markets }: { markets: Market[] }) {
    const parentRef = useRef<HTMLDivElement>(null);
    const virtualizer = useVirtualizer({
        count: markets.length,
        getScrollElement: () => parentRef.current,
        estimateSize: () => 100,
        overscan: 5,
    });
    return (
        <div ref={parentRef} style={{ height: "600px", overflow: "auto" }}>
            <div style={{ height: `${virtualizer.getTotalSize()}px`, position: "relative" }}>
                {virtualizer.getVirtualItems().map((row) => (
                    <div
                        key={row.index}
                        style={{
                            position: "absolute",
                            top: 0,
                            width: "100%",
                            height: `${row.size}px`,
                            transform: `translateY(${row.start}px)`,
                        }}
                    >
                        <MarketCard market={markets[row.index]} />
                    </div>
                ))}
            </div>
        </div>
    );
}
```

## 폼 처리 — 제어 입력 + 검증

```tsx
export function CreateMarketForm() {
    const [formData, setFormData] = useState<FormData>({ name: "", description: "" });
    const [errors, setErrors] = useState<FormErrors>({});

    const validate = (): boolean => {
        const next: FormErrors = {};
        if (!formData.name.trim()) next.name = "이름은 필수입니다";
        else if (formData.name.length > 200) next.name = "이름은 200자 미만이어야 합니다";
        setErrors(next);
        return Object.keys(next).length === 0;
    };

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!validate()) return;
        await createMarket(formData);
    };

    return (
        <form onSubmit={handleSubmit}>
            <input
                value={formData.name}
                onChange={(e) => setFormData((prev) => ({ ...prev, name: e.target.value }))}
            />
            {errors.name && <span className="error">{errors.name}</span>}
            <button type="submit">생성</button>
        </form>
    );
}
```

> 외부 입력(폼·API 응답)은 Zod 스키마로 검증한다 — `rules/javascript/coding-style.md` 참고. 시스템 경계 검증과 같은 원칙.

## React 19 / 서버 컴포넌트 (App Router·RSC)

신규 코드 기준. (Arachne 스타일로 작성)

### 서버/클라이언트 컴포넌트 경계

```tsx
// 서버 컴포넌트 — 기본값, async, 자기 자신의 JS를 보내지 않음
export default async function ProductPage({ params }: { params: { id: string } }) {
    const product = await db.product.findUnique({ where: { id: params.id } });
    if (!product) notFound();
    return <ProductView product={product} />;
}

// 클라이언트 컴포넌트 — "use client"로 옵트인 (상호작용 경계)
"use client";
export function AddToCartButton({ productId }: { productId: string }) {
    const [pending, startTransition] = useTransition();
    return (
        <button disabled={pending} onClick={() => startTransition(() => addToCart(productId))}>
            {pending ? "담는 중..." : "장바구니"}
        </button>
    );
}
```

경계 규칙:
- 서버→클라이언트: 직렬화 가능한 props 또는 `children` 전달
- 클라이언트→서버: Server Action을 `<form action={...}>` 또는 이벤트 핸들러에서 호출
- **클라이언트 파일에서 서버 컴포넌트를 `import` 금지** — `children`으로 합성

### 폼 액션 — `useActionState` (신규 코드 권장)

```tsx
"use client";
import { useActionState } from "react";

const initial = { error: null as string | null };

async function updateUserAction(_prev: typeof initial, formData: FormData) {
    "use server";
    const parsed = UserSchema.safeParse(Object.fromEntries(formData));   // 서버 경계 검증 필수
    if (!parsed.success) return { error: "잘못된 입력" };
    await db.user.update({ where: { id: parsed.data.id }, data: parsed.data });
    return { error: null };
}

export function UserForm() {
    const [state, formAction, pending] = useActionState(updateUserAction, initial);
    return (
        <form action={formAction}>
            <input name="name" required />
            <button type="submit" disabled={pending}>저장</button>
            {state.error && <p role="alert">{state.error}</p>}
        </form>
    );
}
```

> Server Action 입력은 클라이언트 검증만 신뢰하지 말고 **서버에서 스키마 재검증**한다.

### 낙관적 UI — `useOptimistic`

```tsx
"use client";
import { useOptimistic } from "react";

export function MessageList({ messages }: { messages: Message[] }) {
    const [optimistic, addOptimistic] = useOptimistic(
        messages,
        (state, newMessage: Message) => [...state, newMessage],
    );

    async function send(formData: FormData) {
        const text = String(formData.get("text"));
        addOptimistic({ id: "pending", text, sender: "me" });   // 즉시 반영
        await saveMessage(text);                                // 확정은 서버 응답 후
    }

    return (
        <>
            <ul>{optimistic.map((m) => <li key={m.id}>{m.text}</li>)}</ul>
            <form action={send}><input name="text" /><button type="submit">전송</button></form>
        </>
    );
}
```

### 상태 위치 결정 트리

```
한 컴포넌트만 사용?            → 그 안에서 useState
부모 + 일부 자손?             → 가장 가까운 공통 조상으로 끌어올림
먼 가지들 + 저빈도 읽기?       → React Context (theme·auth·locale)
  (theme·auth·locale)
트리 전체 고빈도 갱신?         → 외부 스토어 (Zustand·Jotai·Redux Toolkit)
서버에서 파생?                → 서버 상태 라이브러리 (TanStack Query·SWR·RSC fetch)
```

> 대부분의 페이지는 Context·전역 스토어가 필요 없다. 중복 끌어올림이 고통스러워지기 전엔 추상화를 미룬다.

### 데이터 워터폴 제거 (성능)

```tsx
const a = await getA(); const b = await getB();          // BAD — 직렬 대기
const [a, b] = await Promise.all([getA(), getB()]);      // GOOD — 병렬
```

> 서버에서 같은 요청이 반복되면 `React.cache()`로 중복 제거. 배럴 임포트(`index.ts` 재노출)는
> 트리셰이킹을 저해하므로 직접 임포트를 선호.

## 에러 바운더리 — UI 격리

```tsx
export class ErrorBoundary extends React.Component<Props, ErrorBoundaryState> {
    state: ErrorBoundaryState = { hasError: false, error: null };

    static getDerivedStateFromError(error: Error): ErrorBoundaryState {
        return { hasError: true, error };
    }

    componentDidCatch(error: Error, info: React.ErrorInfo) {
        console.warn("[PROJ] error boundary caught", error, info);   // 운영 경고
    }

    render() {
        if (this.state.hasError) {
            return (
                <div className="error-fallback">
                    <h2>문제가 발생했습니다</h2>
                    <button onClick={() => this.setState({ hasError: false })}>다시 시도</button>
                </div>
            );
        }
        return this.props.children;
    }
}
```

## 애니메이션 — Framer Motion

```tsx
import { motion, AnimatePresence } from "framer-motion";

export function AnimatedMarketList({ markets }: { markets: Market[] }) {
    return (
        <AnimatePresence>
            {markets.map((market) => (
                <motion.div
                    key={market.id}
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: -20 }}
                    transition={{ duration: 0.3 }}
                >
                    <MarketCard market={market} />
                </motion.div>
            ))}
        </AnimatePresence>
    );
}
```

> 모션 디테일(enter/exit 분리, press scale, transition 범위)은 스킬 `make-interfaces-feel-better` 참고.

## 접근성 패턴

### 키보드 내비게이션

```tsx
const handleKeyDown = (e: React.KeyboardEvent) => {
    switch (e.key) {
        case "ArrowDown":
            e.preventDefault();
            setActiveIndex((i) => Math.min(i + 1, options.length - 1));
            break;
        case "ArrowUp":
            e.preventDefault();
            setActiveIndex((i) => Math.max(i - 1, 0));
            break;
        case "Enter":
            e.preventDefault();
            onSelect(options[activeIndex]);
            break;
        case "Escape":
            setIsOpen(false);
            break;
    }
};
```

### 포커스 관리 — 모달 열고 닫을 때 복원

```tsx
export function Modal({ isOpen, onClose, children }: ModalProps) {
    const modalRef = useRef<HTMLDivElement>(null);
    const previousFocusRef = useRef<HTMLElement | null>(null);

    useEffect(() => {
        if (isOpen) {
            previousFocusRef.current = document.activeElement as HTMLElement;
            modalRef.current?.focus();
        } else {
            previousFocusRef.current?.focus();   // 닫을 때 이전 포커스 복원
        }
    }, [isOpen]);

    return isOpen ? (
        <div
            ref={modalRef}
            role="dialog"
            aria-modal="true"
            tabIndex={-1}
            onKeyDown={(e) => e.key === "Escape" && onClose()}
        >
            {children}
        </div>
    ) : null;
}
```

> **기억할 것**: 모던 프론트엔드 패턴은 유지보수 가능하고 성능 좋은 UI를 만든다.
> 프로젝트 복잡도에 맞는 패턴을 고른다. 디자인 품질 기준은 `rules/web/design-quality.md` 참고.
