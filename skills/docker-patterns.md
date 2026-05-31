---
name: docker-patterns
description: 로컬 개발·컨테이너 보안·네트워킹·볼륨 전략·멀티서비스 오케스트레이션을 위한 Docker 및 Docker Compose 패턴.
origin: ECC
---

# Docker 패턴

컨테이너화된 개발을 위한 Docker 및 Docker Compose 모범 사례.

## 언제 활성화하나

- 로컬 개발을 위한 Docker Compose 설정
- 멀티 컨테이너 아키텍처 설계
- 컨테이너 네트워킹 또는 볼륨 이슈 해결
- Dockerfile 보안 및 이미지 크기 검토
- 로컬 개발에서 컨테이너화 워크플로로 마이그레이션

## 로컬 개발용 Docker Compose

### 표준 웹앱 스택

```yaml
# docker-compose.yml
services:
  app:
    build:
      context: .
      target: dev                     # 멀티스테이지 Dockerfile의 dev 스테이지
    ports:
      - "3000:3000"
    volumes:
      - .:/app                        # 핫 리로드를 위한 바인드 마운트
      - /app/node_modules             # 컨테이너 의존성 보호
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/app_dev
      - NODE_ENV=development
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app_dev
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 3s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redisdata:/data

volumes:
  pgdata:
  redisdata:
```

### 개발 vs 운영 Dockerfile

```dockerfile
# 의존성 단계
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# 개발 단계 (핫 리로드, 디버그 도구)
FROM node:22-alpine AS dev
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
CMD ["npm", "run", "dev"]

# 빌드 단계
FROM node:22-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build && npm prune --production

# 운영 단계 (최소 이미지)
FROM node:22-alpine AS production
WORKDIR /app
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001
USER appuser
COPY --from=build --chown=appuser:appgroup /app/dist ./dist
COPY --from=build --chown=appuser:appgroup /app/node_modules ./node_modules
ENV NODE_ENV=production
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

### 오버라이드 파일

```yaml
# docker-compose.override.yml (자동 로드, 개발 전용)
services:
  app:
    environment:
      - LOG_LEVEL=debug
    ports:
      - "9229:9229"                   # Node.js 디버거

# docker-compose.prod.yml (운영 명시적 파일)
services:
  app:
    build:
      target: production
    restart: always
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
```

```bash
# 개발 (오버라이드 자동 로드)
docker compose up

# 운영
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## 네트워킹

### 서비스 디스커버리

같은 Compose 네트워크의 서비스는 서비스 이름으로 해석:

```
# "app" 컨테이너에서:
postgres://postgres:postgres@db:5432/app_dev    # "db"가 db 컨테이너로 해석
redis://redis:6379/0                             # "redis"가 redis 컨테이너로 해석
```

### 커스텀 네트워크

```yaml
services:
  frontend:
    networks: [frontend-net]

  api:
    networks: [frontend-net, backend-net]

  db:
    networks: [backend-net]    # api에서만 접근 가능, frontend 불가

networks:
  frontend-net:
  backend-net:
```

### 필요한 것만 노출

```yaml
services:
  db:
    ports:
      - "127.0.0.1:5432:5432"   # 호스트에서만 접근 가능
    # 운영에서는 ports 완전 생략 — Docker 네트워크 내에서만 접근
```

## 볼륨 전략

```yaml
volumes:
  pgdata:         # Named volume: 컨테이너 재시작 후에도 유지, Docker가 관리

services:
  app:
    volumes:
      - .:/app                   # 소스 코드 (바인드 마운트, 핫 리로드)
      - /app/node_modules        # 컨테이너의 node_modules 보호
      - /app/.next               # 빌드 캐시 보호
```

## 컨테이너 보안

### Dockerfile 강화

```dockerfile
# 1. 특정 태그 사용 (:latest 절대 금지)
FROM node:22.12-alpine3.20

# 2. 비-루트로 실행
RUN addgroup -g 1001 -S app && adduser -S app -u 1001
USER app
```

### Compose 보안

```yaml
services:
  app:
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
```

### 비밀값 관리

```yaml
# 올바름: 환경변수 사용 (런타임에 주입)
services:
  app:
    env_file:
      - .env               # .env는 절대 git에 커밋하지 않는다
    environment:
      - API_KEY            # 호스트 환경에서 상속

# 잘못됨: 이미지에 하드코딩
# ENV API_KEY=sk-proj-xxxxx      # 절대 하지 않는다
```

## .dockerignore

```
node_modules
.git
.env
.env.*
dist
coverage
*.log
.next
docker-compose*.yml
Dockerfile*
tests/
```

## 디버깅

```bash
# 로그 확인
docker compose logs -f app           # app 로그 팔로우
docker compose logs --tail=50 db     # db 최근 50줄

# 실행 중인 컨테이너에서 명령 실행
docker compose exec app sh           # 셸 접속
docker compose exec db psql -U postgres  # postgres 접속

# 검사
docker compose ps                     # 실행 중인 서비스
docker stats                          # 리소스 사용량

# 재빌드
docker compose up --build             # 이미지 재빌드
docker compose build --no-cache app   # 강제 전체 재빌드

# 정리
docker compose down                   # 컨테이너 중지 및 제거
docker compose down -v                # 볼륨도 제거 (파괴적!)
```

### 네트워크 이슈 디버깅

```bash
# 컨테이너 내부에서 DNS 확인
docker compose exec app nslookup db

# 연결 확인
docker compose exec app wget -qO- http://api:3000/health
```

## 안티패턴

```
# 나쁨: 오케스트레이션 없이 운영에서 Docker Compose 사용
# 운영 멀티컨테이너 워크로드에는 Kubernetes, ECS, Docker Swarm 사용

# 나쁨: 볼륨 없이 컨테이너에 데이터 저장
# 컨테이너는 임시적 — 재시작 시 볼륨 없으면 모든 데이터 손실

# 나쁨: 루트로 실행
# 항상 비-루트 사용자 생성 및 사용

# 나쁨: :latest 태그 사용
# 재현 가능한 빌드를 위해 특정 버전에 고정

# 나쁨: 하나의 거대한 컨테이너에 모든 서비스
# 컨테이너당 하나의 프로세스

# 나쁨: docker-compose.yml에 비밀값 넣기
# .env 파일 사용 (gitignore)
```
