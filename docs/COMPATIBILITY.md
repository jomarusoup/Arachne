---
Title: "Arachne 플랫폼 호환성"
creation: 2026-06-09
modification: 2026-10-06
tags:
 - "arachne"
 - "compatibility"
aliases:
 - "arachne-platform-support"
---
MOC:: [[Arachne]]
FROM:: [[Arachne]]

# Arachne 플랫폼 호환성

이 문서는 Arachne 기능이 어느 운영체제에서 지원되고, 그 지원을 무엇으로 확인하는지 정리한 표다.
새 머신에 설치하기 전이나, 특정 기능이 내 환경에서 검증된 것인지 확인할 때 읽는다.

지원 여부는 기능별로 판단한다. 한 플랫폼에서 설치가 된다는 사실이 모든 훅·테스트·tmux 기능을 지원한다는
뜻은 아니다. "CI 검증"은 GitHub Actions가 매 push·PR마다 그 플랫폼에서 실행해 확인한다는 뜻이다.
"미검증"은 동작하도록 만들었지만 자동 검사가 없다는 뜻이다.

| 기능 | Linux | macOS | Windows PowerShell | Git Bash/WSL |
| --- | --- | --- | --- | --- |
| Unix `install.sh` | 지원 | 지원 | 미지원 | 지원 |
| PowerShell `install.ps1` | 미지원 | 미지원 | 지원 | 해당 없음 |
| Claude hooks | 지원 | 지원 | Git Bash 필요 | 지원 |
| `tws` | 지원 | 지원 | 미지원 | WSL에서 지원 |
| `new`, `init-ci`, `project-check` | 지원 | 지원 | Git Bash/WSL | 지원 |
| 확장 도구 `--extras`(UA·taste·codegraph) | 지원 | 지원 | 지원(`setup-extras.ps1`) | 지원 |
| 전체 저장소 테스트 | CI 검증 | CI 검증 | PowerShell+스모크 | 환경별 |

## 보안 가드와 프로젝트 키트

아래 표는 보안 가드와 프로젝트 키트 기능의 검증 범위다. Linux 열은 Ubuntu와 Rocky Linux 9 CI를 함께 가리킨다.
단, C 컴파일이 필요한 항목은 Ubuntu에서만 돈다. Rocky 작업에는 C 컴파일러를 설치하지 않으므로 해당 테스트를 건너뛴다.

| 기능 | Linux | macOS | Windows (Git Bash) | 근거 |
| --- | --- | --- | --- | --- |
| 가드 훅 판정 (`guard-bash.sh`·`guard-secrets.sh`) | CI 검증 | CI 검증 | 스모크 검증 | 전체 판정 테스트(`tests/guard_hooks.bats`)는 Linux·macOS에서 돈다. Windows는 Git Bash 스모크(`tests/smoke_hooks.sh`)가 거부 1건과 통과 2건만 확인한다. |
| 가드 훅 등록 (`settings.json`의 PreToolUse) | CI 검증 | CI 검증 | 부분 검증 | 템플릿 구조는 `tests/validate_settings.sh`가 확인한다. Windows는 `install.ps1`이 같은 템플릿으로 만든 `settings.json`이 올바른 JSON인지만 확인한다. |
| `permissions.deny` 읽기 차단 | 템플릿만 검증 | 템플릿만 검증 | 템플릿만 검증 | 규칙 존재는 `tests/validate_settings.sh`가 확인한다. 실제 차단은 Claude Code가 수행하므로 CI로 검증하지 않는다. |
| `--init-ci --profile c-system` 키트 복사 | CI 검증 | CI 검증 | 미검증 | `tests/project_ci.bats`·`tests/new_project.bats` |
| c-system C 코드 빌드·테스트 | CI 검증 (Ubuntu) | 미검증 | 해당 없음 | robust 뮤텍스 등 Linux 전용 경로가 있다. 운영 대상도 Linux 서버다. |
| c-system 운영 도구 (`shmctl.sh`·`shm_view`·`shm_recover`) | CI 검증 (Ubuntu) | 일부 검증 | 해당 없음 | `tests/shm_tools.bats`. attach 프로세스 수 세기처럼 `/proc`가 필요한 항목은 macOS에서 건너뛴다. |
| 네이밍 검사 (`lib/naming-check.sh`) | CI 검증 | CI 검증 | 미검증 | `tests/naming_check.bats`. universal-ctags가 없으면 정규식 추출로 대신하며, ctags 경로 테스트는 건너뛴다. |
| 3티어 compose 스모크 (`templates/project/compose-3tier`) | CI 검증 (Ubuntu) | 미검증 | 미검증 | C 빌드 테스트, PostgreSQL 기동, 스키마 적용과 재적용을 확인한다. Oracle 경로는 자동 검증 범위가 아니다. |

## macOS 도구 범위

- `install.sh` 경로 해석은 BSD `readlink`에서도 동작하는 `ResolvePath`를 사용한다.
- `tests/check_convention_sync.sh` 등 일부 기여자 검사는 GNU coreutils가 필요하다.
- 상태표시줄의 일부 날짜 표현은 GNU `date` 동작에 의존할 수 있다.
- 공식 macOS CI는 Homebrew의 Bash, coreutils, ShellCheck, Bats, jq를 설치한다.

따라서 일반 설치 사용자에게 coreutils를 일괄 필수로 요구하지 않는다. Arachne 자체 전체 테스트를
재현하는 기여자는 다음을 설치한다.

```bash
brew install bash coreutils shellcheck bats-core jq
export PATH="$(brew --prefix coreutils)/libexec/gnubin:$PATH"
```

## 검증 범위

GitHub Actions는 Ubuntu, Rocky Linux 9, macOS, Windows를 검증한다. Windows 작업은 PowerShell 설치기
검증(`tests/install_windows.ps1`)과 Git Bash 훅 런타임 스모크(`tests/smoke_hooks.sh`)만 실행한다.
WSL, 모든 OS 버전 조합, 외부 AI CLI의 API 응답, 실제 사용자 인증 상태는 자동 검증 범위가 아니다.
CI 단계별 상세는 [CI 운영 가이드](CI.md)에 있다.
