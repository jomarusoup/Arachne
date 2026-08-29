---
Title: "Arachne 플랫폼 호환성"
creation: 2026-06-09
modification: 2026-06-09
tags:
 - "arachne"
 - "compatibility"
aliases:
 - "arachne-platform-support"
---
MOC:: [[Arachne]]
FROM:: [[Arachne]]

# Arachne 플랫폼 호환성

지원 여부는 기능별로 판단한다. 한 플랫폼에서 설치가 된다는 사실이 모든 hook·test·tmux 기능 지원을
의미하지 않는다.

| 기능 | Linux | macOS | Windows PowerShell | Git Bash/WSL |
| --- | --- | --- | --- | --- |
| Unix `install.sh` | 지원 | 지원 | 미지원 | 지원 |
| PowerShell `install.ps1` | 미지원 | 미지원 | 지원 | 해당 없음 |
| Claude hooks | 지원 | 지원 | Git Bash 필요 | 지원 |
| `tws` | 지원 | 지원 | 미지원 | WSL에서 지원 |
| `new`, `init-ci`, `project-check` | 지원 | 지원 | Git Bash/WSL | 지원 |
| 확장 도구 `--extras`(UA·taste·codegraph) | 지원 | 지원 | 지원(`setup-extras.ps1`) | 지원 |
| 전체 저장소 테스트 | CI 검증 | CI 검증 | PowerShell+스모크 | 환경별 |

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

GitHub Actions는 Ubuntu, Rocky Linux 9, macOS, Windows를 검증한다. WSL과 모든 OS 버전 조합,
외부 AI CLI API 응답, 실제 사용자 인증 상태는 자동 검증 범위가 아니다.
