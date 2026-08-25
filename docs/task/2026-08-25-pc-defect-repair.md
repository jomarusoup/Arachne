---
Title: "[task] PC-1~6 현행 결함 수리 — 상태 파일 경합·쿼터 오판·git-bus·스냅샷"
creation: 2026-08-25
modification: 2026-08-25
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

# [task] PC-1~6 현행 결함 수리 — 상태 파일 경합·쿼터 오판·git-bus·스냅샷

- **상태**: to do
- **우선순위**: high
- **담당**: unassigned
- **관련 문서**: [[2026-08-22-harness-runtime-audit]], [[0003-dynamic-workflows-adoption]] (ADR-0003 — 수리는 도입 게이트가 아니라 수리 자체가 목적)

## 목표

감사 [현행 결함] B-01~05·B-11과 [도입 제약] C-01~04를 수리해, ADR-0003 선결조건
체크리스트 PC-1~PC-6이 "tests/ 에 검증 테스트가 있고 통과한다" 형태로 닫힌다.

## 범위

- 포함: `arachne-task.sh`(쿼터 패턴·상태 파일 동시성), `hooks/git-bus-check.sh`(로컬 HEAD
  폴백·rebase 미탐), `hooks/session-end.sh`(B-11 덮어쓰기), 각 항목 회귀 테스트
- 제외: dynamic workflows 도입 여부 판단(ADR-0003), PC-7~10(별도 task), 계측 코드
  (`MetricAppend` — 완료됨, [[2026-08-25-metrics-baseline]])

## 작업 목록

- [ ] PC-4 (B-01~03): `QUOTA_PATTERN` 정비 — `429` 단어 경계, bare `overloaded`·`usage limit`
  정리, stdout 스캔 범위 재검토, `NON_QUOTA_PATTERN` 부분문자열(`compil` 등) 정리.
  이슈 `2026-06-07-workflow-06-quota-false-positive` 재오픈 → 반영 → 종결
- [ ] PC-1 (C-01·C-03): `SetCooldown` 동시 기록 보존 — 동시 10+ 프로세스 경합 bats 테스트 추가
- [ ] PC-2 (C-02): 상태 파일 교체를 동일 파일시스템 rename으로 (`mktemp -p "${STATE_DIR}"`)
- [ ] PC-3 (C-04): `CooldownUntil`/`InCooldown` 비수치 값 안전 기본값 처리
- [ ] PC-5 (B-04·B-05): git-bus — 업스트림 미설정 브랜치 무공지, `LAST_SEEN` 도달 불가
  (rebase/force-push) 시 무공지 점프 대신 경고
- [ ] PC-6 (B-11): session-end.sh 스냅샷을 비-git CWD에서 미기록(또는 세션·프로젝트 구분 저장)
- [ ] 각 항목 회귀 테스트 추가 + `tests/README.md` 갱신

## 검증

```bash
bats tests/atask.bats tests/metrics.bats tests/hooks.bats tests/solo_mode.bats tests/smoke.bats
shellcheck -S warning arachne-task.sh hooks/git-bus-check.sh hooks/session-end.sh
```

기대: 신규 경합·오판 회귀 테스트 포함 전부 통과, 기존 28+10 케이스 무회귀.

## 완료 조건

- ADR-0003의 PC-1~PC-6 각 항목이 명시한 "테스트 존재 + 통과" 판정을 만족한다.
- workflow-06 이슈가 코드 반영 근거와 함께 종결 상태다.

## 진행 기록

### 2026-08-25

- task 생성: 감사(B/C 결함 분류)와 ADR-0003 "도입과 무관하게 진행" 결정에서 파생.
