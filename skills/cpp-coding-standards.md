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
- 언어 기능 선택 (`enum` vs `enum class`, 원시 포인터 vs 스마트 포인터)

### 언제 사용하지 않나

- C++ 이외 프로젝트
- 현대 C++ 기능을 채택할 수 없는 레거시 C 코드베이스
- 가이드라인이 하드웨어 제약과 충돌하는 임베디드/베어메탈 컨텍스트 (선택적 적용)

## 핵심 원칙

1. **RAII 어디서나** (P.8, R.1, E.6, CP.20): 자원 수명을 객체 수명에 귀속
2. **기본 불변성** (P.10, Con.1-5, ES.25): `const`/`constexpr`으로 시작; 변이는 예외
3. **타입 안전성** (P.4, I.4, ES.46-49, Enum.3): 컴파일 타임에 타입 시스템으로 오류 방지
4. **의도 표현** (P.3, F.1, NL.1-2, T.10): 이름·타입·개념이 목적을 전달해야 함
5. **복잡성 최소화** (F.2-3, ES.5, Per.4-5): 단순한 코드가 올바른 코드
6. **포인터 의미론보다 값 의미론** (C.10, R.3-5, F.20, CP.31): 값으로 반환하고 범위 객체 선호

## 철학 및 인터페이스 (P.*, I.*)

### 주요 규칙

| 규칙     | 요약                                  |
| -------- | ------------------------------------- |
| **P.1**  | 코드에서 아이디어를 직접 표현         |
| **P.3**  | 의도 표현                             |
| **P.4**  | 프로그램은 정적 타입 안전해야 함      |
| **P.5**  | 런타임 검사보다 컴파일 타임 검사 선호 |
| **P.8**  | 자원 누수 금지                        |
| **P.10** | 가변 데이터보다 불변 데이터 선호      |
| **I.2**  | 비-const 전역 변수 금지               |
| **I.4**  | 인터페이스를 정확하고 강하게 타입화   |
| **I.11** | 원시 포인터나 참조로 소유권 전달 금지 |
| **I.23** | 함수 인자 수를 적게 유지              |

```cpp
/* 올바름: 불변, 강하게 타입화된 인터페이스 */
struct Temperature { double kelvin; };
Temperature boil(const Temperature& water);

/* 잘못됨 */
double boil(double* temp);
int g_counter = 0;  /* I.2 위반 */
```

## 함수 (F.*)

### 주요 규칙

| 규칙     | 요약                                                     |
| -------- | -------------------------------------------------------- |
| **F.1**  | 의미 있는 연산을 신중하게 이름 붙인 함수로 묶기          |
| **F.2**  | 함수는 하나의 논리적 연산 수행                           |
| **F.3**  | 함수를 짧고 단순하게 유지                                |
| **F.4**  | 컴파일 타임에 평가될 수 있으면 `constexpr` 선언          |
| **F.6**  | 절대 던지지 않아야 하면 `noexcept` 선언                  |
| **F.16** | "in" 매개변수: 저렴한 타입은 값으로, 나머지는 `const&`로 |
| **F.20** | "out" 값에는 출력 매개변수보다 반환 값 선호              |
| **F.21** | 여러 "out" 값을 반환할 때는 구조체 반환                  |
| **F.43** | 지역 객체에 대한 포인터나 참조 반환 금지                 |

### 매개변수 전달

```cpp
/* F.16: 저렴한 타입은 값으로, 비싼 타입은 const&로 */
void print(int x);                           /* 저렴: 값으로 */
void analyze(const std::string& data);       /* 비쌈: const&로 */
void transform(std::string s);               /* sink: 값으로 (이동할 것) */

/* F.20 + F.21: 출력 매개변수 대신 반환 값 */
struct ParseResult {
    std::string token;
    int position;
};
ParseResult parse(std::string_view input);   /* 올바름: 구조체 반환 */

/* 잘못됨: 출력 매개변수 */
void parse(std::string_view input, std::string& token, int& pos);
```

### 순수 함수와 constexpr

```cpp
/* F.4 + F.8: 가능한 경우 순수, constexpr */
constexpr int factorial(int n) noexcept {
    return (n <= 1) ? 1 : n * factorial(n - 1);
}
static_assert(factorial(5) == 120);
```

### 안티패턴

- 함수에서 `T&&` 반환 (F.45)
- C 스타일 가변 인자 `va_arg` 사용 (F.55)
- 다른 스레드에 전달되는 람다에서 참조 캡처 (F.53)
- 이동 의미론을 억제하는 `const T` 반환 (F.49)

## 클래스 및 클래스 계층 (C.*)

### 주요 규칙

| 규칙      | 요약                                                              |
| --------- | ----------------------------------------------------------------- |
| **C.2**   | 불변식이 있으면 `class`, 데이터 멤버가 독립적으로 변하면 `struct` |
| **C.9**   | 멤버 노출 최소화                                                  |
| **C.20**  | 기본 연산 정의를 피할 수 있으면 Rule of Zero                      |
| **C.21**  | 복사/이동/소멸자를 정의하면 모두 처리 (Rule of Five)              |
| **C.35**  | 기본 클래스 소멸자: public virtual 또는 protected non-virtual     |
| **C.46**  | 단일 인자 생성자는 `explicit` 선언                                |
| **C.128** | 가상 함수: `virtual`, `override`, `final` 중 정확히 하나 지정     |

### Rule of Zero

```cpp
/* C.20: 컴파일러가 특수 멤버 생성하도록 허용 */
struct Employee {
    std::string name;
    std::string department;
    int id;
    /* 소멸자, 복사/이동 생성자, 대입 연산자 불필요 */
};
```

### Rule of Five

```cpp
/* C.21: 자원을 직접 관리해야 하면 다섯 모두 정의 */
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
            auto new_data = std::make_unique<char[]>(other.size_);
            std::copy_n(other.data_.get(), other.size_, new_data.get());
            data_ = std::move(new_data);
            size_ = other.size_;
        }
        return *this;
    }

    Buffer(Buffer&&) noexcept = default;
    Buffer& operator=(Buffer&&) noexcept = default;

private:
    std::unique_ptr<char[]> data_;
    std::size_t size_;
};
```

### 클래스 계층

```cpp
/* C.35 + C.128: 가상 소멸자, override 사용 */
class Shape {
public:
    virtual ~Shape() = default;
    virtual double area() const = 0;
};

class Circle : public Shape {
public:
    explicit Circle(double r) : radius_(r) {}
    double area() const override { return 3.14159 * radius_ * radius_; }
private:
    double radius_;
};
```

## 자원 관리 (R.*)

### 주요 규칙

| 규칙     | 요약                                                          |
| -------- | ------------------------------------------------------------- |
| **R.1**  | RAII를 사용해 자원을 자동으로 관리                            |
| **R.3**  | 원시 포인터(`T*`)는 비소유                                    |
| **R.5**  | 범위 객체 선호; 불필요한 힙 할당 금지                         |
| **R.11** | `new`와 `delete` 명시적 호출 금지                             |
| **R.20** | `unique_ptr` 또는 `shared_ptr`로 소유권 표현                  |
| **R.21** | 소유권 공유가 필요한 경우만 `shared_ptr`, 아니면 `unique_ptr` |
| **R.22** | `shared_ptr` 생성에는 `make_shared()` 사용                    |

```cpp
/* R.11 + R.20 + R.21: 스마트 포인터로 RAII */
auto widget = std::make_unique<Widget>("config");  /* 단독 소유권 */
auto cache  = std::make_shared<Cache>(1024);        /* 공유 소유권 */

/* R.3: 원시 포인터 = 비소유 관찰자 */
void render(const Widget* w) {  /* w를 소유하지 않음 */
    if (w) w->draw();
}
```

### RAII 패턴

```cpp
class FileHandle {
public:
    explicit FileHandle(const std::string& path)
        : handle_(std::fopen(path.c_str(), "r")) {
        if (!handle_) throw std::runtime_error("파일 열기 실패: " + path);
    }
    ~FileHandle() { if (handle_) std::fclose(handle_); }
    FileHandle(const FileHandle&) = delete;
    FileHandle& operator=(const FileHandle&) = delete;
    FileHandle(FileHandle&& other) noexcept
        : handle_(std::exchange(other.handle_, nullptr)) {}
private:
    std::FILE* handle_;
};
```

## 표현식 및 문장 (ES.*)

### 주요 규칙

| 규칙      | 요약                                                 |
| --------- | ---------------------------------------------------- |
| **ES.5**  | 범위를 작게 유지                                     |
| **ES.20** | 항상 객체 초기화                                     |
| **ES.23** | `{}` 초기화 구문 선호                                |
| **ES.25** | 수정이 의도되지 않으면 `const` 또는 `constexpr` 선언 |
| **ES.28** | `const` 변수의 복잡한 초기화에는 람다 사용           |
| **ES.45** | 매직 상수 금지; 심볼릭 상수 사용                     |
| **ES.46** | 좁히기/손실 산술 변환 금지                           |
| **ES.47** | `0`이나 `NULL` 대신 `nullptr` 사용                   |
| **ES.48** | 캐스트 금지                                          |
| **ES.50** | `const`를 캐스트로 제거 금지                         |

```cpp
const int max_retries{3};
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

### 주요 규칙

| 규칙     | 요약                                                         |
| -------- | ------------------------------------------------------------ |
| **E.2**  | 함수가 할당된 작업을 수행할 수 없음을 신호하려면 예외 던지기 |
| **E.6**  | 누수 방지에 RAII 사용                                        |
| **E.12** | 던지기가 불가능하거나 허용되지 않으면 `noexcept` 사용        |
| **E.14** | 목적에 맞게 설계된 사용자 정의 타입을 예외로 사용            |
| **E.15** | 값으로 던지고 참조로 잡기                                    |
| **E.16** | 소멸자·해제·swap은 절대 실패하면 안 됨                       |
| **E.17** | 모든 함수에서 모든 예외를 잡으려 하지 않기                   |

```cpp
/* E.14 + E.15: 커스텀 예외, 값으로 던지고 참조로 잡기 */
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

void run() {
    try {
        fetch_data("https://api.example.com");
    } catch (const NetworkError& e) {
        log_error(e.what(), e.status_code);
    } catch (const AppError& e) {
        log_error(e.what());
    }
    /* E.17: 예기치 않은 에러는 전파되도록 허용 */
}
```

## 상수 및 불변성 (Con.*)

| 규칙      | 요약                                              |
| --------- | ------------------------------------------------- |
| **Con.1** | 기본적으로 객체를 불변으로 만들기                 |
| **Con.2** | 기본적으로 멤버 함수를 `const`로 만들기           |
| **Con.3** | 기본적으로 포인터와 참조를 `const`로 전달         |
| **Con.4** | 생성 후 변경되지 않는 값에는 `const` 사용         |
| **Con.5** | 컴파일 타임에 계산 가능한 값에는 `constexpr` 사용 |

```cpp
class Sensor {
public:
    explicit Sensor(std::string id) : id_(std::move(id)) {}
    const std::string& id() const { return id_; }     /* Con.2 */
    double last_reading() const { return reading_; }
    void record(double value) { reading_ = value; }
private:
    const std::string id_;   /* Con.4 */
    double reading_{0.0};
};

constexpr double PI = 3.14159265358979;    /* Con.5 */
constexpr int MAX_SENSORS = 256;
```

## 동시성 (CP.*)

### 주요 규칙

| 규칙       | 요약                                          |
| ---------- | --------------------------------------------- |
| **CP.2**   | 데이터 경쟁 방지                              |
| **CP.3**   | 쓰기 가능한 데이터의 명시적 공유 최소화       |
| **CP.8**   | 동기화에 `volatile` 사용 금지                 |
| **CP.20**  | RAII 사용, 일반 `lock()`/`unlock()` 금지      |
| **CP.21**  | 여러 뮤텍스 획득 시 `std::scoped_lock` 사용   |
| **CP.22**  | 잠금을 유지하면서 알 수 없는 코드 호출 금지   |
| **CP.42**  | 조건 없이 대기 금지                           |
| **CP.44**  | `lock_guard`와 `unique_lock`에 항상 이름 지정 |
| **CP.100** | 꼭 필요하지 않으면 락프리 프로그래밍 금지     |

```cpp
/* CP.20 + CP.44: RAII 잠금, 항상 이름 지정 */
class ThreadSafeQueue {
public:
    void push(int value) {
        std::lock_guard<std::mutex> lock(mutex_);  /* CP.44: 이름 있음! */
        queue_.push(value);
        cv_.notify_one();
    }

    int pop() {
        std::unique_lock<std::mutex> lock(mutex_);
        cv_.wait(lock, [this] { return !queue_.empty(); });  /* CP.42: 조건으로 대기 */
        const int value = queue_.front();
        queue_.pop();
        return value;
    }
private:
    std::mutex mutex_;
    std::condition_variable cv_;
    std::queue<int> queue_;
};

/* CP.21: 여러 뮤텍스 — scoped_lock으로 데드락 방지 */
void transfer(Account& from, Account& to, double amount) {
    std::scoped_lock lock(from.mutex_, to.mutex_);
    from.balance_ -= amount;
    to.balance_ += amount;
}
```

## 템플릿 및 제네릭 프로그래밍 (T.*)

### 주요 규칙

| 규칙      | 요약                                        |
| --------- | ------------------------------------------- |
| **T.1**   | 추상화 수준을 높이기 위해 템플릿 사용       |
| **T.10**  | 모든 템플릿 인자에 컨셉 지정                |
| **T.11**  | 가능하면 표준 컨셉 사용                     |
| **T.13**  | 단순한 컨셉에는 약식 표기 선호              |
| **T.43**  | `typedef` 대신 `using` 선호                 |
| **T.120** | 정말 필요할 때만 템플릿 메타프로그래밍 사용 |
| **T.144** | 함수 템플릿 특수화 금지 (대신 오버로드)     |

### 컨셉 (C++20)

```cpp
#include <concepts>

/* T.10 + T.11: 표준 컨셉으로 템플릿 제약 */
template<std::integral T>
T gcd(T a, T b) {
    while (b != 0) { a = std::exchange(b, a % b); }
    return a;
}

/* T.13: 약식 컨셉 구문 */
void sort(std::ranges::random_access_range auto& range) {
    std::ranges::sort(range);
}

/* 도메인별 커스텀 컨셉 */
template<typename T>
concept Serializable = requires(const T& t) {
    { t.serialize() } -> std::convertible_to<std::string>;
};

template<Serializable T>
void save(const T& obj, const std::string& path);
```

### 안티패턴

- 보이는 네임스페이스에서 제약 없는 템플릿 (T.47)
- 오버로드 대신 함수 템플릿 특수화 (T.144)
- `constexpr`으로 충분한데 템플릿 메타프로그래밍 사용 (T.120)
- `using` 대신 `typedef` (T.43)

## 표준 라이브러리 (SL.*)

### 주요 규칙

| 규칙         | 요약                                             |
| ------------ | ------------------------------------------------ |
| **SL.1**     | 가능하면 라이브러리 사용                         |
| **SL.con.1** | C 배열 대신 `std::array` 또는 `std::vector` 선호 |
| **SL.str.1** | 문자 시퀀스 소유에는 `std::string` 사용          |
| **SL.str.2** | 문자 시퀀스 참조에는 `std::string_view` 사용     |
| **SL.io.50** | `endl` 금지 (`'\n'` 사용 — `endl`은 플러시 강제) |

```cpp
/* SL.con.1: C 배열 대신 vector/array */
const std::array<int, 4> fixed_data{1, 2, 3, 4};
std::vector<std::string> dynamic_data;

/* SL.str.1 + SL.str.2: string은 소유, string_view는 관찰 */
std::string build_greeting(std::string_view name) {
    return "Hello, " + std::string(name) + "!";
}

/* SL.io.50: endl 대신 '\n' */
std::cout << "result: " << value << '\n';
```

## 열거형 (Enum.*)

### 주요 규칙

| 규칙       | 요약                               |
| ---------- | ---------------------------------- |
| **Enum.1** | 매크로 대신 열거형 선호            |
| **Enum.3** | 일반 `enum` 대신 `enum class` 선호 |
| **Enum.5** | 열거자에 ALL_CAPS 사용 금지        |
| **Enum.6** | 이름 없는 열거형 금지              |

```cpp
/* Enum.3 + Enum.5: 범위 있는 enum, ALL_CAPS 금지 */
enum class Color { red, green, blue };
enum class LogLevel { debug, info, warning, error };

/* 잘못됨: 일반 enum이 이름을 유출, ALL_CAPS가 매크로와 충돌 */
enum { RED, GREEN, BLUE };           /* Enum.3 + Enum.5 + Enum.6 위반 */
#define MAX_SIZE 100                  /* Enum.1 위반 — constexpr 사용 */
```

## 소스 파일 및 네이밍 (SF.*, NL.*)

### 주요 규칙

| 규칙      | 요약                                                |
| --------- | --------------------------------------------------- |
| **SF.1**  | 코드 파일에는 `.cpp`, 인터페이스 파일에는 `.h`      |
| **SF.7**  | 헤더의 전역 범위에서 `using namespace` 금지         |
| **SF.8**  | 모든 `.h` 파일에 include guard 사용                 |
| **SF.11** | 헤더 파일은 자체 완결                               |
| **NL.5**  | 이름에 타입 정보 인코딩 금지 (헝가리안 표기법 금지) |
| **NL.8**  | 일관된 네이밍 스타일 사용                           |
| **NL.9**  | 매크로 이름에만 ALL_CAPS 사용                       |
| **NL.10** | `underscore_style` 이름 선호                        |

### 헤더 가드

```cpp
/* SF.8: Include guard (또는 #pragma once) */
#ifndef PROJECT_MODULE_WIDGET_H
#define PROJECT_MODULE_WIDGET_H

/* SF.11: 자체 완결 — 이 헤더에 필요한 모든 것 포함 */
#include <string>
#include <vector>

namespace project::module {

class Widget {
public:
    explicit Widget(std::string name);
    const std::string& name() const;
private:
    std::string name_;
};

}  /* namespace project::module */

#endif  /* PROJECT_MODULE_WIDGET_H */
```

### 네이밍 컨벤션

```cpp
/* NL.8 + NL.10: 일관된 underscore_style */
namespace my_project {

constexpr int max_buffer_size = 4096;  /* NL.9: 매크로 아니므로 ALL_CAPS 금지 */

class tcp_connection {                 /* underscore_style 클래스 */
public:
    void send_message(std::string_view msg);
    bool is_connected() const;
private:
    std::string host_;                 /* 멤버에 trailing underscore */
    int port_;
};

}  /* namespace my_project */
```

### 안티패턴

- 헤더 전역 범위에서 `using namespace std;` (SF.7)
- 포함 순서에 의존하는 헤더 (SF.10, SF.11)
- `strName`, `iCount` 같은 헝가리안 표기법 (NL.5)
- 매크로가 아닌 것에 ALL_CAPS (NL.9)

## 성능 (Per.*)

### 주요 규칙

| 규칙       | 요약                                 |
| ---------- | ------------------------------------ |
| **Per.1**  | 이유 없이 최적화 금지                |
| **Per.2**  | 조기 최적화 금지                     |
| **Per.6**  | 측정 없이 성능에 대한 주장 금지      |
| **Per.11** | 런타임에서 컴파일 타임으로 계산 이동 |
| **Per.19** | 예측 가능하게 메모리 접근            |

```cpp
/* Per.11: 컴파일 타임 계산 */
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

- [ ] raw `new`/`delete` 없음 — 스마트 포인터 또는 RAII (R.11)
- [ ] 객체가 선언 시 초기화됨 (ES.20)
- [ ] 변수는 기본적으로 `const`/`constexpr` (Con.1, ES.25)
- [ ] 멤버 함수는 가능하면 `const` (Con.2)
- [ ] 일반 `enum` 대신 `enum class` (Enum.3)
- [ ] `0`/`NULL` 대신 `nullptr` (ES.47)
- [ ] 좁히기 변환 없음 (ES.46)
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
- [ ] 템플릿 인자에 컨셉 제약 (T.10)
