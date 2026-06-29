---
Title: "[task] 하네스 역할·플랫폼 설명 정확화 반영 검증 및 #36 종료"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
tags:
 - "project"
 - "task"
 - "priority/low"
aliases:
 - "docs-accuracy-verify-close"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-harness-role-platform-accuracy]]

# [task] 하네스 역할·플랫폼 설명 정확화 반영 검증 및 #36 종료

- **상태**: done
- **우선순위**: low
- **담당**: Claude (Opus)
- **관련 문서**: #36, [[2026-06-07-harness-role-platform-accuracy]]

## 목표

`docs/harness-role-platform-accuracy` 브랜치 병합으로 반영된 역할·플랫폼 정확화 내용이 현재 main에
모순 없이 남아 있는지 검증하고, 충족되면 #36을 종료한다.

## 범위

- 포함: README·MULTI-CLI·ARCHITECTURE·GLOSSARY·CLAUDE의 역할/플랫폼 서술 검증
- 제외: 신규 문서 작성

## 작업 목록

- [x] 정확화 서술 검증: "실행 후보 폴백"(7파일)·"마커 병합 사본"(10)·"coreutils"(6)·"자동 승계 아님"(6) 모두 main에 일관 존재
- [x] 모순 점검: USAGE 지원 표가 "Windows 부분 지원(install.ps1 CI 검증, Git Bash 훅·atask 미검증)"으로 정확. 옛 "Windows 미지원" 단정 없음. `tws Windows 미지원`은 사실(tmux는 WSL만)이라 정확
- [x] `gh issue close 36` (수용 근거 코멘트 포함)

## 검증

```bash
git grep -n "실행 후보 폴백\|마커 병합 사본\|coreutils" -- '*.md'
```

정확화 서술이 main에 일관되게 존재한다.

## 완료 조건

- 정확화 내용이 검증되고 #36이 종료된다.

## 진행 기록

### 2026-06-07

- task 생성: 내용은 병합으로 반영됨 → 검증·종료만 남은 저우선 작업.

### 2026-06-08

- 검증 완료: 정확화 서술이 main에 일관 존재(실행후보폴백 7파일·마커병합 10·coreutils 6·자동승계아님 6).
  USAGE 지원 표가 "Windows 부분 지원(install.ps1 CI 검증, Git Bash 훅·atask 미검증)"으로 정확 — 옛 "미지원" 단정 없음.
- 신규 코드 변경 없음(검증·종료 task). 상태 → **done**, GitHub #36 close 예정.
- 후속: Git Bash 훅·atask 런타임 "미검증"은 별도 task(windows-runtime-verification, #40)에서 다룬다.
