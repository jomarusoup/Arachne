# Arachne 하네스 최신성 감사 — 2026-09-13

> 범위: Claude Code · Codex CLI · Gemini CLI 최신 스펙 대비 Arachne(HEAD `5b9d9ac`) 구조 감사.
> 모든 벤더 사실관계는 2026-09-13 웹 조사로 확인했고 항목마다 출처 URL을 남겼다.
> **이 보고서는 제안만 담는다 — 코드 변경 없음. 적용은 항목별 사용자 승인 후 진행.**
>
> ⚠ 감사 의뢰 프롬프트의 전제 2건이 현재 저장소와 다르다:
> ① "Gemini→Codex→Claude 3-레인 위임 구조" — **ADR-0004(2026-08-29)로 런타임 제거·`archive/multi-cli/` 보존** 상태다.
> ② "CLAUDE.md가 `@rules/common/...` 방식으로 import" — **@import는 0건**, `rules/`는 `~/.claude/rules/` 심볼릭으로 네이티브 자동 로드된다(커밋 `c123a7e`에서 import 19개 제거). 감사는 실제 상태 기준으로 수행했다.

---

## 1. 요약

Arachne의 뼈대 — `rules/` 네이티브 로딩(paths 지연 로드 포함), AGENTS.md SSOT + CLI별 어댑터, command 타입 훅 5종, 서브에이전트 8종 — 는 2026-09 현재 공식 스펙과 정확히 부합하며, "Claude Code는 AGENTS.md를 직접 읽지 않는다"는 설계 전제도 공식 문서로 재확인됐다. 가장 큰 격차는 단 하나다: **`skills/` 47개가 벤더 공통 표준(SKILL.md 디렉터리 포맷, 4대 CLI 전부 채택)이 아닌 자체 단일 `.md` 포맷이라, 현행 Claude Code의 네이티브 스킬 로더에 등록되지 않고 있다** — 이번 세션에서 `commands/` 19개는 전부 스킬로 등록된 반면 `skills/` 47개는 0개 등록임을 실측으로 확인했다. Q1(서브에이전트 규칙 주입)은 실검증 결과 **"주입된다(조건부)"** — CLAUDE.md와 paths 없는 `rules/common/` 9종은 서브에이전트에 전문 주입되지만, paths 규칙 48종은 프리로드되지 않고 Explore/Plan 계열은 공식적으로 CLAUDE.md 자체를 건너뛴다. 그 외에는 대규모 재설계 없이 잔재 청소·문서 최신화 수준의 정비만 필요하며, Dynamic Workflows 미도입(ADR-0003)과 3-레인 제거(ADR-0004) 결정은 이번 조사 결과로도 여전히 타당하다.

---

## 2. 모델별 대응 현황표

### 2-1. Claude Code

| 축 | 지금 활용 중 | 최신 가능 기능 | 미활용이 정당한가 |
|---|---|---|---|
| 훅 이벤트 | 5종 (UserPromptSubmit·PostToolUse·SessionStart·PreCompact·Stop), 전부 `type: "command"` | 이벤트 확장: SessionEnd·StopFailure·PostToolUseFailure·PreModelSwitch/PostModelSwitch·ConfigChange·FileChanged. 핸들러 5타입: command / **http** / **mcp_tool** / **prompt** / **agent** | **정당** — 현 훅은 전부 결정론·무토큰 bash이고 목적(알림·스냅샷)에 충분. prompt/agent 핸들러는 호출마다 토큰을 쓰므로 현 용도엔 역행. 신규 이벤트도 지금 요구사항에 대응할 게 없음 |
| 서브에이전트 | 8종, frontmatter는 name·description·tools·model 4필드 | 신규 필드: `permissionMode`·`skills`(프리로드)·`memory`·`isolation: worktree`·`maxTurns`·`disallowedTools`·`mcpServers` | **대체로 정당** — 단, 4개 에이전트(code-reviewer·tdd·debugger·planner)의 "프롬프트 방어 기준선"이 제목만 있고 4항 목록이 빠진 비대칭은 수리 대상(제안 3). `skills` 프리로드는 제안 1 이후 재평가 |
| 스킬 | `skills/*.md` 단일 파일 47개 + 자체 `triggers` frontmatter | 공식 포맷: `~/.claude/skills/<name>/SKILL.md` 디렉터리. 공식 frontmatter: name·description·disable-model-invocation·user-invocable·allowed-tools·context·agent·arguments (`triggers`는 공식 필드 아님) | **정당하지 않음** — 실측: 이번 세션 스킬 레지스트리에 commands 19개는 등록, skills 47개는 **0개 등록**. 47개 스킬은 네이티브 스킬이 아니라 Claude가 수동 Read하는 참고 문서로만 기능 중 (갭 G-1) |
| rules | `~/.claude/rules/` 심볼릭 네이티브 로드, paths frontmatter 지연 로드, @import 0건 | 동일 — 현행 공식 스펙 그대로 | **최신과 일치** (격차 없음) |
| Dynamic Workflows | 미도입 (ADR-0003 Proposed, 채택안 A=도입 안 함) | Workflow 도구: JS 스크립트 기반 대규모 병렬 오케스트레이션, 유료 플랜 | **정당** (§6 보류 참조) |
| AGENTS.md | import 안 함 (rules가 풀 디테일) | Claude Code는 AGENTS.md 직접 미독 — 공식: "Claude Code reads CLAUDE.md, not AGENTS.md" | **최신과 일치** — 현 설계 전제가 공식 확인됨 |

출처: https://code.claude.com/docs/en/hooks.md · https://code.claude.com/docs/en/sub-agents.md · https://code.claude.com/docs/en/skills.md · https://code.claude.com/docs/en/workflows.md · https://code.claude.com/docs/en/memory.md

### 2-2. Codex CLI (현재 미사용 — 어댑터만 유지)

| 축 | 지금 활용 중 | 최신 가능 기능 | 미활용이 정당한가 |
|---|---|---|---|
| 규약 파일 | `AGENTS.md` → `~/.codex/AGENTS.md` 마커 병합 (`arachne -i --target codex`) | 전역 `~/.codex/AGENTS.md` 인정 + git루트→cwd 병합, `project_doc_max_bytes` 기본 32KiB | **최신과 일치** — 어댑터 경로·방식 유효 |
| 스킬 | 없음 | SKILL.md 오픈 표준 채택. 탐색: `$CWD/.agents/skills` → `~/.agents/skills` → `/etc/codex/skills` | 미사용 CLI라 당장 무해. 단 제안 1을 표준 포맷으로 하면 `~/.agents/skills` 경유 공유 가능(재도입 발판) |
| 서브에이전트 | 없음 | TOML 정의 (`~/.codex/agents/`, `.codex/agents/`), 빌트인 default/worker/explorer | **정당** — 미사용 |
| headless | (archive) `codex exec --skip-git-repo-check -s read-only` + 정규식 출력 필터 | `codex exec --json`(JSONL 이벤트 스트림)·`--output-schema`·`--output-last-message`. **`codex mcp-server`는 제거됨** | 재도입 시 래퍼를 `--json` 기반으로 재작성 필요 (제안 5에 기록) |

출처: https://developers.openai.com/codex/skills · https://developers.openai.com/codex/subagents · https://developers.openai.com/codex/guides/agents-md · https://developers.openai.com/codex/non-interactive-mode · https://developers.openai.com/codex/mcp

### 2-3. Gemini CLI (현재 미사용 — 어댑터만 유지)

| 축 | 지금 활용 중 | 최신 가능 기능 | 미활용이 정당한가 |
|---|---|---|---|
| 규약 파일 | `AGENTS.md` → `~/.gemini/GEMINI.md` 심볼릭 | `settings.json`의 `context.fileName: ["AGENTS.md","GEMINI.md"]`로 심볼릭 없이 AGENTS.md 직독 가능 | 심볼릭도 유효(즉시 반영 장점 유지). 대안 존재만 문서화(제안 5) |
| 스킬 | 없음 | SKILL.md 표준 채택 (`~/.gemini/skills/` + **`~/.agents/skills/` 별칭**, `.agents/skills/`가 우선) | Codex와 동일 — 제안 1이 공유 발판 |
| 서브에이전트 | 없음 | `.gemini/agents/*.md` (Claude와 유사한 md+frontmatter), A2A 원격 에이전트 | **정당** — 미사용 |
| headless | (archive) `gemini --skip-trust -p` + stderr 노이즈 정규식 필터 | `--output-format json` / stream-JSON(NDJSON), 종료코드 0/1/42/53 | 재도입 시 `--output-format json` 기반 재작성 필요 (제안 5) |
| **지속성 리스크** | — | **2026-05-19 발표: 무료·소비자 티어 Gemini CLI는 2026-06-18부로 Antigravity CLI로 대체** (유료 API 키·엔터프라이즈는 유지, OSS 릴리스는 v0.59.0/2026-09까지 지속) | 재도입 계산이 바뀜 — 인증 방식에 따라 Antigravity CLI 대응 재검토 필요 (제안 5) |

출처: https://geminicli.com/docs/core/subagents/ · https://geminicli.com/docs/cli/skills/ · https://geminicli.com/docs/cli/gemini-md/ · https://geminicli.com/docs/cli/headless/ · https://developers.googleblog.com/an-important-update-transitioning-gemini-cli-to-antigravity-cli/

### 2-4. 상호운용 표준 현황 (공통)

- **AGENTS.md**: Linux Foundation 산하 Agentic AI Foundation(AAIF) 스튜어드십. Codex·Gemini CLI·Copilot 등 24개+ 도구 채택. Claude Code는 미채택(공식 우회: import/심볼릭). Arachne의 SSOT 선택은 표준 정합. — https://agents.md/ · https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation
- **Agent Skills(SKILL.md)**: Anthropic 원저 오픈 표준. 공식 쇼케이스에서 Claude Code·Codex·Gemini CLI·Copilot **4대 CLI 전부 채택 확인**. — https://agentskills.io/home
- **MCP**: 2025-12 AAIF 이관. 4대 CLI 모두 클라이언트 지원. Codex의 MCP **서버** 모드는 제거됨. — https://blog.modelcontextprotocol.io/posts/2025-12-09-mcp-joins-agentic-ai-foundation/
- **크로스-하네스 호출 방식 사례**: vibe-kanban(headless spawn + stream-json 파이프, `crates/executors/`) · claude-squad(tmux + git worktree 인터랙티브 spawn) · zen-mcp-server(MCP tool-use 프론트 + 내부 CLI spawn 하이브리드) · spec-kit(파일 기반 핸드오프 + 각 CLI 네이티브 디렉터리에 래퍼 생성). 공통 격리 수단은 git worktree — Arachne `/worktree` 규약과 동일 계열. — https://github.com/BloopAI/vibe-kanban · https://github.com/smtg-ai/claude-squad · https://github.com/BeehiveInnovations/zen-mcp-server · https://github.com/github/spec-kit

---

## 3. 갭 목록 (우선순위 순)

각 항목: **현재 상태 → 최신 표준 → 격차 → 실제로 문제인가**

### G-1. 스킬 포맷 — 문제임 (우선순위 1)
- 현재: `skills/<name>.md` 단일 파일 47개, 자체 `triggers.paths/keywords` frontmatter. `tests/skill_meta.bats`가 이 자체 계약을 강제.
- 최신 표준: `<dir>/skills/<name>/SKILL.md` 디렉터리 포맷(Agent Skills 오픈 표준). Claude Code 공식 문서도 디렉터리 포맷만 기술하며 `triggers`는 공식 필드가 아님. Codex(`~/.agents/skills`)·Gemini(`~/.agents/skills` 별칭)·Copilot도 같은 포맷을 읽음.
- 격차: 포맷 자체가 표준 밖.
- 문제인가: **그렇다 — 이미 실기능 손실이 있다.** 이번 세션 실측에서 `commands/` 19개는 전부 네이티브 스킬로 등록된 반면 `skills/` 47개는 0개 등록. 즉 47개 스킬은 자동 발견·자동 호출 대상이 아니고, CLAUDE.md의 "triggers가 스킬 선택의 결정론 힌트"라는 전제도 하네스 차원에서는 동작하지 않는다(Claude가 규칙을 기억해 수동 Read할 때만 기능). 부수적으로, 표준 포맷이 아니면 타 CLI 재도입 시 스킬 공유도 불가.
- 근거: https://code.claude.com/docs/en/skills.md · https://agentskills.io/home · https://developers.openai.com/codex/skills · https://geminicli.com/docs/cli/skills/ · 이번 세션 스킬 레지스트리 실측

### G-2. 서브에이전트 규칙 도달 범위 — 부분 문제 (우선순위 2)
- 현재: 서브에이전트 위임 시 규칙 전달을 별도 처리하지 않음 (자동 상속 가정).
- 최신 표준: 표준 서브에이전트는 CLAUDE.md 계층을 자동 로드하지만, **Explore·Plan 계열은 CLAUDE.md를 건너뛴다** — 공식 문서: "Since Explore and Plan skip CLAUDE.md, restate critical rules in your delegation prompt".
- 격차: Explore/Plan 위임 시 sgrep-우선·파일 전체 읽기 금지 등 핵심 규칙이 미도달. paths 규칙 48종은 어느 서브에이전트에도 프리로드되지 않음(§4).
- 문제인가: **부분적으로.** 커스텀 에이전트 8종은 안전(실측 확인). Explore/Plan 위임 경로만 규칙 사각지대 — 위임 프롬프트 규약 한 줄로 해소 가능(제안 2).
- 근거: https://code.claude.com/docs/en/sub-agents.md + §4 실검증

### G-3. 에이전트 프롬프트 방어 기준선 비대칭 — 경미한 문제 (우선순위 3)
- 현재: `python/fastapi/react/database-reviewer` 4종은 방어 기준선 4항(역할 불변·비밀 미노출·외부 데이터 불신·동형문자/긴급성 의심)을 보유. `code-reviewer`·`tdd`·`debugger`·`planner`는 **섹션 제목만 있고 4항 목록이 없음**.
- 최신 표준: (벤더 표준 아님 — Arachne 자체 규약의 내부 일관성 문제)
- 문제인가: **그렇다, 경미하게.** code-reviewer·debugger는 외부 유래 텍스트(diff·로그)를 가장 많이 다루는 에이전트인데 방어 기준선이 오히려 빠져 있다. `rules/common/workflow.md`의 간접 인젝션 방어 원칙과도 어긋남.

### G-4. 인터롭 레이어(레인 간 호출 방식) — 현재는 문제 아님, 기록만 필요 (우선순위 4)
- 현재: 런타임 호출 없음(솔로). `archive/multi-cli/` 래퍼는 plain-text 출력 + 정규식 필터/에러판별 기반.
- 최신 표준: headless 구조화 출력이 벤더 공식 — `codex exec --json`(JSONL), `gemini --output-format json`(+종료코드 계약 0/1/42/53). 업계 사례(vibe-kanban)도 stream-json 파이프가 지배적. Codex MCP 서버 모드는 제거돼 MCP 경유 Codex 호출 선택지는 소멸.
- 문제인가: **지금은 아니다** — 호출 자체가 없으므로. 단 archive의 재도입 절차가 이 사실을 모르면 낡은 인터페이스로 복원하게 되므로, 재도입 전제 문서에만 반영(제안 5). Gemini 소비자 티어 중단(Antigravity 전환)도 같은 문서에 기록.
- 근거: §2-2·§2-3 출처

### G-5. 잔재·드리프트 — 경미 (우선순위 5)
- `.claude/settings.local.json`에 ADR-0004로 사라진 테스트·래퍼를 가리키는 죽은 permission 5건 (`bats tests/atask.bats ...`, `command -v gemini codex claude`, `echo "gtask rc=$?"` 등).
- `skills/README.md` "## Java 백엔드" 섹션이 표 헤더만 남고 0행 (아카이브 후 정리 누락).
- `.stignore.bak-20260719` untracked 잔재.
- ADR 번호 `0002` 중복 (`0002-systems-profiles` / `0002-external-analysis-plugins`).
- 문제인가: 실동작 영향 없음. 죽은 permission은 권한 표면을 불필요하게 넓히므로 정리 가치 있음(제안 4).

### G-6. 훅 — 격차 있으나 문제 아님
- 현재: command 타입 5이벤트, jq 비의존, 스로틀·간접 인젝션 방어까지 갖춘 성숙한 구성.
- 최신 표준: 이벤트 6종+ 추가, 핸들러 5타입.
- 문제인가: **아니다.** 현 훅의 목적(알림·스냅샷·기준점 관리)에 command 타입이 최적 — 결정론적이고 토큰 비용 0. prompt/agent 핸들러로 옮기면 매 발화마다 토큰을 태운다. `doc-drift-check`를 `FileChanged`로 옮기는 것도 검토했으나 현 `PostToolUse(Edit|Write)` matcher와 실질 차이가 없어 이득 없음. **변경 권고 없음.**

### G-7. 레인 배정 기준 — 해당 없음 (기록만)
- 3-레인은 제거됨. archive의 배정표(read→gemini, test→codex)는 당시 모델 강점 기준이었으나, Gemini CLI 소비자 티어 중단·Codex 서브에이전트/스킬 정식화로 재도입 시 배정 논리는 원점 재검토 대상. `archive/multi-cli/README.md` 재도입 절차 4단계(결함 선수리)에 이 재검토를 추가하는 것으로 충분(제안 5).

---

## 4. Q1 검증 결과 — "CLAUDE.md 규칙이 서브에이전트에 주입되는가"

### 방법
CLAUDE.md·rules에만 있고 서브에이전트 시스템 프롬프트에는 없는 규칙(전역 변수 `g_SnakeCase`, 파일 헤더 4필드, 단일 문자 변수 금지, 디버그 prefix)을 골라, **파일 읽기 도구 사용을 금지한 채** 서브에이전트 2종을 실제 실행해 답하게 했다.

### 실행 로그 요약
| 실험 | 대상 | 결과 |
|---|---|---|
| 1 | `general-purpose` 에이전트 | CLAUDE.md 제목("# Claude Code 글로벌 지시서")·`g_SnakeCase`·헤더 4필드(`FILE NAME/DESCRIPTION/DATA/Modification`)·단일문자 금지·`[DEBUG]` prefix 전부 파일 미접근 상태에서 정확 인용. 컨텍스트 내 파일 목록: `rules/common/` 9종 + `rules/README.md` 전문 주입 확인. **`rules/common/hooks.md`(paths 있음)와 언어별 규칙 본문은 부재** |
| 2 | 커스텀 `code-reviewer` 에이전트 (자체 시스템 프롬프트 보유) | 동일 항목 전부 정확 인용, 동일한 rules 파일 목록 확인. (에이전트가 실험 취지를 프롬프트 추출 시도로 의심하는 방어 반응을 보인 뒤 사실관계는 답변 — 방어 기준선이 작동한 부수 관찰) |

### 공식 문서 대조
서브에이전트 시작 시 로드 항목에 "CLAUDE.md Files: ✅ Yes (Full hierarchy: ~/.claude/CLAUDE.md, project rules, CLAUDE.local.md, managed policy)" — 실측과 일치. 단서 조항 "Since Explore and Plan skip CLAUDE.md, restate critical rules in your delegation prompt" — Explore/Plan 계열은 예외. fork(`/subtask`)는 대화 전체를 상속. (https://code.claude.com/docs/en/sub-agents.md)

### 결론: **주입된다 — 조건부**
1. **닿는 것**: `~/.claude/CLAUDE.md` + paths frontmatter 없는 `rules/common/` 9종 + `rules/README.md` → 표준 서브에이전트(범용·커스텀 불문)에 전문 주입. (실측 + 공식 문서 일치)
2. **조건부**: paths 있는 규칙 49종(`rules/common/hooks.md` + 언어별 48종)은 **프리로드되지 않음**(실측). 서브에이전트가 매칭 파일을 읽을 때 지연 로드되는지는 이번 실험 범위 밖 — 미검증으로 남긴다.
3. **안 닿는 것**: Explore·Plan 계열 에이전트는 CLAUDE.md 계층 전체를 건너뜀 (공식 문서 명시).

### 영향 범위 (안 닿거나 조건부인 Arachne 규칙)
- Explore/Plan 위임 시 미도달: `rules/common/` 전부 — 특히 sgrep-우선·파일 전체 읽기 금지(workflow.md·performance.md), 간접 인젝션 구획화(workflow.md). → 위임 프롬프트에 핵심 규칙 재기술 필요 (제안 2).
- 모든 서브에이전트에서 프리로드 안 됨: 언어별 코딩 스타일·보안·테스팅 48종 + hooks.md. 리뷰어 에이전트들은 자체 시스템 프롬프트에 언어별 체크리스트를 내장하고 있어 실질 공백은 작으나, tdd·debugger가 언어 규칙 없이 코드를 쓰는 경로는 이론상 존재.

---

## 5. 개선 제안 (승인 대기 — 우선순위 순)

### 제안 1. `skills/`를 표준 SKILL.md 디렉터리 포맷으로 이관 [G-1]
**왜 지금**: 47개 스킬이 현행 Claude Code에서 네이티브 등록 0건임이 실측됐다 — 이관 즉시 자동 발견·`/skill-name` 호출이 살아나고, 4대 CLI 공통 표준이라 재도입 발판도 된다.

- 이동: `skills/<name>.md` → `skills/<name>/SKILL.md` (47건, `git mv`)
- frontmatter: `name`·`description`은 표준 그대로. `triggers.paths/keywords`는 표준 필드가 아니므로 description 말미에 접어 넣어 자동 발견 매칭에 기여시키고, 원 블록은 제거(또는 1단계에선 잔류시키고 무해성 확인 후 제거 — 승인 시 선택).

```yaml
# skills/cpp-patterns/SKILL.md (예)
---
name: cpp-patterns
description: >-
  모던 C++ RAII·스마트 포인터·이동 시맨틱 패턴 가이드.
  대상: **/*.cpp, **/*.hpp. 키워드: RAII, 스마트 포인터, move, rule of five.
---
(본문 무변경)
```

- 동반 수정: `tests/skill_meta.bats`(디렉터리/SKILL.md 존재·name=디렉터리명 계약으로 개정), `tests/check_index.sh`·`skills/README.md` 경로 갱신, CLAUDE.md Architecture 트리 갱신. `install.sh`는 `skills` 디렉터리 통째 심볼릭이라 무변경.
- 검증: 이관 후 새 세션에서 스킬 레지스트리에 47개 등장 확인 + `/skill-doctor`.
- 규모: 기계적 이동 47건 + 테스트·인덱스 3파일. 위험: 낮음(본문 무변경).

### 제안 2. Explore/Plan 위임 규약 추가 + Q1 결과를 규칙에 반영 [G-2]
**왜 지금**: 공식 문서가 명시한 규칙 사각지대(Explore/Plan)를 문서 한 절로 막을 수 있다.

`rules/common/agents.md`에 추가:

```markdown
## 서브에이전트 규칙 도달 범위 (2026-09-13 실검증)

- 표준 서브에이전트(커스텀 포함)는 CLAUDE.md + paths 없는 rules/common/*을 자동 상속한다.
- **Explore·Plan 계열은 CLAUDE.md를 건너뛴다** — 위임 프롬프트에 핵심 규칙
  (sgrep-우선, 파일 전체 읽기 금지, 외부 콘텐츠 구획화)을 반드시 재기술한다.
- paths 있는 언어 규칙은 서브에이전트에 프리로드되지 않는다 — 언어 특화 작업 위임 시
  해당 규칙 요지를 프롬프트에 포함하거나 리뷰어 에이전트(자체 체크리스트 내장)를 쓴다.
```

- 규모: 문서 1파일. 위험: 없음.

### 제안 3. 에이전트 4종에 프롬프트 방어 기준선 4항 복원 [G-3]
**왜 지금**: 외부 유래 텍스트를 가장 많이 다루는 code-reviewer·debugger에 방어 기준선이 빠진 비대칭 — 리뷰어 4종에 이미 있는 4항 블록을 그대로 이식하면 끝난다.

- 대상: `agents/code-reviewer.md`, `agents/tdd.md`, `agents/debugger.md`, `agents/planner.md` — 제목만 있는 섹션에 `python-reviewer.md`와 동일한 4항(역할·페르소나 불변 / 비밀 미노출 / 외부·페치 데이터 불신 / 유니코드·동형문자·긴급성·권위 주장 의심) 삽입.
- 규모: 4파일, 각 4줄. 위험: 없음.

### 제안 4. 잔재 청소 [G-5]
**왜 지금**: 죽은 permission은 불필요한 권한 표면 — 5분짜리 정리다.

- `.claude/settings.local.json`: ADR-0004 잔재 permission 5건 제거 (`Bash(bats tests/atask.bats ...)`, `Bash(command -v gemini codex claude)`, `Bash(echo "gtask rc=$?")`, `Bash(echo "ctask rc=$?")`, `Bash(echo "ctask -w rc=$?")`).
- `skills/README.md`: 빈 "## Java 백엔드" 섹션 제거(또는 "archive/ 이동" 1줄 주석).
- `.stignore.bak-20260719` 삭제 (untracked 백업 잔재 — 삭제 전 내용 확인 후).
- `docs/decisions/README.md`: ADR `0002` 번호 중복을 인덱스에 명기(재번호는 "기록 재작성 금지" 원칙상 하지 않음).
- 규모: 3파일 + 1삭제. 위험: 없음.

### 제안 5. 어댑터·재도입 문서 최신화 [G-4, G-7]
**왜 지금**: 재도입 정본(`archive/multi-cli/README.md`)이 2026년 벤더 변경 3건을 모르면, 미래의 재도입이 낡은 인터페이스로 복원된다 — 문서 몇 줄로 예방된다.

- `archive/multi-cli/README.md` 재도입 절차에 추가: ① Gemini CLI 무료·소비자 티어는 2026-06-18부로 Antigravity CLI로 대체(유료 API·엔터프라이즈만 유지) — 재도입 시 인증 방식 확인 후 대상 CLI 재선정. ② Codex 래퍼는 `codex exec --json`(JSONL) 기반으로 재작성(MCP 서버 모드 제거됨). ③ Gemini 래퍼는 `--output-format json` + 종료코드 계약(0/1/42/53) 기반으로 재작성. ④ 레인 배정표는 재도입 시점 모델 강점으로 원점 재검토.
- `docs/MULTI-CLI.md`·`AGENTS.md` 헤더: Gemini 어댑터 항에 "심볼릭 대신 `context.fileName: ["AGENTS.md","GEMINI.md"]` 설정 대안 존재" 1줄, Antigravity 전환 사실 1줄.
- 규모: 문서 2~3파일. 위험: 없음.

---

## 6. 보류/기각 후보 (검토했으나 하지 않기로 제안)

| 항목 | 판정 | 이유 |
|---|---|---|
| **Dynamic Workflows 도입** | 기각 유지 | ADR-0003(채택안 A)의 논거가 이번 조사로도 유효: 솔로 운용에서 기존 Agent fan-out으로 충족, 서브에이전트 콜드 스타트 실측(25~28k 토큰/기)상 16-에이전트 오케스트레이션은 오버헤드 하한 ≈0.4M 토큰/실행. 정기 대규모 감사가 생기면 그때 ADR-0003 재개정 |
| **훅 핸들러 타입 전환 (prompt/agent/http)** | 기각 | 현 훅은 결정론·무토큰 bash로 목적에 최적. prompt/agent 핸들러는 매 발화 토큰 비용 — 현 용도(알림·스냅샷)에 역행 (G-6) |
| **신규 훅 이벤트 추가 (PostToolUseFailure·FileChanged 등)** | 보류 | 대응할 요구사항이 현재 없음. 필요 신호(예: 반복되는 도구 실패 패턴)가 생기면 그때 |
| **3-레인 런타임 재도입** | 기각 유지 | ADR-0004 논거(실사용 0·결함 집중) 그대로 + Gemini 소비자 티어 중단으로 근거 추가 약화. 어댑터·archive 보존이 올바른 대비 수준 |
| **AGENTS.md를 CLAUDE.md로 심볼릭/import 통합** | 기각 | Claude는 rules/에서 AGENTS.md보다 상세한 풀 디테일을 이미 로드 — import는 중복 재도입. 현 이원 구조(SSOT+풀디테일)가 공식 권장과도 충돌 없음 |
| **서브에이전트 신규 frontmatter 즉시 채택 (`memory`·`skills`·`permissionMode` 등)** | 보류 | 구체 효용 미식별. `skills` 프리로드는 제안 1(스킬 표준화) 완료 후 tdd↔tdd-workflow, code-reviewer↔verification-loop 결합을 재평가하는 게 순서 |
| **Gemini `context.fileName` 방식으로 어댑터 교체** | 보류 | 현 심볼릭이 "수정 즉시 반영" 장점 보유. 미사용 CLI의 어댑터 교체는 ROI 없음 — 대안 존재만 문서화(제안 5) |
| **ADR 0002 번호 재부여** | 기각 | "기록은 재작성하지 않는다" 원칙. 인덱스 명기로 충분(제안 4) |

---

## 7. 적용 기록 (2026-09-13 — 제안 1~5 전체 사용자 승인 후 적용)

### 제안 1 → 커밋 `c73cfa1` (refactor)
- `skills/<이름>.md` 47개 전부 `skills/<이름>/SKILL.md`로 `git mv` (본문 무변경, rename 유사도 73~99%).
- frontmatter: 비표준 `triggers.paths/keywords` 블록 제거, 힌트를 `description` 말미에
  `… 대상 경로 — <globs>. 키워드 — <keywords>.` 형식으로 접음. `latency-critical-systems`의
  `tools:` 추가 필드는 보존.
- 스킬 본문 상대 링크 19건 자동 보정 (`../X` → `../../X`, 형제 스킬 → `../<이름>/SKILL.md`), 수동 처리 0건.
- 살아있는 문서 15개의 평면 경로 참조 갱신: docs/CAPABILITY-MAP·HARNESS-LEARNING-GUIDE·ui-ux/README·
  DESIGN-DOCS·tools/taste-skill, rules/common/performance·workflow, rules/docker/patterns,
  rules/java 2종, rules/rust 5종. **기록물(docs/issue·task·idea)은 원칙대로 미변경.**
- `tests/skill_meta.bats` 재작성: 6개 테스트 — 평면 .md 회귀 차단 / SKILL.md 존재 / frontmatter 존재 /
  name=디렉터리명 / description 비어있지 않음 / triggers 블록 회귀 차단.
- `tests/check_index.sh`: `CheckSkillReferenced`(디렉터리명 기준, archive 제외) 신설,
  `SKILL_COUNT`를 `-mindepth 2 -maxdepth 2 -name SKILL.md`로 변경.
- CLAUDE.md 트리·형식 절, docs/USAGE.md(§0 표·§3 사용법·계약·새 스킬 추가),
  skills/archive/README.md 복원 절차를 표준 포맷 기준으로 갱신.
- **효과 실측**: 이관 직후 같은 세션의 스킬 레지스트리에 스킬들이 네이티브 등록됨(이관 전 0건).

### 제안 2 → 커밋 `e98d229` (docs)
- `rules/common/agents.md`에 "서브에이전트 규칙 도달 범위 (2026-09-13 실검증)" 절 추가:
  표준 서브에이전트 자동 상속 / Explore·Plan은 CLAUDE.md 건너뜀 → 위임 프롬프트에 핵심 규칙
  재기술 의무 / paths 언어 규칙 프리로드 안 됨 / fork는 전체 상속.

### 제안 3 → 커밋 `e6d7302` (fix)
- `agents/code-reviewer.md`·`tdd.md`·`debugger.md`: 제목만 있던 "프롬프트 방어 기준선"에
  리뷰어 4종과 동일한 4항 삽입 (debugger는 외부 데이터 예시를 크래시 로그·코어 덤프로 구체화).
- `agents/planner.md`: 섹션 자체가 없어 신설. 결과: 에이전트 8/8 기준선 보유 확인.

### 제안 4 → 커밋 `623d9aa` (chore)
- `skills/README.md`: 빈 "Java 백엔드" 섹션(표 헤더만) 제거.
- `docs/decisions/README.md`: ADR `0002` 번호 중복을 인덱스에 명기(재번호 없음, 다음 신규는 0005).
- git 외 로컬: `.claude/settings.local.json`의 죽은 permission 5건 삭제
  (`bats tests/atask.bats …`, `command -v gemini codex claude`, `echo "gtask rc=$?"`,
  `echo "ctask rc=$?"`, `echo "ctask -w rc=$?"`), `.stignore.bak-20260719` 삭제
  (현행 `.stignore`로 대체된 구버전 4줄 백업 — 내용 확인 후).

### 제안 5 → 커밋 `ead2b58` (docs)
- `archive/multi-cli/README.md`: "재도입 전 벤더 변경 반영" 절 신설 (Antigravity 전환,
  `codex exec --json`, `gemini --output-format json` + 종료코드 계약, 레인 배정 원점 재검토,
  `~/.agents/skills` 스킬 공유).
- `docs/MULTI-CLI.md`: `context.fileName` 대안, Gemini 지속성 리스크, headless 구조화 출력
  권장, Codex MCP 서버 모드 제거 사실 명기.
- `AGENTS.md`: 벤더 현황 정본 위치 포인터 1줄.

### 검증
- `bats tests/*.bats`(uv 필요한 data_contract 제외) **175/175 통과**, `check_index.sh`·
  `check_convention_sync.sh`·`validate_settings.sh`·`shellcheck -S warning`(수정 스크립트) 통과.
- 각 제안은 독립 커밋으로 분리 — 항목별 되돌리기 가능.

---

*작성: Claude Code 감사 세션, 2026-09-13. 웹 조사·저장소 인벤토리·서브에이전트 실검증은 병렬 에이전트 6기로 수행, 상세 근거 URL은 각 절에 병기.*
