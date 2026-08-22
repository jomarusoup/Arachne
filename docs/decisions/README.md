---
Title: "ADR 인덱스"
creation: 2026-07-01
modification: 2026-08-22
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

| ADR | 결정 |
| --- | --- |
| [0001-python-web-profile](0001-python-web-profile.md) | Python·Web profile을 Arachne의 기본 프로젝트 적용 축으로 둔다. |
| [0002-systems-profiles](0002-systems-profiles.md) | cpp·rust profile로 빌드+테스트+sanitizer 게이트를 기본 제공한다. |
| [0002-external-analysis-plugins](0002-external-analysis-plugins.md) | 결정론 분석(스캔·그래프·심볼)은 외부 플러그인에 두고 Arachne는 계약 지점(설치·신선도·영속화·폴백)만 소유한다. |
| [0003-dynamic-workflows-adoption](0003-dynamic-workflows-adoption.md) | (Proposed) dynamic workflows를 읽기 전용·검증 커맨드에 한정 도입하고, 수정형 확장은 선결조건 PC-1~10 충족을 게이트로 한다. |
