---
Title: "[task] CI 플랫폼 분기와 Windows 실패 수정"
creation: 2026-06-08
modification: 2026-06-08
tags:
 - "arachne"
 - "task"
 - "priority/high"
 - "ci"
aliases:
 - "ci-platform-split"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [task] CI 플랫폼 분기와 Windows 실패 수정

- **상태**: done
- **우선순위**: high
- **담당**: Codex
- **관련 문서**: [ci.md](../ci.md), [ci.yml](../../.github/workflows/ci.yml)

## 목표

GitHub Actions CI를 Ubuntu, Red Hat/Rocky, Windows, macOS job으로 분리해 플랫폼별 실패 원인을 바로
구분할 수 있게 하고, 현재 반복 실패 중인 Windows 설치 테스트 호출 계약을 수정한다.

## 범위

- 포함:
  - `.github/workflows/ci.yml` 플랫폼별 job 분리
  - Windows 설치 테스트의 PowerShell 인자 전달 수정
  - `docs/ci.md` 플랫폼별 Mermaid 흐름과 운영 절차 갱신
- 제외:
  - 실제 외부 Claude/Codex/Gemini/Copilot API 호출 E2E
  - 배포 또는 릴리스 자동화

## 작업 목록

- [x] 최신 CI 실패 로그에서 Windows 실패 원인을 확인한다.
- [x] 별도 브랜치 `ci-platform-split`에서 작업한다.
- [x] Ubuntu, Red Hat/Rocky, Windows, macOS job을 workflow에 분리한다.
- [x] Windows 설치 테스트의 `-Install` 인자 전달 실패를 수정한다.
- [x] `docs/ci.md`를 실제 플랫폼 분기와 일치하게 갱신한다.
- [x] 정적 검사와 가능한 로컬 검증을 실행한다.

## 검증

```bash
bash -n tests/validate_settings.sh tests/check_index.sh tests/check_convention_sync.sh tests/smoke_hooks.sh
git diff --check
```

가능한 경우:

```powershell
pwsh -File .\tests\install_windows.ps1
```

기대 결과: 문법과 공백 검사가 통과하고, Windows 환경에서는 설치 테스트가 `Target` ValidateSet 오류 없이
진행된다.

## 완료 조건

- CI YAML이 네 플랫폼 job을 명시한다.
- Windows 실패 원인과 수정 내용이 task와 CI 문서에 기록된다.
- 실행한 검증 결과가 진행 기록에 남아 있다.

## 진행 기록

### 2026-06-08

- task 생성: 사용자 요청에 따라 CI 구조를 확인하고 플랫폼별 job 분리 작업을 시작했다.
- 최신 GitHub Actions 실패 로그 확인: Windows job의 `tests/install_windows.ps1`가 `install.ps1`을 호출할 때
  `-Install`이 positional `Target` 값처럼 전달되어 `ValidateSet("claude", "gemini", "codex", "all")`
  오류가 발생했다.
- 구현: CI job을 `verify-ubuntu`, `verify-rocky`, `verify-windows`, `verify-macos`로 분리하고,
  Windows 테스트 호출을 `RunInstaller -Arguments @(...)`로 고쳐 `-Install`이 named switch로 전달되게 했다.
- 문서: `docs/ci.md`를 플랫폼별 Mermaid 흐름과 로컬 재현 절차 중심으로 갱신하고, `docs/CI.md`는
  대문자 경로 호환 안내 문서로 축소했다.
- 검증 통과:
  - `git diff --check`
  - `bash -n tests/validate_settings.sh tests/check_index.sh tests/check_convention_sync.sh tests/smoke_hooks.sh`
  - `python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml", encoding="utf-8")); print("yaml ok")'`
  - `shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh`
  - `bats tests/*.bats` — 101개 통과
  - `bash tests/validate_settings.sh`
  - `bash tests/check_index.sh`
  - `bash tests/check_convention_sync.sh`
- 미실행: 현재 Linux 작업 환경에 `pwsh`가 없어 `pwsh -File ./tests/install_windows.ps1` 로컬 실행은
  하지 못했다. 실제 Windows 통과 여부는 다음 `verify-windows` CI에서 확인해야 한다.
