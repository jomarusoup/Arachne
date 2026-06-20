---
name: java-coding-standards
description: Java 코드 작성·리뷰 기준. record, sealed type, Optional, 예외, 컬렉션 불변성, 패키지 구조, Maven/Gradle 검증을 다룬다.
---

# Java 코딩 표준

Java 백엔드 작업에서 기본으로 적용할 실무 기준이다. Spring Boot나 Quarkus를 쓰더라도 이 문서를 먼저 적용한다.

## 언제 사용하나

- Java 파일을 새로 만들거나 수정할 때
- Java 코드 리뷰를 할 때
- DTO, service, repository, exception 구조를 정리할 때
- Maven/Gradle 프로젝트의 검증 기준을 정할 때

## 핵심 규칙

- 값 타입은 `record`를 우선한다.
- 필드는 기본적으로 `final`이다.
- `Optional`은 반환값에만 쓴다.
- public API는 mutable collection을 그대로 반환하지 않는다.
- 예외는 계층 경계에서 의미 있는 타입으로 변환한다.
- `null`은 도메인 상태가 아니라 경계 입력으로만 취급하고 즉시 검증한다.

## 패키지 구조

작은 서비스의 기본 구조:

```text
com.example.app
├── api          # controller, request/response DTO
├── application  # use case service
├── domain       # model, domain service, domain exception
├── persistence  # entity, repository adapter
└── config       # framework configuration
```

프레임워크 의존을 domain에 끌어들이지 않는 것이 기본이다. JPA Entity를 domain으로 겸용할 때는 이유와 한계를 문서화한다.

## 리뷰 체크리스트

- [ ] DTO와 Entity가 무분별하게 섞이지 않았다.
- [ ] 트랜잭션 경계가 service에 있다.
- [ ] 입력 검증이 controller 또는 command boundary에 있다.
- [ ] `Optional.get()`이 없다.
- [ ] 컬렉션 반환이 방어적이다.
- [ ] 예외 메시지에 비밀값이나 내부 경로가 없다.
- [ ] 테스트가 단위, slice, 통합 중 적절한 수준을 선택했다.

## 검증 명령

```bash
./mvnw test
./mvnw verify
./gradlew test
./gradlew check
```

프로젝트 wrapper가 있으면 system Maven/Gradle보다 wrapper를 우선한다.
