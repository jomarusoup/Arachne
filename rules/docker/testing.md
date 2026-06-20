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
# Docker 테스트

> 컨테이너 변경 후 최소 검증 기준을 정의한다.

## 빌드 검증

```bash
docker build .
docker compose config
```

- Dockerfile 변경은 이미지 빌드까지 확인한다.
- Compose 변경은 `docker compose config`로 병합 결과를 확인한다.
- multi-stage Dockerfile은 변경된 target과 production target을 모두 확인한다.

## 기동 검증

```bash
docker compose up -d
docker compose ps
docker compose logs --tail=100 app
docker compose down
```

- healthcheck가 healthy가 되는지 확인한다.
- app이 DB readiness 전에 죽지 않는지 확인한다.
- 종료 시 volume 삭제 여부를 명확히 구분한다. `down -v`는 데이터 삭제라 기본 검증에서 사용하지 않는다.

## 애플리케이션 검증

- 컨테이너 안에서 test command가 실행되는지 확인한다.
- host와 container의 경로 차이로 테스트가 깨지지 않아야 한다.
- timezone, locale, file permission 차이를 확인한다.

```bash
docker compose run --rm app npm test
docker compose run --rm app pytest
docker compose run --rm app ./gradlew test
```
