---
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.hh"
  - "**/*.cxx"
---
# C++ 패턴

> [common/patterns.md](../common/patterns.md) 를 확장한다.

## RAII — 자원 수명을 객체에 귀속

```cpp
class FileHandle
{
public:
    explicit FileHandle(const std::string &path)
        : m_file(std::fopen(path.c_str(), "r")) {}
    ~FileHandle() { if (m_file) std::fclose(m_file); }

    FileHandle(const FileHandle &)            = delete;
    FileHandle &operator=(const FileHandle &) = delete;

private:
    std::FILE *m_file;
};
```

## Rule of Five / Zero

- **Rule of Zero** — 소멸자·복사·이동 정의 불필요한 클래스 선호
- **Rule of Five** — 소멸자·복사 생성자·복사 대입·이동 생성자·이동 대입 중 하나를 정의하면 다섯 모두 정의

## 값 의미론

- 작은 타입 → 값으로 전달
- 큰 타입 → `const &` 로 전달
- 반환 → 값으로 반환 (RVO/NRVO 신뢰)
- sink 파라미터 → 이동 의미론 활용

## 소유권은 타입으로

- 단독 소유는 `std::unique_ptr`, 공유 소유는 `std::shared_ptr`(꼭 필요할 때만)로 표현한다.
- 비소유 참조는 참조·`std::span`·`std::string_view`로 받는다. 비소유 원시 포인터는 nullable 관찰자일 때만 쓴다.
- 소유권을 넘기는 함수는 `unique_ptr`을 값으로 받는다. 시그니처만 보고 해제 책임을 알 수 있어야 한다.

## 에러 처리

```cpp
/* 선택적 값 */
std::optional<Config> LoadConfig(const std::string &path);

/* 예상된 실패 — std::expected 는 C++23, C++20 에서는 tl::expected 로 대체 */
std::expected<Data, Error> ParseData(std::string_view input);
```

- 비핫패스(초기화·설정·관리)는 예외를 쓸 수 있다(D03).
- 핫패스(`// HOTPATH`) 함수는 `noexcept`로 선언하고 실패를 에러 값(`expected`·에러 코드)으로 반환한다.
  `noexcept` 함수에서 예외가 새면 `std::terminate`이므로, 호출하는 함수도 예외를 던지지 않아야 한다.

## 메모리 모델

- 스레드 간 공유 데이터는 `std::atomic`이나 락으로만 접근한다. `volatile`은 동기화 수단이 아니다(하드웨어 I/O 전용).
- `memory_order`는 명시한다. 기본 `seq_cst`에서 시작하고, `acquire`/`release`/`relaxed`로 약화할 때는 근거를 주석으로 남긴다.
- 원시 동기화는 의도가 드러나는 추상화(작업 큐·future)로 감싼다. 원칙은 [systems/philosophy.md](../systems/philosophy.md) 11절.

## 의존성 주입

```cpp
class Server
{
public:
    explicit Server(std::unique_ptr<ITransport> transport,
                    std::shared_ptr<ILogger>    logger)
        : m_transport(std::move(transport))
        , m_logger(std::move(logger)) {}
private:
    std::unique_ptr<ITransport> m_transport;
    std::shared_ptr<ILogger>    m_logger;
};
```
