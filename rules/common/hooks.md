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

## 종료 코드

- `0` — 성공 (경고 출력 가능)
- `2` — 차단 (PreToolUse에서만 유효, 도구 실행 중단)

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
