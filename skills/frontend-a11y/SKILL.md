---
name: frontend-a11y
description: 웹 UI 접근성 점검 스킬. 키보드 조작, focus 관리, semantic HTML, 폼 라벨·오류 연결, ARIA 사용 기준, live region, contrast, reduced motion, screen reader 흐름을 다룬다. 대상 경로 — **/*.tsx, **/*.jsx, **/*.html. 키워드 — 접근성, a11y, 키보드 내비게이션, focus, ARIA, contrast, reduced motion.
---

# Frontend Accessibility

접근성은 마지막 장식이 아니라 UI 계약의 일부다.
키보드와 스크린리더만으로 주요 흐름을 끝낼 수 있어야 한다.

## 언제 사용하나

- 폼·모달·메뉴·탭·테이블 같은 상호작용 컴포넌트를 만들거나 고칠 때
- 커스텀 컴포넌트(셀렉트·콤보박스)를 직접 구현할 때
- 애니메이션·실시간 갱신 화면을 추가할 때
- 리뷰에서 a11y 지적을 받았을 때

## 어떻게

### 1. 기본 체크리스트

- [ ] 버튼은 `button`, 링크 이동은 `a`를 사용한다.
- [ ] 모든 input은 label과 연결돼 있다.
- [ ] keyboard만으로 주요 흐름을 완료할 수 있다.
- [ ] focus-visible이 명확하다.
- [ ] modal은 focus trap과 Escape close 정책이 있다.
- [ ] 색만으로 상태를 전달하지 않는다.
- [ ] 텍스트 대비가 충분하다 (본문 4.5:1, 큰 텍스트·UI 경계 3:1).
- [ ] `prefers-reduced-motion`을 존중한다.

### 2. 폼

- 모든 입력에 보이는 `<label>`을 둔다. placeholder는 라벨을 대신하지 않는다.
- 필수 입력은 `required`(또는 `aria-required`)와 시각 표시를 함께 쓴다.
- 오류 메시지는 `aria-describedby`로 필드에 연결하고, 오류 상태에 `aria-invalid="true"`를 준다.
- 제출 실패 시 첫 오류 필드로 포커스를 옮긴다. 오류가 많으면 상단 요약을 두고 각 필드로 링크한다.
- 관련 입력 묶음(라디오·주소)은 `<fieldset>`·`<legend>`로 묶는다.
- `autocomplete` 속성(`email`·`current-password` 등)을 지정한다. 자동 완성과 보조 기술이 함께 좋아진다.

```tsx
<label htmlFor="qty">수량</label>
<input
    id="qty"
    inputMode="numeric"
    aria-invalid={qtyError ? true : undefined}
    aria-describedby={qtyError ? "qty-error" : undefined}
/>
{qtyError && <p id="qty-error">{qtyError}</p>}
```

### 3. ARIA 사용 기준

ARIA의 첫 규칙은 "쓸 수 있으면 네이티브 요소를 쓴다"이다.
잘못된 ARIA는 ARIA가 없는 것보다 나쁘다.

| 상황 | 쓸 것 |
|---|---|
| 아이콘만 있는 버튼 | `aria-label="닫기"` |
| 펼침·접힘 토글 | `aria-expanded` + `aria-controls` |
| 현재 위치 탭·페이지 | `aria-selected`(탭) · `aria-current="page"`(내비게이션) |
| 장식 아이콘 | `aria-hidden="true"` |
| 로딩 중 영역 | `aria-busy="true"` |
| 커스텀 위젯 | WAI-ARIA Authoring Practices의 패턴(role·키보드 동작)을 그대로 따른다 |

- `role="button"`을 `div`에 붙이면 Enter·Space 처리와 `tabIndex={0}`까지 직접 구현해야 한다. 그냥 `button`을 쓴다.
- `aria-label`은 보이는 텍스트와 일치시킨다. 음성 제어 사용자가 보이는 이름으로 호출한다.

### 4. 상태 메시지와 live region

- 비동기 성공·안내는 `role="status"`(정중), 즉시 알려야 하는 오류는 `role="alert"`(즉시)를 쓴다.
- live region 요소는 처음부터 DOM에 두고 내용만 바꾼다. 요소를 새로 삽입하면 읽지 않는 경우가 있다.
- 실시간 가격처럼 계속 바뀌는 값은 live region에 넣지 않는다. 스크린리더가 끊임없이 읽는다.
  대신 사용자가 요청할 때 읽을 수 있게 하거나, 임계 이벤트(체결·경보)만 알린다.
- loading 중 버튼 텍스트가 바뀌어도 버튼 폭이 과도하게 흔들리지 않게 한다.

### 5. 포커스 관리

| 상황 | 포커스 처리 |
|---|---|
| 모달 열림 | 모달 안 첫 상호작용 요소(또는 제목)로 이동, 바깥은 `inert` |
| 모달 닫힘 | 모달을 연 트리거로 복원 |
| SPA 경로 이동 | 새 화면의 `h1`(`tabIndex={-1}`)로 이동하고 제목을 갱신 |
| 항목 삭제 | 다음 항목 또는 목록 컨테이너로 이동 (포커스가 `body`로 떨어지지 않게) |
| 복합 위젯(탭·메뉴·그리드) | 진입은 Tab 한 번, 내부 이동은 화살표 키 (roving tabindex) |

- 네이티브 `<dialog>`의 `showModal()`은 포커스 가두기와 Escape 닫기를 기본 제공한다.
- `tabIndex`에 양수를 쓰지 않는다. 문서 순서를 깨뜨린다.
- 포커스 표시를 `outline: none`으로 지우지 않는다. 지운다면 `:focus-visible`로 대체 스타일을 준다.
- 페이지 상단에 "본문으로 건너뛰기" 링크를 둔다.

### 6. 모션 줄이기

- `prefers-reduced-motion: reduce`이면 이동·확대·패럴랙스 애니메이션을 끄거나 페이드로 바꾼다.
- 5초 넘게 자동 재생되는 움직임에는 일시정지 수단을 둔다.
- 초당 3회 넘게 번쩍이는 효과를 쓰지 않는다.

```css
@media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
        animation-duration: 0.01ms !important;
        transition-duration: 0.01ms !important;
        scroll-behavior: auto !important;
    }
}
```

JS 애니메이션은 `window.matchMedia("(prefers-reduced-motion: reduce)").matches`를 확인한다.
Framer Motion은 `useReducedMotion()`을 쓴다.

## 예시 — 확인 모달

```tsx
export function ConfirmDialog({ open, onClose, onConfirm }: Readonly<ConfirmDialogProps>): JSX.Element {
    const ref = useRef<HTMLDialogElement>(null);

    useEffect(() => {
        const dialog = ref.current;
        if (!dialog) return;
        if (open && !dialog.open) dialog.showModal();     // 포커스 가두기·Escape 기본 제공
        if (!open && dialog.open) dialog.close();
    }, [open]);

    return (
        <dialog ref={ref} aria-labelledby="confirm-title" onClose={onClose}>
            <h2 id="confirm-title">주문을 취소할까요?</h2>
            <button onClick={onClose}>돌아가기</button>
            <button onClick={onConfirm}>주문 취소</button>
        </dialog>
    );
}
```

닫힌 뒤 트리거로 포커스가 돌아오는지 브라우저에서 직접 확인한다.

## 검증

```bash
npm run test
npm run e2e
npx @axe-core/cli <url>      # 자동 점검 (가능 시)
```

프로젝트에 axe, Playwright accessibility 검사, Storybook a11y addon이 있으면 함께 실행한다.
자동 도구는 문제의 일부만 잡는다. 키보드만으로 한 번, 스크린리더(VoiceOver·NVDA)로 한 번 흐름을 직접 확인한다.
컴포넌트 테스트에서는 `getByRole` 쿼리가 실패하는 것 자체가 a11y 신호다 (`react-testing` 스킬).
