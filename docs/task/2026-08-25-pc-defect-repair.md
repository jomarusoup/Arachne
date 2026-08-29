---
Title: "[task] 현행 결함 수리 — git-bus 오탐/미탐·스냅샷 덮어쓰기 (B-04·05·11)"
creation: 2026-08-25
modification: 2026-08-29
status: "to do"
tags:
 - "arachne"
 - "task"
 - "priority/high"
aliases:
 - "pc-defect-repair"
---
MOC:: [[Arachne]]
FROM:: [[2026-08-22-harness-runtime-audit]]

# [task] 현행 결함 수리 — git-bus 오탐/미탐·스냅샷 덮어쓰기 (B-04·05·11)

- **상태**: to do
- **우선순위**: high
- **담당**: unassigned
- **관련 문서**: [[2026-08-22-harness-runtime-audit]], [[0003-dynamic-workflows-adoption]] (ADR-0003 — 수리는 도입 게이트가 아니라 수리 자체가 목적)

## 목표

감사 [현행 결함] 중 잔존분 B-04·B-05(git-bus)·B-11(스냅샷)을 수리한다.

> **2026-08-29 범위 축소**: [[0004-remove-3lane-runtime]]로 atask/래퍼 런타임이 제거되어
> B-01~03·B-07·B-08·C-01~04(쿼터 오판·상태 파일 경합 일체)는 수리 대상에서 소멸했다.
> 재도입 시에는 archive README의 절차대로 선수리가 조건이다.

## 범위

- 포함: `hooks/git-bus-check.sh`(로컬 HEAD 폴백·rebase 미탐), `hooks/session-end.sh`
  (B-11 덮어쓰기), 각 항목 회귀 테스트
- 제외: archive된 atask/래퍼 결함(ADR-0004로 소멸), dynamic workflows 판단(ADR-0003),
  PC-7~10(별도 task)

## 작업 목록

- [ ] B-04·B-05: git-bus — 업스트림 미설정 브랜치 무공지, `LAST_SEEN` 도달 불가
  (rebase/force-push) 시 무공지 점프 대신 경고
- [ ] B-11: session-end.sh 스냅샷을 비-git CWD에서 미기록(또는 세션·프로젝트 구분 저장)
- [ ] 각 항목 회귀 테스트 추가 + `tests/README.md` 갱신

## 검증

```bash
bats tests/hooks.bats tests/smoke.bats
shellcheck -S warning hooks/git-bus-check.sh hooks/session-end.sh
```

기대: 신규 회귀 테스트 포함 전부 통과.

## 완료 조건

- B-04·B-05·B-11 각각 "테스트 존재 + 통과" 판정을 만족한다.

## 진행 기록

### 2026-08-29

- 범위 축소: ADR-0004로 atask/래퍼 런타임 제거 — B-01~03·07·08·C-01~04 소멸, B-04·05·11 잔존.

### 2026-08-25

- task 생성: 감사(B/C 결함 분류)와 ADR-0003 "도입과 무관하게 진행" 결정에서 파생.
