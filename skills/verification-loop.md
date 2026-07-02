---
name: verification-loop
description: Claude Code 세션의 포괄적 검증 시스템. 기능 완료·PR 생성·리팩터링 후 품질 게이트 통과 확인.
triggers:
  paths: []
  keywords: ["검증 루프", "세션 검증", "verify", "정적 검사"]
---

# 검증 루프 스킬

Claude Code 세션을 위한 포괄적 검증 시스템.

## 언제 사용하나

- 기능 완료 또는 주요 코드 변경 후
- PR 생성 전
- 품질 게이트 통과 확인이 필요할 때
- 리팩터링 후

## 검증 단계

### 1단계: 빌드 검증

```bash
# 프로젝트 빌드 확인
npm run build 2>&1 | tail -20
# 또는
make clean && make
go build ./...
```

빌드 실패 시 즉시 중단하고 수정.

### 2단계: 타입 검사

```bash
# TypeScript 프로젝트
npx tsc --noEmit 2>&1 | head -30

# Python 프로젝트
pyright . 2>&1 | head -30
```

모든 타입 오류 보고. 중요한 것은 계속 진행 전에 수정.

### 3단계: 린트 검사

```bash
# JavaScript/TypeScript
npm run lint 2>&1 | head -30

# Python
ruff check . 2>&1 | head -30

# C/C++
cppcheck --enable=warning src/ 2>&1 | head -30
```

### 4단계: 테스트 실행

```bash
# 커버리지 포함 테스트
npm run test -- --coverage 2>&1 | tail -50
go test -cover ./...
pytest --cov=src
make test

# 커버리지 목표: 최소 80%
```

보고:
- 전체 테스트: N개
- 통과: N개
- 실패: N개
- 커버리지: N%

### 5단계: 보안 스캔

```bash
# 비밀값 노출 확인
grep -rn "sk-\|api_key\|password\s*=" --include="*.ts" --include="*.c" --include="*.go" . | head -10

# 디버그 출력 잔존 확인
grep -rn "console.log\|\[DEBUG\]\|printf.*DEBUG" src/ | head -10
```

### 6단계: 변경사항 리뷰

```bash
# 변경 내용 확인
git diff --stat
git diff HEAD~1 --name-only
```

각 변경 파일 점검:
- 의도치 않은 변경 없음
- 에러 처리 누락 없음
- 잠재적 엣지 케이스 없음

## 출력 형식

모든 단계 실행 후 검증 리포트 작성:

```
검증 리포트
====================

빌드:     [통과/실패]
타입:     [통과/실패] (N개 오류)
린트:     [통과/실패] (N개 경고)
테스트:   [통과/실패] (N/M 통과, Z% 커버리지)
보안:     [통과/실패] (N개 이슈)
변경:     [N개 파일 변경]

전체:     [PR 준비 완료/미완료]

수정 필요 항목:
1. ...
2. ...
```

## 연속 모드

장시간 세션에서 15분마다 또는 주요 변경 후 검증 실행:

```
체크포인트 설정:
- 각 함수 완료 후
- 컴포넌트 완료 후
- 다음 태스크 이동 전

실행: /verify
```

## 훅과의 통합

이 스킬은 PostToolUse 훅을 보완하지만 더 깊은 검증을 제공한다.
훅은 즉각 문제를 잡고, 이 스킬은 포괄적 리뷰를 제공한다.
