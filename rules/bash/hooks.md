---
paths:
  - "**/*.sh"
  - "**/*.bash"
---
# Bash 훅

> [common/hooks.md](../common/hooks.md) 를 확장한다.

## PostToolUse — 편집 후 자동 실행

```bash
# shellcheck — 정적 분석
shellcheck "$FILE"

# 실행 권한 확인
[ -x "$FILE" ] || chmod +x "$FILE"
```

## 커밋 전 체크

```bash
# 모든 .sh 파일 정적 분석
find . -name "*.sh" -exec shellcheck {} \;

# 문법 검사
bash -n script.sh
```
