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
# Docker 패턴

> [common/patterns.md](../common/patterns.md)를 Docker와 Docker Compose에 맞게 확장한다.

## 기본 원칙

- 개발 이미지와 운영 이미지를 분리한다.
- 운영 이미지는 multi-stage build로 작게 만든다.
- 컨테이너는 하나의 주 프로세스만 책임진다.
- `latest` 태그를 사용하지 않는다.
- host network, privileged, docker socket mount는 명시적 승인 없이는 사용하지 않는다.

## Compose 설계

- 서비스 이름을 DNS 이름으로 사용한다.
- DB, Redis, queue는 healthcheck를 둔다.
- `depends_on`은 시작 순서일 뿐 readiness 보장이 아님을 기억한다. health condition 또는 앱 retry가 필요하다.
- 운영 compose와 개발 override를 분리한다.

```yaml
services:
  app:
    build:
      context: .
      target: dev
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5
```

## 네트워크

- 필요한 포트만 host에 공개한다.
- DB는 가능하면 compose network 내부에만 둔다.
- 로컬 개발에서 host 노출이 필요하면 `127.0.0.1:5432:5432`처럼 loopback에 바인딩한다.

## 볼륨

- 데이터는 named volume에 둔다.
- 소스 핫 리로드는 bind mount를 사용하되, `node_modules`, build cache 등 컨테이너 내부 의존성은 anonymous volume으로 보호한다.
- 운영에서 host path mount는 백업, 권한, 이식성 문제를 검토한다.

## 관련 스킬

- [docker-patterns](../../skills/docker-patterns.md)
- [deployment-patterns](../../skills/deployment-patterns.md)
