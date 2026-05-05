## 파일 헤더

모든 소스 파일 맨 위에 헤더 블록 작성해 해당 파일의 이름과 설명을 찾을 수 있고 최초 작성일과 수정된 일자를 기록

```
/******************************************************************************
FILE NAME   : 파일명.확장자
DESCRIPTION : 파일 역할 한 줄 요약
DATA        : YYYY-MM-DD
Modification: YYYY-MM-DD
******************************************************************************/
```

## 함수 주석

함수마다 헤더 주석 작성. 간단한 유틸은 한 줄 주석 허용.

```
/******************************************************************************
FUNCTION    : 함수명
DESCRIPTION : 역할 설명
PARAMETERS  : type 인자명 - 설명
              type 인자명 - 설명
RETURNED    : 반환값 설명 (void면 생략)
******************************************************************************/
```


## 네이밍

| 형식 | 예시 | 적용 대상 |
|---|---|---|
| `snake_case` | `task_count` | 지역 변수, 함수 인자 (Go, JS) |
| `g_SnakeCase` | `g_UserList` | 전역 변수 (JS: `let tasks`, Go: package-level) |
| `PascalCase` | `GetTaskList` | 함수·메서드, 타입, 클래스 |
| `SCREAMING_SNAKE_CASE` | `MAX_RETRY_COUNT` | 상수, 매크로, 환경변수 |
| `camelCase` | `taskCount` | JS 객체 속성, JSON 키 |

공통 규칙:
- 이름 길이 최대 30자
- 이름만 보고 역할 추측 가능해야 함
- 단일 문자 변수 금지 (`i` → `ii`, `j` → `jj`)
- 임시 변수는 `ii`, `jj`, `tmp`, `len` 허용
- `a`, `b`, `c` 절대 금지

## 변수선언

대상: 모든 언어

- 한 줄에 변수 하나만 선언
- 전역 변수는 반드시 초기값 지정
- 관련 변수는 열 맞춤(column alignment)


```js
let g_Tasks     = [];
let g_Settings  = {};
let g_EditingId = null;
```

```go
var (
    g_UserList  []User = nil
    g_MaxRetry  int    = 3
    g_IsRunning bool   = false
)
```

## 포매팅

- 들여쓰기: 4 스페이스 (탭 문자 금지)
- 줄 끝 공백 제거
- 파일 끝 빈 줄 1개

### 중괄호 스타일 비교

| 스타일 | 구조적 특징 | 시각적 형상 |
| :--- | :--- | :--- |
| Allman | 중괄호 `{ }`가 수직으로 완벽하게 정렬됨 | `[` 모양의 대칭 구조 |
| K&R | 여는 중괄호가 구문 끝에 붙어 행을 절약함 | `L` 모양의 흐름 구조 |

#### Allman 스타일 (C / C++)
```cpp
void ProcessData(int value)
{
    if (value > 0)
    {
        printf("Positive\n");
    }
    else
    {
        printf("Non-positive\n");
    }
}
```

#### K&R 스타일 (Go / JS)
```go
func processData(value int) {
    if value > 0 {
        fmt.Println("Positive")
    } else {
        fmt.Println("Non-positive")
    }
}
```

#### [주의] JavaScript — ASI 문제로 Allman 금지
```javascript
// WRONG: return 다음 줄에 { } → ASI가 세미콜론 삽입 → undefined 반환
return
{
    data: "success"
};

// CORRECT: K&R 스타일 사용
return {
    data: "success"
};
```

## 디버그 출력

디버그용 출력은 맨 앞에 붙여서 일반 로직과 구분.

```js
// JavaScript
console.log('[DEBUG]', variable);      // 디버그 (배포 전 제거)
console.warn('[TASKFLOW]', message);   // 경고 (유지 가능)
```

```go
// Go
log.Printf("[DEBUG] %v\n", variable)   // 디버그 (배포 전 제거)
log.Printf("[TASKFLOW] %v\n", message) // 경고
```
