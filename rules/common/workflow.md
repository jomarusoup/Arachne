## AI 역할 분담 (Claude / Codex / Gemini) — 3-레인

> Claude Code가 **중심(오케스트레이터 + 주 구현자)**이고, Codex·Gemini는 위임 대상이다.
> 각 CLI는 `AGENTS.md`(공통 규약)를 공유하므로 인계 마찰이 작다.

| 레인 | 담당 CLI | 호출 | 하는 일 |
| --- | --- | --- | --- |
| **오케스트레이터 + 주 구현자** | **Claude** | (중심) | 설계·구현·리팩터링·통합·커밋, 보안/임계 리뷰, 설정·마이그레이션·인프라 |
| **tester / fixer** | **Codex** | `codex-task` (= `ctask`) | 테스트 작성·실행, 버그 수정. **기능 추가는 안 함** |
| **reader / advisor** | **Gemini** | `gemini-task` (= `gtask`) | 대용량 읽기·요약, 설계 탐색, 1차 리뷰, 장문 생성. **구현은 안 함** |

### 두 개의 우선순위 사슬 (방향이 반대)

| 축 | 기준 | 우선순위 |
| --- | --- | --- |
| **오프로드** (싸게 떠넘김) | 비용 | Gemini → Codex → (Claude 안 씀) |
| **실행 후보 폴백** | 가용성 | Claude → **Codex** → Gemini |

> 핵심: 토큰 무겁고 정밀도 덜 중요한 일은 **Gemini 먼저**(한계비용 ≈ 0).
> 테스트·검증은 **Codex 레인**(구현자와 다른 모델이라 맹점 탈상관).
> Claude 쿼터 소진 시 자동 중심 이양은 없다. 별도 세션과 `/handoff`로 사람이 인계한다.
> Gemini는 코딩 스타일 충실도가 낮아 **최종 구현 코드 생성은 맡기지 않는다.**

### 사용량 소진 시 실행 후보와 수동 인계

**불변식**: 3-레인 위임 모드에서는 Claude가 오케스트레이터 + 주 구현자 + **유일 커미터**다.
Claude가 소진되면 자동으로 중심이나 커밋 권한이 이동하지 않는다. 별도 Codex/Gemini 세션을
중심으로 사용할지는 사람이 명시적으로 결정하고 `/handoff`로 상태를 넘긴다.

| 단계 | 가용 CLI | `atask` 자동 후보 | 실제 역할 | 인계·주의 |
| --- | --- | --- | --- | --- |
| **L0 정상** | Claude·Codex·Gemini | Claude | 구현·통합·커밋 | 기본 3-레인 |
| **L1 Claude 소진** | Codex·Gemini | `codex-task` | tester/fixer | 구현 완료 아님. 사람 인계·검증 필요 |
| **L2 Claude+Codex 소진** | Gemini | `gemini-task` | reader/advisor | 구현 완료 아님. 사람 인계·검증 필요 |
| **L3 전부 소진** | 없음 | 없음 | — | 쿼터 회복 대기 |

**분기 — 중심은 Claude 유지, 위임 대상 하나만 소진된 경우:**

| 소진된 대상 | 역할 재배치 | 영향 |
| --- | --- | --- |
| **Codex만 소진** | Claude가 tester/fixer를 직접 흡수(테스트 작성·실행을 본인이) | 구현·검증을 같은 모델이 맡아 **맹점 탈상관 효과↓** — 리뷰 더 신중 |
| **Gemini만 소진** | 읽기·요약·1차 리뷰를 Claude(또는 Codex)가 직접 | **토큰 절약 효과↓**, 구현 품질엔 영향 없음 |

**솔로 모드 — Codex/Gemini가 아예 설치되지 않은 환경 (Claude 단독):**

소진과 동일한 역할 재배치를 **상시로** 적용한다. Claude가 세 레인(읽기·요약 / 테스트 작성·실행 /
구현·리뷰·커밋)을 모두 직접 수행하며, 에이전트·스킬·훅·커맨드 등 하네스 기능은 전부 그대로 동작한다.

- 위임을 시도하면: `gtask`/`ctask`는 하위 CLI 미설치를 감지해 안내 메시지와 함께 **종료코드 127**로
  즉시 실패하고, `atask`는 127을 쿨다운 없이 다음 후보로 건너뛴다. 잘못된 호출이 조용히 실패하지 않는다.
- 비용 오프로드가 없으므로 대용량 읽기는 `sgrep`으로 범위를 좁혀 직접 읽는다.
- 구현과 검증을 같은 모델이 맡는 만큼(맹점 탈상관 없음) 리뷰·`/verify`를 한 단계 더 신중하게 한다.
- 규율의 최종 게이트는 프로젝트 CI(`.arachne/verify.sh`)로 동일하다 — 위임 유무와 무관.
- 이후 Codex/Gemini를 설치하면 `arachne -i` 한 번으로 3-레인 위임이 활성화된다.

> 원칙: ① `atask` 종료코드 0을 구현 완료로 간주하지 않는다. ② Codex/Gemini 결과는 역할 계약에 맞게
> 검토한다. ③ 중심 변경과 커밋 권한 이전은 자동 상태가 아니라 사람이 명시적으로 수행하는 운영 결정이다.

**자동화 — `atask` (= `arachne-task`)**: 역할별 실행 후보 순서를 자동화한다. 역할별 우선순위
(`-R impl|read|test|review`)로 헤드리스 CLI를 시도하고, 출력의 쿼터·rate limit 패턴을 감지하면 그 CLI를
쿨다운(`~/.claude/arachne-quota-state`) 등록 후 다음으로 자동 전환한다. 쿼터가 아닌 일반 에러는
폴백하지 않고 중단한다(토큰 낭비 방지). 소진 상태는 `atask-quota-warn.sh` 훅이 프롬프트마다 사전 경고한다.
Codex와 Gemini는 각각 기존 tester/fixer, reader/advisor 래퍼로 호출되므로 `impl` 역할을 그대로 승계하지 않는다.
**헤드리스 전용** — 대화형 세션 중간 구제는 못 하므로 그땐 `/handoff`로 인계한다. 상세는 `docs/MULTI-CLI.md` §5.1.

---

## Gemini 위임 — `gemini-task` (= `gtask`)

Claude Code가 **별도 터미널 전환 없이 Bash로 `gemini-task`를 직접 호출**해 Gemini에 위임하고
답변을 받아온다. (`gemini -p` 래퍼, 경고·노이즈 제거 후 답변만 stdout)

```bash
gemini-task "이 설계 검토해줘: $(cat module.c)"            # 자문 → 답변 stdout
gemini-task "이 로그에서 에러 원인만 요약: $(cat app.log)"  # 요약 → 답변 stdout
gemini-task "README 초안 작성" > README.md                  # 생성 → 파일로, 내용 재독 금지
gemini-task -m gemini-2.5-flash "간단 질의"                 # 모델 지정 (선택)
```

### 비용 라우팅 — 무엇을 어떻게 위임할지

| 패턴                      | 예시                          | 방식                                | 비용                          |
| ------------------------- | ----------------------------- | ----------------------------------- | ----------------------------- |
| **끌어오기 (요약·자문)**  | 대용량 읽기, 설계 검토, 조사  | `gemini-task "..."` → 답변 받아 사용       | 🟢 절약 (큰 입력 → 작은 출력) |
| **쏟아내기 (문서 생성)**  | README, 설계 문서, 장문       | `gemini-task "..." > file` → **재독 금지** | 🔴 읽으면 절약 상쇄           |

> 원칙: Gemini 답을 Claude 컨텍스트로 **끌어오는 건 요약·자문일 때만**.
> 장문 생성은 파일로 빼고 Claude는 존재만 확인한다(내용을 다시 읽으면 절약 효과가 사라진다).

---

## Codex 위임 — `codex-task` (= `ctask`)

Claude Code가 **Bash로 `codex-task`를 직접 호출**해 테스트 작성·실행과 버그 수정을 Codex에
위임하고 결과만 받아온다. (`codex exec` 래퍼, 헤더·메타·경고 제거 후 결과만 stdout)

```bash
codex-task "tests/ 의 parser 테스트 보강안 제시: $(cat src/parser.c)"  # 제안만 (read-only 기본)
codex-task -w "실패하는 test_auth 를 green 까지 수정"                   # 직접 실행·수정 (workspace-write)
codex-task -r "이 함수 리뷰만 해줘"                                     # 역할 주입 없이 raw
```

### 통합 경계 (A안 — Claude가 유일 커미터)

| 모드 | 플래그 | Codex 동작 | Claude 동작 |
| --- | --- | --- | --- |
| **제안 (기본)** | 없음 | 테스트 코드·수정 diff 를 stdout 으로 반환, 트리 미변경 | 받아서 적용·실행·커밋 |
| **실행** | `-w` | 테스트를 직접 쓰고 돌려 green 까지 수정, 변경을 트리에 남김 | `git diff` 검토·스타일 보정·커밋 |

> `codex-task` 는 블로킹 호출이라 Claude가 결과를 받을 때까지 대기 → 순차 실행이라
> 두 모델이 같은 파일을 동시에 건드리는 충돌이 없다. **커밋은 항상 Claude가 한다.**
> Codex 산출물은 `AGENTS.md`(다이제스트)만 따르므로, 통합 시 Claude가 `rules/` 풀
> 규칙(헤더·네이밍 등)으로 스타일을 보정한다.

---

## git-bus 감지 (보조 경로)

업스트림 브랜치에 새 커밋이 추가됐는지 확인하는 git 기반 감지도 유지한다.
작성자가 사람인지 Gemini/Codex인지 판별하지 않으며, 미푸시 로컬 커밋은 감지하지 않는다.

| 시점           | 동작                                                                  |
| -------------- | --------------------------------------------------------------------- |
| 메시지 입력 시 | `UserPromptSubmit` 훅 → `git-bus-check.sh` (fetch 후 origin HEAD 비교) |
| 세션 종료 시   | `session-end.sh` → 리모트 HEAD를 `.claude/last-seen-commit` 저장      |
| 감지 시        | 마지막 기준점 이후 새 커밋 목록·변경 파일 출력 후 기준점 갱신         |
| 중복 방지      | 이미 확인한 커밋은 재출력 안 함                                       |

> AI 사이 직접 채널은 `gemini-task`/`codex-task`(동기 호출)와 git 히스토리(비동기 메시지 버스)다.

---

## 전역 행동 규칙

- **파일 전체 읽기 금지** — `sgrep <키워드>`로 위치 먼저, 해당 범위만 Read
  - `sgrep`은 `~/.bash_profile`의 전용 검색 함수로 전 확장자를 커버
  - 심볼 정의·호출 관계·변경 영향 범위는 `codegraph`가 설치된 경우(`command -v codegraph`)
    `sgrep` 본문 훑기 전에 먼저 쓴다 — 다중 grep 왕복을 인덱스 한 번으로 대체한다(미설치 시
    `sgrep` 폴백). 조사 라우팅 상세는 `rules/common/performance.md`
  - 대용량 일괄 분석은 Read 대신 `gemini-task`로 Gemini에 요약 위임 (Claude 입력 토큰 절약)
- **테스트·검증은 `codex-task`로 Codex에 위임 고려** — 구현(Claude)과 검증(Codex)을 다른
  모델이 맡으면 상관된 맹점이 줄어든다. 기본은 제안 모드, 직접 수정은 `-w`.
- **Gemini 자문은 저비용 sanity check 후 채택** — Gemini 설계를 출발점으로 받되,
  구현 직전 명백한 결함만 1회 가볍게 검토한다(전체 재분석 금지 — 틀린 설계 구현이
  더 큰 토큰 낭비이므로 가벼운 점검은 오히려 절약).
- **장문 문서는 Gemini가 파일로 직접 출력** — Claude는 내용 재독 금지(사용자 명시 요청 시 예외)
- **Codex/Gemini 산출물의 최종 통합·커밋은 Claude가** — 위임 결과를 받아 스타일 보정 후 커밋
- **병행 중복 작업 금지** — 위임한 작업을 Claude가 선제 중복 수행 금지
- **수정 전 보고** — 기능 추가·삭제 전 `[PLAN]`으로 승인 요청
- **코딩 스타일 준수** — `rules/common/coding-style.md` 적용
- **수정 완료 시 자동 git push** — 수정 → `/verify` → `git push` 순서로 진행
