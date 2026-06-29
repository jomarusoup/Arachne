---
Title: "[task] Arachne 역량 보강과 학습 가이드 작성"
creation: 2026-06-20
modification: 2026-06-20
status: "done"
tags:
 - "project"
 - "task"
 - "priority/high"
aliases:
 - "extension-capability-port"
---
MOC:: [[Arachne]]
FROM:: [[Arachne]]

# [task] Arachne 역량 보강과 학습 가이드 작성

- **상태**: done
- **우선순위**: high
- **담당**: Codex
- **관련 문서**: [skills/README](../../skills/README.md), [rules/README](../../rules/README.md), [docs/README](../README.md)

## 목표

Arachne에 필요한 Java, Docker, 제품, 아키텍처, UI/UX, 시스템·네트워크 관련 지식을 한글 규칙·스킬·가이드로 보강한다.

## 범위

- 포함:
  - Java 언어 규칙과 Spring Boot/JPA 스킬 추가
  - Docker 규칙 추가와 기존 Docker 스킬 보강
  - 제품 진단, ADR, Linux system/network programming 스킬 추가
  - 하네스 학습 순서와 역량 지도를 문서화
  - README, docs index, rules index, skills index 최신화
- 제외:
  - 설치 스크립트 동작 변경
  - 외부 패키지 설치
  - 목적과 맞지 않는 대량 문서 추가

## 작업 목록

- [x] Java와 Docker 규칙 추가
- [x] 제품·아키텍처·시스템 네트워크 스킬 추가
- [x] 학습 순서와 역량 지도 문서 추가
- [x] 인덱스 문서 최신화
- [x] 정적 문서 검증 실행

## 검증

```bash
bash tests/check_index.sh
bash tests/check_convention_sync.sh
```

문서 인덱스와 공통 규약 동기화 검사가 통과해야 한다.

## 완료 조건

- 새 규칙·스킬·문서가 저장소 구조에 맞게 추가된다.
- 학습자가 Arachne를 어떤 순서로 익힐지 문서에서 바로 확인할 수 있다.
- 실행한 검증 결과를 진행 기록에 남긴다.

## 진행 기록

### 2026-06-20

- task 생성: Arachne에 부족한 Java, Docker rules, 제품·아키텍처 학습 흐름을 한글로 보강하기로 결정.
- 구현: `rules/java/`, `rules/docker/`, Java/Spring/JPA, 제품, 아키텍처, UI/UX, 네트워크·처리량 스킬을 추가했다.
- 문서: `docs/CAPABILITY-MAP.md`, `docs/HARNESS-LEARNING-GUIDE.md`, `docs/ui-ux/` 예시 문서를 추가하고 README·USAGE·rules/skills/docs 인덱스를 최신화했다.
- 출처성 표기 제거: 사용자가 제거 요청한 출처 키워드의 검색 결과가 없도록 정리했다.
- 검증:
  - `bash tests/check_index.sh`: 통과
  - `bash tests/check_convention_sync.sh`: 통과
