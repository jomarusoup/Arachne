---
name: frontend-design-direction
description: 웹·앱·대시보드 UI를 만들기 전 제품 목적, 사용자, 톤, 밀도, 시각 방향을 정하는 프론트엔드 디자인 방향 스킬.
triggers:
  paths: []
  keywords: ["디자인 방향", "톤", "밀도", "시각 방향", "UI 기획"]
---

# Frontend Design Direction

UI를 단순히 동작하게 만드는 것이 아니라 제품에 맞게 보이도록 방향을 정한다.

## 언제 사용하나

- 새 화면, 앱, 대시보드, 컴포넌트를 만들 때
- 기존 UI가 제네릭하거나 어색할 때
- 시각 위계, 간격, 타이포그래피, 색, 상태 설계가 필요할 때

## 코딩 전 결정

1. 목적: 이 화면이 해결하는 작업은 무엇인가?
2. 사용자: 누가 반복해서 쓰는가?
3. 톤: 조용한 운영 도구, 기술적, 편집적, 고급스러운, playful 등 명시한다.
4. 밀도: 많은 정보를 스캔해야 하는가, 메시지를 전달해야 하는가?
5. 기억점: 이 UI를 의도적으로 보이게 하는 한 가지 디테일은 무엇인가?
6. 제약: 기존 디자인 시스템, 접근성, 성능, 반응형 조건은 무엇인가?

## 방향 예시

- 운영 SaaS: dense, calm, scannable, low decoration
- 개발자 도구: technical, compact, keyboard-friendly
- 제품 랜딩: expressive, asset-led, strong first viewport
- 데이터 대시보드: hierarchy-first, table/chart clarity, stable numbers

## 연결 문서

- [rules/web/ui-layout](../rules/web/ui-layout.md)
- [rules/web/design-quality](../rules/web/design-quality.md)
- [docs/ui-ux/README](../docs/ui-ux/README.md)
