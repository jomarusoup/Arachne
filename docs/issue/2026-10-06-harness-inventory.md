---
Title: "[audit] 로드맵 W6 하네스 인벤토리 — 다음 감사 기준선"
creation: 2026-10-06
modification: 2026-10-06
status: "done"
tags:
 - "arachne"
 - "audit"
 - "roadmap"
aliases:
 - "harness-inventory-2026-10-06"
---
MOC:: [[Arachne]]
FROM:: [[2026-10-05-roadmap-w6]]

# 로드맵 W6 하네스 인벤토리 — 다음 감사 기준선

이 문서는 로드맵 W6(최종 정리)에서 하네스 전체를 훑어 정리한 결과를 기록한다. 다음 감사를 시작하는 사람은
이 문서를 기준선으로 삼아 그 뒤에 바뀐 것만 보면 된다. 정리 방법은 [로드맵](../task/2026-10-05-arachne-roadmap.md)
§5 Z-0, 문장 기준은 같은 절의 Z-3을 따랐다.

## 1. 요약

- W6에서 고친 것은 크게 다섯 갈래다. 제거된 런타임(3-레인) 서술, 깨진 링크, 문서 상태 불일치, 문서 배치(D-15),
  구조 문서와 다이어그램의 낡은 내용이다.
- 정리 후 제거 런타임을 현행처럼 쓴 살아있는 문서는 0건이다. 깨진 상대 링크도 0건이며, task 문서의
  frontmatter 상태와 인덱스 표는 서로 일치한다.
- 구조 문서는 [ARCHITECTURE](../ARCHITECTURE.md)가 정본이다. 다이어그램 7개는 모두 Mermaid CLI로 렌더링해
  문법 오류가 없음을 확인했다.
- 원인을 찾은 사고가 한 건 있다. 저장소가 iCloud 동기화 폴더(Desktop)에 있어 `.git/refs` 안에 `* 2` 사본이 생겼고,
  이 때문에 `git pull`이 실패했다. 복구 절차와 예방책은 [SYNCTHING-SETUP](../SYNCTHING-SETUP.md)에 적었다.

## 2. 규모 (2026-10-06, `docs/roadmap-w6-cleanup` 브랜치 기준)

| 영역 | 개수 | 비고 |
|---|---:|---|
| 서브에이전트 (`agents/`) | 10 | 리뷰어 7종 포함 |
| 슬래시 커맨드 (`commands/`) | 21 | |
| 스킬 (`skills/`, 현역) | 65 | 별도로 `archive/` 9개, `synced/` |
| 규칙 디렉터리 (`rules/`) | 14 | 공통 1 · 언어 9 · 관심사 4(systems·react·electron·web) |
| 훅 스크립트 (`hooks/`) | 9 | settings 등록 8 + 공용 함수 `lib-guard.sh` |
| 테스트 (`tests/`) | bats 23 · 셸 검사 6 | PowerShell 2개 별도 |
| 프로젝트 프로필 | 7 | minimal · python · python-web · web · cpp · rust · c-system |
| ADR | 6 | 다음 번호 0007 |

## 3. 문서 역할

문서는 네 가지 역할로 나눈다. 한 문서는 한 역할만 맡고, 변경이 생기면 그 역할을 맡은 문서만 고친다.

| 역할 | 문서 | 갱신 시점 |
|---|---|---|
| 헌법 — 무엇을 지켜야 하는가 | `CLAUDE.md`, `AGENTS.md`, `rules/` | 규약이 바뀔 때 |
| 지도 — 무엇이 어디 있는가 | `README.md`, `docs/ARCHITECTURE.md`, `docs/CAPABILITY-MAP.md`, `docs/README.md`, 각 폴더 README | 자산이 추가·삭제될 때 |
| 상태 — 지금 무엇을 하고 있는가 | `docs/task/` (`[plan]` 포함) | 작업이 진행될 때 |
| 이력 — 무엇이 왜 일어났는가 | `docs/issue/`, `docs/decisions/`, `docs/idea/` | 기록 시점에 한 번. 본문은 고치지 않는다 |

## 4. 처리 내역

### 4.1 이동 (D-15)

| 원래 위치 | 새 위치 | 역할 |
|---|---|---|
| `ARACHNE_AUDIT_2026-09-13.md` | `docs/issue/2026-09-13-arachne-audit.md` | 이력 |
| `CHANGELOG-AUDIT.md` | `docs/issue/CHANGELOG-AUDIT.md` | 이력 (코드 주석의 `CHANGELOG-AUDIT A-xx` 참조를 살리려고 이름 유지) |
| `docs/task/20261005/2026-10-05-arachne-roadmap.md` | `docs/task/` | 상태 |
| `docs/task/20261005/2026-10-05-roadmap-input-sheet.md` | `docs/task/` | 상태 |
| `docs/task/20261005/2026-09-29-programming-philosophy-integration.md` | `docs/task/` | 상태 |
| `docs/task/20261005/claude-code-kickoff-prompts.md` | `docs/task/2026-09-29-philosophy-kickoff-prompts.md` | 상태 (내용에 맞게 이름 변경, done) |
| `docs/task/20261005/programming-philosophy.md` | `docs/idea/2026-09-29-programming-philosophy.md` | 이력 (입력 원문) |

`docs/task/20261005/`에는 추적되지 않는 초안 4개만 남아 있다. 로드맵이 대체한 초안이며, 삭제 여부는 사용자가 정한다.

### 4.2 삭제

| 대상 | 근거 |
|---|---|
| `.git/refs/**/'* 2'` 6개 | iCloud 충돌 사본. 원본 ref와 같은 대상을 가리켜 `git pull`을 막았다 |
| `skills/service-latency/SKILL 2.md` | 같은 iCloud 사본. 원본과 내용이 같다 (추적되지 않음) |
| `templates/project/c-system/src 2/` | 같은 iCloud 사본. 빈 디렉터리였다 (추적되지 않음) |

### 4.3 최신화

| 대상 | 무엇이 낡았나 | 조치 |
|---|---|---|
| `docs/ARCHITECTURE.md` | 3-레인 설명, 에이전트 8종, 가드 훅 판정 방식(종료코드 2로 잘못 기술), 규칙 디렉터리 누락, 서브에이전트 규칙 도달 범위 없음 | 수정 + 7절(보안 계층)·8절(프로젝트 키트)·9절(3티어 지원 지도) 다이어그램 추가 |
| `docs/CAPABILITY-MAP.md` | 3티어·대용량 자산 없음 (2026-06 상태) | 7절 3티어 지도와 비밀값·개인정보 항목 추가 |
| `CLAUDE.md` 트리 | `lib/`·`templates/`·`docs/`·`archive/` 없음 | 추가 |
| `README.md`, `docs/README.md`, `docs/USAGE.md` | 규칙 디렉터리·키트·ARCHITECTURE 설명이 낡음 | 갱신 |
| `docs/AI-ENGINEERING-NOTES.md`, `docs/tools/codegraph.md` | 제거된 위임 래퍼를 현행처럼 서술 | 단독 운용 기준으로 재작성 |
| `docs/DATA-HANDLING.md`, `PYTHON-WEB-PROFILE.md`, `PROJECT-CI.md`, `DOCS-SYNC.md`, `SYNCTHING-SETUP.md`, `CI.md` | 7월 이전 상태, 신규 프로필·CI 단계 누락 | 현행 코드와 대조해 갱신 |
| `docs/task/README.md`, `docs/decisions/README.md`, `docs/issue/README.md`, `docs/idea/README.md` | 없는 `docs/plan/PLAN.md` 참조, ADR 표 끊김, 신규 기록 누락 | 갱신 |
| `rules/{python,golang,bash,javascript}/coding-style.md` | 헤더 예시에 날짜 필드 (D20 위반) | 날짜 필드 삭제 |
| W1~W5 신규 스크립트 11개 | 헤더에 날짜 필드 (D20은 신규 파일부터 적용) | 날짜 필드 삭제 |
| `rules/bash/testing.md`, `docs/CI.md`, `tests/README.md` | bats 단언이 조용히 통과하는 함정 미기재 | 규칙과 설명 추가 |
| Obsidian 볼트 경로로 깨진 링크 3건 | `100.%20Project/...` 형태 | 상대 경로로 수정 |

### 4.4 상태 대조 결과

task 문서 37개(`docs/task/20261005/` 제외)의 상태는 done 29 · in progress 3 · to do 5다. 표류가 의심됐던
세 문서(`2026-06-11-audit-followup`, `2026-08-25-pc-defect-repair`, `2026-08-25-hook-subagent-experiment`)는
커밋 이력과 대조한 결과 실제로 남은 작업이 있어 `to do`를 유지했다. 근거는 각 문서의 2026-10-06 진행 기록에 있다.

## 5. 고아 점검

| 점검 | 결과 |
|---|---|
| settings에 등록되지 않은 훅 | `lib-guard.sh` 1개. 가드 훅이 `source`하는 공용 함수라 정상이다 |
| 링크가 없는 문서 | `docs/ui-ux/examples/*.md` 2개. `docs/ui-ux/README.md`가 폴더 단위로 안내하므로 정상이다 |
| 다른 곳에서 언급되지 않는 스킬 | 없음 |
| 어디서도 참조되지 않는 스크립트 | 없음 |

## 6. 크기 경고 판정

`tests/check_index.sh` 검사 8은 에이전트 200줄, 스킬 400줄, 규칙 100줄을 넘으면 경고한다. 줄 수는 점검
신호일 뿐 한도가 아니다. 판정 기준은 "한 파일에 서로 독립적으로 바뀌는 역할이 섞였는가"다.

| 파일 | 줄 수 | 판정 | 근거 |
|---|---:|---|---|
| `rules/c/testing.md` | 118 → 72 | 압축 | cmocka 예시·커버리지 명령을 `c-testing` 스킬로 넘기고 규칙만 남김 |
| `rules/javascript/coding-style.md` | 173 → 134 | 압축 후 유지 | 중복 예시를 `patterns.md`·`security.md` 참조로 대체. 남은 것은 TS 타입 규칙으로 옮길 곳이 없다 |
| `rules/c/coding-style.md` | 132 → 112 | 압축 후 유지 | 절마다 다른 규칙이며 최소 예시만 남았다 |
| `rules/web/ui-layout.md` | 124 → 113 | 압축 후 유지 | 대부분 배치 수치 표이고 모든 행이 규칙이다 |
| `rules/bash/coding-style.md`, `rules/python/coding-style.md`, `rules/rust/testing.md` | 100 이하 | 압축 | 중복 제거 |
| `rules/c/patterns.md` | 181 | 유지 | 불투명 포인터·ops 테이블 예시의 정본이며 `systems/philosophy.md`와 `c-server-patterns`가 참조한다 |
| `rules/systems/philosophy.md` | 208 | 유지 | ADR-0005로 확정된 철학. 12절 위임 요약은 의도된 중복이다 |
| `agents/planner.md` 296, `debugger.md` 282, `code-reviewer.md` 256, `database-reviewer.md` 208 | | 유지 | 서브에이전트는 언어 규칙을 물려받지 않으므로 체크리스트를 정의 안에 담아야 한다 |
| `skills/frontend-patterns` 514, `python-patterns` 506, `golang-patterns` 485, `error-handling` 470 | | 유지 | 호출될 때만 읽히는 단일 도메인 스킬이다. 역할이 섞이면 그때 나눈다 |

## 7. 남은 일

| 항목 | 이유 | 시점 |
|---|---|---|
| 서브에이전트 `skills:` 프리로드 크기 측정 (G-2) | 이 세션은 시작 시점의 정의를 캐시하므로 측정할 수 없다. 기준선은 tdd 26530, code-reviewer 31085, debugger 29376 토큰이며 5k 넘게 늘면 되돌린다 | 새 세션 |
| Oracle·Jaeger compose 프로필 실행 | CI는 PostgreSQL 경로만 돈다 | 필요 시 |
| `docs/task/20261005/` 초안 4개 | 추적되지 않는 초안. 삭제는 사용자 승인 사항이다 | 사용자 결정 |
| `trading-systems` 스킬의 생성 코드 커밋 예외 | 철학 §10(생성물은 커밋하지 않음)과 충돌 여부를 사용자가 확인해야 한다 | 사용자 결정 |
| 저장소 위치 | iCloud 동기화 폴더 밖으로 옮기는 것을 권장한다 | 사용자 결정 |
