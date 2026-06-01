---
name: golang-patterns
description: 강력하고 효율적이며 유지 보수하기 쉬운 Go 애플리케이션을 구축하기 위한 이디엄틱 Go 패턴·모범 사례·컨벤션.
---

# Go 개발 패턴

강력하고 효율적이며 유지 보수하기 쉬운 애플리케이션을 구축하기 위한 이디엄틱 Go 패턴과 모범 사례.

## 언제 활성화하나

- 새 Go 코드 작성
- Go 코드 검토
- 기존 Go 코드 리팩터링
- Go 패키지/모듈 설계

## 핵심 원칙

### 1. 단순성과 명확성

Go는 영리함보다 단순함을 선호한다. 코드는 명백하고 읽기 쉬워야 한다.

```go
/* 올바름: 명확하고 직접적 */
func GetUser(id string) (*User, error) {
    user, err := db.FindUser(id)
    if err != nil {
        return nil, fmt.Errorf("get user %s: %w", id, err)
    }
    return user, nil
}

/* 잘못됨: 과도하게 영리함 */
func GetUser(id string) (*User, error) {
    return func() (*User, error) {
        if u, e := db.FindUser(id); e == nil {
            return u, nil
        } else {
            return nil, e
        }
    }()
}
```

### 2. 제로 값을 유용하게 만들기

타입을 설계할 때 제로 값이 초기화 없이 바로 사용 가능하도록 한다.

```go
/* 올바름: 제로 값이 유용함 */
type Counter struct {
    mu    sync.Mutex
    count int /* 제로 값은 0, 바로 사용 가능 */
}

func (c *Counter) Inc() {
    c.mu.Lock()
    c.count++
    c.mu.Unlock()
}

/* 잘못됨: 초기화 필요 */
type BadCounter struct {
    counts map[string]int /* nil 맵은 패닉 발생 */
}
```

### 3. 인터페이스 수락, 구조체 반환

함수는 인터페이스 매개변수를 수락하고 구체적인 타입을 반환해야 한다.

```go
/* 올바름: 인터페이스 수락, 구체적 타입 반환 */
func ProcessData(r io.Reader) (*Result, error) {
    data, err := io.ReadAll(r)
    if err != nil { return nil, err }
    return &Result{Data: data}, nil
}
```

## 에러 처리 패턴

### 컨텍스트가 있는 에러 래핑

```go
func LoadConfig(path string) (*Config, error) {
    data, err := os.ReadFile(path)
    if err != nil {
        return nil, fmt.Errorf("load config %s: %w", path, err)
    }

    var cfg Config
    if err := json.Unmarshal(data, &cfg); err != nil {
        return nil, fmt.Errorf("parse config %s: %w", path, err)
    }
    return &cfg, nil
}
```

### 커스텀 에러 타입

```go
/* 도메인별 에러 정의 */
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("필드 %s 검증 실패: %s", e.Field, e.Message)
}

/* 일반적인 케이스를 위한 센티넬 에러 */
var (
    ErrNotFound     = errors.New("리소스 없음")
    ErrUnauthorized = errors.New("권한 없음")
    ErrInvalidInput = errors.New("유효하지 않은 입력")
)
```

### errors.Is와 errors.As로 에러 확인

```go
func HandleError(err error) {
    if errors.Is(err, sql.ErrNoRows) {
        log.Println("레코드 없음")
        return
    }

    var validationErr *ValidationError
    if errors.As(err, &validationErr) {
        log.Printf("필드 %s 검증 에러: %s", validationErr.Field, validationErr.Message)
        return
    }

    log.Printf("예기치 않은 에러: %v", err)
}
```

### 에러 절대 무시 금지

```go
/* 잘못됨: 블랭크 식별자로 에러 무시 */
result, _ := doSomething()

/* 올바름: 처리하거나 안전하게 무시할 수 있는 이유 명시 */
result, err := doSomething()
if err != nil { return err }
```

## 동시성 패턴

### 워커 풀

```go
func WorkerPool(jobs <-chan Job, results chan<- Result, numWorkers int) {
    var wg sync.WaitGroup
    for i := 0; i < numWorkers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for job := range jobs {
                results <- process(job)
            }
        }()
    }
    wg.Wait()
    close(results)
}
```

### 취소 및 타임아웃을 위한 Context

```go
func FetchWithTimeout(ctx context.Context, url string) ([]byte, error) {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, fmt.Errorf("요청 생성: %w", err)
    }

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return nil, fmt.Errorf("가져오기 %s: %w", url, err)
    }
    defer resp.Body.Close()
    return io.ReadAll(resp.Body)
}
```

### 우아한 종료

```go
func GracefulShutdown(server *http.Server) {
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit
    log.Println("서버 종료 중...")

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := server.Shutdown(ctx); err != nil {
        log.Fatalf("서버 강제 종료: %v", err)
    }
    log.Println("서버 종료됨")
}
```

### 조율된 고루틴을 위한 errgroup

```go
import "golang.org/x/sync/errgroup"

func FetchAll(ctx context.Context, urls []string) ([][]byte, error) {
    g, ctx := errgroup.WithContext(ctx)
    results := make([][]byte, len(urls))

    for i, url := range urls {
        i, url := i, url /* 루프 변수 캡처 */
        g.Go(func() error {
            data, err := FetchWithTimeout(ctx, url)
            if err != nil { return err }
            results[i] = data
            return nil
        })
    }

    if err := g.Wait(); err != nil { return nil, err }
    return results, nil
}
```

### 고루틴 누수 방지

```go
/* 올바름: 취소를 제대로 처리 */
func safeFetch(ctx context.Context, url string) <-chan []byte {
    ch := make(chan []byte, 1) /* 버퍼 있는 채널 */
    go func() {
        data, err := fetch(url)
        if err != nil { return }
        select {
        case ch <- data:
        case <-ctx.Done():
        }
    }()
    return ch
}
```

## 인터페이스 설계

### 작고 집중된 인터페이스

```go
/* 올바름: 단일 메서드 인터페이스 */
type Reader interface { Read(p []byte) (n int, err error) }
type Writer interface { Write(p []byte) (n int, err error) }
type Closer interface { Close() error }

/* 필요에 따라 인터페이스 조합 */
type ReadWriteCloser interface { Reader; Writer; Closer }
```

### 사용하는 곳에서 인터페이스 정의

```go
/* 제공자가 아닌 소비자 패키지에서 정의 */
package service

type UserStore interface {
    GetUser(id string) (*User, error)
    SaveUser(user *User) error
}

type Service struct { store UserStore }
```

### 타입 단언으로 선택적 동작

```go
func WriteAndFlush(w io.Writer, data []byte) error {
    if _, err := w.Write(data); err != nil { return err }

    if f, ok := w.(interface{ Flush() error }); ok {
        return f.Flush()
    }
    return nil
}
```

## 패키지 구성

### 표준 프로젝트 레이아웃

```text
myproject/
├── cmd/
│   └── myapp/
│       └── main.go           # 진입점
├── internal/
│   ├── handler/              # HTTP 핸들러
│   ├── service/              # 비즈니스 로직
│   ├── repository/           # 데이터 접근
│   └── config/               # 설정
├── pkg/
│   └── client/               # 공개 API 클라이언트
├── testdata/                 # 테스트 픽스처
├── go.mod
└── Makefile
```

### 패키지 전역 상태 금지

```go
/* 잘못됨: 전역 가변 상태 */
var db *sql.DB
func init() { db, _ = sql.Open("postgres", os.Getenv("DATABASE_URL")) }

/* 올바름: 의존성 주입 */
type Server struct { db *sql.DB }
func NewServer(db *sql.DB) *Server { return &Server{db: db} }
```

## 구조체 설계

### Functional Options 패턴

```go
type Server struct {
    addr    string
    timeout time.Duration
    logger  *log.Logger
}

type Option func(*Server)

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func NewServer(addr string, opts ...Option) *Server {
    s := &Server{addr: addr, timeout: 30 * time.Second, logger: log.Default()}
    for _, opt := range opts { opt(s) }
    return s
}

/* 사용 */
server := NewServer(":8080",
    WithTimeout(60*time.Second),
    WithLogger(customLogger),
)
```

### 임베딩으로 컴포지션

```go
type Logger struct { prefix string }
func (l *Logger) Log(msg string) { fmt.Printf("[%s] %s\n", l.prefix, msg) }

type Server struct {
    *Logger /* 임베딩 — Server가 Log 메서드를 가짐 */
    addr    string
}
```

## 메모리 및 성능

### 크기를 알면 슬라이스 미리 할당

```go
/* 올바름: 단일 할당 */
func processItems(items []Item) []Result {
    results := make([]Result, 0, len(items))
    for _, item := range items { results = append(results, process(item)) }
    return results
}
```

### 빈번한 할당에 sync.Pool 사용

```go
var bufferPool = sync.Pool{New: func() interface{} { return new(bytes.Buffer) }}

func ProcessRequest(data []byte) []byte {
    buf := bufferPool.Get().(*bytes.Buffer)
    defer func() { buf.Reset(); bufferPool.Put(buf) }()
    buf.Write(data)
    return buf.Bytes()
}
```

### 루프에서 문자열 연결 금지

```go
/* 올바름: strings.Builder 사용 */
func join(parts []string) string {
    var sb strings.Builder
    for i, p := range parts {
        if i > 0 { sb.WriteString(",") }
        sb.WriteString(p)
    }
    return sb.String()
}

/* 최선: 표준 라이브러리 사용 */
func join(parts []string) string { return strings.Join(parts, ",") }
```

## Go 도구 통합

```bash
# 빌드 및 실행
go build ./...
go run ./cmd/myapp

# 테스팅
go test ./...
go test -race ./...
go test -cover ./...

# 정적 분석
go vet ./...
staticcheck ./...
golangci-lint run

# 모듈 관리
go mod tidy
go mod verify

# 포매팅
gofmt -w .
goimports -w .
```

## 빠른 참조: Go 이디엄

| 이디엄 | 설명 |
|---|---|
| 인터페이스 수락, 구조체 반환 | 함수는 인터페이스 매개변수 수락, 구체적 타입 반환 |
| 에러는 값이다 | 에러를 예외가 아닌 일급 값으로 취급 |
| 공유 메모리로 통신하지 않기 | 고루틴 간 조율에 채널 사용 |
| 제로 값을 유용하게 | 타입은 명시적 초기화 없이 작동해야 함 |
| 조금 복사하는 것이 조금 의존하는 것보다 낫다 | 불필요한 외부 의존성 금지 |
| 명확함이 영리함보다 낫다 | 영리함보다 가독성 우선 |
| gofmt로 항상 포매팅 | gofmt/goimports로 항상 포매팅 |
| 조기 반환 | 에러 먼저 처리, 행복 경로 들여쓰기 최소화 |

## 피해야 할 안티패턴

```go
/* 잘못됨: 긴 함수에서 naked return */
func process() (result int, err error) {
    return /* 무엇이 반환되는지? */
}

/* 잘못됨: 제어 흐름에 panic 사용 */
func GetUser(id string) *User {
    user, err := db.Find(id)
    if err != nil { panic(err) /* 하지 않는다 */ }
    return user
}

/* 잘못됨: 구조체에 context 포함 */
type Request struct {
    ctx context.Context /* 첫 번째 매개변수여야 함 */
    ID  string
}

/* 올바름: context는 첫 번째 매개변수 */
func ProcessRequest(ctx context.Context, id string) error { }

/* 잘못됨: 값 수신자와 포인터 수신자 혼용 */
type Counter struct{ n int }
func (c Counter) Value() int { return c.n }    /* 값 수신자 */
func (c *Counter) Increment() { c.n++ }        /* 포인터 수신자 */
/* 하나를 선택하고 일관되게 */
```

---

**기억**: Go 코드는 최선의 의미에서 지루해야 한다 — 예측 가능하고, 일관되고, 이해하기 쉽게. 의심스러울 때는 단순하게.
