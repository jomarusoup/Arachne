---
Title: "Arachne 문서 인덱스"
creation: 2026-06-09
modification: 2026-11-21
tags:
 - "arachne"
 - "documentation"
aliases:
 - "arachne-docs"
---
MOC:: [[Arachne]]
FROM:: [[100. Project/110. Side-Project/111. Arachne/docs/README]]

# Arachne 문서 지도

하고 싶은 일을 고르고, 그 줄의 문서를 **왼쪽부터 순서대로** 읽는다.
문서와 실제 동작이 다르면 소스·테스트가 우선이다([관리 규칙 §8](MANAGEMENT.md#8-정본-문서-갱신)).

## 1. 독자 경로

| 하고 싶은 일 | 읽는 순서 |
|---|---|
| **A. 처음 설치하고 감 잡기** (30분) | [루트 README](../README.md) → [USAGE §0](USAGE.md#0-overview-at-a-glance) → [GLOSSARY](GLOSSARY.md) |
| **B. 매일 쓰기** — 커맨드·에이전트·스킬·훅 | [USAGE](USAGE.md) §1~§5 → [ARCHITECTURE](ARCHITECTURE.md) 규칙 로딩 절 |
| **C. 내 프로젝트에 적용하기** — CI·검증 | [PROJECT-CI](PROJECT-CI.md) → [DATA-HANDLING](DATA-HANDLING.md) → [DESIGN-DOCS](DESIGN-DOCS.md) |
| **D. 하네스를 고치기** — 규칙·자산 변경 | [OBJECTIVES](OBJECTIVES.md) → [MANAGEMENT](MANAGEMENT.md) → [CI](CI.md) → [decisions/](decisions/README.md) → [진행 중 계획](task/2026-11-20-harness-direction-plan.md) |
| **E. 플랫폼·동기화 맞추기** | [COMPATIBILITY](COMPATIBILITY.md) → [WINDOWS-SETUP](WINDOWS-SETUP.md) → [SYNCTHING-SETUP](SYNCTHING-SETUP.md) → [DOCS-SYNC](DOCS-SYNC.md) |

D를 하기 전에는 반드시 두 가지를 확인한다.
- 지금은 **자산 추가 동결 중**이다(2026-11-20~). 규칙·스킬·에이전트·커맨드 추가는 ADR로만 한다([MANAGEMENT §6](MANAGEMENT.md#6-동결-자산-추가)).
- `~/.claude`가 main 체크아웃을 가리키므로 작업은 worktree에서 하고, push는 사람 확인 후에 한다([MANAGEMENT §7](MANAGEMENT.md#7-브랜치커밋push)).

## 2. 정본 문서

정본은 **현재 상태**를 설명한다. 한 주제는 한 문서에만 쓴다.

### 목표와 규칙

| 문서 | 무엇의 정본인가 |
|---|---|
| [OBJECTIVES](OBJECTIVES.md) | 북극성·우선순위·범위·계층·운영 원칙·동결. 예산 수치는 [`objectives/budgets.yaml`](../objectives/budgets.yaml) |
| [MANAGEMENT](MANAGEMENT.md) | 버전·기록 분류·계획·결정·폐기·동결·브랜치·문서 갱신 규칙과 각각의 강제 수단 |
| [decisions/README](decisions/README.md) | ADR 목록과 다음 번호 |

### 사용

| 문서 | 무엇의 정본인가 |
|---|---|
| [USAGE](USAGE.md) | 커맨드·에이전트·스킬·훅·규칙 사용법, 설치·업데이트 명령 |
| [ARCHITECTURE](ARCHITECTURE.md) | 설치 배선, 훅 흐름, 보안 계층, 규칙 로딩, 프로젝트 키트 구조도 |
| [GLOSSARY](GLOSSARY.md) | 약어·용어 |

### 프로젝트 적용

| 문서 | 무엇의 정본인가 |
|---|---|
| [PROJECT-CI](PROJECT-CI.md) | `arachne init-ci`·profile(`minimal`·`cpp`·`rust`·`python`…)·`.arachne/` 소유권·브랜치 보호 |
| [DATA-HANDLING](DATA-HANDLING.md) | 개인정보 분류, 노출 표면, 암호화 경계, DB 품질 게이트 |
| [DESIGN-DOCS](DESIGN-DOCS.md) | 사용 프로젝트 디자인 문서 위치와 `/design` 탐색 순서 |
| [PYTHON-WEB-PROFILE](PYTHON-WEB-PROFILE.md) | `minimal`·`python` profile 도구 (`web`·`python-web` 부분은 범위 밖 표시) |

### 운영·플랫폼

| 문서 | 무엇의 정본인가 |
|---|---|
| [CI](CI.md) | 이 저장소 자체 GitHub Actions와 로컬 재현 |
| [COMPATIBILITY](COMPATIBILITY.md) | 기능별 Linux·macOS·Windows 지원 범위 |
| [WINDOWS-SETUP](WINDOWS-SETUP.md) | Windows 설치 — PowerShell·Git Bash·WSL |
| [SYNCTHING-SETUP](SYNCTHING-SETUP.md) | 다중 머신 설정 동기화 |
| [DOCS-SYNC](DOCS-SYNC.md) | 원격 프로젝트 문서 ↔ Obsidian 동기화 |
| [tools/README](tools/README.md) | 확장 도구(codegraph·Understand-Anything·taste-skill) 설치·사용 |

### 학습

| 문서 | 무엇의 정본인가 |
|---|---|
| [HARNESS-LEARNING-GUIDE](HARNESS-LEARNING-GUIDE.md) | 하네스를 익히는 순서 |
| [AI-ENGINEERING-NOTES](AI-ENGINEERING-NOTES.md) | 에이전틱 엔지니어링 설계 노트 |

### 범위 밖 (계획 2-1에서 아카이브 예정)

[OBJECTIVES §2](OBJECTIVES.md#2-범위)의 범위 밖 자산을 다루거나 많이 포함한 문서다. 아카이브 전까지 현재 동작 설명으로 남아 있고, 각 문서 상단에 표시가 있다.

| 문서 | 범위 밖 내용 |
|---|---|
| [CAPABILITY-MAP](CAPABILITY-MAP.md) | Python·Web·Java·Electron 영역 |
| [MULTI-CLI](MULTI-CLI.md) | Gemini·Codex·Copilot 어댑터 (결정 D-08) |
| [ui-ux/README](ui-ux/README.md) | 웹 UI/UX 예시와 기준 |

## 3. 기록 문서

기록은 **특정 시점**의 문제·후보·작업·결정을 남긴다. 덮어쓰지 않고, 지우지 않는다.
어디에 쓸지는 [MANAGEMENT §2](MANAGEMENT.md#2-기록-문서-어디에-쓰나)가 정한다.

| 폴더 | 담는 것 | 안내 |
|---|---|---|
| [issue/](issue/README.md) | 증상·재현·원인, 감사 결과 | [issue/README](issue/README.md) |
| [idea/](idea/README.md) | 실행 여부가 정해지지 않은 후보와 입력 원문 | [idea/README](idea/README.md) |
| [task/](task/README.md) | 하기로 정한 작업(`[task]`)과 계획(`[plan]`) | [task/README](task/README.md) |
| [decisions/](decisions/README.md) | 바꾸기 어려운 설계 결정(ADR) | [decisions/README](decisions/README.md) |
| [template/](template/) | issue·idea·task·plan·audit·feedback·failure 양식 | — |
