---
Title: "Arachne 관리 규칙 — 버전·계획·결정·기록·폐기·동결·브랜치"
creation: 2026-11-21
modification: 2026-11-21
status: "done"
tags:
 - "arachne"
 - "management"
aliases:
 - "management"
---
MOC:: [[Arachne]]
FROM:: [[objectives]]

# Arachne 관리 규칙

> **이 문서가 관리 규칙의 정본이다.** 목표·우선순위는 [OBJECTIVES](OBJECTIVES.md), 각 기록 폴더의
> 파일명·필수 항목 같은 세부는 폴더 README가 맡는다. 규칙마다 **강제 수단**을 적는다.
> "미강제"는 사람과 리뷰가 지키는 규칙이고, 같은 위반이 2회 이상 나오면 검사 추가 후보다
> ([OBJECTIVES §4](OBJECTIVES.md#4-운영-원칙) 수확 원칙).

## 0. 한눈에 보기

| 대상 | 핵심 규칙 | 정본 위치 | 강제 |
|---|---|---|---|
| [버전](#1-버전) | SemVer, 바꾸는 PR 안에서 `VERSION`을 올린다 | `VERSION` | 미강제 |
| [기록 분류](#2-기록-문서-어디에-쓰나) | 문제는 issue, 후보는 idea, 실행은 task, 결정은 ADR | 이 문서 §2 | 미강제 |
| [계획·작업](#3-계획과-작업) | plan은 살아있는 정본 1개, task는 `to do → in progress → done` | [task/README](task/README.md) | 미강제 (`check_index.sh`는 깨진 상대 링크만) |
| [결정](#4-결정-adr) | 덮어쓰지 않고 새 ADR로 대체(supersede) | [decisions/README](decisions/README.md) | 미강제 |
| [폐기](#5-폐기와-아카이브) | 지우지 말고 보관, 기록 문서는 삭제 금지 | 이 문서 §5 | 미강제 (아카이브가 동결 검사에 막히지 않는 것만 보장) |
| [동결](#6-동결-자산-추가) | 규칙·스킬·에이전트·커맨드 추가는 ADR로만 | [OBJECTIVES §5](OBJECTIVES.md#5-동결-2026-11-20부터) | `freeze.bats`·`check_freeze_adr.sh` |
| [브랜치·push](#7-브랜치커밋push) | worktree에서 작업, push는 사람 확인 후, main 자동 병합 금지 | `rules/common/git-workflow.md` | 미강제 (push 확인을 거는 훅은 없다) |
| [정본 문서](#8-정본-문서-갱신) | 소스·테스트가 우선, 인덱스·개수 표기는 실제와 일치 | 이 문서 §8 | `check_index.sh`·`docs_cli_contract.bats` |

## 1. 버전

**규칙**

- 버전 정본은 루트 `VERSION` 한 파일이다. 설치기와 `arachne -v`는 이 값만 읽는다(`install.sh` F-07).
- [SemVer](https://semver.org/lang/ko/) `MAJOR.MINOR.PATCH`를 따른다.

| 올리는 자리 | 언제 | 예 |
|---|---|---|
| MAJOR | 사용자가 손으로 대응해야 하는 깨짐 | 설치 경로·CLI 옵션·커맨드 제거나 이름 변경, `settings.template.json` 형식 변경 |
| MINOR | 기능 추가 또는 **하네스 동작 변경** | 규칙·커맨드·에이전트·훅·스킬의 추가·변경·아카이브, CLI 옵션 추가, CI 강제 검사 추가 |
| PATCH | 의도한 동작을 바꾸지 않는 결함 수정 | 설치 재실행 중복 제거, 검사 오탐 수정 |
| 올리지 않음 | 동작이 바뀌지 않는 변경 | `docs/` 기록·정본 문서, 테스트만 추가 |

**따라 하기**

1. 변경이 위 표의 어느 칸인지 정한다. 여러 칸이면 가장 높은 칸을 따른다.
2. 같은 PR 안에서 `VERSION`을 고치고, 그 커밋 제목 끝에 `(vX.Y.Z)`를 붙인다.
3. PR이 병합되면 사람이 병합 커밋에 태그를 단다.
   ```bash
   git tag -a vX.Y.Z <병합 커밋> -m "vX.Y.Z" && git push origin vX.Y.Z
   ```
4. 변경 이력은 별도 CHANGELOG 없이 git으로 본다: `git log --oneline --grep='(v[0-9]'`.

**강제**: 미강제. 태그는 v1.5.0부터 단다(그 전 버전은 태그 없음).

## 2. 기록 문서 어디에 쓰나

| 상황 | 위치 | 파일명 |
|---|---|---|
| 버그·드리프트·보안 위험을 발견했다 (증상·재현·원인) | `docs/issue/` | `YYYY-MM-DD-<문제>.md` |
| 개선 방향은 보이지만 범위·담당·검증이 정해지지 않았다 | `docs/idea/` | `YYYY-MM-DD-<아이디어>.md` |
| 하기로 정한 작업이다 | `docs/task/` (`[task]`) | `YYYY-MM-DD-<작업>.md` |
| 여러 task를 묶는 목표·순서다 | `docs/task/` (`[plan]`) | `YYYY-MM-DD-<계획>.md` |
| 나중에 바꾸기 어렵거나 여러 문서에 영향을 주는 결정이다 | `docs/decisions/` | `NNNN-<결정>.md` |
| 사용 프로젝트에서 반복된 실패를 남긴다 | 그 프로젝트 `docs/failures/` | [failure 양식](template/failure.md) |

- 모든 기록은 [`docs/template/`](template/) 양식에서 시작한다.
- 흐름은 **issue·idea → task → (필요하면) ADR**이다. 다음 문서의 `FROM::`에 출처를 링크한다.
- 새 기록을 만들면 해당 폴더 README 인덱스에 행을 추가한다(미강제).
- 입력 시트(`[input]`)는 `docs/task/`에, `[plan]`의 근거가 된 입력 원문은 `docs/idea/`에 둔다.

## 3. 계획과 작업

**규칙**

- `[plan]`은 **살아있는 정본 1개**다. 버전별 사본을 만들지 않고 git 이력을 버전으로 쓴다.
  여러 세션이 동시에 일할 때는 한 세션만 plan을 고친다.
- task 상태는 `to do → in progress → done` 셋뿐이다. 취소 상태는 없다 — 불필요해지면 진행 기록에
  근거를 남기고 `done`으로 닫는다.
- 코드·문서 변경과 검증이 모두 끝난 뒤에만 `done`으로 바꾼다. 실행하지 않은 항목을 `[x]`로 표시하지 않는다.
- task 하나 = 브랜치(또는 worktree) 하나. 완료하면 진행 기록에 검증 결과와 커밋·PR을 남긴다.

**따라 하기**

1. [task 양식](template/task.md)을 복사해 `docs/task/YYYY-MM-DD-<작업>.md`를 만든다.
2. 목표·범위·작업 목록·검증 명령·완료 조건을 채운다(필수 항목은 [task/README](task/README.md#필수-항목)).
3. 착수할 때 `in progress`, 끝나면 검증 결과를 적고 `done`.

**강제**: `check_index.sh`는 깨진 상대 `.md` 링크(파일 존재만, `#앵커`는 보지 않음)만 잡는다.
폴더 README 인덱스 누락과 필수 항목 누락은 미강제.

## 4. 결정 (ADR)

**규칙**

- 결정은 **덮어쓰지 않는다.** 바뀌면 새 ADR을 쓰고 대체 관계(supersede)를 표로 링크한다.
  기존 ADR 본문은 기록이므로 고치지 않는다(예: ADR-0007이 ADR-0006 D-02를 대체).
- 기록은 재작성하지 않는다. 번호 실수(`0002` 중복)도 그대로 둔다.
- 상태는 `Proposed`·`Accepted`·`Superseded`. 상태가 바뀌면 [decisions/README](decisions/README.md) 표도 고친다.

**따라 하기**

1. [decisions/README](decisions/README.md)의 "다음 신규 ADR 번호"를 확인한다.
2. 배경·결정·대안·결과·검증을 나눠 쓴다.
3. README 표에 행을 추가하고 다음 번호를 올린다.

**강제**: 미강제. 단, 동결 해제(§6)에는 신규 ADR이 CI로 강제된다.

## 5. 폐기와 아카이브

**규칙**: 지우지 말고 보관한다. 보관한 자산은 이력과 복원 절차를 함께 남긴다.

| 대상 | 방법 | 복원 절차 |
|---|---|---|
| 스킬 | `skills/archive/`로 이동 | [skills/archive/README](../skills/archive/README.md) |
| 런타임·도구 묶음 | `archive/<묶음>/`으로 이동, settings·install·CI 배선 해제 | 묶음별 README (예: [archive/multi-cli](../archive/multi-cli/README.md)) |
| 규칙·에이전트·커맨드 | `archive/<묶음>/`으로 이동 (계획 2-1에서 첫 적용) | 묶음별 README |
| issue | 삭제하지 않는다. 닫아도 결과와 검증 근거를 남긴다 | — |
| idea | 삭제하지 않는다. "현재 판단" 절을 추가해 유효성을 갱신한다 | — |
| task·plan 초안 | 삭제는 결정 기록 후에만 (예: 로드맵 초안 4개 — 입력 시트 8-1) | git 이력 |

**따라 하기** (자산 아카이브)

1. 대상을 `git mv`로 옮긴다(이력 보존).
2. `objectives/freeze-manifest.txt`에서 해당 행을 지운다.
3. 인덱스(`CLAUDE.md` 트리, `skills/README.md`, `docs/USAGE.md`, 개수 표기)를 고친다.
4. 하네스 동작이 바뀌므로 `VERSION` MINOR를 올린다(§1).
5. `bats tests/*.bats && bash tests/check_index.sh`

**강제**: 아카이브는 ADR 없이 허용된다(`check_freeze_adr.sh`가 행 삭제는 통과시킨다). 인덱스 정합은 `check_index.sh`.

## 6. 동결 (자산 추가)

**규칙**

- `rules/`·`agents/`·`commands/` 아래 모든 파일과 `skills/` 최상위 항목의 **추가를 동결**한다(2026-11-20부터).
- 해제·예외는 ADR로만 한다. 같은 PR에서 매니페스트에 행을 추가한다.
- 2단계(시스템 루프) 동안 허용되는 하네스 변경은 범위 밖 자산 아카이브뿐이다.

**따라 하기** (예외가 꼭 필요할 때)

1. 같은 실패가 2회 이상 반복됐다는 기록(failure·issue)을 준비한다.
2. ADR을 쓴다 — 왜 실행 자산(훅·검사·템플릿)으로 막을 수 없는지 적는다.
3. 자산을 추가하고 `objectives/freeze-manifest.txt`에 행을 넣는다. `VERSION` MINOR를 올린다.

**강제**: `tests/freeze.bats`가 매니페스트 밖 항목을 거부하고, `tests/check_freeze_adr.sh`(CI `verify-freeze`)가
행 추가에 신규 `docs/decisions/NNNN-*.md`가 없으면 실패한다.

## 7. 브랜치·커밋·push

**규칙**

- `~/.claude`의 항목은 이 저장소 main 체크아웃을 가리킨다. 하네스 개선은 **worktree에서만** 한다.
- 순서는 수정 → `/verify` → 커밋 → **사람 확인 후** push. **main 자동 병합 금지** — 병합은 사람이 PR에서 한다.
- 커밋 제목은 `<type>: <설명>` (`feat`·`fix`·`docs`·`test`·`chore`·`refactor`·`perf`·`style`).
- 한 브랜치는 한 관심사만 다룬다. 이름은 `feat/`·`fix/`·`refactor/` 접두(`git-workflow.md`), 문서 작업은 이 저장소 관례로 `docs/`.

**따라 하기**

```bash
git worktree add -b docs/<작업> ../Arachne-<작업> main   # 또는 /worktree
# 수정 → /verify → git commit
# 사람 확인 → git push -u origin docs/<작업> → gh pr create
# 사람이 PR 병합 → main 체크아웃에서 git pull (이때 실행 중 하네스에 반영)
git worktree remove ../Arachne-<작업>
```

**강제**: 미강제(규칙 문서와 `/git` 커맨드). 병합 후 반영은 `git pull` 시점이다.

## 8. 정본 문서 갱신

**규칙**

- 문서와 실제 동작이 충돌하면 **소스·테스트가 우선**이다. 충돌을 issue나 task에 남기고 정본 하나만 고친다.
- 같은 내용을 두 문서에 쓰지 않는다. 한 곳에 쓰고 나머지는 링크한다.
- 자산을 추가·삭제하면 인덱스와 "N개" 개수 표기를 같은 커밋에서 고친다.
- 정본 문서는 현재 상태만 담는다. 과거 맥락은 ADR·기록으로 링크한다.

**강제**: `check_index.sh`(스킬·커맨드·에이전트·규칙 디렉터리 ↔ 인덱스, 개수 표기, 상대 링크),
`docs_cli_contract.bats`(CLI 명령 ↔ README·USAGE), `doc-drift-check.sh` 훅(기능 파일 변경 시 알림).
