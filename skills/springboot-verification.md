---
name: springboot-verification
description: Spring Boot 변경 후 빌드, 테스트, 정적 분석, 보안, 컨테이너 검증을 묶어 실행하는 체크리스트.
---

# Spring Boot 검증 루프

Spring Boot 변경을 "완료"라고 부르기 전 실행할 검증 순서다.

## 빠른 로컬 루프

Maven:

```bash
./mvnw test
```

Gradle:

```bash
./gradlew test
```

## 전체 검증

```bash
./mvnw verify
./gradlew check
```

프로젝트에 다음 도구가 있으면 함께 실행한다.

```bash
./mvnw spotless:check checkstyle:check spotbugs:check
./gradlew spotlessCheck checkstyleMain spotbugsMain
```

## 보안 검증

```bash
./mvnw dependency:tree
./gradlew dependencies
```

OWASP Dependency-Check, Snyk, Trivy 등이 구성돼 있으면 CI와 같은 명령을 사용한다.

## 컨테이너 검증

Dockerfile이나 compose가 있으면 다음을 포함한다.

```bash
docker compose config
docker build .
```

## 완료 보고 형식

```text
검증:
- ./mvnw test: 통과
- docker compose config: 통과
- 보안 스캔: 미구성, 실행하지 않음
```

실패한 명령은 실패라고 말하고 핵심 로그를 요약한다.
