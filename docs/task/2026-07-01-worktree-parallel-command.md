---
Title: "[task] Worktree parallel command"
creation: 2026-07-01
modification: 2026-07-01
status: "done"
tags:
 - "arachne"
 - "task"
 - "priority/medium"
 - "workflow"
aliases:
 - "worktree-parallel-command"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [task] Worktree parallel command

- **상태**: done
- **우선순위**: medium
- **담당**: Codex
- **관련 문서**: [git workflow](../../rules/common/git-workflow.md)

## 목표

병렬 작업 시 사람이 직접 worktree 명령을 기억해야 하는 부분을 줄이고, 세션별 폴더·브랜치 분리와 커밋 전 혼입 점검을 하네스 명령으로 표준화한다.

## 범위

- 포함:
  - `/worktree` 커맨드 추가
  - `/git` 커맨드의 worktree 확인 가드 보강
  - 사용 문서와 doc-contract 테스트 갱신
- 제외:
  - 실제 worktree를 자동 생성하는 별도 실행 바이너리 구현
  - 기존 미커밋 변경인 `docs/tools/understand-anything.md` 수정

## 작업 목록

- [x] `/worktree` 커맨드를 추가한다.
- [x] `/git` 커맨드에 worktree 혼입 점검을 추가한다.
- [x] 인덱스와 테스트를 갱신한다.
- [x] 관련 검증을 실행한다.

## 검증

```bash
bats tests/git_command.bats
bash tests/check_index.sh
git diff --check
```

기대 결과: 새 worktree 커맨드와 git 가드 계약이 테스트에서 확인되고 공백 오류가 없다.

## 완료 조건

- 병렬 작업 시작 시 사용할 표준 명령이 문서화된다.
- 커밋 전 `/git` 절차가 worktree 상태와 다른 세션 변경 혼입을 함께 확인한다.
- 검증 결과가 task 진행 기록에 남는다.

## 진행 기록

### 2026-07-01

- task 생성: 병렬 작업의 수동 worktree 준비 절차를 하네스 커맨드로 보강하기로 했다.
- 구현: `commands/worktree.md`를 추가해 `create`, `status`, `cleanup` 절차와 dirty 작업트리·기존 경로·push/PR 반영 가드를 문서화했다.
- 구현: `commands/git.md`의 커밋 전 변경 소유권 점검에 `git worktree list`, `rev-parse --show-toplevel`, `/worktree status` 확인을 추가했다.
- 문서: `CLAUDE.md`, `README.md`, `docs/USAGE.md`, `rules/common/git-workflow.md`에 `/worktree` 진입점을 연결했다.
- 테스트: `tests/worktree_command.bats`를 추가하고 `tests/git_command.bats`에 worktree 상태 확인 계약을 추가했다.
- 검증: `bats ../tests/git_command.bats ../tests/worktree_command.bats` 통과.
- 검증: `bash ../tests/check_index.sh` 통과.
- 검증: `git diff --check` 통과.
