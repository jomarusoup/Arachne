---
name: deployment-patterns
description: 배포 워크플로·CI/CD 파이프라인·Docker 컨테이너화·헬스 체크·롤백 전략·웹 애플리케이션 운영 준비 체크리스트.
origin: ECC
---

# 배포 패턴

운영 배포 워크플로 및 CI/CD 모범 사례.

## 언제 활성화하나

- CI/CD 파이프라인 설정
- 애플리케이션 Docker화
- 배포 전략 계획 (블루-그린, 카나리, 롤링)
- 헬스 체크 및 준비 프로브 구현
- 운영 릴리스 준비
- 환경별 설정 구성

## 배포 전략

### 롤링 배포 (기본값)

인스턴스를 점진적으로 교체 — 롤아웃 중 구버전과 신버전이 동시 실행.

```
인스턴스 1: v1 → v2  (첫 번째 업데이트)
인스턴스 2: v1        (아직 v1 실행 중)
인스턴스 3: v1        (아직 v1 실행 중)
...
```

**장점:** 제로 다운타임, 점진적 롤아웃
**단점:** 두 버전이 동시 실행 — 하위 호환 변경 필요
**사용 시:** 표준 배포, 하위 호환 변경

### 블루-그린 배포

동일한 두 환경 실행. 트래픽을 원자적으로 전환.

```
블루  (v1) ← 트래픽
그린  (v2)   유휴, 신버전 실행 중

# 검증 후:
블루  (v1)   유휴 (대기 상태)
그린  (v2) ← 트래픽
```

**장점:** 즉시 롤백 (블루로 전환), 깔끔한 컷오버
**단점:** 배포 중 2배 인프라 필요
**사용 시:** 중요 서비스, 이슈 허용 불가

### 카나리 배포

신버전에 트래픽의 일부를 먼저 라우팅.

```
v1: 95% 트래픽
v2:  5% 트래픽  (카나리)

# 메트릭이 좋으면:
v1: 50% → v2: 50%

# 최종:
v2: 100% 트래픽
```

**장점:** 전체 롤아웃 전 실제 트래픽으로 이슈 감지
**단점:** 트래픽 분할 인프라, 모니터링 필요
**사용 시:** 고트래픽 서비스, 위험 변경, 피처 플래그

## Docker

### 멀티스테이지 Dockerfile (Node.js)

```dockerfile
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production=false

FROM node:22-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build
RUN npm prune --production

FROM node:22-alpine AS runner
WORKDIR /app
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001
USER appuser
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
ENV NODE_ENV=production
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

### 멀티스테이지 Dockerfile (Go)

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server ./cmd/server

FROM alpine:3.19 AS runner
RUN apk --no-cache add ca-certificates
RUN adduser -D -u 1001 appuser
USER appuser
COPY --from=builder /server /server
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:8080/health || exit 1
CMD ["/server"]
```

## CI/CD 파이프라인

### GitHub Actions (표준 파이프라인)

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test -- --coverage

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: 운영 배포
        run: echo "Deploying ${{ github.sha }}"
```

### 파이프라인 단계

```
PR 오픈:
  린트 → 타입 체크 → 단위 테스트 → 통합 테스트 → 프리뷰 배포

main 병합:
  린트 → 타입 체크 → 테스트 → 이미지 빌드 → 스테이징 배포 → 스모크 테스트 → 운영 배포
```

## 헬스 체크

### 헬스 체크 엔드포인트

```typescript
/* 기본 헬스 체크 */
app.get("/health", (req, res) => {
    res.status(200).json({ status: "ok" })
})

/* 상세 헬스 체크 */
app.get("/health/detailed", async (req, res) => {
    const checks = {
        database: await checkDatabase(),
        redis: await checkRedis(),
    }
    const allHealthy = Object.values(checks).every(c => c.status === "ok")
    res.status(allHealthy ? 200 : 503).json({
        status: allHealthy ? "ok" : "degraded",
        timestamp: new Date().toISOString(),
        checks,
    })
})
```

### Kubernetes 프로브

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 30
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 10
```

## 환경 설정

```bash
# 모든 설정은 환경변수로 — 코드에 절대 하드코딩 금지
DATABASE_URL=postgres://user:pass@host:5432/db
REDIS_URL=redis://host:6379/0
NODE_ENV=production
PORT=3000
```

### 설정 검증

```typescript
import { z } from "zod"

const envSchema = z.object({
    NODE_ENV: z.enum(["development", "staging", "production"]),
    PORT: z.coerce.number().default(3000),
    DATABASE_URL: z.string().url(),
    JWT_SECRET: z.string().min(32),
})

/* 시작 시 검증 — 잘못된 설정 시 즉시 실패 */
export const env = envSchema.parse(process.env)
```

## 롤백 전략

```bash
# Kubernetes: 이전 이미지로 지정
kubectl rollout undo deployment/app

# Vercel: 이전 배포 승격
vercel rollback

# 데이터베이스: 마이그레이션 롤백
npx prisma migrate resolve --rolled-back <migration-name>
```

### 롤백 체크리스트

- [ ] 이전 이미지/아티팩트 사용 가능하고 태그됨
- [ ] DB 마이그레이션이 하위 호환 (파괴적 변경 없음)
- [ ] 피처 플래그로 새 기능 비활성화 가능
- [ ] 에러율 스파이크에 대한 모니터링 알림 설정

## 운영 준비 체크리스트

### 애플리케이션
- [ ] 모든 테스트 통과 (단위, 통합, E2E)
- [ ] 코드나 설정 파일에 하드코딩된 비밀값 없음
- [ ] 에러 처리가 모든 엣지 케이스 커버
- [ ] 로깅이 구조화 (JSON)되어 있고 PII 없음
- [ ] 헬스 체크 엔드포인트가 의미 있는 상태 반환

### 인프라
- [ ] Docker 이미지가 재현 가능하게 빌드 (버전 고정)
- [ ] 환경변수 문서화, 시작 시 검증
- [ ] 리소스 제한 설정 (CPU, 메모리)

### 모니터링
- [ ] 애플리케이션 메트릭 내보내기 (요청률, 지연, 에러)
- [ ] 에러율 임계값에 대한 알림 설정
- [ ] 헬스 엔드포인트 업타임 모니터링

### 보안
- [ ] CVE에 대한 의존성 스캔
- [ ] 허용된 출처만 CORS 설정
- [ ] 공개 엔드포인트에 레이트 리미팅
- [ ] 보안 헤더 설정 (CSP, HSTS, X-Frame-Options)

### 운영
- [ ] 롤백 계획 문서화 및 테스트
- [ ] 운영 규모 데이터 대상 DB 마이그레이션 테스트
- [ ] 일반적인 실패 시나리오에 대한 런북
