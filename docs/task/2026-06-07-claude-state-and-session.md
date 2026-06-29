---
Title: "[task] .claude 상태 파일 안정화 — 세션 인계·git-bus 기준점"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
tags:
 - "project"
 - "task"
 - "priority/medium"
aliases:
 - "claude-state-and-session"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [task] .claude 상태 파일 안정화

- **상태**: done
- **우선순위**: medium
- **담당**: Claude (Opus)
- **관련 문서**: #29 #30

## 목표

세션 저장·복원 경로 불일치(인계 끊김)와 git-bus 기준점 파일이 `.claude` 부재 시 저장되지 않는
문제를 해결해, 세션 인계와 외부 커밋 감지가 끊기지 않게 한다.

## 범위

- 포함: `hooks/session-start.sh`, `hooks/session-end.sh`, `hooks/git-bus-check.sh`, 세션 경로 규약
- 제외: 세션 요약 내용 형식

## 작업 목록

- [x] #29: 원인은 **경로 불일치** — `save-session`은 상대경로 `.claude/sessions/`, 훅은 `$HOME/.claude/sessions/`. save-session 커맨드를 홈 절대경로(`~/.claude/sessions/`)로 명시하고 경로 일치 주의 추가
- [x] #30: `session-end.sh`(`UpdateGeminiRef`)·`git-bus-check.sh`가 기준점 기록 전 `mkdir -p .claude` 보장(부재 시 조용한 실패 방지)
- [x] 회귀 테스트: 격리 temp 레포에서 `.claude` 부재 시 기준점 생성(git-bus·session-end), save↔훅 경로 일치 — `tests/hooks.bats` 3건
- [x] `shellcheck` + `bats`(91개 green) 통과

## 검증

```bash
bats tests/hooks.bats
# .claude 삭제 후 git-bus-check 실행 → 기준점 파일 생성 확인
```

세션 인계 경로가 일치하고, `.claude` 부재에서도 git-bus 기준점이 기록된다.

## 완료 조건

- #29·#30 회귀 테스트 green.

## 진행 기록

### 2026-06-07

- task 생성: 두 결함 모두 `.claude/` 상태 파일 수명주기 문제라 하나로 묶음.

### 2026-06-08

- 구현 (`commands/save-session.md`·`hooks/session-end.sh`·`hooks/git-bus-check.sh`·`tests/hooks.bats`).
- **#29 원인 규명**: 단순 네이밍이 아니라 **저장 경로 자체가 상대/절대로 갈렸던 것**. save-session이
  `./.claude/sessions/`(프로젝트·cwd)로 저장하면 훅이 읽는 `$HOME/.claude/sessions/`와 분리돼 인계가 끊김.
- 검증: `shellcheck` 통과, `bats tests/*.bats` **91개 전부 green**(신규 3), `check_index.sh` 통과.
- 커밋: **62f552b** (`fix: .claude 상태 파일 안정화 — 세션 인계·git-bus 기준점 (#29·#30)`), push 완료.
- 상태 → **done**. GitHub #29·#30 close 예정.
