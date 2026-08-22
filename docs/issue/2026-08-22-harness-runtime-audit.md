---
Title: "[audit] 하네스 런타임 감사 — 서브에이전트 컨텍스트·훅 발화·커맨드 조정·쿼터 동시성"
creation: 2026-08-22
modification: 2026-08-22
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "audit"
aliases:
 - "harness-runtime-audit-2026-08"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [audit] 하네스 런타임 감사 — 서브에이전트 컨텍스트·훅 발화·커맨드 조정·쿼터 동시성

- **작성일**: 2026-08-22
- **유형**: audit
- **검수 기준**: `26986c9` (branch `audit`)
- **범위**: Q1 rules/의 서브에이전트 로드 여부 · Q2 훅의 서브에이전트 발화와 git-bus 오탐/미탐 ·
  Q3 슬래시 커맨드 19개 조정 로직 분류 · Q4 쿼터 소진 감지와 동시 16 프로세스 동작

## 요약

| 질문 | 판정 |
| --- | --- |
| Q1 rules → 서브에이전트 로드 | **확인 불가.** 저장소 내 로드 장치는 `install.sh`의 심볼릭 링크뿐이고, 모든 문서 주장은 "세션/파일 편집" 스코프다. 서브에이전트 컨텍스트 주입을 주장·구현·검증하는 설정/코드/테스트는 0건. 실험 B(전사 관찰)·보조 수단(`--debug` 헤드리스) 모두 (b) 관측 불가 — **최종 상태: 미해결 — 관측 수단 부재**(B-10). 상세·ADR 취급은 Q1 절 참고 |
| Q2 훅의 서브에이전트 발화 | 등록 이벤트는 5종뿐(`settings.template.json:24-88`), `SubagentStop`·`PreToolUse` 미등록 — 서브에이전트 종료 시 실행될 훅 자체가 없음(설정 근거 확정). UserPromptSubmit·SessionStart·PreCompact·Stop이 메인 세션 수명주기 이벤트라는 것과 PostToolUse의 서브에이전트 도구 호출 발화 여부는 저장소 근거 없음 → [추정] + 검증 방법 제시 |
| Q2' git-bus 오탐/미탐 | 코드 근거로 오탐 2계열(worktree별 상태 분리로 동료 커밋 재공지, 업스트림 미설정 브랜치의 로컬 HEAD 폴백로 자기 커밋 공지)·미탐 3계열(미푸시 로컬 커밋, rebase/force-push 후 조용한 기준점 점프, 동일 폴더 2세션 상태 공유 경합) 판정 |
| Q3 커맨드 분류 | 조정 로직 보유 15 / 단순 템플릿 4 (`fix`·`status`·`handoff`·`save-session`). 조정 로직 최강 3개: `git`·`worktree`·`issue` |
| Q4 쿼터 감지·동시성 | **질문 전제 교정**: `codex-task.sh`·`gemini-task.sh`에는 쿼터 감지 코드가 없다(출력 필터만). 감지·쿨다운은 `arachne-task.sh` 단일 지점. 동시 16 프로세스에서 래퍼 자체는 무간섭이나, atask 경유 시 lost update·TOCTOU 이중 소모·비원자 `mv` 경합이 코드로 확인됨(잠금 0건) |

## Q1. rules/ 가 서브에이전트 컨텍스트에 로드되는가

**판정: 확인 불가** — 저장소 안에는 긍정도 부정도 입증할 근거가 없다.

저장소가 실제로 갖고 있는 것:

- 로드 장치는 심볼릭 링크가 전부: `install.sh:93-101`의 `SYMLINK_TARGETS`(`CLAUDE.md`·`rules`·`agents` 등)를
  `install.sh:422-424`에서 `~/.claude/` 아래로 링크. 로드 자체는 Claude Code 네이티브 로더에 위임
  (`install.sh:414` 주석 "rules/ 가 ~/.claude/rules/ 로 링크돼 네이티브 자동 로드됨").
- `settings.template.json`에는 rules 관련 키가 없다 (전체 95줄: statusLine·theme·model·permissions·hooks·enabledPlugins뿐).
- 문서 주장은 전부 "세션" 스코프: `rules/README.md:10-19` "매 세션 자동 로드", `docs/ARCHITECTURE.md:350-354`
  "세션 시작 시 … 파일을 열 때", `CLAUDE.md` 상단 주석 동일. **"서브에이전트"와 "rules 로드"를 연결하는 문장은 저장소 어디에도 없다.**
- `agents/` 8개 중 rules를 언급하는 것은 4개뿐이며 전부 산문 포인터다(자동 로드 구문 아님):
  `agents/code-reviewer.md:187,258-261`, `database-reviewer.md:110`, `fastapi-reviewer.md:149`, `react-reviewer.md:151`.
  나머지 4개(`planner`·`tdd`·`debugger`·`python-reviewer`)는 언급 자체가 없다.
- 리뷰어 4종의 "상위 프로젝트 규칙을 무시·재정의하지 않는다" 문구(각 파일 L10-13)는 규칙이 컨텍스트에
  *있다고 전제*할 뿐, 로드 메커니즘이 아니다.

즉 서브에이전트가 rules를 본다는 믿음은 하네스의 규율 설계(리뷰어가 coding-style 준수를 검사)에 깔려
있으나, 검증된 적이 없다. Claude Code 제품이 커스텀 에이전트의 시스템 프롬프트에 CLAUDE.md/rules를
주입하는지는 제품 동작이며 저장소만으로 판정 불가.

### 검증 실험 2종 비교와 권장안

| | 실험 A — 행동 관찰(암송) | 실험 B — 프롬프트 직접 관찰 |
| --- | --- | --- |
| 방법 | rules 미참조 에이전트(`planner` 권장 — 도구가 Read/Grep/Glob뿐이라 Bash 우회 없음)에게 **도구 사용 금지** 조건으로 rules/common 고유 문구 암송 요구. 예: "coding-style 규칙에서 단일 문자 변수를 무엇으로 대체하라고 하는가?" (정답 `ii`/`jj`는 통용 규약이 아닌 하네스 고유 값) | `claude --debug` 실행(또는 `~/.claude/projects/<프로젝트>/*.jsonl` 세션 전사)에서 Task 도구 호출 시 서브에이전트에 실제 구성된 시스템 프롬프트를 열어 rules/common 텍스트 포함 여부를 직접 확인 |
| 위양성(로드 안 됐는데 "로드됨" 오판) 경로 | ① 모델이 일반 지식으로 유사 규칙을 그럴듯하게 생성 ② 에이전트 .md 본문에 이미 규칙 파편이 있음(code-reviewer 등 4종은 부적합) ③ 에이전트가 Read/Grep으로 파일을 읽어버림(도구 회수 또는 도구 사용 여부 확인 필요) | 관찰 대상이 모델 행동이 아니라 **주입된 텍스트 그 자체**라 추측이 개입할 자리가 없음 — 위양성 위험 사실상 0 |
| 위음성/판정 불가 위험 | 로드됐는데 모델이 암송에 실패(낮음) | 디버그 로그가 서브에이전트 프롬프트 전문을 출력하지 않는 빌드일 수 있음 → 판정 불가로 끝날 위험 |

**권장: 실험 B를 1차로.** 위양성 위험이 구조적으로 낮다(행동 추론이 아니라 원문 관찰). 로그에 프롬프트가
노출되지 않으면 실험 A를 보강판으로 실행하되, 반드시 **일회용 nonce 카나리아**(임의 문자열 한 줄을
`rules/common/coding-style.md`에 임시 추가 → 암송 확인 → 원복)를 쓸 것 — nonce는 추측 불가라 실험 A의
위양성 경로 ①②가 모두 차단된다.

### 검증 결과 (2026-08-22, 실험 B 실행)

**판정: 관측 불가 (b)** — 대조군·실험군 모두. 세션 전사(jsonl)와 서브에이전트 태스크 전사에는
시스템 프롬프트/컨텍스트 주입이 **기록되지 않아**, 주입 여부를 전사 관찰로는 판정할 수 없다.
부재의 증거가 아니라 증거의 부재이며, "주입 안 됨"으로 읽어서는 안 된다.

- 환경 전제: `~/.claude/rules → /home/Arachne/Arachne/rules` 실측 확인(체크아웃 브랜치 `audit`이
  곧 전역 하네스, B-09 참조).
- 대조군(메인 세션 전사 `~/.claude/projects/-home-Arachne-Arachne/<session>.jsonl`, 261라인):
  이 세션에서 타이핑된 적 없는 신선 프로브 3종(`연결_실패시_재시도_3회`·`커밋 전 필수 체크리스트`·
  `다중 세션·병렬 작업 — git worktree`) 전부 0건. `system-reminder`·`claudeMd` 문자열 0건. 레코드
  type 분포에 시스템 컨텍스트를 담는 타입이 없음(user/assistant/message/attachment 등만 존재) →
  전사는 대화 메시지만 영속화하고 컨텍스트 주입은 기록하지 않는다.
- 실험군 1(`planner`, 도구 사용 금지 프롬프트, tool_use 0건): 태스크 전사 2라인(내 프롬프트 user
  레코드 + "OK" assistant 레코드)이 전부. P 마커(`Universal Implementation Planner Guide`, 본문
  고유 문구) **0건** → 시스템 프롬프트 미기록 → (b). R1·R2·R3 0건은 이 상태에서 판정 근거가 되지
  못한다.
- 실험군 2(`code-reviewer`, 동일 프롬프트, tool_use 0건): 동일하게 2라인. P 마커(`신뢰도 기반
  필터링`) **0건** → (b). 두 호출의 판정은 갈리지 않았다.
- 부수 관측(usage 메타데이터, 구성 판정 불가): planner 호출 `cache_creation_input_tokens=25140`·
  모델 `claude-opus-5`, code-reviewer 호출 `27921`·`claude-sonnet-5` — 서브에이전트에 ~25k 토큰
  규모의 시스템 컨텍스트가 *존재*하고 frontmatter `model` 라우팅이 동작함은 확인되나, 그 컨텍스트에
  rules가 포함되는지는 전사로 관측 불가. [추정 금지 — 크기만으로 구성을 추론하지 않는다]
- 후속: 실험 A(nonce 카나리아)는 미수행으로 확정(파일 수정 금지 지시). 향후 수행하려면 제약 —
  심볼릭 링크로 인해 전역 즉시 반영되므로 다른 세션 부재 확인, worktree 금지(링크가 원본 레포를
  가리켜 worktree 수정은 무효), 무의미 난수 문자열 사용, 실험 후 `git status`와 `~/.claude/rules`
  양쪽에서 원복 확인.

### 보조 수단 결과 (2026-08-22, `claude --debug -p` 헤드리스 1회) — 최종 (b) 확정

**Q1 상태: 미해결 — 관측 수단 부재.**

- 실행: 빈 디렉터리 `/tmp/claude-probe`(프로젝트 설정·훅 오염 배제)에서
  `ANTHROPIC_LOG=debug claude --debug -p '<planner 서브에이전트 1회 호출 지시>'` 1회.
- **서브에이전트 호출은 확인됨**: 요청 로그 3건 중 2번째가 `model: "claude-opus-5"`(planner
  frontmatter `model: opus`와 일치), `tools: [3개]`(planner의 Read·Grep·Glob 3개와 일치),
  요청 헤더에 `x-claude-code-agent-id` 존재 — 메인 요청(fable-5, tools 12개)과 구조적으로 구분되는
  별도 API 호출. 최종 stdout 말미 `OK`.
- **그러나 페이로드 본문은 전부 생략 출력**: `system: [ [Object ...], [Object ...], [Object ...] ]`,
  `messages: [ [Object ...] ]` — SDK 로거가 중첩 객체를 자리표시자로 접어 시스템 프롬프트 원문이
  노출되지 않는다. P1 = 0건(생략 출력이라는 구조적 사유가 로그에서 직접 확인됨) → 판정 규칙에 따라
  **(b) 관측 불가 확정**. 시도 1회 제약에 따라 종료.
- 관측 가능했던 유일한 구성 정보: 시스템 블록 *개수*(메인 4개 vs 서브에이전트 3개) — 내용 판정에는
  사용 불가.
- 부수효과 보고: repo `git status`·git-bus 상태 파일(`last-seen-commit`·`last-fetch-epoch`)은 실행
  전후 mtime·내용 불변, `/tmp/claude-probe`에 파일 생성 없음. 단 **프로브 세션의 Stop 훅
  (session-end.sh)이 `~/.claude/sessions/auto-2026-08-22.md`를 덮어씀**(927B, 브랜치 `audit` 정보 →
  426B, "브랜치: N/A / (git 없음)"). 19:33 시점 스냅샷 내용은 **유실됐고 복구 불가**하다 — 이후
  세션이 같은 파일을 다시 덮어써도 그것은 새 내용이지 복원이 아니다. [현행 결함] **B-11**로 승격.
- ADR 취급 한 줄: **ADR은 Q1을 "미검증 가정"으로 명시하고, 주입 여부 어느 쪽이어도 성립하는
  완화책(에이전트 본문에 핵심 규칙 명시 포함 + 구조적 강제)을 채택 근거로 삼아야 한다.**

### Q1 미해결이 ADR 결론에 미치는 영향

검토 논지: "rules 주입 여부와 무관하게 프롬프트 계층의 지시는 강제력이 아니므로, Q1의 답은 문제의
크기를 바꾸지 방향을 바꾸지 않는다. 따라서 Q1 미해결 상태로 ADR을 진행할 수 있다." (논지가 인용한
C-10은 이 보고서 번호로는 **C-08**(프롬프트 의존 게이트)에 해당한다 — C-10은 래퍼 증폭 항목.)

**동의하며, 근거를 보강한다.** 주입이 되더라도 프롬프트 계층은 확률적 준수만 제공하고, 집행은 어차피
구조 계층(CI·`.arachne/verify.sh`·훅 차단·allowed-tools)이 담당해야 한다는 것이 이 감사의 C-08
판정이자 `AGENTS.md:173-179`("최종 게이트는 프로젝트 CI")가 이미 선언한 방향이다. 따라서 Q1의 답은
"규칙 드리프트가 얼마나 자주 생기는가"(크기)를 정하지, "구조적 강제가 필요한가"(방향)를 바꾸지
않는다. 단 하나의 단서: 만약 답이 "주입 안 됨"이면 리뷰어 에이전트 4종의 전제("상위 프로젝트 규칙"
존재)가 조용히 공허해지므로, 완화책의 **우선순위**(에이전트 본문에 핵심 규칙 명시 주입을 선행)는
달라질 수 있다 — 이는 같은 방향 안의 순서 문제다. 결론: ADR은 Q1을 미검증 가정으로 기록하고, 주입
여부에 강건한 완화책을 전제로 진행 가능하다.

## Q2. 훅은 서브에이전트 실행 시에도 발화하는가

### 설정 근거로 확정되는 부분

`settings.template.json:24-88` 등록 현황: `UserPromptSubmit`(git-bus-check, atask-quota-warn) ·
`PostToolUse` matcher `Edit|Write`(doc-drift-check) · `SessionStart`(session-start, ua-stale-check) ·
`PreCompact`(pre-compact) · `Stop`(session-end). **`SubagentStop`·`PreToolUse` 등록 0건**(저장소 전체
grep에서도 `SubagentStop` 0건) — 서브에이전트 종료 시점에 실행될 훅은 등록 자체가 없다. 이것은 설정
파일로 확정되는 사실이다.

### [추정]으로만 판정 가능한 부분

저장소 문서(`rules/common/hooks.md`의 훅 표, `docs/USAGE.md:152-200`, `docs/ARCHITECTURE.md:265-300`)는
훅 실행 주체를 단일 액터 "Claude Code"로만 그리며 서브에이전트와의 상호작용을 어디에도 서술하지 않는다.
이벤트 의미론에 따르면:

- `UserPromptSubmit`·`SessionStart`·`PreCompact`·`Stop`: 사용자 프롬프트 제출·세션 시작·압축·메인 응답
  종료라는 **메인 세션 수명주기 이벤트**로, 서브에이전트 실행 중에는 발화할 계기가 없다 [추정 — 이벤트
  명칭·`rules/common/hooks.md:13-20`의 시점 서술 기반, 저장소 내 직접 근거 없음].
- `PostToolUse`(doc-drift-check): 서브에이전트의 Edit/Write 호출에도 발화하는지가 쟁점이다. 발화한다면
  `tdd`·`debugger`(둘 다 Write·Edit 보유)가 기능 파일을 고칠 때도 문서 갱신 알림이 나온다 [추정 —
  제품 동작, 저장소 근거 없음]. **검증 방법**: `tdd` 에이전트에 스크래치 `*.sh` 파일 편집을 시키고
  doc-drift 알림 출현 여부 확인 + `~/.claude/.docdrift-seen-<session_id>` 마커 생성 여부 확인
  (`doc-drift-check.sh:43-47`이 세션별 마커를 남기므로 발화 여부가 파일시스템에 증거로 남는다).

### git-bus-check.sh — /worktree 병렬 실행에서의 오탐/미탐 (코드 근거)

전제 구조: `REPO_DIR=$(git rev-parse --show-toplevel)`(`git-bus-check.sh:13`)은 훅의 CWD 기준이고,
상태 파일 `"$REPO_DIR/.claude/last-seen-commit"`(L53)·fetch 스탬프(L24)는 그 아래에 있다. linked
worktree에서 `--show-toplevel`은 worktree 디렉터리를 반환하므로 **기준점·스로틀이 worktree마다 완전히
분리**된다. 공용 기준(`git rev-parse --git-common-dir`)을 쓰는 코드는 없다.

**오탐 (없는 "외부 새 커밋"을 공지)**

1. **동료(자기) worktree 커밋의 재공지.** worktree A 세션이 `/git`으로 push하면 기준점 갱신
   (`commands/git.md:84-85`)은 **A의 `.claude/`에만** 적용된다. worktree B 세션의 다음 프롬프트에서
   훅은 B의 기준점과 fetch된 upstream(L42-44)을 비교해 A의 커밋을 "업스트림 새 커밋 (작성 CLI 판별
   없음)"으로 공지한다(L83-93). 병렬 협업 관점에서는 방금 옆 세션이 만든 자기 팀 커밋이 외부 변경으로
   보고되는 오탐이다.
2. **업스트림 미설정 브랜치의 자기 커밋 공지.** `/worktree create` 직후의 `feat/<task>`처럼 `@{u}`가
   없으면 L42가 실패하고 L46이 **로컬 HEAD로 폴백**한다. 이후 로컬 커밋을 만들 때마다
   `LAST_SEEN..CURRENT_HEAD`(L75)에 자기 커밋이 잡혀 다음 프롬프트에 "업스트림 새 커밋"으로 공지된다.
   `push -u`로 업스트림이 생기기 전까지 반복된다. `/git`의 기준점 갱신(git.md:85)은 push 성공 시에만
   실행되므로 push 이전 구간을 막지 못한다.

**미탐 (실제 새 커밋을 놓침)**

3. **다른 worktree의 미푸시 로컬 커밋.** 비교 대상이 `origin` fetch 결과의 `@{u}`(L34, L42-44)뿐이므로
   push되지 않은 커밋은 구조적으로 감지 불가 — `CLAUDE.md`의 훅 설명("미푸시 로컬 커밋 미감지")도 이를
   자인한다. /worktree 병렬 작업에서 세션 간 최신 상태 공유는 push 이전에는 이뤄지지 않는다.
4. **rebase/force-push 후 조용한 기준점 점프.** upstream이 리라이트되어 `LAST_SEEN`이 도달 불가
   커밋이 되면 L75의 `git log`가 실패(`2>/dev/null`)해 `NEW_COMMITS`가 비고, L76-79가 **아무 공지 없이
   기준점을 새 HEAD로 갱신**한다 — 리라이트에 실려 온 실제 새 커밋들이 통째로 미공지된다.
5. **동일 폴더 2세션 경합.** `git-workflow.md`가 금지하는 형태지만, 같은 작업 디렉터리에서 두 세션이
   병렬이면 상태 파일을 공유한다. 세션 A의 훅이 공지 후 L110에서 기준점을 갱신하면, 세션 B는 해당
   커밋을 영영 공지받지 못한다(읽기 L66 ↔ 쓰기 L110 사이 잠금 없음). 반대로 두 훅이 동시에 L66을
   읽으면 중복 공지(경미한 오탐)가 된다.

부가: fetch 스로틀 스탬프(L24)도 worktree별이라 N개 worktree × 300초 간격으로 각자 fetch한다 —
오탐/미탐은 아니고 네트워크 부하 특성. 또한 `commands/git.md:85`는 **로컬 HEAD**를 기록하고 훅은
**upstream**을 비교하므로 push 성공 직후에만 두 값이 일치한다는 비대칭이 있다(push 성공 경로에서는
실질 문제 없음 — 관찰 사항).

## Q3. 슬래시 커맨드 19개 — 조정 로직 vs 단순 템플릿

19개 전부 frontmatter는 `description` 한 필드뿐이며 `allowed-tools`는 어느 파일에도 없다 — 커맨드의
도구 제약·게이트는 전부 프롬프트 텍스트로만 표현된다.

**단순 프롬프트 템플릿 (4)** — 선형 절차, 분기 없음:

| 커맨드 | 근거 |
| --- | --- |
| `/fix` | 6단계 선형 절차(`fix.md:10-28`), 말미 `/verify` 호출뿐 |
| `/status` | 고정 bash 스니펫(`status.md:8-24`); L26-29의 "/issue 확인"은 안내 문구 수준 |
| `/handoff` | 수집→HANDOFF.md 갱신→보고 3단계 선형, 조건 분기 0건 (`handoff.md` 전체) |
| `/save-session` | 저장 경로·형식 고정(`save-session.md:9-13`) |

**조정 로직 보유 (15)** — 강도순:

| 강도 | 커맨드 | 조정 로직 근거 |
| --- | --- | --- |
| 강 | `/git` | 최상위 **위임 라우팅**(직접 처리 vs `Agent(model:"haiku")` 위임, `git.md:9-14`) + 가드 7단계: 소유권 검사·무관 변경 시 선택 스테이징·병렬 감지 시 `/worktree status`와 함께 중단(L35-40), 브랜치 가드(L43), 검증 선행·실패 시 중단(L48-55), non-fast-forward 분기·충돌 시 중단(L79-80), git-bus 기준점 갱신(L84-85) |
| 강 | `/worktree` | **모드 디스패치 3종**(create/status/cleanup, `worktree.md:12-16`) + 인자 불명 시 중단(L20-21) + create 가드 3건(미커밋 변경·경로 존재·브랜치 존재, L36-38) + cleanup 가드 2건(L65-66) |
| 강 | `/issue` | 인자 유무 분기(L15) + **선행 이슈 미완료 시 스킵**(L18-19) + 타입별 처리 경로 라우팅 표(`[bug]→/fix`·`[feat]→planner→/add` 등, L22-27) + 타입 미표기 시 질문(L29) + 승인 게이트 + `/verify`→`/git`→code-reviewer 체인(L32-38, 89) |
| 중 | `/verify` | STEP1 실패 시 STEP2 미진행 게이트(L34) + 판정표 4분기(L63-68) + `.arachne/` 존재 여부에 따른 리포트 기록/생략 분기(L77-78) |
| 중 | `/design` | 설계 문서 4단계 폴백 체인(docs/design→루트→legacy→규칙 기준 적용, `design.md:22-26`) + 영역별 단계 승인(L54) + `/verify`→`/git` 체인 |
| 중 | `/e2e` | 프로젝트 유형 감지표 분기(L10-15) + 실패 유형별 조치 라우팅(debugger 에이전트/build-debug 스킬/strace, L99-104) |
| 약 | `/add` | 승인 게이트("승인 없이 진행 금지", `add.md:6`) → `/verify` |
| 약 | `/learn` | 패턴 성격별 저장 위치 라우팅(L11-15) + diff 승인 게이트(L17-18) |
| 약 | `/tdd` | 프로젝트 유형 감지→프레임워크 선택(L11, 24-30) + 복잡 시 tdd 에이전트 위임(L52) |
| 약 | `/refactor` | 파일 3개 이상 시 planner 선행(L33) + 테스트 부재 시 `/tdd` 선행(L51) + 실패 시 롤백(L57) |
| 약 | `/codegraph` | 설치 여부 분기(L15-17) + 인자 유무 분기(L35-37) |
| 래퍼 | `/python-review` `/fastapi-review` `/react-review` `/database-review` | 각 전용 에이전트 호출 + 승인/경고/차단 판정표(예: `python-review.md:7,84-88`; `database-review.md:11`은 순서 고정 파이프라인) |

커맨드 간 체인(본문 명시분): `/add`·`/fix`·`/design`→`/verify`→`/git`, `/e2e`→`/git`,
`/issue`→(planner|/fix|/add)→`/verify`→`/git`→code-reviewer, `/status`→`/issue`,
`/refactor`→planner·`/tdd`.

## Q4. 쿼터 소진 감지와 동시 16 프로세스 동작

### 감지 방식 — 질문 전제 교정

**`codex-task.sh`와 `gemini-task.sh`에는 쿼터 소진 감지가 없다.**

- `codex-task.sh:21`의 `ERROR_PATTERN`은 stderr에서 에러성 줄만 통과시키는 **표시 필터**이고
  (L146-155: 하위 종료코드를 그대로 전파), 쿨다운·상태 기록이 전혀 없다.
- `gemini-task.sh:17`의 `NOISE_PATTERN`은 stderr **노이즈 제거 필터**다(L92-100). 동일하게 전파만 한다.
- 두 래퍼의 유일한 특수 코드는 미설치 가드 `exit 127`(codex L106-110 / gemini L75-79)이다.

실제 감지는 `arachne-task.sh` 단일 지점에 있다:

- `QUOTA_PATTERN`(`arachne-task.sh:24`): `rate.?limit|…|429|too many requests|overloaded_error|overloaded|…|usage limit|quota exceeded|…`
- `NON_QUOTA_PATTERN`(L28): 일반 오류 신호(`syntax error|…|compil|disk quota|…`)가 있으면 쿼터로 보지 않는 네거티브 가드
- `IsQuotaError()`(L191-197): **stdout·stderr 캡처 둘 다** `grep -qiE`로 스캔 → 매칭 시 `SetCooldown` 후 다음 후보 폴백(L342-346), 비매칭 실패는 폴백 중단(L351-353), 127은 쿨다운 없이 스킵(L337-340)

감지 품질 결함(단일 실행에서도 발현):

- `429`에 단어 경계가 없어 `1429`·해시 조각에 매칭되고, bare `overloaded`·`usage limit`이 남아 있으며,
  **rc≠0이면 정상 응답 본문(stdout)에 쓰인 "rate limit" 같은 문구도 쿼터로 오판**된다.
- `NON_QUOTA_PATTERN`의 `compil` 등 부분문자열이 진짜 쿼터 응답과 컴파일 로그가 섞인 캡처에서 쿼터
  감지를 통째로 무효화한다(폴백 대신 중단).
- 닫힌 이슈 `docs/issue/2026-06-07-workflow-06-quota-false-positive.md`(status done)의 수정 방향 중
  1(CLI별 detector)·3(429 단어 경계)·4(bare overloaded 제거)·6(상태 파일에 감지 근거 기록)이
  **미반영**이다 — 반영된 것은 NON_QUOTA 가드와 bare `quota` 제거뿐.
- `docs/MULTI-CLI.md`의 감지 키워드 표는 bare `quota`를 나열하지만 코드는 매칭하지 않고, 코드의
  `too many requests`·`usage limit`은 문서에 없다(문서-코드 드리프트).

### 동시 16 프로세스 판정

**래퍼 직접 호출(codex-task/gemini-task × 16): 상호 간섭 없음.** 두 래퍼는 공유 상태가 없고 프로세스별
`mktemp` + EXIT trap뿐이다(codex L146-147 / gemini L92-93). 판정: 각자 독립 실행되며, 다만 쿼터 감지가
없으므로 16개가 소진된 하위 CLI를 **각자 끝까지 두드린다** — 백오프·차단 장치가 없다.

**atask 경유(× 16): 경합 결함 4건.** 상태 파일 `~/.claude/arachne-quota-state`(L34-35, 형식
`cli\tepoch`)에 대해 저장소 전체에 잠금(flock/lockfile)이 **0건**이다.

1. **Lost update.** `SetCooldown()`(L170-182)은 read(L178 `grep -v`)→modify→write(L181 `mv`)인데
   무잠금이라, 프로세스 A(claude 소진)·B(codex 소진)가 동시에 실행되면 나중 `mv`만 남아 **한쪽 CLI의
   쿨다운 등록이 소실**된다 — 소진된 CLI가 계속 후보로 남는다.
2. **비원자 교체 가능성.** L176 `mktemp`는 `TMPDIR`(기본 `/tmp`)에 생성되고 대상은 `$HOME/.claude`다.
   두 경로가 다른 파일시스템이면 `mv`가 rename(2)이 아닌 copy+unlink로 폴백해 **부분 기록 파일**이
   노출되는 창이 생긴다. 동시 reader(`CooldownUntil` L148, 훅 `atask-quota-warn.sh:27-40`)가 잘린
   값을 읽을 수 있다. 원자 교체 의도라면 `mktemp -p "${STATE_DIR}"`이어야 한다.
3. **check→act TOCTOU.** `InCooldown` 검사(L289)와 `SetCooldown` 등록(L343) 사이에 실제 CLI 호출
   (L305/311/314)이 끼어 있어, 동시 기동한 N개 atask가 모두 "가용"으로 보고 같은 CLI를 호출한다 —
   16개 동시라면 **최악 16회 쿼터 이중 소모** 후에야 쿨다운이 기록된다. 사후 기록 구조라 원천 방지
   불가.
4. **비수치 값 무방어.** L148 `cut -f2` 결과가 부분 기록으로 오염되면 L149 `${until:-0}`은 빈 값만
   막는다. L162 `[ "$(date +%s)" -lt "${until}" ]`가 정수 비교 오류를 내면 `InCooldown`이 실패(=가용
   판정)로 귀결돼 소진 CLI를 재호출한다.

훅 정합성: `atask-quota-warn.sh:14`의 상태 파일 경로·형식은 atask와 일치한다. 단 훅의 후보 순서
`claude→codex→gemini`(L48-56)는 `OrderForRole impl`(arachne-task.sh:102)의 손 복제이고, 훅은 설치
여부(`command -v`)를 검사하지 않아 솔로 모드에서 "첫 가용 후보" 안내가 실제 폴백과 어긋난다.

부가: `-w`(write 모드)는 codex 단계에만 전달되므로(L308-309) codex가 쿨다운/미설치로 스킵되면 쓰기
의도가 조용히 소실된 채 claude/gemini로 폴백한다. 동시성 테스트는 저장소에 없다(`tests/atask.bats`는
단일 프로세스 시나리오만).

## 결함 분류

dynamic workflows(병렬 서브에이전트·다중 worktree·동시 atask 확대) 도입과 무관하게 지금 고쳐야 할
것과, 도입 시에만 문제가 되는 것을 나눈다.

### [현행 결함] — 도입 여부와 무관하게 지금 버그

| ID | 내용 | 판정 근거 (한 줄) |
| --- | --- | --- |
| B-01 | 쿼터 오판: bare `429`(무경계)·`overloaded`·`usage limit` + stdout 스캔 (`arachne-task.sh:24,191-197`) | 단일 atask 실행에서 정상 응답 본문·무관 숫자만으로 재현되는 오판 |
| B-02 | `NON_QUOTA_PATTERN`의 `compil` 등 부분문자열 과잉 차단으로 진짜 소진을 일반 에러로 오판→폴백 중단 (L28,193-194) | 단일 실행에서 캡처에 컴파일 로그가 섞이면 즉시 발현 |
| B-03 | 닫힌 이슈 workflow-06(done)의 수정 방향 1·3·4·6 미반영 — 이슈 상태와 코드 불일치 | 이슈 관리 정합성 결함으로 병렬성과 무관 |
| B-04 | git-bus 로컬 HEAD 폴백: 업스트림 미설정 브랜치에서 자기 커밋을 "업스트림 새 커밋"으로 공지 (`git-bus-check.sh:42-47,75`) | 단일 세션·단일 폴더에서 `push -u` 전 커밋만으로 재현 |
| B-05 | git-bus rebase/force-push 시 무공지 기준점 점프 — 실려 온 새 커밋 통째 미탐 (L75-79) | 단일 세션에서 upstream 리라이트만으로 재현 |
| B-06 | `atask -w`의 쓰기 의도가 codex 스킵 시 조용히 소실 (`arachne-task.sh:308-309`) | 단일 실행에서 codex 쿨다운/미설치면 발현 |
| B-07 | `atask-quota-warn.sh` 훅: impl 순서 하드코딩 중복(L48-56) + 설치 여부 미검사 → 솔로 모드 안내와 실제 폴백 불일치 | 단일 세션 솔로 모드에서 발현, 병렬성 무관 |
| B-08 | 래퍼(codex/gemini-task)에 쿼터 백오프가 전혀 없어 직접 호출 시 소진 CLI를 무제한 재타격 | 단일 사용자라도 래퍼 직접 호출 경로에는 감지가 0건 |
| B-09 | 체크아웃 브랜치 = 전역 하네스: `install.sh:93-101,422-424`가 `rules/`·`agents/`·`hooks/` 등을 `~/.claude/` 아래로 심볼릭 링크해(실측: `~/.claude/rules → /home/Arachne/Arachne/rules`), 레포의 브랜치 전환·실험적 수정이 커밋·재설치 없이 모든 세션의 전역 하네스에 즉시 반영됨 — 하네스를 개발하면서 동시에 사용하는 구조에서 격리 수단이 없음 | 단일 세션 개발 중에도 발현하며 git 브랜치가 격리 수단이 되지 못함 — 병렬성과 무관 |
| B-10 | 하네스가 자기 컨텍스트 조립 과정(어떤 rules·agent 정의가 실제로 주입되는지)을 관측할 수단을 제공하지 않음. 세션 전사(jsonl)는 대화 메시지만 영속화하고 시스템 컨텍스트를 남기지 않으며(실험 B: 신선 프로브 3종 0건·레코드 type 분포에 시스템 컨텍스트 타입 부재), 서브에이전트 태스크 전사도 user/assistant 2레코드뿐(P 마커 0건), `--debug`/`ANTHROPIC_LOG=debug` 로그도 페이로드를 `[Object ...]`로 접어 출력 — Q1이 "미해결 — 관측 수단 부재"로 끝난 직접 원인 | 관측 수단 부재는 단일 세션에서도 성립하는 현행 공백 — 규율이 적용되는지 스스로 검증할 수 없음 |
| B-11 | `session-end.sh`가 전역 Stop 훅으로 등록되어(`settings.template.json:77-87`) CWD와 무관하게 발화하며, 일 단위 단일 파일 `~/.claude/sessions/auto-YYYY-MM-DD.md`를 무조건 덮어씀. 헤드리스 세션·다른 프로젝트 세션이 하루 중 마지막에 종료되면 그날의 스냅샷이 그 세션 내용으로 대체되고 이전 내용은 복구 불가. 이번 프로브 실행에서 실측: 927B(19:33, 브랜치 `audit` 정보) → 426B(20:19, "브랜치: N/A / (git 없음)") | 세션을 2개만 띄워도(프로젝트 무관) 발현하는 현행 데이터 유실 — dynamic workflows 도입 여부와 무관 |

### [도입 제약] — dynamic workflows 도입 시에만 문제

| ID | 내용 | 판정 근거 (한 줄) |
| --- | --- | --- |
| C-01 | `SetCooldown` lost update — 무잠금 read-modify-write (`arachne-task.sh:170-182`, repo 전체 flock 0건) | 둘 이상의 atask가 동시에 서로 다른 CLI 소진을 기록할 때만 발현 |
| C-02 | cross-fs `mv` 비원자 교체로 동시 reader가 부분 기록을 읽음 (L176,181) | 쓰기와 동시에 읽는 프로세스가 있어야 발현 |
| C-03 | `InCooldown`↔`SetCooldown` TOCTOU로 동시 N 프로세스가 같은 소진 CLI를 N회 호출 (L289↔L343) | 동시 기동이 전제 — 단일 프로세스에서는 검사·기록 순서가 항상 정합 |
| C-04 | `InCooldown` 비수치 값 무방어 (L148-149,162) | 오염 원인이 C-02의 동시 부분 기록이므로 병렬 환경에서만 현실화 |
| C-05 | git-bus worktree별 상태 분리로 동료 세션 커밋을 "외부 커밋"으로 재공지 (`git-bus-check.sh:13,53` + `git.md:84-85`가 자기 worktree만 갱신) | worktree 2개 이상 병렬일 때만 존재하는 시나리오 |
| C-06 | 동일 폴더 2세션의 기준점 파일 공유 경합 — 한 세션 공지 후 갱신하면 다른 세션 미탐 (L66↔L110 무잠금) | 병렬 세션이 규약을 어기고 폴더를 공유할 때만 발현 |
| C-07 | 서브에이전트의 rules 로드(Q1)·훅 발화(Q2)가 미검증 — 병렬 서브에이전트에 규율(코딩 스타일·doc-drift 알림)이 적용된다는 보장 없음 | 단일 메인 세션에서는 네이티브 로더·훅이 확인된 경로로 동작하고, 공백은 서브에이전트 대량 활용 시에만 노출 |
| C-08 | 커맨드 조정 로직(승인 게이트·중단 가드)이 전부 프롬프트 텍스트 — `allowed-tools` 등 구조적 강제 0건 | 사람이 지켜보는 단일 세션에서는 관찰 가능하나 무감독 병렬 실행에서는 게이트 우회를 막을 장치가 없음 |
| C-09 | `isolation:"worktree"` 자동 격리 주장(`git-workflow.md:62`, `ARCHITECTURE.md:414`)이 저장소 내 검증 없음. 이 세션 도구 스키마로 확인되는 것은 **일반 서브에이전트(Agent/Task) 도구에 해당 옵션이 존재한다**는 사실까지다 — dynamic workflow 런타임이 같은 실행 경로·같은 격리 보장을 쓴다는 근거는 없으므로 워크플로 맥락에서의 격리 가용성은 [추정]이다. 하네스가 격리를 *강제*하는 설정도 없음 | 격리 미적용 서브에이전트의 동시 파일 수정은 병렬 실행에서만 문제 |
| C-10 | 래퍼 감지 부재(B-08)의 증폭: 동시 16 프로세스가 각자 소진 CLI를 재타격 — 프로세스 간 차단·공유 백오프 없음 | 단일 호출에서는 낭비 1회지만 병렬에서는 낭비가 프로세스 수에 비례 |

## 공통 원인

1. **제품 동작에 대한 무검증 단정.** "네이티브 자동 로드"·"isolation 자동 격리" 등 Claude Code 제품
   동작이 저장소 문서에 사실로 서술되지만, 이를 확인하는 테스트·실험 절차가 저장소에 없다 (Q1·Q2·C-07·C-09).
2. **상태 파일 설계가 단일 세션·단일 프로세스 가정.** CWD 의존 경로 해석(git-bus·session-end·ua-stale)과
   무잠금 read-modify-write(atask)가 worktree 병렬 전략(`git-workflow.md`가 스스로 권장)과 상충한다
   (C-01~C-06).
3. **동시성 테스트 0건.** `tests/`의 bats는 전부 단일 프로세스 시나리오다 — 경합·부분 기록·TOCTOU를
   재현하는 테스트가 없어 위 결함들이 회귀 감지망 밖에 있다.
4. **문서-코드 드리프트.** 닫힌 이슈 미반영(B-03), 쿼터 키워드 표 불일치, 훅의 후보 순서 손 복제(B-07)
   — SSOT 원칙(AGENTS.md)이 파생물 동기화 장치 없이 운영된다.
5. **규율 집행의 프롬프트 의존.** 게이트·역할 제한·도구 제약이 구조적 설정(allowed-tools, 훅 차단)이
   아니라 텍스트 지시로만 존재한다 (C-08).

## 권장 처리 순서

심각도(쿼터 낭비·커밋 유실 위험)와 의존성(도입 전 선행 필요) 기준:

1. **B-01·B-02·B-03 — 쿼터 감지 정비** (workflow-06 재오픈): `429` 단어 경계, bare `overloaded`·
   `usage limit` 제거, stderr 우선 스캔, NON_QUOTA 부분문자열 정리. 현행 오판이 즉시 토큰 낭비로
   이어지는 최상위 항목.
2. **B-04·B-05 — git-bus 폴백·rebase 처리**: `@{u}` 부재 시 공지 억제(또는 "로컬 전용" 표시),
   `LAST_SEEN` 도달 불가 시 무공지 점프 대신 리라이트 경고 출력.
3. **B-06·B-07 — 폴백 의미 보존·훅 정합**: `-w` 소실 시 경고 또는 중단, 훅 후보 순서·설치 검사 공유
   소스화.
4. **C-07·C-09 — Q1/Q2 검증 실험 실행** (dynamic workflows 도입 전 선행 필수): 실험 B(--debug 프롬프트
   관찰) → 필요 시 실험 A(nonce 카나리아). 결과가 "미로드"면 agents/* 본문에 핵심 규칙 명시 주입 또는
   에이전트 프롬프트 생성 단계 추가를 결정.
5. **C-01~C-04 — 상태 파일 동시성**: `flock` 도입 + `mktemp -p "${STATE_DIR}"` + `until` 숫자 검증.
   셋 다 소규모 패치로 같은 커밋에서 처리 가능.
6. **C-05·C-06 — git-bus worktree 전략 결정**: 공용 기준점(`git rev-parse --git-common-dir` 하위) 채택
   여부 설계 판단 — 세션별 공지 의미가 바뀌므로 [PLAN] 승인 사항.
7. **동시성 bats 테스트 추가**: SetCooldown 병렬 10회 기록 보존, 부분 기록 내성, 기준점 경합 재현 —
   1·5·6의 회귀망.
8. **C-08 — 커맨드 구조적 강제 검토**: 최소한 `/git`·`/worktree`의 파괴적 경로에 `allowed-tools` 또는
   PreToolUse 차단 훅 도입 검토 (dynamic workflows 규모 확대 시점에).
