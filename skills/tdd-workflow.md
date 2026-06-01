---
name: tdd-workflow
description: 신규 기능 작성·버그 수정·리팩터링 시 사용. 단위·통합·E2E 테스트 포함 80%+ 커버리지로 테스트 주도 개발 강제.
---

# 테스트 주도 개발 워크플로

모든 코드 개발이 TDD 원칙을 따르고 포괄적인 테스트 커버리지를 갖추도록 보장한다.

## 언제 활성화하나

- 신규 기능 작성
- 버그 수정
- 기존 코드 리팩터링
- API 엔드포인트 추가
- 새 컴포넌트 생성

## 핵심 원칙

### 1. 코드보다 테스트 먼저

항상 테스트를 먼저 작성하고, 그 후 테스트를 통과시키는 코드를 구현한다.

### 2. 커버리지 요구사항

- 최소 80% 커버리지 (단위 + 통합 + E2E)
- 모든 엣지 케이스 커버
- 에러 시나리오 테스트
- 경계 조건 검증

### 3. 테스트 유형

| 유형            | 대상                                   |
| --------------- | -------------------------------------- |
| **단위 테스트** | 개별 함수·컴포넌트 로직·순수 함수      |
| **통합 테스트** | API 엔드포인트·DB 작업·서비스 상호작용 |
| **E2E 테스트**  | 중요 사용자 플로우·완전한 워크플로     |

### 4. Git 체크포인트

- 저장소가 Git 하에 있으면 각 TDD 단계 후 체크포인트 커밋 생성
- 권장 커밋 형식:
  - `test: <기능 또는 버그>에 대한 재현 테스트 추가` (RED)
  - `fix: <기능 또는 버그>` (GREEN)
  - `refactor: <기능 또는 버그> 구현 후 정리` (IMPROVE)

## TDD 워크플로 단계

### 1단계: 사용자 여정 작성

```
[역할]로서, [액션]을 하고 싶다, 그래서 [이점]을 얻을 수 있다.
```

### 2단계: 테스트 케이스 생성

```typescript
describe('의미론적 검색', () => {
  it('쿼리에 맞는 관련 시장을 반환한다', async () => { })
  it('빈 쿼리를 우아하게 처리한다', async () => { })
  it('Redis 사용 불가 시 문자열 검색으로 폴백한다', async () => { })
})
```

### 3단계: 테스트 실행 — 실패 확인 (RED)

```bash
npm test / make test / go test ./... / pytest
```

**RED 게이트**: 운영 코드 수정 전에 유효한 RED 상태를 확인해야 한다.
- 런타임 RED: 테스트가 실행되어 의도된 이유로 실패함
- 컴파일 타임 RED: 새 테스트가 결함 있는 코드를 참조하고 컴파일 실패가 RED 신호

관련 없는 문법 오류나 테스트 설정 문제는 RED로 인정하지 않는다.

Git 저장소면 이 단계 검증 직후 체크포인트 커밋 생성.

### 4단계: 코드 구현

테스트를 통과시키는 최소한의 코드 작성.

### 5단계: 테스트 다시 실행 — 통과 확인 (GREEN)

```bash
npm test / make test / go test ./... / pytest
```

동일한 관련 테스트 대상을 재실행하고 이전에 실패한 테스트가 GREEN임을 확인.
GREEN 결과 후에만 리팩터링 진행.

### 6단계: 리팩터링 (IMPROVE)

테스트를 유지하면서 코드 품질 개선: 중복 제거, 네이밍 개선, 성능 최적화.

### 7단계: 커버리지 확인

```bash
npm run test:coverage          # JavaScript
go test -cover ./...           # Go
pytest --cov=src               # Python
lcov --capture --directory .   # C/C++
# 목표: 80%+
```

## 테스트 패턴

### 단위 테스트 (Jest/Vitest)

```typescript
describe('Button 컴포넌트', () => {
  it('올바른 텍스트로 렌더링된다', () => {
    render(<Button>Click me</Button>)
    expect(screen.getByText('Click me')).toBeInTheDocument()
  })

  it('클릭 시 onClick을 호출한다', () => {
    const handleClick = jest.fn()
    render(<Button onClick={handleClick}>Click</Button>)
    fireEvent.click(screen.getByRole('button'))
    expect(handleClick).toHaveBeenCalledTimes(1)
  })
})
```

### API 통합 테스트

```typescript
describe('GET /api/markets', () => {
  it('시장을 성공적으로 반환한다', async () => {
    const response = await GET(new NextRequest('http://localhost/api/markets'))
    expect(response.status).toBe(200)
  })

  it('잘못된 파라미터에 400을 반환한다', async () => {
    const response = await GET(new NextRequest('http://localhost/api/markets?limit=invalid'))
    expect(response.status).toBe(400)
  })
})
```

### E2E 테스트 (Playwright)

```typescript
test('사용자가 시장을 검색하고 필터링할 수 있다', async ({ page }) => {
  await page.goto('/')
  await page.fill('input[placeholder="시장 검색"]', '선거')
  await page.waitForTimeout(600)
  await expect(page.locator('[data-testid="market-card"]')).toHaveCount(5)
})
```

## 흔한 테스트 실수

```typescript
/* 잘못됨: 구현 세부사항 테스트 */
expect(component.state.count).toBe(5)

/* 올바름: 사용자에게 보이는 동작 테스트 */
expect(screen.getByText('Count: 5')).toBeInTheDocument()

/* 잘못됨: 취약한 셀렉터 */
await page.click('.css-class-xyz')

/* 올바름: 의미론적 셀렉터 */
await page.click('button:has-text("제출")')
```

## CI/CD 통합

```yaml
# GitHub Actions
- name: 테스트 실행
  run: npm test -- --coverage
- name: 커버리지 업로드
  uses: codecov/codecov-action@v3
```

## 모범 사례

1. **테스트 먼저 작성** — 항상 TDD
2. **테스트당 하나의 단언** — 단일 동작에 집중
3. **설명적인 테스트 이름** — 무엇을 테스트하는지 설명
4. **Arrange-Act-Assert** — 명확한 테스트 구조
5. **외부 의존성 모킹** — 단위 테스트 격리
6. **엣지 케이스 테스트** — null, undefined, empty, 대용량
7. **에러 경로 테스트** — 행복 경로만 테스트하지 않음
8. **테스트를 빠르게 유지** — 단위 테스트 < 50ms
9. **테스트 후 정리** — 부작용 없음
10. **커버리지 리포트 검토** — 격차 식별

---

**기억**: 테스트는 선택사항이 아니다. 자신감 있는 리팩터링·빠른 개발·운영 안정성을 가능하게 하는 안전망이다.
