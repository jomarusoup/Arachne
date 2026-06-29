---
Title: "[task] /git 커맨드 가드레일 — 브랜치·검증·변경 소유권"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
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

- **상태**: done
- **우선순위**: medium
- **담당**: Claude (Opus)
- **관련 문서**: #27, [[2026-06-07-workflow-02-git-command-guardrails]]

## 목표

`/git`(Haiku 위임)이 무분별하게 커밋·푸시하지 않도록 브랜치 확인, 변경 소유권(다른 세션 변경 혼입
방지), 검증 선행 가드를 추가한다.

## 범위

- 포함: `commands/git.md`, 필요 시 보조 훅/스크립트
- 제외: 실제 CI 검증 로직(이미 존재)

## 작업 목록

- [x] 브랜치 가드: 의도치 않은 브랜치면 중단·보고, main 직접 푸시는 진행하되 feat 브랜치 권장 명시(§2)
- [x] 변경 소유권 점검: `git add -A` 전 무관한(병렬 세션) 변경 혼입 차단·선택 스테이징(§1)
- [x] 검증 선행: `*.sh`→shellcheck·`bash -n`, `git diff --check`, 실패 시 커밋 중단(§3)
- [x] non-fast-forward 푸시 가드 추가(병렬 세션 대비): `pull --no-rebase` 재시도, 충돌 시 임의해결 금지(§6)
- [x] 커맨드 문서 갱신(`commands/git.md` 절차 재구성) + doc-contract 테스트 `tests/git_command.bats` 5건

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

### 2026-06-08

- 구현 (`commands/git.md` Haiku 위임 절차에 4가지 가드 추가 + 신규 `tests/git_command.bats`).
- 검증: `shellcheck` 통과, `bats tests/*.bats` **100개 전부 green**(신규 5), `check_index.sh` 통과.
- 커밋: **4bafe62** (`feat: /git 커맨드 가드레일 — 소유권·브랜치·검증·non-ff 푸시 (#27)`), push 완료.
- 설계 메모: `/git`은 마크다운 위임 커맨드라 단위 테스트 불가 → **doc-contract 테스트**(가드 키워드 존재 검사)로
  절차에서 가드가 빠지는 회귀를 차단. 이번 세션에서 실제 겪은 non-ff 충돌도 §6 가드로 반영.
- 상태 → **done**. GitHub #27 close 예정.
