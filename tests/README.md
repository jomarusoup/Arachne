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
# 전체 테스트
bats tests/

# 개별 실행
bats tests/install.bats
bats tests/hooks.bats
bash tests/validate_settings.sh

# Windows (PowerShell)
pwsh -File tests/install_windows.ps1
```

## 테스트 목록

| 파일 | 대상 | 도구 |
|---|---|---|
| `install.bats` | `install.sh` — 링크·settings·Codex/Copilot 병합·연결 점검 | bats |
| `hooks.bats` | `hooks/*.sh` — 존재·권한·문법·기본 동작 | bats |
| `atask.bats` | `arachne-task.sh` — 역할 순서·쿼터 폴백·쿨다운·오류 처리 | bats |
| `docs_sync.bats` | `docs-sync.sh` — 설정 생성·목록·문법 | bats |
| `drift.bats` | 인덱스·규약 드리프트 검사 fixture | bats |
| `git_command.bats` | `/git` 커맨드 문서 계약 | bats |
| `new_project.bats` | `arachne new` — 문서 구조·템플릿·git init·입력 안전성 | bats |
| `project_ci.bats` | 사용 프로젝트 profile·`init-ci`·`project-check`·실패 상태 전파 | bats |
| `docs_cli_contract.bats` | 핵심 CLI 도움말과 README·USAGE 발견성 계약 | bats |
| `smoke.bats` | 훅·`atask` 런타임 스모크 | bats |
| `wrapper_security.bats` | `gtask`/`ctask` wrapper 프리앰블·raw·쓰기 경고 | bats |
| `data_contract.bats` | `fixtures/python-db` — 데이터 계약 정적 검사 + alembic·pytest 실행 게이트 (uv 필요) | bats |
| `sgrep.bats` | `dotfiles/bash_profile` — sgrep/lgrep 확장자 커버리지·제외 디렉터리·rg/find 폴백 | bats |
| `ua_stale.bats` | `hooks/ua-stale-check.sh` — UA 지식그래프 stale 감지 (최신/뒤처짐/해시 유실/임계값) | bats |
| `check_index.sh` | 인덱스 ↔ 실제 파일 일치 + 문서 "(N개)" 개수 표기 검증 (skills·commands·agents·rules) | bash |
| `check_convention_sync.sh` | `AGENTS.md` ↔ `rules/common/*` 핵심 토큰 동기화 | bash |
| `validate_settings.sh` | `settings.template.json` — JSON 유효성·필수 키 | bash + jq |
| `smoke_hooks.sh` | Windows Git Bash와 Ubuntu smoke job 공용 런타임 스모크 | bash |
| `install_windows.ps1` | `install.ps1` — 링크·경로 치환·Gemini/Codex·CMD 래퍼 | PowerShell |

## validate_settings.sh

bats 없이도 실행 가능. jq가 있으면 JSON 파싱 검사까지 수행:

```bash
bash tests/validate_settings.sh
```
