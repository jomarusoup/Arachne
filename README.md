---
Title: README
description: Arachne — Claude Code 하네스 · 설치 · 문서 지도
creation: 2026-05-05
modification: 2026-11-21
Description: 리눅스 저지연 시스템을 위한 Claude Code 엔지니어링 하네스
tags:
aliases:
---
> MOC::
> FROM:: #Project / #Side_Project / #Arachne

# Arachne

**Claude Code가 모든 프로젝트에서 같은 규율로 일하게 만드는 설정 묶음(하네스)**이다.
규칙(`rules/`), 스킬(`skills/`), 서브에이전트(`agents/`), 슬래시 커맨드(`commands/`), 이벤트 훅(`hooks/`)을
한 저장소에 두고, 설치기가 `~/.claude/`에 연결한다. 사용 프로젝트에는 profile 기반 CI 키트를 만들어 준다.

- **목표**: 리눅스에서 정확하고 장애가 격리된 저지연 시스템(C 중심, Rust로 경계부터 이식)과, 그 성능을 받쳐 주는
  Rust 네이티브 클라이언트. 우선순위는 정확성 > 장애 격리 > 성능 > 개발 효율 ([OBJECTIVES](docs/OBJECTIVES.md)).
- **현재 상태**: 방향 전환 1단계. 새 규칙·스킬·에이전트·커맨드 추가는 동결 중이고, 범위 밖 자산(웹·Java·
  Electron·Go·Python·멀티-CLI)은 아카이브 예정이다 ([계획](docs/task/2026-11-20-harness-direction-plan.md)).
- **버전**: [`VERSION`](VERSION) — 규칙은 [MANAGEMENT §1](docs/MANAGEMENT.md#1-버전).

## 시작하기 — 3단계

**1. 설치** (macOS·Linux)

```bash
git clone https://github.com/jomarusoup/Arachne.git ~/Arachne
cd ~/Arachne
./install.sh        # 최초 1회 — 이후 arachne 명령 사용 가능
```

설치기는 기존 `~/.claude/` 파일을 `.bak`으로 백업하고, 저장소 항목을 `~/.claude/`에 심볼릭 링크로
연결한다. `settings.template.json`으로 `settings.json`을 만들고, `~/.local/bin/`에 `arachne`·`tws`·`docs-sync`를 등록한다.
Windows는 [WINDOWS-SETUP](docs/WINDOWS-SETUP.md)을 따른다(`install.ps1 -Install`).

**2. 확인**

```bash
arachne -v          # 버전
arachne -c          # 연결 상태 점검
arachne -t          # 개발 도구(C/C++·Go·Rust·Python 등) 점검·설치
```

Claude Code를 새로 열면 `CLAUDE.md`와 `rules/common/`이 자동으로 로드된다. `/verify`, `/git` 같은 커맨드를 바로 쓸 수 있다.

**3. 내 프로젝트에 적용**

```bash
cd /path/to/project
arachne init-ci --profile cpp      # 또는 rust · python · minimal · python-web
arachne project-check              # .arachne/commands 의 검증을 로컬에서 실행
```

`.github/workflows/arachne.yml`이 `main` push·PR에서 `bash .arachne/verify.sh`를 실행하고, `/git`도 커밋 전에
같은 runner를 쓴다. profile별 도구와 소유권은 [docs/PROJECT-CI.md](docs/PROJECT-CI.md),
디자인 문서 위치는 [DESIGN-DOCS.md](docs/DESIGN-DOCS.md)가 정본이다.
새 프로젝트는 `arachne -n <이름> [DIR] --profile <P>`로 만든다.

## 무엇이 언제 동작하나

| 자산 | 위치 | 언제 동작하나 |
|---|---|---|
| 지시서 | `CLAUDE.md`, `rules/common/*` | 매 세션 자동 로드 |
| 언어 규칙 | `rules/<언어>/*` | 해당 확장자 파일을 편집할 때 자동 로드 |
| 스킬 | `skills/<이름>/SKILL.md` | 작업이 description과 맞으면 Claude가 호출, `/이름`으로 직접 호출 |
| 에이전트 | `agents/*.md` | 리뷰·설계·디버깅 시점에 자동 활성화 (`rules/common/agents.md`) |
| 커맨드 | `commands/*.md` | 채팅에 `/이름` 입력 |
| 훅 | `hooks/*.sh` | 세션 시작·종료, 명령 실행 전, 커밋 전 등 이벤트 |

전체 목록과 사용법은 [USAGE](docs/USAGE.md), 구조도는 [ARCHITECTURE](docs/ARCHITECTURE.md)에 있다.

## 주요 명령

| 명령 | 설명 |
|---|---|
| `arachne -i` | 재설치·설정 동기화 (`--with-ua`: Understand-Anything 함께) |
| `arachne -u` | 업데이트(git pull + 재설치)와 확장 도구·개발 도구 갱신을 대화형으로 선택 |
| `arachne -t` | 개발 도구 그룹별 점검·설치 (`--update` 버전 갱신, `--rollback` 되돌리기) |
| `arachne -a` | 읽기 전용 보안 점검 (`--full` Lynis, `--binary` annocheck) |
| `arachne -c` | 연결 상태 점검 |
| `arachne -n <P> [DIR] --profile <P>` | 새 프로젝트 만들기 |
| `arachne init-ci [DIR] --profile <P>` | 기존 프로젝트에 CI·검증 생성·갱신 |
| `arachne project-check [DIR]` | 프로젝트 검증 로컬 실행 |
| `arachne feedback new/list/submit` | 사용 프로젝트에서 Arachne 개선 의견 기록·제출 |
| `arachne -s` (`tws`) | tmux 워크스페이스 매니저 |
| `arachne -e` / `arachne -d` | `settings.json` → 템플릿 / dotfiles → 저장소 내보내기 |
| `docs-sync` | 원격 프로젝트 문서 ↔ Obsidian 동기화 |

자주 쓰는 슬래시 커맨드: `/add` 기능 추가 · `/fix` 버그 수정 · `/tdd` · `/verify` 수정 후 검증 ·
`/git` 커밋 · `/worktree` 병렬 작업 폴더. 전체 24개는 [USAGE §1](docs/USAGE.md#1-slash-commands-commands).

## 문서

**어디서부터 읽을지는 [docs/README.md](docs/README.md)의 독자 경로 표를 본다.** 처음 설치, 매일 사용,
내 프로젝트에 적용, 하네스 고치기, 플랫폼·동기화 다섯 경로로 나눠 읽는 순서를 정해 두었다.

## 하네스를 고치려면

1. [OBJECTIVES](docs/OBJECTIVES.md)에서 목표와 동결 범위를 확인한다.
2. [MANAGEMENT](docs/MANAGEMENT.md)의 규칙을 따른다 — worktree에서 작업, `/verify` 후 커밋,
   **push는 사람 확인 후**, main 자동 병합 금지, 동작이 바뀌면 `VERSION`을 올린다.
3. 로컬 검증: `bats tests/*.bats && bash tests/check_index.sh && bash tests/check_convention_sync.sh`
   (CI 전체는 [CI](docs/CI.md)).

## Git에 올리지 않는 경로

`projects/`(대화 기록), `cache/`·`sessions/`·`backups/`(런타임 생성), `.credentials.json`(인증 정보), `*.bak`(설치 백업).
