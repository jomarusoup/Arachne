---
Title: "[task] 드리프트 검출 강화 — 인덱스 오탐·AGENTS↔rules 내용 동기화"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "project"
 - "task"
 - "priority/medium"
aliases:
 - "drift-detection-content-sync"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [task] 드리프트 검출 강화

- **상태**: planned
- **우선순위**: medium
- **담당**: unassigned
- **관련 문서**: #35 #39, [[2026-06-07-postmerge-03-agents-rules-content-sync]]

## 목표

인덱스 검사가 일반 단어 일치로 누락 파일을 통과시키는 오탐을 없애고, AGENTS.md(다이제스트)와
rules/(풀버전)의 **내용** 동기화를 자동 검사해 멀티-CLI SSOT 약속을 내용 단위까지 보장한다.

## 범위

- 포함: `tests/check_index.sh`, 신규 검증 스크립트, `.github/workflows/ci.yml`
- 제외: 규약 내용 자체의 재작성

## 작업 목록

- [ ] #35: `check_index.sh`가 stem 부분일치가 아닌 **정확한 파일명 토큰**으로 검사하도록 강화(오탐 제거)
- [ ] #39: 핵심 규약 항목(네이밍 표·TDD 단계·git type 표)에 대한 AGENTS↔rules 일치 검사 추가, 또는 AGENTS 마커 구간을 rules에서 생성/검증
- [ ] 픽스처 테스트: 누락/불일치를 심으면 검사가 exit 1
- [ ] CI에 신규 검사 연결

## 검증

```bash
bash tests/check_index.sh
# 불일치 픽스처에서 exit 1 확인
```

파일명 오탐이 사라지고, 규약 한쪽만 수정하면 CI가 차단한다.

## 완료 조건

- #35·#39 검사가 CI에서 강제되고 픽스처로 검증된다.

## 진행 기록

### 2026-06-07

- task 생성: 인덱스 오탐과 내용 동기화 모두 "드리프트 검출" 범주라 묶음.
