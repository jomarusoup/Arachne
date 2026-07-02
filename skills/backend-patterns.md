---
name: backend-patterns
description: 확장 가능한 서버 아키텍처 패턴 — API 설계, 레이어 분리(레포지토리·서비스), DB 최적화(N+1·인덱싱·풀링), 캐싱, 백그라운드 작업, 구조적 로깅. Python/FastAPI 기준이며 각 패턴의 시스템(C/Rust) 전환 이식 맵을 함께 제공.
triggers:
  paths: []
  keywords: ["백엔드", "서비스 레이어", "레포지토리 패턴", "캐싱", "큐", "N+1"]
---

# 백엔드 개발 패턴

확장 가능한 서버 애플리케이션의 아키텍처 패턴. 예시는 Python/FastAPI 기준이지만,
핵심은 **언어 무관 아키텍처 원칙**이다 — 서버를 시스템 프로그래밍으로 전환할 때 그대로 이식된다.

## 언제 활성화하나

- REST/GraphQL 엔드포인트 설계
- 레포지토리·서비스·컨트롤러 레이어 구현
- DB 쿼리 최적화 (N+1, 인덱싱, 커넥션 풀링)
- 캐싱 추가 (Redis, 인메모리, HTTP 캐시 헤더)
- 백그라운드 작업·비동기 처리
- API 에러 처리·검증 구조화
- 미들웨어(인증·로깅·레이트 리미팅) 구축

## 시스템 전환 이식 맵

| 백엔드 패턴 | 시스템(C/Rust) 대응 | 공통 원칙 |
| ----------- | ------------------- | --------- |
| 레포지토리/서비스 레이어 분리 | I/O 레이어 ↔ 도메인 로직 분리 | 데이터 접근과 비즈니스 로직 결합 금지 |
| 커넥션 풀링 | fd/소켓 풀, 사전 할당 버퍼 | 자원 생성 비용을 재사용으로 상환 |
| N+1 방지(배치 조회) | syscall 배치(`readv`/`writev`), epoll 일괄 처리 | 왕복(round-trip) 횟수 최소화 |
| 인메모리 큐 | ring buffer, lock-free 큐 | 생산자-소비자 분리 |
| 캐시-어사이드 | mmap 캐시, LRU 페이지 캐시 | 핫 데이터 지역성 |
| 구조적 로깅(JSON) | 구조적 로깅(동일) | 머신 파싱 가능한 이벤트 |
| 지수 백오프 재시도 | 동일 (소켓 재연결) | 폭주 방지 |

## API 설계 패턴

### RESTful 구조

```
GET    /api/markets         # 목록
GET    /api/markets/{id}    # 단건 조회
POST   /api/markets         # 생성
PUT    /api/markets/{id}    # 교체
PATCH  /api/markets/{id}    # 부분 수정
DELETE /api/markets/{id}    # 삭제

# 필터·정렬·페이지네이션은 쿼리 파라미터로
GET /api/markets?status=active&sort=volume&limit=20&offset=0
```

### 레포지토리 패턴 — 데이터 접근 추상화

```python
from typing import Protocol, Optional

class MarketRepository(Protocol):
    async def find_all(self, filters: MarketFilters | None = None) -> list[Market]: ...
    async def find_by_id(self, market_id: str) -> Optional[Market]: ...
    async def create(self, data: CreateMarketDto) -> Market: ...

class PgMarketRepository:
    def __init__(self, session: AsyncSession):
        self._session = session

    async def find_all(self, filters: MarketFilters | None = None) -> list[Market]:
        query = select(Market)
        if filters and filters.status:
            query = query.where(Market.status == filters.status)
        if filters and filters.limit:
            query = query.limit(filters.limit)
        result = await self._session.execute(query)
        return list(result.scalars().all())
```

### 서비스 레이어 — 비즈니스 로직 분리

```python
class MarketService:
    def __init__(self, repo: MarketRepository):
        self._repo = repo   # 데이터 접근은 주입받음 (의존성 역전)

    async def search_markets(self, query: str, limit: int = 10) -> list[Market]:
        # 비즈니스 로직만 — 어떻게 저장되는지는 모름
        embedding = await generate_embedding(query)
        hits = await self._vector_search(embedding, limit)
        markets = await self._repo.find_by_ids([h.id for h in hits])
        score = {h.id: h.score for h in hits}
        return sorted(markets, key=lambda m: score.get(m.id, 0.0))
```

### 미들웨어 패턴 — 요청/응답 파이프라인

```python
from fastapi import Request, HTTPException

async def auth_dependency(request: Request) -> User:
    """인증 미들웨어 — 의존성으로 주입."""
    token = request.headers.get("authorization", "").removeprefix("Bearer ")
    if not token:
        raise HTTPException(status_code=401, detail="Unauthorized")
    try:
        return await verify_token(token)
    except TokenError as err:
        raise HTTPException(status_code=401, detail="Invalid token") from err
```

## 데이터베이스 패턴

### 쿼리 최적화 — 필요한 컬럼만

```python
# 올바름: 필요한 컬럼만 선택
query = (
    select(Market.id, Market.name, Market.status, Market.volume)
    .where(Market.status == "active")
    .order_by(Market.volume.desc())
    .limit(10)
)

# 잘못됨: 전체 컬럼 — 불필요한 I/O
query = select(Market)
```

### N+1 쿼리 방지 — 배치 조회

가장 흔한 백엔드 성능 결함. 시스템 코드의 syscall 왕복 최소화와 같은 원리다.

```python
# 잘못됨: N+1 — 마켓마다 작성자 개별 조회
markets = await get_markets()
for market in markets:
    market.creator = await get_user(market.creator_id)   # N번 쿼리

# 올바름: 배치 조회 — 1번 쿼리 + 맵 조인
markets = await get_markets()
creator_ids = [m.creator_id for m in markets]
creators = await get_users(creator_ids)                  # 1번 쿼리
creator_map = {c.id: c for c in creators}
for market in markets:
    market.creator = creator_map.get(market.creator_id)
```

### 트랜잭션 — 다단계 연산의 원자성

```python
async def create_market_with_position(
    session: AsyncSession,
    market_data: CreateMarketDto,
    position_data: CreatePositionDto,
) -> Market:
    async with session.begin():   # 예외 시 자동 롤백
        market = Market(**market_data.model_dump())
        session.add(market)
        await session.flush()       # market.id 확보
        position = Position(market_id=market.id, **position_data.model_dump())
        session.add(position)
    return market
```

## 캐싱 전략

### 캐시-어사이드 패턴

```python
import json

async def get_market_with_cache(market_id: str) -> Market:
    cache_key = f"market:{market_id}"

    cached = await redis.get(cache_key)
    if cached:
        return Market(**json.loads(cached))   # 캐시 히트

    market = await repo.find_by_id(market_id)  # 캐시 미스 → DB
    if not market:
        raise NotFoundError(f"마켓 없음: {market_id}")

    await redis.setex(cache_key, 300, market.model_dump_json())  # 5분 TTL
    return market

async def invalidate(market_id: str) -> None:
    await redis.delete(f"market:{market_id}")   # 쓰기 시 무효화
```

> 캐시 무효화는 가장 어려운 문제다. 쓰기 경로에서 반드시 무효화하고, TTL은 데이터 신선도 요구에 맞춘다.

## 에러 처리 패턴

### 중앙 집중식 에러 핸들러

```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

class ApiError(Exception):
    def __init__(self, status_code: int, message: str):
        self.status_code = status_code
        self.message = message

def register_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def handle_api_error(request: Request, exc: ApiError):
        return JSONResponse(
            status_code=exc.status_code,
            content={"success": False, "error": exc.message},
        )

    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, exc: Exception):
        logger.error("unexpected error", error=str(exc), path=request.url.path)
        # 내부 에러 상세를 클라이언트에 노출하지 않음
        return JSONResponse(
            status_code=500,
            content={"success": False, "error": "Internal server error"},
        )
```

### 지수 백오프 재시도

```python
import asyncio
from typing import Awaitable, Callable, TypeVar

T = TypeVar("T")

async def fetch_with_retry(fn: Callable[[], Awaitable[T]], max_retries: int = 3) -> T:
    last_error: Exception | None = None
    for ii in range(max_retries):
        try:
            return await fn()
        except Exception as err:       # noqa: BLE001 — 재시도 경계
            last_error = err
            if ii < max_retries - 1:
                await asyncio.sleep(2 ** ii)   # 1s, 2s, 4s
    raise last_error   # type: ignore[misc]
```

## 인증·인가

### JWT 검증

```python
import jwt

async def require_auth(request: Request) -> JWTPayload:
    token = request.headers.get("authorization", "").removeprefix("Bearer ")
    if not token:
        raise ApiError(401, "Missing authorization token")
    try:
        # 알고리즘·만료·발급자·대상 모두 검증
        return jwt.decode(
            token, JWT_SECRET, algorithms=["HS256"],
            issuer=EXPECTED_ISSUER, audience=EXPECTED_AUDIENCE,
        )
    except jwt.PyJWTError as err:
        raise ApiError(401, "Invalid token") from err
```

### 역할 기반 접근 제어(RBAC)

```python
from enum import Enum

class Permission(str, Enum):
    READ = "read"
    WRITE = "write"
    DELETE = "delete"
    ADMIN = "admin"

ROLE_PERMISSIONS: dict[str, set[Permission]] = {
    "admin":     {Permission.READ, Permission.WRITE, Permission.DELETE, Permission.ADMIN},
    "moderator": {Permission.READ, Permission.WRITE, Permission.DELETE},
    "user":      {Permission.READ, Permission.WRITE},
}

def has_permission(user: User, permission: Permission) -> bool:
    return permission in ROLE_PERMISSIONS.get(user.role, set())
```

## 레이트 리미팅

레이트 리미팅은 **반드시 공유 저장소**(Redis·게이트웨이·플랫폼 네이티브 리미터)를 사용한다.
프로세스별 인메모리 카운터는 운영 API에 사용 금지 — 배포 시 리셋되고, 레플리카 간 분산되며,
서버리스/다중 인스턴스에서 fail-open 된다.

> HTTP 계약은 `api-design`(미포팅 시 직접 정의), 남용 케이스 검토는 `security-review` 참고.

## 백그라운드 작업·큐

```python
import asyncio
from dataclasses import dataclass

@dataclass
class IndexJob:
    market_id: str

class JobQueue:
    """간단한 인메모리 큐. 운영은 Redis/Celery 등 영속 큐 사용."""
    def __init__(self):
        self._queue: asyncio.Queue[IndexJob] = asyncio.Queue()

    async def add(self, job: IndexJob) -> None:
        await self._queue.put(job)

    async def worker(self) -> None:
        while True:
            job = await self._queue.get()
            try:
                await self._execute(job)
            except Exception as err:        # noqa: BLE001
                logger.error("job failed", market_id=job.market_id, error=str(err))
            finally:
                self._queue.task_done()
```

> 인메모리 큐는 프로세스 종료 시 유실된다. 내구성이 필요하면 영속 큐를 쓴다.
> 이 생산자-소비자 구조는 시스템 코드의 ring buffer + worker 스레드 패턴과 동일하다.

## 로깅·모니터링 — 구조적 로깅

```python
import json
import logging
from datetime import datetime, timezone

class StructuredLogger:
    """JSON 한 줄 = 이벤트 하나. 머신 파싱 가능."""
    def __init__(self, name: str):
        self._logger = logging.getLogger(name)

    def _log(self, level: str, message: str, **context) -> None:
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": level,
            "message": message,
            **context,
        }
        self._logger.info(json.dumps(entry))

    def info(self, message: str, **context) -> None:
        self._log("info", message, **context)

    def error(self, message: str, **context) -> None:
        self._log("error", message, **context)

logger = StructuredLogger("app")

# 사용 — request_id로 추적 가능
logger.info("fetching markets", request_id=req_id, method="GET", path="/api/markets")
```

> **기억할 것**: 백엔드 패턴은 확장 가능하고 유지보수 가능한 서버를 만든다. 복잡도에 맞는 패턴을 고른다.
> 레이어 분리·자원 풀링·왕복 최소화·구조적 로깅은 시스템 서버로 전환해도 그대로 가져간다.
