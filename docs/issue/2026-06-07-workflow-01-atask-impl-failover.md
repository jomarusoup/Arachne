---
Title: "[bug] atask impl 페일오버가 구현 역할을 보존하지 않음"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/high"
aliases:
 - "atask-impl-failover"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] atask impl 페일오버가 구현 역할을 보존하지 않음

- **작성일**: 2026-06-07
- **심각도**: HIGH
- **영역**: `arachne-task.sh`, `codex-task.sh`, `gemini-task.sh`
- **상태**: 해결됨 — 7087f4e (impl 비-claude 후보 역할·커밋 비승계 경고). task [[2026-06-07-atask-correctness-hardening]]

## 문제

`atask -R impl`은 `claude → codex → gemini` 순서로 실행하지만, Codex와 Gemini 단계에서는
각각 tester/fixer와 reader/advisor 전용 래퍼를 호출한다.

- `arachne-task.sh:278-289`: `codex-task`, `gemini-task` 호출
- `codex-task.sh:27-31`: 새 기능 추가 금지, 기본 읽기 모드
- `gemini-task.sh:29-30`: 구현이 아닌 읽기·요약·자문 역할

따라서 중심 역할이 Codex나 Gemini로 이양된다는 문서 계약과 실제 프롬프트 계약이 충돌한다.

## 재현

1. Claude mock은 429 오류를 반환한다.
2. Codex mock은 파일을 변경하지 않고 “proposal only”를 출력한 뒤 0을 반환한다.
3. `atask -R impl -w "implement feature"`를 실행한다.
4. `atask`는 Codex를 “처리 완료”로 판정하고 0으로 종료한다.

실제 작업 완료 여부나 Git diff 발생 여부는 확인하지 않는다.

## 영향

- 구현 요청이 제안문만 반환한 채 성공 처리될 수 있다.
- 호출자는 후속 검증 없이 기능이 구현됐다고 오인할 수 있다.
- Gemini까지 내려가면 “최종 구현 금지” 정책과 직접 충돌한다.
- 자동 페일오버의 핵심 불변식인 역할 보존이 깨진다.

## 원인

CLI 우선순위와 작업 역할을 별개로 모델링하지 않고, 기존 위임 래퍼를 그대로 재사용했다.
또한 성공 조건이 하위 프로세스 종료코드 0 하나뿐이다.

## 수정 방향

1. `impl`용 Codex/Gemini 호출 경로를 tester/reader 래퍼와 분리한다.
2. 역할별 프리앰블을 `impl`, `read`, `test`, `review`로 명시한다.
3. 쓰기 작업은 시작 전 HEAD와 작업트리 상태를 기록한다.
4. 성공 후 예상 산출물을 검증한다.
   - 구현: diff 또는 명시적 결과 계약
   - 테스트: 테스트 실행 결과
   - 읽기·리뷰: 비어 있지 않은 응답
5. Gemini 구현 페일오버를 유지할지 정책적으로 재검토한다.

## 회귀 테스트

- Codex가 제안만 출력하고 diff를 만들지 않으면 `impl` 성공 처리 금지
- `impl` Codex 프롬프트에 “기능 추가 금지”가 포함되지 않음
- `test` 역할에는 기존 tester/fixer 제약이 유지됨
- Gemini 구현 단계의 허용 여부와 사람 승인 게이트 검증

## 완료 조건

- 역할이 바뀌지 않은 채 CLI만 교체된다.
- 성공 종료는 역할별 완료 조건을 만족할 때만 가능하다.
- 문서의 L1/L2 중심 이양 설명과 실제 호출 프롬프트가 일치한다.
