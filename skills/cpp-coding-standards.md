---
name: cpp-coding-standards
description: C++ Core Guidelines(isocpp.github.io) 기반 C++ 코딩 표준. C++ 코드 작성·검토·리팩터링 시 현대적·안전·이디엄적 관행 강제.
origin: ECC
---

# C++ 코딩 표준 (C++ Core Guidelines)

[C++ Core Guidelines](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines)에서 파생된 현대 C++ (C++17/20/23) 포괄적 코딩 표준.
타입 안전성, 자원 안전성, 불변성, 명확성 강제.

## 언제 사용하나

- 새 C++ 코드 작성 (클래스, 함수, 템플릿)
- 기존 C++ 코드 검토 또는 리팩터링
- C++ 프로젝트에서 아키텍처 결정
- C++ 코드베이스 전반의 일관된 스타일 강제
- 언어 기능 선택 (예: `enum` vs `enum class`, 원시 포인터 vs 스마트 포인터)

### 언제 사용하지 않나

- C++ 이외 프로젝트
- 현대 C++ 기능을 채택할 수 없는 레거시 C 코드베이스
- 가이드라인이 하드웨어 제약과 충돌하는 임베디드/베어메탈 컨텍스트 (선택적 적용)

## 핵심 원칙

전체 가이드라인에서 반복되는 기반 주제:

1. **RAII 어디서나** (P.8, R.1, E.6, CP.20): 자원 수명을 객체 수명에 귀속
2. **기본 불변성** (P.10, Con.1-5, ES.25): `const`/`constexpr`으로 시작; 변이는 예외
3. **타입 안전성** (P.4, I.4, ES.46-49, Enum.3): 컴파일 타임에 타입 시스템으로 오류 방지
4. **의도 표현** (P.3, F.1, NL.1-2, T.10): 이름·타입·개념이 목적을 전달해야 함
5. **복잡성 최소화** (F.2-3, ES.5, Per.4-5): 단순한 코드가 올바른 코드
6. **포인터 의미론보다 값 의미론** (C.10, R.3-5, F.20, CP.31): 값으로 반환하고 범위 객체 선호

## 철학 및 인터페이스 (P.*, I.*)

### 주요 규칙

| 규칙 | 요약 |
|---|---|
| **P.1** | 코드에서 아이디어를 직접 표현 |
| **P.3** | 의도 표현 |
| **P.4** | 이상적으로 프로그램은 정적 타입 안전해야 함 |
| **P.5** | 런타임 검사보다 컴파일 타임 검사 선호 |
| **P.8** | 자원 누수 금지 |
| **P.10** | 가변 데이터보다 불변 데이터 선호 |
| **I.1** | 인터페이스를 명시적으로 만들기 |
| **I.2** | 비-const 전역 변수 금지 |
| **I.4** | 인터페이스를 정확하고 강하게 타입화 |
| **I.11** | 원시 포인터나 참조로 소유권 전달 금지 |
| **I.23** | 함수 인자 수를 적게 유지 |

```cpp
/* 올바름: 불변, 강하게 타입화된 인터페이스 */
struct Temperature { double kelvin; };
Temperature boil(const Temperature& water);

/* 잘못됨: 불명확한 소유권, 불명확한 단위 */
double boil(double* temp);
int g_counter = 0;  /* I.2 위반 */
```

## 함수 (F.*)

### 주요 규칙

| 규칙 | 요약 |
|---|---|
| **F.1** | 의미 있는 연산을 함수로 묶기 |
| **F.2** | 함수는 하나의 논리적 연산 수행 |
| **F.3** | 함수를 짧고 단순하게 유지 |
| **F.15** | 정보 전달 방법을 단순하고 전통적으로 |
| **F.20** | 출력 값에는 반환 값 선호 |
| **F.21** | 여러 출력 값을 반환할 때는 구조체나 튜플 반환 |

```cpp
/* F.20: 출력 매개변수 대신 반환 값 선호 */
/* 잘못됨 */
void get_name(std::string* out_name);

/* 올바름 */
std::string get_name();

/* F.21: 여러 값 반환 */
std::pair<std::string, int> get_name_and_age();
auto [name, age] = get_name_and_age();  /* 구조화 바인딩 */
```

## 클래스 및 클래스 계층 (C.*)

### 주요 규칙

| 규칙 | 요약 |
|---|---|
| **C.2** | 불변식이 있는 경우 클래스 사용 |
| **C.7** | 클래스 정의에 비멤버 함수 포함 금지 |
| **C.20** | 특수 연산 정의를 피할 수 있으면 Rule of Zero 사용 |
| **C.21** | 특수 연산을 정의·삭제하면 모두 정의/삭제 (Rule of Five) |
| **C.35** | 기본 클래스 소멸자는 public virtual 또는 protected non-virtual |
| **C.46** | 단일 인자 생성자는 explicit 선언 |

### Rule of Zero / Five

```cpp
/* Rule of Zero: 스마트 포인터 사용 시 특수 연산 불필요 */
class Widget {
public:
    explicit Widget(std::string name) : name_(std::move(name)) {}
    const std::string& name() const { return name_; }
private:
    std::string name_;  /* 자동 복사/이동/소멸 */
};

/* Rule of Five: 수동 자원 관리 시 다섯 모두 정의 */
class FileHandle {
public:
    explicit FileHandle(const char* path);
    ~FileHandle();
    FileHandle(const FileHandle&) = delete;
    FileHandle& operator=(const FileHandle&) = delete;
    FileHandle(FileHandle&&) noexcept;
    FileHandle& operator=(FileHandle&&) noexcept;
private:
    int fd_{-1};
};
```

## 자원 관리 (R.*)

### RAII 패턴

```cpp
/* R.1: RAII로 자원 수명 관리 */
class MutexGuard {
public:
    explicit MutexGuard(std::mutex& m) : mutex_(m) { mutex_.lock(); }
    ~MutexGuard() { mutex_.unlock(); }
    MutexGuard(const MutexGuard&) = delete;
private:
    std::mutex& mutex_;
};

/* R.11: raw new/delete 금지 */
/* 잘못됨 */
Widget* w = new Widget("button");
delete w;

/* 올바름 */
auto w = std::make_unique<Widget>("button");
```

## 표현식 및 문장 (ES.*)

### 초기화

```cpp
/* ES.20 + ES.23 + ES.25: 항상 초기화, {} 선호, 기본값은 const */
const int max_retries{3};
const std::string name{"widget"};
const std::vector<int> primes{2, 3, 5, 7, 11};

/* ES.28: 복잡한 const 초기화에는 람다 */
const auto config = [&] {
    Config c;
    c.timeout = std::chrono::seconds{30};
    c.retries = max_retries;
    return c;
}();
```

## 에러 처리 (E.*)

```cpp
/* E.14: 커스텀 예외 타입 */
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

/* E.15: 값으로 던지고 참조로 잡기 */
void run() {
    try {
        fetch_data("https://api.example.com");
    } catch (const NetworkError& e) {
        log_error(e.what(), e.status_code);
    } catch (const AppError& e) {
        log_error(e.what());
    }
}
```

## 상수 및 불변성 (Con.*)

```cpp
class Sensor {
public:
    explicit Sensor(std::string id) : id_(std::move(id)) {}

    const std::string& id() const { return id_; }   /* Con.2: 기본 const 멤버 함수 */
    double last_reading() const { return reading_; }
    void record(double value) { reading_ = value; }

private:
    const std::string id_;   /* Con.4: 생성 후 변경 없음 */
    double reading_{0.0};
};

/* Con.5: 컴파일 타임 상수 */
constexpr double PI = 3.14159265358979;
constexpr int MAX_SENSORS = 256;
```

## 동시성 (CP.*)

### 안전한 잠금

```cpp
/* CP.20: RAII 잠금 */
std::mutex mtx;
{
    std::scoped_lock lock{mtx};
    /* 임계 구역 */
}  /* 자동 해제 */

/* CP.21: 여러 뮤텍스 획득 시 scoped_lock */
std::scoped_lock lock{mtx1, mtx2};  /* 데드락 방지 */

/* CP.42: 조건으로 대기 */
std::condition_variable cv;
std::unique_lock<std::mutex> lock{mtx};
cv.wait(lock, [&] { return !queue.empty(); });  /* spurious wake 방지 */
```

## 네이밍 (NL.*)

```cpp
namespace my_project {

constexpr int max_buffer_size = 4096;

class tcp_connection {                  /* underscore_style */
public:
    void send_message(std::string_view msg);
    bool is_connected() const;

private:
    std::string host_;                  /* 멤버에 trailing underscore */
    int port_;
};

}  /* namespace my_project */
```

## 성능 (Per.*)

```cpp
/* Per.11: 가능한 경우 컴파일 타임 계산 */
constexpr auto lookup_table = [] {
    std::array<int, 256> table{};
    for (int i = 0; i < 256; ++i) table[i] = i * i;
    return table;
}();

/* Per.19: 캐시 친화적 연속 데이터 선호 */
std::vector<Point> points;                          /* 올바름: 연속적 */
std::vector<std::unique_ptr<Point>> indirect;       /* 잘못됨: 포인터 체이싱 */
```

## 빠른 참조 체크리스트

C++ 작업 완료 전:

- [ ] raw `new`/`delete` 없음 — 스마트 포인터 또는 RAII 사용 (R.11)
- [ ] 객체가 선언 시 초기화됨 (ES.20)
- [ ] 변수는 기본적으로 `const`/`constexpr` (Con.1, ES.25)
- [ ] 멤버 함수는 가능하면 `const` (Con.2)
- [ ] 일반 `enum` 대신 `enum class` (Enum.3)
- [ ] `0`/`NULL` 대신 `nullptr` (ES.47)
- [ ] 축소 변환 없음 (ES.46)
- [ ] C 스타일 캐스트 없음 (ES.48)
- [ ] 단일 인자 생성자는 `explicit` (C.46)
- [ ] Rule of Zero 또는 Rule of Five 적용 (C.20, C.21)
- [ ] 기본 클래스 소멸자가 public virtual 또는 protected non-virtual (C.35)
- [ ] 잠금에 RAII (`scoped_lock`/`lock_guard`) 사용 (CP.20)
- [ ] 예외는 커스텀 타입, 값으로 던지고 참조로 잡기 (E.14, E.15)
- [ ] `std::endl` 대신 `'\n'` (SL.io.50)
- [ ] 매직 넘버 없음 (ES.45)
- [ ] 헤더에 전역 범위 `using namespace` 없음 (SF.7)
- [ ] 헤더에 include guard가 있고 자체 완결 (SF.8, SF.11)
