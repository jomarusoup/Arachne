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

- **상태**: done
- **우선순위**: high
- **담당**: Claude (Opus)
- **관련 문서**: #26 #31 #32 #37, [[2026-06-07-workflow-01-atask-impl-failover]], [[2026-06-07-postmerge-01-atask-date-portability]]

## 목표

`atask`(arachne-task.sh)의 폴백 의미·쿼터 감지·모델 옵션·날짜 표시 결함을 바로잡아, 디스패처가
역할 제약을 지키고 일반 오류를 소진으로 오판하지 않으며 macOS/Windows에서도 시각이 바르게 표시된다.

## 범위

- 포함: `arachne-task.sh`, `hooks/atask-quota-warn.sh`, `tests/atask.bats`
- 제외: 위임 래퍼 입력 경계(#38 — 별도 task), Windows 런타임 검증(#40 — 별도 task)

## 작업 목록

- [x] #26: `impl` 폴백이 구현 역할을 보존하도록 — 비-claude 후보 처리 시 "역할 제한 래퍼 실행, 역할·커밋 자동 승계 아님, 종료코드 0이 구현 완료 아님" 경고를 stderr에 출력
- [x] #31: `IsQuotaError`에 `NON_QUOTA_PATTERN` 네거티브 가드 추가(`disk quota`·`syntax error` 등 제외) + bare `quota`/`429`를 API 소진 표현으로 정밀화
- [x] #32: atask `-m` 옵션 제거 — CLI별 모델은 `GTASK_MODEL`/`CTASK_MODEL` 환경변수로 분리, 모델 forwarding 제거
- [x] #37: GNU `date -d @N` 의존 제거 — `FmtCooldown`으로 플랫폼 무관 상대시간("~Nm 후") 표시, `atask-quota-warn.sh`도 동일 처리
- [x] 회귀 테스트: `tests/atask.bats`에 #26·#31·#32·#37 케이스 4건 추가(총 16)
- [x] `shellcheck` + `bats tests/atask.bats` 통과
- [x] USAGE §9 atask 레퍼런스에서 `-m` 제거·환경변수 안내 반영(MULTI-CLI §5.1엔 `-m` 미사용)

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

### 2026-06-08

- 4개 이슈 구현 완료 (`arachne-task.sh`·`hooks/atask-quota-warn.sh`·`tests/atask.bats`·`docs/USAGE.md`).
- 검증: `shellcheck -S warning` 통과, `bats tests/*.bats` **75개 전부 green**(신규 4 포함), `check_index.sh` 통과.
- 커밋: **7087f4e** (`fix: atask 정확성 하드닝 (#26·#31·#32·#37)`), origin/main push 완료.
- 설계 메모: #32는 옵션 추가 대신 **제거**로 해결(디스패처는 실행 CLI를 미리 모르므로 단일 모델명이 부적절). #37은 BSD/GNU 분기 대신 **상대시간 표시**로 통일해 플랫폼 분기 자체를 없앰.
- 상태 → **done**. GitHub #26·#31·#32·#37 close 예정.
