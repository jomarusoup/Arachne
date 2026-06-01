---
description: git 커밋·푸시. GitHub MCP 연결 시 Claude Code 안에서 바로 실행.
---

# /git $ARGUMENTS

**이 스킬은 Haiku 에이전트에 위임한다.**

아래 프롬프트로 `Agent(model: "haiku")` 를 즉시 호출한다. 추가 판단 없이 호출만 하면 된다.

---

## Haiku 에이전트에 전달할 프롬프트

```
다음 순서로 git 커밋·푸시를 실행해라.

커밋 메시지 인수: "$ARGUMENTS"

### 1. 변경사항 확인
```bash
git diff --stat
git status --short
```

### 2. 커밋 메시지 결정
인수가 있으면 그것을 사용.
없으면 변경사항 분석 후 아래 형식으로 결정:

  feat     새 기능
  fix      버그 수정
  style    UI·CSS 변경
  refactor 코드 구조 개선
  docs     문서 수정
  chore    설정 변경

예) fix: 널 포인터 역참조 수정

### 3. README.md 동기화 (생략)
README.md 업데이트는 Gemini CLI가 담당한다. 이 단계에서는 README.md를 직접 수정하지 않는다.

### 4. 커밋 & 푸시
```bash
git add -A
git commit -m "[커밋 메시지]"
git push
```

### 5. 결과 보고
커밋 해시와 푸시 결과를 한 줄로 보고.
```
