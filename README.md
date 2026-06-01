---
Title: README
creation: 2026-05-05
modification: 2026-06-01
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

```bash
./install.sh --export-settings   # settings.json → settings.template.json 내보내기
./install.sh --export-dotfiles   # ~/.bash_profile, ~/.vimrc → dotfiles/ 내보내기
```

---

## 📁 구조

```
Arachne/
├── CLAUDE.md                    # 글로벌 지시서 진입점 (@rules/* 임포트)
├── settings.template.json       # ~/.claude/settings.json 템플릿
├── install.sh                   # 설치 스크립트
│
├── rules/                       # Claude 전역 행동 규칙
│   ├── common/                  # 언어 공통 (workflow, coding-style, patterns 등 12개)
│   ├── c/                       # C 시스템 프로그래밍
│   ├── cpp/                     # C++
│   ├── golang/                  # Go
│   ├── rust/                    # Rust (저지연·트레이딩 특화)
│   ├── python/                  # Python (툴링·스크립팅)
│   ├── javascript/              # JavaScript / TypeScript
│   └── bash/                    # Bash / Shell
│
├── skills/                      # 워크플로·도메인 스킬 (20개)
├── commands/                    # 슬래시 커맨드 (13개)
├── agents/                      # 서브에이전트 (planner, code-reviewer, tdd, debugger)
├── hooks/                       # 이벤트 훅 (session-start/end, pre-compact, gemini-check)
├── mcp-configs/                 # MCP 서버 설정 템플릿
├── tests/                       # 검증 스크립트 (bats + shell)
└── dotfiles/                    # bash_profile, vimrc
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
| `/issue` | GitHub 오픈 이슈 확인 후 순차 처리 |
| `/status` | 프로젝트 현황 빠르게 파악 |
| `/design` | UI·컴포넌트 설계 문서 작성 |
| `/e2e` | E2E 테스트 실행 |
| `/handoff` | AI 전환 전 작업 상태 저장 |
| `/save-session` | 세션 요약 저장 (컨텍스트 70% 시 실행) |
| `/learn` | 세션 발견 패턴을 rules에 저장 |

---

## 📚 Skills

`skills/` 디렉터리에 저장된 워크플로·도메인 지식. 관련 파일 편집 시 자동 로드되거나 명시적으로 참조합니다.

### 시스템 프로그래밍
| 스킬 | 설명 |
|---|---|
| `latency-critical-systems` | IPC·epoll·소켓 저지연 설계 |
| `trading-systems` | FIX 프로토콜, 오더북, 마켓 데이터, rdtsc |
| `performance-profiling` | pprof·perf·flamegraph 병목 분석 |
| `build-debug` | C/C++ 빌드·GDB 디버그 |
| `memory-check` | valgrind·ASan·TSan |
| `cpp-testing` | GoogleTest·sanitizer |
| `error-handling` | C/C++·Go·TypeScript 에러 처리 |

### 언어별 패턴·테스팅
| 스킬 | 설명 |
|---|---|
| `rust-patterns` | tokio, lock-free, zero-copy, 저지연 Rust |
| `rust-testing` | criterion 벤치마크, proptest, flamegraph |
| `golang-patterns` | 이디엄틱 Go 패턴 |
| `golang-testing` | 테이블 드리븐·벤치마크·퍼징 |
| `go-http-patterns` | Go HTTP 서버, gRPC, graceful shutdown |

### 기타
| 스킬 | 설명 |
|---|---|
| `tdd-workflow` | Red-Green-Refactor 범용 워크플로 |
| `verification-loop` | Claude Code 세션 검증 시스템 |
| `security-review` | 보안 리뷰 체크리스트 |
| `security-scan` | Claude Code 설정 보안 스캔 |
| `docker-patterns` | Docker/Compose 패턴 |
| `network-config-validation` | 라우터·스위치 설정 검증 |
| `network-interface-health` | 인터페이스 오류·플래핑 진단 |
| `netmiko-ssh-automation` | Python Netmiko SSH 자동화 |

---

## 🤖 에이전트

| 에이전트 | 활성화 시점 |
|---|---|
| `planner` | 파일 3개+ 수정, 신규 모듈, 시스템 레벨 변경 |
| `code-reviewer` | 코드 작성·수정 완료 후 |
| `tdd` | 신규 기능, 버그 수정, 리팩터링 |
| `debugger` | 빌드 실패, 세그폴트, 메모리 오류 |

---

## 🪝 Hooks

| 훅 | 시점 | 동작 |
|---|---|---|
| `session-start.sh` | 세션 시작 | 최근 세션 파일 안내 |
| `session-end.sh` | 세션 종료 | git 기반 스냅샷 저장 |
| `pre-compact.sh` | 컨텍스트 압축 전 | 현재 상태 저장 |
| `gemini-check.sh` | 메시지 입력 시 | Gemini 작업 완료 감지 |

---

## 🔄 동기화

심볼릭 링크로 연결되어 `~/.claude/` 수정 = 레포 수정입니다.

```bash
# 변경 후 푸시
cd ~/Arachne && git add -A && git commit -m "..." && git push

# 다른 머신에서 동기화
cd ~/Arachne && git pull
```

---

## 🚫 Git 추적 제외

| 항목 | 이유 |
|---|---|
| `projects/` | 대화 기록·세션 데이터 |
| `cache/`, `sessions/`, `backups/` | 런타임 생성 파일 |
| `history.jsonl` | 대화 히스토리 |
| `plugins/` | 설치 시 자동 다운로드 |
| `.credentials.json` | API 키 등 민감 정보 |
| `*.bak` | 설치 시 생성되는 백업 |
