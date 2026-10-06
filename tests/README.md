# Tests

Arachne 스크립트 및 유틸리티 검증 테스트 모음.

GitHub Actions의 실행 조건, job별 범위, 로컬 CI 전체 재현, 실패 대응은
[CI 운영 가이드](../docs/CI.md)를 참고한다.

## 의존성 설치

```bash
# bats-core (Bash Automated Testing System)
# Ubuntu/Debian
sudo apt install bats diffutils jq shellcheck

# macOS
brew install bats-core bash coreutils jq shellcheck

# 또는 직접 설치
git clone https://github.com/bats-core/bats-core.git
cd bats-core && sudo ./install.sh /usr/local
```

## 실행 방법

```bash
# 전체 테스트 (macOS — 한글 테스트 이름 때문에 로캘 변수를 비우고 실행)
env LC_ALL= LANG= LC_CTYPE= bats tests/*.bats

# 개별 실행
bats tests/install.bats
bats tests/hooks.bats
bash tests/validate_settings.sh

# Windows (PowerShell)
pwsh -File tests/install_windows.ps1
```

macOS 기본 bash 3.2에서는 마지막 줄이 아닌 `[[ ]]` 단언이 실패해도 테스트가 통과할 수 있고, `!` 부정은
어느 bash 버전에서도 `set -e`에 잡히지 않는다. 그래서 로컬 통과가 CI 실패를 숨길 수 있으며 판정 정본은 CI다.
작성 규칙은 [rules/bash/testing.md](../rules/bash/testing.md), 자세한 설명은 [docs/CI.md](../docs/CI.md)에 있다.

## 테스트 목록

| 파일 | 대상 | 도구 |
|---|---|---|
| `install.bats` | `install.sh` — 링크·settings·Codex/Copilot 병합·연결 점검 | bats |
| `hooks.bats` | `hooks/*.sh` — 존재·권한·문법·기본 동작 | bats |
| `docs_sync.bats` | `docs-sync.sh` — 설정 생성·목록·문법 | bats |
| `drift.bats` | 인덱스·규약 드리프트 검사 fixture | bats |
| `git_command.bats` | `/git` 커맨드 문서 계약 | bats |
| `verify_command.bats` | `/verify` 리포트 영속화 문서 계약 (`.arachne/reports/` 형식·정책) | bats |
| `skill_meta.bats` | `skills/*.md` frontmatter 계약 — name 일치·description·triggers(paths·keywords) | bats |
| `new_project.bats` | `arachne new` — 문서 구조·템플릿·git init·입력 안전성 | bats |
| `project_ci.bats` | 사용 프로젝트 profile·`init-ci`·`project-check`·실패 상태 전파 | bats |
| `docs_cli_contract.bats` | 핵심 CLI 도움말과 README·USAGE 발견성 계약 | bats |
| `smoke.bats` | 훅 런타임 스모크 | bats |
| `data_contract.bats` | `fixtures/python-db` — 데이터 계약 정적 검사 + alembic·pytest 실행 게이트 (uv 필요) | bats |
| `sgrep.bats` | `dotfiles/bash_profile` — sgrep/lgrep 확장자 커버리지·제외 디렉터리·rg/find 폴백 | bats |
| `agent_command_meta.bats` | `agents/*.md`·`commands/*.md` frontmatter·프롬프트 방어 기준선·리뷰어 읽기 전용 계약 | bats |
| `guard_hooks.bats` | `hooks/guard-bash.sh`·`guard-secrets.sh` — 거부·확인·통과 판정, 우회 시도, jq 없는 폴백 | bats |
| `naming_check.bats` | `lib/naming-check.sh` — 네이밍 사전 대조·신규 식별자 보고 | bats |
| `sql_schema_versioning.bats` | `templates/project/sql/apply-schema.sh` — 버전 순서·체크섬·dry-run | bats |
| `shm_tools.bats` | c-system `tools/` — 공유메모리 조회 마스킹·원문 보기 감사 로그·제어·복구 시나리오 | bats |
| `collect.bats` | c-system `tools/collect.sh` — dry-run·운영 서버 프로파일링 거부·반출 전 개인정보 마스킹 | bats |
| `logtrace.bats` | c-system `tools/logtrace.sh` — 거래 ID 추적·회전 로그 | bats |
| `feedback.bats` | `arachne feedback` — 프로젝트 피드백 채널 | bats |
| `worktree_command.bats` | `/worktree` 커맨드 문서 계약 | bats |
| `ua_stale.bats` | `hooks/ua-stale-check.sh` — UA 지식그래프 stale 감지 (최신/뒤처짐/해시 유실/임계값) | bats |
| `check_index.sh` | 인덱스 ↔ 실제 파일 일치 + 문서 "(N개)" 개수 표기 + 상대 .md 링크 해소 검증 (skills·commands·agents·rules·docs) | bash |
| `check_sensitive_text.sh` | 추적 파일의 개인 경로·비밀값·개인정보 (값은 출력하지 않음) | bash |
| `check_unicode_safety.sh` | 지시 파일의 숨은 유니코드(폭 없는 문자·양방향 제어 문자) | bash |
| `check_convention_sync.sh` | `AGENTS.md` ↔ `rules/common/*` 핵심 토큰 동기화 | bash |
| `check_ps_syntax.ps1` | 저장소 전체 `.ps1` 구문 파싱 — Linux pwsh 에서 Windows 러너 전 조기 차단 | PowerShell |
| `validate_settings.sh` | `settings.template.json` — JSON 유효성·필수 키 | bash + jq |
| `smoke_hooks.sh` | Windows Git Bash와 Ubuntu smoke job 공용 런타임 스모크 — 알림 훅 3종과 가드 훅 기본 판정 | bash |
| `install_windows.ps1` | `install.ps1` — 링크·경로 치환·Gemini/Codex·CMD 래퍼 | PowerShell |

## validate_settings.sh

bats 없이도 실행 가능. jq가 있으면 JSON 파싱 검사까지 수행:

```bash
bash tests/validate_settings.sh
```
