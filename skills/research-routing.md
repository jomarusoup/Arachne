---
name: research-routing
description: 작업 성격에 맞는 모델 선택(Haiku/Sonnet/Opus)과 코드 조사 도구 라우팅(codegraph vs sgrep). 비용·토큰 최적화 판단이 필요할 때 참조.
triggers:
  paths: []
  keywords: ["모델 선택", "codegraph", "sgrep", "조사 라우팅", "토큰 절약", "비용 최적화"]
---

# 조사·모델 라우팅 스킬

작업 특성에 맞는 모델과 조사 도구를 골라 비용과 품질을 균형 있게 쓴다.

## 모델 선택 전략

**Haiku** (빠른 응답, 저비용):
- 단순 커밋·푸시 작업
- 정형화된 코드 생성 (boilerplate)
- 멀티 에이전트 시스템의 워커 에이전트

**Sonnet** (기본 개발 모델):
- 일반적인 코드 구현·버그 수정
- 코드 리뷰 (`code-reviewer` 에이전트)
- 멀티 에이전트 오케스트레이터

**Opus** (깊은 추론 필요):
- 저수준 시스템 설계 (IPC, 데몬, 커널 인터페이스)
- 복잡한 아키텍처 결정
- 메모리·레이스 컨디션 원인 분석
- `planner` 에이전트 (기본값)

> 결정론적 리팩터링·단순 편집은 Sonnet 이하로 충분.
> Opus는 판단이 필요한 시스템 설계·분석 작업에 집중.

## 조사 라우팅 — codegraph vs sgrep

코드 조사(Research) 시 질의 성격에 맞는 도구를 골라 토큰·시간을 아낀다.
**codegraph 가 설치된 경우**(`command -v codegraph`) 심볼·관계 질의는 grep 으로 본문을 훑기 전에
codegraph 를 먼저 쓴다 — 인덱스 한 번에 호출/정의/영향 범위를 돌려주므로 다중 grep 왕복이 사라진다.

| 질의 성격 | 도구 | 예 |
| --- | --- | --- |
| 심볼 정의·참조·호출 관계, 변경 영향 범위 | **codegraph** (설치 시) → `/codegraph` | "이 함수 누가 호출?", "이 타입 바꾸면 어디 깨지나" |
| 단순 텍스트·문자열·패턴 매칭, 파일 위치 | **sgrep** | "이 에러 문구 어디?", "TODO 검색" |

> codegraph 미설치 환경에서는 전부 `sgrep` 으로 폴백한다 — 설치는 `arachne --extras --codegraph`.
> 어느 경우든 **파일 전체 읽기 금지** 원칙은 그대로다(범위만 좁힌 뒤 `Read`).
