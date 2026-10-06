---
Title: "[reference] 프로그래밍 철학 이식 착수 프롬프트"
creation: 2026-09-29
modification: 2026-10-06
status: "done"
tags:
 - "arachne"
 - "task"
 - "philosophy"
aliases:
 - "philosophy-kickoff-prompts"
---
FROM:: [[2026-09-29-programming-philosophy-integration]]

> 이 문서는 철학 이식(P0~P4)을 단계별로 시작할 때 붙여 넣던 프롬프트 기록이다. 실행 순서는 이후
> [로드맵](2026-10-05-arachne-roadmap.md)의 웨이브(W0~W7)로 대체됐고, 철학 이식은 W4까지 반영을 마쳤다.

# Claude Code 착수 프롬프트 — 프로그래밍 철학 이식 (Arachne)

집에서 Arachne 저장소를 연 Claude Code에 단계별로 붙여 넣는 프롬프트 모음.
**한 세션에 한 단계만** 진행한다. 각 단계는 별도 브랜치·별도 PR.

---

## 0. 사전 준비 (사람이 직접, 1회)

1. 받은 두 파일을 저장소에 둔다.
   - `programming-philosophy.md` → `docs/idea/2026-09-29-programming-philosophy.md`
   - `2026-09-29-programming-philosophy-integration.md` → `docs/task/2026-09-29-programming-philosophy-integration.md`
2. `git pull`로 main 최신화. 기준 커밋이 `d6e260d`보다 앞서 있으면 P0 프롬프트가 줄 번호 재확인을 먼저 한다.

---

## P0. 결정 확정 + 계획 정합성 확인

```
docs/task/2026-09-29-programming-philosophy-integration.md(이하 "계획")와
docs/idea/2026-09-29-programming-philosophy.md(이하 "철학")를 읽어라.

이번 세션 목표: 결정 확정과 계획 검증만 한다. 규칙 파일은 수정하지 않는다.

1. 결정: 사용자는 모든 결정을 권장안으로 확정했다(2026-09-29).
   - 철학 §1의 D01~D17: 각 항목의 (기본) 선택지를 [x]로 표시.
   - 계획 §3.1의 D18~D23, §3.3 실행 방식: (권장) 선택지를 [x]로 표시.
   - 각 결정 아래 "- 결정일: 2026-09-29 / 사유: 권장안 일괄 채택" 한 줄 추가.
   - D06 핫패스 표시 위치는 "코드의 // HOTPATH 주석"으로 기입.
   - D16은 C11 / C++20 / Rust 2024.
2. 계획 §4의 모든 파일·줄 번호가 현재 HEAD에서 유효한지 확인하라.
   기준 커밋은 d6e260d다. 어긋난 항목은 계획 표를 현재 줄 번호로 고치고
   개정 로그에 한 줄 남겨라.
3. docs/decisions/0005-programming-philosophy.md를 기존 ADR(0002-systems-profiles.md)
   형식으로 작성하라. 상태 Accepted, D18~D23과 D01·D03·D05·D06·D16 요약.
   docs/decisions/README.md 인덱스 갱신.
4. 계획의 P1~P4를 docs/task/ 문서 4개로 분해하라(docs/template/task.md 형식,
   FROM:: 계획). 계획 §2 표의 상태 열에 task 링크를 건다.
5. bash tests/check_index.sh, bash tests/check_convention_sync.sh 통과 확인.

브랜치: docs/philosophy-p0. 완료 후 /verify → 커밋 → PR.
보고: 줄 번호 수정 내역, 생성 파일 목록, 테스트 결과.
```

---

## P1. 사실 오류 수정

```
docs/task/의 P1 task 문서와 계획 §4 P1 표(E1~E9)를 읽어라.
이번 세션은 E1~E9만 수정한다. 그 외 규칙 변경은 하지 않는다.

- 각 항목은 표의 "변경" 열대로 고친다. 예시 코드를 바꾸면 컴파일 가능한 형태로 쓴다.
- AGENTS.md를 고치면 대응하는 rules 파일과 문장을 맞춘다(SSOT 드리프트 금지).
- E6은 링크 대상 절이 아직 없으므로 "P3에서 rules/systems/philosophy.md 동시성 절로
  연결 예정" 주석으로 처리한다.

완료 기준(계획 P1 완료 기준 + 아래):
- grep -rn "strncpy" rules agents AGENTS.md 결과에 "권고"로 읽히는 줄이 없을 것
- bats tests/*.bats, tests/check_index.sh, tests/check_convention_sync.sh 통과

브랜치: fix/philosophy-p1-factual. 수정 전 [PLAN]으로 변경 목록을 먼저 보여줘라.
완료 후 code-reviewer 에이전트로 리뷰 → /verify → 커밋 → PR.
task 문서의 체크박스와 상태를 갱신하라.
```

---

## P2. 규칙 충돌 해소

```
docs/task/의 P2 task 문서, 계획 §4 P2, docs/decisions/0005를 읽어라.
결정은 전부 확정되어 있다. 결정과 다르게 판단되는 지점이 있으면 수정하지 말고 보고하라.

작업 순서(의존성 순):
1. D18 불변성: rules/common/patterns.md에서 절 삭제·대체 → rules/javascript,
   rules/python으로 이동 → AGENTS.md → agents/code-reviewer.md 범위 한정.
2. D19·D20 네이밍·헤더: rules/common/coding-style.md → rules/{c,cpp,rust}/* →
   AGENTS.md → tests/check_convention_sync.sh 토큰 확인.
   C/C++ 하우스 스타일(PascalCase 함수, g_ 전역)은 유지. ii 규칙과 _t 접미사는 폐지.
   Rust는 //!·/// 문서 주석과 Rust API Guidelines.
   하네스 자체 bash 스크립트의 기존 헤더는 건드리지 않는다(D01).
3. D21 테스트 강제 수준, D03·D16 C++ 정합, D05 NULL 체크 조정.

변경 전후 wc -c rules/common/*.md를 기록해 보고에 넣어라(증가 금지).
계획 §6.2의 grep 감사 중 P2 해당 항목이 0건인지 확인하라.

브랜치: refactor/philosophy-p2-conflicts. [PLAN] → 수정 → code-reviewer → /verify → PR.
```

---

## P3. 철학 본문 이식

```
docs/task/의 P3 task 문서, 계획 §4 P3, docs/idea/2026-09-29-programming-philosophy.md를 읽어라.

1. rules/systems/philosophy.md 신설. paths frontmatter는 계획 D23 목록.
   철학 §2~§11의 [공통]·[Linux/시스템] 항목과 §12 압축본을 옮긴다.
   P2에서 확정된 하우스 스타일과 충돌하는 문장은 넣지 않는다
   (포매팅·네이밍은 rules/<언어>/coding-style.md를 정본으로 참조).
2. rules/systems/decisions.md 신설: 철학 §1 + 계획 D18~D23 확정본.
3. [C/C++]·[Rust]·[Linux/C] 항목은 rules/{c,cpp,rust}/patterns.md에 병합.
   기존 내용과 중복되는 항목은 한쪽으로 통합하고 중복을 남기지 않는다.
4. rules/common/agents.md, agents/planner.md, rules/README.md, CLAUDE.md 트리,
   AGENTS.md(1~2줄만) 갱신.
5. rules/systems/*.md 합계 20KB 이하. 초과하면 보고하고 멈춰라.

검증: tests 전체 + 새 세션에서 .c 파일을 열었을 때 rules/systems가 로드되는지
확인하는 방법을 보고에 적어라.

브랜치: feat/philosophy-p3-rules. [PLAN] → 수정 → code-reviewer → /verify → PR.
```

---

## P4. 공백 보강

```
docs/task/의 P4 task 문서와 계획 §4 P4를 읽어라.

1. agents/debugger.md 진단 절차 확장(재현 → 최근 변경/bisect → 가설·증거 분리 →
   최소 수정 → 재현 테스트 → 유사 패턴 검색).
2. agents/code-reviewer.md 시스템 프로그래밍 절 보강.
3. D22: skills/latency-critical-systems 분리. 기존 웹 지연 내용은 새 스킬
   (이름은 기존 스킬 명명 규칙에 맞춰 제안 후 확정)로 이동하고, latency-critical-systems는
   프로세스 내부 핫패스로 재작성. skills/README.md, docs/USAGE.md, 모든 스킬 개수 표기 갱신.
   skill_meta.bats 형식 준수.
4. rules/c/testing.md, rules/cpp/testing.md에 libFuzzer·차분 테스트·장애 주입.
5. skills/trading-systems 표기법 절, skills/cpp-patterns CP.100 링크(E6) 최종 연결.
6. rules/common/performance.md 상단 안내 한 줄.

브랜치: feat/philosophy-p4-gaps. [PLAN] → 수정 → code-reviewer → /verify → PR.
```

---

## P5. 검증 (P4 머지 후 새 세션)

```
계획 §6(P5)의 검증을 수행하라. 코드 수정은 하지 않는다.

1. 6.1 자동 테스트 전체 실행.
2. 6.2 grep 감사 4종 — 각 결과 건수를 표로.
3. 6.3 행동 검증 시나리오 1~4를 scratch 디렉터리(/tmp 아래 임시 프로젝트)에서 수행.
   시나리오 2는 구현 컨텍스트를 모르는 별도 서브에이전트에게 리뷰만 맡겨라.
4. 6.4 컨텍스트 비용: P0 시점 대비 rules/common, rules/systems 용량.

결과를 docs/issue/2026-MM-DD-philosophy-integration-verification.md로 작성
(docs/template/issue.md 형식). 실패 항목은 원인 가설과 함께 적고,
계획 문서 상태를 done 또는 잔여 task 링크로 갱신하라.
```

---

## 운용 메모

- 세션 중간에 끊기면 `/handoff`로 상태 저장 후, 다음 세션은 해당 task 문서부터 읽게 한다.
- 각 단계 프롬프트 첫 줄에 "이전 단계 PR이 머지되었는지 git log로 확인하고,
  아니면 멈춰라"를 붙이면 순서 역전을 막을 수 있다.
- Explore·Plan 서브에이전트에 위임할 때는 rules/common/agents.md 규칙대로
  핵심 규칙을 프롬프트에 재기술해야 한다(P3 이후에는 §12 압축본 포함).
