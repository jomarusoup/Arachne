---
Title: "Task 작성 규약"
creation: 2026-06-07
modification: 2026-10-06
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "task"
aliases:
 - "task-writing-rules"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# Task 작성 규약

`docs/task/`는 Arachne 저장소에서 **실행하기로 정한 작업과 그 진행 상태**를 기록하는 곳이다.
작업을 시작하거나 이어받는 사람과 에이전트는 먼저 아래 [task 인덱스](#task-인덱스)에서 같은 범위의
열린 task가 있는지 확인한다. 이 저장소에서는 여러 task를 묶는 `[plan]` 문서도 이 폴더에 함께 둔다.

이 README는 Arachne 저장소 전용 규약이다. `arachne -n`으로 만든 프로젝트는 일반 규약인
[task README 양식](../template/task-README.md)을 받는다. 그 양식은 기획 정본으로 `docs/plan/PLAN.md`를 쓴다.

## 문서 위치

이 저장소는 문서를 성격에 따라 다섯 종류로 나누고, 네 폴더에 둔다. 기획과 task는 같은 `docs/task/`에 둔다.

| 성격 | 위치 |
| --- | --- |
| 여러 task를 묶는 기획·로드맵(`[plan]`)과 입력 시트(`[input]`) | `docs/task/` |
| 실행하기로 정한 작업(`[task]`) | `docs/task/` |
| 문제의 증상·재현·원인 분석, 감사 기록 | `docs/issue/` |
| 실행 여부가 정해지지 않은 후보와 입력 원문 | `docs/idea/` |
| 바꾸기 어려운 설계 결정(ADR) | `docs/decisions/` |

이 저장소에는 `docs/plan/` 폴더가 없다. `[plan]` 문서는 `docs/task/`에 평면으로 두고,
제목 접두어 `[plan]`과 태그 `plan`으로 task와 구분한다(ADR-0006 D-15).

하네스가 만들어 주는 사용 프로젝트는 구조가 다르다. `arachne -n`으로 만든 프로젝트에는
`lib/project-ci.sh`가 `docs/plan/PLAN.md`를 전체 기획 정본으로 만든다. 그 프로젝트에서는
`docs/plan/`이 기획을, `docs/task/`가 개별 작업을 맡는다.

## 수명주기

1. 기획이나 감사가 작업 후보를 만든다.
2. 실행 여부가 정해지지 않은 후보는 `docs/idea/`에 둔다.
3. 실행하기로 정한 작업은 `docs/task/`에 task로 만들고 `FROM::`에 출처 문서를 링크한다.
4. task 단위로 브랜치나 worktree를 분기해 구현한다.
5. 검증을 마치면 task 상태를 `done`으로 바꾸고 진행 기록에 커밋이나 PR을 남긴다.

`[plan]` 문서는 살아있는 정본 1개로 유지한다. 버전별 사본은 만들지 않고 git 이력을 버전으로 쓴다.
여러 세션이 동시에 작업할 때는 `[plan]` 문서를 고치지 않고 읽기만 한다. 계획을 바꿀 일이 생기면 한 세션만 고친다.

## 생성 기준

- 구현·수정·문서화·조사 같은 후속 행동이 합의되면 task를 만든다.
- 단순 메모나 구현 여부가 정해지지 않은 제안은 `docs/idea/`에 둔다.
- 여러 task에 걸친 목표·범위·순서는 개별 task가 아니라 `[plan]` 문서에서 관리한다.
- 결함의 증상·재현·원인 추적은 `docs/issue/`에 남기고 task에서 해당 issue를 링크한다.
- 여러 issue를 하나의 변경으로 처리할 수 있으면 task 하나에서 의존 관계와 범위를 명시한다.

## 파일명

```text
YYYY-MM-DD-<짧은-kebab-case-작업명>.md
```

- 날짜는 task를 처음 만든 날짜다.
- 작업명은 결과물이 드러나게 쓴다.
- 같은 작업의 진행 기록은 새 파일로 나누지 않고 기존 task를 갱신한다.

## 필수 항목

모든 task는 [task 템플릿](../template/task.md)을 사용하고 다음 내용을 포함한다.

| 항목 | 규칙 |
| --- | --- |
| 상태 | `to do`, `in progress`, `done` 중 하나 |
| 우선순위 | `critical`, `high`, `medium`, `low` 중 하나 |
| 담당 | 실행 주체 또는 `unassigned` |
| 관련 문서 | issue, audit, 설계 문서 링크 |
| 목표 | 완료 후 달라지는 동작을 한 문단으로 기술 |
| 범위 | 수정 대상과 제외 대상을 구분 |
| 작업 목록 | 검증 가능한 단위의 체크박스 |
| 검증 | 실행할 명령과 기대 결과 |
| 완료 조건 | 제3자가 판정할 수 있는 종료 조건 |
| 진행 기록 | 날짜별 결정·실행·실패·차단 사유 |

본문의 `- **상태**:` 줄은 frontmatter `status:`와 같은 값으로 시작한다. 덧붙일 설명이 있으면
값 뒤에 ` — `를 두고 이어 쓴다(예: `- **상태**: done — 측정 대상이 사라져 조기 종결`).
`[plan]`·`[input]` 문서에도 이 줄을 둔다.

## 상태 전이

```text
to do -> in progress -> done
```

- 착수할 때 `in progress`로 바꾸고 담당을 기록한다.
- 외부 입력이나 선행 작업 없이 진행할 수 없으면 상태를 `to do`로 두고 진행 기록에 차단 조건을 적는다.
- 코드·문서 변경과 검증이 모두 끝난 뒤에만 `done`으로 바꾼다.
- 범위가 불필요해지면 별도 취소 상태를 만들지 않는다. 진행 기록에 그 결정과 근거를 남기고,
  남은 범위가 없으면 `done`으로 닫는다(예: `2026-08-25-metrics-baseline.md`의 조기 종결).

## 작업 목록 작성법

- 한 항목에는 검증 가능한 결과 하나만 넣는다.
- "확인", "처리"처럼 끝났는지 판정하기 어려운 표현 대신 대상과 기대 결과를 쓴다.
- 구현 항목과 검증 항목을 분리한다.
- 새로 발견한 작업이 현재 목표에 필수면 같은 task에 추가하고, 독립적이면 새 task로 분리한다.
- 완료한 항목만 `[x]`로 바꾸고, 실행하지 않은 항목을 완료로 표시하지 않는다.

## task 인덱스

아래 표는 2026-10-06 시점의 스냅샷이다. 로드맵 웨이브를 닫을 때마다 갱신한다.
표와 문서가 다르면 각 문서의 frontmatter `status:`가 정본이다. 완료된 task의 상세 근거는
각 문서의 진행 기록과 검증 결과에 있다.

### 열린 문서

| 우선순위 | 상태 | 문서 | 남은 범위 |
| --- | --- | --- | --- |
| — | `in progress` | [Arachne 보강 로드맵 2026 Q4 (plan)](2026-10-05-arachne-roadmap.md) | W7의 새 세션 스모크만 남았다 |
| — | `in progress` | [프로그래밍 철학 하네스 이식 (plan)](2026-09-29-programming-philosophy-integration.md) | 실행은 로드맵 웨이브를 따르며, W7이 끝나면 닫는다 |
| medium | `in progress` | [로드맵 W7 최종 검증](2026-10-05-roadmap-w7.md) | 자동 검사는 끝났고, 새 세션에서 스모크 4항목을 확인하면 닫는다 |
| — | `to do` | [로드맵 착수 전 입력 시트 (input)](2026-10-05-roadmap-input-sheet.md) | 결정은 반영을 마쳤고, §3의 8-1(이전 초안 4개 삭제·보관)만 사용자 결정으로 남았다 |
| high | `to do` | [현행 결함 수리](2026-08-25-pc-defect-repair.md) | 새 커밋 알림 훅(git-bus)이 업스트림 없는 브랜치와 rebase 뒤에 조용히 넘어가는 문제를 고친다. 세션 종료 스냅샷이 git 저장소 밖에서 서로 덮어쓰는 문제도 고친다 |
| medium | `to do` | [훅의 서브에이전트 발화 실험](2026-08-25-hook-subagent-experiment.md) | 서브에이전트의 도구 호출에도 PreToolUse·PostToolUse 훅이 실행되는지 실험 1회로 확인한다. 런타임 감사에서 추정으로 남은 판단을 확정한다 |
| medium | `to do` | [아키텍처 감사 후속](2026-06-11-audit-followup.md) | uninstall과 복구 가이드, 릴리스 정책, 훅 로그, 언어별 자산을 묶음 단위로 분리하는 일이 남았다. 모두 착수 조건이 생기기를 기다린다 |

새 작업을 시작할 때 위 열린 문서와 범위가 겹치면 새 파일을 만들지 않고 기존 문서를 갱신한다.

### 전체 목록

| 날짜 | 상태 | 문서 |
| --- | --- | --- |
| 2026-06-07 | `done` | [atask 정확성 하드닝](2026-06-07-atask-correctness-hardening.md) |
| 2026-06-07 | `done` | [.claude 상태 파일 안정화](2026-06-07-claude-state-and-session.md) |
| 2026-06-07 | `done` | [하네스 역할·플랫폼 설명 정확화 검증](2026-06-07-docs-accuracy-verify-close.md) |
| 2026-06-07 | `done` | [기능 문서화 커버리지 보강](2026-06-07-documentation-coverage-hardening.md) |
| 2026-06-07 | `done` | [드리프트 검출 강화](2026-06-07-drift-detection-content-sync.md) |
| 2026-06-07 | `done` | [/git 커맨드 가드레일](2026-06-07-git-command-guardrails.md) |
| 2026-06-07 | `done` | [설치·업데이트 안전성](2026-06-07-install-update-safety.md) |
| 2026-06-07 | `done` | [사용 프로젝트 피드백 경로](2026-06-07-project-feedback-channel.md) |
| 2026-06-07 | `done` | [Windows Copilot 통합](2026-06-07-windows-copilot-integration.md) |
| 2026-06-07 | `done` | [Windows 런타임 검증](2026-06-07-windows-runtime-verification.md) |
| 2026-06-07 | `done` | [위임 래퍼 입력 경계](2026-06-07-wrapper-injection-defense.md) |
| 2026-06-08 | `done` | [CI 플랫폼 분기](2026-06-08-ci-platform-split.md) |
| 2026-06-08 | `done` | [main CI와 문서 드리프트 검수](2026-06-08-main-ci-docs-audit.md) |
| 2026-06-09 | `done` | [DB·JSON 데이터 처리 하드닝](2026-06-09-data-handling-hardening.md) |
| 2026-06-09 | `done` | [macOS sed CI 호환성](2026-06-09-macos-sed-ci-fix.md) |
| 2026-06-09 | `done` | [사용 프로젝트 CI 스캐폴딩](2026-06-09-project-ci-scaffold.md) |
| 2026-06-09 | `done` | [사용 프로젝트 디자인 문서 계약](2026-06-09-project-design-docs-contract.md) |
| 2026-06-09 | `done` | [Python·Web profile 기반](2026-06-09-python-web-profile-foundation.md) |
| 2026-06-11 | `to do` | [아키텍처 감사 후속](2026-06-11-audit-followup.md) |
| 2026-06-20 | `done` | [역량 보강과 학습 가이드](2026-06-20-capability-port.md) |
| 2026-07-01 | `done` | [docs 구조 분리](2026-07-01-docs-structure-separation.md) |
| 2026-07-01 | `done` | [Understand-Anything 설치 연동](2026-07-01-understand-anything-install-workflow.md) |
| 2026-07-01 | `done` | [worktree 병렬 커맨드](2026-07-01-worktree-parallel-command.md) |
| 2026-08-25 | `to do` | [훅의 서브에이전트 발화 실험](2026-08-25-hook-subagent-experiment.md) |
| 2026-08-25 | `done` | [계측 기준선 (조기 종결)](2026-08-25-metrics-baseline.md) |
| 2026-08-25 | `to do` | [현행 결함 수리](2026-08-25-pc-defect-repair.md) |
| 2026-09-29 | `done` | [철학 이식 착수 프롬프트 (참고 자료)](2026-09-29-philosophy-kickoff-prompts.md) |
| 2026-09-29 | `in progress` | [프로그래밍 철학 하네스 이식 (plan)](2026-09-29-programming-philosophy-integration.md) |
| 2026-10-05 | `in progress` | [Arachne 보강 로드맵 2026 Q4 (plan)](2026-10-05-arachne-roadmap.md) |
| 2026-10-05 | `to do` | [로드맵 착수 전 입력 시트 (input)](2026-10-05-roadmap-input-sheet.md) |
| 2026-10-05 | `done` | [로드맵 W1 보안 강제와 기반 정비](2026-10-05-roadmap-w1.md) |
| 2026-10-05 | `done` | [로드맵 W2 C·임베디드 SQL 기반](2026-10-05-roadmap-w2.md) |
| 2026-10-05 | `done` | [로드맵 W3 데이터 계층과 대용량 처리](2026-10-05-roadmap-w3.md) |
| 2026-10-05 | `done` | [로드맵 W4 운영 도구·클라이언트·리뷰](2026-10-05-roadmap-w4.md) |
| 2026-10-05 | `done` | [로드맵 W5 통합 행동 검증](2026-10-05-roadmap-w5.md) |
| 2026-10-05 | `done` | [로드맵 W6 최종 정리](2026-10-05-roadmap-w6.md) |
| 2026-10-05 | `in progress` | [로드맵 W7 최종 검증](2026-10-05-roadmap-w7.md) |

`docs/task/20261005/`는 로드맵에 통합된 이전 초안 4개를 임시로 두는 폴더다. 이 초안의 삭제나 보관은
[입력 시트](2026-10-05-roadmap-input-sheet.md) §3의 8-1 항목에서 정한다. 그때까지 이 폴더는 인덱스 대상에서 뺀다.
철학 이식 착수 프롬프트는 참고 자료로만 남아 있다. 실행 순서는 로드맵 웨이브가 대체했다.

## 진행 기록 원칙

- 중요한 설계 결정, 실패한 검증, 범위 변경, 차단 사유를 날짜와 함께 기록한다.
- 명령을 실행했다면 명령과 실제 결과를 요약한다.
- task를 완료하면 최종 검증 결과와 관련 커밋 또는 PR을 기록한다.
- task 문서는 현재 상태를 나타낸다. 과거 기록을 지워 상태를 좋게 보이게 하지 않는다.
