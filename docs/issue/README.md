---
Title: "Issue 기록 규약"
creation: 2026-07-01
modification: 2026-07-01
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "issue"
aliases:
 - "issue-log"
---
MOC:: [[Arachne]]
FROM:: [[arachne-docs]]

# Issue 기록

`docs/issue/`는 **문제의 증상, 재현 조건, 원인 분석, 영향 범위**를 남기는 곳이다.
실행하기로 결정한 수정 계획은 `docs/task/`로 옮기고, 아직 실행 여부가 정해지지 않은 개선 후보는
`docs/idea/`에 둔다.

## 언제 issue에 쓰나

| 상황 | 기록 위치 |
| --- | --- |
| 실제 버그, 문서 드리프트, 보안 위험, 플랫폼 불일치를 발견했다 | `issue/` |
| 해결할 작업 범위와 담당이 정해졌다 | `task/` |
| 아직 실행 여부를 판단 중인 제안이다 | `idea/` |
| 장기 설계 결정으로 보존해야 한다 | `decisions/` |

## 작성 기준

- 파일명은 `YYYY-MM-DD-<짧은-kebab-case-문제명>.md`로 쓴다.
- 증상과 재현 조건을 먼저 적고, 추정과 확인된 사실을 구분한다.
- 해결 작업이 생기면 관련 task를 링크한다.
- 닫힌 문제라도 삭제하지 않고 결과와 검증 근거를 남긴다.

## 현재 묶음

| 묶음 | 포함 내용 |
| --- | --- |
| `workflow-*` | 위임, 설치, 라우팅, git guardrail 등 워크플로 세부 결함 |
| `postmerge-*` | 병합 후 발견된 후속 점검 항목 |
| `*-audit`, `*-evaluation` | 문서, 아키텍처, 역량 평가 결과 |
| `data-handling-*` | 데이터 취급과 보안 경계 관련 gap |
| `macos-*`, `windows-*` | 플랫폼별 동작 차이와 검증 이슈 |

## 현재 인벤토리 (2026-07-01)

현재 `docs/issue/`에는 README를 제외하고 24개 issue/audit 기록이 있다.

| 상태 | 개수 | 의미 |
| --- | ---: | --- |
| `done` | 23 | 해결됐거나 감사 스냅샷으로 종료된 기록 |
| `in progress` | 1 | 연결 task의 열린 체크박스가 남아 있는 기록 |
| `to do` | 0 | 조사 또는 재현을 아직 시작하지 않은 기록 없음 |

### 열린 issue

| 심각도 | 상태 | 문서 | 연결 task |
| --- | --- | --- | --- |
| high | `in progress` | [보강 후보 대비 DB·JSON 데이터 처리 격차](2026-06-09-data-handling-gap.md) | [DB·JSON 데이터 처리 하드닝](../task/2026-06-09-data-handling-hardening.md) |

닫힌 issue라도 삭제하지 않는다. 해결 근거, 관련 task, 검증 결과가 이후 회귀 분석의 기준점이다.
