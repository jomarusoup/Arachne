---
description: PEP 8·타입 힌트·보안·이디엄 종합 Python 코드 리뷰 — python-reviewer 에이전트 호출
---

# /python-review — Python 코드 리뷰

**python-reviewer** 에이전트를 호출해 Python 특화 종합 리뷰를 수행한다.

## 동작

1. **변경 식별** — `git diff`로 수정된 `.py` 파일 탐색
2. **정적 분석** — `ruff` · `mypy` · `black --check` · `isort --check-only` 실행
3. **보안 스캔** — SQL/커맨드 인젝션, 안전하지 않은 역직렬화, 하드코딩 비밀 점검
4. **타입 안전성** — 타입 힌트·mypy 오류 분석
5. **이디엄 점검** — PEP 8·Pythonic 패턴 확인
6. **리포트** — 심각도별 분류

## 언제 사용하나

- Python 코드 작성·수정 후, 커밋 전
- Python 코드가 포함된 PR 리뷰
- 새 Python 코드베이스 온보딩

## 리뷰 카테고리

### CRITICAL (반드시 수정)
- SQL/커맨드 인젝션
- 안전하지 않은 `eval`/`exec`, `pickle` 역직렬화, YAML unsafe load
- 하드코딩된 자격증명
- 에러를 숨기는 bare except

### HIGH (수정 권장)
- 공개 함수 타입 힌트 누락
- 가변 기본 인자 (`def f(x=[])`)
- 조용히 삼켜진 예외, 컨텍스트 매니저 미사용
- 컴프리헨션 대신 C 스타일 루프, `type()` 대신 `isinstance` 미사용
- 락 없는 레이스 컨디션, async 라우트의 블로킹 호출

### MEDIUM (검토)
- PEP 8 포맷 위반, 공개 함수 docstring 누락
- `print` 대신 `logging`, f-string 미사용
- 매직 넘버, 빌트인 섀도잉

## 자동 검사

```bash
ruff check .            # 린팅
mypy .                  # 타입 검사
black --check .         # 포맷
isort --check-only .    # 임포트 정렬
bandit -r .             # 보안 스캔
pip-audit               # 의존성 취약점
pytest --cov=app --cov-report=term-missing
```

## 흔한 수정 패턴

```python
# 가변 기본 인자
def f(items=[]):           # BAD → 호출 간 상태 공유
def f(items=None):         # GOOD
    if items is None:
        items = []

# 컨텍스트 매니저
f = open("x"); ...; f.close()   # BAD → 예외 시 누수
with open("x") as f: ...        # GOOD

# 컴프리헨션
result = []                     # BAD
for i in items:
    if i.active:
        result.append(i.name)
result = [i.name for i in items if i.active]   # GOOD

# 문자열 결합
s = ""                          # BAD → O(n²)
for i in items: s += str(i)
s = "".join(str(i) for i in items)   # GOOD
```

## 승인 기준

| 상태 | 조건 |
| ---- | ---- |
| 승인 | CRITICAL·HIGH 없음 |
| 경고 | MEDIUM만 존재 (주의 후 머지) |
| 차단 | CRITICAL·HIGH 존재 |

## 연계

- 비-Python 관심사는 `/code-review`
- 커밋 전 검증은 `/verify`
- 상세 패턴은 스킬 `python-patterns` · `python-testing` · `backend-patterns`
- 에이전트: `agents/python-reviewer.md`
