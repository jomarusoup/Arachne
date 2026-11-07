---
name: golang-testing
description: 테이블 드리븐 테스트·서브테스트·벤치마크·퍼징·테스트 커버리지를 포함한 Go 테스팅 패턴. TDD 방법론과 이디엄틱 Go 관행 준수. 대상 경로 — **/*_test.go. 키워드 — Go 테스트, 테이블 드리븐, 벤치마크, 퍼징, -race.
---

# Go 테스팅 패턴

TDD 방법론과 이디엄틱 Go 관행을 따르는 포괄적 Go 테스팅 패턴.

## 언제 활성화하나

- Go 코드 테스트 작성
- 테스트 인프라 설정
- 벤치마크 또는 퍼징 추가
- 테스트 커버리지 개선
- 테스트 리팩터링

## Go TDD 사이클

하네스 공통 TDD(`rules/common/testing.md`)를 Go 도구로 수행하는 흐름. 진입점은 `/go-test`.

```
RED      → 시그니처만 두고 실패하는 테이블 드리븐 테스트 작성
GREEN    → 테스트를 통과하는 최소 구현
REFACTOR → 테스트 녹색 유지하며 정리
CHECK    → go test -race -cover 로 레이스·커버리지(80%+) 확인
```

```go
/* 1단계: 시그니처만 선언 — 본문은 미구현 표시 */
// ratelimit/bucket.go
type Bucket struct{}

func NewBucket(capacity int, refill time.Duration) *Bucket {
    panic("미구현")
}

func (b *Bucket) Allow(now time.Time) bool {
    panic("미구현")
}

/* 2단계: 실패 테스트 작성 (RED) */
// ratelimit/bucket_test.go
func TestBucket_Allow(t *testing.T) {
    base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
    tests := []struct {
        name     string
        consumed int
        elapsed  time.Duration
        want     bool
    }{
        {"용량_남으면_허용", 0, 0, true},
        {"용량_소진시_거부", 3, 0, false},
        {"리필_주기_경과시_재허용", 3, time.Second, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            bucket := NewBucket(3, time.Second)
            for ii := 0; ii < tt.consumed; ii++ {
                bucket.Allow(base)
            }
            if got := bucket.Allow(base.Add(tt.elapsed)); got != tt.want {
                t.Errorf("Allow() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

```bash
go test ./ratelimit/...            # 3단계: 실패 확인 — panic "미구현" 이 올바른 실패 이유인지 본다
# 4단계: 최소 구현 후
go test -race -cover ./ratelimit/... # 5단계: 통과 + 레이스 + 커버리지
```

- 시간은 `time.Now()`를 직접 부르지 말고 인자로 주입한다 — `time.Sleep` 없는 결정적 테스트
- 실패 이유가 컴파일 에러·panic 이 아니라 **단언 실패**로 바뀐 뒤 구현에 들어가면 더 안전하다

## 핵심 테스팅 원칙

### 1. 테이블 드리븐 테스트

Go의 이디엄틱 테스팅 방식은 포괄적 커버리지를 위해 테이블 드리븐 테스트를 사용한다.

```go
func TestCalculate(t *testing.T) {
    tests := []struct {
        name    string
        input   int
        want    int
        wantErr bool
    }{
        {name: "양수", input: 5, want: 25, wantErr: false},
        {name: "0", input: 0, want: 0, wantErr: false},
        {name: "음수", input: -5, want: 25, wantErr: false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := Calculate(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Calculate() error = %v, wantErr %v", err, tt.wantErr)
                return
            }
            if got != tt.want {
                t.Errorf("Calculate() = %v, want %v", got, tt.want)
            }
        })
    }
}
```

### 2. 테스트 네이밍

```go
// 패턴: Test<함수><시나리오>
func TestParseConfig(t *testing.T) {}
func TestParseConfig_EmptyFile(t *testing.T) {}
func TestParseConfig_InvalidJSON(t *testing.T) {}

// 메서드: Test<타입>_<메서드>
func TestServer_Start(t *testing.T) {}
func TestServer_HandleRequest(t *testing.T) {}
```

## 테이블 드리븐 테스트

### 포괄적 예시

```go
func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name  string
        email string
        want  bool
    }{
        {"유효한 이메일", "user@example.com", true},
        {"@ 누락", "userexample.com", false},
        {"빈 문자열", "", false},
        {"@ 중복", "user@@example.com", false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            if got := ValidateEmail(tt.email); got != tt.want {
                t.Errorf("ValidateEmail(%q) = %v, want %v", tt.email, got, tt.want)
            }
        })
    }
}
```

## 서브테스트와 병렬 테스트

```go
func TestParallel(t *testing.T) {
    tests := []struct {
        name  string
        input int
    }{
        {"case1", 1},
        {"case2", 2},
    }

    for _, tt := range tests {
        tt := tt // Go 1.21 이하에서만 필요 — 1.22+ 는 반복마다 새 변수 (go.mod 의 go 지시어 기준)
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel() // 서브테스트 병렬 실행
            result := Process(tt.input)
            if result == 0 {
                t.Error("예기치 않은 0 결과")
            }
        })
    }
}
```

## 테스트 픽스처와 설정

### Setup과 Teardown

```go
func TestMain(m *testing.M) {
    // 설정
    setup()

    // 테스트 실행
    code := m.Run()

    // 정리
    teardown()

    os.Exit(code)
}

func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()

    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        t.Fatalf("테스트 db 열기 실패: %v", err)
    }

    t.Cleanup(func() {
        db.Close()
    })

    return db
}
```

## 모킹과 인터페이스

```go
// 의존성을 위한 인터페이스 정의
type UserStore interface {
    GetUser(id string) (*User, error)
    SaveUser(user *User) error
}

// 목 구현
type MockUserStore struct {
    users map[string]*User
}

func NewMockUserStore() *MockUserStore {
    return &MockUserStore{users: make(map[string]*User)}
}

func (m *MockUserStore) GetUser(id string) (*User, error) {
    user, ok := m.users[id]
    if !ok {
        return nil, ErrNotFound
    }
    return user, nil
}

func (m *MockUserStore) SaveUser(user *User) error {
    m.users[user.ID] = user
    return nil
}
```

## 벤치마킹

```go
func BenchmarkCalculate(b *testing.B) {
    for i := 0; i < b.N; i++ {
        Calculate(42)
    }
}

func BenchmarkProcessLarge(b *testing.B) {
    data := generateLargeData()
    b.ResetTimer() // 설정 후 타이머 리셋

    for i := 0; i < b.N; i++ {
        Process(data)
    }
}
```

### 여러 크기로 벤치마크

```go
func BenchmarkSort(b *testing.B) {
    sizes := []int{100, 1000, 10000}

    for _, size := range sizes {
        b.Run(fmt.Sprintf("size-%d", size), func(b *testing.B) {
            data := generateData(size)
            b.ResetTimer()

            for i := 0; i < b.N; i++ {
                Sort(data)
            }
        })
    }
}
```

## 퍼징

```go
func FuzzParse(f *testing.F) {
    // 시드 코퍼스
    f.Add("valid input")
    f.Add("123")

    f.Fuzz(func(t *testing.T, input string) {
        result, err := Parse(input)
        if err != nil {
            return // 유효하지 않은 입력은 OK
        }
        // 라운드트립 검증
        encoded := Encode(result)
        if encoded != input {
            t.Errorf("라운드트립 실패: got %q, want %q", encoded, input)
        }
    })
}
```

## 커버리지

```bash
# 커버리지 포함 테스트 실행
go test -cover ./...

# 커버리지 프로파일 생성
go test -coverprofile=coverage.out ./...

# 브라우저에서 커버리지 확인
go tool cover -html=coverage.out

# 함수별 커버리지
go tool cover -func=coverage.out

# 레이스 디텍터와 함께
go test -race -coverprofile=coverage.out ./...
```

### 커버리지 목표

| 코드 유형 | 목표 |
|---|---|
| 핵심 비즈니스 로직 | 100% |
| 공개 API | 90%+ |
| 일반 코드 | 80%+ (하네스 최소 기준) |
| 생성 코드 (mock·protobuf) | 측정 제외 |

### 생성 코드 제외

Go 커버리지는 파일 단위 제외 플래그가 없다 — 프로파일에서 생성 파일 줄을 걸러낸다.

```bash
go test -coverprofile=coverage.raw ./...
grep -vE '(_mock\.go|\.pb\.go|_gen\.go):' coverage.raw > coverage.out
go tool cover -func=coverage.out | tail -1
```

## 임시 파일·디렉터리

`t.TempDir()`은 테스트 종료 시 자동 삭제된다 — 수동 `os.RemoveAll` 정리가 필요 없다.

```go
func TestLoadConfig_파일에서_읽기(t *testing.T) {
    // Arrange
    tmp_dir := t.TempDir()
    cfg_path := filepath.Join(tmp_dir, "app.yaml")
    if err := os.WriteFile(cfg_path, []byte("port: 8080\n"), 0o600); err != nil {
        t.Fatalf("픽스처 작성 실패: %v", err)
    }

    // Act
    cfg, err := LoadConfig(cfg_path)

    // Assert
    if err != nil {
        t.Fatalf("LoadConfig() 에러: %v", err)
    }
    if cfg.Port != 8080 {
        t.Errorf("Port = %d, want 8080", cfg.Port)
    }
}
```

- 픽스처 권한은 최소로(`0o600`) — `rules/common/security.md` POSIX 권한 원칙
- 환경변수는 `t.Setenv()` — 종료 시 원복되며, `t.Parallel()`과 함께 쓰면 panic 으로 막아준다

## HTTP 핸들러 테스트

`net/http/httptest`로 서버 없이 핸들러를 직접 호출한다. 서버 구성 패턴은 스킬 `go-http-patterns` 참고.

```go
func TestUserHandler(t *testing.T) {
    tests := []struct {
        name       string
        method     string
        path       string
        body       string
        wantStatus int
    }{
        {"조회_성공", http.MethodGet, "/users/42", "", http.StatusOK},
        {"없는_사용자_404", http.MethodGet, "/users/999", "", http.StatusNotFound},
        {"생성_201", http.MethodPost, "/users", `{"name":"kim"}`, http.StatusCreated},
        {"잘못된_JSON_400", http.MethodPost, "/users", `{"name":`, http.StatusBadRequest},
    }

    handler := NewUserHandler(newFakeUserStore()) // 인터페이스 기반 페이크 주입

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Arrange
            req := httptest.NewRequest(tt.method, tt.path, strings.NewReader(tt.body))
            req.Header.Set("Content-Type", "application/json")
            rec := httptest.NewRecorder()

            // Act
            handler.ServeHTTP(rec, req)

            // Assert
            if rec.Code != tt.wantStatus {
                t.Errorf("status = %d, want %d (body=%s)", rec.Code, tt.wantStatus, rec.Body.String())
            }
        })
    }
}
```

- 바디 비교는 문자열 일치보다 `json.Unmarshal` 후 필드 비교가 덜 취약하다
- 미들웨어·라우터까지 포함한 경로는 `httptest.NewServer`로 실제 HTTP 왕복 테스트

## 통합 테스트

```go
//go:build integration
// +build integration

package mypackage

func TestDatabaseIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("통합 테스트 건너뜀")
    }

    db := setupRealDB(t)
    defer db.Close()

    // 실제 데이터베이스로 테스트
}
```

## 골든 파일 테스트

```go
var update = flag.Bool("update", false, "골든 파일 업데이트")

func TestRender(t *testing.T) {
    result := Render(input)
    golden := filepath.Join("testdata", t.Name()+".golden")

    if *update {
        os.WriteFile(golden, []byte(result), 0644)
    }

    want, _ := os.ReadFile(golden)
    if result != string(want) {
        t.Errorf("결과 불일치:\ngot: %s\nwant: %s", result, want)
    }
}
```

## 테스트 헬퍼

```go
func assertEqual[T comparable](t *testing.T, got, want T) {
    t.Helper() // 헬퍼 함수로 표시
    if got != want {
        t.Errorf("got %v, want %v", got, want)
    }
}

func requireNoError(t *testing.T, err error) {
    t.Helper()
    if err != nil {
        t.Fatalf("예기치 않은 에러: %v", err)
    }
}
```

## 빠른 참조

| 명령 | 용도 |
|---|---|
| `go test ./...` | 전체 테스트 실행 |
| `go test -v` | 상세 출력 |
| `go test -run TestName` | 특정 테스트 실행 |
| `go test -race` | 레이스 디텍터 |
| `go test -cover` | 커버리지 |
| `go test -bench=.` | 벤치마크 실행 |
| `go test -fuzz=Fuzz` | 퍼징 실행 |
| `go test -short` | 긴 테스트 건너뜀 |
| `go test -run 'TestUser/생성'` | 서브테스트 패턴 실행 |
| `go test -timeout 30s` | 행(hang) 방지 타임아웃 |
| `go test -count=10 -run TestX` | 불안정(flaky) 테스트 재현 — 캐시도 우회 |
| `go test -bench=. -benchmem` | 할당량 포함 벤치마크 |
| `go test -fuzz=FuzzParse -fuzztime=30s` | 시간 제한 퍼징 |

## CI 통합

커버리지 80% 미만이면 실패시키는 게이트 예시 (GitHub Actions):

```yaml
- uses: actions/setup-go@v5
  with:
    go-version-file: go.mod      # 버전 하드코딩 대신 go.mod 를 단일 출처로

- name: 테스트 (레이스 + 커버리지)
  run: go test -race -coverprofile=coverage.out ./...

- name: 커버리지 게이트 80%
  run: |
    total=$(go tool cover -func=coverage.out | tail -1 | grep -oE '[0-9.]+' | tail -1)
    awk -v t="$total" 'BEGIN { if (t < 80) { print "[CI] 커버리지 " t "% < 80%"; exit 1 } }'
```

## 피해야 할 안티패턴

```go
// 잘못됨: 헬퍼에서 t.Helper() 미사용
func checkResult(t *testing.T, got, want int) {
    // t.Helper() 누락
    if got != want {
        t.Errorf(...)
    }
}

// 잘못됨 (go.mod 가 go 1.21 이하일 때): 병렬 테스트에서 range 변수 미캡처
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        t.Parallel()
        // tt가 고루틴 간 공유됨! — 1.22+ 에서는 반복별 변수라 안전
    })
}

// 잘못됨: 동기화 대기에 time.Sleep — 느리고 불안정. 채널·sync.WaitGroup·조건 폴링 사용
// 잘못됨: 에러 경로 미테스트 — 테이블에 wantErr 케이스를 반드시 포함
// 잘못됨: 비공개 함수 직접 테스트 — 공개 API 로 동작을 검증

// 잘못됨: 동작 대신 구현 테스트
// 잘못됨: 리팩터링 시 깨지는 취약한 테스트
```

---

**기억**: 좋은 테스트는 자신감 있는 리팩터링을 가능하게 한다. 구현이 아닌 동작을 테스트한다.
