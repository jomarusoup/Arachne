---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
---
# JavaScript / TypeScript 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.

## API 응답 포맷

```typescript
interface ApiResponse<T> {
    success: boolean;
    data?:   T;
    error?:  string;
    meta?: {
        total: number;
        page:  number;
        limit: number;
    };
}
```

## Repository 패턴

```typescript
interface Repository<T> {
    findAll(filters?: Filters): Promise<T[]>;
    findById(id: string):       Promise<T | null>;
    create(data: CreateDto):    Promise<T>;
    update(id: string, data: UpdateDto): Promise<T>;
    delete(id: string):         Promise<void>;
}
```

## Custom Hook (React)

```typescript
export function useDebounce<T>(value: T, delay: number): T {
    const [debouncedValue, setDebouncedValue] = useState<T>(value);

    useEffect(() => {
        const handler = setTimeout(() => setDebouncedValue(value), delay);
        return () => clearTimeout(handler);
    }, [value, delay]);

    return debouncedValue;
}
```

## 불변 상태 업데이트

```typescript
/* BAD: 변이 */
state.items.push(newItem);
state.user.name = "new";

/* GOOD: 불변 */
const items = [...state.items, newItem];
const user  = { ...state.user, name: "new" };
```

## 에러 클래스

```typescript
class AppError extends Error {
    constructor(
        message: string,
        public readonly code: string,
        public readonly status: number = 500
    ) {
        super(message);
        this.name = "AppError";
    }
}
```
