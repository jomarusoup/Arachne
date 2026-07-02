---
name: jpa-patterns
description: JPA/Hibernate entity, relationship, transaction, query optimization, N+1 방지, projection, pagination, auditing 패턴.
triggers:
  paths: ["**/*.java"]
  keywords: ["JPA", "Hibernate", "entity", "N+1", "transaction", "projection"]
---

# JPA/Hibernate 패턴

Spring Boot에서 JPA/Hibernate를 사용할 때 데이터 모델과 성능 문제를 예방하기 위한 기준이다.

## Entity 설계

```java
@Entity
@Table(name = "orders", indexes = {
    @Index(name = "idx_orders_customer_id", columnList = "customer_id")
})
public class OrderEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 120)
    private String customerName;

    @Column(nullable = false, precision = 19, scale = 4)
    private BigDecimal amount;
}
```

- 테이블명, 컬럼 길이, null 가능 여부를 명시한다.
- 금액은 float/double이 아니라 `BigDecimal`을 사용한다.
- enum은 `EnumType.STRING`을 기본으로 한다.
- 양방향 관계는 필요할 때만 사용한다.

## 관계와 N+1 방지

- collection 관계는 기본 lazy loading을 유지한다.
- `EAGER` collection은 금지에 가깝게 취급한다.
- 조회 use case에 맞게 fetch join, entity graph, DTO projection을 선택한다.

```java
@Query("select o from OrderEntity o left join fetch o.items where o.id = :id")
Optional<OrderEntity> findWithItems(@Param("id") Long id);
```

## Repository

```java
public interface OrderRepository extends JpaRepository<OrderEntity, Long> {
    Optional<OrderEntity> findByExternalId(String externalId);

    @Query("select o from OrderEntity o where o.status = :status")
    Page<OrderEntity> findByStatus(@Param("status") OrderStatus status, Pageable pageable);
}
```

- 복잡한 동적 쿼리는 Specification, QueryDSL, jOOQ 중 프로젝트 표준을 따른다.
- 무거운 읽기 경로는 Entity 대신 projection을 사용한다.

## Transaction

- service method에 `@Transactional`을 둔다.
- 읽기 전용 경로는 `@Transactional(readOnly = true)`를 둔다.
- lazy loading을 view rendering까지 끌고 가지 않는다. Open Session In View는 명시적으로 판단한다.

## Pagination

- 큰 테이블에서 offset pagination 비용을 확인한다.
- 무한 스크롤이나 대규모 feed는 keyset/cursor pagination을 검토한다.
- 정렬 컬럼에는 index가 필요하다.

## 검증

- repository query는 통합 테스트로 검증한다.
- 실제 DB 방언 차이가 있으면 H2 대신 Testcontainers를 사용한다.
- 성능 이슈는 SQL 로그와 EXPLAIN으로 증명한다.
