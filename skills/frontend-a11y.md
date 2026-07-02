---
name: frontend-a11y
description: 웹 UI 접근성 점검 스킬. 키보드 조작, focus, semantic HTML, label, contrast, motion preference, screen reader 흐름을 다룬다.
triggers:
  paths: ["**/*.tsx", "**/*.jsx", "**/*.html"]
  keywords: ["접근성", "a11y", "키보드 내비게이션", "focus", "contrast"]
---

# Frontend Accessibility

접근성은 마지막 장식이 아니라 UI 계약의 일부다.

## 기본 체크리스트

- [ ] 버튼은 `button`, 링크 이동은 `a`를 사용한다.
- [ ] 모든 input은 label과 연결돼 있다.
- [ ] keyboard만으로 주요 흐름을 완료할 수 있다.
- [ ] focus-visible이 명확하다.
- [ ] modal은 focus trap과 Escape close 정책이 있다.
- [ ] 색만으로 상태를 전달하지 않는다.
- [ ] 텍스트 대비가 충분하다.
- [ ] `prefers-reduced-motion`을 존중한다.

## 상태 메시지

- form error는 해당 필드와 연결한다.
- 비동기 성공/실패 메시지는 필요한 경우 live region을 사용한다.
- loading 중 버튼 텍스트가 바뀌어도 버튼 폭이 과도하게 흔들리지 않게 한다.

## 검증

```bash
npm run test
npm run e2e
```

프로젝트에 axe, Playwright accessibility 검사, Storybook a11y addon이 있으면 함께 실행한다.
