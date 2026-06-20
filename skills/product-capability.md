---
name: product-capability
description: 제품 목표를 구현 가능한 capability map, 사용자 여정, acceptance criteria, release slice로 변환한다.
---

# Product Capability

제품 아이디어를 엔지니어링 가능한 계약으로 바꾸는 스킬이다. `product-lens`가 "왜"를 검증한다면, 이 스킬은 "무엇을 어떤 순서로 만들지"를 정한다.

## 언제 사용하나

- product brief를 구현 계획으로 바꿀 때
- 기능 범위가 커서 release slice가 필요할 때
- 사용자 여정, API, 데이터, UI가 함께 움직일 때
- acceptance criteria가 불분명할 때

## Capability Map

```text
Goal
├── Capability A
│   ├── User journey
│   ├── API/data contract
│   ├── UI state
│   └── Verification
└── Capability B
```

## 작성 템플릿

```markdown
# CAPABILITY: 이름

## 목표
## 사용자
## 사용자 여정
## 기능 범위
## 제외 범위
## API / 데이터 계약
## UI 상태
## 보안·권한
## Acceptance Criteria
## Release Slice
## 검증 계획
```

## 좋은 acceptance criteria

- 관찰 가능한 동작으로 쓴다.
- 권한, 실패, 빈 상태, 로딩 상태를 포함한다.
- 테스트로 검증할 수 있어야 한다.

```text
Given 인증된 사용자가 주문 목록에 접근할 때
When 상태 필터를 "취소됨"으로 선택하면
Then 취소된 주문만 최신순으로 표시되고 URL query에 필터가 반영된다.
```
