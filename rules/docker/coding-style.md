---
paths:
  - "Dockerfile"
  - "**/Dockerfile"
  - "**/*.Dockerfile"
  - "docker-compose*.yml"
  - "docker-compose*.yaml"
  - "compose*.yml"
  - "compose*.yaml"
---
# Docker 작성 스타일

## Dockerfile

- stage 이름을 의미 있게 붙인다: `deps`, `dev`, `build`, `production`.
- 캐시 효율을 위해 dependency manifest를 먼저 복사하고 의존성을 설치한 뒤 소스를 복사한다.
- 여러 패키지 설치는 한 `RUN`에서 수행하고 package manager cache를 정리한다.
- `WORKDIR`를 항상 명시한다.
- 운영 stage에는 debug shell과 build dependency를 남기지 않는다.

```dockerfile
FROM eclipse-temurin:21-jre AS production
WORKDIR /app
COPY --from=build /app/build/libs/app.jar ./app.jar
USER 10001:10001
ENTRYPOINT ["java", "-jar", "app.jar"]
```

## Compose

- 서비스 이름은 짧고 역할 중심으로 쓴다: `app`, `api`, `db`, `redis`, `worker`.
- 환경변수는 공통값과 secret을 분리한다.
- 개발 override와 운영 override를 파일로 분리한다.
- YAML anchor는 과도하게 쓰지 않는다. 중복이 커질 때만 사용한다.

## 주석

Dockerfile과 Compose 주석은 "왜 필요한지"를 설명할 때만 둔다. 명령 자체를 반복 설명하지 않는다.
