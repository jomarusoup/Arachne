---
paths:
  - "**/*.java"
---
# Java 설계 패턴

> [common/patterns.md](../common/patterns.md)를 Java 백엔드에 맞게 확장한다.

## 계층 경계

Spring Boot 기준 기본 흐름은 다음을 따른다.

```text
Controller -> Application Service -> Domain Model -> Repository -> Database
```

- Controller는 HTTP 매핑, 인증 주체 추출, DTO 검증, 응답 변환만 담당한다.
- Service는 트랜잭션과 use case orchestration을 담당한다.
- Domain은 불변식과 상태 전이를 가진다.
- Repository는 영속성 세부사항을 감춘다.

## DTO와 도메인 분리

- 요청/응답 DTO를 JPA Entity로 직접 받거나 반환하지 않는다.
- 외부 API 계약은 record DTO로 명확히 둔다.
- 도메인 모델은 프레임워크 annotation 의존을 줄인다. JPA Entity가 도메인을 겸하면 경계를 문서화한다.

## 트랜잭션

- 트랜잭션은 service 계층에서 시작한다.
- 조회 경로는 `@Transactional(readOnly = true)`를 사용한다.
- 외부 API 호출, 파일 I/O, 장시간 계산을 열린 DB 트랜잭션 안에 넣지 않는다.
- 이벤트 발행은 commit 이후 동작이 필요한지 확인한다.

## 에러 모델

- 도메인 예외와 인프라 예외를 구분한다.
- API 경계에서는 exception handler로 안정적인 응답 형식에 매핑한다.
- 실패를 `null`로 표현하지 않는다. 값 없음은 `Optional`, 실패는 예외 또는 명시적 결과 타입을 사용한다.

## 동시성

- mutable shared state를 피한다.
- executor, scheduler, async 작업은 queue 크기와 timeout을 명시한다.
- `ThreadLocal` 사용 시 cleanup을 보장한다.
- 병렬 stream은 I/O 작업과 공유 pool 오염 가능성을 검토한 뒤 사용한다.

## 테스트 가능한 설계

- 시간은 `Clock`, UUID는 provider, 외부 API는 port/interface로 주입한다.
- static helper에 비즈니스 로직을 몰아넣지 않는다.
- 테스트 편의를 위해 운영 설계를 훼손하지 않는다. 대신 작은 interface와 명시적 dependency injection을 사용한다.

## 관련 스킬

- [springboot-patterns](../../skills/archive/springboot-patterns.md)
- [jpa-patterns](../../skills/archive/jpa-patterns.md)
- [api-design](../../skills/api-design.md)
