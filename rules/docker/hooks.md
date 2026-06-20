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
# Docker 훅

## 권장 검사

```bash
docker compose config
hadolint Dockerfile
```

## 선택 검사

```bash
docker build .
trivy fs .
trivy image <image>
```

## 실행 원칙

- Dockerfile만 바뀌면 최소 `docker build` 또는 프로젝트 CI의 컨테이너 빌드를 실행한다.
- Compose만 바뀌면 최소 `docker compose config`를 실행한다.
- 보안 민감 변경(`privileged`, socket mount, host network, secret)은 수동 리뷰를 요구한다.
