---
Title: "Arachne 학습 순서"
creation: 2026-06-20
modification: 2026-10-06
tags:
 - "arachne"
 - "learning"
aliases:
 - "arachne-learning-guide"
---
MOC:: [[Arachne]]
FROM:: [[100. Project/110. Side-Project/111. Arachne/docs/README]]

# Arachne 학습 순서

이 문서는 Arachne를 업무 능력을 키우는 도구로 익히기 위한 학습 순서다.
하네스를 처음 쓰는 사람이 무엇을 어떤 순서로 읽고 연습할지 정할 때 읽는다.
목표는 문서를 외우는 것이 아니다. 작업을 시작하고 끝내는 사고 절차를 반복해서 몸에 붙이는 것이 목표다.

자산 전체 목록은 [CAPABILITY-MAP](CAPABILITY-MAP.md)에 있다. 이 문서는 그중 무엇부터 익힐지만 정한다.
0~3단계는 모든 사람이 순서대로 밟는다. 4단계부터는 맡은 업무에 맞는 단계를 골라 밟는다.

## 0단계: 전체 지형 파악

읽을 문서:

1. [README](../README.md)
2. [docs/README](README.md)
3. [docs/ARCHITECTURE](ARCHITECTURE.md) 1~4절 — 설치 배선, Claude Code 단독 운용, 디렉터리 구성, 훅 실행 시점
4. [docs/CAPABILITY-MAP](CAPABILITY-MAP.md)
5. [docs/GLOSSARY](GLOSSARY.md)

연습:

- 지금 하는 업무 하나를 골라 역량 지도의 어느 영역에 속하는지 표시한다.
- 그 업무를 할 때 자동으로 도는 훅이 무엇인지 ARCHITECTURE 4절에서 찾는다.

## 1단계: 공통 작업 규율

읽을 문서:

1. [rules/common/development-workflow](../rules/common/development-workflow.md)
2. [rules/common/agents](../rules/common/agents.md)
3. [rules/common/testing](../rules/common/testing.md)
4. [docs/task/README](task/README.md)

연습:

- 작은 수정 작업을 하나 정하고 `docs/task/`에 task를 만든다.
- 수정 전 계획과 수정 후 검증 결과를 task 진행 기록에 남긴다.
- 그 작업에서 어느 리뷰 에이전트가 돌아야 하는지 `rules/common/agents`의 표로 고른다.

## 2단계: TDD와 검증 루프

읽을 문서:

1. [skills/tdd-workflow](../skills/tdd-workflow/SKILL.md)
2. [skills/verification-loop](../skills/verification-loop/SKILL.md)
3. [docs/PROJECT-CI](PROJECT-CI.md)

연습:

- 실패하는 테스트를 먼저 만들고, 최소 구현으로 통과시킨다.
- 검증 명령과 결과를 완료 보고에 적는다. 실행하지 못한 검증은 따로 구분해 적는다.

## 3단계: 보안 계층과 가드 훅

비밀값과 개인정보는 한 번 새면 되돌릴 수 없다. 그래서 이 단계는 도메인과 관계없이 모두 밟는다.

읽을 문서:

1. [docs/ARCHITECTURE](ARCHITECTURE.md) 7절 — 읽기 차단, 가드 훅, CI 검사, 작성 규약의 네 겹
2. [rules/common/security](../rules/common/security.md)
3. [skills/sensitive-data-handling](../skills/sensitive-data-handling/SKILL.md)
4. [docs/DATA-HANDLING](DATA-HANDLING.md)

연습:

- [tests/guard_hooks.bats](../tests/guard_hooks.bats)에서 가드 훅이 막는 명령과 통과시키는 명령을 한 쌍씩 골라 이유를 설명한다.
- 테스트 fixture에 예시 값을 넣어야 할 때 합성 데이터 표식을 어떻게 다는지 직접 적어 본다.

## 4단계: 제품·기획 사고

읽을 문서:

1. [skills/product-lens](../skills/product-lens/SKILL.md)
2. [skills/product-capability](../skills/product-capability/SKILL.md)
3. [skills/api-design](../skills/api-design/SKILL.md)

연습:

- 만들고 싶은 기능 하나에 대해 `누구/고통/왜 지금/MVP/anti-goal/성공 지표`를 쓴다.
- 기능을 capability 2~4개로 쪼갠다.

## 5단계: 아키텍처 기록

읽을 문서:

1. [skills/architecture-decision-records](../skills/architecture-decision-records/SKILL.md)
2. [docs/decisions](decisions/)
3. [rules/common/patterns](../rules/common/patterns.md)

연습:

- 최근 선택한 기술 결정 하나를 ADR 형식으로 요약한다.
- 대안 2개와 포기한 이유를 반드시 적는다.

## 6단계: 프로젝트 키트

하네스 본체는 모든 프로젝트에 공통으로 적용된다. 프로젝트마다 다른 검증 명령과 코드 골격은 프로젝트 키트로 깐다.

읽을 문서:

1. [docs/ARCHITECTURE](ARCHITECTURE.md) 8절 — 프로필이 깔리는 순서
2. [docs/PROJECT-CI](PROJECT-CI.md)
3. [skills/naming-dictionary](../skills/naming-dictionary/SKILL.md)

연습:

- 빈 디렉터리에 `arachne --init-ci --profile <이름>`을 실행하고, `.arachne/`에 무엇이 생겼는지 확인한다.
- `arachne --project-check`로 깔린 상태를 점검한다.
- C 서버를 다룬다면 `c-system` 프로필로 깔고, 네이밍 사전에 약어 하나를 등록한 뒤 `lib/naming-check.sh`의 보고를 확인한다.

## 7단계: 도메인 트랙

맡은 업무에 맞는 트랙 하나를 고른다. 트랙마다 규칙(rules)과 스킬(skills)을 함께 읽는다.

### 7-A. 3티어 대용량 데이터 처리 시스템

Arachne가 주력으로 지원하는 대상이다. TypeScript 클라이언트, Linux C·Rust 서버, Oracle·PostgreSQL DB가 이어진다.

읽을 문서:

1. [docs/ARCHITECTURE](ARCHITECTURE.md) 9절 — 데이터 한 건이 지나는 길과 담당 자산
2. [docs/CAPABILITY-MAP](CAPABILITY-MAP.md) 7절 — 티어별 자산 표
3. [rules/systems/philosophy](../rules/systems/philosophy.md)와 [ADR-0005](decisions/0005-programming-philosophy.md)
4. [skills/data-throughput-accelerator](../skills/data-throughput-accelerator/SKILL.md)
5. [templates/project/compose-3tier](../templates/project/compose-3tier/README.md)

연습:

- 데이터 채널 하나를 골라 손실 정책(버릴지, 막을지)과 그 이유를 적는다.
- ARCHITECTURE 9절의 여섯 단계(수신·보관·영속화·송신·표시·운영) 중 하나를 골라, 담당 스킬을 읽고 체크리스트를 만든다.

### 7-B. Linux 시스템·네트워크

읽을 문서:

1. [skills/linux-system-network-programming](../skills/linux-system-network-programming/SKILL.md)
2. [rules/c](../rules/c)
3. [rules/cpp](../rules/cpp)
4. [skills/latency-critical-systems](../skills/latency-critical-systems/SKILL.md)
5. [skills/memory-check](../skills/memory-check/SKILL.md)
6. [skills/network-interface-health](../skills/network-interface-health/SKILL.md)

연습:

- blocking echo server를 nonblocking·epoll 설계로 바꾸는 설계 문서를 쓴다.
- fd 소유권, 부분 쓰기, `EINTR`, `EAGAIN`, 종료 경로를 체크리스트로 검토한다.

### 7-C. UI/UX와 사용자 관점

읽을 문서:

1. [rules/web/design-quality](../rules/web/design-quality.md)
2. [rules/web/ui-layout](../rules/web/ui-layout.md)
3. [skills/frontend-patterns](../skills/frontend-patterns/SKILL.md)
4. [skills/make-interfaces-feel-better](../skills/make-interfaces-feel-better/SKILL.md)

연습:

- 기존 화면 하나를 골라 첫 화면, 정보 위계, 빈 상태, 로딩 상태, 오류 상태를 점검한다.
- before/after 표로 개선안을 작성한다.

### 7-D. Java·Docker 백엔드

Java 스킬은 현재 비활성 보관본(`skills/archive/`)이다. 규칙과 Docker 스킬은 현역이다.

읽을 문서:

1. [rules/java](../rules/java)
2. [skills/archive/java-coding-standards](../skills/archive/java-coding-standards.md)
3. [skills/archive/springboot-patterns](../skills/archive/springboot-patterns.md)
4. [skills/archive/jpa-patterns](../skills/archive/jpa-patterns.md)
5. [rules/docker](../rules/docker)
6. [skills/docker-patterns](../skills/docker-patterns/SKILL.md)

연습:

- Spring Boot CRUD API 하나를 Controller-Service-Repository로 설계한다.
- Dockerfile과 compose를 만들고 `docker compose config`와 테스트 실행 경로를 확인한다.

## 8단계: 하네스 자체 운영

하네스를 고치거나 늘리려는 사람이 마지막에 밟는다.

읽을 문서:

1. [docs/ARCHITECTURE](ARCHITECTURE.md) 5~6절 — 규칙이 로드되는 시점, 개발 파이프라인
2. [rules/common/workflow](../rules/common/workflow.md)
3. [docs/AI-ENGINEERING-NOTES](AI-ENGINEERING-NOTES.md)
4. [docs/MULTI-CLI](MULTI-CLI.md) — 공통 규약(`AGENTS.md`)을 다른 CLI에 배포하는 방법

연습:

- 서브에이전트에 일을 맡길 때 위임 프롬프트에 다시 적어야 할 규칙을 `rules/common/agents`에서 찾아 적는다.
- 최근 하네스 변경 하나를 골라, 그 변경이 어느 테스트(`tests/`)로 고정돼 있는지 찾는다.

## 4주 반복 루틴

| 주차 | 목표 | 산출물 |
| --- | --- | --- |
| 1주차 | 공통 규율, task 기록, 보안 계층 | task 2개, 검증 로그, 가드 훅 판정 설명 1개 |
| 2주차 | TDD와 검증 습관 | RED/GREEN 기록 1개 |
| 3주차 | 제품·아키텍처 사고 | product brief 1개, ADR 초안 1개 |
| 4주차 | 프로젝트 키트와 도메인 트랙 실습 | 프로필 적용 프로젝트 1개, 트랙 실습 1개 |

## 완료 기준

- 새 작업을 시작할 때 어떤 규칙과 스킬을 볼지 스스로 고를 수 있다.
- 구현 전에 "왜·범위·검증"을 먼저 말할 수 있다.
- 비밀값이 어느 겹에서 막히는지 설명할 수 있다.
- 완료 보고에 실행한 검증과 실행하지 않은 검증을 구분해 적을 수 있다.
