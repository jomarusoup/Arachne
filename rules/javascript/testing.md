---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
---
# JavaScript / TypeScript 테스팅

> [common/testing.md](../common/testing.md) 를 확장한다.

## 프레임워크

- **단위·통합 테스트** — Jest 또는 Vitest
- **E2E 테스트** — Playwright

## 테스트 실행

```bash
npm test                          # 전체 테스트
npm test -- --coverage            # 커버리지
npm test -- --watch               # 감시 모드
npx playwright test               # E2E 테스트
```

## AAA 패턴 예시

```typescript
test("유효한 이메일로 사용자 생성 성공", async () => {
    /* Arrange */
    const input = { email: "user@example.com", age: 30 };

    /* Act */
    const result = await createUser(input);

    /* Assert */
    expect(result.id).toBeDefined();
    expect(result.email).toBe(input.email);
});
```

## 모킹

```typescript
jest.mock("../transport");
const MockTransport = Transport as jest.MockedClass<typeof Transport>;

test("전송 실패 시 에러 반환", async () => {
    MockTransport.prototype.send.mockRejectedValueOnce(new Error("timeout"));
    await expect(service.send("data")).rejects.toThrow("timeout");
});
```

## Playwright E2E 예시

```typescript
test("로그인 후 대시보드 접근", async ({ page }) => {
    await page.goto("/login");
    await page.fill('[name="email"]', "user@example.com");
    await page.fill('[name="password"]', "password");
    await page.click('[type="submit"]');
    await expect(page).toHaveURL("/dashboard");
});
```
