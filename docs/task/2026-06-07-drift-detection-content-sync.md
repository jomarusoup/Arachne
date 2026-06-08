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

- **상태**: done
- **우선순위**: medium
- **담당**: Claude (Opus)
- **관련 문서**: #35 #39, [[2026-06-07-postmerge-03-agents-rules-content-sync]]

## 목표

인덱스 검사가 일반 단어 일치로 누락 파일을 통과시키는 오탐을 없애고, AGENTS.md(다이제스트)와
rules/(풀버전)의 **내용** 동기화를 자동 검사해 멀티-CLI SSOT 약속을 내용 단위까지 보장한다.

## 범위

- 포함: `tests/check_index.sh`, 신규 검증 스크립트, `.github/workflows/ci.yml`
- 제외: 규약 내용 자체의 재작성

## 작업 목록

- [x] #35: `check_index.sh` stem 매칭을 **단어 경계(-w)** 로 강화 → 부분일치 false-negative 차단
- [x] #39: `tests/check_convention_sync.sh` 신설 — 네이밍·TDD 단계·git type 핵심 토큰이 AGENTS.md↔rules 양쪽에 존재하는지 검사
- [x] 실제 드리프트 수정: `rules/common/testing.md` TDD 3단계 `IMPROVE` → `REFACTOR`(AGENTS.md·GLOSSARY 정본과 일치) — #39 검사가 잡아낸 실 사례
- [x] 픽스처 테스트: `tests/drift.bats` 4건 — 토큰 누락 픽스처에서 exit 1, -w 단어경계 동작
- [x] CI 연결: `.github/workflows/ci.yml`에 규약 동기화 step 추가, `docs/CI.md §3.7` 문서화

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

### 2026-06-08

- 구현 (`tests/check_index.sh`·신규 `tests/check_convention_sync.sh`·`ci.yml`·`docs/CI.md`·`tests/drift.bats`).
- **실드리프트 발견·수정**: 새 #39 검사가 `testing.md`의 TDD 3단계 `IMPROVE`와 AGENTS.md/GLOSSARY의
  `REFACTOR` 불일치를 잡아냄 → `REFACTOR`로 통일. 검사가 의도대로 작동함을 실증.
- 검증: `shellcheck` 통과, `bats tests/*.bats` **95개 전부 green**(신규 4), `check_index.sh`·`check_convention_sync.sh` PASS.
- 커밋: **c7afec6** (`feat: 드리프트 검출 강화 — 인덱스 단어경계 + 규약 동기화 검사 (#35·#39)`), push 완료.
- 한계(정직): #39는 **토큰 단위** 존재 검사이지 본문 의미 등가까지 보장하진 않음. 새 핵심 규약 추가 시 토큰 목록 갱신 필요.
- 상태 → **done**. GitHub #35·#39 close 예정.
