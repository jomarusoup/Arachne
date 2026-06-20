---
name: architecture-decision-records
description: 중요한 설계 결정을 ADR로 기록한다. 선택 배경, 대안, 결정, 결과, 리스크를 docs/decisions에 남기는 기준.
---

# Architecture Decision Records

설계 결정이 대화나 기억에만 남지 않게 구조화해 기록한다.

## 언제 사용하나

- 프레임워크, DB, 메시징, 배포 방식, 인증 방식 등 중요한 선택을 할 때
- "왜 이 방식을 택했는가"를 나중에 설명해야 할 때
- 대안이 여러 개이고 트레이드오프가 명확할 때
- 기존 결정을 바꾸거나 폐기할 때

## 저장 위치

Arachne는 `docs/decisions/`를 사용한다.

파일명:

```text
NNNN-short-title.md
```

## ADR 템플릿

```markdown
# ADR-NNNN: 결정 제목

**Date**: YYYY-MM-DD
**Status**: proposed | accepted | deprecated | superseded
**Deciders**: 이름 또는 역할

## Context

결정을 요구한 문제, 제약, 힘의 방향을 적는다.

## Decision

선택한 결정을 짧고 명확하게 쓴다.

## Alternatives Considered

### 대안 1
- Pros:
- Cons:
- Why not:

## Consequences

### Positive
### Negative
### Risks
```

## Arachne 운영 원칙

- 새 ADR을 만들기 전에 기존 `docs/decisions/`를 검색한다.
- 결정 없는 조사 문서는 `docs/idea/` 또는 `docs/issue/`에 둔다.
- 구현 task는 ADR을 링크하고, ADR은 구현 세부가 아니라 결정 이유를 보존한다.
