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

저지연 풀스택 시스템 프로그래밍 프레임워크를 위한 Claude Code 글로벌 설정.
**C/C++ · Go · Rust** 중심의 실시간 트레이딩·데이터 파이프라인 개발에 최적화.

`~/.claude/` 디렉터리를 심볼릭 링크로 이 레포와 연결합니다.
레포를 수정하면 글로벌 설정에 즉시 반영되고, `git push/pull`로 모든 머신을 동기화할 수 있습니다.

> 📖 skills·agents·커맨드·hooks 사용법은 [docs/USAGE.md](docs/USAGE.md) 참고

---

## 🚀 설치

```bash
git clone https://github.com/jomarusoup/Arachne.git ~/Arachne
cd ~/Arachne
./install.sh
```

설치 스크립트가 하는 일:
1. 기존 `~/.claude/` 파일 자동 백업 (`.bak`)
2. 레포 → `~/.claude/` 심볼릭 링크 생성
3. `settings.template.json`의 `__HOME__` → 실제 홈 경로로 치환해 `settings.json` 생성
4. **dotfiles 병합**: `~/.bash_profile`, `~/.vimrc`에 Arachne 설정을 안전하게 병합 (기존 내용 보존)
5. **CLI 등록**: `~/.local/bin/`에 `arachne`, `tws` 커맨드 등록

### 주요 CLI 커맨드
| 커맨드 | 설명 |
|---|---|
| `arachne update` | Arachne 최신 상태로 업데이트 (git pull + 재설치) |
| `arachne session` | **Tmux Workspace Manager**: Claude Code 전용 대화형 세션 매니저 (`tws`와 동일) |
| `arachne` | (인자 없음) Arachne 재설치 및 설정 동기화 |
| `gask` | **Gemini 직접 호출 래퍼** — Claude Code가 `gemini -p`를 Bash로 호출해 설계·요약을 위임 |

---

## 📁 구조

```
Arachne/
├── CLAUDE.md                    # 글로벌 지시서 진입점 (@rules/* 임포트)
├── settings.template.json       # ~/.claude/settings.json 템플릿
├── install.sh                   # 통합 관리 도구 (CLI: arachne)
├── tmux.sh                      # tmux 워크스페이스 매니저 (CLI: tws)
├── gask.sh                      # Gemini 직접 호출 래퍼 (CLI: gask)
│
├── rules/                       # Claude 전역 행동 규칙
│   ├── common/                  # 언어 공통 (workflow, coding-style, patterns 등 12개)
│   ├── ...                      # 언어별 규칙 (c, cpp, golang, rust, python, js, bash)
│
├── skills/                      # 워크플로·도메인 스킬 (20개)
├── commands/                    # 슬래시 커맨드 (13개)
├── agents/                      # 서브에이전트 (planner, code-reviewer, tdd, debugger)
├── hooks/                       # 이벤트 훅 (session-start/end, pre-compact, gemini-check)
├── mcp-configs/                 # MCP 서버 설정 템플릿
├── tests/                       # 검증 스크립트 (bats + shell)
└── dotfiles/                    # bash_profile, vimrc (병합 원본)
```

---

## ⌨️ 슬래시 커맨드

| 커맨드 | 설명 |
|---|---|
| `/add` | 기능 추가 — planner 설계 후 단계적 구현 |
| `/fix` | 버그 수정 — 재현 조건 파악 후 최소 범위 수정 |
| `/refactor` | SRP 기반 리팩터링 — 역할 분석 → 단계적 이동 |
| `/tdd` | TDD 사이클 — Red-Green-Refactor + 메모리 검사 |
| `/verify` | 수정 후 2단계 검증 (정적 검사 + 동작) |
| `/git` | 커밋·푸시 |
| `/status` | 프로젝트 현황 빠르게 파악 |
| `/handoff` | AI 전환 전 작업 상태 저장 |
| `/save-session` | 세션 요약 저장 (컨텍스트 70% 시 실행) |
| `/learn` | 세션 발견 패턴을 rules에 저장 |

---

## 🏗️ 워크스페이스 관리 (session)

`arachne session` (또는 `tws`) 커맨드를 통해
 Claude Code 세션을 효율적으로 관리할 수 있습니다.
- **템플릿 지원**: 기본 터미널 / Claude Code 자동 실행(dev) / 테스트용 2분할 화면
- **세션 관리**: 생성, 접속(Attach), 삭제(Kill), 일괄 종료 지원

---

## 🤝 Claude ↔ Gemini 협업 (비용 최적화)

Claude 쿼터는 희소 자원, Gemini는 한계비용 ≈ 0이라는 전제로 역할을 나눕니다.
**토큰 무거운 작업(설계·대용량 읽기·요약·장문 생성)은 Gemini로, 정밀 구현·디버깅은 Claude로.**

- **`gask` 직접 호출**: Claude Code가 터미널 전환 없이 `gemini -p`를 Bash로 호출 → 답변 수신
  - 끌어오기(요약·자문): `gask "이 로그 요약: $(cat app.log)"` → 큰 입력, 작은 출력으로 **절약**
  - 쏟아내기(생성): `gask "README 작성" > README.md` → 파일로 빼고 **내용 재독 안 함**
- **git-bus 감지**: 다른 터미널에서 Gemini가 직접 커밋한 경우 `gemini-check.sh` 훅이 자동 감지

> 상세 워크플로·비용 라우팅은 [docs/USAGE.md](docs/USAGE.md) 6장 참고.

---

## 🔄 동기화 및 업데이트

Arachne은 심볼릭 링크를 기반으로 하며, `update` 커맨드로 소스 동기화와 재설치를 한 번에 처리합니다.

```bash
# 최신 상태로 업데이트 (표준 방식)
arachne update

# 설정 내보내기
arachne --export-settings   # settings.json → settings.template.json
arachne --export-dotfiles   # ~/.bash_profile, ~/.vimrc → dotfiles/ 내보내기
```

---

## 🚫 Git 추적 제외

| 항목 | 이유 |
|---|---|
| `projects/` | 대화 기록·세션 데이터 |
| `cache/`, `sessions/`, `backups/` | 런타임 생성 파일 |
| `.credentials.json` | API 키 등 민감 정보 |
| `*.bak` | 설치 시 생성되는 백업 |
