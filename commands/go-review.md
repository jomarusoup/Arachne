---
description: 이디엄·에러 처리·동시성·보안 종합 Go 코드 리뷰 — go-reviewer 에이전트 호출
---

# /go-review — Go 코드 리뷰

**go-reviewer** 에이전트를 호출해 Go 특화 종합 리뷰를 수행한다. 리뷰어는 코드를 수정하지 않는다.

## 동작

1. **변경 식별** — `git diff`로 수정된 `.go`·`go.mod`·`go.sum` 탐색
2. **정적 분석** — `go vet` · `staticcheck` · `golangci-lint` 실행 (미설치 도구는 보고서에 명시)
3. **보안 스캔** — SQL/커맨드 인젝션, 경로 순회, TLS 검증 해제, 취약 의존성(`govulncheck`)
4. **동시성 점검** — 데이터 레이스, 고루틴 누수, 락·채널·context 전파
5. **이디엄 점검** — 에러 래핑·early return·인터페이스 위치·패키지 네이밍
6. **리포트** — 심각도별 분류, 80% 이상 확신하는 문제만

## 언제 사용하나

- Go 코드 작성·수정 후, 커밋 전
- Go 코드가 포함된 PR 리뷰
- 새 Go 코드베이스 온보딩

## 리뷰 카테고리

### CRITICAL (반드시 수정)
- SQL/커맨드 인젝션, 경로 순회
- `InsecureSkipVerify: true`, 정당화 없는 `unsafe`
- 하드코딩된 자격증명, 보안 용도 `math/rand`
- 실패 경로가 있는 호출의 에러 폐기 (`_`)

### HIGH (수정 권장)
- 동기화 없는 공유 상태 (데이터 레이스)
- 종료 경로 없는 고루틴 (누수), 수신자 없는 채널 송신
- 패키지 경계를 넘는 맥락 없는 `return err`, `%v` 래핑
- 요청 경로에서 context 미전파, 라이브러리의 panic

### MEDIUM (검토)
- 루프 내 문자열 결합, 슬라이스 미리 할당 누락
- 공개 식별자 doc 주석·하네스 헤더 주석 누락
- 테이블 드리븐이 아니거나 에러 경로 없는 테스트

## 자동 검사

```bash
go vet ./...
staticcheck ./...
golangci-lint run
go build -race ./...
go test -race ./...
govulncheck ./...
```

## 흔한 수정 패턴

```go
/* 에러 맥락 */
return err                                          // BAD → 어디서 실패했는지 모름
return fmt.Errorf("사용자 %s 조회: %w", user_id, err) // GOOD

/* 에러 비교 */
if err == sql.ErrNoRows { ... }                     // BAD → 래핑되면 불일치
if errors.Is(err, sql.ErrNoRows) { ... }            // GOOD

/* 고루틴 종료 경로 */
go func() { for { work() } }()                      // BAD → 누수
go func() {                                         // GOOD
    for {
        select {
        case <-ctx.Done():
            return
        default:
            work()
        }
    }
}()

/* 루프 내 defer */
for _, path := range paths {                        // BAD → 함수 종료까지 fd 누적
    f, _ := os.Open(path)
    defer f.Close()
}
for _, path := range paths {                        // GOOD → 반복마다 닫힘
    if err := processFile(path); err != nil {
        return err
    }
}
```

## 승인 기준

| 상태 | 조건 |
| ---- | ---- |
| 승인 | CRITICAL·HIGH 없음 |
| 경고 | MEDIUM만 존재 (주의 후 머지) |
| 차단 | CRITICAL·HIGH 존재 |

## 연계

- 테스트 먼저 녹색으로: `/go-test`
- 빌드가 깨져 있으면: `/go-build`
- 비-Go 관심사는 `code-reviewer` 에이전트, 커밋 전 검증은 `/verify`
- 상세 패턴은 스킬 `golang-patterns` · `golang-testing` · `go-http-patterns`
- 에이전트: `agents/go-reviewer.md`
