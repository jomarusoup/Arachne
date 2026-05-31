---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Go 코딩 스타일

> [common/coding-style.md](../common/coding-style.md) 를 확장한다.

## 헤더 형식

`/* */` 블록 주석 지원 → C 스타일 그대로 사용.

```go
/*#############################################################################
FILE NAME   : 파일명.go
DESCRIPTION : 파일 역할 한 줄 요약
DATA        : YYYY-MM-DD
Modification: YYYY-MM-DD
#############################################################################*/

/*=============================================================================
FUNCTION    : FunctionName
DESCRIPTION : 역할 설명
PARAMETERS  : type 인자명 - 설명
RETURNED    : 반환값 설명
=============================================================================*/
```

## 포매팅

- `gofmt` + `goimports` 필수 — 커밋 전 자동 실행
- 탭 들여쓰기 (Go 공식 규칙 준수, common의 4 스페이스 예외)

## 중괄호 스타일 — K&R

```go
func ProcessData(value int) error {
    if value < 0 {
        return fmt.Errorf("invalid value: %d", value)
    }
    return nil
}
```

## 에러 처리

- 에러는 항상 래핑해서 컨텍스트 추가

```go
/* BAD */
return err

/* GOOD */
return fmt.Errorf("ParseConfig: %w", err)
```

- `errors.Is` / `errors.As` 로 에러 타입 비교
- 에러 무시 금지 (`_` 로 에러 버리기 금지)

## 설계 원칙

- 인터페이스 수락, 구조체 반환
- 인터페이스는 작게 (1~3 메서드)
- 고루틴 생성 시 반드시 종료 조건 명시

## 네이밍 (Go 전용)

- 공개 식별자: `PascalCase` (`GetServerInfo`)
- 비공개 식별자: `camelCase` (`parseHeader`)
- 패키지명: 짧은 `lowercase` (`ipc`, `net`, `config`)
- 전역 변수: `g_SnakeCase` (공통 규칙 준수)

## 디버그 출력

```go
log.Printf("[DEBUG] value=%v\n", value)     /* 배포 전 제거 */
log.Printf("[PROJECTNAME] msg=%v\n", msg)   /* 운영 경고 */
```
