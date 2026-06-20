---
Title: "UI/UX 예시와 참고 기준"
creation: 2026-06-20
modification: 2026-06-20
tags:
 - "arachne"
 - "ui-ux"
aliases:
 - "ui-ux-reference"
---
MOC:: [[Arachne]]
FROM:: [[docs/README]]

# UI/UX 예시와 참고 기준

이 디렉터리는 UI/UX 작업 때 참고할 예시와 판단 기준을 둔다.
규칙은 `rules/`와 `skills/`에 있고, 실제 화면·컴포넌트 사례는 `docs/ui-ux/examples/`에 둔다.

## 어디에 무엇을 두나

| 위치 | 용도 |
| --- | --- |
| [rules/common/ui-layout](../../rules/common/ui-layout.md) | 간격, 정렬, 밀도, 상태별 레이아웃 기준 |
| [rules/web/design-quality](../../rules/web/design-quality.md) | 제네릭 UI 방지, 시각 방향, 디자인 품질 기준 |
| [skills/frontend-patterns](../../skills/frontend-patterns.md) | React/Next 컴포넌트·상태·성능 패턴 |
| [skills/make-interfaces-feel-better](../../skills/make-interfaces-feel-better.md) | radius, optical alignment, motion, hit area 같은 디테일 |
| [examples/](examples/) | 화면·컴포넌트 예시와 before/after 기록 |

## 예시 작성 규칙

예시는 다음 항목을 포함한다.

- 대상 사용자와 반복 작업
- 화면의 첫 스캔 순서
- 간격·정렬 기준
- loading, empty, error, disabled 상태
- 모바일과 데스크톱 차이
- 검증 방법

## UI 작업 순서

1. 사용자와 반복 작업을 먼저 쓴다.
2. 화면 밀도를 정한다: 운영 도구, 폼, 랜딩, 모바일 작업 화면.
3. 기준 예시를 `examples/`에서 찾는다.
4. `rules/common/ui-layout.md`로 간격과 정렬을 잡는다.
5. `rules/web/design-quality.md`로 제네릭한 결과를 거른다.
6. 실제 브라우저 또는 스크린샷으로 overflow, 겹침, 상태 전이를 확인한다.
