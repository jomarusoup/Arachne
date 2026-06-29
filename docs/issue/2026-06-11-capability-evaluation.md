---
Title: "[audit] 언어 × 도구 역량 평가 — 하네스가 어디까지 지원하는가"
creation: 2026-06-11
modification: 2026-06-11
status: "done"
tags:
 - "arachne"
 - "audit"
 - "capability"
 - "evaluation"
aliases:
 - "capability-eval-2026-06"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-11-architecture-audit]]

# [audit] 언어 × 도구 역량 평가

- **작성일**: 2026-06-11
- **검수 기준**: 35b1fd9 (솔로 모드 포함)
- **유형**: 역량 평가 스냅샷 — 자산이 추가되면 점수는 달라진다

## 0. 무엇을 평가하나 (중요한 전제)

이 평가의 대상은 **"하네스가 해당 언어·도구 조합에 제공하는 지원 수준"** 이다.
모델 자체의 코딩 지능을 평가하는 것이 아니다 — 같은 모델이라도 하네스가 규칙·검증·
자동화를 얼마나 공급하느냐에 따라 실전 산출물 품질이 달라진다는 관점이다.

점수는 측정값이 아니라 **자산 보유량·집행 자동화·검증 연결**이라는 객관적 근거 위에 세운
구조적 추정치다. 구간 의미:

| 구간 | 의미 |
| --- | --- |
| 90~100 | 설계→구현→테스트→리뷰→CI 전 파이프라인이 자동 집행됨 |
| 70~89 | 주력 사용 가능 — 핵심 자산·검증 있음, 일부 수동 |
| 50~69 | 보조 사용 — 규약은 있으나 집행·검증 자동화 부족 |
| 30~49 | 제한적 — 텍스트 규약 수신만, 특정 레인·작업에 한정 |
| 0~29 | 비권장 — 지원 구조 없음 |

## 1. 평가 기준 (5개 차원)

| 차원 | 무엇을 보나 | 근거 자산 |
| --- | --- | --- |
| **개발·구현** | 언어 패턴·이디엄·스타일 규칙의 깊이, 자동 로드 여부 | `rules/<언어>/coding-style·patterns`, `skills/*-patterns` |
| **테스트** | TDD 자산, 테스트 스킬, 검증 명령, CI 게이트 연결 | `rules/<언어>/testing`, `skills/*-testing`, tdd 에이전트, profile commands |
| **유지보수** | 리뷰 에이전트, 리팩터링 워크플로, 드리프트 방지 | reviewer 에이전트, `/refactor`, check_index·convention_sync |
| **보안** | 언어별 보안 규칙, 보안 리뷰 경로, 의존성 감사 | `rules/<언어>/security`, security-review/scan 스킬, pip-audit 등 |
| **구조·아키텍처** | 설계 지원(planner), 아키텍처 패턴, profile 계약 | planner 에이전트, backend/api-design 스킬, `.arachne` profile |

도구 축은 **규약 전달 깊이 × 집행 자동화 × 레인 역할**로 본다:

| 도구 | 규약 전달 | 집행 자동화 | 비고 |
| --- | --- | --- | --- |
| Claude Code | `rules/` 풀버전 자동 로드 (공통=매 세션, 언어=확장자 매칭) | 훅·에이전트 8종·커맨드 16종·`/verify` 자동 | 풀 스택 — 기준점 |
| Codex CLI | AGENTS.md 다이제스트(마커 병합) + 언어 규칙은 경로 포인터 | 없음 (래퍼 경유 시 tester/fixer 프리앰블 주입) | 3-레인에서 테스트·버그픽스 전담 |
| Gemini CLI | AGENTS.md 다이제스트(심볼릭) + 경로 포인터 | 없음 (래퍼 경유 시 reader/advisor) | 읽기·요약·설계 탐색 전담 |
| GitHub Copilot | 저장소 AGENTS.md 자동 발견 + `~/.copilot/` 전역 | 없음 (에디터 인라인·PR 리뷰는 Copilot 자체 기능) | 편집기 보조 표면 |

공통 바닥: 어느 도구가 작성했든 **프로젝트 CI(`.arachne/verify.sh`)가 동일 게이트**로 잡아준다
— 도구 점수가 낮아도 최종 품질 하한은 CI가 지킨다 (단 profile이 있는 언어만, §4 참고).

## 2. 언어별 하네스 자산 점수 (Claude Code 기준 = 하네스 최대치)

근거 자산 집계 (2026-06-11 기준):

| 언어 | rules | 전용 skills | 전용 reviewer/커맨드 | profile CI | 비고 |
| --- | --- | --- | --- | --- | --- |
| Python | **7** (5+fastapi+data-handling) | python-patterns·testing, fastapi-patterns, json-contracts, database-migrations, postgres-patterns, netmiko | python·fastapi·database-reviewer, /python-review·/fastapi-review | **python** (uv·ruff·mypy·pytest·pip-audit) | 최다 자산 |
| TS/JS·Web | 5 + web/design-quality | frontend-patterns, api-design, make-interfaces-feel-better, backend-patterns(공용) | react-reviewer, /react-review, /e2e(Playwright) | **web** (pnpm·tsc·vitest·build·playwright) | |
| Go | 5 | golang-patterns·testing, go-http-patterns | 없음 | 없음 | |
| Rust | 5 | rust-patterns·testing (+latency 공용) | 없음 | 없음 | |
| C | 5 | build-debug, memory-check, error-handling, latency, trading, perf(공용) | debugger 에이전트(공용) | 없음 | 메모리 검사 규칙 강함 |
| C++ | 5 | 위 + cpp-testing | debugger(공용) | 없음 | |
| Bash | 5 | (하네스 자체가 실증 — bats 124·shellcheck 4-OS CI) | 없음 | 없음 | wrapper_security.bats 등 보안 테스트 실증 |

**언어 × 차원 점수 (Claude Code로 사용할 때):**

| 언어 | 개발·구현 | 테스트 | 유지보수 | 보안 | 구조 | **종합** |
| --- | :-: | :-: | :-: | :-: | :-: | :-: |
| **Python** | 90 | 88 | 85 | 85 | 85 | **87** |
| **TS/JS·Web** | 85 | 80 | 80 | 78 | 78 | **80** |
| **Bash** | 80 | 82 | 75 | 80 | 70 | **77** |
| **C** | 75 | 72 | 65 | 75 | 70 | **71** |
| **C++** | 75 | 73 | 65 | 73 | 70 | **71** |
| **Go** | 72 | 70 | 63 | 68 | 65 | **68** |
| **Rust** | 70 | 68 | 62 | 70 | 65 | **67** |

점수 산정 근거(대표):

- **Python 87** — 유일하게 5개 차원 전부에 전용 자산: 규칙 7종 자동 로드, 전담 reviewer 3종
  자동 활성화, DB·JSON 데이터 계약(rules+skills 4종), profile CI로 format·lint·type·test·의존성
  감사가 로컬/GitHub 동일 집행. 90을 못 넘는 이유: DB fixture CI gate·OpenAPI 검사 미구현
  (data-handling-hardening P1), Django 미지원.
- **TS/JS·Web 80** — react-reviewer·design-quality·Playwright E2E·web profile까지 연결.
  감점: 백엔드 Node(Express/Nest) 전용 자산 없음, vitest/MSW는 profile 명령에만 존재하고
  스킬 깊이가 Python 대비 얕음.
- **Bash 77** — 규칙·보안(인젝션·mktemp·권한)·bats 테스팅이 하네스 자체 CI로 **실증**됨.
  감점: profile 없음(프로젝트 CI 계약 미정의), 전담 reviewer 없음.
- **C/C++ 71** — 메모리 검사(valgrind/ASan/TSan) 규칙·debugger 에이전트·시스템 스킬 다수.
  감점: profile 없음 → 프로젝트 CI를 손으로 작성해야 함, 전담 reviewer 없음(공용 code-reviewer).
- **Go 68 / Rust 67** — 규칙·스킬은 충실하나 전담 reviewer·profile·E2E 연결이 없어
  "규약은 있고 집행은 약한" 전형. 2순위(Go)·3순위(Rust) 선언과 일치하는 상태.

## 3. 도구별 전달·역량 점수 (언어 무관)

| 도구 | 개발·구현 | 테스트 | 유지보수 | 보안 | 구조 | **종합** | 역량 상한 (어디까지 가능한가) |
| --- | :-: | :-: | :-: | :-: | :-: | :-: | --- |
| **Claude Code** | 95 | 90 | 90 | 85 | 90 | **90** | 설계→구현→TDD→리뷰→`/verify`→커밋·push 전 파이프라인 자동. 유일하게 오케스트레이터·커미터 |
| **Codex CLI** | 55 | **75** | 50 | 55 | 40 | **55** | 테스트 작성·실행·버그 수정을 green까지(-w). 구현도 가능하나 스타일 보정·통합·커밋은 Claude/사람 몫 |
| **GitHub Copilot** | 50 | 40 | 45 | 45 | 35 | **43** | 에디터 인라인 완성·PR 리뷰 코멘트. 규약 준수는 AGENTS.md 자동 발견에 의존, 파이프라인 실행 없음 |
| **Gemini CLI** | 35 | 30 | 45 | 45 | **60** | **43** | 대용량 읽기·요약·설계 탐색·1차 리뷰·장문 문서. 최종 구현 코드는 비위임(스타일 충실도) |

도구 점수 근거:

- **Claude 90** — 차원 전부에 집행 수단 보유. 100이 아닌 이유: 보안 자동 게이트가 커밋 전
  체크리스트(텍스트)와 CI 의존이고, 훅 실패가 로그로 남지 않음(감사 followup #4).
- **Codex 55 (테스트 75)** — tester/fixer 레인 전담 + `-w` 실행 모드 + 인젝션 방어 프리앰블이
  테스트 차원을 끌어올린다. 단 언어 규칙은 경로 포인터만 받아 헤더·네이밍 충실도가 낮고
  (통합 시 Claude가 보정), 구조 설계는 레인 밖.
- **Gemini 43 (구조 60)** — 설계 탐색·대용량 분석이 강점 레인. 구현·테스트는 계약상 비위임.
- **Copilot 43** — 저장소 규약을 읽는 에디터 보조. 하네스의 에이전트·훅·커맨드와 연결점이
  없어 점수가 전달층(①)에 머문다.

## 4. 종합 매트릭스 — 언어 × 도구

산식: Claude 열 = §2 언어 종합점수. 다른 도구 = 언어 점수 × 도구 전달률
(Codex 0.55 / Gemini 0.45 / Copilot 0.45) 후 레인 보정(Codex 테스트 작업 +α, 반올림).

| 언어 \ 도구 | Claude Code | Codex CLI | Gemini CLI | Copilot |
| --- | :-: | :-: | :-: | :-: |
| **Python** | **87** | 50 (테스트 한정 68) | 40 | 42 |
| **TS/JS·Web** | **80** | 46 (테스트 한정 62) | 37 | 44 |
| **Bash** | **77** | 44 | 35 | 33 |
| **C** | **71** | 39 | 32 | 30 |
| **C++** | **71** | 40 | 32 | 30 |
| **Go** | **68** | 39 | 31 | 33 |
| **Rust** | **67** | 38 | 30 | 31 |

읽는 법:

- **모든 언어에서 Claude가 압도적**인 것은 의도된 설계다 — 하네스 자산(에이전트·훅·규칙
  자동 로드)이 Claude Code 전용 메커니즘이기 때문. 다른 도구는 ①규약 전달층만 받는다.
- **Codex의 "테스트 한정" 점수**가 별도인 이유: 3-레인 계약상 Codex의 본업이 테스트·버그픽스
  이고, 그 작업에는 ctask 프리앰블·-w 실행·AGENTS 다이제스트가 충분히 작동한다.
- **Copilot이 TS/Web에서 상대적으로 높은** 것은 에디터 인라인 보조가 프론트엔드 반복
  패턴(JSX·CSS)에서 효용이 크기 때문이다.
- 점수 30대 = "규약을 읽는 단독 도구로 쓸 수 있으나, 산출물을 프로젝트 CI와 사람(또는
  Claude) 리뷰 없이 신뢰하지 말 것"이라는 뜻이다.

## 5. 점수를 올리려면 (우선순위 제안)

| 대상 | 현재 | 올리는 방법 | 예상 효과 |
| --- | :-: | --- | --- |
| Go | 68 | `golang` profile(go vet·staticcheck·-race·govulncheck) + go-reviewer | 68→78 (2순위 선언에 걸맞게) |
| C/C++ | 71 | systems profile(cmake/make + cppcheck + ASan 테스트 러너) | 71→78 |
| TS/JS 백엔드 | 80 | Node 서버(Express/Nest) 패턴 스킬 + 백엔드 E2E | 80→84 |
| Python | 87 | data-handling-hardening P1 (DB fixture gate·OpenAPI 검사·/database-review) | 87→91 |
| Codex/Gemini 전달층 | 55/43 | cross-harness 패키징(MULTI-CLI §5.4) — 언어 규칙 어댑터 배포 | +5~10 |

각 도구를 **현재 점수의 상한까지** 뽑아 쓰는 운영 방법(질문법·모드 선택·결과 처리)은
[MULTI-CLI.md §5.5 도구별 최대 활용 가이드](../MULTI-CLI.md)가 정본이다 — 자산 추가 없이
호출자의 수동 규율로 상한에 붙이는 방법과, 그래도 남는 자동 집행 격차를 함께 기술한다.

> 단, 1·2·3순위 선언(Python·Web > Go > C/C++/Rust)과 충돌하지 않게 — Go/C 보강은
> 실제 프로젝트가 생길 때(트리거 도래 시) 진행한다. [[2026-06-11-audit-followup]] 원칙과 동일.

## 6. 평가의 한계

- 점수는 **하네스 지원 수준**이지 결과물 품질 보증이 아니다. 모델 버전·과제 난이도에 따라
  실제 산출물은 달라진다.
- Codex/Gemini/Copilot의 규약 *준수율*은 자동 측정하지 않았다(텍스트 지시 의존). 측정하려면
  도구별 동일 과제 벤치마크가 필요하다 — 현재 범위 밖.
- 이 문서는 스냅샷이다. 자산 추가·profile 신설 시 §2·§4를 갱신하거나 새 평가를 작성한다.
