---
paths:
  - "**/app/**/*.py"
  - "**/fastapi/**/*.py"
  - "**/*_api.py"
---
# FastAPI 규칙

> 일반 Python 규칙([coding-style.md](coding-style.md)·[patterns.md](patterns.md)·[security.md](security.md))과 함께 적용한다.
> FastAPI는 경량·async 구조라 Python 서버를 시스템 프로그래밍으로 전환하기 전 **브릿지 서버**로 적합하다.
> 아키텍처 원칙(레이어 분리·의존성 주입·경계 검증)은 추후 C/Rust 서버로 그대로 이식된다.

## 구조

- 앱 생성은 `create_app()` 팩토리에 모은다.
- 라우터는 얇게 유지 — 영속화·비즈니스 로직은 서비스/CRUD 헬퍼로 분리.
- 요청 스키마·수정 스키마·응답 스키마를 각각 분리한다.
- DB 세션·인증은 의존성(`Depends`)에 둔다.

## Async

- I/O를 수행하는 엔드포인트는 `async def` 사용.
- async 엔드포인트에서는 async DB·HTTP 클라이언트 사용.
- async 라우트에서 `requests`, 동기 SQLAlchemy 세션, 블로킹 파일/네트워크 연산 호출 **금지**.

```python
#-------------------------------------------------------------------------------
# BAD: async 라우트에서 블로킹 호출 → 이벤트 루프 정지
#-------------------------------------------------------------------------------
@router.get("/data")
async def get_data():
    return requests.get(url).json()   # 동기 호출이 루프를 막음

#-------------------------------------------------------------------------------
# GOOD: async 클라이언트 사용
#-------------------------------------------------------------------------------
@router.get("/data")
async def get_data(client: AsyncClient = Depends(get_client)):
    resp = await client.get(url)
    return resp.json()
```

## 의존성 주입

```python
@router.get("/users/{user_id}")
async def get_user(
    user_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    ...
```

라우트 핸들러 안에서 `SessionLocal()`이나 장수명 클라이언트를 직접 생성하지 않는다.

## 스키마

- 응답 모델에 비밀번호·비밀번호 해시·액세스 토큰·리프레시 토큰·내부 인증 상태를 **절대 포함하지 않는다**.
- 애플리케이션 데이터를 반환하는 엔드포인트에는 `response_model` 지정.
- Pydantic으로 표현 가능한 규칙은 손수 검증 대신 필드 제약(`Field`)으로 처리.

## 보안

- CORS origin은 환경별로 명시한다.
- 와일드카드 origin과 credentialed CORS를 함께 쓰지 않는다.
- JWT 만료·발급자(issuer)·대상(audience)·알고리즘을 검증한다.
- 인증·쓰기 위주 엔드포인트에 레이트 리미팅 적용.
- 로그에서 자격증명·쿠키·Authorization 헤더·토큰을 마스킹한다.

## 테스트

- `Depends`가 사용하는 정확한 의존성을 오버라이드한다.
- 테스트 후 `app.dependency_overrides`를 비운다.
- async 애플리케이션은 async 테스트 클라이언트를 우선 사용.

> 상세 패턴·코드 예시는 스킬 `python-patterns`, `backend-patterns` 참고.
