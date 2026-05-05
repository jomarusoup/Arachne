# GitHub 이슈 처리 워크플로

## 이슈 제목 형식

| 타입 | 의미 |
|---|---|
| `[bug]` | 기존 동작 오작동 |
| `[feat]` | 신규 기능 추가 |
| `[remove]` | 기능/필드 제거 |
| `[refactor]` | 동작 변화 없는 코드 정리 |

## 섹션 → grep 키워드 매핑

이슈 본문 섹션명을 grep 키워드로 변환해 위치를 먼저 파악한다:

| 섹션 | 파일 | grep 키워드 |
|---|---|---|
| 모달 | `src/js/modal.js` | `MODAL`, `openModal`, `populateModalDropdowns` |
| 업무대장 | `src/js/ledger.js` | `LEDGER`, `renderLedger` |
| 캘린더 | `src/js/calendar.js` | `CALENDAR`, `renderCalendar`, `_renderEventBars` |
| 칸반 | `src/js/kanban.js` | `KANBAN`, `renderKanban` |
| 연락처 | `src/js/contacts.js` | `CONTACTS`, `renderContacts` |
| 월간업무 | `src/js/calendar.js` | `RECURRING`, `renderRecurring` |
| 연간업무 | `src/js/calendar.js` | `ANNUAL`, `renderAnnual` |
| 설정 | `src/js/ui.js` | `SETTINGS`, `renderSettings` |
| 공통 | `src/js/core.js` | `CORE`, `accentColor`, `priInfo`, `statusInfo` |

## [feat] 처리 규칙

1. planner 에이전트로 설계 먼저
2. 데이터 구조 변경 시 `load()` 마이그레이션 처리 필수
3. localStorage 키 버전 변경 여부 판단

## [remove] 처리 규칙

1. localStorage 키 영향 여부 먼저 확인
2. `tasks[]` / `contacts[]` / `recurringTasks[]` 필드 변경 시 마이그레이션 필요

## 이슈 처리 순서

`/issue` 커맨드로 최신 목록 확인 후 처리.
