---
description: 세션 시작 시 git 상태·미완료 이슈·최근 변경 빠르게 파악
---
# /status — 프로젝트 현황 확인

세션 시작 시 현재 상태를 빠르게 파악.

```bash
echo "=== Git 상태 ==="
git status --short
git log --oneline -5

echo "=== 브랜치 ==="
git branch -v

echo "=== 미커밋 변경 ==="
git diff --stat

echo "=== 최근 세션 ==="
ls -t .claude/sessions/*.md 2>/dev/null | head -3

echo "=== 미구현 TODO ==="
sgrep "TODO\|FIXME\|미구현" | head -10
```

## 출력 후 확인 사항

1. 미커밋 변경이 있으면 이전 세션 작업 파악
2. 최근 세션 파일 읽어 컨텍스트 복원
3. 오픈 이슈 확인: `/issue`
