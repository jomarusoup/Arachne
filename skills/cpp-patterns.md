---
name: cpp-patterns
description: C++ Core Guidelines 다이제스트 — RAII·Rule of Zero/Five·값 의미론·스마트 포인터·concepts·동시성·예외 전략. 모던 C++(17/20) 작성·리뷰·리팩터링 시 참조.
triggers:
  paths: ["**/*.cpp", "**/*.hpp", "**/*.cc"]
  keywords: ["C++ 패턴", "RAII", "스마트 포인터", "Rule of Five", "concepts", "Core Guidelines"]
---

# C++ 개발 패턴 (Core Guidelines 다이제스트)

[C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines) 기반
모던 C++(C++17/20) 패턴 다이제스트. 규칙 번호(P.8, R.11 …)는 원문 참조 키다.

> 네이밍·헤더 주석·포매팅은 이 스킬이 아니라 `rules/common/coding-style.md`
> (함수·타입 PascalCase, 지역 snake_case)와 `rules/cpp/coding-style.md`가 정본이다.
> 원문 NL.* 절(underscore_style)은 하네스 규칙과 충돌하므로 채택하지 않는다.

## 언제 사용하나

- 새 C++ 클래스·함수·템플릿 작성
- 기존 C++ 코드 리뷰·리팩터링 (code-reviewer 에이전트 보조 기준)
- 언어 기능 선택 판단 (`enum` vs `enum class`, raw pointer vs smart pointer)
- `rules/cpp/patterns.md`(요약본)보다 깊은 근거·예시가 필요할 때

### 언제 사용하지 않나

- C 전용 코드베이스 → `rules/c/*`, `linux-system-network-programming`
- 저지연 특화 판단 → `latency-critical-systems` 우선
- 테스트 작성 → `cpp-testing`

## 횡단 원칙 (전 절 공통)

1. **RAII everywhere** (P.8, R.1, E.6, CP.20) — 자원 수명을 객체 수명에 귀속
2. **불변성 기본** (P.10, Con.1-5, ES.25) — `const`/`constexpr`로 시작, 가변은 예외
3. **타입 안전** (P.4, I.4, ES.46-49) — 컴파일 타임에 오류 차단
4. **의도 표현** (P.3, F.1, T.10) — 이름·타입·concept이 목적을 말하게
5. **값 의미론 우선** (C.10, R.3-5, F.20) — 포인터 의미론보다 값 반환·스코프 객체

## 인터페이스·함수 (I.*, F.*)

| 규칙 | 요약 |
|---|---|
| I.2 | 비-const 전역 변수 금지 |
| I.4 | 인터페이스는 정밀·강타입으로 |
| I.11 | raw pointer/reference로 소유권 이전 금지 |
| F.2-3 | 함수는 단일 논리 연산, 짧고 단순하게 |
| F.4 | 컴파일 타임 평가 가능하면 `constexpr` |
| F.6 | 던지지 않는 함수는 `noexcept` |
| F.16 | "in" 인자: 저렴한 타입 값 전달, 나머지 `const&` |
| F.20-21 | "out"은 반환값으로 — 다중 반환은 struct |
| F.43 | 지역 객체의 포인터·참조 반환 금지 |

```cpp
// I.4 + F.20/21: 강타입 인터페이스, 반환은 struct로
struct ParseResult {
    std::string token;
    int         position;
};

ParseResult Parse(std::string_view input);          // GOOD

void Parse(std::string_view input,
           std::string& token, int& pos);           // BAD: 출력 인자

// F.4 + F.8: 순수 함수는 constexpr + noexcept
constexpr int Factorial(int nn) noexcept {
    return (nn <= 1) ? 1 : nn * Factorial(nn - 1);
}
static_assert(Factorial(5) == 120);
```

안티패턴: `T&&` 반환(F.45), C 가변 인자 `va_arg`(F.55), 다른 스레드로 넘기는 람다의
참조 캡처(F.53), 이동을 막는 `const T` 반환(F.49).

## 클래스 (C.*)

| 규칙 | 요약 |
|---|---|
| C.2 | 불변식 있으면 `class`, 독립 데이터면 `struct` |
| C.20 | **Rule of Zero** — 특수 멤버를 정의하지 않을 수 있으면 하지 마라 |
| C.21 | **Rule of Five** — 하나라도 정의/`=delete`하면 다섯 모두 처리 |
| C.35 | 베이스 소멸자: public virtual 또는 protected non-virtual |
| C.41 | 생성자는 완전히 초기화된 객체를 만든다 |
| C.46 | 단일 인자 생성자는 `explicit` |
| C.128 | 가상 함수는 `virtual`·`override`·`final` 중 정확히 하나 |

```cpp
// C.20: Rule of Zero — 컴파일러 생성에 맡긴다
struct Employee {
    std::string name;
    std::string department;
    int         id;
};

// C.21: 자원을 직접 관리해야만 하면 다섯 모두 정의
class Buffer {
public:
    explicit Buffer(std::size_t size)
        : data_(std::make_unique<char[]>(size)), size_(size) {}
    ~Buffer() = default;
    Buffer(const Buffer& other)
        : data_(std::make_unique<char[]>(other.size_)), size_(other.size_) {
        std::copy_n(other.data_.get(), size_, data_.get());
    }
    Buffer& operator=(const Buffer& other) {
        if (this != &other) {
            auto new_data = std::make_unique<char[]>(other.size_);  // R.13: 예외 안전
            std::copy_n(other.data_.get(), other.size_, new_data.get());
            data_ = std::move(new_data);
            size_ = other.size_;
        }
        return *this;
    }
    Buffer(Buffer&&) noexcept            = default;
    Buffer& operator=(Buffer&&) noexcept = default;

private:
    std::unique_ptr<char[]> data_;
    std::size_t             size_;
};

// C.35 + C.128: 가상 소멸자 + override
class Shape {
public:
    virtual ~Shape() = default;
    virtual double Area() const = 0;
};

class Circle : public Shape {
public:
    explicit Circle(double rr) : radius_(rr) {}
    double Area() const override { return 3.14159 * radius_ * radius_; }

private:
    double radius_;
};
```

안티패턴: 생성자·소멸자에서 가상 함수 호출(C.82), non-trivial 타입에 `memset`/`memcpy`(C.90),
멤버를 `const`·참조로 선언해 복사/이동 봉쇄(C.12).

## 자원 관리 (R.*)

| 규칙 | 요약 |
|---|---|
| R.1 | RAII로 자동 관리 |
| R.3 | raw pointer(`T*`)는 **비소유** 관찰자 |
| R.5 | 스코프 객체 우선 — 불필요한 힙 할당 금지 |
| R.10-11 | `malloc`/`free`·직접 `new`/`delete` 회피 |
| R.21 | 공유 소유가 아니면 `shared_ptr` 대신 `unique_ptr` |
| R.22 | `shared_ptr`는 `make_shared()`로 |

```cpp
auto widget = std::make_unique<Widget>("config");   // 단독 소유
auto cache  = std::make_shared<Cache>(1024);        // 공유 소유(필요할 때만)

// R.3: raw pointer = 비소유 관찰
void Render(const Widget* ww) {
    if (ww) ww->Draw();
}
Render(widget.get());

// R.1: OS 핸들도 RAII로 감싼다 — 이동 전용, 복사 금지
class FileHandle {
public:
    explicit FileHandle(const std::string& path)
        : handle_(std::fopen(path.c_str(), "r")) {
        if (!handle_) throw std::runtime_error("open 실패: " + path);
    }
    ~FileHandle() { if (handle_) std::fclose(handle_); }
    FileHandle(const FileHandle&)            = delete;
    FileHandle& operator=(const FileHandle&) = delete;
    FileHandle(FileHandle&& other) noexcept
        : handle_(std::exchange(other.handle_, nullptr)) {}
    FileHandle& operator=(FileHandle&& other) noexcept {
        if (this != &other) {
            if (handle_) std::fclose(handle_);
            handle_ = std::exchange(other.handle_, nullptr);
        }
        return *this;
    }

private:
    std::FILE* handle_;
};
```

## 표현식·불변성 (ES.*, Con.*)

- **ES.20 + ES.23**: 선언 즉시 `{}` 초기화 — `const int max_retries{3};`
- **ES.25 / Con.1-2**: 변수·멤버 함수는 `const` 기본, 변경 필요할 때만 해제
- **ES.28**: 복잡한 `const` 초기화는 즉시 실행 람다로
- **ES.45**: 매직 넘버 금지 → 심볼 상수 (하네스 `SCREAMING_SNAKE_CASE`)
- **ES.46-48**: 축소 변환·C 스타일 캐스트 금지 → `static_cast` 등 명시 캐스트
- **ES.47**: `0`/`NULL` 대신 `nullptr`
- **Con.5**: 컴파일 타임 계산 가능 값은 `constexpr`

```cpp
// ES.28: 즉시 실행 람다로 const 복합 초기화
const auto config = [&] {
    Config cc;
    cc.timeout = std::chrono::seconds{30};
    cc.retries = MAX_RETRY_COUNT;
    return cc;
}();
```

## 에러 처리 (E.*)

- **E.2**: 함수가 임무를 수행할 수 없음을 예외로 알린다
- **E.14 + E.15**: 목적 설계된 사용자 타입을 **값으로 던지고 참조로 잡는다**
- **E.16**: 소멸자·해제·swap은 절대 실패 금지 (`noexcept`)
- **E.17**: 모든 함수에서 모든 예외를 잡으려 하지 마라 — 처리할 수 있는 곳에서만

```cpp
class AppError : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

class NetworkError : public AppError {
public:
    NetworkError(const std::string& msg, int code)
        : AppError(msg), status_code(code) {}
    int status_code;
};

try {
    FetchData(url);
} catch (const NetworkError& ee) {          // E.15: 참조로 캐치 (슬라이싱 방지)
    LogError(ee.what(), ee.status_code);
}
```

안티패턴: `int`·문자열 리터럴 던지기(E.14), 값 캐치(슬라이싱), 빈 catch로 삼키기,
흐름 제어용 예외(E.3), `errno` 같은 전역 상태 기반 에러(E.28).

## 동시성 (CP.*)

- **CP.20 + CP.44**: 락은 RAII로, 반드시 **이름 있는** guard — `std::lock_guard<std::mutex>(m_);`은 즉시 소멸하는 버그
- **CP.21**: 다중 뮤텍스는 `std::scoped_lock` (데드락 프리)
- **CP.22**: 락 잡은 채 미지의 코드(콜백) 호출 금지
- **CP.42**: 조건 없는 `wait` 금지 — predicate와 함께
- **CP.8**: `volatile`은 동기화 수단이 아니다 (하드웨어 I/O 전용)
- **CP.100**: lock-free는 최후 수단 (`latency-critical-systems` 참조)

```cpp
class ThreadSafeQueue {
public:
    void Push(int value) {
        std::lock_guard<std::mutex> lock(mutex_);           // CP.44: 이름 필수
        queue_.push(value);
        cv_.notify_one();
    }
    int Pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return !queue_.empty(); }); // CP.42: 조건과 함께
        const int value = queue_.front();
        queue_.pop();
        return value;
    }

private:
    std::mutex              mutex_;     // CP.50: 뮤텍스는 데이터와 함께
    std::condition_variable cv_;
    std::queue<int>         queue_;
};
```

## 템플릿·표준 라이브러리 (T.*, SL.*, Enum.*)

- **T.10-11**: 템플릿 인자는 concept으로 제약 — 표준 concept 우선
- **T.43**: `typedef` 대신 `using`
- **T.144**: 함수 템플릿 특수화 금지 → 오버로드
- **SL.con.1-2**: C 배열 대신 `std::array`/`std::vector` — 기본은 `vector`
- **SL.str.1-2**: 소유는 `std::string`, 관찰은 `std::string_view`
- **SL.io.50**: `std::endl` 금지 (flush 강제) → `'\n'`
- **Enum.1 + Enum.3**: 매크로·plain enum 대신 `enum class`

```cpp
// T.10 + T.11: 표준 concept 제약
template<std::integral T>
T Gcd(T aa, T bb) {
    while (bb != 0) aa = std::exchange(bb, aa % bb);
    return aa;
}

// 도메인 concept
template<typename T>
concept Serializable = requires(const T& tt) {
    { tt.Serialize() } -> std::convertible_to<std::string>;
};

enum class LogLevel { debug, info, warning, error };   // Enum.3
```

## 성능 (Per.*)

- **Per.1-2, Per.6**: 측정 없이 최적화·성능 주장 금지 → `performance-profiling` 스킬
- **Per.11**: 런타임 계산을 컴파일 타임으로 (`constexpr` 룩업 테이블)
- **Per.19**: 예측 가능한 메모리 접근 — `std::vector<Point>`(연속) >
  `std::vector<std::unique_ptr<Point>>`(포인터 추적)

## 완료 전 체크리스트

- [ ] raw `new`/`delete` 없음 — 스마트 포인터·RAII (R.11)
- [ ] 선언 즉시 초기화, `const`/`constexpr` 기본 (ES.20, Con.1)
- [ ] 단일 인자 생성자 `explicit` (C.46)
- [ ] Rule of Zero 또는 Five 적용 (C.20/21)
- [ ] 베이스 소멸자 public virtual / protected non-virtual (C.35)
- [ ] 템플릿 concept 제약 (T.10)
- [ ] 헤더: include guard + 자기완결, 전역 `using namespace` 금지 (SF.7/8/11)
- [ ] 락 RAII + 이름, 예외는 값 던지고 참조 캐치 (CP.20/44, E.15)
- [ ] `nullptr`·명시 캐스트·`enum class`·`'\n'` (ES.47/48, Enum.3, SL.io.50)
- [ ] 매직 넘버 없음 (ES.45)
