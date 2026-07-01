---
description: 병렬 세션용 git worktree 생성·상태확인·정리 가드
---

# /worktree $ARGUMENTS

병렬 작업을 시작하거나 정리할 때 사용한다. 브랜치만 나누는 대신 **폴더까지 분리**해서
서로 다른 세션의 체크아웃과 미커밋 변경이 섞이지 않게 한다.

## 모드

| 모드 | 용도 | 예시 |
| --- | --- | --- |
| `create <task>` | 현재 `main` 기준으로 새 worktree와 브랜치 생성 | `/worktree create docs-cleanup` |
| `status` | 현재 저장소의 worktree와 dirty 상태 확인 | `/worktree status` |
| `cleanup <path>` | 머지·푸시가 끝난 worktree 제거 전 점검 | `/worktree cleanup ../Arachne-docs-cleanup` |

## create 절차

`$ARGUMENTS`가 비어 있거나 모드가 불명확하면 작업명을 물어보고 중단한다. 작업명은
짧은 kebab-case로 정한다.

```bash
git status --short
git branch --show-current
git worktree list
git fetch origin
git switch main
git pull --ff-only
git switch -c feat/<task>
git switch main
git worktree add ../Arachne-<task> feat/<task>
```

가드:
- 현재 작업트리에 미커밋 변경이 있으면 새 worktree를 만들지 말고 먼저 커밋·stash·별도 task 분리를 보고한다.
- `../Arachne-<task>`가 이미 있으면 덮어쓰지 않는다.
- `feat/<task>` 브랜치가 이미 있으면 새로 만들지 말고 기존 브랜치를 사용할지 확인한다.
- 생성 후 새 세션은 반드시 `../Arachne-<task>`에서 시작한다.

## status 절차

```bash
git worktree list
git status --short
git branch --show-current
git rev-parse --show-toplevel
```

확인:
- 현재 세션이 의도한 worktree 폴더에서 실행 중인지 확인한다.
- 다른 worktree의 dirty 파일은 커밋에 포함하지 않는다.
- 같은 파일을 여러 worktree에서 수정 중이면 PR 머지 충돌 가능성을 보고한다.

## cleanup 절차

```bash
git -C <path> status --short
git worktree list
git worktree remove <path>
git worktree prune
```

가드:
- `<path>`에 미커밋 변경이 있으면 제거하지 않는다.
- 브랜치가 아직 push되지 않았거나 PR에 반영되지 않았으면 제거하지 않는다.
- 제거 후 `git worktree list`로 남은 worktree를 보고한다.
