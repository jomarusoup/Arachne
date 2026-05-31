---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.

## Functional Options

```go
type Option func(*Server)

func WithPort(port int) Option {
    return func(s *Server) { s.port = port }
}

func WithTimeout(d time.Duration) Option {
    return func(s *Server) { s.timeout = d }
}

func NewServer(opts ...Option) *Server {
    s := &Server{port: 8080, timeout: 30 * time.Second}
    for _, opt := range opts {
        opt(s)
    }
    return s
}
```

## 작은 인터페이스

인터페이스는 구현 측이 아닌 **사용 측**에서 정의:

```go
/* 사용 측 패키지에서 선언 */
type Sender interface {
    Send(ctx context.Context, msg []byte) error
}
```

## 의존성 주입

```go
func NewUserService(repo UserRepository, logger *slog.Logger) *UserService {
    return &UserService{repo: repo, logger: logger}
}
```

## 고루틴 수명 관리

```go
func (s *Server) Run(ctx context.Context) error {
    g, ctx := errgroup.WithContext(ctx)

    g.Go(func() error { return s.listenLoop(ctx) })
    g.Go(func() error { return s.healthCheck(ctx) })

    return g.Wait()
}
```

## 채널 패턴

```go
/* 생산자가 채널을 소유하고 닫음 */
func Generate(ctx context.Context) <-chan int {
    ch := make(chan int)
    go func() {
        defer close(ch)
        for i := 0; ; i++ {
            select {
            case ch <- i:
            case <-ctx.Done():
                return
            }
        }
    }()
    return ch
}
```
