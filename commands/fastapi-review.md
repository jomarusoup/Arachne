---
description: async 정확성·의존성 주입·스키마 분리·보안·OpenAPI 종합 FastAPI 리뷰 — fastapi-reviewer 에이전트 호출
---

# /fastapi-review — FastAPI 코드 리뷰

**fastapi-reviewer** 에이전트를 호출해 FastAPI 특화 종합 리뷰를 수행한다.
Python 일반 이디엄은 `/python-review`와 겹치므로 **async·DI·API 경계** 고유 문제에 집중한다.

## 동작

1. **변경 식별** — `git diff`로 수정된 라우터·의존성·스키마·모델 탐색
2. **정적 분석** — `ruff check` · `mypy` 실행
3. **보안 점검** — SQL 인젝션, `response_model` 과노출, CORS 오설정, 인증·인가 누락
4. **async 정확성** — 핸들러 내 블로킹 I/O, await 누락, 의존성 정리
5. **스키마·DI** — 입력/출력 스키마 분리, 요청 단위 DB 세션, 상태 코드 의미
6. **리포트** — 심각도별 분류

## 언제 사용하나

- FastAPI 엔드포인트 작성·수정 후, 커밋 전
- API 코드가 포함된 PR 리뷰
- 새 FastAPI 코드베이스 온보딩

## 리뷰 카테고리

### CRITICAL (반드시 수정)
- SQL 인젝션 (f-string 쿼리)
- `response_model` 미지정으로 비밀번호·내부 필드 누출
- `allow_origins=["*"]` + `allow_credentials=True`
- async 핸들러 내 블로킹 I/O (`requests`·`time.sleep`·동기 드라이버)
- 인증·인가 누락

### HIGH (수정 권장)
- 전역 DB 세션 공유 (→ `Depends(get_db)` 요청 단위)
- raw `dict`/`Request.json()` 직접 파싱 (→ Pydantic 모델)
- 입력/출력 스키마 미분리 (과입력·과노출)
- 상태 코드 오용 (201/204/409/422 구분)
- 내부 예외 메시지·스택트레이스 클라이언트 누출

### MEDIUM (검토)
- 비대한 라우터 (→ 서비스 레이어), 앱 팩토리 미사용
- OpenAPI 문서 부실 (응답·에러 모델·설명 누락)

## 자동 검사

```bash
ruff check .                                # 린팅
mypy .                                      # 타입 검사
bandit -r .                                 # 보안 스캔
pytest --cov=app --cov-report=term-missing  # TestClient·dependency_overrides
```

## 흔한 수정 패턴

```python
# 응답 과노출 차단
@app.get("/users/{id}")                                  # BAD
async def get_user(id): return db.get(User, id)
@app.get("/users/{id}", response_model=UserOut)          # GOOD

# async 핸들러 내 블로킹 → 비동기 클라이언트
r = requests.get(url)                                    # BAD (루프 정지)
async with httpx.AsyncClient() as c: r = await c.get(url)  # GOOD

# 요청 단위 DB 세션
def get_db():                                            # GOOD
    db = SessionLocal()
    try: yield db
    finally: db.close()
```

## 승인 기준

| 상태 | 조건 |
| ---- | ---- |
| 승인 | CRITICAL·HIGH 없음 |
| 경고 | MEDIUM만 존재 (주의 후 머지) |
| 차단 | CRITICAL·HIGH 존재 |

## 연계

- Python 일반 리뷰는 `/python-review`, 프론트엔드는 `/react-review`
- 커밋 전 검증은 `/verify`
- 상세 패턴은 스킬 `backend-patterns`, 규칙 `rules/python/fastapi.md`·`rules/python/security.md`
- 에이전트: `agents/fastapi-reviewer.md`
