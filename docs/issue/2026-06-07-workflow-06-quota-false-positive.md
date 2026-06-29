---
Title: "[bug] atask 쿼터 휴리스틱이 일반 오류를 소진으로 오판함"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/medium"
aliases:
 - "quota-false-positive"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] atask 쿼터 휴리스틱이 일반 오류를 소진으로 오판함

- **작성일**: 2026-06-07
- **심각도**: MEDIUM
- **영역**: `arachne-task.sh:18-22`, `IsQuotaError`
- **상태**: 해결됨 — 7087f4e (NON_QUOTA 네거티브 가드 + 쿼터 패턴 정밀화). task [[2026-06-07-atask-correctness-hardening]]

## 문제

현재 쿼터 패턴은 다음 일반 문자열도 독립적으로 매칭한다.

```text
quota
429
overloaded
```

예를 들어 다음은 설정 검증 오류지만 쿼터 소진으로 분류된다.

```text
validation failed: quota field is not an integer
```

## 재현 결과

- Claude mock 종료코드: 2
- stderr: 위 validation 오류
- 실제 결과: Claude 쿨다운 등록 후 Codex 실행
- 예상 결과: 일반 오류로 즉시 중단

## 영향

- 정상 가용 CLI가 최대 5시간 쿨다운 처리될 수 있다.
- 원래 오류 원인이 가려지고 다른 CLI 토큰까지 소비한다.
- 상태 파일이 잘못 오염되어 후속 작업 라우팅도 변경된다.
- `atask-quota-warn`이 잘못된 중심 상태를 계속 표시한다.

## 원인

CLI별 오류 형식, 종료코드, HTTP 상태 조합 없이 자유 텍스트 전체에 광범위한 정규식을 적용한다.

## 수정 방향

1. CLI별 quota detector를 분리한다.
2. 가능한 경우 구조화된 오류 코드나 알려진 고정 문구를 사용한다.
3. `429`는 단어 경계와 rate-limit 문맥을 함께 요구한다.
4. 단순 `quota`, `overloaded` 단독 매칭을 제거한다.
5. 불확실한 경우 자동 쿨다운 대신 원본 오류를 보고한다.
6. 상태 파일에 감지 근거와 발생 시각을 기록해 진단 가능하게 한다.

## 회귀 테스트

- 실제 rate-limit fixture는 폴백
- `quota field`, 데이터의 숫자 429, 사용자 프롬프트 내 quota 단어는 폴백하지 않음
- stdout에 작업 내용으로 등장한 quota와 stderr 오류를 구분
- CLI별 대표 오류 fixture 검증

## 완료 조건

- 알려진 쿼터 오류만 쿨다운을 생성한다.
- 일반 오류는 원본 종료코드와 메시지로 즉시 중단한다.
