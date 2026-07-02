---
name: go-http-patterns
description: Go HTTP 서버 특화 패턴. net/http 미들웨어 체인, context 전파, gRPC 서비스 간 통신, graceful shutdown, 저지연 응답 최적화.
triggers:
  paths: ["**/*.go"]
  keywords: ["Go HTTP", "gRPC", "graceful shutdown", "미들웨어"]
---

# Go HTTP 서버 패턴

범용 Go 패턴(`golang-patterns`)의 웹 레이어 확장.  
실시간 데이터 서비스의 HTTP/gRPC 서버 구현에 집중.

## 언제 사용하나

- Go HTTP 서버·라우터 구현
- 미들웨어 체인 설계
- gRPC 서비스 정의·구현
- graceful shutdown 구현
- WebSocket 실시간 푸시

## 언제 사용하지 않나

- 범용 Go 패턴 → `golang-patterns` 스킬
- 성능 프로파일링 → `performance-profiling` 스킬

---

## 미들웨어 체인 (net/http)

```go
type Middleware func(http.Handler) http.Handler

func Chain(h http.Handler, middlewares ...Middleware) http.Handler {
    for ii := len(middlewares) - 1; ii >= 0; ii-- {
        h = middlewares[ii](h)
    }
    return h
}

// 사용
mux := http.NewServeMux()
mux.HandleFunc("/ticks", handleTicks)

handler := Chain(mux,
    RequestID,
    Logger,
    Recovery,
)
```

## context 전파·타임아웃

```go
func handleOrder(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 5*time.Millisecond)
    defer cancel()

    order, err := parseOrder(r.Body)
    if err != nil {
        http.Error(w, "invalid order", http.StatusBadRequest)
        return
    }

    result, err := submitOrder(ctx, order)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            http.Error(w, "timeout", http.StatusGatewayTimeout)
            return
        }
        http.Error(w, "internal error", http.StatusInternalServerError)
        return
    }

    json.NewEncoder(w).Encode(result)
}
```

## Graceful Shutdown

```go
func Run(addr string) error {
    srv := &http.Server{
        Addr:         addr,
        Handler:      buildRouter(),
        ReadTimeout:  5 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  60 * time.Second,
    }

    errCh := make(chan error, 1)
    go func() { errCh <- srv.ListenAndServe() }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

    select {
    case err := <-errCh:
        return fmt.Errorf("server error: %w", err)
    case <-quit:
        ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
        defer cancel()
        return srv.Shutdown(ctx)
    }
}
```

## gRPC 서비스

```go
/* 서버 */
type MarketDataServer struct {
    pb.UnimplementedMarketDataServer
    book *OrderBook
}

func (s *MarketDataServer) StreamTicks(
    req *pb.StreamRequest,
    stream pb.MarketData_StreamTicksServer,
) error {
    sub := s.book.Subscribe(req.Symbol)
    defer sub.Close()

    for {
        select {
        case <-stream.Context().Done():
            return nil
        case tick := <-sub.Ch():
            if err := stream.Send(toProto(tick)); err != nil {
                return err
            }
        }
    }
}

/* 클라이언트 */
conn, err := grpc.Dial(addr,
    grpc.WithTransportCredentials(insecure.NewCredentials()),
    grpc.WithKeepaliveParams(keepalive.ClientParameters{
        Time:    10 * time.Second,
        Timeout: 5 * time.Second,
    }),
)
```

## WebSocket 실시간 푸시

```go
var upgrader = websocket.Upgrader{
    ReadBufferSize:  1024,
    WriteBufferSize: 4096,
    CheckOrigin: func(r *http.Request) bool { return true },
}

func handleWS(w http.ResponseWriter, r *http.Request) {
    conn, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        return
    }
    defer conn.Close()

    sub := book.Subscribe(r.URL.Query().Get("symbol"))
    defer sub.Close()

    for tick := range sub.Ch() {
        if err := conn.WriteJSON(tick); err != nil {
            return
        }
    }
}
```

## 저지연 응답 최적화

```go
// 응답 버퍼 재사용
var bufPool = sync.Pool{
    New: func() any { return new(bytes.Buffer) },
}

func writeJSON(w http.ResponseWriter, v any) {
    buf := bufPool.Get().(*bytes.Buffer)
    buf.Reset()
    defer bufPool.Put(buf)

    json.NewEncoder(buf).Encode(v)
    w.Header().Set("Content-Type", "application/json")
    w.Write(buf.Bytes())
}
```
