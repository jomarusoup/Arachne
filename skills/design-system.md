---
name: design-system
description: 디자인 토큰, 컴포넌트 상태, spacing, radius, typography, color, accessibility 기준을 일관되게 관리하는 스킬.
triggers:
  paths: ["**/*.css", "**/*.scss"]
  keywords: ["디자인 토큰", "spacing", "radius", "typography", "컴포넌트 상태"]
---

# Design System

UI가 화면마다 다른 규칙으로 흩어지지 않게 토큰과 컴포넌트 기준을 정한다.

## 핵심 토큰

- color: 배경, 표면, 텍스트, border, semantic 상태
- spacing: 4px 기반 scale
- radius: small, medium, large를 용도별로 제한
- typography: display, heading, body, caption, mono
- shadow: surface 분리와 popover 깊이에만 사용
- motion: duration, easing, reduced motion

## 컴포넌트 상태

모든 interactive component는 다음 상태를 고려한다.

- default
- hover
- active
- focus-visible
- disabled
- loading
- error

## 체크리스트

- [ ] spacing scale이 중복 임의값보다 우선한다.
- [ ] radius와 shadow가 컴포넌트 역할별로 제한돼 있다.
- [ ] 색은 의미 토큰으로 사용한다.
- [ ] focus-visible이 키보드 사용자에게 보인다.
- [ ] loading/empty/error 상태가 컴포넌트 API에 포함된다.
