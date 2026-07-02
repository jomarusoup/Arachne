---
name: agent-architecture-audit
description: 에이전트·하네스·자동화 구조를 감사해 역할 경계, 상태 저장, 위임, 검증, 실패 복구 위험을 점검한다.
triggers:
  paths: []
  keywords: ["하네스 감사", "에이전트 구조", "역할 경계", "위임 검증", "harness audit"]
---

# Agent Architecture Audit

AI 하네스나 자동화 시스템의 구조를 점검하는 스킬이다.

## 점검 항목

- 역할 경계: planner, implementer, reviewer, tester가 섞여 있지 않은가?
- 상태 저장: 세션 상태, task, decision, output이 어디에 남는가?
- 위임 계약: 위임 대상이 할 수 있는 일과 금지된 일이 명확한가?
- 검증: 자동화 결과를 CI 또는 로컬 명령으로 확인하는가?
- 실패 복구: 중단, timeout, quota, 충돌, partial write를 다루는가?
- 보안: prompt injection, secret exposure, command injection 경계가 있는가?

## 출력 형식

```markdown
# Architecture Audit

## 요약
## 강점
## 위험
## 누락된 검증
## 우선순위별 개선안
```

## Arachne 적용

하네스 자체 변경은 [docs/ARCHITECTURE](../docs/ARCHITECTURE.md), [docs/MULTI-CLI](../docs/MULTI-CLI.md),
[rules/common/workflow](../rules/common/workflow.md)를 함께 확인한다.
