---
Title: "[task] atask 정확성 하드닝 — 페일오버 역할·쿼터 오판·모델 라우팅·날짜 이식성"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "project"
 - "task"
 - "priority/high"
aliases:
 - "atask-correctness-hardening"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [task] atask 정확성 하드닝

- **상태**: planned
- **우선순위**: high
- **담당**: unassigned
- **관련 문서**: #26 #31 #32 #37, [[2026-06-07-workflow-01-atask-impl-failover]], [[2026-06-07-postmerge-01-atask-date-portability]]

## 목표

`atask`(arachne-task.sh)의 폴백 의미·쿼터 감지·모델 옵션·날짜 표시 결함을 바로잡아, 디스패처가
역할 제약을 지키고 일반 오류를 소진으로 오판하지 않으며 macOS/Windows에서도 시각이 바르게 표시된다.

## 범위

- 포함: `arachne-task.sh`, `hooks/atask-quota-warn.sh`, `tests/atask.bats`
- 제외: 위임 래퍼 입력 경계(#38 — 별도 task), Windows 런타임 검증(#40 — 별도 task)

## 작업 목록

- [ ] #26: `impl` 폴백이 구현 역할을 보존하도록 — Codex/Gemini 단계가 tester/reader 제약을 유지하고 "중심·커밋 권한 자동 승계 없음"을 코드·출력에 명시
- [ ] #31: `IsQuotaError` 패턴이 일반 오류(`syntax error` 등)를 소진으로 오판하지 않도록 패턴 정밀화(종료코드 + 패턴 조합)
- [ ] #32: 단일 `-m` 모델 옵션이 서로 다른 CLI 모델 공간을 혼합하지 않도록 — CLI별 모델 지정 분리 또는 거부
- [ ] #37: GNU `date -d @N` 의존 제거 — BSD `date -r`/GNU 분기 또는 "N분 후" 상대 표시
- [ ] 회귀 테스트: 위 4건 각각 bats 케이스 추가
- [ ] `shellcheck` + `bats tests/atask.bats` 통과
- [ ] USAGE/MULTI-CLI 관련 서술 갱신

## 검증

```bash
bats tests/atask.bats
shellcheck -S warning arachne-task.sh hooks/atask-quota-warn.sh
```

일반 오류는 폴백하지 않고, cooldown 시각이 macOS/Linux 모두 사람이 읽을 수 있게 표시된다.

## 완료 조건

- #26·#31·#32·#37의 회귀 테스트가 추가되고 전부 green.
- atask가 역할 승계 오해를 일으키지 않는 출력·문서를 가진다.

## 진행 기록

### 2026-06-07

- task 생성: workflow·postmerge 감사에서 atask 관련 4개 이슈를 하나의 하드닝 작업으로 묶음.
