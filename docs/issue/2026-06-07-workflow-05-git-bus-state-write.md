---
Title: "[bug] git-bus 기준점 파일이 .claude 부재 시 저장되지 않음"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/medium"
aliases:
 - "git-bus-state-write"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] git-bus 기준점 파일이 .claude 부재 시 저장되지 않음

- **작성일**: 2026-06-07
- **심각도**: MEDIUM
- **영역**: `hooks/session-end.sh`, `hooks/gemini-check.sh`
- **상태**: 일반 Git 저장소에서 재현 완료

## 문제

`session-end.sh`의 `UpdateGeminiRef`는 다음 경로에 직접 기록한다.

```bash
echo "$current_head" > "$repo_dir/.claude/last-seen-commit"
```

그러나 `$repo_dir/.claude`를 생성하지 않는다. Arachne 자체 저장소가 아닌 일반 프로젝트에서는
해당 디렉터리가 없을 수 있다.

## 재현

1. 빈 임시 Git 저장소를 생성하고 첫 커밋을 만든다.
2. `.claude` 디렉터리는 만들지 않는다.
3. `session-end.sh`를 실행한다.
4. `No such file or directory`가 발생하고 기준점 파일은 생성되지 않는다.

훅은 `set -e`를 의도적으로 사용하지 않으므로 전체 종료는 성공처럼 보일 수 있다.

## 영향

- 다음 UserPromptSubmit에서 git-bus 기준점이 없어 최초 실행으로 처리된다.
- 외부 커밋 알림이 누락되거나 기준점이 예상과 다르게 초기화된다.
- 사용자는 훅이 설치됐지만 작동하지 않는 상태를 알아채기 어렵다.

## 원인

상태 파일 쓰기 전 부모 디렉터리 보장과 쓰기 결과 검사가 없다.

## 수정 방향

1. `mkdir -p "$repo_dir/.claude"` 후 기록한다.
2. 임시 파일 작성 후 atomic rename을 사용한다.
3. 실패 시 훅을 막지는 않더라도 진단 로그를 남긴다.
4. `.claude`를 프로젝트에 만들지 않는 정책이면 전역 state root와 repo hash를 사용한다.
5. `session-end`와 `gemini-check`가 동일한 state resolver를 공유한다.

## 회귀 테스트

- `.claude` 없는 저장소에서 기준점 생성
- read-only 저장소에서는 명확한 경고
- state 파일이 부분 기록되지 않음
- 여러 저장소의 기준점이 섞이지 않음

## 완료 조건

- 일반 Git 저장소에서도 기준점이 안정적으로 저장된다.
- 실패가 조용히 삼켜지지 않고 진단 가능하다.
