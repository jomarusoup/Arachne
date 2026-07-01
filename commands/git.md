---
description: git 커밋·푸시. GitHub MCP 연결 시 Claude Code 안에서 바로 실행.
---

# /git $ARGUMENTS

**이 스킬은 Haiku 에이전트에 위임한다.**

아래 프롬프트로 `Agent(model: "haiku")` 를 즉시 호출한다. 추가 판단 없이 호출만 하면 된다.

---

## Haiku 에이전트에 전달할 프롬프트

```
다음 순서로 git 커밋·푸시를 실행해라. 각 가드에서 문제가 보이면 커밋하지 말고 보고한다.

커밋 메시지 인수: "$ARGUMENTS"

### 1. 변경 확인 + 변경 소유권 점검 (가드)
```bash
git status --short
git diff --stat
git branch --show-current
git worktree list
git rev-parse --show-toplevel
```
- status에 **이번 작업과 무관한 변경**(다른 세션·도구가 남긴 파일)이 섞여 있으면, `git add -A` 대신
  이번 작업 파일만 선택 스테이징한다. 무관한 파일은 결과 보고에 적는다(남의 작업 혼입 금지).
- 현재 폴더가 의도한 worktree인지 확인한다. 병렬 작업 중인데 같은 폴더에서 작업 중이면 커밋하지 말고
  `/worktree status` 결과와 함께 중단·보고한다.
- 다른 worktree에 같은 파일 변경이 진행 중이면 머지 충돌 가능성을 보고하고, 이번 커밋에는 현재 작업 파일만
  선택 스테이징한다.

### 2. 브랜치 가드
- 현재 브랜치가 의도한 브랜치인지 확인. **의도치 않은 브랜치면 중단·보고**한다.
- 기본 브랜치(main) 직접 푸시는 그대로 진행하되, 대규모·실험 변경은 feat 브랜치 권장
  (`rules/common/git-workflow.md`).

### 3. 검증 선행 (커밋 전 가드)
- `.arachne/verify.sh`가 있으면 가장 먼저 `arachne project-check`를 실행한다.
  - 이 명령은 GitHub Actions의 `bash .arachne/verify.sh`와 동일한 프로젝트 검증 계약이다.
  - 실패하면 이후 커밋·푸시를 중단하고 실패한 `.arachne/commands` 항목을 보고한다.
- 변경에 `*.sh` 포함 시: `shellcheck -S warning <파일>` 와 `bash -n <파일>`.
- 테스트·스크립트 영향 시: `bats tests/*.bats`(또는 관련 파일만).
- 공통: `git diff --check`(공백 오류·충돌 마커). **검증 실패면 커밋하지 말고 보고**한다.

### 4. 커밋 메시지 결정
인수가 있으면 그것을 사용.
없으면 변경사항 분석 후 아래 형식으로 결정:

  feat     새 기능
  fix      버그 수정
  style    UI·CSS 변경
  refactor 코드 구조 개선
  docs     문서 수정
  chore    설정 변경

예) fix: 널 포인터 역참조 수정

### 5. README.md 동기화 (생략)
README.md 업데이트는 Gemini CLI가 담당한다. 이 단계에서는 README.md를 직접 수정하지 않는다.

### 6. 커밋 & 푸시
```bash
git add -A          # 단, 1단계에서 무관한 변경이 있으면 해당 파일만: git add <이번 작업 파일들>
git commit -m "[커밋 메시지]"
git push
```
- `git push`가 **non-fast-forward**로 거부되면(병렬 세션이 origin을 진전시킨 경우):
  `git pull --no-rebase` 후 다시 push. **머지 충돌이 나면 임의로 해결하지 말고 중단·보고**한다.

### 7. 결과 보고
커밋 해시·푸시 결과·스테이징한 파일 목록을 한 줄로 보고.
```
