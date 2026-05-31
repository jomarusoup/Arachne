---
paths:
  - "**/*.cpp"
  - "**/*.hpp"
  - "**/*.cc"
  - "**/*.hh"
  - "**/*.cxx"
---
# C++ 코딩 스타일

> [common/coding-style.md](../common/coding-style.md) 를 확장한다.
> C 규칙([c/coding-style.md](../c/coding-style.md))도 함께 적용한다.

## 헤더 형식

C와 동일한 `/*###*/` / `/*===*/` 형식 사용.

```cpp
/*#############################################################################
FILE NAME   : 파일명.cpp
DESCRIPTION : 파일 역할 한 줄 요약
DATA        : YYYY-MM-DD
Modification: YYYY-MM-DD
#############################################################################*/
```

## Modern C++ (C++17/20)

- `auto` — 타입이 문맥상 명확할 때 사용
- `constexpr` — 컴파일 타임 상수
- structured bindings — `auto [key, val] = entry;`
- range-based for — `for (const auto &item : items)`

## 자원 관리 — RAII 필수

```cpp
/* BAD: 수동 new/delete */
Resource *res = new Resource();
// ...
delete res;

/* GOOD: 스마트 포인터 */
auto res = std::make_unique<Resource>();
```

- `std::unique_ptr` — 단독 소유권
- `std::shared_ptr` — 공유 소유권이 실제로 필요한 경우만
- `std::make_unique` / `std::make_shared` 사용 (`new` 직접 사용 금지)

## 네이밍 (C++ 전용)

- 클래스·구조체: `PascalCase` (`ConnectionManager`, `MsgParser`)
- 멤버 변수: `m_snake_case` (`m_server_fd`, `m_is_running`)
- 네임스페이스: `lowercase` (`ipc`, `net`, `util`)
- 템플릿 파라미터: 단일 대문자 (`T`, `U`) 또는 `PascalCase`

## 중괄호 스타일 — Allman (C와 동일)

```cpp
class ConnectionManager
{
public:
    bool Connect(const std::string &host)
    {
        if (host.empty())
        {
            return false;
        }
        return true;
    }
};
```

## 포매팅

- `clang-format` 강제 적용 — 커밋 전 `clang-format -i <파일>` 실행
- 헤더 인클루드: `#pragma once` 사용 (include guard 대신)
