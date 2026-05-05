# /fix [버그 설명]

버그 수정 워크플로우. **파일 전체 읽기 금지.**

## 실행 순서
```
1. grep으로 위치 찾기
   grep -n "키워드\|함수명" taskflow.js | head -10   # JS 버그
   grep -n "클래스\|키워드" taskflow.css | head -10  # CSS 버그

2. 해당 범위만 view로 확인
   (시작줄 ~ 끝줄만)

3. 수정

4. /verify 실행

5. 결과 보고
```

## 예시
```
/fix 캘린더 바가 겹침
/fix 업무추가 모달이 열리지 않음
/fix 연락처 정렬 안됨
/fix expand panel 필드가 겹침
```
