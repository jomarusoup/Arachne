---
Title: "[bug] 인덱스 검사가 일반 단어 일치로 누락 파일을 통과시킴"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/low"
aliases:
 - "index-false-negative"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] 인덱스 검사가 일반 단어 일치로 누락 파일을 통과시킴

- **작성일**: 2026-06-07
- **심각도**: LOW
- **영역**: `tests/check_index.sh:CheckReferenced`
- **상태**: 해결됨 — c7afec6 (check_index stem 매칭을 단어경계 -w로 강화). task [[2026-06-07-drift-detection-content-sync]]

## 문제

인덱스 검사는 파일명 또는 확장자를 제거한 stem이 문서 어디에든 문자열로 등장하면 통과한다.

```bash
grep -qF "$base" index.md || grep -qF "$stem" index.md
```

`skills/test.md`처럼 stem이 일반 단어인 경우 실제 항목으로 등록되지 않아도 문서 본문에 `test`가
한 번 등장하는 것만으로 통과한다.

## 재현

1. `main` 아카이브에 `skills/test.md`를 추가한다.
2. `skills/README.md`와 `docs/USAGE.md`는 수정하지 않는다.
3. `bash tests/check_index.sh`를 실행한다.
4. 결과는 `[PASS] 인덱스 일치`와 종료코드 0이다.

## 영향

- CI가 인덱스 드리프트를 차단한다는 보장이 약해진다.
- 짧거나 흔한 파일명일수록 false negative 가능성이 높다.
- 새 명령·에이전트·스킬이 사용자 문서에서 누락될 수 있다.

## 원인

Markdown 구조를 검사하지 않고 전역 substring 검색을 사용한다.

## 수정 방향

1. 인덱스에 canonical path를 명시하도록 형식을 표준화한다.
2. 예: `skills/test.md` 같은 canonical path의 정확한 등록을 요구한다.
3. Markdown 링크 parser 또는 경계가 있는 정규식을 사용한다.
4. 역방향 검사도 추가한다.
   - 문서가 존재하지 않는 파일을 참조하는지
   - 파일이 두 번 등록됐는지
5. 짧은 stem fixture를 포함한다.

## 회귀 테스트

- `skills/test.md`, `commands/add.md` 같은 일반 단어 stem 누락 탐지
- 정확한 Markdown 링크가 있으면 통과
- 깨진 링크 탐지
- 중복 항목 탐지
- README 제외 규칙 유지

## 완료 조건

- 단순 본문 단어 등장으로는 인덱스 등록으로 인정되지 않는다.
- 파일시스템과 문서 인덱스가 양방향으로 일치한다.
