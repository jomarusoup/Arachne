---
Title: "[bug] /git 명령에 브랜치·검증·변경 소유권 가드가 없음"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/high"
aliases:
 - "git-command-guardrails"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] /git 명령에 브랜치·검증·변경 소유권 가드가 없음

- **작성일**: 2026-06-07
- **심각도**: HIGH
- **영역**: `commands/git.md`, Git 워크플로우
- **상태**: 해결됨 — 4bafe62 (commands/git.md에 소유권·브랜치·검증·non-ff 가드 추가). task [[2026-06-07-git-command-guardrails]]

## 문제

`/git`은 다음 명령을 직접 실행하도록 지시한다.

```bash
git add -A
git commit -m "..."
git push
```

그러나 다음 항목을 검사하지 않는다.

- 현재 브랜치가 `main`인지
- upstream이 의도한 원격 브랜치인지
- `/verify`가 실제 실행·통과했는지
- 작업트리에 다른 세션이나 사용자의 변경이 섞였는지
- 새 비밀값·대용량 산출물·로컬 설정이 포함됐는지
- push가 force 또는 예상 밖 원격으로 향하는지

## 영향

- `main`에 직접 커밋·push할 수 있다.
- `git add -A`가 무관한 dirty 파일까지 한 커밋에 포함한다.
- 테스트하지 않은 변경도 자동 push 흐름을 탈 수 있다.
- 다중 세션에서 다른 작업자의 변경을 함께 커밋할 수 있다.
- 저장소 규약의 “한 브랜치 한 관심사”와 “유일 커미터”를 보장하지 못한다.

## 원인

`/git`이 상태 검증기가 아니라 단순 명령 매크로로 작성됐다. `/verify`와 `/git` 사이에도
검증 결과를 전달하는 상태 계약이 없다.

## 수정 방향

1. 기본적으로 `main` 직접 커밋을 거부한다.
2. 현재 브랜치, upstream, ahead/behind, dirty 목록을 출력한다.
3. 전체 추가 대신 작업 관련 pathspec을 결정하거나 사용자 확인을 받는다.
4. staged diff를 대상으로 비밀값·대용량 파일 검사를 수행한다.
5. 검증 명령과 결과를 커밋 직전에 다시 확인한다.
6. 새 브랜치는 `git push -u origin <branch>`를 사용한다.
7. 예상 HEAD를 기록하고 push 전 HEAD 이동 여부를 검사한다.

## 회귀 테스트

- `main`에서 `/git` 실행 시 명시적 승인 없이는 중단
- 무관한 untracked 파일이 자동 staged 되지 않음
- 테스트 실패 상태에서 commit 차단
- upstream 없는 새 브랜치는 올바른 원격 브랜치로 push
- staged secret fixture가 있으면 중단

## 완료 조건

- `/git`이 “검증 → 선택적 stage → commit → push” 순서를 강제한다.
- 커밋 대상과 원격 대상이 결과 보고에 명시된다.
- 다른 세션의 변경을 조용히 포함하지 않는다.
