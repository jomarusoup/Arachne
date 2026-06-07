---
Title: "[task] /git 커맨드 가드레일 — 브랜치·검증·변경 소유권"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "project"
 - "task"
 - "priority/medium"
aliases:
 - "git-command-guardrails"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-02-git-command-guardrails]]

# [task] /git 커맨드 가드레일

- **상태**: planned
- **우선순위**: medium
- **담당**: unassigned
- **관련 문서**: #27, [[2026-06-07-workflow-02-git-command-guardrails]]

## 목표

`/git`(Haiku 위임)이 무분별하게 커밋·푸시하지 않도록 브랜치 확인, 변경 소유권(다른 세션 변경 혼입
방지), 검증 선행 가드를 추가한다.

## 범위

- 포함: `commands/git.md`, 필요 시 보조 훅/스크립트
- 제외: 실제 CI 검증 로직(이미 존재)

## 작업 목록

- [ ] 기본 브랜치 직접 푸시 가드(비-main 또는 확인) 절차 명문화
- [ ] 커밋 전 `git status`로 의도치 않은 외부 변경(병렬 세션) 혼입 점검 단계 추가
- [ ] `/verify` 또는 최소 정적 검사 선행을 커맨드 절차에 명시
- [ ] 커맨드 문서 갱신 + 예시
- [ ] 동작 확인(시뮬레이션 커밋으로 가드 발동 확인)

## 검증

```bash
# dirty 트리·비-main 상태에서 /git 절차가 경고/중단하는지 수동 확인
git status --short
```

가드 조건에서 무인 커밋·푸시가 발생하지 않는다.

## 완료 조건

- `commands/git.md`에 브랜치·소유권·검증 가드가 절차로 포함된다.

## 진행 기록

### 2026-06-07

- task 생성: 이번 세션의 병렬 브랜치 혼선이 정확히 이 가드 부재와 맞닿아 우선 기록.
