---
paths:
  - "**/*.java"
---
# Java 테스트

> [common/testing.md](../common/testing.md)를 Java/JVM 프로젝트에 맞게 확장한다.

## 기본 도구

- 단위 테스트: JUnit 5
- Assertion: AssertJ
- Mocking: Mockito 또는 MockK(Kotlin 혼합 프로젝트)
- 통합 테스트: Testcontainers
- Spring Boot: `@SpringBootTest`, `@WebMvcTest`, `@DataJpaTest`를 목적별로 선택
- 커버리지: JaCoCo

## TDD 흐름

1. 실패하는 테스트를 먼저 작성한다.
2. 실패를 확인한다.
3. 가장 작은 구현으로 통과시킨다.
4. 리팩터링 후 전체 테스트를 다시 실행한다.

## 테스트 분류

| 유형 | 목적 | 예 |
| --- | --- | --- |
| Unit | 순수 로직과 도메인 불변식 | entity state transition, validator |
| Slice | 계층 일부 검증 | `@WebMvcTest`, `@DataJpaTest` |
| Integration | DB, queue, 외부 adapter 포함 | Testcontainers PostgreSQL |
| E2E | 사용자 흐름 | API smoke, browser flow |

## AAA 패턴

```java
@Test
void createOrder_rejectsEmptyCustomerName() {
    // Arrange
    CreateOrderRequest request = new CreateOrderRequest("", BigDecimal.TEN);

    // Act
    Throwable thrown = catchThrowable(() -> service.create(request));

    // Assert
    assertThat(thrown).isInstanceOf(IllegalArgumentException.class);
}
```

## 통합 테스트 원칙

- 실제 DB 동작이 중요한 코드는 H2 대신 Testcontainers PostgreSQL/MySQL을 사용한다.
- 테스트 데이터는 factory/builder로 만든다.
- 테스트 간 순서 의존성을 금지한다.
- 외부 HTTP API는 WireMock, MockWebServer 또는 contract test로 격리한다.

## 검증 명령 예시

```bash
./mvnw test
./mvnw verify
./gradlew test
./gradlew check
```

## 관련 스킬

- [springboot-tdd](../../skills/springboot-tdd.md)
- [springboot-verification](../../skills/springboot-verification.md)
