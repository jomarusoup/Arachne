---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go 보안

> [common/security.md](../common/security.md) 를 확장한다.

## 비밀값 관리

```go
apiKey := os.Getenv("API_KEY")
if apiKey == "" {
    log.Fatal("API_KEY 환경변수 필요")
}
```

## Context와 타임아웃

외부 호출에 항상 타임아웃 적용:

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()

resp, err := client.Do(req.WithContext(ctx))
```

## SQL 인젝션 방지

```go
/* BAD */
query := fmt.Sprintf("SELECT * FROM users WHERE id = %s", userID)

/* GOOD */
row := db.QueryRowContext(ctx, "SELECT * FROM users WHERE id = $1", userID)
```

## 정적 보안 분석

```bash
gosec ./...
govulncheck ./...
```
