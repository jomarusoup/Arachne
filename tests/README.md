# Tests

Arachne 스크립트 및 유틸리티 검증 테스트 모음.

## 의존성 설치

```bash
# bats-core (Bash Automated Testing System)
# Ubuntu/Debian
sudo apt install bats

# macOS
brew install bats-core

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
```

## 테스트 목록

| 파일 | 대상 | 도구 |
|---|---|---|
| `install.bats` | `install.sh` — 심볼릭 링크·settings.json 생성 | bats |
| `hooks.bats` | `hooks/*.sh` — 존재·권한·문법·기본 동작 | bats |
| `docs_sync.bats` | `docs-sync.sh` — 설정 생성·목록·문법 | bats |
| `validate_settings.sh` | `settings.template.json` — JSON 유효성·필수 키 | bash + jq |

## validate_settings.sh

bats 없이도 실행 가능. jq가 있으면 JSON 파싱 검사까지 수행:

```bash
bash tests/validate_settings.sh
```
