---
name: springboot-security
description: Spring Boot 보안 기준. Spring Security, 인증·인가, CSRF/CORS, validation, actuator, secret, 에러 응답을 다룬다.
triggers:
  paths: ["**/*.java"]
  keywords: ["Spring Security", "CORS", "CSRF", "actuator", "secret"]
---

# Spring Boot 보안

Spring Boot API와 웹 서비스를 보안 관점에서 설계·리뷰할 때 사용한다.

## 인증·인가

- Spring Security를 사용하고 자체 인증 필터를 최소화한다.
- endpoint authorization과 service-level authorization을 함께 검토한다.
- 관리자 API, 내부 API, 사용자 API의 권한 모델을 분리한다.
- JWT를 사용할 때 issuer, audience, expiration, signature algorithm을 검증한다.

## CORS와 CSRF

- CORS origin은 allowlist로 제한한다. `*`와 credential 조합은 금지한다.
- browser session cookie 기반 앱은 CSRF 보호를 유지한다.
- pure bearer-token API라도 browser에서 호출된다면 storage와 XSS 위험을 함께 검토한다.

## 입력 검증

- `@Valid`를 controller boundary에 적용한다.
- path variable, query parameter에도 범위와 형식을 검증한다.
- enum 변환 실패와 validation 실패의 응답 형식을 통일한다.

## Actuator

- 운영에서 `/actuator/env`, `/actuator/heapdump`, `/actuator/threaddump`를 공개하지 않는다.
- health endpoint도 상세 정보 노출 수준을 제한한다.
- management port와 network policy를 분리할 수 있으면 분리한다.

## 에러 응답

- stack trace와 exception class name을 클라이언트에 노출하지 않는다.
- `server.error.include-stacktrace=never`를 운영 기본값으로 둔다.
- 보안 실패는 상세 이유를 과도하게 말하지 않는다.

## 의존성

```bash
./mvnw dependency:tree
./gradlew dependencies
```

Spring Security, Jackson, Tomcat/Jetty/Netty, logback/log4j 계열 CVE를 우선 감시한다.

## 리뷰 체크리스트

- [ ] 인증 없는 endpoint가 의도된 것만 남아 있다.
- [ ] 권한 검사가 URL 패턴과 service boundary에 모두 고려됐다.
- [ ] CORS allowlist가 환경별로 명시돼 있다.
- [ ] actuator 민감 endpoint가 닫혀 있다.
- [ ] validation 실패가 400/422로 매핑된다.
- [ ] 로그에 token, cookie, PII가 없다.
