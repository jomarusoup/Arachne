---
Title: README
description: 📚 Documentation Map · 🚀 Installation · macOS / Linux
creation: 2026-05-05
modification: 2026-06-09
Description: Python·Web과 시스템 개발을 위한 멀티 CLI 엔지니어링 하네스
tags:
aliases:
---
> MOC::
> FROM:: #Project / #Side_Project / #Arachne

# Arachne

Python·Web과 C/C++·Go·Rust 시스템 개발에 공통 규약, 역할 분담, 프로젝트 검증을 제공하는
**멀티 CLI 엔지니어링 하네스**다. 현재 우선 profile은 Python·Web이며 systems·network 자산도
선택적으로 사용할 수 있다.

하나의 공통 규약(`AGENTS.md`, SSOT)을 **Claude Code · Gemini CLI · Codex CLI · GitHub Copilot**이
동시에 따른다. Claude와 Gemini는 레포 심볼릭 링크를 읽고, Codex는 `AGENTS.md`를 마커 병합한
사본을 읽는다. 따라서 Claude/Gemini 자산은 레포 수정 후 다음 로드부터 반영되지만, Codex 규약은
`arachne -i --target codex` 재실행이 필요하다. `git push/pull`로 여러 머신의 원본 레포를 동기화한다.

## 📚 Documentation Map

전체 문서 인덱스와 독자별 진입점은 **[docs/README.md](docs/README.md)** 가 정본이다.
목적별 진입점:

| 알고 싶은 것 | 문서 |
|---|---|
| 하네스 구조 다이어그램·설치 배선·3-레인 협업 | [ARCHITECTURE](docs/ARCHITECTURE.md) |
| 일상 사용법(skills·agents·커맨드·hooks) · 약어 풀이 | [USAGE](docs/USAGE.md) · [GLOSSARY](docs/GLOSSARY.md) |
| 멀티 CLI(Claude·Codex·Gemini·Copilot) 역할·위임 | [MULTI-CLI](docs/MULTI-CLI.md) |
| 프로젝트 적용 — CI 계약·profile·데이터·디자인 문서 | [PROJECT-CI](docs/PROJECT-CI.md) · [PYTHON-WEB-PROFILE](docs/PYTHON-WEB-PROFILE.md) · [DATA-HANDLING](docs/DATA-HANDLING.md) · [DESIGN-DOCS.md](docs/DESIGN-DOCS.md) |
| 확장 도구 — Understand-Anything·taste-skill·codegraph | [tools/README](docs/tools/README.md) |
| 플랫폼·동기화 — Windows·호환성·다중 머신·Obsidian | [WINDOWS-SETUP](docs/WINDOWS-SETUP.md) · [COMPATIBILITY](docs/COMPATIBILITY.md) · [SYNCTHING-SETUP](docs/SYNCTHING-SETUP.md) · [OBSIDIAN-DOCS-SYNC](docs/OBSIDIAN-DOCS-SYNC.md) |
| 학습 — 익히는 순서·역량 지도·AI 엔지니어링 노트 | [HARNESS-LEARNING-GUIDE](docs/HARNESS-LEARNING-GUIDE.md) · [CAPABILITY-MAP](docs/CAPABILITY-MAP.md) · [AI-ENGINEERING-NOTES](docs/AI-ENGINEERING-NOTES.md) |
| 저장소 자체 CI·UI/UX 기준·장기 설계 결정(ADR) | [CI](docs/CI.md) · [ui-ux/README](docs/ui-ux/README.md) · [decisions/](docs/decisions/README.md) |

## 🚀 Installation

### macOS / Linux

> 기본 설치기는 macOS BSD 도구로 동작한다. 전체 저장소 테스트와 일부 상태표시줄 기능은 GNU
> coreutils를 사용하므로 기여자는 `brew install coreutils`가 필요하다. 기능별 범위는
> [호환성 표](docs/COMPATIBILITY.md)를 참고한다.

```bash
git clone https://github.com/jomarusoup/Arachne.git ~/Arachne
cd ~/Arachne
./install.sh      # 최초 1회 — 이후 arachne 커맨드 사용 가능
```

### Windows (PowerShell)

먼저 Claude Code·Codex CLI·Gemini CLI와 Git for Windows, Node.js를 설치합니다.
명령별 인증·업데이트·WSL2 대안은
[Windows 상세 설치 가이드](docs/WINDOWS-SETUP.md)를 따릅니다.

```powershell
git clone https://github.com/jomarusoup/Arachne.git "$HOME\Arachne"
Set-Location "$HOME\Arachne"
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Install
```

Windows 설치기는 관리자 권한 없이 디렉터리 junction과 파일 hard link를 우선 사용하고,
불가능하면 복사로 폴백합니다. Claude 훅과 `gtask`/`ctask`/`atask`는 Bash 스크립트이므로
[Git for Windows](https://gitforwindows.org/)의 `bash.exe`가 PATH에 있어야 합니다.
`tws`는 Windows 네이티브에서 지원하지 않으며 WSL 등 tmux 환경에서 사용합니다.

최초 설치 후 재설치 또는 설정 동기화는 `arachne -i`를 사용합니다.

설치 스크립트가 하는 일:
1. 기존 `~/.claude/` 파일 자동 백업 (`.bak`)
2. 레포 → `~/.claude/` 심볼릭 링크 생성
3. `settings.template.json`의 `__HOME__` → 실제 홈 경로로 치환해 `settings.json` 생성
4. **dotfiles 병합**: `~/.bash_profile`, `~/.vimrc`에 Arachne 설정을 안전하게 병합 (기존 내용 보존)
5. **Copilot 지침**: `arachne -i --target copilot`으로 Copilot CLI와 VS Code 사용자 프로필에 전역 규약 설치
6. **CLI 등록**: `~/.local/bin/`에 `arachne`, `tws`, `gemini-task`(=`gtask`), `codex-task`(=`ctask`), `arachne-task`(=`atask`), `docs-sync` 커맨드 등록
7. **선택 확장 도구**: `arachne -i --with-ua`로 Understand-Anything을 설치 흐름에 붙이거나,
   `arachne -i --with-extras`로 UA·taste-skill·codegraph를 함께 설정

Windows 네이티브 PowerShell에서는 `.\install.ps1 -Install -Target copilot`을 실행합니다.
독립 설치 경로가 필요하면 `.\install-copilot.ps1`도 사용할 수 있습니다. macOS/Linux/WSL/Git
Bash에서는 `./install.sh -i --target copilot`을 사용합니다. 모든 경로는 심볼릭 링크 권한 없이
일반 파일로 `~/.copilot/`에 설치합니다.

### Core CLI Commands
| 커맨드 | 설명 |
|---|---|
| `arachne`, `arachne -h` | 도움말 출력 |
| `arachne -i` (`--install`) | 재설치 및 설정 동기화 |
| `arachne -i --with-ua` | 설치와 함께 Understand-Anything 플러그인 세팅 |
| `arachne -u` (`--update`) | 대화형 선택: Arachne 업데이트/재설치, Understand-Anything 갱신, codegraph 갱신 |
| `arachne -u --with-ua` | 업데이트와 함께 Understand-Anything 갱신 |
| `arachne -c` (`--check`) | Claude·Gemini·Codex·Copilot 연결 상태 점검 |
| `arachne -n <P> [DIR] --profile <P>` | 신규 프로젝트 스캐폴딩. profile 기본값은 `minimal` |
| `arachne init-ci [DIR] --profile <P>` | 기존 프로젝트에 profile 기반 검증과 GitHub Actions 생성/갱신 |
| `arachne project-check [DIR]` | `.arachne/commands`에 정의한 프로젝트 검증을 로컬에서 실행 |
| `arachne feedback new/list/submit` | 사용 프로젝트에서 Arachne 개선 의견을 로컬 기록 후 GitHub Issue로 명시 제출 |
| `arachne -s` (`--session`) | **TWS (Tmux Workspace Manager)**: 대화형 세션 매니저 (`tws`와 동일) |
| `arachne -e` (`--export-settings`) | settings.json → 템플릿 내보내기 |
| `arachne -d` (`--export-dotfiles`) | dotfiles → 레포 내보내기 |
| `arachne -v` | 버전 정보 |
| `gemini-task` (= `gtask`) | **Gemini 위임 래퍼 (reader/advisor 레인)** — Claude Code가 `gemini -p`를 Bash로 호출해 읽기·요약·자문을 위임 |
| `codex-task` (= `ctask`) | **Codex 위임 래퍼 (tester/fixer 레인)** — Claude Code가 `codex exec`를 Bash로 호출해 테스트 작성·실행·버그 수정을 위임 |
| `atask` (= `arachne-task`) | **헤드리스 폴백 디스패처** — 역할별 순서로 실행 후보를 바꾸지만 Codex/Gemini 단계는 각각 tester/fixer·reader/advisor 래퍼 제약을 유지 |
| `docs-sync` | 원격 프로젝트 README/docs/Markdown 문서 ↔ Obsidian Vault 동기화 |

### Project CI

Arachne 저장소의 CI는 하네스 자체를 검증한다. Arachne를 사용하는 각 프로젝트는 별도의 프로젝트 CI를
가져야 하며, 다음 명령으로 생성한다.

```bash
cd /path/to/project
arachne init-ci --profile python-web
arachne project-check
```

생성되는 `.github/workflows/arachne.yml`은 `main` push와 `main` 대상 PR에서
`bash .arachne/verify.sh`를 실행한다. Claude Code의 `/git`도 같은 runner를 커밋 전에 실행하므로
로컬과 GitHub의 검증 기준이 일치한다. `minimal`, `python`, `web`, `python-web`의 도구·소유권·
갱신 정책은 [PROJECT-CI.md](docs/PROJECT-CI.md)가 정본이다. Web 계열 profile의 제품 디자인 문서
위치와 `/design` 탐색 계약은 [DESIGN-DOCS.md](docs/DESIGN-DOCS.md)가 정본이다.

## 📁 Structure

```
Arachne/
├── CLAUDE.md                    # Claude 전용 보충 지시서 (rules/는 네이티브 자동 로드)
├── AGENTS.md                    # 공통 규약 SSOT (Claude·Gemini·Codex·Copilot 공유)
├── .github/copilot-instructions.md # Copilot 저장소 어댑터
├── settings.template.json       # ~/.claude/settings.json 템플릿
├── install.sh / install.ps1     # Unix / Windows 통합 관리 도구 (CLI: arachne)
├── lib/                         # install.sh 도메인 라이브러리 (project-ci · feedback)
├── install-copilot.ps1          # Windows PowerShell용 Copilot 설치기
├── tmux.sh                      # tmux 워크스페이스 매니저 (CLI: tws)
├── gemini-task.sh               # Gemini 위임 래퍼 — reader/advisor (CLI: gemini-task, gtask)
├── codex-task.sh                # Codex 위임 래퍼 — tester/fixer (CLI: codex-task, ctask)
├── arachne-task.sh              # 자동 폴백 캐스케이드 디스패처 (CLI: arachne-task, atask)
├── docs-sync.sh                 # 원격 프로젝트 문서 ↔ Obsidian 동기화 (CLI: docs-sync)
├── statusline-command.sh        # Claude Code 상태표시줄 렌더러
│
├── rules/                       # Claude 전역 행동 규칙
│   ├── common/                  # 언어 공통 (workflow, coding-style, patterns 등 12개)
│   ├── ...                      # 언어별 규칙 (c, cpp, golang, rust, python, js, bash)
│   └── web/                     # 웹 디자인 품질 (design-quality)
│
├── skills/                      # 워크플로·도메인 스킬 (51개)
├── commands/                    # 슬래시 커맨드 (19개)
├── agents/                      # 서브에이전트 8개 (planner · code-reviewer · tdd · debugger
│                                #   · python-reviewer · fastapi-reviewer · react-reviewer
│                                #   · database-reviewer)
├── hooks/                       # 이벤트 훅 (session-start/end, pre-compact, git-bus-check,
│                                #   atask-quota-warn, doc-drift-check, ua-stale-check)
├── mcp-configs/                 # MCP (Model Context Protocol) 서버 설정 템플릿
├── docs/CI.md                   # GitHub Actions CI 운영·로컬 재현 가이드
├── docs/PROJECT-CI.md           # Arachne 사용 프로젝트의 CI 계약
├── docs/DESIGN-DOCS.md          # 사용 프로젝트 디자인 문서 위치와 /design 탐색 계약
├── docs/HARNESS-LEARNING-GUIDE.md # 하네스 학습 순서
├── docs/CAPABILITY-MAP.md       # 역량 지도
├── docs/ui-ux/                  # UI/UX 예시와 기준
├── docs/PYTHON-WEB-PROFILE.md   # Python·Web profile 기술 기준
├── docs/COMPATIBILITY.md        # 기능별 플랫폼 지원표
├── docs/decisions/              # Architecture Decision Record
├── docs/task/                   # 승인된 실행 작업과 진행 상태 기록
├── docs/template/               # idea · issue · task · audit · feedback 기록 템플릿
├── tests/                       # 검증 스크립트 (bats + shell)
├── templates/project/           # profile별 프로젝트 CI 템플릿
└── dotfiles/                    # bash_profile, vimrc (병합 원본)
```

## ⌨️ Slash Commands

| 커맨드 | 설명 |
|---|---|
| `/add` | 기능 추가 — planner 설계 후 단계적 구현 |
| `/fix` | 버그 수정 — 재현 조건 파악 후 최소 범위 수정 |
| `/refactor` | SRP(Single Responsibility Principle, 단일 책임 원칙) 기반 리팩터링 — 역할 분석 → 단계적 이동 |
| `/design` | UI·컴포넌트 설계 문서 작성 및 디자인 개선 계획 제안 |
| `/tdd` | TDD(Test-Driven Development, 테스트 주도 개발) 사이클 — RED→GREEN→REFACTOR + 메모리 검사 |
| `/verify` | 수정 후 2단계 검증 (정적 검사 + 동작) + `.arachne/reports/` 리포트 기록 |
| `/e2e` | E2E(End-to-End, 종단 간) 테스트 — 데몬·IPC(시스템) 및 Playwright(웹) 공통 |
| `/python-review` | Python 코드 리뷰 — PEP 8·타입 힌트·보안·이디엄 (python-reviewer 에이전트) |
| `/fastapi-review` | FastAPI 리뷰 — async 정확성·DI(Dependency Injection, 의존성 주입)·스키마·OpenAPI |
| `/react-review` | React/Next 리뷰 — 렌더·Hooks·a11y(accessibility, 접근성)·XSS·성능 |
| `/database-review` | DB schema·쿼리·migration·ORM 리뷰 (database-reviewer 에이전트) |
| `/issue` | GitHub 오픈 이슈 확인 후 순차 처리 |
| `/git` | 커밋·푸시 |
| `/worktree` | 병렬 세션용 worktree 생성·상태확인·정리 |
| `/status` | 프로젝트 현황 빠르게 파악 |
| `/handoff` | AI 전환 전 작업 상태 저장 |
| `/save-session` | 세션 요약 저장 (컨텍스트 70% 시 실행) |
| `/learn` | 세션 발견 패턴을 rules에 저장 |
| `/codegraph` | 코드 그래프·심볼·영향 범위 분석 (확장 도구 codegraph) |

## 🏗️ Workspace Management (`-s`)

`arachne -s` (또는 `tws`) 로
 Claude Code 세션을 효율적으로 관리할 수 있습니다.
- **템플릿 지원**: 기본 터미널 / Claude Code 자동 실행(dev) / 테스트용 2분할 화면
- **세션 관리**: 생성, 접속(Attach), 삭제(Kill), 일괄 종료 지원

## 🤝 Multi-CLI Collaboration (3-Lane)

> **Claude Code만 있어도 됩니다(솔로 모드)** — Codex·Gemini·Copilot 미설치 환경에서도 규칙·
> 에이전트·스킬·훅·커맨드·프로젝트 CI 전부가 그대로 동작하며, 설치기는 미감지 CLI를 자동으로
> 건너뜁니다. 위임 명령(`gtask`/`ctask`)은 미설치 시 안내와 함께 127로 실패하고 `atask`는 다음
> 후보로 넘어갑니다. 상세: [MULTI-CLI.md §5.3](docs/MULTI-CLI.md). 협업 규율의 계층 원칙
> (사상 동일·수단 상이·집행은 CI)은 [MULTI-CLI.md §5.0](docs/MULTI-CLI.md) 참고.

Claude Code가 **중심(오케스트레이터 + 주 구현자)**이고, Codex·Gemini는 위임 대상입니다.
세 CLI가 같은 공통 규약(`AGENTS.md`)을 공유하므로 인계 마찰이 작습니다.
**토큰 무겁고 정밀도가 덜 중요한 일은 위임으로 떠넘기고, 정밀 구현·통합·커밋은 Claude가 맡습니다.**

| 레인 (Lane) | CLI | 위임 호출 | 하는 일 |
|---|---|---|---|
| **오케스트레이터 + 주 구현자** | **Claude** | (중심) | 설계·구현·리팩터링·통합·커밋, 보안/임계 리뷰, 설정·마이그레이션·인프라 |
| **tester / fixer** | **Codex** | `codex-task` (=`ctask`) | 테스트 작성·실행, 버그 수정 — **기능 추가는 안 함** |
| **reader / advisor** | **Gemini** | `gemini-task` (=`gtask`) | 대용량 읽기·요약, 설계 탐색, 1차 리뷰, 장문 생성 — **구현은 안 함** |

방향이 반대인 두 우선순위 사슬:
- **오프로드 (offload, 비용 기준)**: Gemini → Codex → (Claude 안 씀) — 토큰 무거운 일을 싸게 떠넘김
- **실행 후보 순서 (availability fallback)**: Claude → Codex → Gemini — 쿼터 소진 시 다음
  헤드리스 CLI를 시도하지만 역할·커밋 권한이 자동 승계되는 것은 아님

위임 경로:
- **`gemini-task` (Gemini reader/advisor)**: Claude Code가 터미널 전환 없이 `gemini -p`를 Bash로 호출 → 답변 수신
  - 끌어오기(요약·자문): `gemini-task "이 로그 요약: $(cat app.log)"` → 큰 입력, 작은 출력으로 **절약**
  - 쏟아내기(생성): `gemini-task "README 작성" > README.md` → 파일로 빼고 **내용 재독 안 함**
- **`codex-task` (Codex tester/fixer)**: Claude Code가 `codex exec`를 Bash로 호출 → 테스트·수정 위임
  - 제안 모드(기본): `codex-task "parser 테스트 보강안 제시: $(cat src/parser.c)"` → diff만 반환, 트리 미변경
  - 실행 모드: `codex-task -w "실패하는 test_auth 를 green 까지 수정"` → 직접 쓰고 돌려 수정 (커밋은 Claude)
- **`atask` (자동 폴백)**: `atask -R impl "..."`이 역할별 순서로 헤드리스 CLI를 시도하고 쿼터 소진 시 다음 후보로 전환 (헤드리스 전용)
  - Codex는 `codex-task`, Gemini는 `gemini-task`를 거치므로 각각의 역할 제한이 유지된다. 소진 상태는 `atask-quota-warn.sh` 훅이 사전 경고.
  - 특히 `impl` 폴백의 종료코드 0은 기능 구현 완료를 보장하지 않으므로 결과와 diff를 사람이 검증해야 한다.
- **git-bus 감지 (보조)**: `git-bus-check.sh`가 업스트림 브랜치의 새 커밋을 감지한다. 작성 CLI는 판별하지
  않으며, 업스트림이 설정된 경우 다른 로컬 터미널의 미푸시 커밋은 감지하지 않는다.

> 상세 역할·비용 라우팅은 [docs/MULTI-CLI.md](docs/MULTI-CLI.md)·[docs/USAGE.md](docs/USAGE.md) 6장 참고.
> 정책 SSOT(Single Source of Truth, 단일 진실 공급원)는 [`rules/common/workflow.md`](rules/common/workflow.md).

## 🔄 Sync & Update

Arachne은 심볼릭 링크를 기반으로 하며, `-u` 옵션으로 소스 동기화와 재설치를 한 번에 처리합니다.

```bash
# 최신 상태로 업데이트 (표준 방식)
arachne -u

# 설정 내보내기
arachne -e   # settings.json → settings.template.json
arachne -d   # ~/.bash_profile, ~/.vimrc → dotfiles/ 내보내기
```

## 🚫 Git-Ignored Paths

| 항목 | 이유 |
|---|---|
| `projects/` | 대화 기록·세션 데이터 |
| `cache/`, `sessions/`, `backups/` | 런타임 생성 파일 |
| `.credentials.json` | API 키 등 민감 정보 |
| `*.bak` | 설치 시 생성되는 백업 |
