---
Title: "[task] 계측 기준선 4주 수집·판독 — ADR-0003 재평가 입력"
creation: 2026-08-25
modification: 2026-08-29
status: "done"
tags:
 - "arachne"
 - "task"
 - "priority/medium"
aliases:
 - "metrics-baseline"
---
MOC:: [[Arachne]]
FROM:: [[0003-dynamic-workflows-adoption]]

# [task] 계측 기준선 4주 수집·판독 — ADR-0003 재평가 입력

- **상태**: done (조기 종결 — 측정 대상 소멸)
- **우선순위**: medium
- **담당**: unassigned
- **관련 문서**: [[0003-dynamic-workflows-adoption]], [[2026-08-22-harness-runtime-audit]]

## 목표

래퍼 호출·쿨다운 진입 계측(2026-08-25 가동, 커밋 `ab013eb`)을 4주 축적한 뒤 판독해,
ADR-0003 재평가 트리거의 "측정 불가" 항목(오프로드 절약량·쿨다운 진입 빈도·감사류 작업
빈도)을 실측으로 대체한다. **판독 시점: 2026-09-22 이후.**

## 범위

- 포함: 로그 축적 상태 점검(주 1회 수준), 2026-09-22 이후 1회 판독·기록
- 제외: 분석·집계 도구 제작(금지 — 지금 필요한 것은 축적뿐), 계측 코드 변경,
  dynamic workflows 재평가 판단 자체(트리거 충족 시 ADR-0003 개정으로)

## 작업 목록

- [x] 계측 구현·테스트·가동 (2026-08-25, `ab013eb` — `~/.claude/metrics/`)
- [ ] 수집 상태 점검: `wrapper-calls-*.log`·`cooldown-entries-*.log`가 계속 쌓이는지,
  테스트 오염(rc=0 스텁 기록)이 없는지 확인
- [ ] 2026-09-22 이후 판독: 주당 래퍼 호출 수(레인별), 쿨다운 진입 횟수, 오프로드 추정
  절약량을 이 문서 진행 기록에 수치로 기록
- [ ] ADR-0003 재평가 트리거 대조: 감사류 월 4회 이상? 절약 실측이 워크플로 비용
  (+0.4M/실행)과 같은 자릿수? → 충족 시 ADR 개정 발의, 미충족 시 (A) 유지 기록

## 검증

```bash
ls -la ~/.claude/metrics/
wc -l ~/.claude/metrics/*.log
# 필드: wrapper-calls = ts·래퍼·레인·모드·rc·pid / cooldown-entries = ts·cli·레인·pid (TSV)
```

기대: 월 파일이 append-only로 증가, 90일 초과 파일은 자동 prune.

## 완료 조건

- 4주 치 실측 수치가 이 문서에 기록되고, ADR-0003 재평가 트리거 충족 여부 판정이
  근거와 함께 남는다 (충족/미충족 어느 쪽이든 완료).

## 진행 기록

### 2026-08-29

- **조기 종결**: [[0004-remove-3lane-runtime]] (ADR-0004)로 3-레인 런타임과 계측 코드
  (`MetricAppend`)가 `archive/multi-cli/`로 제거되어 측정 대상이 소멸했다. 4주 판독은
  수행하지 않는다. ADR-0003 재평가 트리거 중 "오프로드 절약 실측" 축은 무의미해졌고,
  "감사 fan-out 한계 2회 문서화" 축만 유효하게 남는다. 수집됐던 로그(127 가드 4건)는
  `~/.claude/metrics/`에 잔존하며 90일 후 자동 소멸.

### 2026-08-25

- task 생성: ADR-0003 "계측 2건 — 도입과 무관하게 진행" 이행. 계측 가동 완료,
  4주 시계 시작. wrapper_security.bats 격리 누락으로 인한 초기 오염 4줄은 제거함.
