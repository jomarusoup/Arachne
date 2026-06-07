---
Title: "[bug] atask 단일 모델 옵션이 서로 다른 CLI 모델 공간을 혼합함"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/medium"
aliases:
 - "atask-model-routing"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] atask 단일 모델 옵션이 서로 다른 CLI 모델 공간을 혼합함

- **작성일**: 2026-06-07
- **심각도**: MEDIUM
- **영역**: `arachne-task.sh:53-56`, CLI별 호출부
- **상태**: 코드 경로 확인 완료

## 문제

`atask -m MODEL`의 하나의 값을 Claude, Codex, Gemini 호출에 모두 전달한다.

```text
claude --model MODEL
codex-task -m MODEL
gemini-task -m MODEL
```

세 제품의 모델 식별자는 서로 호환된다는 보장이 없다.

## 실패 시나리오

1. 사용자가 Gemini 모델을 지정해 read 역할을 실행한다.
2. Gemini가 쿼터로 실패해 Codex나 Claude로 폴백한다.
3. 동일 모델명이 다음 CLI에 전달되어 invalid model 오류가 발생한다.
4. 일반 오류이므로 캐스케이드가 즉시 중단된다.

반대 방향으로 Claude나 Codex 모델명을 지정해도 같은 문제가 생긴다.

## 영향

- 모델을 명시하는 순간 자동 페일오버 신뢰성이 낮아진다.
- 쿼터 폴백이 모델 검증 오류에서 중단된다.
- 사용자는 어느 CLI에 적용되는 옵션인지 usage만으로 알기 어렵다.

## 원인

라우팅 대상과 모델 선택을 하나의 전역 옵션으로 모델링했다.

## 수정 방향

1. `--claude-model`, `--codex-model`, `--gemini-model`로 분리한다.
2. 짧은 `-m`을 유지한다면 첫 번째 CLI에만 적용하거나 역할별 기본 대상만 적용한다.
3. CLI별 환경변수 fallback을 지원한다.
4. dry-run에 실제 CLI별 모델을 출력한다.
5. 미지정 CLI는 각 도구 기본 모델을 사용한다.

## 회귀 테스트

- Gemini 모델이 Codex/Claude 호출에 전달되지 않음
- Claude 모델이 Gemini 호출에 전달되지 않음
- dry-run 출력에 모델 매핑 표시
- 일부 모델만 지정한 캐스케이드 동작

## 완료 조건

- 서로 다른 CLI의 모델 namespace가 섞이지 않는다.
- 모델 지정 여부와 무관하게 폴백 경로가 유효하다.
