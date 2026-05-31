---
name: golang-testing
description: 테이블 드리븐 테스트·서브테스트·벤치마크·퍼징·테스트 커버리지를 포함한 Go 테스팅 패턴. TDD 방법론과 이디엄틱 Go 관행 준수.
origin: ECC
---

# Go 테스팅 패턴

TDD 방법론과 이디엄틱 Go 관행을 따르는 포괄적 Go 테스팅 패턴.

## 언제 활성화하나

- Go 코드 테스트 작성
- 테스트 인프라 설정
- 벤치마크 또는 퍼징 추가
- 테스트 커버리지 개선
- 테스트 리팩터링

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
        tt := tt // range 변수 캡처
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
```

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

## 피해야 할 안티패턴

```go
// 잘못됨: 헬퍼에서 t.Helper() 미사용
func checkResult(t *testing.T, got, want int) {
    // t.Helper() 누락
    if got != want {
        t.Errorf(...)
    }
}

// 잘못됨: 병렬 테스트에서 range 변수 미캡처
for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        t.Parallel()
        // tt가 고루틴 간 공유됨!
    })
}

// 잘못됨: 동작 대신 구현 테스트
// 잘못됨: 리팩터링 시 깨지는 취약한 테스트
```

---

**기억**: 좋은 테스트는 자신감 있는 리팩터링을 가능하게 한다. 구현이 아닌 동작을 테스트한다.
