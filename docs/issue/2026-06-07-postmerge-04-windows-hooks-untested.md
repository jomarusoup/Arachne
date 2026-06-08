---
Title: "[bug] 신규 훅·atask가 Windows/Git Bash 환경에서 미검증"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "postmerge-audit"
 - "issue"
 - "severity/medium"
aliases:
 - "windows-hooks-untested"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-postmerge-audit]]

# [bug] 신규 훅(atask-quota-warn·doc-drift-check)·atask가 Windows/Git Bash 환경에서 미검증

- **작성일**: 2026-06-07
- **심각도**: MEDIUM
- **영역**: `settings.template.json`, `hooks/*.sh`, `arachne-task.sh`, `tests/install_windows.ps1`
- **상태**: 해결됨 — 7fd1cc6 (Git Bash 훅·atask 스모크를 Windows CI·bats에 추가). task [[2026-06-07-windows-runtime-verification]]
- **GitHub**: #40

## 문제

windows-support 병합 후 추가된 훅·`atask`는 Windows CI(`tests/install_windows.ps1`)나 별도
테스트로 검증되지 않는다. `settings.template.json`의 훅은 `bash "__HOME__/..."`로 등록돼
Git Bash(`bash.exe`)와 Windows 경로 변환에 의존한다.

## 재현

Windows에서 `install.ps1 -Install` 후 Claude Code 세션을 열어 프롬프트를 입력해도,
`bash "C:\Users\...\.claude\hooks\git-bus-check.sh"`가 정상 실행되는지 확인하는 테스트가 없다.

## 영향

- `__HOME__`가 Windows 경로(`C:\Users\...`)로 치환됐을 때 `bash "C:\..."` 동작 미검증.
- atask 상태 파일 `$HOME/.claude/arachne-quota-state` 경로 미검증.
- #37(GNU `date -d`)과 결합하면 Windows에서 쿨다운 표시가 깨진다.

## 원인

CI의 Windows job은 `install.ps1` 설치만 검증하고 런타임 훅·`atask`는 다루지 않는다.

## 수정 방향

- Windows job에 Git Bash로 훅·`atask --dry-run` 스모크 테스트 추가, 또는
- Windows에서 미지원 항목을 문서·`arachne --check`에 명시.

## 회귀 테스트

`tests/install_windows.ps1`(또는 신규)에 Git Bash 훅 스모크 추가.

## 완료 조건

Windows에서 훅·`atask`가 동작하거나, 미지원 범위가 명시적으로 문서화된다.
