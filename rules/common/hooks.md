---
paths:
  - "**/settings.json"
  - "**/settings.local.json"
  - "**/hooks/*.sh"
---
# 훅 시스템

Claude Code 이벤트에 반응하는 자동화 훅 기준.

## 훅 유형

| 훅                 | 실행 시점        | 용도                      |
| ------------------ | ---------------- | ------------------------- |
| `PreToolUse`       | 도구 실행 전     | 검증, 파라미터 수정, 차단 |
| `PostToolUse`      | 도구 실행 후     | 자동 포맷, 린트, 분석     |
| `UserPromptSubmit` | 메시지 입력 시   | 상태 체크, 알림           |
| `SessionStart`     | 세션 시작 시     | 컨텍스트 로드, 상태 안내  |
| `Stop`             | 세션 종료 시     | 스냅샷 저장, 정리         |
| `PreCompact`       | 컨텍스트 압축 전 | 상태 저장                 |

## 종료 코드와 결정 출력

- `0` — 성공. PreToolUse 훅은 stdout에 결정 JSON을 출력해 허용·확인·거부를 정할 수 있다.
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny|ask|allow","permissionDecisionReason":"..."}}`
  아무것도 출력하지 않으면 평소 권한 흐름을 따른다.
- `2` — 차단. stderr가 Claude에게 전달된다.
- 그 밖의 코드 — 차단하지 않는 오류로 처리된다. 가드 스크립트가 고장 나도 작업이 멈추지 않게
  훅에서는 `set -e`를 쓰지 않는다.

## Arachne 보안 가드

`hooks/guard-bash.sh`와 `hooks/guard-secrets.sh`는 PreToolUse(Bash)에 등록된다. 검사 우회는 거부하고,
파괴적 명령·비밀 파일 읽기·개인정보가 의심되는 커밋은 사용자 확인을 받거나 거부한다. 판정 기준은
`tests/guard_hooks.bats`에 쌍(막아야 할 것·통과해야 할 것)으로 고정돼 있다.

가드는 실수를 막는 장치이지 보안 경계가 아니다. 비밀 파일 접근의 1차 경계는 `settings.json`의
`permissions.deny`다. deny 규칙에는 예외를 둘 수 없으므로 `.env.*`처럼 넓게 잡지 말고 파일명을
나열한다(`.env.example`은 읽을 수 있어야 한다).

## PostToolUse 공통 권장 훅

| 대상                 | 동작                            |
| -------------------- | ------------------------------- |
| `Edit` / `Write`     | 저장 후 언어별 린터·포매터 실행 |
| `Bash(git commit *)` | 커밋 전 staged 파일 품질 검사   |
| `Bash(git push *)`   | 푸시 전 변경 내용 요약 출력     |

## 훅 등록 위치

`~/.claude/settings.json` 의 `hooks` 섹션에 등록:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "~/.claude/hooks/post-edit.sh" }]
      }
    ]
  }
}
```

## 주의사항

- `dangerouslyAllowPermissions` 플래그 사용 금지
- 탐색적 작업 중에는 auto-accept 비활성화
- 훅 스크립트는 빠르게 실행되어야 함 (블로킹 최소화)
