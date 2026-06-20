---
name: springboot-tdd
description: Spring Boot TDD 워크플로. JUnit 5, AssertJ, Mockito, MockMvc, DataJpaTest, Testcontainers를 사용한다.
---

# Spring Boot TDD

Spring Boot 기능을 테스트 먼저 구현하기 위한 작업 순서다.

## RED

기능 요구를 사용자 흐름으로 쪼갠 뒤 실패 테스트를 먼저 작성한다.

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {
    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private OrderService orderService;

    @Test
    void createOrder_returnsCreatedOrder() throws Exception {
        given(orderService.create(any()))
            .willReturn(new Order(1L, "Alice", BigDecimal.TEN));

        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"customerName":"Alice","amount":10}
                    """))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").value(1));
    }
}
```

## GREEN

- 테스트를 통과시키는 최소 controller/service/repository 구현을 추가한다.
- 아직 일반화하지 않는다.
- validation, exception, transaction은 실패 테스트가 요구하는 범위에서만 추가한다.

## REFACTOR

- 중복 fixture를 factory로 이동한다.
- service와 domain 책임을 분리한다.
- slice test와 integration test의 중복을 줄인다.

## 테스트 선택 기준

| 변경 | 우선 테스트 |
| --- | --- |
| Controller mapping, JSON shape | `@WebMvcTest` |
| Repository query, mapping | `@DataJpaTest` + Testcontainers |
| Service domain rule | JUnit unit test |
| 인증·인가 | Spring Security test |
| 전체 wiring | `@SpringBootTest` |

## 검증

```bash
./mvnw test
./mvnw verify
./gradlew test
./gradlew check
```
