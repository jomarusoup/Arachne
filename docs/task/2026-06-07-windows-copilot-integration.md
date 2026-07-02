---
Title: "[task] Windows Copilot 통합 설치와 검증 보완"
creation: 2026-06-07
modification: 2026-07-01
status: "done"
tags:
 - "arachne"
 - "task"
 - "windows"
 - "copilot"
 - "priority/high"
aliases:
 - "windows-copilot-integration"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-postmerge-audit]]

# [task] Windows Copilot 통합 설치와 검증 보완

- **상태**: done
- **우선순위**: high
- **담당**: unassigned
- **관련 문서**: [postmerge audit](../issue/2026-06-07-postmerge-audit.md),
  [Windows hooks issue](../issue/2026-06-07-postmerge-04-windows-hooks-untested.md)

## 목표

Windows 사용자가 저장소를 클론한 뒤 통합 설치 명령 하나로 GitHub Copilot CLI와 VS Code 사용자
지침까지 설치하고, Windows CI가 해당 산출물과 멱등성을 검증하도록 한다.

## 범위

- 포함:
  - `install.ps1`에 `copilot` 타깃과 `all` 설치 경로 추가
  - 기존 `install-copilot.ps1` 로직 재사용 또는 공통 함수화
  - Copilot CLI·VS Code 사용자 지침 생성과 기존 사용자 내용 보존 검증
  - Windows CI 테스트에 Copilot 설치·재설치 검증 추가
  - README, `docs/USAGE.md`, `docs/WINDOWS-SETUP.md`의 설치 절차와 지원 표 일치
- 제외:
  - GitHub Copilot 자체 설치와 구독 활성화 자동화
  - 조직 정책에서 비활성화된 Copilot 우회
  - Windows 네이티브 `tws` 지원

## 작업 목록

- [x] `install.ps1 -Target copilot -Install`을 허용한다.
- [x] `install.ps1 -Target all -Install`이 Copilot 감지 시 Copilot 지침을 설치한다.
- [x] `install.ps1 -Check`가 Copilot CLI와 VS Code 지침의 누락·stale 상태를 검사한다.
- [x] 기존 `~\.copilot\copilot-instructions.md`의 마커 외 사용자 내용을 보존한다.
- [x] 재설치해도 ARACHNE 마커가 중복되지 않는 Windows 회귀 테스트를 추가한다.
- [x] `~\.copilot\instructions\arachne.instructions.md` frontmatter와 `applyTo: "**"`를 검증한다.
- [x] Windows CI에서 통합 설치와 독립 `install-copilot.ps1` 경로를 모두 실행한다.
- [x] `docs/USAGE.md`의 오래된 “Windows 네이티브 미지원” 문구를 현재 지원 범위로 교정한다.
- [x] README와 Windows 설치 가이드의 명령을 통합 설치 기준으로 정리한다.

## 검증

```powershell
pwsh -File .\tests\install_windows.ps1
pwsh -File .\install.ps1 -Install -Target copilot
pwsh -File .\install.ps1 -Check
```

```bash
bats tests/install.bats tests/new_project.bats
bash tests/check_index.sh
```

Windows 테스트 홈에 두 Copilot 지침 파일이 생성되고, 사용자 내용 보존·마커 멱등성·frontmatter
검증이 모두 통과해야 한다.

## 완료 조건

- Windows의 `install.ps1` 도움말, 허용 타깃, 실제 설치, 점검 동작이 모두 Copilot을 포함한다.
- Windows CI가 Copilot 설치 산출물과 재설치 안전성을 검증한다.
- 문서 어디에도 현재 구현과 충돌하는 Windows 지원 설명이 남지 않는다.
- 저장소 내부 Copilot 지침과 사용자 전역 지침의 적용 범위가 구분되어 설명된다.

## 진행 기록

### 2026-06-07

- 저장소 내부에서는 `AGENTS.md`와 `.github/copilot-instructions.md`가 자동 발견됨을 확인했다.
- Windows 통합 설치기 `install.ps1`은 현재 `copilot` 타깃을 허용하지 않으며, 독립
  `install-copilot.ps1` 실행이 필요함을 확인했다.
- Windows CI의 `tests/install_windows.ps1`은 Claude, Gemini, Codex만 검증하고 Copilot은
  검증하지 않음을 확인했다.
- `docs/USAGE.md`에 Windows PowerShell 설치기 존재와 충돌하는 “Windows 네이티브 미지원”
  설명이 남아 있음을 확인했다.

### 2026-07-01

- task 인벤토리 정리: 규약상 상태 값은 `planned`가 아니라 `to do`로 표준화했다.
- 정리 당시에는 구현이 아직 착수되지 않았고, Windows Copilot 통합 설치·검증 항목은 전부 열린 상태였다.
- 완료: `install.ps1`에 `copilot` target, `all` 감지 설치, `-Check` stale 검사를 추가했다.
- 완료: `tests/install_windows.ps1`이 통합 설치, 재설치 멱등성, `applyTo: "**"` frontmatter,
  독립 `install-copilot.ps1` 경로를 검증한다.
- 문서: README, USAGE, WINDOWS-SETUP, ARCHITECTURE, MULTI-CLI를 통합 `install.ps1 -Target copilot`
  기준으로 교정했다.
- 검증: `bats ../tests/install.bats` 33건 통과(권한 상승 실행). `pwsh`/`powershell`은 이 Linux
  환경에 없어 `tests/install_windows.ps1`은 로컬 미실행이며, Windows CI에서 실행해야 한다.
- 상태 → **done**.
