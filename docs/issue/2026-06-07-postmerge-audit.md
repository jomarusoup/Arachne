---
Title: "[audit] 병합 후 허점 검수 (copilot·windows·atask 통합 이후)"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "postmerge-audit"
 - "audit"
aliases:
 - "postmerge-audit"
---
MOC:: [[Arachne]]
FROM:: [[Arachne]]

# [audit] 병합 후 허점 검수 — copilot·windows·atask 통합 이후

- **작성일**: 2026-06-07
- **범위**: 5개 브랜치(copilot·windows·task-aliases·audit·harness-role) main 병합 + `atask` 신설 이후
- **선행 감사**: [[2026-06-07-workflow-audit]] (workflow-01~10, GitHub #26~35)

기존 workflow 감사가 다루지 못한, **새로 병합된 코드**에서 발견한 허점을 정리한다.
AI-ENGINEERING-NOTES.md의 5개 주제 중 하네스에 **미적용**인 영역(특히 §3 프롬프트 인젝션)을 포함한다.

## 발견 항목

| 파일 | 제목 | 심각도 | GitHub |
| --- | --- | --- | --- |
| [[2026-06-07-postmerge-01-atask-date-portability]] | GNU `date -d` 의존 → macOS/Windows 표시 깨짐 | LOW | #37 |
| [[2026-06-07-postmerge-02-wrapper-input-boundary]] | 위임 래퍼 입력 경계·최소권한 부재 (인젝션) | HIGH | #38 |
| [[2026-06-07-postmerge-03-agents-rules-content-sync]] | AGENTS.md ↔ rules/ 내용 동기화 자동 검사 부재 | MEDIUM | #39 |
| [[2026-06-07-postmerge-04-windows-hooks-untested]] | 신규 훅·atask Windows 미검증 | MEDIUM | #40 |

## 우선순위

1. **#38 (HIGH)** — 노트 §3 방어 원칙 미적용. 지식↔코드 정합성 회복의 1순위.
2. **#39 (MEDIUM)** — 멀티-CLI SSOT 약속의 내용 단위 보강.
3. **#40 (MEDIUM)** — Windows 지원 선언과 런타임 검증의 간극.
4. **#37 (LOW)** — 표시 결함, 크래시 아님.

## 관련

- [AI-ENGINEERING-NOTES.md](../AI-ENGINEERING-NOTES.md) — 5개 주제의 하네스 적용 현황(§ "하네스 적용 현황")
