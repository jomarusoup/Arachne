---
description: AI 전환 전 현재 작업 상태를 HANDOFF.md에 저장
---
# /handoff — AI 전환 전 상태 저장

Gemini(또는 다른 AI)로 전환하기 전에 실행.
HANDOFF.md를 현재 상태로 갱신한다.

**매번 자동 저장 안 함 — 이 커맨드 실행 시에만 갱신.**

---

## 실행 순서

### 1. 현재 상태 수집

```bash
git log --oneline -3
git status --short
git diff --stat
```

### 2. HANDOFF.md 갱신

아래 항목을 업데이트한다:

```markdown
## 마지막 갱신
- 날짜: 오늘 날짜
- 작업자: Claude Sonnet
- 커밋: `[해시]` [커밋 메시지]

## 프로젝트 스냅샷
- 브랜치: [현재 브랜치]
- 미커밋 파일: [있으면 목록]

## 완료된 주요 작업
[이번 세션에서 완료한 작업 추가]

## 미처리 이슈
[현재 남은 작업 / GitHub 이슈 번호]

## 다음 세션이 할 일
[명확한 다음 작업]
```

### 3. 완료 보고

```
HANDOFF.md 갱신 완료.
Gemini 전환: 프로젝트 디렉토리에서 gemini 실행
첫 메시지: "HANDOFF.md 읽고 이어서 진행해줘"
```

---

## 갱신 기준

- 큰 기능 완료 후 git push 직후
- Gemini로 전환하기 직전
- 사용자 명시 요청 시
