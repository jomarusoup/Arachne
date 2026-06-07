# Arachne 사용 가이드

하니스(Claude Code)에서 Arachne의 **skills · agents · 슬래시 커맨드 · hooks · rules · Gemini 협업**을 실제로 어떻게 쓰는지 정리한 상세 가이드.

> README는 "무엇이 있는지"(카탈로그), CLAUDE.md는 "항상 적용되는 지시서", 이 문서는 "어떻게 쓰는지"(how-to)를 담는다.
> Gemini CLI·Codex CLI와의 통합 사용·전파·상호작용은 [MULTI-CLI.md](MULTI-CLI.md)에 별도 정리돼 있다.

---

## 0. Overview at a Glance

| 구성 요소 | 위치 | 호출 방식 | 등록·로드 방식 |
|---|---|---|---|
| 슬래시 커맨드 | `commands/*.md` | 채팅에 `/이름` 입력 | YAML frontmatter(`description`) 자동 인식 |
| 에이전트 | `agents/*.md` | Claude가 자동 활성화 / `Task`·`Agent` 호출 | YAML frontmatter(`name`,`tools`,`model`) |
| 스킬(지식) | `skills/*.md` | 관련 작업 시 Claude가 참조 | frontmatter 없음 — 마크다운 본문 |
| 훅 | `hooks/*.sh` | Claude Code 이벤트가 자동 실행 | `settings.json`의 `hooks` 섹션 |
| 규칙 | `rules/**/*.md` | 공통=매 세션 / 언어=확장자 매칭 시 | `~/.claude/rules/` 네이티브 자동 로드 (paths frontmatter) |

모든 항목은 `~/.claude/`에 심볼릭 링크로 연결되어, **레포 수정 = 즉시 반영**된다(`install.sh` 참고).

---

## 1. Slash Commands (`commands/`)

### 사용법
채팅 입력창에 `/커맨드명`을 입력하면 해당 워크플로가 실행된다.

```
/add 결제 모듈에 재시도 로직 추가
/fix 로그인 시 세션 토큰이 갱신되지 않는 버그
/verify
```

### 동작 원리
- `commands/이름.md` 파일이 곧 `/이름` 커맨드가 된다.
- 파일 상단 YAML frontmatter의 `description`이 `/help` 목록에 표시된다.

```yaml
---
description: /명령어 설명
---
```

- 본문에 적힌 절차를 Claude가 그대로 따른다. 인자는 커맨드 뒤에 자연어로 붙인다.

### 주요 커맨드
| 커맨드 | 용도 |
|---|---|
| `/add` `/fix` `/refactor` | 기능 추가 · 버그 수정 · 리팩터링 |
| `/tdd` `/verify` `/e2e` | TDD 사이클 · 2단계 검증 · E2E 테스트 |
| `/design` `/python-review` | 설계 문서 · Python 코드 리뷰 |
| `/fastapi-review` `/react-review` | FastAPI API 리뷰 · React/Next 웹 리뷰 |
| `/issue` `/status` | GitHub 이슈 순차 처리 · 프로젝트 현황 |
| `/git` `/handoff` `/save-session` `/learn` | 커밋·푸시 · 전환 저장 · 세션 요약 · 패턴 학습 |

### 새 커맨드 추가
1. `commands/새이름.md` 생성
2. frontmatter에 `description` 작성
3. 본문에 단계별 절차 작성 → 저장 즉시 `/새이름`으로 사용 가능

---

## 2. Agents (`agents/`)

### 사용법
대부분 **Claude가 상황을 보고 자동 활성화**한다. 명시적으로 부르고 싶으면 작업을 위임하도록 요청하면 된다(예: "code-reviewer로 이 변경 리뷰해줘").

### 자동 활성화 기준 (`rules/common/agents.md`)
| 상황 | 활성화 에이전트 |
|---|---|
| 파일 3개 이상 수정 / 신규 모듈 도입 / 시스템 레벨 변경 | `planner` |
| 코드 작성·수정 완료 직후 | `code-reviewer` |
| 신규 기능 구현 시작 | `tdd` |
| 빌드 실패 · 세그폴트 · 메모리 오류 | `debugger` |

### 동작 원리
`agents/이름.md`의 YAML frontmatter로 정의된다.

```yaml
---
name: 에이전트명          # 호출 시 매칭되는 식별자
description: 한 줄 설명    # 언제 활성화할지 Claude가 참고
tools: ["Read", "Grep"]   # 허용 도구 목록
model: opus               # opus / sonnet / haiku
---
```

| 에이전트 | model | 역할 |
|---|---|---|
| `planner` | opus | 구현 설계·단계 분해 |
| `code-reviewer` | sonnet | 품질·보안·안정성 리뷰 |
| `tdd` | sonnet | Red-Green-Refactor 안내 |
| `debugger` | sonnet | GDB·valgrind·strace·perf |
| `python-reviewer` | sonnet | PEP 8·타입 힌트·보안·이디엄 Python 리뷰 |
| `fastapi-reviewer` | sonnet | FastAPI async·DI·스키마·API 보안 리뷰 |
| `react-reviewer` | sonnet | React/Next 렌더·Hooks·a11y·XSS·성능 리뷰 |

### 병렬 실행
독립적인 작업은 여러 에이전트를 동시에 돌릴 수 있다(예: 모듈 A 보안 분석 + 모듈 B 성능 검토 + 모듈 C 리뷰 → 3개 동시).

---

## 3. Skills — Domain Knowledge (`skills/`)

### 사용법
슬래시 커맨드와 달리 **직접 호출하는 것이 아니라**, 관련 작업을 할 때 Claude가 해당 지식 파일을 참조한다. frontmatter가 없는 순수 마크다운 지식 문서다.

- 예: Rust 저지연 코드를 작성할 때 → `rust-patterns`, `latency-critical-systems` 참조
- 예: C/C++ 메모리 문제 → `memory-check`, `build-debug` 참조

### 구성
각 스킬 파일은 다음 3요소로 작성한다.
1. **언제 사용하는지** — 적용 트리거
2. **어떻게 동작하는지** — 핵심 절차·도구
3. **예시** — 구체 코드/명령

### 분류
| 카테고리 | 스킬 |
|---|---|
| 시스템 프로그래밍 | `latency-critical-systems` `trading-systems` `performance-profiling` `build-debug` `memory-check` `cpp-testing` `error-handling` |
| 언어별 패턴·테스팅 | `rust-patterns` `rust-testing` `golang-patterns` `golang-testing` `go-http-patterns` `python-patterns` `python-testing` |
| 백엔드·웹 | `backend-patterns` `frontend-patterns` `api-design` `fastapi-patterns` `make-interfaces-feel-better` |
| 워크플로·보안·기타 | `tdd-workflow` `verification-loop` `security-review` `security-scan` `docker-patterns` `agentic-engineering` |
| 네트워크 | `network-config-validation` `network-interface-health` `netmiko-ssh-automation` |

### 새 스킬 추가
`skills/새스킬.md` 생성 → "언제 / 어떻게 / 예시" 3요소로 작성. frontmatter 불필요.

---

## 4. Hooks (`hooks/`)

### 사용법
훅은 직접 실행하지 않는다. Claude Code의 **이벤트가 발생하면 자동 실행**된다.

### 등록된 훅 (이 레포 기준)
| 훅 스크립트 | 이벤트 | 동작 |
|---|---|---|
| `gemini-check.sh` | `UserPromptSubmit` | 메시지 입력마다 Gemini 새 커밋 감지 |
| `session-start.sh` | `SessionStart` | 최근 세션 파일 경로 안내 |
| `pre-compact.sh` | `PreCompact` | 컨텍스트 압축 전 상태 스냅샷 저장 |
| `session-end.sh` | `Stop` | 종료 시 스냅샷 + `last-seen-commit` 갱신 |

### 등록 방법
`~/.claude/settings.json`의 `hooks` 섹션에 이벤트별로 등록한다.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "__HOME__/.claude/hooks/gemini-check.sh" }
        ]
      }
    ]
  }
}
```

> 이 레포에서는 `settings.template.json`이 추적되는 원본이고, `install.sh`가 `__HOME__`를 실제 경로로 치환해 `~/.claude/settings.json`을 생성한다. **훅을 추가하면 반드시 템플릿에도 반영**해야 `install.sh` 재실행 시 사라지지 않는다.

### 이벤트 종류
| 이벤트 | 시점 | 용도 |
|---|---|---|
| `PreToolUse` | 도구 실행 전 | 검증·차단(종료 코드 `2`로 차단) |
| `PostToolUse` | 도구 실행 후 | 자동 포맷·린트 |
| `UserPromptSubmit` | 메시지 입력 시 | 상태 체크·알림 |
| `SessionStart` / `Stop` | 세션 시작/종료 | 컨텍스트 로드 / 스냅샷 |
| `PreCompact` | 압축 전 | 상태 저장 |

종료 코드: `0` 성공(경고 출력 가능), `2` 차단(`PreToolUse`에서만 유효).

---

## 5. Rules (`rules/`)

### 사용법
규칙은 **항상 자동 적용**된다 — 별도 호출 없음.

- **공통 규칙**(`rules/common/*.md`)은 `~/.claude/rules/` 네이티브 자동 로드로 **모든 세션에** 적용된다(@import 아님 — `install.sh`가 `rules/`를 심볼릭).
- **언어별 규칙**(`rules/<언어>/*.md`)은 `paths` frontmatter 덕에 해당 확장자 파일을 편집할 때 자동 활성화된다.
- Gemini·Codex는 `rules/` 자동 로더가 없어, 공통 규약 다이제스트인 [`AGENTS.md`](../AGENTS.md)를 본다(6장 참고).

| 확장자 | 자동 로드되는 규칙 |
|---|---|
| `*.c` `*.h` | `rules/c/*` |
| `*.cpp` `*.hpp` | `rules/cpp/*` |
| `*.go` | `rules/golang/*` |
| `*.rs` `Cargo.toml` | `rules/rust/*` |
| `*.py` | `rules/python/*` |
| `*.js` `*.ts` | `rules/javascript/*` |
| `*.sh` | `rules/bash/*` |

각 언어 폴더는 `coding-style · hooks · patterns · security · testing` 5개 파일로 구성된다.

---

## 6. Claude ↔ Codex ↔ Gemini Collaboration (3-Lane)

**전제**: Claude Code가 중심(오케스트레이터 + 주 구현자). Codex·Gemini는 위임 대상이며, 셋 다 `AGENTS.md` 공통 규약을 공유해 인계 마찰이 작다.

> **정책 SSOT**: 비용 라우팅·역할 분담의 **단일 출처는 [`rules/common/workflow.md`](../rules/common/workflow.md)** (Claude가 실제로 따르는 행동 규칙). 이 절은 사람용 설명이며, 충돌 시 workflow.md가 우선한다.

### 역할 분담 (3-레인)
| 레인 | CLI | 호출 | 하는 일 |
|---|---|---|---|
| 오케스트레이터 + 주 구현자 | **Claude** | (중심) | 설계·구현·리팩터링·통합·커밋, 보안 리뷰, 설정·마이그레이션·인프라 |
| tester / fixer | **Codex** | `cask` (`codex-task`) | 테스트 작성·실행, 버그 수정 (기능 추가 X) |
| reader / advisor | **Gemini** | `gask` (`gemini-task`) | 대용량 읽기·요약, 설계 탐색, 1차 리뷰, 장문 생성 (구현 X) |

> 우선순위 두 사슬: **오프로드**(비용) = Gemini → Codex → (Claude 안 씀), **페일오버**(구현 품질) = Claude → Codex → Gemini.
> Claude 쿼터 소진 시 구현 대타는 Codex 먼저 — `/handoff`로 인계. Gemini는 코딩 스타일 충실도가 낮아 최종 구현 코드는 안 맡긴다.

### 경로 A — `gask` 직접 호출 (Gemini reader/advisor)
Claude Code가 **터미널 전환 없이 Bash로 `gask`를 직접 호출**해 답변을 받아온다.
`gask`(=`gemini-task`)는 `gemini -p`의 경고·노이즈를 걸러 **답변만 stdout**으로 돌려주는 래퍼다 (`gemini-task.sh` → `~/.local/bin/gask`).

```bash
gask "이 설계 검토해줘: $(cat module.c)"            # 자문 → 답변 stdout
gask "이 로그 에러 원인만 요약: $(cat app.log)"      # 요약 → 답변 stdout
gask "README 초안 작성" > README.md                  # 생성 → 파일로 (내용 재독 금지)
gask -m gemini-2.5-flash "간단 질의"                 # 모델 지정 (선택)
```

#### 비용 라우팅 — 핵심
| 패턴 | 예시 | 방식 | 비용 |
|---|---|---|---|
| **끌어오기 (요약·자문)** | 대용량 읽기, 설계 검토, 조사 | `gask "..."` → 답변 사용 | 🟢 절약 (큰 입력 → 작은 출력) |
| **쏟아내기 (문서 생성)** | README, 설계 문서, 장문 | `gask "..." > file` → **재독 금지** | 🔴 읽으면 절약 상쇄 |

> Gemini 답을 Claude 컨텍스트로 끌어오는 건 **요약·자문일 때만**. 장문 생성은 파일로 빼고 Claude는 존재만 확인한다 — 다시 읽으면 절약이 사라진다.
> 권한: `settings.json`의 `permissions.allow`에 `Bash(gask:*)`가 있어 호출마다 승인 프롬프트가 뜨지 않는다.

### 경로 B — `cask` 직접 호출 (Codex tester/fixer)
Claude Code가 **Bash로 `cask`를 직접 호출**해 테스트·수정을 위임하고 결과만 받아온다.
`cask`(=`codex-task`)는 `codex exec`의 헤더·메타·경고를 걸러 **결과만 stdout**으로 돌려준다 (`codex-task.sh` → `~/.local/bin/cask`).

```bash
cask "tests/ 의 parser 테스트 보강안 제시: $(cat src/parser.c)"  # 제안만 (read-only 기본)
cask -w "실패하는 test_auth 를 green 까지 수정"                   # 직접 실행·수정 (workspace-write)
cask -r "이 함수 리뷰만 해줘"                                     # 역할 주입 없이 raw
cask -m <model> -C <dir> "..."                                    # 모델·작업 디렉터리 지정
```

| 모드 | 플래그 | Codex | Claude |
|---|---|---|---|
| 제안 (기본) | 없음 | 테스트 코드·수정 diff 반환, 트리 미변경 | 적용·실행·커밋 |
| 실행 | `-w` | 직접 쓰고 돌려 green 까지 수정 | `git diff` 검토·스타일 보정·커밋 |

> `cask`는 블로킹·순차 실행이라 두 모델이 같은 파일을 동시에 건드리지 않는다. **커밋은 항상 Claude.**
> 권한: `Bash(cask:*)`가 `permissions.allow`에 있어 호출마다 승인 프롬프트가 뜨지 않는다.

### 경로 C — git-bus 감지 (보조)
본인·가족이 **다른 터미널에서 Gemini/Codex로 직접 커밋**한 경우를 위한 비동기 채널. `gask`/`cask`와 공존한다.

| 구성 요소 | 역할 |
|---|---|
| `hooks/gemini-check.sh` | `UserPromptSubmit` 훅 — `git fetch` 후 `origin` HEAD ↔ 기준점 비교 |
| `.claude/last-seen-commit` | 마지막으로 확인한 리모트 커밋 해시 (gitignore, 추적 안 됨) |
| `hooks/session-end.sh` | 세션 종료 시 fetch한 리모트 HEAD를 기준점에 기록 |

리모트 HEAD가 기준점과 다르면 새 커밋 목록·변경 파일을 박스 UI로 출력하고 기준점을 갱신(중복 알림 방지)한다. 기준점 파일이 없으면 최초 1회는 조용히 기록만 한다.

> 두 AI 사이 채널은 둘이다: **`gask`(동기 호출) + git 히스토리(비동기 메시지 버스).**

---
## 7. Install · Update · Sync (`arachne`)

Arachne는 `install.sh`를 통해 설치되며, 설치 후에는 `arachne` 커맨드로 관리할 수 있습니다.

### 설치 및 업데이트 흐름
1. **심볼릭 링크**: `CLAUDE.md`, `commands/`, `agents/` 등을 `~/.claude/`에 연결하여 레포 수정이 즉시 반영되게 합니다.
2. **설정 생성**: `settings.template.json`을 기반으로 홈 경로를 치환하여 `~/.claude/settings.json`을 생성합니다.
3. **CLI 등록**: `~/.local/bin/`에 `arachne`(관리), `tws`(워크스페이스), `gask`/`gemini-task`(Gemini 위임), `cask`/`codex-task`(Codex 위임), `docs-sync`(문서 동기화) 커맨드를 등록합니다.

### dotfiles 병합 메커니즘 (Safe Merge)
기존의 단순 심볼릭 링크 방식 대신, 사용자 홈 디렉토리의 `.bash_profile`, `.vimrc` 파일에 Arachne 설정을 **병합**합니다.

- **동작 원리**: 파일 내에 `# === ARACHNE BEGIN ===`과 `# === ARACHNE END ===` 마커를 삽입하고, 그 사이에만 설정을 주입합니다.
- **안전성**: 마커 외부의 기존 사용자 설정은 전혀 건드리지 않으므로 재실행해도 안전합니다.
- **멱등성**: 이미 섹션이 존재하면 해당 내용만 최신으로 교체하고, 없으면 파일 끝에 추가합니다.

### 전체 명령어 레퍼런스

설치 후 `arachne`는 표준 CLI 관행을 따른다: **인수 없이 실행하면 도움말, 각 동작은 단/장 플래그로 지정.**
단, 레포에서 직접 실행하는 `./install.sh`의 무인자 실행은 최초 설치로 취급한다.

> **첫 설치는 `./install.sh`로 진행한다.** 설치 후 무인자 `arachne`는 도움말을 출력하고,
> 재설치 또는 설정 동기화는 `arachne -i`를 사용한다.

| 명령 | 동작 |
| ---- | ---- |
| `arachne`, `arachne -h`, `--help` | 도움말 출력 |
| `arachne -i`, `--install` | `~/.claude/` 심볼릭 링크 + `settings.json` 생성 + dotfiles 병합 + bin 등록 (재설치) |
| `arachne -u`, `--update` | `git pull` 후 위 설치를 재실행 (동기화 허브) |
| `arachne -c`, `--check` | 3개 CLI(Claude·Gemini·Codex) 연결 상태 점검 — 심볼릭 댕글링·Codex stale 탐지 |
| `arachne -n <P> [DIR]`, `--new` | 신규 프로젝트 스캐폴딩 — `README.md` + `docs/{issue,idea,template/example.md}`. 모든 문서 frontmatter는 `docs/template/example.md`(SSOT) 파생. `--no-git`로 git init 생략 |
| `arachne -s`, `--session` | tmux 워크스페이스 매니저 실행 (= `tws`, 8장 참고) |
| `arachne -e`, `--export-settings` | 현재 `~/.claude/settings.json` → 레포 `settings.template.json`으로 역추출 |
| `arachne -d`, `--export-dotfiles` | 로컬 `~/.bash_profile`·`~/.vimrc`의 변경 → 레포 `dotfiles/`로 역추출 |
| `arachne -v`, `--version` | 버전 정보 출력 |

> 하위호환: 옛 단어형(`install` / `update` / `session` / `export-settings` / `export-dotfiles`)도 별칭으로 여전히 동작한다.

```bash
# 재설치 / 새 스크립트·심볼릭 링크 추가 후 재등록
arachne -i

# 최신 상태로 업데이트 (git pull + 재설치 통합)
arachne -u

# tmux 워크스페이스 매니저 진입
arachne -s             # tws 와 동일

# settings.json 변경사항을 레포 템플릿에 반영
arachne -e

# 로컬에서 수정한 dotfiles 설정을 레포(dotfiles/)로 역추출
arachne -d
```

### `arachne -u` 실행 시 일어나는 일

```text
[Arachne] 업데이트 시작 (git pull)
이미 업데이트 상태입니다.
[Arachne] 최신 소스 기반 재설치 진행
  링크: ~/.claude/CLAUDE.md, commands, agents, rules, hooks, skills
  백업: ~/.claude/settings.json -> settings.json.bak   ← 기존 설정 보존
  생성: ~/.claude/settings.json (from settings.template.json)
  갱신 (ARACHNE 섹션): ~/.bash_profile, ~/.vimrc
  등록: arachne, tws, gask, gemini-task, cask, codex-task, docs-sync -> bin
```

> **부작용 주의**
> - `settings.json`은 매번 템플릿에서 **재생성**된다. 직접 수정한 값이 있으면 먼저 `arachne -e`로 템플릿에 반영해야 유실되지 않는다 (직전 값은 `settings.json.bak`에 보존).
> - dotfiles는 `# === ARACHNE BEGIN/END ===` 마커 **안쪽만** 갱신하므로 마커 밖 사용자 설정은 안전하다.
> - 셸에 즉시 반영하려면 `source ~/.bash_profile`.

### 왜 어느 위치에서 실행해도 동작하나

`arachne`는 `~/.local/bin/arachne → install.sh` 심볼릭 링크다. `install.sh`는 `readlink -f`로
심링크를 해석해 **실제 레포 경로**를 찾으므로, 현재 작업 디렉터리와 무관하게 올바른 레포에서
`git pull`·재설치가 수행된다.

### 트러블슈팅

| 증상 | 원인·해결 |
| ---- | --------- |
| `arachne: command not found` | `~/.local/bin`이 PATH에 없음. `export PATH="$HOME/.local/bin:$PATH"`를 `.bash_profile`에 추가 후 `source` |
| `git pull` 단계에서 인증 실패 | 레포 원격이 SSH(`git@github.com:...`)이므로 SSH 키 등록 필요 |
| 새 CLI 스크립트가 명령으로 안 잡힘 | `install.sh`의 `BIN_TARGETS`에 `"스크립트명:커맨드명"` 추가 후 `arachne -i` 재실행 |

---

## 8. Tmux Workspace Manager (`-s`)

Claude Code는 터미널을 점유하므로, 여러 프로젝트나 테스트 환경을 동시에 관리하기 위해 `arachne -s` (또는 `tws`) 명령어를 제공합니다.

### 주요 기능
- **대화형 메뉴**: `arachne -s` 입력 시 세션 생성, 목록 확인, 접속, 삭제를 번호 입력만으로 처리합니다.
- **워크플로 템플릿**:
  - `기본`: 일반 터미널 세션
  - `dev`: 진입 시 `claude` 커맨드를 자동 실행
  - `테스트`: 화면을 좌우로 분할하여 한쪽엔 코드/로그, 한쪽엔 테스트 실행
- **영속성**: 터미널 창을 닫아도 `tws` 세션은 백그라운드에서 유지되며, 언제든 다시 `Attach`할 수 있습니다.

### 필수 단축키 (Prefix: `Ctrl + b`)
- **세션 탈출 (Detach)**: `Ctrl + b` -> `d` (작업 유지)
- **화면 전환**: `Ctrl + b` -> `방향키`
- **화면 최대화**: `Ctrl + b` -> `z`
- **스크롤 모드**: `Ctrl + b` -> `[` (이후 방향키, 종료는 `q`)

---

## 9. Delegation Wrappers (`gask` / `cask`) — CLI Reference

**언제·왜·비용 라우팅**은 [6장](#6-claude--codex--gemini-collaboration-3-lane)을 참고. 이 절은 명령 레퍼런스만 다룬다.
두 래퍼 모두 내부 CLI 노이즈(stderr)를 걸러 **결과만 stdout**으로 돌려준다. 각각 짧은 별칭과 명시적 이름으로 등록된다
(`gask`=`gemini-task` → `gemini-task.sh`, `cask`=`codex-task` → `codex-task.sh`).

### `gask` (= `gemini-task`) — Gemini reader/advisor
```bash
gask [-m MODEL] "프롬프트..."
cat file | gask "이 입력을 요약해줘"      # stdin 입력은 프롬프트에 자동 append
```

| 옵션·요소 | 설명 |
| --------- | ---- |
| `-m MODEL` | 사용할 Gemini 모델 (미지정 시 `gemini` 기본값 또는 환경변수 `GASK_MODEL`) |
| `-h` | 도움말 출력 |
| 종료 코드 | 내부 `gemini` 호출 결과를 그대로 전파 → 스크립트·파이프라인에 안전 |
| stdout / stderr | 답변 본문은 stdout, 노이즈 제거 후 남은 진단만 stderr |

### `cask` (= `codex-task`) — Codex tester/fixer
```bash
cask [-m MODEL] [-w] [-r] [-C DIR] "프롬프트..."
cat test.log | cask "이 실패 원인 분석하고 수정 diff 제시"   # stdin 자동 append
```

| 옵션·요소 | 설명 |
| --------- | ---- |
| `-m MODEL` | 사용할 Codex 모델 (미지정 시 `codex` 기본값 또는 환경변수 `CASK_MODEL`) |
| `-w` | 쓰기 모드(workspace-write) — codex가 테스트를 직접 쓰고 실행해 수정. 기본은 read-only 제안 모드 |
| `-r` | raw — tester/fixer 역할 프리앰블 없이 프롬프트 그대로 전달 |
| `-C DIR` | 작업 루트 디렉터리 지정 (`codex -C`) |
| `-h` | 도움말 출력 |
| 종료 코드 | 내부 `codex` 호출 결과를 그대로 전파 |
| stdout / stderr | 결과 본문은 stdout, 진짜 에러로 보이는 줄만 stderr |

> 사용 예시·통합 경계(제안/실행 모드)·비용 라우팅은 6장 참고.
