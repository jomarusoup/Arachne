---
paths:
  - "**/*.java"
---
# Java 보안

> [common/security.md](../common/security.md)를 Java와 JVM 백엔드에 맞게 확장한다.

## 비밀값

- API 키, 토큰, 비밀번호를 코드와 테스트 fixture에 하드코딩하지 않는다.
- 로컬은 환경변수 또는 gitignore된 설정 파일을 사용한다.
- 운영은 Vault, AWS Secrets Manager, GCP Secret Manager 같은 secret manager를 사용한다.
- 로그에 토큰, 세션 ID, PII, 인증 헤더를 남기지 않는다.

```java
String apiKey = System.getenv("PAYMENT_API_KEY");
Objects.requireNonNull(apiKey, "PAYMENT_API_KEY must be set");
```

## SQL Injection 방지

- 사용자 입력을 SQL 문자열에 직접 연결하지 않는다.
- JDBC는 `PreparedStatement`, Spring은 parameterized query, JPA는 bind parameter를 사용한다.
- native query는 입력 검증과 허용 목록을 추가한다. 특히 정렬 컬럼명은 파라미터 바인딩이 되지 않으므로 enum/allowlist로 제한한다.

```java
PreparedStatement statement = connection.prepareStatement(
    "SELECT * FROM orders WHERE customer_name = ?"
);
statement.setString(1, customerName);
```

## 입력 검증

- 시스템 경계에서 DTO를 검증한다.
- Spring Boot에서는 `@Valid`, Bean Validation(`@NotNull`, `@NotBlank`, `@Size`)을 사용한다.
- 파일 경로, URL, 정렬 키, enum 문자열, 금액, 날짜 범위를 명시적으로 검증한다.
- 검증 실패는 400 또는 422로 매핑하고 500으로 숨기지 않는다.

## 인증·인가

- 자체 암호화나 세션 알고리즘을 만들지 않는다.
- 비밀번호는 bcrypt 또는 Argon2로 저장한다. MD5, SHA1, 단순 SHA256 해시는 금지한다.
- 권한 검사는 controller만이 아니라 service boundary에서도 수행한다.
- 리소스 소유권 검사를 누락하지 않는다. "존재하지만 권한 없음" 응답 정책은 제품 보안 정책에 맞게 403 또는 404 중 하나로 통일한다.

## 역직렬화와 표현식

- 신뢰할 수 없는 입력에 Java native serialization을 사용하지 않는다.
- Jackson polymorphic deserialization은 필요한 경우에만 제한된 subtype allowlist와 함께 사용한다.
- SpEL, OGNL, 템플릿 표현식에 사용자 입력을 직접 넣지 않는다.

## 의존성 보안

- Maven/Gradle dependency tree를 주기적으로 확인한다.
- OWASP Dependency-Check, Snyk, Dependabot, Renovate 중 하나 이상으로 CVE를 추적한다.
- 운영 빌드에는 snapshot 의존성을 사용하지 않는다.

```bash
mvn dependency:tree
./gradlew dependencies
```

## 에러 응답

- stack trace, 내부 경로, SQL 오류, 클래스 이름을 API 응답에 노출하지 않는다.
- 상세 원인은 서버 로그에 남기고, 클라이언트에는 안정적인 에러 코드와 안전한 메시지만 반환한다.

## 관련 스킬

- [springboot-security](../../skills/archive/springboot-security.md)
- [security-review](../../skills/security-review.md)
