---
Title: README
creation: 2026-05-05
modification: 2026-06-04
Description: 저지연 풀스택 시스템 프로그래밍을 위한 Claude Code 글로벌 설정 프레임워크
tags:
aliases:
---
> MOC::
> FROM::

# 🕷️ Arachne

저지연 풀스택 시스템 프로그래밍 프레임워크를 위한 **멀티-CLI** 글로벌 설정.
**C/C++ · Go · Rust** 중심의 실시간 트레이딩·데이터 파이프라인 개발에 최적화.

하나의 공통 규약(`AGENTS.md`, SSOT)을 **Claude Code · Gemini CLI · Codex CLI** 세 도구가
동시에 따른다. `~/.claude/` 등을 심볼릭 링크로 이 레포와 연결하므로, 레포를 수정하면 글로벌
설정에 반영되고 `git push/pull`로 모든 머신을 동기화할 수 있습니다.

> 🗺️ 하네스 구조 다이어그램(Mermaid)은 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) 참고
> 📖 skills·agents·커맨드·hooks 사용법은 [docs/USAGE.md](docs/USAGE.md) 참고
> 🔗 3개 CLI 통합 사용·상호작용은 [docs/MULTI-CLI.md](docs/MULTI-CLI.md) 참고
> 🗂️ 원격 프로젝트 문서 ↔ Obsidian 동기화는 [docs/OBSIDIAN-DOCS-SYNC.md](docs/OBSIDIAN-DOCS-SYNC.md)(arachne 설정)·[docs/SYNCTHING-SETUP.md](docs/SYNCTHING-SETUP.md)(자동) 참고
> 📑 약어(SSOT·TDD·DI·a11y 등) 풀이는 [docs/GLOSSARY.md](docs/GLOSSARY.md) 참고

---

## 🚀 Installation

```bash
git clone https://github.com/jomarusoup/Arachne.git ~/Arachne
cd ~/Arachne
./install.sh      # 최초 1회 — 이후 arachne 커맨드 사용 가능
```

최초 설치 후 재설치 또는 설정 동기화는 `arachne -i`를 사용합니다.

설치 스크립트가 하는 일:
1. 기존 `~/.claude/` 파일 자동 백업 (`.bak`)
2. 레포 → `~/.claude/` 심볼릭 링크 생성
3. `settings.template.json`의 `__HOME__` → 실제 홈 경로로 치환해 `settings.json` 생성
4. **dotfiles 병합**: `~/.bash_profile`, `~/.vimrc`에 Arachne 설정을 안전하게 병합 (기존 내용 보존)
5. **CLI 등록**: `~/.local/bin/`에 `arachne`, `tws`, `gemini-task`(=`gask`), `codex-task`(=`cask`), `arachne-task`(=`atask`), `docs-sync` 커맨드 등록

### Core CLI Commands
| 커맨드 | 설명 |
|---|---|
| `arachne`, `arachne -h` | 도움말 출력 |
| `arachne -i` (`--install`) | 재설치 및 설정 동기화 |
| `arachne -u` (`--update`) | 최신 상태로 업데이트 (git pull + 재설치) |
| `arachne -c` (`--check`) | 3개 CLI(Claude·Gemini·Codex) 연결 상태 점검 |
| `arachne -n <P> [DIR]` (`--new`) | 신규 프로젝트 스캐폴딩 (README + docs/{issue,idea,template}) |
| `arachne -s` (`--session`) | **TWS (Tmux Workspace Manager)**: 대화형 세션 매니저 (`tws`와 동일) |
| `arachne -e` (`--export-settings`) | settings.json → 템플릿 내보내기 |
| `arachne -d` (`--export-dotfiles`) | dotfiles → 레포 내보내기 |
| `arachne -v` | 버전 정보 |
| `gemini-task` (= `gask`) | **Gemini 위임 래퍼 (reader/advisor 레인)** — Claude Code가 `gemini -p`를 Bash로 호출해 읽기·요약·자문을 위임 |
| `codex-task` (= `cask`) | **Codex 위임 래퍼 (tester/fixer 레인)** — Claude Code가 `codex exec`를 Bash로 호출해 테스트 작성·실행·버그 수정을 위임 |
| `atask` (= `arachne-task`) | **자동 폴백 캐스케이드 디스패처** — 역할별 우선순위로 CLI를 시도하고 쿼터 소진을 감지하면 다음 CLI로 자동 전환 (`claude → codex → gemini`) |
| `docs-sync` | 원격 프로젝트 README/docs/Markdown 문서 ↔ Obsidian Vault 동기화 |

---

## 📁 Structure

```
Arachne/
├── CLAUDE.md                    # Claude 전용 보충 지시서 (rules/는 네이티브 자동 로드)
├── AGENTS.md                    # 공통 규약 SSOT (Single Source of Truth, 단일 진실 공급원 — Claude·Gemini·Codex 공유)
├── settings.template.json       # ~/.claude/settings.json 템플릿
├── install.sh                   # 통합 관리 도구 (CLI: arachne)
├── tmux.sh                      # tmux 워크스페이스 매니저 (CLI: tws)
├── gemini-task.sh               # Gemini 위임 래퍼 — reader/advisor (CLI: gemini-task, gask)
├── codex-task.sh                # Codex 위임 래퍼 — tester/fixer (CLI: codex-task, cask)
├── arachne-task.sh              # 자동 폴백 캐스케이드 디스패처 (CLI: arachne-task, atask)
├── docs-sync.sh                 # 원격 프로젝트 문서 ↔ Obsidian 동기화 (CLI: docs-sync)
├── statusline-command.sh        # Claude Code 상태표시줄 렌더러
│
├── rules/                       # Claude 전역 행동 규칙
│   ├── common/                  # 언어 공통 (workflow, coding-style, patterns 등 12개)
│   ├── ...                      # 언어별 규칙 (c, cpp, golang, rust, python, js, bash)
│   └── web/                     # 웹 디자인 품질 (design-quality)
│
├── skills/                      # 워크플로·도메인 스킬 (28개)
├── commands/                    # 슬래시 커맨드 (16개)
├── agents/                      # 서브에이전트 7개 (planner · code-reviewer · tdd · debugger
│                                #   · python-reviewer · fastapi-reviewer · react-reviewer)
├── hooks/                       # 이벤트 훅 (session-start/end, pre-compact, gemini-check,
│                                #   atask-quota-warn, doc-drift-check)
├── mcp-configs/                 # MCP (Model Context Protocol) 서버 설정 템플릿
├── tests/                       # 검증 스크립트 (bats + shell)
└── dotfiles/                    # bash_profile, vimrc (병합 원본)
```

---

## ⌨️ Slash Commands

| 커맨드 | 설명 |
|---|---|
| `/add` | 기능 추가 — planner 설계 후 단계적 구현 |
| `/fix` | 버그 수정 — 재현 조건 파악 후 최소 범위 수정 |
| `/refactor` | SRP(Single Responsibility Principle, 단일 책임 원칙) 기반 리팩터링 — 역할 분석 → 단계적 이동 |
| `/design` | UI·컴포넌트 설계 문서 작성 및 디자인 개선 계획 제안 |
| `/tdd` | TDD(Test-Driven Development, 테스트 주도 개발) 사이클 — RED→GREEN→REFACTOR + 메모리 검사 |
| `/verify` | 수정 후 2단계 검증 (정적 검사 + 동작) |
| `/e2e` | E2E(End-to-End, 종단 간) 테스트 — 데몬·IPC(시스템) 및 Playwright(웹) 공통 |
| `/python-review` | Python 코드 리뷰 — PEP 8·타입 힌트·보안·이디엄 (python-reviewer 에이전트) |
| `/fastapi-review` | FastAPI 리뷰 — async 정확성·DI(Dependency Injection, 의존성 주입)·스키마·OpenAPI |
| `/react-review` | React/Next 리뷰 — 렌더·Hooks·a11y(accessibility, 접근성)·XSS·성능 |
| `/issue` | GitHub 오픈 이슈 확인 후 순차 처리 |
| `/git` | 커밋·푸시 |
| `/status` | 프로젝트 현황 빠르게 파악 |
| `/handoff` | AI 전환 전 작업 상태 저장 |
| `/save-session` | 세션 요약 저장 (컨텍스트 70% 시 실행) |
| `/learn` | 세션 발견 패턴을 rules에 저장 |

---

## 🏗️ Workspace Management (`-s`)

`arachne -s` (또는 `tws`) 로
 Claude Code 세션을 효율적으로 관리할 수 있습니다.
- **템플릿 지원**: 기본 터미널 / Claude Code 자동 실행(dev) / 테스트용 2분할 화면
- **세션 관리**: 생성, 접속(Attach), 삭제(Kill), 일괄 종료 지원

---

## 🤝 Multi-CLI Collaboration (3-Lane)

Claude Code가 **중심(오케스트레이터 + 주 구현자)**이고, Codex·Gemini는 위임 대상입니다.
세 CLI가 같은 공통 규약(`AGENTS.md`)을 공유하므로 인계 마찰이 작습니다.
**토큰 무겁고 정밀도가 덜 중요한 일은 위임으로 떠넘기고, 정밀 구현·통합·커밋은 Claude가 맡습니다.**

| 레인 (Lane) | CLI | 위임 호출 | 하는 일 |
|---|---|---|---|
| **오케스트레이터 + 주 구현자** | **Claude** | (중심) | 설계·구현·리팩터링·통합·커밋, 보안/임계 리뷰, 설정·마이그레이션·인프라 |
| **tester / fixer** | **Codex** | `codex-task` (=`cask`) | 테스트 작성·실행, 버그 수정 — **기능 추가는 안 함** |
| **reader / advisor** | **Gemini** | `gemini-task` (=`gask`) | 대용량 읽기·요약, 설계 탐색, 1차 리뷰, 장문 생성 — **구현은 안 함** |

방향이 반대인 두 우선순위 사슬:
- **오프로드 (offload, 비용 기준)**: Gemini → Codex → (Claude 안 씀) — 토큰 무거운 일을 싸게 떠넘김
- **페일오버 (failover, 구현 품질 기준)**: Claude → Codex → Gemini — Claude 쿼터 소진 시 구현 대타는 Codex 먼저

위임 경로:
- **`gemini-task` (Gemini reader/advisor)**: Claude Code가 터미널 전환 없이 `gemini -p`를 Bash로 호출 → 답변 수신
  - 끌어오기(요약·자문): `gemini-task "이 로그 요약: $(cat app.log)"` → 큰 입력, 작은 출력으로 **절약**
  - 쏟아내기(생성): `gemini-task "README 작성" > README.md` → 파일로 빼고 **내용 재독 안 함**
- **`codex-task` (Codex tester/fixer)**: Claude Code가 `codex exec`를 Bash로 호출 → 테스트·수정 위임
  - 제안 모드(기본): `codex-task "parser 테스트 보강안 제시: $(cat src/parser.c)"` → diff만 반환, 트리 미변경
  - 실행 모드: `codex-task -w "실패하는 test_auth 를 green 까지 수정"` → 직접 쓰고 돌려 수정 (커밋은 Claude)
- **`atask` (자동 폴백)**: `atask -R impl "..."` 한 줄이 역할 우선순위로 CLI를 시도하고, 쿼터 소진을 감지하면 다음 CLI로 자동 전환 (헤드리스 전용)
  - 소진 상태는 `atask-quota-warn.sh` 훅이 프롬프트마다 사전 경고 (현재 "중심" CLI 표시)
- **git-bus 감지 (보조)**: 다른 터미널에서 Gemini/Codex가 직접 커밋한 경우 `gemini-check.sh` 훅이 자동 감지

> 상세 역할·비용 라우팅은 [docs/MULTI-CLI.md](docs/MULTI-CLI.md)·[docs/USAGE.md](docs/USAGE.md) 6장 참고.
> 정책 SSOT(Single Source of Truth, 단일 진실 공급원)는 [`rules/common/workflow.md`](rules/common/workflow.md).

---

## 🔄 Sync & Update

Arachne은 심볼릭 링크를 기반으로 하며, `-u` 옵션으로 소스 동기화와 재설치를 한 번에 처리합니다.

```bash
# 최신 상태로 업데이트 (표준 방식)
arachne -u

# 설정 내보내기
arachne -e   # settings.json → settings.template.json
arachne -d   # ~/.bash_profile, ~/.vimrc → dotfiles/ 내보내기
```

---

## 🚫 Git-Ignored Paths

| 항목 | 이유 |
|---|---|
| `projects/` | 대화 기록·세션 데이터 |
| `cache/`, `sessions/`, `backups/` | 런타임 생성 파일 |
| `.credentials.json` | API 키 등 민감 정보 |
| `*.bak` | 설치 시 생성되는 백업 |
