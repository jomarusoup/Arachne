# Claude Code 글로벌 지시서

웹·MVP부터 저수준 시스템 프로그래밍까지 아우르는 Harness의 글로벌 Claude Code 설정.

@rules/common/workflow.md
@rules/common/coding-style.md
@rules/common/patterns.md
@rules/common/issue-workflow.md
@rules/common/ui-layout.md
@rules/common/hooks.md
@rules/common/security.md
@rules/common/testing.md
@rules/common/agents.md
@rules/common/development-workflow.md
@rules/common/git-workflow.md
@rules/common/performance.md

@rules/c/coding-style.md
@rules/cpp/coding-style.md
@rules/golang/coding-style.md
@rules/python/coding-style.md
@rules/javascript/coding-style.md
@rules/bash/coding-style.md

## Architecture

```
~/.claude/  (→ Arachne/ 심볼릭 링크)
│
├── agents/                          # Claude Code 서브에이전트
│   ├── planner.md                   # 구현 설계 전담 (model: opus)
│   ├── code-reviewer.md             # 코드 리뷰 전담 (model: sonnet)
│   ├── tdd.md                       # TDD 사이클 안내 (model: sonnet)
│   └── debugger.md                  # GDB·valgrind·strace·perf (model: sonnet)
│
├── commands/                        # 슬래시 커맨드 (/명령어)
│   ├── add.md                       # /add        — 기능 추가
│   ├── fix.md                       # /fix        — 버그 수정
│   ├── design.md                    # /design     — 설계 문서
│   ├── verify.md                    # /verify     — 수정 후 검증
│   ├── status.md                    # /status     — 프로젝트 현황
│   ├── git.md                       # /git        — 커밋·푸시
│   ├── handoff.md                   # /handoff    — AI 전환 전 상태 저장
│   ├── issue.md                     # /issue      — GitHub 이슈 처리
│   ├── learn.md                     # /learn      — 패턴 학습
│   └── save-session.md              # /save-session — 세션 요약 저장
│
├── hooks/                           # 이벤트 기반 자동화
│   ├── session-start.sh             # SessionStart  — 최근 세션 안내
│   ├── session-end.sh               # Stop          — git 기반 스냅샷 저장
│   ├── pre-compact.sh               # PreCompact    — 압축 전 상태 저장
│   └── gemini-check.sh              # UserPromptSubmit — Gemini 작업 감지
│
├── rules/                           # 항상 적용되는 전역 규칙
│   ├── common/                      # 언어 무관 공통 규칙 (12개)
│   │   ├── workflow.md              # Claude/Gemini 역할 분담·행동 규칙
│   │   ├── coding-style.md          # 헤더 구조·네이밍·포매팅 공통 원칙
│   │   ├── patterns.md              # SRP·불변성·에러 처리
│   │   ├── agents.md                # 에이전트 목록·활성화 기준
│   │   ├── development-workflow.md  # 조사→설계→TDD→리뷰→커밋
│   │   ├── git-workflow.md          # 커밋 형식·브랜치·PR
│   │   ├── hooks.md                 # 훅 유형·등록 방법
│   │   ├── security.md              # 보안 체크리스트·비밀값 관리
│   │   ├── testing.md               # TDD·AAA·메모리 테스트
│   │   ├── performance.md           # 모델 선택·컨텍스트 관리
│   │   ├── issue-workflow.md        # 이슈 타입별 처리 원칙
│   │   └── ui-layout.md             # UI 레이아웃 기준
│   ├── c/          # C 시스템 프로그래밍 (coding-style·hooks·patterns·security·testing)
│   ├── cpp/        # C++ (coding-style·hooks·patterns·security·testing)
│   ├── golang/     # Go (coding-style·hooks·patterns·security·testing)
│   ├── python/     # Python (coding-style·hooks·patterns·security·testing)
│   ├── javascript/ # JS/TS (coding-style·hooks·patterns·security·testing)
│   └── bash/       # Bash/Shell (coding-style·hooks·patterns·security·testing)
│
├── dotfiles/                        # 홈 디렉토리 설정 파일
│   ├── bash_profile                 # → ~/.bash_profile (sgrep 등 유틸 포함)
│   └── vimrc                        # → ~/.vimrc
│
├── skills/                          # 워크플로·도메인 스킬 (20개, README.md 참고)
│   ├── build-debug.md / memory-check.md                             # Harness 전용
│   ├── cpp-testing.md / latency-critical-systems.md / error-handling.md
│   ├── golang-patterns.md / golang-testing.md / python-patterns.md / python-testing.md
│   ├── tdd-workflow.md / verification-loop.md
│   ├── security-review.md / security-scan.md / architecture-decision-records.md
│   ├── docker-patterns.md / deployment-patterns.md
│   └── network-*.md / netmiko-ssh-automation.md
├── mcp-configs/                     # (예정) MCP 서버 설정 템플릿
└── tests/                           # (예정) Arachne 자체 테스트
```

## Development Notes

### 파일 형식

**agents/** — Claude Code 서브에이전트 (YAML frontmatter 필수)
```yaml
---
name: 에이전트명          # Agent(subagent_type: "name") 호출 시 매칭
description: 한 줄 설명   # 언제 활성화할지 Claude가 참고
tools: ["Read", "Grep"]   # 허용 도구 목록
model: opus               # opus / sonnet / haiku
---
```

**commands/** — 슬래시 커맨드 (YAML frontmatter 필수)
```yaml
---
description: /명령어 설명  # /help 에서 표시되는 설명
---
```

**skills/** — 워크플로 스킬 (frontmatter 없음, 마크다운 본문만)
- 구성: 언제 사용하는지 / 어떻게 동작하는지 / 예시

**rules/** — 지시서 (@임포트 또는 직접 작성, frontmatter 불필요)

### 기타

- 패키지 관리자: npm, pnpm, yarn, bun (`CLAUDE_PACKAGE_MANAGER` 환경변수로 지정)
- 훅 형식: Bash 스크립트, `settings.json`의 `hooks` 섹션에 등록
- `install.sh` 실행 시 `~/.claude/` 심볼릭 링크 + `settings.json` 생성
