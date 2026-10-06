---
Title: "Arachne 역량 지도"
creation: 2026-06-20
modification: 2026-10-06
tags:
 - "arachne"
 - "capability"
aliases:
 - "arachne-capability-map"
---
MOC:: [[Arachne]]
FROM:: [[100. Project/110. Side-Project/111. Arachne/docs/README]]

# Arachne 역량 지도

이 문서는 "이 일을 할 때 Arachne의 어떤 자산을 쓰는가"를 영역별 표로 정리한 지도다.
새 업무를 시작할 때나 자산이 빠진 영역을 찾을 때 읽는다. 구조와 흐름은 [ARCHITECTURE](ARCHITECTURE.md)에 있다.

Arachne는 Python·Web과 C/C++·Go·Rust 시스템 개발을 기본으로 지원한다. 그 위에 제품 판단, 아키텍처 기록,
Docker 운영, Linux 시스템·네트워크 프로그래밍을 연결하고, 3티어 대용량 데이터 처리 시스템(7절)을 주력 대상으로 다룬다.

## 1. 공통 업무 규율

| 목적 | 자산 |
| --- | --- |
| 작업 흐름 | [rules/common/development-workflow](../rules/common/development-workflow.md), [rules/common/workflow](../rules/common/workflow.md) |
| 이슈·작업 기록 | [docs/task/README](task/README.md), [docs/template/task](template/task.md) |
| TDD | [skills/tdd-workflow](../skills/tdd-workflow/SKILL.md), [rules/common/testing](../rules/common/testing.md) |
| 검증 | [skills/verification-loop](../skills/verification-loop/SKILL.md), [docs/PROJECT-CI](PROJECT-CI.md) |
| 보안 | [skills/security-review](../skills/security-review/SKILL.md), [rules/common/security](../rules/common/security.md) |
| 비밀값·개인정보 | [skills/sensitive-data-handling](../skills/sensitive-data-handling/SKILL.md), 가드 훅과 읽기 차단([ARCHITECTURE 7절](ARCHITECTURE.md#7-security-layers--비밀값개인정보-보호)) |

## 2. 제품·기획·사용자 관점

| 목적 | 자산 |
| --- | --- |
| 만들 이유 검증 | [skills/product-lens](../skills/product-lens/SKILL.md) |
| 구현 가능한 capability 분해 | [skills/product-capability](../skills/product-capability/SKILL.md) |
| UI/UX 방향 | [rules/web/design-quality](../rules/web/design-quality.md), [skills/make-interfaces-feel-better](../skills/make-interfaces-feel-better/SKILL.md) |
| API 사용자 경험 | [skills/api-design](../skills/api-design/SKILL.md) |

## 3. 아키텍처

| 목적 | 자산 |
| --- | --- |
| 장기 결정 기록 | [skills/architecture-decision-records](../skills/architecture-decision-records/SKILL.md), [docs/decisions](decisions/) |
| 계층·경계 설계 | [rules/common/patterns](../rules/common/patterns.md), [skills/backend-patterns](../skills/backend-patterns/SKILL.md) |
| 데이터 계약 | [skills/json-contracts](../skills/json-contracts/SKILL.md), [docs/DATA-HANDLING](DATA-HANDLING.md) |

## 4. Java 백엔드

| 목적 | 자산 |
| --- | --- |
| Java 기본 규칙 | [rules/java](../rules/java), [skills/java-coding-standards](../skills/archive/java-coding-standards.md) |
| Spring Boot 구조 | [skills/springboot-patterns](../skills/archive/springboot-patterns.md) |
| Spring Security | [skills/springboot-security](../skills/archive/springboot-security.md) |
| Spring TDD/검증 | [skills/springboot-tdd](../skills/archive/springboot-tdd.md), [skills/springboot-verification](../skills/archive/springboot-verification.md) |
| JPA/Hibernate | [skills/jpa-patterns](../skills/archive/jpa-patterns.md) |

## 5. Docker·배포

| 목적 | 자산 |
| --- | --- |
| Dockerfile/Compose 규칙 | [rules/docker](../rules/docker) |
| Docker 패턴 | [skills/docker-patterns](../skills/docker-patterns/SKILL.md) |
| 배포 운영 | [skills/deployment-patterns](../skills/deployment-patterns/SKILL.md) |
| 프로젝트 CI | [docs/PROJECT-CI](PROJECT-CI.md) |

## 6. Linux 시스템·네트워크

| 목적 | 자산 |
| --- | --- |
| Linux system/network programming | [skills/linux-system-network-programming](../skills/linux-system-network-programming/SKILL.md) |
| C 시스템 규칙 | [rules/c](../rules/c) |
| C++ 시스템 규칙 | [rules/cpp](../rules/cpp) |
| 저지연 시스템 | [skills/latency-critical-systems](../skills/latency-critical-systems/SKILL.md) |
| 메모리 검사 | [skills/memory-check](../skills/memory-check/SKILL.md) |
| 네트워크 운영 진단 | [skills/network-interface-health](../skills/network-interface-health/SKILL.md), [skills/network-config-validation](../skills/archive/network-config-validation.md) |

## 7. 3티어 대용량 데이터 처리 시스템

클라이언트(TypeScript 웹·Electron) ↔ Linux 서버(C·Rust) ↔ DB(Oracle·PostgreSQL)로 이어지는 시스템이다.
티어 사이의 데이터 흐름은 [ARCHITECTURE 9절](ARCHITECTURE.md#9-3-tier-system-support-map--대용량-시스템-지원-지도)에 그림으로 있다.

| 티어·목적 | 자산 |
| --- | --- |
| 설계 철학·결정 기준 | [rules/systems](../rules/systems), [ADR-0005](decisions/0005-programming-philosophy.md) |
| 서버 골격 (epoll·시그널·마스터/워커) | [skills/c-server-patterns](../skills/c-server-patterns/SKILL.md), [templates/project/c-system](../templates/project/c-system) |
| 수신·큐·팬아웃 | [skills/stream-pipeline-patterns](../skills/stream-pipeline-patterns/SKILL.md), [skills/data-throughput-accelerator](../skills/data-throughput-accelerator/SKILL.md) |
| 수신 데이터 자료구조·정렬 | [skills/c-data-structures](../skills/c-data-structures/SKILL.md) |
| 공유메모리 ⇄ DB, 조회·제어·복구 도구 | [skills/shm-db-patterns](../skills/shm-db-patterns/SKILL.md), c-system 키트 `tools/` (shmctl.sh · shm_view · shm_recover) |
| 임베디드 SQL (Pro*C·ecpg) | [skills/embedded-sql](../skills/embedded-sql/SKILL.md), [agents/database-reviewer](../agents/database-reviewer.md) |
| DB 설계·스키마 버전 | [skills/oracle-patterns](../skills/oracle-patterns/SKILL.md), [skills/postgres-patterns](../skills/postgres-patterns/SKILL.md), [skills/sql-schema-versioning](../skills/sql-schema-versioning/SKILL.md) |
| 서버 ↔ 클라이언트 계약 | [skills/api-contracts](../skills/api-contracts/SKILL.md), [skills/json-contracts](../skills/json-contracts/SKILL.md) |
| TypeScript 클라이언트 대용량 수신 | [skills/desktop-data-client](../skills/desktop-data-client/SKILL.md), [rules/electron](../rules/electron), [rules/react](../rules/react), [agents/typescript-reviewer](../agents/typescript-reviewer.md) |
| C → Rust 이식 | [skills/c-to-rust-migration](../skills/c-to-rust-migration/SKILL.md), [agents/rust-reviewer](../agents/rust-reviewer.md) |
| 운영 로그·추적 | [skills/operational-logging](../skills/operational-logging/SKILL.md), [skills/distributed-tracing](../skills/distributed-tracing/SKILL.md) |
| 원격·오프라인 서버 분석 | [skills/remote-linux-analysis](../skills/remote-linux-analysis/SKILL.md), [skills/performance-profiling](../skills/performance-profiling/SKILL.md) |
| 처리량·지연 측정 | [skills/load-testing](../skills/load-testing/SKILL.md), [skills/latency-critical-systems](../skills/latency-critical-systems/SKILL.md), [templates/project/throughput-poc](../templates/project/throughput-poc) |
| 네이밍 약어 통일 | [skills/naming-dictionary](../skills/naming-dictionary/SKILL.md), `lib/naming-check.sh` |
| 3티어 통합 실행 | [templates/project/compose-3tier](../templates/project/compose-3tier) |

## 8. 사용 방식

새 업무를 시작할 때 다음 순서로 자산을 고른다.

1. 사용자의 문제와 성공 지표가 불명확하면 `product-lens`.
2. 구현 범위가 크면 `product-capability`.
3. 장기 설계 선택이 있으면 `architecture-decision-records`.
4. 언어와 도메인에 맞는 `rules/<domain>`과 `skills/<domain>`을 적용.
5. `tdd-workflow`로 테스트를 먼저 만들고 `verification-loop`로 닫는다.
