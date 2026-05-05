# /status — 프로젝트 현황 확인

세션 시작 시 현재 상태를 빠르게 파악.

```bash
echo "=== 파일 크기 ==="
wc -l taskflow.html taskflow.css taskflow.js

echo "=== 최신 세션 ==="
ls -t .claude/sessions/*.md | head -3

echo "=== 함수 수 ==="
grep -c "^function " taskflow.js

echo "=== colspan 현황 ==="
grep -o 'colspan="[0-9]*"' taskflow.html | sort | uniq -c

echo "=== 미구현 TODO ==="
grep -n "TODO\|FIXME\|미구현\|\[ \]" taskflow.js taskflow.css | head -10
```
