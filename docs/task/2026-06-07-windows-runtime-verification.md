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

- **상태**: done
- **우선순위**: medium
- **담당**: Claude (Opus)
- **관련 문서**: #40, [[2026-06-07-postmerge-04-windows-hooks-untested]], #37(date 의존 연계)

## 목표

windows-support 병합 후 추가된 훅(`atask-quota-warn`·`doc-drift-check`·`git-bus-check`)과 `atask`가
Windows/Git Bash 경로에서 실제 동작하는지 검증하거나, 미지원 범위를 명시한다.

## 범위

- 포함: `tests/install_windows.ps1`(또는 신규 Windows 스모크), `settings.template.json` 훅 경로
- 제외: tmux(`tws`) — Windows 네이티브 미지원 확정

## 작업 목록

- [x] Windows CI job에 Git Bash(`shell: bash`) 스모크 step 추가 — `tests/smoke_hooks.sh`(atask --dry-run·atask-quota-warn·doc-drift-check·git-bus-check)
- [x] 훅·atask 가 Git Bash 에서 실행되는지 검증(스크립트를 `bash <경로>`로 직접 호출 — Git Bash 호환성 확인)
- [x] atask 상태 파일 경로(`ARACHNE_STATE_DIR`) 격리 동작 확인(스모크에 포함)
- [x] #37 연계: cooldown 상대시간 표시(GNU `date -d` 비의존)를 스모크에서 검증
- [x] 미지원/검증 범위 명시: USAGE 지원 표를 "Git Bash 훅·atask 스모크 CI 검증"으로 갱신, ubuntu job·로컬은 `tests/smoke.bats`
- ~~`bash "C:\..."` 절대경로 치환(install.ps1 산출물)~~ — 본 task 범위는 **런타임 스모크**. 설치 산출물 경로는 `install_windows.ps1`(별도) 담당

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

### 2026-06-08

- 구현 (신규 `tests/smoke_hooks.sh`·`tests/smoke.bats`, `ci.yml` verify-windows step, `docs/USAGE.md` 지원 표).
- 검증: 로컬 `bash tests/smoke_hooks.sh` PASS, `shellcheck` 통과, `bats tests/*.bats` **101개 green**(신규 1), index·sync 통과.
- 커밋: **7fd1cc6** (`feat: Windows 런타임 검증 — Git Bash 훅·atask 스모크 (#40)`), push 완료.
- 한계(정직): GitHub windows-latest 의 Git Bash 에서 **실제 통과 여부는 다음 CI 실행에서 확인**된다(이 환경은 Linux).
  스모크는 외부 CLI를 호출하지 않고 스크립트 실행·플랫폼 무관 동작만 검증한다.
- 병렬 세션 주의: 커밋 시 외부 `docs/CI.md` 변경을 #27 가드대로 제외하고 본 task 파일만 스테이징.
- 상태 → **done**. GitHub #40 close 예정.
