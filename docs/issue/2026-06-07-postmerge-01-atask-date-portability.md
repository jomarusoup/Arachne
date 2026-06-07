---
Title: "[bug] atask·atask-quota-warn 의 GNU date -d 의존으로 macOS/Windows 시각 표시 깨짐"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "postmerge-audit"
 - "issue"
 - "severity/low"
aliases:
 - "atask-date-portability"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-postmerge-audit]]

# [bug] atask·atask-quota-warn 의 GNU `date -d` 의존으로 macOS/Windows 시각 표시 깨짐

- **작성일**: 2026-06-07
- **심각도**: LOW
- **영역**: `arachne-task.sh:231,259`, `hooks/atask-quota-warn.sh:31`
- **상태**: 해결됨 — 7087f4e (FmtCooldown 상대시간, GNU date -d 제거). task [[2026-06-07-atask-correctness-hardening]]
- **GitHub**: #37

## 문제

쿨다운 만료 시각을 사람이 읽게 변환할 때 GNU 전용 `date -d "@<epoch>"`를 사용한다.
macOS 기본 BSD `date`와 Windows에는 `-d`가 없어 변환이 실패한다. 프로젝트가 copilot·windows
브랜치 병합으로 macOS(coreutils)·Windows 지원을 선언한 것과 모순된다.

## 재현

```bash
# BSD date 환경(macOS) 또는 Git Bash 일부
date -d "@1750000000"   # → 오류 (invalid date / -d 미지원)
ATASK_COOLDOWN_CLAUDE=10 atask --dry-run -R impl "x"   # cooldown 시각이 '?' 로 표시
```

## 영향

`|| echo '?'` / `|| CooldownUntil` 폴백이 있어 크래시는 없으나, 회복 시각이 `?` 또는 raw epoch로
표시돼 사전 경고 배너·`--dry-run`의 정보가 깨진다. 기능 자체는 죽지 않는 표시 결함.

## 원인

`date +%s`(현재 epoch)는 BSD에서도 동작하지만, epoch → 사람 시각 변환 `date -d @N`은 GNU 전용이다.

## 수정 방향

- 플랫폼 분기: GNU `date -d @N`, BSD `date -r N`.
- 또는 플랫폼 무관하게 **상대 시간**("약 N분 후")으로 표시(`(until - now)/60`).

## 회귀 테스트

`tests/atask.bats`에 BSD/GNU 모두에서 cooldown 표시가 `?`가 아닌 유효 문자열을 내는지 검증 추가.

## 완료 조건

macOS·Linux·Git Bash 셋에서 `atask --dry-run`의 cooldown 시각이 사람이 읽을 수 있게 표시된다.
