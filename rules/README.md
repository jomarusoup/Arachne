# Rules

Claude Code에 항상 적용되는 전역 규칙 모음.

## 구조

```
rules/
├── common/          # 모든 언어·도메인 공통
│   ├── workflow.md          — Claude/Gemini 역할 분담, 전역 행동 규칙
│   ├── coding-style.md      — 헤더 구조, 네이밍, 포매팅 공통 원칙
│   ├── patterns.md          — SRP, 불변성, 에러 처리, 품질 체크리스트
│   ├── issue-workflow.md    — GitHub 이슈 타입별 처리 원칙
│   ├── ui-layout.md         — UI 레이아웃 기준
│   ├── security.md          — (예정) 공통 보안 규칙
│   └── testing.md           — (예정) 공통 테스팅 원칙
│
├── c/               # C 시스템 프로그래밍
│   └── coding-style.md      — Allman, 포인터, 인클루드 순서
│
├── cpp/             # C++
│   └── coding-style.md      — RAII, 스마트 포인터, Modern C++
│
├── golang/          # Go
│   └── coding-style.md      — gofmt, 에러 래핑, 인터페이스 설계
│
├── python/          # Python
│   └── coding-style.md      — black, 타입 힌트, 에러 처리
│
├── javascript/      # JavaScript / TypeScript
│   └── coding-style.md      — K&R, 불변성, ASI 주의사항
│
└── bash/            # Bash / Shell
    └── coding-style.md      — set -euo pipefail, 변수 따옴표
```

## 사용 방법

### CLAUDE.md에서 임포트

```markdown
# 공통 규칙 (항상 로드)
@rules/common/workflow.md
@rules/common/coding-style.md
@rules/common/patterns.md

# 프로젝트에서 주로 사용하는 언어 추가
@rules/c/coding-style.md
@rules/golang/coding-style.md
```

### 자동 활성화 (paths 기반)

언어별 파일에 `paths:` frontmatter가 있어 해당 확장자 파일 편집 시 자동 로드됨:
- `*.c`, `*.h` → `c/coding-style.md`
- `*.cpp`, `*.hpp` → `cpp/coding-style.md`
- `*.go` → `golang/coding-style.md`
- `*.py` → `python/coding-style.md`
- `*.js`, `*.ts` → `javascript/coding-style.md`
- `*.sh` → `bash/coding-style.md`
