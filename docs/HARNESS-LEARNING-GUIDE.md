---
Title: "Arachne 학습 순서"
creation: 2026-06-20
modification: 2026-06-20
tags:
 - "arachne"
 - "learning"
aliases:
 - "arachne-learning-guide"
---
MOC:: [[Arachne]]
FROM:: [[100. Project/110. Side-Project/111. Arachne/docs/README]]

# Arachne 학습 순서

이 문서는 Arachne를 업무 능력 개선 도구로 익히기 위한 학습 순서다. 목표는 문서를 외우는 것이 아니라,
작업을 시작하고 끝내는 사고 절차를 반복해서 몸에 붙이는 것이다.

## 0단계: 전체 지형 파악

읽을 문서:

1. [README](../README.md)
2. [docs/README](100.%20Project/110.%20Side-Project/111.%20Arachne/docs/README.md)
3. [docs/CAPABILITY-MAP](CAPABILITY-MAP.md)
4. [docs/GLOSSARY](GLOSSARY.md)

연습:

- 현재 하는 업무 하나를 골라 "제품·아키텍처·언어·검증" 중 어디에 속하는지 표시한다.

## 1단계: 공통 작업 규율

읽을 문서:

1. [rules/common/development-workflow](../rules/common/development-workflow.md)
2. [rules/common/testing](../rules/common/testing.md)
3. [rules/common/security](../rules/common/security.md)
4. [docs/task/README](task/README.md)

연습:

- 작은 수정 작업을 하나 정하고 `docs/task/`에 task를 만든다.
- 수정 전 계획, 수정 후 검증 결과를 task 진행 기록에 남긴다.

## 2단계: TDD와 검증 루프

읽을 문서:

1. [skills/tdd-workflow](../skills/tdd-workflow.md)
2. [skills/verification-loop](../skills/verification-loop.md)
3. [docs/PROJECT-CI](PROJECT-CI.md)

연습:

- 실패하는 테스트를 먼저 만들고, 최소 구현으로 통과시킨다.
- 검증 명령과 결과를 완료 보고에 적는다.

## 3단계: 제품·기획 사고

읽을 문서:

1. [skills/product-lens](../skills/product-lens.md)
2. [skills/product-capability](../skills/product-capability.md)
3. [skills/api-design](../skills/api-design.md)

연습:

- 만들고 싶은 기능 하나에 대해 `누구/고통/왜 지금/MVP/anti-goal/성공 지표`를 쓴다.
- 기능을 capability 2~4개로 쪼갠다.

## 4단계: 아키텍처 기록

읽을 문서:

1. [skills/architecture-decision-records](../skills/architecture-decision-records.md)
2. [docs/decisions](decisions/)
3. [rules/common/patterns](../rules/common/patterns.md)

연습:

- 최근 선택한 기술 결정 하나를 ADR 형식으로 요약한다.
- 대안 2개와 포기한 이유를 반드시 적는다.

## 5단계: UI/UX와 사용자 관점

읽을 문서:

1. [rules/web/design-quality](../rules/web/design-quality.md)
2. [rules/web/ui-layout](../rules/web/ui-layout.md)
3. [skills/frontend-patterns](../skills/frontend-patterns.md)
4. [skills/make-interfaces-feel-better](../skills/make-interfaces-feel-better.md)

연습:

- 기존 화면 하나를 골라 첫 viewport, 정보 위계, 빈 상태, 로딩 상태, 오류 상태를 점검한다.
- before/after 표로 개선안을 작성한다.

## 6단계: Java·Docker 백엔드 트랙

읽을 문서:

1. [rules/java](../rules/java)
2. [skills/java-coding-standards](../skills/java-coding-standards.md)
3. [skills/springboot-patterns](../skills/springboot-patterns.md)
4. [skills/jpa-patterns](../skills/jpa-patterns.md)
5. [rules/docker](../rules/docker)
6. [skills/docker-patterns](../skills/docker-patterns.md)

연습:

- Spring Boot CRUD API 하나를 Controller-Service-Repository로 설계한다.
- Dockerfile과 compose를 만들고 `docker compose config`와 테스트 실행 경로를 확인한다.

## 7단계: Linux 시스템·네트워크 트랙

읽을 문서:

1. [skills/linux-system-network-programming](../skills/linux-system-network-programming.md)
2. [rules/c](../rules/c)
3. [rules/cpp](../rules/cpp)
4. [skills/latency-critical-systems](../skills/latency-critical-systems.md)
5. [skills/memory-check](../skills/memory-check.md)
6. [skills/network-interface-health](../skills/network-interface-health.md)

연습:

- blocking echo server를 nonblocking/epoll 설계로 바꿔 설계 문서를 쓴다.
- fd ownership, partial write, `EINTR`, `EAGAIN`, 종료 경로를 체크리스트로 검토한다.

## 8단계: 멀티 CLI 운영

읽을 문서:

1. [docs/MULTI-CLI](MULTI-CLI.md)
2. [docs/ARCHITECTURE](ARCHITECTURE.md)
3. [rules/common/workflow](../rules/common/workflow.md)

연습:

- 큰 작업을 reader/advisor, tester/fixer, orchestrator 역할로 나눠본다.
- 어떤 작업을 Gemini/Codex에 위임하고 어떤 작업을 직접 통합할지 기록한다.

## 4주 반복 루틴

| 주차 | 목표 | 산출물 |
| --- | --- | --- |
| 1주차 | 공통 규율과 task 기록 | task 2개, 검증 로그 |
| 2주차 | TDD와 검증 습관 | RED/GREEN 기록 1개 |
| 3주차 | 제품·아키텍처 사고 | product brief 1개, ADR 초안 1개 |
| 4주차 | 도메인 트랙 실습 | Java/Docker 또는 Linux network 실습 1개 |

## 완료 기준

- 새 작업을 시작할 때 어떤 규칙과 스킬을 볼지 스스로 고를 수 있다.
- 구현 전 "왜/범위/검증"을 먼저 말할 수 있다.
- 완료 보고에 실행한 검증과 미실행 검증을 구분해 적을 수 있다.
