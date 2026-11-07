---
description: Go TDD 사이클 — 테이블 드리븐 테스트 먼저 작성 후 구현, -race·커버리지 80%+ 확인. tdd 에이전트와 연동.
---

# /go-test [대상 함수·기능 설명]

Go 프로젝트용 TDD 진입점. `/tdd`의 공통 사이클을 Go 도구·이디엄으로 구체화하고 `tdd` 에이전트와 연동한다.

## 실행 흐름

```
1. 시그니처 정의     → 타입·함수 시그니처만, 본문은 panic("미구현")
2. 테스트 작성 (RED) → 테이블 드리븐, 정상·경계·에러 케이스
3. 실행 → 실패 확인 → 올바른 이유로 실패하는지 본다
4. 최소 구현 (GREEN)
5. 실행 → 통과 확인
6. 리팩터링         → 테스트 녹색 유지
7. go test -race -cover → 레이스·커버리지 80%+ 확인
```

## 예시 세션 — 설정 값 파서

```go
/* 1단계: 시그니처 — config/duration.go */
// ParseTimeout 은 "30s"·"5m" 형식 문자열을 검증해 time.Duration 으로 변환한다.
func ParseTimeout(raw string) (time.Duration, error) {
    panic("미구현")
}
```

```go
/* 2단계: 실패 테스트 — config/duration_test.go */
func TestParseTimeout(t *testing.T) {
    tests := []struct {
        name    string
        raw     string
        want    time.Duration
        wantErr error
    }{
        {"초_단위", "30s", 30 * time.Second, nil},
        {"분_단위", "5m", 5 * time.Minute, nil},
        {"빈_문자열시_에러", "", 0, ErrEmptyTimeout},
        {"음수시_에러", "-1s", 0, ErrTimeoutRange},
        {"상한_초과시_에러", "2h", 0, ErrTimeoutRange},
        {"형식_오류시_에러", "abc", 0, ErrTimeoutFormat},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseTimeout(tt.raw)
            if !errors.Is(err, tt.wantErr) {
                t.Fatalf("ParseTimeout(%q) err = %v, want %v", tt.raw, err, tt.wantErr)
            }
            if got != tt.want {
                t.Errorf("ParseTimeout(%q) = %v, want %v", tt.raw, got, tt.want)
            }
        })
    }
}
```

```bash
$ go test ./config/...
--- FAIL: TestParseTimeout/초_단위
panic: 미구현                     # 3단계: 예상한 실패
```

```go
/* 4단계: 최소 구현 */
const MAX_TIMEOUT = time.Hour

var (
    ErrEmptyTimeout  = errors.New("타임아웃 값이 비어 있음")
    ErrTimeoutFormat = errors.New("타임아웃 형식 오류")
    ErrTimeoutRange  = errors.New("타임아웃 범위 초과")
)

func ParseTimeout(raw string) (time.Duration, error) {
    if raw == "" {
        return 0, ErrEmptyTimeout
    }
    dur, err := time.ParseDuration(raw)
    if err != nil {
        return 0, fmt.Errorf("%w: %q", ErrTimeoutFormat, raw)
    }
    if dur < 0 || dur > MAX_TIMEOUT {
        return 0, fmt.Errorf("%w: %v", ErrTimeoutRange, dur)
    }
    return dur, nil
}
```

```bash
$ go test -race -cover ./config/...   # 5·7단계
ok   example.com/app/config  0.012s  coverage: 100.0% of statements
```

## 테스트 패턴 요약

| 패턴 | 언제 | 상세 |
|---|---|---|
| 테이블 드리븐 + `t.Run` | 입력·기대값 조합이 2개 이상 | 스킬 `golang-testing` |
| `t.Parallel()` | 공유 상태 없는 독립 케이스 | 1.22 미만이면 `tt := tt` 캡처 |
| `t.Helper()` · `t.Cleanup()` | 공통 준비·정리 헬퍼 | 실패 줄이 호출부로 보고됨 |
| `t.TempDir()` · `t.Setenv()` | 파일·환경변수 픽스처 | 자동 정리·원복 |
| `httptest` | HTTP 핸들러 | 스킬 `golang-testing`, `go-http-patterns` |
| 인터페이스 페이크 | 외부 의존성 격리 | 소비하는 쪽에 작은 인터페이스 |
| `Fuzz*` | 파서·디코더 | `go test -fuzz=FuzzX -fuzztime=30s` |

테스트 이름은 하네스 규칙대로 동작을 설명한다 (`빈_문자열시_에러`). AAA 순서를 지킨다.

## 커버리지

```bash
go test -race -coverprofile=coverage.out ./...
go tool cover -func=coverage.out | tail -1      # 총합
go tool cover -html=coverage.out                # 미커버 줄 확인
```

| 코드 유형 | 목표 |
|---|---|
| 핵심 비즈니스 로직 | 100% |
| 공개 API | 90%+ |
| 일반 코드 | 80%+ |
| 생성 코드 | 제외 |

## 지켜야 할 것

- 구현보다 테스트 먼저, RED 단계를 건너뛰지 않는다
- 에러 경로 케이스(`wantErr`)를 테이블에 반드시 포함
- 동작을 테스트한다 — 비공개 함수 직접 테스트 지양
- `time.Sleep`으로 동기화하지 않는다 — 시간은 인자로 주입, 채널·`WaitGroup`으로 대기
- 불안정 테스트는 `go test -count=10 -run TestX`로 재현해 고친다 — 무시·skip 금지

## 연계

- 범용 TDD 흐름: `/tdd` (에이전트 `tdd`)
- 빌드가 깨지면: `/go-build`
- 구현 후 리뷰: `/go-review`
- 커밋 전 검증: `/verify`
- 스킬: `golang-testing` · `tdd-workflow`
