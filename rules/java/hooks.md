---
paths:
  - "**/*.java"
  - "pom.xml"
  - "build.gradle"
  - "build.gradle.kts"
---
# Java 훅

> Java 프로젝트에서 세션 종료 또는 커밋 전 실행할 검증 후보를 정의한다.

## 권장 로컬 검증

Maven:

```bash
./mvnw -q test
./mvnw -q verify
```

Gradle:

```bash
./gradlew test
./gradlew check
```

## 정적 분석 후보

```bash
./mvnw spotless:check
./mvnw checkstyle:check
./mvnw pmd:check
./mvnw spotbugs:check
./gradlew spotlessCheck
./gradlew checkstyleMain checkstyleTest
./gradlew pmdMain pmdTest
./gradlew spotbugsMain spotbugsTest
```

프로젝트에 설정된 도구만 실행한다. 도구가 없으면 새로 추가하기 전에 사용자와 합의한다.

## 보안 후보

```bash
./mvnw org.owasp:dependency-check-maven:check
./gradlew dependencyCheckAnalyze
```

## 실행 원칙

- 변경 범위가 작아도 최소 단위 테스트는 실행한다.
- DB mapping, migration, repository 변경은 통합 테스트를 포함한다.
- 인증·인가·결제·개인정보 경계 변경은 보안 리뷰를 함께 수행한다.
