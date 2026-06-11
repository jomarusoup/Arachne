# Rules

Claude Code에 항상 적용되는 전역 규칙 모음.

## 구조

```
rules/
├── common/                      # 모든 언어·도메인 공통
│   ├── workflow.md              — Claude/Gemini 역할 분담, 전역 행동 규칙
│   ├── coding-style.md          — 헤더 구조, 네이밍, 포매팅 공통 원칙
│   ├── patterns.md              — SRP, 불변성, 에러 처리, 품질 체크리스트
│   ├── issue-workflow.md        — GitHub 이슈 타입별 처리 원칙
│   ├── ui-layout.md             — UI 레이아웃 기준
│   ├── hooks.md                 — 훅 유형·등록 방법·공통 권장 훅
│   ├── security.md              — 커밋 전 보안 체크리스트, 비밀값 관리
│   ├── testing.md               — TDD 워크플로, AAA 패턴, 메모리 테스트
│   ├── agents.md                — 에이전트 목록·활성화 기준·병렬 실행
│   ├── development-workflow.md  — 조사→설계→TDD→리뷰→커밋 파이프라인
│   ├── git-workflow.md          — 커밋 메시지 형식, 브랜치 전략, PR
│   └── performance.md           — 모델 선택 전략, 컨텍스트 창 관리
│
├── c/                           # C 시스템 프로그래밍
│   ├── coding-style.md          — Allman, 포인터, 인클루드 순서
│   ├── hooks.md                 — cppcheck, valgrind CI 파이프라인
│   ├── patterns.md              — goto cleanup, opaque pointer, 에러 코드
│   ├── security.md              — 버퍼 오버플로, 포맷 스트링, POSIX 권한
│   └── testing.md               — cmocka, valgrind, ASan, 커버리지
│
├── cpp/                         # C++
│   ├── coding-style.md          — RAII, 스마트 포인터, Modern C++
│   ├── hooks.md                 — clang-format, clang-tidy, ctest
│   ├── patterns.md              — RAII, Rule of Five, 의존성 주입
│   ├── security.md              — 메모리 안전성, UB 방지, sanitizer
│   └── testing.md               — GoogleTest, sanitizer, 커버리지
│
├── golang/                      # Go
│   ├── coding-style.md          — gofmt, 에러 래핑, 인터페이스 설계
│   ├── hooks.md                 — gofmt, go vet, staticcheck
│   ├── patterns.md              — functional options, 작은 인터페이스, 채널
│   ├── security.md              — context 타임아웃, gosec, SQL 인젝션
│   └── testing.md               — 테이블 드리븐, -race, 커버리지
│
├── rust/                        # Rust
│   ├── coding-style.md          — rustfmt, Clippy, K&R, 네이밍
│   ├── hooks.md                 — cargo fmt, cargo clippy, cargo audit
│   ├── patterns.md              — 소유권·빌림, tokio, lock-free, 저지연
│   ├── security.md              — unsafe 규칙, cargo-audit, 공급망 보안
│   └── testing.md               — criterion 벤치마크, proptest, nextest
│
├── python/                      # Python
│   ├── coding-style.md          — black, 타입 힌트, 불변 dataclass
│   ├── hooks.md                 — black, mypy, ruff
│   ├── patterns.md              — Protocol, dataclass DTO, context manager
│   ├── security.md              — bandit, SQL 인젝션, Pydantic 검증
│   ├── testing.md               — pytest, fixture, 모킹
│   ├── fastapi.md               — async DI, 스키마 분리, 시스템 전환 브릿지
│   └── data-handling.md         — JSON 경계, SQLAlchemy 세션·트랜잭션, migration, 민감 데이터
│
├── web/                         # 웹 디자인 품질 (프론트엔드 공통)
│   └── design-quality.md        — 안티-템플릿 정책, 필수 품질, 스타일 방향
│
├── javascript/                  # JavaScript / TypeScript
│   ├── coding-style.md          — K&R, 불변성, ASI 주의, any 금지
│   ├── hooks.md                 — Prettier, tsc, console.log 감사
│   ├── patterns.md              — Repository, API 응답 포맷, 에러 클래스
│   ├── security.md              — XSS, SQL 인젝션, Zod 검증, npm audit
│   └── testing.md               — Jest, Playwright E2E
│
└── bash/                        # Bash / Shell
    ├── coding-style.md          — set -euo pipefail, 변수 따옴표
    ├── hooks.md                 — shellcheck CI
    ├── patterns.md              — trap cleanup, 로그 함수, 에러 처리
    ├── security.md              — 커맨드 인젝션, mktemp, 권한 검사
    └── testing.md               — bats-core
```

## 사용 방법

> **@import 하지 않는다.** `install.sh`가 `rules/`를 `~/.claude/rules/`로 심볼릭하며,
> Claude Code가 이를 **네이티브로 자동 로드**한다. 과거의 `@rules/...` import는
> 전부 중복이라 제거됐다(`c123a7e`). 공식 문서: code.claude.com/docs/en/memory
> ("Organize rules with .claude/rules/", "Path-specific rules").

| 규칙 | 로드 시점 |
|---|---|
| `rules/common/*` (paths frontmatter 없음) | **매 세션 자동 로드** |
| `rules/<언어>/*` (paths frontmatter 있음) | **해당 확장자 파일 편집 시** 자동 로드 |

Gemini CLI·Codex CLI·GitHub Copilot은 `rules/` 자동 로더가 없으므로, 공통 규약을 추출한
[`AGENTS.md`](../AGENTS.md)(SSOT)를 본다 — Gemini는 `~/.gemini/GEMINI.md` 심볼릭,
Codex는 `~/.codex/AGENTS.md` 마커 병합, Copilot은 저장소 `AGENTS.md`와
`~/.copilot/` 사용자 지침을 사용한다.

### 자동 활성화 (paths 기반)

해당 확장자 파일 편집 시 언어 규칙 전체(5개 파일) 자동 로드:

| 확장자 | 로드되는 규칙 |
|---|---|
| `*.c`, `*.h` | `c/*.md` 전체 |
| `*.cpp`, `*.hpp` | `cpp/*.md` 전체 |
| `*.go` | `golang/*.md` 전체 |
| `*.rs`, `Cargo.toml` | `rust/*.md` 전체 |
| `*.py` | `python/*.md` 전체 |
| `*.js`, `*.ts` | `javascript/*.md` 전체 |
| `*.css`, `*.scss`, `*.html`, `*.jsx`, `*.tsx`, `*.vue` | `web/design-quality.md` |
| `*.sh` | `bash/*.md` 전체 |
