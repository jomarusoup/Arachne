---
Title: "Arachne 역량 지도"
creation: 2026-06-20
modification: 2026-06-20
tags:
 - "arachne"
 - "capability"
aliases:
 - "arachne-capability-map"
---
MOC:: [[Arachne]]
FROM:: [[100. Project/110. Side-Project/111. Arachne/docs/README]]

# Arachne 역량 지도

Arachne는 Python·Web과 C/C++·Go·Rust 시스템 개발에서 출발했지만, 업무 보조 하네스로 쓰기 위해
제품 판단, 아키텍처 기록, Java 백엔드, Docker 운영, Linux system/network programming까지 연결한다.

## 1. 공통 업무 규율

| 목적 | 자산 |
| --- | --- |
| 작업 흐름 | [rules/common/development-workflow](../rules/common/development-workflow.md), [rules/common/workflow](../rules/common/workflow.md) |
| 이슈·작업 기록 | [docs/task/README](task/README.md), [docs/template/task](template/task.md) |
| TDD | [skills/tdd-workflow](../skills/tdd-workflow.md), [rules/common/testing](../rules/common/testing.md) |
| 검증 | [skills/verification-loop](../skills/verification-loop.md), [docs/PROJECT-CI](PROJECT-CI.md) |
| 보안 | [skills/security-review](../skills/security-review.md), [rules/common/security](../rules/common/security.md) |

## 2. 제품·기획·사용자 관점

| 목적 | 자산 |
| --- | --- |
| 만들 이유 검증 | [skills/product-lens](../skills/product-lens.md) |
| 구현 가능한 capability 분해 | [skills/product-capability](../skills/product-capability.md) |
| UI/UX 방향 | [rules/web/design-quality](../rules/web/design-quality.md), [skills/make-interfaces-feel-better](../skills/make-interfaces-feel-better.md) |
| API 사용자 경험 | [skills/api-design](../skills/api-design.md) |

## 3. 아키텍처

| 목적 | 자산 |
| --- | --- |
| 장기 결정 기록 | [skills/architecture-decision-records](../skills/architecture-decision-records.md), [docs/decisions](decisions/) |
| 계층·경계 설계 | [rules/common/patterns](../rules/common/patterns.md), [skills/backend-patterns](../skills/backend-patterns.md) |
| 데이터 계약 | [skills/json-contracts](../skills/json-contracts.md), [docs/DATA-HANDLING](DATA-HANDLING.md) |

## 4. Java 백엔드

| 목적 | 자산 |
| --- | --- |
| Java 기본 규칙 | [rules/java](../rules/java), [skills/java-coding-standards](../skills/java-coding-standards.md) |
| Spring Boot 구조 | [skills/springboot-patterns](../skills/springboot-patterns.md) |
| Spring Security | [skills/springboot-security](../skills/springboot-security.md) |
| Spring TDD/검증 | [skills/springboot-tdd](../skills/springboot-tdd.md), [skills/springboot-verification](../skills/springboot-verification.md) |
| JPA/Hibernate | [skills/jpa-patterns](../skills/jpa-patterns.md) |

## 5. Docker·배포

| 목적 | 자산 |
| --- | --- |
| Dockerfile/Compose 규칙 | [rules/docker](../rules/docker) |
| Docker 패턴 | [skills/docker-patterns](../skills/docker-patterns.md) |
| 배포 운영 | [skills/deployment-patterns](../skills/deployment-patterns.md) |
| 프로젝트 CI | [docs/PROJECT-CI](PROJECT-CI.md) |

## 6. Linux 시스템·네트워크

| 목적 | 자산 |
| --- | --- |
| Linux system/network programming | [skills/linux-system-network-programming](../skills/linux-system-network-programming.md) |
| C 시스템 규칙 | [rules/c](../rules/c) |
| C++ 시스템 규칙 | [rules/cpp](../rules/cpp) |
| 저지연 시스템 | [skills/latency-critical-systems](../skills/latency-critical-systems.md) |
| 메모리 검사 | [skills/memory-check](../skills/memory-check.md) |
| 네트워크 운영 진단 | [skills/network-interface-health](../skills/network-interface-health.md), [skills/network-config-validation](../skills/network-config-validation.md) |

## 7. 사용 방식

새 업무를 시작할 때 다음 순서로 자산을 고른다.

1. 사용자의 문제와 성공 지표가 불명확하면 `product-lens`.
2. 구현 범위가 크면 `product-capability`.
3. 장기 설계 선택이 있으면 `architecture-decision-records`.
4. 언어와 도메인에 맞는 `rules/<domain>`과 `skills/<domain>`을 적용.
5. `tdd-workflow`로 테스트를 먼저 만들고 `verification-loop`로 닫는다.
