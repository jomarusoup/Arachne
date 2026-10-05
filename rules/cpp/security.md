---
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.hh"
  - "**/*.cxx"
---
# C++ 보안

> [common/security.md](../common/security.md) 를 확장한다.

## 메모리 안전성

- `new`/`delete` 직접 사용 금지 → 스마트 포인터
- C 스타일 배열 금지 → `std::array` 또는 `std::vector`
- `malloc`/`free` 금지 → C++ 할당 사용
- `reinterpret_cast` 최소화

## 버퍼 오버플로

- `char *` 대신 `std::string`
- 경계 검사: 핫패스가 아니면 `.at()`을 허용한다
- 핫패스는 인덱스를 사전 검증한 뒤 `operator[]` 또는 `std::span`을 쓰고, 전제는 `assert`로 표현한다
- `strcpy`, `strcat`, `sprintf` 금지 → `std::string` 또는 `fmt::format`

## 미정의 동작 방지

- 변수 반드시 초기화
- 부호 있는 정수 오버플로 방지
- null·댕글링 포인터 역참조 금지

## 민감정보

- 로그에는 개인정보를 필드 단위로 마스킹한 값만 남긴다. 개인정보 타입은 `operator<<`·`std::formatter`에서 마스킹한 값만 출력한다.
- 비밀번호·키 버퍼는 소멸자에서 `explicit_bzero`(또는 `OPENSSL_cleanse`)로 지운다. `std::string`은 재할당 때 사본이 남으므로 비밀값에는 고정 버퍼를 쓴다.
- 처리 기준 전체는 `skills/sensitive-data-handling/SKILL.md`를 따른다.

## Sanitizer 적용

```bash
# AddressSanitizer + UBSan
cmake -DCMAKE_CXX_FLAGS="-fsanitize=address,undefined" ..

# ThreadSanitizer (멀티스레드)
cmake -DCMAKE_CXX_FLAGS="-fsanitize=thread" ..
```

## 정적 분석

```bash
clang-tidy --checks='*' src/*.cpp
cppcheck --enable=all src/
```
