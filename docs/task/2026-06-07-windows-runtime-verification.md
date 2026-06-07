---
Title: "[task] Windows 런타임 검증 — 신규 훅·atask Git Bash 동작"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "project"
 - "task"
 - "priority/medium"
aliases:
 - "windows-runtime-verification"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-postmerge-04-windows-hooks-untested]]

# [task] Windows 런타임 검증

- **상태**: planned
- **우선순위**: medium
- **담당**: unassigned
- **관련 문서**: #40, [[2026-06-07-postmerge-04-windows-hooks-untested]], #37(date 의존 연계)

## 목표

windows-support 병합 후 추가된 훅(`atask-quota-warn`·`doc-drift-check`·`git-bus-check`)과 `atask`가
Windows/Git Bash 경로에서 실제 동작하는지 검증하거나, 미지원 범위를 명시한다.

## 범위

- 포함: `tests/install_windows.ps1`(또는 신규 Windows 스모크), `settings.template.json` 훅 경로
- 제외: tmux(`tws`) — Windows 네이티브 미지원 확정

## 작업 목록

- [ ] Windows CI job에 Git Bash로 훅·`atask --dry-run` 스모크 테스트 추가
- [ ] `bash "C:\...\hooks\*.sh"` 경로 변환 동작 확인(`__HOME__` 치환 결과)
- [ ] atask 상태 파일 `$HOME/.claude/arachne-quota-state` 경로 확인
- [ ] #37(date) 수정과 연계해 Windows에서 cooldown 표시 검증
- [ ] 미지원 항목은 `arachne --check`/문서에 명시

## 검증

```powershell
pwsh ./tests/install_windows.ps1
# Git Bash: bash hooks/atask-quota-warn.sh 스모크
```

Windows에서 훅·atask가 동작하거나, 미지원 범위가 명시된다.

## 완료 조건

- Windows에서 신규 훅·atask 동작이 테스트로 확인되거나 한계가 문서화된다.

## 진행 기록

### 2026-06-07

- task 생성: Windows 지원 선언과 런타임 검증의 간극을 닫기 위한 작업.
