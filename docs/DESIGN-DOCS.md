---
Title: "프로젝트 디자인 문서 계약"
creation: 2026-07-01
modification: 2026-07-01
status: "done"
tags:
 - "arachne"
 - "design"
 - "web"
aliases:
 - "project-design-docs"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-09-project-design-docs-contract]]

# 프로젝트 디자인 문서 계약

Arachne 자체의 디자인 품질 규칙은 `rules/web/design-quality.md`와 `skills/frontend-design-direction.md`가
담당한다. Arachne를 사용하는 개별 Web 프로젝트의 제품 디자인 정본은 `docs/design/DESIGN.md`다.

## 위치와 소유권

| 경로 | 책임 | 소유 |
| --- | --- | --- |
| `docs/design/DESIGN.md` | 제품 방향, 대상 사용자, UX 원칙, 상태·반응형·접근성 목표 | 프로젝트 |
| `docs/design/README.md` | 디자인 문서가 여러 개로 분리될 때 인덱스 | 프로젝트 |
| `docs/design/decisions/` | 중요한 디자인 결정과 대안 | 프로젝트 |
| token/theme 소스 | 실제 color, spacing, typography, radius 값 | 코드 |

Markdown은 token 값을 중복 관리하지 않는다. `DESIGN.md`에는 값의 의미, 선택 이유, 실제 token 파일
경로만 둔다.

## 생성 규칙

- `arachne new --profile web`과 `arachne new --profile python-web`은 `docs/design/DESIGN.md`와
  `docs/design/decisions/.gitkeep`을 생성한다.
- `arachne init-ci --profile web|python-web`은 기존 프로젝트에 디자인 문서가 없을 때만 최소
  구조를 생성한다.
- `minimal`과 `python` profile에는 디자인 문서를 만들지 않는다.
- 기존 `docs/design/DESIGN.md`, `docs/design/README.md`, 루트 `DESIGN.md`는 덮어쓰지 않는다.
- `docs/design`, `docs/design/DESIGN.md`, `docs/design/decisions`, 루트 `DESIGN.md`가 심볼릭
  링크면 쓰기를 거부한다.

## 탐색 우선순위

`/design`은 다음 순서로 읽는다.

1. `docs/design/DESIGN.md`
2. `docs/design/README.md`와 그 인덱스가 가리키는 분리 문서
3. 루트 `DESIGN.md` legacy fallback
4. 문서가 없으면 자동 생성하지 않고 생성 계획과 범위를 먼저 제안

## 분리 기준

작은 프로젝트는 `docs/design/DESIGN.md` 하나로 충분하다. 다음 조건이 생기면 분리 문서를 추가한다.

| 조건 | 분리 문서 |
| --- | --- |
| token·component 상태의 설계 의도가 길어진다 | `docs/design/design-system.md` |
| 여러 사용자 여정과 상태 전이가 있다 | `docs/design/ux-flows.md` |
| 접근성 목표와 예외를 추적해야 한다 | `docs/design/accessibility.md` |
| 화면별 복잡한 반응형 동작이 있다 | `docs/design/responsive.md` |
| 용어·마이크로카피 결정이 반복된다 | `docs/design/content-style.md` |
| 브라우저·viewport·상태 QA가 필요하다 | `docs/design/qa-checklist.md` |

## 참조

- `/design` command: `commands/design.md`
- Web 품질 규칙: `rules/web/design-quality.md`
- Python/Web profile: `docs/PYTHON-WEB-PROFILE.md`

