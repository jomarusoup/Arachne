---
name: error-handling
description: C/C++·TypeScript·Python·Go 전반의 견고한 에러 처리 패턴. 타입화된 에러, 반환 코드, 재시도, 서킷 브레이커, 사용자 대면 에러 메시지 다룸.
origin: ECC (modified — C/C++ 섹션 추가)
---

# 에러 처리 패턴

운영 애플리케이션을 위한 일관되고 견고한 에러 처리 패턴.

## 언제 활성화하나

- 새 모듈·서비스의 에러 타입 또는 예외 계층 설계
- 불안정한 외부 의존성에 재시도 로직·서킷 브레이커 추가
- API 엔드포인트의 에러 처리 누락 검토
- 사용자 대면 에러 메시지 및 피드백 구현
- 연쇄 실패 또는 조용한 에러 삼킴 디버깅

## 핵심 원칙

1. **빠르고 명확하게 실패** — 에러가 발생하는 경계에서 노출; 묻어두지 않는다
2. **문자열 메시지보다 타입화된 에러** — 에러는 구조를 가진 일급 값
3. **사용자 메시지 ≠ 개발자 메시지** — 사용자에게는 친절한 텍스트, 서버에는 전체 컨텍스트 로깅
4. **에러를 조용히 삼키지 않기** — 모든 `catch` 블록은 처리·재던지기·로깅 중 하나
5. **에러는 API 계약의 일부** — 클라이언트가 받을 수 있는 모든 에러 코드 문서화

## TypeScript / JavaScript

### 타입화된 에러 클래스

```typescript
// 도메인의 에러 계층 정의
export class AppError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly statusCode: number = 500,
    public readonly details?: unknown,
  ) {
    super(message)
    this.name = this.constructor.name
    // 트랜스파일된 ES5 JavaScript에서 올바른 프로토타입 체인 유지.
    // 내장 Error 클래스 확장 시 `instanceof` 검사가 올바르게 작동하도록 필요.
    Object.setPrototypeOf(this, new.target.prototype)
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string, id: string) {
    super(`${resource} not found: ${id}`, 'NOT_FOUND', 404)
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details: { field: string; message: string }[]) {
    super(message, 'VALIDATION_ERROR', 422, details)
  }
}

export class RateLimitError extends AppError {
  constructor(public readonly retryAfterMs: number) {
    super('Rate limit exceeded', 'RATE_LIMITED', 429)
  }
}
```

### Result 패턴 (no-throw 스타일)

실패가 예상되고 흔한 연산(파싱, 외부 호출)에 사용:

```typescript
type Result<T, E = AppError> =
  | { ok: true; value: T }
  | { ok: false; error: E }

function ok<T>(value: T): Result<T> {
  return { ok: true, value }
}

function err<E>(error: E): Result<never, E> {
  return { ok: false, error }
}

// 사용
async function fetchUser(id: string): Promise<Result<User>> {
  try {
    const user = await db.users.findUnique({ where: { id } })
    if (!user) return err(new NotFoundError('User', id))
    return ok(user)
  } catch (e) {
    return err(new AppError('Database error', 'DB_ERROR'))
  }
}

const result = await fetchUser('abc-123')
if (!result.ok) {
  logger.error('사용자 조회 실패', { error: result.error })
  return
}
console.log(result.value.email)
```

### API 에러 핸들러 (Next.js / Express)

```typescript
import { NextRequest, NextResponse } from 'next/server'

function handleApiError(error: unknown): NextResponse {
  // 알려진 애플리케이션 에러
  if (error instanceof AppError) {
    return NextResponse.json(
      {
        error: {
          code: error.code,
          message: error.message,
          ...(error.details ? { details: error.details } : {}),
        },
      },
      { status: error.statusCode },
    )
  }

  // Zod 검증 에러
  if (error instanceof z.ZodError) {
    return NextResponse.json(
      {
        error: {
          code: 'VALIDATION_ERROR',
          message: '요청 검증 실패',
          details: error.issues.map(i => ({
            field: i.path.join('.'),
            message: i.message,
          })),
        },
      },
      { status: 422 },
    )
  }

  // 예기치 않은 에러 — 상세 로깅, 일반 메시지 반환
  console.error('예기치 않은 에러:', error)
  return NextResponse.json(
    { error: { code: 'INTERNAL_ERROR', message: '예기치 않은 오류가 발생했습니다' } },
    { status: 500 },
  )
}

export async function POST(req: NextRequest) {
  try {
    // ... 핸들러 로직
  } catch (error) {
    return handleApiError(error)
  }
}
```

### React 에러 바운더리

```typescript
import { Component, ErrorInfo, ReactNode } from 'react'

interface Props {
  fallback: ReactNode
  onError?: (error: Error, info: ErrorInfo) => void
  children: ReactNode
}

interface State {
  hasError: boolean
  error: Error | null
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, error: null }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    this.props.onError?.(error, info)
    console.error('처리되지 않은 React 에러:', error, info)
  }

  render() {
    if (this.state.hasError) return this.props.fallback
    return this.props.children
  }
}

// 사용
<ErrorBoundary fallback={<p>문제가 발생했습니다. 새로고침해 주세요.</p>}>
  <MyComponent />
</ErrorBoundary>
```

## Python

### 커스텀 예외 계층

```python
class AppError(Exception):
    """기본 애플리케이션 에러."""
    def __init__(self, message: str, code: str, status_code: int = 500):
        super().__init__(message)
        self.code = code
        self.status_code = status_code

class NotFoundError(AppError):
    def __init__(self, resource: str, id: str):
        super().__init__(f"{resource} not found: {id}", "NOT_FOUND", 404)

class ValidationError(AppError):
    def __init__(self, message: str, details: list[dict] | None = None):
        super().__init__(message, "VALIDATION_ERROR", 422)
        self.details = details or []
```

### FastAPI 전역 예외 핸들러

```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

app = FastAPI()

@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.code, "message": str(exc)}},
    )

@app.exception_handler(Exception)
async def generic_error_handler(request: Request, exc: Exception) -> JSONResponse:
    # 전체 상세 로깅, 일반 메시지 반환
    logger.exception("예기치 않은 에러", exc_info=exc)
    return JSONResponse(
        status_code=500,
        content={"error": {"code": "INTERNAL_ERROR", "message": "예기치 않은 오류가 발생했습니다"}},
    )
```

## Go

### 센티넬 에러와 에러 래핑

```go
package domain

import "errors"

// 타입 검사를 위한 센티넬 에러
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
    ErrConflict     = errors.New("conflict")
)

// 컨텍스트로 에러 래핑 — 원본을 절대 잃지 않는다
func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
    user, err := r.db.QueryRow(ctx, "SELECT * FROM users WHERE id = $1", id)
    if errors.Is(err, sql.ErrNoRows) {
        return nil, fmt.Errorf("user %s: %w", id, ErrNotFound)
    }
    if err != nil {
        return nil, fmt.Errorf("querying user %s: %w", id, err)
    }
    return user, nil
}

// 핸들러 레벨에서 unwrap하여 응답 결정
func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
    user, err := h.service.GetUser(r.Context(), chi.URLParam(r, "id"))
    if err != nil {
        switch {
        case errors.Is(err, domain.ErrNotFound):
            writeError(w, http.StatusNotFound, "not_found", err.Error())
        case errors.Is(err, domain.ErrUnauthorized):
            writeError(w, http.StatusForbidden, "forbidden", "접근 거부됨")
        default:
            slog.Error("예기치 않은 에러", "err", err)
            writeError(w, http.StatusInternalServerError, "internal_error", "예기치 않은 오류 발생")
        }
        return
    }
    writeJSON(w, http.StatusOK, user)
}
```

## C / C++ — 시스템 프로그래밍 에러 처리

### 반환 코드 패턴

```c
/*=============================================================================
FUNCTION    : ConnCreate
DESCRIPTION : 연결 생성 — 실패 시 NULL 반환, errno 설정
=============================================================================*/
typedef enum
{
    ERR_OK        =  0,
    ERR_NULL_PTR  = -1,
    ERR_NO_MEM    = -2,
    ERR_IO        = -3,
    ERR_TIMEOUT   = -4,
} ErrCode_t;

/* 반환값 항상 확인 */
ErrCode_t ret = ConnSend(conn, data, len);
if (ret != ERR_OK)
{
    fprintf(stderr, "[ERROR] ConnSend: %d\n", ret);
    goto cleanup;
}
```

### goto cleanup 패턴 — 자원 누수 방지

```c
int ProcessFile(const char *path)
{
    int    ret = -1;
    int    fd  = -1;
    char  *buf = NULL;

    fd = open(path, O_RDONLY);
    if (fd < 0) { perror("open"); goto cleanup; }

    buf = malloc(BUF_SIZE);
    if (!buf) { ret = ERR_NO_MEM; goto cleanup; }

    /* ... 작업 ... */
    ret = ERR_OK;

cleanup:
    free(buf);
    if (fd >= 0) { close(fd); }
    return ret;
}
```

### 시스템 콜 에러 — errno 처리

```c
/* 시스템 콜 실패 시 errno 즉시 확인 */
ssize_t n = write(fd, buf, len);
if (n < 0)
{
    int saved_errno = errno;  /* errno는 덮어씌워질 수 있으므로 저장 */
    fprintf(stderr, "[ERROR] write: %s (errno=%d)\n",
            strerror(saved_errno), saved_errno);
    return ERR_IO;
}
```

### C++ — std::expected (C++23) / 예외 계층

```cpp
/* C++23 std::expected */
std::expected<Config, ErrCode_t> LoadConfig(const std::string &path)
{
    if (path.empty()) { return std::unexpected(ERR_NULL_PTR); }
    /* ... */
    return config;
}

auto result = LoadConfig("config.toml");
if (!result)
{
    std::cerr << "[ERROR] LoadConfig: " << result.error() << '\n';
    return result.error();
}

/* 예외 계층 */
class AppError : public std::runtime_error
{
public:
    explicit AppError(const std::string &msg, ErrCode_t code)
        : std::runtime_error(msg), code_(code) {}
    ErrCode_t code() const noexcept { return code_; }
private:
    ErrCode_t code_;
};
```

### 에러 처리 체크리스트 (C/C++)

- [ ] 모든 시스템 콜·라이브러리 함수 반환값 확인
- [ ] errno는 실패 직후 저장 (`int saved = errno`)
- [ ] 모든 종료 경로에서 자원 해제 보장 (goto cleanup)
- [ ] NULL 포인터 전달 시 즉시 에러 반환
- [ ] 에러 로그에 파일명·라인·에러 코드 포함

## 지수 백오프 재시도

```typescript
interface RetryOptions {
  maxAttempts?: number
  baseDelayMs?: number
  maxDelayMs?: number
  retryIf?: (error: unknown) => boolean
}

async function withRetry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {},
): Promise<T> {
  const {
    maxAttempts = 3,
    baseDelayMs = 500,
    maxDelayMs = 10_000,
    retryIf = () => true,
  } = options

  let lastError: unknown

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error
      if (attempt === maxAttempts || !retryIf(error)) throw error

      const jitter = Math.random() * baseDelayMs
      const delay = Math.min(baseDelayMs * 2 ** (attempt - 1) + jitter, maxDelayMs)
      await new Promise(resolve => setTimeout(resolve, delay))
    }
  }

  throw lastError
}

// 사용: 4xx가 아닌 일시적 네트워크 에러만 재시도
const data = await withRetry(() => fetch('/api/data').then(r => r.json()), {
  maxAttempts: 3,
  retryIf: (error) => !(error instanceof AppError && error.statusCode < 500),
})
```

## 사용자 대면 에러 메시지

에러 코드를 사람이 읽을 수 있는 메시지로 매핑. 사용자에게 보이는 텍스트에서 기술 세부사항 제외.

```typescript
const USER_ERROR_MESSAGES: Record<string, string> = {
  NOT_FOUND: '요청하신 항목을 찾을 수 없습니다.',
  UNAUTHORIZED: '계속하려면 로그인해 주세요.',
  FORBIDDEN: '해당 작업에 대한 권한이 없습니다.',
  VALIDATION_ERROR: '입력을 확인하고 다시 시도해 주세요.',
  RATE_LIMITED: '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.',
  INTERNAL_ERROR: '서버에 문제가 발생했습니다. 나중에 다시 시도해 주세요.',
}

export function getUserMessage(code: string): string {
  return USER_ERROR_MESSAGES[code] ?? USER_ERROR_MESSAGES.INTERNAL_ERROR
}
```

## 에러 처리 체크리스트

에러 처리를 다루는 코드 머지 전:

- [ ] 모든 `catch` 블록이 처리·재던지기·로깅 — 조용한 삼킴 없음
- [ ] API 에러가 표준 형식 `{ error: { code, message } }` 따름
- [ ] 사용자 대면 메시지에 스택 트레이스나 내부 세부사항 없음
- [ ] 전체 에러 컨텍스트가 서버에 로깅됨
- [ ] 커스텀 에러 클래스가 `code` 필드가 있는 기본 `AppError` 확장
- [ ] 비동기 함수가 호출자에게 에러 노출 — 폴백 없는 fire-and-forget 없음
- [ ] 재시도 로직이 재시도 가능한 에러만 재시도 (4xx 클라이언트 에러 제외)
- [ ] React 컴포넌트가 렌더링 에러를 위해 `ErrorBoundary`로 감싸짐
