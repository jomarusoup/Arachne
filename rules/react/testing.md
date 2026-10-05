---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---
# React 테스팅

> [javascript/testing.md](../javascript/testing.md)를 확장한다.
> 상세 예시(userEvent·MSW·커스텀 훅 테스트)는 스킬 `react-testing`에 둔다.

## 원칙

- 구현 세부가 아니라 사용자가 보는 결과를 검증한다.
- 컴포넌트 내부 state·인스턴스 메서드·CSS 클래스에 의존하는 단언을 쓰지 않는다.
- 사용자 입력은 `fireEvent` 대신 `@testing-library/user-event`로 재현한다.
- 네트워크는 함수 모킹 대신 MSW로 요청 단위에서 가로챈다.

## 쿼리 우선순위

위에서부터 고른다. 아래로 내려갈수록 사용자 경험과 멀어진다.

| 순위 | 쿼리 | 용도 |
|---|---|---|
| 1 | `getByRole` (+ `name`) | 대부분의 요소. 접근성 트리와 같은 기준이다 |
| 2 | `getByLabelText` | 폼 입력 |
| 3 | `getByPlaceholderText` | 라벨이 없을 때만 (라벨 누락 자체가 a11y 문제다) |
| 4 | `getByText` | 비상호작용 텍스트 |
| 5 | `getByDisplayValue` | 채워진 입력값 |
| 6 | `getByAltText`·`getByTitle` | 이미지·보조 텍스트 |
| 7 | `getByTestId` | 위 방법이 모두 불가능할 때만 |

`getByRole`로 찾을 수 없다면 마크업의 접근성부터 의심한다.

## 비동기

- 나타날 요소는 `findBy*`로 기다린다. `waitFor` 안에 부수효과를 넣지 않는다.
- 사라짐 확인은 `waitForElementToBeRemoved` 또는 `queryBy*` + `not.toBeInTheDocument()`.
- 고정 시간 `sleep`을 쓰지 않는다. 타이머는 가짜 타이머로 제어한다.

## 스냅샷

- 큰 컴포넌트 트리 스냅샷을 쓰지 않는다. 의미 없는 변경에도 깨지고 리뷰에서 그냥 갱신된다.
- 작고 안정적인 직렬화 결과(포맷 함수 출력 등)에만 인라인 스냅샷을 허용한다.

## 예시

```tsx
test("수량_0_입력시_주문_버튼_비활성", async () => {
    /* Arrange */
    const user = userEvent.setup();
    render(<OrderForm />);

    /* Act */
    await user.type(screen.getByLabelText("수량"), "0");

    /* Assert */
    expect(screen.getByRole("button", { name: "주문" })).toBeDisabled();
});
```
