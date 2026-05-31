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
        : file_(std::fopen(path.c_str(), "r")) {}
    ~FileHandle() { if (file_) std::fclose(file_); }

    FileHandle(const FileHandle &)            = delete;
    FileHandle &operator=(const FileHandle &) = delete;

private:
    std::FILE *file_;
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

## 에러 처리

```cpp
/* 선택적 값 */
std::optional<Config> LoadConfig(const std::string &path);

/* 예상된 실패 (C++23) */
std::expected<Data, Error> ParseData(std::string_view input);
```

## 의존성 주입

```cpp
class Server
{
public:
    explicit Server(std::unique_ptr<ITransport> transport,
                    std::shared_ptr<ILogger>    logger)
        : transport_(std::move(transport))
        , logger_(std::move(logger)) {}
private:
    std::unique_ptr<ITransport> transport_;
    std::shared_ptr<ILogger>    logger_;
};
```
