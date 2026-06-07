---
Title: "[audit] Arachne main 워크플로우 허점 검수"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "workflow"
 - "audit"
aliases:
 - "workflow-audit-2026-06-07"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [audit] Arachne main 워크플로우 허점 검수

- **작성일**: 2026-06-07
- **유형**: audit
- **검수 기준**: `main@bb5fece`
- **범위**: Arachne 저장소 자체의 설치·위임·세션·Git·CI 워크플로우

> `main` 아카이브에서 Bats 65개, ShellCheck, settings 검증, 인덱스 검증은 모두
> 통과했다. 아래 항목은 그 상태에서도 별도 반례로 재현된 워크플로우 허점이다.
> 즉 단순한 테스트 실패가 아니라 현재 테스트가 다루지 못하는 불변식과 통합 경계 문제다.

---

## 요약

| 번호 | 심각도 | 영역 | 핵심 문제 | 상세 문서 |
| --- | --- | --- | --- | --- |
| 01 | HIGH | 자동 페일오버 | `atask impl`이 구현 금지 래퍼를 호출하고 성공으로 판정 | [01](2026-06-07-workflow-01-atask-impl-failover.md) |
| 02 | HIGH | Git | `/git`이 브랜치·검증·변경 소유권 없이 전체 변경을 push | [02](2026-06-07-workflow-02-git-command-guardrails.md) |
| 03 | HIGH | 설치 | Claude `settings.json` 사용자 설정을 재설치 때 덮어씀 | [03](2026-06-07-workflow-03-settings-destructive-reinstall.md) |
| 04 | HIGH | 세션 | 저장과 복원 경로가 달라 인계 파일을 찾지 못함 | [04](2026-06-07-workflow-04-session-path-split.md) |
| 05 | MEDIUM | git-bus | `.claude` 디렉터리 부재 시 기준점 저장 실패 | [05](2026-06-07-workflow-05-git-bus-state-write.md) |
| 06 | MEDIUM | 자동 페일오버 | 광범위한 문자열 패턴으로 일반 오류를 쿼터로 오판 | [06](2026-06-07-workflow-06-quota-false-positive.md) |
| 07 | MEDIUM | 모델 라우팅 | 하나의 `-m` 값을 서로 다른 CLI에 그대로 전달 | [07](2026-06-07-workflow-07-model-routing.md) |
| 08 | MEDIUM | 업데이트 | `arachne -u`가 현재 브랜치와 dirty 상태를 검증하지 않음 | [08](2026-06-07-workflow-08-update-branch-safety.md) |
| 09 | LOW | 설치 | 특정 타깃 설치도 dotfiles와 전체 bin을 수정 | [09](2026-06-07-workflow-09-target-side-effects.md) |
| 10 | LOW | CI | 인덱스 검사가 일반 단어 일치로 누락 파일을 통과시킴 | [10](2026-06-07-workflow-10-index-false-negative.md) |

## 공통 원인

1. 문서에 선언된 불변식이 실행 코드에서 강제되지 않는다.
2. 단위 테스트는 정상 경로와 종료 코드 중심이며 산출물 의미를 검증하지 않는다.
3. 설치·세션·위임 경계마다 상태 소유권이 명확하지 않다.
4. fail-open 훅이 오류를 숨기지만 별도 진단 수단은 제공하지 않는다.
5. 문자열 기반 휴리스틱이 구조화된 상태 검증을 대신한다.

## 권장 처리 순서

1. **Phase 1**: 01, 02, 03, 04
2. **Phase 2**: 05, 06, 07, 08
3. **Phase 3**: 09, 10

각 항목은 별도 브랜치와 PR로 처리한다. 01·06·07은 모두 `atask`를 수정하지만 동작 계약이
다르므로 테스트를 먼저 독립적으로 추가한 뒤 마지막에 통합하는 편이 안전하다.
