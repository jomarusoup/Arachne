---
Title: "[enhancement] AGENTS.md(다이제스트) ↔ rules/(풀버전) 내용 동기화 자동 검사 부재"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "postmerge-audit"
 - "issue"
 - "severity/medium"
aliases:
 - "agents-rules-content-sync"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-postmerge-audit]]

# [enhancement] AGENTS.md(다이제스트) ↔ rules/(풀버전) 내용 동기화 자동 검사 부재

- **작성일**: 2026-06-07
- **심각도**: MEDIUM
- **영역**: `tests/check_index.sh`, `AGENTS.md`, `rules/common/*`
- **상태**: 해결됨 — c7afec6 (check_convention_sync.sh 신설, AGENTS↔rules 토큰 일치 CI 검사). task [[2026-06-07-drift-detection-content-sync]]
- **GitHub**: #39

## 문제

`tests/check_index.sh`는 **파일명 인덱스 일치**만 검사하고, AGENTS.md(공통 규약 다이제스트)와
`rules/common/*`(풀버전)의 **내용 동기화는 검사하지 않는다**. 문서도 "내용 동기화는 사람 책임"이라
명시(MULTI-CLI §4.1). 한쪽만 고치면 Gemini/Codex(AGENTS.md)와 Claude(rules/)가 서로 다른 규약을 본다.

## 재현

`rules/common/coding-style.md`의 네이밍 표만 바꾸고 `AGENTS.md §2`를 그대로 두면, CI·`arachne --check`
어디에서도 불일치를 잡지 못한다.

## 영향

멀티-CLI SSOT의 핵심 약속(드리프트 구조적 차단)이 **파일 단위에선 보장되나 내용 단위에선 미보장**.
세 CLI가 미묘하게 다른 규칙으로 동작할 수 있다.

## 원인

AGENTS.md는 손으로 요약한 다이제스트라 rules/ 원본과 자동 연결이 없다.

## 수정 방향

- 경량: 핵심 규약 항목(네이밍 표·TDD 단계·git type 표 등)에 대한 키워드/표 일치 검사 추가.
- 근본: AGENTS.md의 마커 구간을 `rules/`에서 **생성/검증**하는 빌드 스텝(단일 소스화).

## 회귀 테스트

규약 항목 불일치를 심은 픽스처에서 검사 스크립트가 실패(exit 1)하는지 확인.

## 완료 조건

핵심 규약을 한쪽만 수정하면 CI가 드리프트로 차단한다.
