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
# Docker 보안

> [common/security.md](../common/security.md)를 컨테이너 보안에 맞게 확장한다.

## 이미지

- base image는 구체적 버전 태그 또는 digest로 고정한다.
- 불필요한 패키지와 build tool을 운영 이미지에 남기지 않는다.
- 이미지 빌드 중 secret을 `ARG`나 `ENV`로 굽지 않는다.
- `.dockerignore`에 `.git`, `.env`, coverage, build output, dependency cache를 포함한다.

## 런타임 권한

- 운영 컨테이너는 non-root 사용자로 실행한다.
- `privileged: true`는 금지한다. 필요한 capability만 추가한다.
- 가능하면 `read_only: true`, `cap_drop: [ALL]`, `no-new-privileges:true`를 사용한다.
- docker socket(`/var/run/docker.sock`) mount는 host root 권한과 유사하므로 금지에 가깝게 취급한다.

```yaml
services:
  app:
    user: "10001:10001"
    read_only: true
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
```

## 비밀값

- `.env`는 git에 커밋하지 않는다.
- 운영 secret은 orchestrator secret, vault, cloud secret manager에서 주입한다.
- 로그와 crash dump에 환경변수 전체를 출력하지 않는다.

## 네트워크 노출

- 운영 DB와 내부 queue는 host port를 열지 않는다.
- 관리 UI, debug port, profiler port는 로컬 전용 또는 VPN 내부로 제한한다.
- 컨테이너 간 통신에도 인증이 필요한 서비스는 인증을 생략하지 않는다.

## 검증 후보

```bash
docker build --no-cache .
docker scout cves .
trivy image <image>
hadolint Dockerfile
```

프로젝트에 설치된 도구를 우선 사용한다.
