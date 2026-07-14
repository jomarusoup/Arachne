# Rules

Claude Code에 항상 적용되는 전역 규칙 모음.

> 디렉터리별 파일 구성은 [CLAUDE.md](../CLAUDE.md)의 Architecture 트리가 정본이다 —
> 이 파일(매 세션 로드)에는 로드 규칙과 자동 활성화 기준만 담는다.

## 구조 (요약)

- `common/` — 언어 무관 공통 규칙 (workflow·coding-style·patterns·testing·security·
  agents·development-workflow·git-workflow·hooks·performance)
- 언어·도메인별 — `c/` `cpp/` `golang/` `java/` `rust/` `python/` `javascript/`
  `bash/` `docker/` `web/` (각 coding-style·hooks·patterns·security·testing,
  python은 fastapi·data-handling, web은 design-quality·ui-layout)

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

해당 확장자 파일 편집 시 언어 규칙 전체 자동 로드:

| 확장자 | 로드되는 규칙 |
|---|---|
| `*.c`, `*.h` | `c/*.md` 전체 |
| `*.cpp`, `*.hpp` | `cpp/*.md` 전체 |
| `*.go` | `golang/*.md` 전체 |
| `*.java`, `pom.xml`, `build.gradle*` | `java/*.md` 전체 |
| `*.rs`, `Cargo.toml` | `rust/*.md` 전체 |
| `*.py` | `python/*.md` 전체 |
| `*.js`, `*.ts` | `javascript/*.md` 전체 |
| `Dockerfile`, `*.Dockerfile`, `docker-compose*.yml`, `docker-compose*.yaml`, `compose*.yml`, `compose*.yaml` | `docker/*.md` 전체 |
| `*.css`, `*.scss`, `*.html`, `*.jsx`, `*.tsx`, `*.vue` | `web/design-quality.md`, `web/ui-layout.md` |
| `*.sh` | `bash/*.md` 전체 |
