---
name: springboot-patterns
description: Spring Boot REST API, layered service, validation, exception handler, profile, caching, async, event-driven backend 패턴.
---

# Spring Boot 패턴

프로덕션 Spring Boot 서비스를 만들거나 리뷰할 때 사용한다.

## 언제 사용하나

- REST API를 추가할 때
- Controller-Service-Repository 계층을 정리할 때
- validation, exception handler, pagination을 설계할 때
- Spring Data JPA, cache, async, Kafka/Spring Event를 붙일 때
- dev/staging/prod profile을 구성할 때

## 기본 계층

```text
Controller -> Application Service -> Domain -> Repository -> Database
```

Controller는 얇게 유지한다. 비즈니스 판단과 트랜잭션은 service에 둔다.

## REST Controller

```java
@RestController
@RequestMapping("/api/orders")
@Validated
class OrderController {
    private final OrderService orderService;

    OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping
    ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrderRequest request) {
        Order order = orderService.create(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(OrderResponse.from(order));
    }
}
```

## DTO와 Validation

```java
public record CreateOrderRequest(
    @NotBlank @Size(max = 120) String customerName,
    @NotNull @Positive BigDecimal amount
) {}
```

- 요청 DTO에는 Bean Validation을 사용한다.
- 응답 DTO는 Entity를 직접 노출하지 않는다.
- 검증 실패 응답 형식은 프로젝트 전체에서 통일한다.

## Service와 Transaction

```java
@Service
public class OrderService {
    private final OrderRepository orderRepository;

    public OrderService(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @Transactional
    public Order create(CreateOrderRequest request) {
        Order order = Order.create(request.customerName(), request.amount());
        return orderRepository.save(order);
    }
}
```

- 읽기 경로는 `@Transactional(readOnly = true)`를 사용한다.
- 외부 API 호출을 DB 트랜잭션 안에 넣지 않는다.
- repository가 반환한 Entity를 controller까지 그대로 올리지 않는다.

## Exception Handler

```java
@RestControllerAdvice
class ApiExceptionHandler {
    @ExceptionHandler(OrderNotFoundException.class)
    ResponseEntity<ApiError> notFound(OrderNotFoundException exception) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(ApiError.of("order_not_found", "Order was not found"));
    }
}
```

## 운영 설정

- profile별 설정을 분리한다.
- 운영 secret은 환경변수나 secret manager에서 주입한다.
- actuator health endpoint는 공개 범위를 제한한다.
- structured logging과 correlation id를 고려한다.

## 관련 스킬

- [springboot-security](springboot-security.md)
- [springboot-tdd](springboot-tdd.md)
- [jpa-patterns](jpa-patterns.md)
