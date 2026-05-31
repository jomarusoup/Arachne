---
name: backend-patterns
description: 확장 가능한 서버사이드 애플리케이션을 위한 백엔드 아키텍처 패턴·API 설계·DB 최적화·Node.js/Express/Next.js 모범 사례.
origin: ECC
---

# 백엔드 개발 패턴

확장 가능한 서버사이드 애플리케이션을 위한 백엔드 아키텍처 패턴과 모범 사례.

## 언제 활성화하나

- REST 또는 GraphQL API 엔드포인트 설계
- 레포지토리·서비스·컨트롤러 레이어 구현
- DB 쿼리 최적화 (N+1, 인덱싱, 연결 풀링)
- 캐싱 추가 (Redis, 인메모리, HTTP 캐시 헤더)
- 백그라운드 작업 또는 비동기 처리 설정
- API의 에러 처리 및 검증 구조화
- 미들웨어 구축 (인증, 로깅, 레이트 리미팅)

## API 설계 패턴

### RESTful API 구조

```typescript
/* 올바름: 리소스 기반 URL */
GET    /api/markets                 /* 리소스 목록 */
GET    /api/markets/:id             /* 단일 리소스 */
POST   /api/markets                 /* 리소스 생성 */
PUT    /api/markets/:id             /* 리소스 교체 */
PATCH  /api/markets/:id             /* 리소스 업데이트 */
DELETE /api/markets/:id             /* 리소스 삭제 */
```

### 레포지토리 패턴

```typescript
/* 데이터 접근 로직 추상화 */
interface MarketRepository {
    findAll(filters?: MarketFilters): Promise<Market[]>
    findById(id: string): Promise<Market | null>
    create(data: CreateMarketDto): Promise<Market>
    update(id: string, data: UpdateMarketDto): Promise<Market>
    delete(id: string): Promise<void>
}

class SupabaseMarketRepository implements MarketRepository {
    async findAll(filters?: MarketFilters): Promise<Market[]> {
        let query = supabase.from('markets').select('*')
        if (filters?.status) query = query.eq('status', filters.status)
        if (filters?.limit) query = query.limit(filters.limit)
        const { data, error } = await query
        if (error) throw new Error(error.message)
        return data
    }
}
```

### 서비스 레이어 패턴

```typescript
/* 데이터 접근과 분리된 비즈니스 로직 */
class MarketService {
    constructor(private marketRepo: MarketRepository) {}

    async searchMarkets(query: string, limit: number = 10): Promise<Market[]> {
        const embedding = await generateEmbedding(query)
        const results = await this.vectorSearch(embedding, limit)
        const markets = await this.marketRepo.findByIds(results.map(r => r.id))
        return markets.sort((a, b) => {
            const scoreA = results.find(r => r.id === a.id)?.score || 0
            const scoreB = results.find(r => r.id === b.id)?.score || 0
            return scoreA - scoreB
        })
    }
}
```

## 데이터베이스 패턴

### N+1 쿼리 방지

```typescript
/* 잘못됨: N+1 쿼리 */
const markets = await db.markets.findAll()
for (const market of markets) {
    market.creator = await db.users.findOne(market.creatorId) /* N개의 추가 쿼리 */
}

/* 올바름: 조인 또는 배치 */
const markets = await db.markets.findAll({
    include: [{ model: db.users, as: 'creator' }]
})
```

### 트랜잭션

```typescript
async function transferFunds(fromId: string, toId: string, amount: number) {
    return await db.transaction(async (trx) => {
        await trx.query('UPDATE accounts SET balance = balance - $1 WHERE id = $2', [amount, fromId])
        await trx.query('UPDATE accounts SET balance = balance + $1 WHERE id = $2', [amount, toId])
        return { success: true }
    })
}
```

## 캐싱 전략

### Redis 캐싱

```typescript
async function getCachedMarket(id: string): Promise<Market> {
    const cacheKey = `market:${id}`
    const cached = await redis.get(cacheKey)
    if (cached) return JSON.parse(cached)

    const market = await db.markets.findById(id)
    await redis.setex(cacheKey, 300, JSON.stringify(market)) /* 5분 TTL */
    return market
}
```

### 캐시 무효화

```typescript
async function updateMarket(id: string, data: UpdateMarketDto) {
    const updated = await db.markets.update(id, data)
    await redis.del(`market:${id}`)          /* 특정 캐시 무효화 */
    await redis.del(`markets:list:*`)         /* 패턴 기반 무효화 */
    return updated
}
```

## 미들웨어 패턴

### 인증 미들웨어

```typescript
export function requireAuth() {
    return async (request: Request, next: NextFunction) => {
        const token = request.headers.get('Authorization')?.replace('Bearer ', '')
        if (!token) throw new ApiError(401, '인증이 필요합니다')

        const user = await verifyToken(token)
        if (!user) throw new ApiError(401, '유효하지 않은 토큰')

        return next(request, user)
    }
}
```

### 권한 미들웨어

```typescript
export function requirePermission(permission: string) {
    return (handler: AuthenticatedHandler) => {
        return async (request: Request) => {
            const user = await authenticate(request)
            if (!hasPermission(user, permission)) {
                throw new ApiError(403, '권한이 부족합니다')
            }
            return handler(request, user)
        }
    }
}

export const DELETE = requirePermission('delete')(
    async (request: Request, user: User) => {
        return new Response('삭제됨', { status: 200 })
    }
)
```

## 레이트 리미팅

레이트 리미팅은 반드시 Redis, 게이트웨이, 또는 플랫폼의 네이티브 리미터 같은 공유 저장소를 사용해야 한다.
운영 API에서 프로세스별 인메모리 카운터 사용 금지 — 배포 시 리셋되고, 레플리카 간 분리되며, 서버리스 환경에서 실패한다.

## 백그라운드 작업 & 큐

```typescript
class JobQueue<T> {
    private queue: T[] = []
    private processing = false

    async add(job: T): Promise<void> {
        this.queue.push(job)
        if (!this.processing) this.process()
    }

    private async process(): Promise<void> {
        this.processing = true
        while (this.queue.length > 0) {
            const job = this.queue.shift()!
            try {
                await this.execute(job)
            } catch (error) {
                console.error('작업 실패:', error)
            }
        }
        this.processing = false
    }
}

/* 사용 예시 */
const indexQueue = new JobQueue<{ marketId: string }>()

export async function POST(request: Request) {
    const { marketId } = await request.json()
    await indexQueue.add({ marketId })        /* 블로킹 대신 큐에 추가 */
    return NextResponse.json({ success: true, message: '작업 대기 중' })
}
```

## 로깅 & 모니터링

### 구조화된 로깅

```typescript
class Logger {
    log(level: 'info' | 'warn' | 'error', message: string, context?: object) {
        console.log(JSON.stringify({
            timestamp: new Date().toISOString(),
            level,
            message,
            ...context
        }))
    }
}

const logger = new Logger()

export async function GET(request: Request) {
    const requestId = crypto.randomUUID()
    logger.log('info', '시장 목록 조회', { requestId, path: '/api/markets' })

    try {
        const markets = await fetchMarkets()
        return NextResponse.json({ success: true, data: markets })
    } catch (error) {
        logger.log('error', '시장 조회 실패', { requestId, error: (error as Error).message })
        return NextResponse.json({ error: '내부 오류' }, { status: 500 })
    }
}
```

---

**기억**: 백엔드 패턴은 확장 가능하고 유지 보수가 쉬운 서버사이드 애플리케이션을 가능하게 한다. 현재 복잡도 수준에 맞는 패턴을 선택한다.
