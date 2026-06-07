---
Title: "[task] .claude 상태 파일 안정화 — 세션 인계·git-bus 기준점"
creation: 2026-06-07
modification: 2026-06-07
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

- **상태**: planned
- **우선순위**: medium
- **담당**: unassigned
- **관련 문서**: #29 #30

## 목표

세션 저장·복원 경로 불일치(인계 끊김)와 git-bus 기준점 파일이 `.claude` 부재 시 저장되지 않는
문제를 해결해, 세션 인계와 외부 커밋 감지가 끊기지 않게 한다.

## 범위

- 포함: `hooks/session-start.sh`, `hooks/session-end.sh`, `hooks/git-bus-check.sh`, 세션 경로 규약
- 제외: 세션 요약 내용 형식

## 작업 목록

- [ ] #29: 세션 저장 경로와 복원(안내) 경로를 일치시켜 인계가 이어지게 수정
- [ ] #30: git-bus 기준점 기록 전 `.claude` 디렉터리 보장(`mkdir -p`)으로 최초 실행 누락 방지
- [ ] 회귀 테스트: `.claude` 부재 상태에서 git-bus 기준점이 기록되는지, 세션 경로 왕복 검증
- [ ] `shellcheck` + `bats tests/hooks.bats` 통과

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
