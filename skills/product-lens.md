---
name: product-lens
description: 구현 전 "왜 만드는가"를 검증하고 사용자 문제, MVP, anti-goal, 성공 지표, 우선순위를 정리하는 제품 진단 스킬.
---

# Product Lens

기능을 바로 구현 계약으로 만들기 전에 제품 관점에서 압력을 가하는 스킬이다.

## 언제 사용하나

- 요구가 모호한 기능을 시작하기 전
- 여러 기능 후보 중 우선순위를 정해야 할 때
- 사용자의 실제 고통과 성공 지표가 불분명할 때
- 출시 전 사용자 여정을 점검할 때

## 제품 진단 질문

1. 누구를 위한 기능인가? "개발자"가 아니라 구체적 사용자 역할로 답한다.
2. 어떤 고통을 줄이는가? 빈도, 심각도, 현재 대안을 적는다.
3. 왜 지금인가? 새 제약, 새 기회, 기존 실패 이유를 적는다.
4. 10점짜리 버전은 무엇인가?
5. MVP는 무엇인가? 가설을 증명하는 가장 작은 단위로 줄인다.
6. anti-goal은 무엇인가? 이번에 의도적으로 만들지 않을 것을 적는다.
7. 성공을 어떻게 측정할 것인가? 느낌이 아니라 지표로 적는다.

## 출력 형식

```markdown
# PRODUCT-BRIEF: 기능명

## 사용자
## 문제
## 현재 대안
## MVP
## Anti-goal
## 성공 지표
## 위험
## Go / No-go
```

## Arachne에서의 연결

- 제품 brief가 구현으로 이어지면 `docs/task/`에 task를 만든다.
- 장기 설계 선택이 생기면 [architecture-decision-records](architecture-decision-records.md)를 사용한다.
- 사용자 여정이 UI와 연결되면 [frontend-patterns](frontend-patterns.md), [make-interfaces-feel-better](make-interfaces-feel-better.md)를 함께 사용한다.
