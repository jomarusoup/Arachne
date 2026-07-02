---
name: hexagonal-architecture
description: 도메인 중심 설계, port/adapter, inbound/outbound boundary, 테스트 가능한 백엔드 구조를 설계하는 스킬.
triggers:
  paths: []
  keywords: ["헥사고날", "port adapter", "도메인 경계", "클린 아키텍처"]
---

# Hexagonal Architecture

도메인 로직을 프레임워크와 인프라에서 분리하기 위한 구조다.

## 핵심 구조

```text
Inbound Adapter -> Use Case Port -> Domain -> Outbound Port -> Outbound Adapter
```

## 언제 사용하나

- 외부 API, DB, queue, 파일 시스템 의존이 많은 서비스
- 테스트에서 인프라를 쉽게 교체해야 하는 도메인
- 프레임워크 교체 가능성을 보존해야 하는 장기 서비스

## 기준

- domain은 HTTP, ORM, framework annotation을 몰라도 된다.
- use case는 input port로 호출되고 output port로 외부 의존을 사용한다.
- adapter는 변환과 I/O만 담당한다.
- 테스트는 domain/use case를 fake port로 검증한다.

## Java/Spring 적용

```text
api/controller -> application/usecase -> domain/model
                                      -> application/port
persistence/adapter -> application/port 구현
```

JPA Entity와 domain model을 분리하면 명확하지만 비용이 든다. 작은 프로젝트에서 겸용할 경우 이유를 ADR에 남긴다.
