---
name: fastapi-patterns
description: FastAPI 프로덕션 패턴 — 앱 팩토리(create_app·lifespan), 라우터/스키마/의존성/DB 레이어 분리, 요청 단위 DB 세션(Depends(get_db)), Pydantic 입력/출력 스키마 분리, async 엔드포인트, 중앙 에러 핸들러, dependency_overrides 테스트, 보안·성능 체크리스트.
---

# FastAPI 프로덕션 패턴

FastAPI 서비스를 위한 프로덕션 지향 패턴.
(Arachne 스타일로 작성)

## 언제 활성화하나

- FastAPI 앱 구축·리뷰
- 라우터·스키마·의존성·DB 접근 분리
- DB·외부 서비스를 호출하는 async 엔드포인트 작성
- 인증·인가·OpenAPI 문서·테스트·배포 설정 추가
- FastAPI PR에서 복붙 가능한 예시·프로덕션 리스크 점검

## 핵심 사고

FastAPI 앱을 **명시적 의존성과 서비스 코드 위의 얇은 HTTP 레이어**로 취급한다.

- `main.py` — 앱 생성·미들웨어·예외 핸들러·라우터 등록
- `schemas/` — Pydantic 요청·응답 모델
- `dependencies.py` — DB·인증·페이지네이션 등 요청 단위 의존성
- `services/`·`crud/` — 비즈니스·영속성 로직
- `tests/` — 프로덕션 자원 대신 의존성을 오버라이드

작은 라우터와 명시적 `response_model`을 선호한다. **raw ORM 객체·비밀·프레임워크 전역을 응답 스키마에서 배제.**

## 프로젝트 레이아웃

```
app/
├── main.py          # create_app, 미들웨어, 핸들러, 라우터
├── config.py
├── dependencies.py  # get_db, get_current_user, 페이지네이션
├── exceptions.py
├── api/routes/      # users.py, health.py
├── core/            # security.py, middleware.py
├── db/              # session.py, crud.py
├── models/          # ORM
├── schemas/         # Pydantic
└── tests/
```

## 앱 팩토리 — 테스트·워커가 통제된 설정으로 빌드

```python
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import health, users
from app.config import settings
from app.db.session import close_db, init_db
from app.exceptions import register_exception_handlers


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield
    await close_db()


def create_app() -> FastAPI:
    app = FastAPI(title=settings.api_title, version=settings.api_version, lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=bool(settings.cors_origins),
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
        allow_headers=["Authorization", "Content-Type"],
    )
    register_exception_handlers(app)
    app.include_router(health.router, prefix="/health", tags=["health"])
    app.include_router(users.router, prefix="/api/v1/users", tags=["users"])
    return app


app = create_app()
```

> `allow_origins=["*"]` + `allow_credentials=True` 조합 금지 — 브라우저가 거부하고 Starlette도 자격증명 요청엔 불허.

## Pydantic 스키마 — 요청·수정·응답 분리

```python
from datetime import datetime
from typing import Annotated
from uuid import UUID
from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserBase(BaseModel):
    email: EmailStr
    full_name: Annotated[str, Field(min_length=1, max_length=100)]


class UserCreate(UserBase):
    password: Annotated[str, Field(min_length=12, max_length=128)]


class UserUpdate(BaseModel):
    email: EmailStr | None = None
    full_name: Annotated[str | None, Field(min_length=1, max_length=100)] = None


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)
    id: UUID
    created_at: datetime
```

> 응답 모델엔 비밀번호 해시·액세스/리프레시 토큰·내부 인가 상태를 **절대 포함하지 않는다.**

## 의존성 — 요청 단위 자원

```python
from collections.abc import AsyncIterator
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import session_factory

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


async def get_db() -> AsyncIterator[AsyncSession]:
    async with session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    payload = decode_token(token)
    user = await db.get(User, UUID(payload["sub"]))
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    return user
```

> 핸들러 안에서 세션·클라이언트·자격증명을 인라인 생성하지 않는다. 무거운 객체는 `lifespan`·캐시로 재사용.

## async 엔드포인트 — I/O면 async, 안에서도 async 라이브러리

```python
@router.get("/", response_model=list[UserResponse])
async def list_users(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(User).order_by(User.created_at.desc()).limit(limit).offset(offset)
    )
    return result.scalars().all()
```

> 외부 HTTP는 `httpx.AsyncClient`. **async 라우트에서 `requests`·`time.sleep`·동기 드라이버 금지**(이벤트 루프 정지).

## 중앙 에러 핸들러 — 응답 형태 안정화

```python
class ApiError(Exception):
    def __init__(self, status_code: int, code: str, message: str):
        self.status_code, self.code, self.message = status_code, code, message


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(ApiError)
    async def api_error_handler(request: Request, exc: ApiError):
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": {"code": exc.code, "message": exc.message}},
        )
```

> 내부 예외 원문·스택트레이스·DB 에러를 클라이언트로 반환하지 않는다.

## 테스트 — `Depends` 대상을 오버라이드

```python
@pytest.fixture
async def client(test_session: AsyncSession):
    app = create_app()

    async def override_get_db():
        yield test_session

    app.dependency_overrides[get_db] = override_get_db
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
```

> 라우트가 실제로 참조하는 의존성(`get_db`)을 오버라이드한다 — 내부 헬퍼가 아니라.

## 보안 체크리스트

- 비밀번호 해싱: `argon2-cffi`·`bcrypt` 등 최신 해셔
- JWT: issuer·audience·만료·서명 알고리즘 검증
- CORS origin은 환경별로
- 인증·쓰기 위주 엔드포인트에 레이트 리밋
- 모든 요청 본문은 Pydantic 모델로 수신
- ORM 파라미터 바인딩/SQLAlchemy Core — f-string SQL 금지
- 로그에서 토큰·인증 헤더·쿠키·비밀번호 마스킹
- CI에서 의존성 감사

## 성능 체크리스트

- DB 커넥션 풀 명시 설정
- 리스트 엔드포인트 페이지네이션
- N+1 감시, eager loading 의도적 사용
- async 경로엔 async HTTP/DB 클라이언트
- 안정적·비싼 읽기는 명시적 무효화와 함께 캐시

## 참조

- 에이전트: `fastapi-reviewer`, 커맨드: `/fastapi-review`
- 스킬: `api-design`, `backend-patterns`, `python-patterns`, `python-testing`
- 규칙: `rules/python/fastapi.md`, `rules/python/security.md`
