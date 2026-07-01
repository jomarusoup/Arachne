---
Title: "[task] Docs structure separation"
creation: 2026-07-01
modification: 2026-07-01
status: "done"
tags:
 - "arachne"
 - "task"
 - "priority/medium"
 - "documentation"
aliases:
 - "docs-structure-separation"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [task] Docs structure separation

- **상태**: done
- **우선순위**: medium
- **담당**: Codex
- **관련 문서**: [docs/README](../README.md)

## 목표

문서 인덱스와 기록 디렉터리의 경계를 더 분명하게 만들어, 새 사용자가 어떤 문서를 먼저 읽고 어디에 새 기록을 남길지 빠르게 판단할 수 있게 한다.

## 범위

- 포함:
  - `docs/README.md`의 문서 분류와 진입점 정리
  - `docs/issue/`, `docs/idea/`, `docs/decisions/` 안내 README 추가
  - 변경된 문서 링크와 목록 검증
- 제외:
  - 기존 문서 파일 이동 또는 이름 변경
  - `tools/understand-anything.md`의 기존 미커밋 변경 수정

## 작업 목록

- [x] 문서 인덱스를 정본 문서와 기록 문서로 구분한다.
- [x] 기록 디렉터리별 README를 추가한다.
- [x] 변경된 문서 링크와 파일 목록을 검증한다.

## 검증

```bash
rg -n "issue/README|idea/README|decisions/README|빠른 선택|문서 유형" README.md issue/README.md idea/README.md decisions/README.md
git diff --check
```

기대 결과: 새 구분 안내가 검색되고, diff 공백 오류가 없다.

## 완료 조건

- 사용 목적별 문서 구분이 `docs/README.md`에서 한눈에 보인다.
- `issue/`, `idea/`, `decisions/` 각각의 작성 기준이 디렉터리 내부에 있다.
- 검증 명령이 통과한다.

## 진행 기록

### 2026-07-01

- task 생성: 문서 파일 이동 없이 인덱스와 기록 디렉터리 README를 보강하는 방향으로 착수했다.
- 완료: `docs/README.md`를 Guide, Operations, Profiles, Design, Tools & UI/UX, Records로 재구성했다.
- 완료: `issue/README.md`, `idea/README.md`, `decisions/README.md`를 추가해 기록 위치 판단 기준을 분리했다.
- 검증: `rg -n "issue/README|idea/README|decisions/README|빠른 선택|문서 유형" README.md issue/README.md idea/README.md decisions/README.md` 통과.
- 검증: `git diff --check` 통과.
- 커밋: `docs: clarify documentation structure`.
