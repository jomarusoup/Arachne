---
paths:
  - "**/*.java"
---
# Java 코딩 스타일

> [common/coding-style.md](../common/coding-style.md)를 Java에 맞게 확장한다.

## 포매팅

- 프로젝트 표준에 맞춰 `google-java-format` 또는 Checkstyle을 사용한다.
- 공개 top-level 타입은 파일 하나에 하나만 둔다.
- 들여쓰기는 프로젝트 표준을 따른다. 신규 프로젝트는 4 스페이스를 기본으로 한다.
- 멤버 순서는 상수, 필드, 생성자, public 메서드, protected 메서드, private 메서드 순으로 정리한다.
- import는 와일드카드 없이 정렬하고, 사용하지 않는 import를 남기지 않는다.

## 네이밍

| 대상 | 규칙 | 예 |
| --- | --- | --- |
| class, interface, record, enum | PascalCase | `OrderService` |
| method, field, parameter, local variable | camelCase | `orderCount` |
| `static final` 상수 | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| package | 소문자 reverse domain | `com.example.billing` |

테스트 이름은 동작을 드러내게 작성한다. 한글 테스트명이 허용되는 프로젝트라면 실패 조건과 기대 결과를 포함한다.

## 불변성

- 값 타입은 Java 16+에서 `record`를 우선한다.
- 필드는 기본적으로 `final`로 선언하고, 변경 가능한 상태는 명시적 이유가 있을 때만 사용한다.
- public API에서 컬렉션을 반환할 때는 `List.copyOf`, `Map.copyOf`, `Set.copyOf` 등 방어적 복사를 사용한다.
- setter 중심 엔티티와 DTO를 남발하지 않는다. 생성 시 유효한 상태를 만들고, 상태 전이는 의미 있는 메서드로 표현한다.

```java
public record OrderSummary(Long id, String customerName, BigDecimal total) {}

public class Order {
    private final Long id;
    private final List<LineItem> items;

    public List<LineItem> getItems() {
        return List.copyOf(items);
    }
}
```

## 현대 Java 기능

- DTO와 값 타입에는 `record`를 사용한다.
- 닫힌 타입 계층은 Java 17+의 sealed type으로 모델링한다.
- `instanceof` 패턴 매칭으로 불필요한 캐스팅을 줄인다.
- SQL, JSON 템플릿 등 여러 줄 문자열에는 text block을 사용한다.
- 상태 분기는 switch expression을 선호한다.

```java
public sealed interface PaymentMethod permits CreditCard, BankTransfer, Wallet {}

String label = switch (status) {
    case ACTIVE -> "Active";
    case SUSPENDED -> "Suspended";
    case CLOSED -> "Closed";
};
```

## Optional 사용

- 결과가 없을 수 있는 finder 메서드 반환값에만 `Optional<T>`를 사용한다.
- `Optional.get()`은 금지한다. `map`, `flatMap`, `orElseThrow`를 사용한다.
- 필드나 메서드 파라미터 타입으로 `Optional`을 쓰지 않는다.

```java
return repository.findById(id)
    .map(OrderResponse::from)
    .orElseThrow(() -> new OrderNotFoundException(id));
```

## 예외 처리

- 복구 가능한 외부 실패는 checked exception 또는 결과 타입으로 경계에서 명확히 처리한다.
- 도메인 불변식 위반은 의미 있는 unchecked exception으로 표현한다.
- 예외를 삼키지 않는다. 로그에는 맥락을 남기고 사용자 응답에는 내부 정보를 노출하지 않는다.
- `catch (Exception e)`는 경계 계층(controller, worker entrypoint, scheduler)에서만 허용한다.

## 관련 스킬

- [java-coding-standards](../../skills/archive/java-coding-standards.md)
- [springboot-patterns](../../skills/archive/springboot-patterns.md)
- [jpa-patterns](../../skills/archive/jpa-patterns.md)
