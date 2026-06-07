---
Title: ARCHITECTURE
creation: 2026-06-06
modification: 2026-06-07
Description: Arachne 하네스 구조 다이어그램 (Mermaid) — 심볼릭 배선 · 3-레인 협업 · 훅 · SSOT 로딩 · 워크플로
tags:
aliases:
---

# 🕷️ Arachne 하네스 구조

> 이 문서의 Mermaid 다이어그램은 GitHub에서 자동 렌더링됩니다.
> 전체 디렉터리 설명은 [README](../README.md), 사용법은 [docs/USAGE.md](USAGE.md),
> 멀티-CLI 통합은 [docs/MULTI-CLI.md](MULTI-CLI.md) 참고.

---

## 1. Big Picture — Repo ↔ Multi-CLI Symlink Wiring

하나의 레포(`Arachne/`)를 `install.sh`(CLI: `arachne`)가 심볼릭 링크로 세 CLI에 연결한다.
레포를 수정하면 글로벌 설정에 즉시 반영되고, `git push/pull`로 모든 머신이 동기화된다.

```mermaid
flowchart TB
    subgraph REPO["📦 Arachne 레포 (SSOT)"]
        direction TB
        AGENTS["AGENTS.md<br/>공통 규약 SSOT"]
        CLAUDEMD["CLAUDE.md<br/>Claude 보충 지시"]
        RULES["rules/"]
        SKILLS["skills/"]
        CMDS["commands/"]
        SUBAG["agents/"]
        HOOKSD["hooks/"]
        SETT["settings.template.json"]
        DOTS["dotfiles/"]
    end

    INSTALL{{"install.sh<br/>CLI: arachne -i / -u / -c"}}

    subgraph CLAUDE["🤖 Claude Code (~/.claude)"]
        C_RULES["rules/ (네이티브 자동 로드)"]
        C_MISC["CLAUDE.md · skills · commands<br/>agents · hooks · settings.json"]
    end
    subgraph GEMINI["💎 Gemini CLI (~/.gemini)"]
        G_MD["GEMINI.md → AGENTS.md (심볼릭)"]
    end
    subgraph CODEX["🔷 Codex CLI (~/.codex)"]
        X_MD["AGENTS.md (마커 병합)"]
    end
    HOME["🏠 ~/.bash_profile · ~/.vimrc<br/>(병합)"]

    REPO --> INSTALL
    INSTALL -->|"심볼릭 링크"| CLAUDE
    INSTALL -->|"AGENTS.md 심볼릭"| GEMINI
    INSTALL -->|"AGENTS.md 마커 병합"| CODEX
    INSTALL -->|"dotfiles 병합"| HOME

    AGENTS -. "SSOT 공유" .-> G_MD
    AGENTS -. "SSOT 공유" .-> X_MD
    RULES --> C_RULES

    classDef repo fill:#1f2937,stroke:#60a5fa,color:#e5e7eb;
    classDef cli fill:#0f3d3e,stroke:#34d399,color:#d1fae5;
    class REPO,AGENTS,CLAUDEMD,RULES,SKILLS,CMDS,SUBAG,HOOKSD,SETT,DOTS repo;
    class CLAUDE,GEMINI,CODEX,C_RULES,C_MISC,G_MD,X_MD cli;
```

---

## 2. Collaboration Architecture — 3-Lane Delegation

§1이 **정적 배선**(레포→세 CLI 심볼릭)이라면, 이 절은 **런타임 협업 구조**다.
**Claude Code가 중심(오케스트레이터 + 주 구현자 + 유일 커미터)**이고, 토큰 무겁거나 검증성
작업을 두 위임 대상에게 **역할을 분리해서** 떠넘긴다. 셋 다 같은 `AGENTS.md` 규약을 공유하므로
인계 마찰이 작다.

| 레인 (Lane) | CLI | 위임 호출 | 역할 | 안 하는 것 |
| --- | --- | --- | --- | --- |
| 중심 | **Claude** | (직접) | 설계·구현·리팩터링·통합·**커밋**, 보안/임계 리뷰, 인프라 | — |
| reader / advisor | **Gemini** | `gask` (`gemini-task`) | 대용량 읽기·요약, 설계 탐색, 1차 리뷰, 장문 생성 | 최종 구현 코드 |
| tester / fixer | **Codex** | `cask` (`codex-task`) | 테스트 작성·실행, 버그 수정 | 기능 추가 |

```mermaid
flowchart TB
    GEMINI["💎 Gemini — reader/advisor<br/>대용량 읽기·요약·설계 탐색<br/>1차 리뷰·장문 생성"]
    CLAUDE["🤖 Claude Code<br/>오케스트레이터 + 주 구현자<br/>= 유일 커미터"]
    CODEX["🔷 Codex — tester/fixer<br/>테스트 작성·실행·버그 수정<br/>(기능 추가 X)"]
    GIT["📦 git (main)"]

    CLAUDE -->|"gask 위임"| GEMINI
    CLAUDE -->|"cask 위임"| CODEX
    GEMINI -.->|"요약·자문 (stdout)"| CLAUDE
    CODEX -.->|"테스트·수정 diff (stdout)"| CLAUDE
    CLAUDE ==>|"통합·스타일 보정·단독 커밋"| GIT
    GIT -.->|"git-bus: 외부 직접 커밋 감지<br/>(hooks/gemini-check.sh)"| CLAUDE

    classDef gem fill:#0f3d3e,stroke:#34d399,color:#d1fae5;
    classDef cla fill:#1e3a5f,stroke:#60a5fa,color:#dbeafe;
    classDef cdx fill:#3b2f5e,stroke:#a78bfa,color:#ede9fe;
    classDef git fill:#1f2937,stroke:#9ca3af,color:#e5e7eb;
    class GEMINI gem;
    class CLAUDE cla;
    class CODEX cdx;
    class GIT git;
```

**방향이 반대인 두 우선순위 사슬** — 같은 세 CLI를 두 축으로 줄 세운다:

| 축 | 기준 | 우선순위 | 의미 |
| --- | --- | --- | --- |
| **오프로드 (offload)** | 비용 | Gemini → Codex → (Claude 안 씀) | 토큰 무거운 일을 싸게 떠넘김 |
| **페일오버 (failover)** | 구현 품질 | Claude → Codex → Gemini | Claude 쿼터 소진 시 구현 대타는 Codex 먼저 |

> **왜 역할을 분리하나** — 구현(Claude)과 검증(Codex)을 **다른 모델**이 맡으면 상관된 맹점(correlated
> blind spot)이 줄어든다. Gemini는 코딩 스타일 충실도가 낮아 최종 구현 코드는 맡기지 않고 읽기·자문에 둔다.
> `cask`/`gask`는 블로킹·순차 호출이라 두 모델이 같은 파일을 동시에 건드리지 않으며, **커밋은 항상 Claude**다.

**`cask` 통합 경계 (제안 / 실행)**:

| 모드 | 플래그 | Codex 동작 | Claude 동작 |
| --- | --- | --- | --- |
| 제안 (기본) | 없음 | 테스트·수정 diff를 stdout 반환, 트리 미변경 | 받아서 적용·실행·커밋 |
| 실행 | `-w` | 직접 쓰고 돌려 green까지 수정, 트리 변경 | `git diff` 검토·스타일 보정·커밋 |

> 정책 단일 출처(SSOT)는 [`rules/common/workflow.md`](../rules/common/workflow.md),
> 사람용 상세는 [MULTI-CLI.md](MULTI-CLI.md)·[USAGE.md §6](USAGE.md).

---

## 3. Repository Directory Layout

> 디렉터리 구조는 다이어그램이 아닌 트리 텍스트로 표기한다(Mermaid는 관계·흐름 표현용).

```
Arachne/
├── AGENTS.md                    # 공통 규약 SSOT (Claude·Gemini·Codex 공유)
├── CLAUDE.md                    # Claude 전용 보충 지시
├── README.md
├── settings.template.json       # ~/.claude/settings.json 템플릿
├── install.sh                   # 통합 관리 도구 (CLI: arachne)
├── tmux.sh                      # 워크스페이스 매니저 (CLI: tws)
├── gemini-task.sh               # Gemini 위임 래퍼 — reader/advisor (CLI: gask, gemini-task)
├── codex-task.sh                # Codex 위임 래퍼 — tester/fixer (CLI: cask, codex-task)
├── statusline-command.sh
│
├── rules/                       # Claude 전역 행동 규칙
│   ├── common/                  # 언어 공통 (12)
│   ├── c · cpp · golang · rust  # 언어별 규칙
│   ├── python · javascript · bash
│   └── web/                     # design-quality
├── skills/                      # 워크플로·도메인 스킬 (28)
├── commands/                    # 슬래시 커맨드 (16)
├── agents/                      # 서브에이전트 7개 (planner·code-reviewer·tdd·debugger
│                                #   ·python-reviewer·fastapi-reviewer·react-reviewer)
├── hooks/                       # 이벤트 훅 (session-start/end · pre-compact · gemini-check)
├── mcp-configs/                 # MCP 서버 설정 템플릿
├── dotfiles/                    # bash_profile · vimrc (병합 원본)
├── tests/                       # 검증 (bats + shell)
└── docs/ · .github/workflows/   # 문서 · CI
```

---

## 4. Runtime — Event Hook Flow

`settings.json`이 Claude Code 라이프사이클 이벤트를 `hooks/`의 스크립트에 연결한다.

```mermaid
sequenceDiagram
    participant U as 사용자
    participant CC as Claude Code
    participant H as hooks/
    participant FS as 세션/스냅샷 파일

    Note over CC: SessionStart
    CC->>H: session-start.sh
    H->>FS: 최근 세션 파일 안내

    U->>CC: 프롬프트 입력
    Note over CC: UserPromptSubmit
    CC->>H: gemini-check.sh
    H->>H: git fetch 후 origin HEAD 비교
    H-->>CC: Gemini/Codex 외부 직접 커밋 감지 시 변경 목록 (git-bus)

    Note over CC: PreCompact (컨텍스트 압축 전)
    CC->>H: pre-compact.sh
    H->>FS: 압축 전 상태 저장

    Note over CC: Stop (세션 종료)
    CC->>H: session-end.sh
    H->>FS: git 기반 스냅샷 + last-seen-commit 저장
```

---

## 5. SSOT Convention Loading Model

`rules/common/*`는 매 세션, `rules/<언어>/*`는 해당 확장자 편집 시 자동 로드된다.
세 CLI 공통 규약은 `AGENTS.md` 하나에서 파생된다.

```mermaid
flowchart TB
    AGENTS["AGENTS.md<br/>(공통 규약 SSOT)"]

    AGENTS --> CLAUDE["Claude Code"]
    AGENTS --> GEMINI["Gemini: ~/.gemini/GEMINI.md (심볼릭)"]
    AGENTS --> CODEX["Codex: ~/.codex/AGENTS.md (마커 병합)"]

    CLAUDE --> CM["CLAUDE.md (Claude 전용 보충)"]
    CLAUDE --> RC["rules/common/* — 매 세션 로드"]
    CLAUDE --> RL["rules/<언어>/* — 확장자 매칭 시 로드"]

    RL --> EX1[".c/.h → c/*"]
    RL --> EX2[".py → python/*"]
    RL --> EX3[".go/.rs/.ts/.sh → 각 언어/*"]
    RL --> EX4[".css/.html/.jsx → web/design-quality"]

    classDef ssot fill:#3b0764,stroke:#c084fc,color:#f3e8ff;
    class AGENTS ssot;
```

---

## 6. Development Workflow Pipeline (3-Lane)

`조사 → 설계 → TDD → 리뷰 → 커밋`. 토큰 무거운 읽기·요약은 Gemini(`gask`, reader/advisor)로,
테스트·버그 수정은 Codex(`cask`, tester/fixer)로, 정밀 구현·통합·커밋은 Claude가 맡는다.
TDD = Test-Driven Development(테스트 주도 개발), RED→GREEN→REFACTOR 순서.

```mermaid
flowchart LR
    START([작업 시작]) --> INV["0. 조사·재사용<br/>sgrep · 기존 라이브러리 탐색"]
    INV --> ROUTE{무거움? 검증?}

    ROUTE -->|"설계·요약·장문·1차 리뷰"| GEMINI["💎 Gemini (gask)<br/>reader/advisor"]
    ROUTE -->|"구현·디버깅·임계 리뷰"| CLAUDE["🤖 Claude<br/>오케스트레이터+구현자"]
    ROUTE -->|"테스트 작성·실행·버그 수정"| CODEX["🔷 Codex (cask)<br/>tester/fixer"]

    GEMINI -.->|자문 결과| PLAN
    CODEX -.->|테스트·수정 diff| REVIEW
    CLAUDE --> PLAN["1. 설계<br/>planner 에이전트"]
    PLAN --> TDD["2. TDD<br/>tdd 에이전트 (RED→GREEN→REFACTOR)"]
    TDD --> REVIEW["3. 리뷰<br/>code-reviewer / debugger"]
    REVIEW --> VERIFY["4. /verify (정적+동작)"]
    VERIFY --> COMMIT["5. git commit + push (Claude 단독 커밋)"]
    COMMIT --> END([완료])

    classDef gem fill:#0f3d3e,stroke:#34d399,color:#d1fae5;
    classDef cla fill:#1e3a5f,stroke:#60a5fa,color:#dbeafe;
    classDef cdx fill:#3b2f5e,stroke:#a78bfa,color:#ede9fe;
    class GEMINI gem;
    class CLAUDE,PLAN,TDD,REVIEW cla;
    class CODEX cdx;
```
