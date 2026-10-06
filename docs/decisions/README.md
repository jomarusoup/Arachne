---
Title: "ADR 인덱스"
creation: 2026-07-01
modification: 2026-10-06
status: "done"
tags:
 - "arachne"
 - "architecture"
 - "adr"
aliases:
 - "decision-records"
---
MOC:: [[Arachne]]
FROM:: [[arachne-docs]]

# Decisions

`docs/decisions/`는 **나중에 바꾸기 어렵거나 여러 문서에 영향을 주는 설계 결정**을 ADR로 남기는
곳이다. 현재 사용법은 정본 문서에 쓰고, 왜 그렇게 결정했는지는 여기에서 보존한다.
기존 결정을 바꾸거나 결정의 이유를 확인하려는 사람이 먼저 읽는다.

## 언제 decision에 쓰나

| 상황 | 기록 위치 |
| --- | --- |
| 장기 유지할 구조, profile, 호환성, 보안 경계를 확정한다 | `decisions/` |
| 실행 전 후보를 비교하고 있다 | `idea/` |
| 이미 하기로 정한 구현·문서 작업을 추적한다 | `task/` |
| 발견된 문제와 원인 분석을 남긴다 | `issue/` |

## 작성 기준

- 파일명은 `NNNN-<짧은-kebab-case-결정명>.md`로 쓴다.
- 배경, 결정, 대안, 결과를 분리한다.
- 결정이 바뀌면 기존 ADR을 덮어쓰기보다 새 ADR에서 supersede 관계를 링크한다.
- 정본 문서에는 현재 상태만 두고, 과거 맥락은 ADR로 연결한다.

## 현재 결정

| ADR | 상태 | 결정 |
| --- | --- | --- |
| [0001-python-web-profile](0001-python-web-profile.md) | Accepted | Python·Web profile을 Arachne의 기본 프로젝트 적용 축으로 둔다. |
| [0002-systems-profiles](0002-systems-profiles.md) | Accepted | cpp·rust profile로 빌드+테스트+sanitizer 게이트를 기본 제공한다. |
| [0002-external-analysis-plugins](0002-external-analysis-plugins.md) | Accepted | 결정론 분석(스캔·그래프·심볼)은 외부 플러그인에 두고 Arachne는 계약 지점(설치·신선도·영속화·폴백)만 소유한다. |
| [0003-dynamic-workflows-adoption](0003-dynamic-workflows-adoption.md) | Proposed | dynamic workflows를 도입하지 않는다. 기존 Agent fan-out으로 충분해 증분 편익이 없다. 결함 수리(PC-1~6)와 계측은 도입과 무관하게 진행하고, 재평가 트리거를 명시한다. |
| [0004-remove-3lane-runtime](0004-remove-3lane-runtime.md) | Accepted | 3-레인 협업 런타임(위임 래퍼·폴백·쿨다운·계측)을 archive/multi-cli/로 제거하고, 규약 배포 계층(AGENTS.md SSOT + 어댑터)은 유지한다. |
| [0005-programming-philosophy](0005-programming-philosophy.md) | Accepted | 시스템 프로그래밍 철학 결정(D01~D23)을 확정한다. 대부분 권장안이며, 동시성·매크로·커밋 언어·기존 관례는 하네스 사용 방식에 맞춰 조정했다. |
| [0006-roadmap-2026q4](0006-roadmap-2026q4.md) | Accepted | 2026 Q4 보강 로드맵의 결정을 확정한다. C 서버와 Pro*C·ecpg를 유지하고, 공유메모리·운영 도구·네이밍·로그·보안 강제를 보강한다. |

상태 열은 각 ADR의 "상태" 절을 옮긴 것이다. ADR의 상태가 바뀌면 이 표도 함께 갱신한다.

## 번호 규칙

다음 신규 ADR 번호는 `0007`이다.

번호 `0002`는 두 ADR이 함께 쓴다. 번호를 잘못 부여한 결과지만, 기록은 재작성하지 않는다는 원칙에
따라 번호를 바꾸지 않는다. 두 ADR을 참조할 때는 전체 파일명으로 구분한다.
