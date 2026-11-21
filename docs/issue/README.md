---
Title: "Issue 기록 규약"
creation: 2026-07-01
modification: 2026-11-21
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
결함의 원인이나 감사 결과를 확인하려는 사람과 회귀를 분석하는 사람이 읽는다.

## 어디에 쓰나

> 어느 폴더에 쓸지, 수명주기·삭제 규칙은 [관리 규칙 §2·§5](../MANAGEMENT.md#2-기록-문서-어디에-쓰나)가 정본이다.
> 이 README는 이 폴더 고유의 작성 기준과 인덱스만 담는다.

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
| `*-audit`, `*-evaluation` | 문서, 아키텍처, 역량, 최신성 감사 결과 |
| `CHANGELOG-AUDIT.md` | 감사에서 승인 없이 고친 항목의 누적 기록(A-번호) |
| `data-handling-*` | 데이터 취급과 보안 경계 관련 gap |
| `macos-*`, `windows-*` | 플랫폼별 동작 차이와 검증 이슈 |
| `*-scan`, `*-result`, `*-verification` | 로드맵 실행 중 남긴 점검·실측·검증 결과 |
| `*-arachne-feedback` | 사용 프로젝트가 `arachne` 피드백 양식으로 남긴 보고(파일명에 시각 포함) |

## 현재 인벤토리 (2026-11-21)

현재 `docs/issue/`에는 README를 제외하고 37개 기록이 있다. 열린 issue는 4개(사용 프로젝트 피드백)다.

| 상태 | 개수 | 의미 |
| --- | ---: | --- |
| `done` | 29 | 해결됐거나 감사 스냅샷으로 종료된 기록 |
| frontmatter 없음 | 2 | 루트에서 옮겨 온 감사 기록물(아래 표). 원문을 그대로 보존한다 |
| `draft` | 4 | 사용 프로젝트 피드백 초안(아래 열린 issue). 원문은 보존한다 |
| `in progress`·`to do` | 0 | 없음 |

### 2026-09 이후 추가된 기록

| 문서 | 내용 | 상태 |
| --- | --- | --- |
| [2026-09-13-arachne-audit](2026-09-13-arachne-audit.md) | Claude Code·Codex CLI·Gemini CLI 최신 스펙 대비 하네스 최신성 감사. 2026 Q4 로드맵의 입력이다 | 제안 기록(종료) |
| [CHANGELOG-AUDIT](CHANGELOG-AUDIT.md) | 아키텍처 감사 이후 승인 없이 고친 항목(A-01~)의 누적 기록 | 누적 기록 |
| [2026-10-05-history-secret-scan](2026-10-05-history-secret-scan.md) | git 이력 비밀값·개인정보 1회 점검. 실제 비밀값은 없었다 | `done` |
| [2026-10-05-throughput-poc-result](2026-10-05-throughput-poc-result.md) | TS(Node) 스트림 수신 처리량 실측(D-02 확인) | `done` |
| [2026-10-06-roadmap-verification](2026-10-06-roadmap-verification.md) | 2026 Q4 로드맵 통합 행동 검증(W5). 찾은 결함 2건은 같은 날 고쳤다 | `done` |
| [2026-10-06-harness-inventory](2026-10-06-harness-inventory.md) | 로드맵 W6 하네스 인벤토리. 정리 내역과 다음 감사 기준선을 담는다 | `done` |

두 감사 기록물은 ADR-0006 D-15에 따라 저장소 루트에서 이 폴더로 옮겼다. 기록이므로 본문은 고치지 않는다.

### 열린 issue

| 심각도 | 상태 | 문서 | 연결 task |
| --- | --- | --- | --- |
| medium | 처리 중 | [범위 밖 언어 사용 프로젝트 정책 공백](2026-11-21-155122-arachne-feedback.md) | [피드백 분류](../task/2026-11-21-project-feedback-triage.md) |
| low | 결정 대기 (D-18) | [CI profile이 혼합 구조에 맞지 않음](2026-11-21-155123-arachne-feedback.md) | [피드백 분류](../task/2026-11-21-project-feedback-triage.md) |
| low | 일부 반영 | [`-t --check`가 clang·rustfmt·clippy·프로젝트 요구 도구를 점검하지 못함](2026-11-21-155125-arachne-feedback.md) | [피드백 분류](../task/2026-11-21-project-feedback-triage.md) |
| medium | 결정·수확 대기 (D-14·D-17) | [C 서버·Rust+egui 클라이언트 스킬·리뷰어 공백](2026-11-21-155126-arachne-feedback.md) | [피드백 분류](../task/2026-11-21-project-feedback-triage.md) |

닫힌 issue라도 삭제하지 않는다. 해결 근거, 관련 task, 검증 결과가 이후 회귀 분석의 기준점이다.
