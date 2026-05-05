# /verify — 수정 후 검증

수정할 때마다 반드시 실행. 2단계로 검증한다.

---

## STEP 1 — 정적 검증 (Haiku 에이전트에 위임)

**Haiku 에이전트에 아래 프롬프트를 전달해서 실행한다.**

```
작업 디렉토리: /Users/jomarusoup/Documents/project/taskflow

다음 node 명령을 실행하고 결과를 그대로 보고해라.

node -e "
const fs=require('fs'),vm=require('vm');
const js=fs.readFileSync('taskflow.js','utf8');
const html=fs.readFileSync('taskflow.html','utf8');

try{new vm.Script(js);console.log('✓ SYNTAX OK');}
catch(e){console.log('✗ ERROR:',e.message);process.exit(1);}

let d=0;for(const c of js){if(c==='{')d++;else if(c==='}')d--;}
console.log(d===0?'✓ 괄호 균형':'✗ 불균형 depth='+d);

['renderAll','openModal','saveTask','renderCalendar',
 '_renderEventBars','renderContacts','renderLedger',
 '_populateAssignee','buildExpandPanel'].forEach(fn=>{
  console.log((js.includes('function '+fn)?'✓':'✗')+' '+fn);
});

const cs=(html.match(/colspan=\"(\d+)\"/g)||[]);
console.log('colspan 값들:',cs.join(', '));
"

✗ 항목이 하나라도 있으면 FAILED, 모두 ✓이면 PASSED 라고 최종 판정을 한 줄로 출력해라.
```

Haiku 결과가 **FAILED**면 STEP 2 진행하지 말고 즉시 오류 내용을 나(Sonnet)에게 반환한다.

---

## STEP 2 — 브라우저 검증 (chrome-devtools-mcp, Sonnet이 직접 실행)

STEP 1 PASSED 후 실행. MCP 도구 순서대로 호출한다.

### 2-1. 파일 열기
```
navigate_page: file:///Users/jomarusoup/Documents/project/taskflow/taskflow.html
```

### 2-2. 로드 대기
```
wait_for: selector="#view-dashboard" (timeout 5000ms)
```

### 2-3. 핵심 함수 window 등록 확인
```
evaluate_script:
  const fns = ['renderAll','openModal','saveTask','renderCalendar',
    '_renderEventBars','renderContacts','renderLedger',
    '_populateAssignee','buildExpandPanel','renderInventory'];
  fns.map(fn => (typeof window[fn]==='function' ? '✓ ' : '✗ ') + fn);
```

### 2-4. 콘솔 에러 확인
```
evaluate_script:
  window.__errors = [];
  window.addEventListener('error', e => window.__errors.push(e.message));
  renderAll();
  window.__errors;
```

### 2-5. 스크린샷 (대시보드 기본 상태)
```
take_screenshot
```

### 2-6. 인벤토리 탭 전환 후 스크린샷
```
evaluate_script: switchView('inventory')
take_screenshot
```

---

## 판정 기준

| 결과 | 조치 |
|---|---|
| STEP 1 FAILED | 즉시 수정, 재실행 |
| STEP 2 console error 있음 | 에러 메시지 확인 후 수정 |
| STEP 2 window 함수 ✗ | 해당 함수 선언 위치 grep 후 확인 |
| 스크린샷 레이아웃 깨짐 | CSS 확인 |
| 모두 통과 | /git 진행 가능 |
