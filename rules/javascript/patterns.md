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

## 불변성 (매우 중요)

항상 새로운 객체를 생성하고, 기존 객체를 절대 변경하지 마십시오.

```
// Pseudocode
WRONG:  modify(original, field, value) → changes original in-place
CORRECT: update(original, field, value) → returns new copy with change
```

근거: 불변 데이터는 숨겨진 부작용을 방지하고, 디버깅을 용이하게 하며, 안전한 동시성을 가능하게 합니다.

**핫패스 예외**: UI·도메인 상태는 불변으로 다룬다. 다만 대용량 수신·변환 핫패스에서
링버퍼·TypedArray·객체 풀을 재사용하는 것은 의도된 변이로 허용한다. 이때 변이는 해당
모듈 안에 가두고, 바깥으로는 복사본이나 읽기 전용 뷰만 내보낸다.

### 불변 상태 업데이트

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
