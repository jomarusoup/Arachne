---
Title: "[bug] 세션 저장·복원 경로가 분리되어 인계가 끊김"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/high"
aliases:
 - "session-path-split"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] 세션 저장·복원 경로가 분리되어 인계가 끊김

- **작성일**: 2026-06-07
- **심각도**: HIGH
- **영역**: `commands/save-session.md`, `hooks/pre-compact.sh`, `hooks/session-start.sh`, `hooks/session-end.sh`
- **상태**: 해결됨 — 62f552b (save-session 경로를 훅과 동일한 ~/.claude/sessions 절대경로로 일치). task [[2026-06-07-claude-state-and-session]]

## 문제

세션 파일 위치가 두 체계로 나뉜다.

| 생산자/소비자 | 경로 |
| --- | --- |
| `/save-session` | `<project>/.claude/sessions/` |
| PreCompact | `<project>/.claude/sessions/` |
| SessionStart | `~/.claude/sessions/` |
| Stop | `~/.claude/sessions/` |

프로젝트에 수동 세션 파일이 있어도 SessionStart는 이를 찾지 못한다. Stop 훅도 수동 저장을
인식하지 못하고 전역 경로에 별도 auto 세션을 생성한다.

## 재현 결과

- 프로젝트: `.claude/sessions/2026-06-07-demo.md` 존재
- SessionStart 출력: 없음
- SessionEnd 출력: `/save-session 미실행`
- 생성 위치: `~/.claude/sessions/auto-...md`

## 영향

- 다음 세션이 가장 관련 있는 프로젝트 인계 문서를 자동 발견하지 못한다.
- 프로젝트가 다른데도 전역 최신 세션을 안내할 수 있다.
- 수동 저장과 자동 저장이 서로 다른 위치에 중복된다.
- 여러 저장소의 세션 파일이 전역 디렉터리에서 충돌하거나 혼동된다.

## 원인

세션 상태의 소유 단위가 “사용자 전역”인지 “프로젝트”인지 결정되지 않았다.

## 수정 방향

권장안은 프로젝트 로컬을 정본으로 통일하는 것이다.

1. Git 저장소면 `<repo>/.claude/sessions` 사용
2. Git 저장소가 아니면 `~/.claude/sessions/<cwd-hash>` fallback
3. 모든 훅과 명령이 하나의 `ResolveSessionDir` 함수를 공유
4. SessionStart는 현재 프로젝트 세션만 안내
5. 수동 저장 존재 판정은 파일명 추측 대신 metadata 또는 명확한 prefix 사용
6. 동시 실행을 고려해 초 단위 timestamp나 session ID 사용

## 회귀 테스트

- 프로젝트 수동 세션을 시작 훅이 안내
- 수동 저장 후 Stop 훅이 auto 파일을 만들지 않음
- 프로젝트 A 세션이 프로젝트 B에 노출되지 않음
- Git 외부 디렉터리 fallback 동작
- 동일 분 내 두 저장이 서로 덮어쓰지 않음

## 완료 조건

- 생산자와 소비자가 동일한 세션 디렉터리를 사용한다.
- 현재 프로젝트의 최근 인계 파일을 안정적으로 찾는다.
- 수동·자동 저장 판정이 일관된다.
