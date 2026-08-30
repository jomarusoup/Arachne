# Arachne 사용 가이드

하니스(Claude Code)에서 Arachne의 **skills · agents · 슬래시 커맨드 · hooks · rules**를 실제로 어떻게 쓰는지 정리한 상세 가이드.

> README는 "무엇이 있는지"(카탈로그), CLAUDE.md는 "항상 적용되는 지시서", 이 문서는 "어떻게 쓰는지"(how-to)를 담는다.
> 공통 규약(AGENTS.md)의 다중 CLI 배포는 [MULTI-CLI.md](MULTI-CLI.md) 참고. 3-레인 협업 런타임은 ADR-0004로 archive됐다.

---

## 0. Overview at a Glance

| 구성 요소 | 위치 | 호출 방식 | 등록·로드 방식 |
|---|---|---|---|
| 슬래시 커맨드 | `commands/*.md` | 채팅에 `/이름` 입력 | YAML frontmatter(`description`) 자동 인식 |
| 에이전트 | `agents/*.md` | Claude가 자동 활성화 / `Task`·`Agent` 호출 | YAML frontmatter(`name`,`tools`,`model`) |
| 스킬(지식) | `skills/*.md` | 관련 작업 시 Claude가 참조 | YAML frontmatter(`name`,`description`) + 마크다운 본문 |
| 훅 | `hooks/*.sh` | Claude Code 이벤트가 자동 실행 | `settings.json`의 `hooks` 섹션 |
| 규칙 | `rules/**/*.md` | 공통=매 세션 / 언어=확장자 매칭 시 | `~/.claude/rules/` 네이티브 자동 로드 (paths frontmatter) |

표의 Claude 자산은 `~/.claude/`에 심볼릭 링크로 연결되어 레포 수정 후 다음 로드부터 반영된다.
예외로 `settings.json`은 템플릿에서 생성되는 실파일이며, Codex의 `AGENTS.md`도 마커 병합 사본이라
각각 재설치가 필요하다.

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
| `/tdd` `/verify` `/e2e` | TDD 사이클 · 2단계 검증(+`.arachne/reports/` 리포트 기록) · E2E 테스트 |
| `/design` `/python-review` | 설계 문서 · Python 코드 리뷰 |
| `/fastapi-review` `/react-review` | FastAPI API 리뷰 · React/Next 웹 리뷰 |
| `/database-review` | DB schema·쿼리·migration·데이터 보안 리뷰 |
| `/issue` `/status` | GitHub 이슈 순차 처리 · 프로젝트 현황 |
| `/git` `/worktree` | 커밋·푸시 · 병렬 세션 worktree 생성/점검/정리 |
| `/handoff` `/save-session` `/learn` | 전환 저장 · 세션 요약 · 패턴 학습 |
| `/codegraph` | 코드 그래프·심볼·영향 분석 (확장 도구 — [docs/tools/](tools/README.md)) |

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
| `database-reviewer` | sonnet | DB schema·쿼리·migration·ORM 변경 리뷰 (read-first) |

### 병렬 실행
독립적인 작업은 여러 에이전트를 동시에 돌릴 수 있다(예: 모듈 A 보안 분석 + 모듈 B 성능 검토 + 모듈 C 리뷰 → 3개 동시).

---

## 3. Skills — Domain Knowledge (`skills/`)

### 사용법
슬래시 커맨드와 달리 **직접 호출하는 것이 아니라**, 관련 작업을 할 때 Claude가 해당 지식 파일을 참조한다. `name`·`description` YAML frontmatter와 마크다운 본문으로 구성된 지식 문서다.

- 예: Rust 저지연 코드를 작성할 때 → `rust-patterns`, `latency-critical-systems` 참조
- 예: 재사용 Rust 라이브러리·crate 를 만들 때 → `rust-library-crate` 참조
- 예: C/C++ 메모리 문제 → `memory-check`, `build-debug` 참조
- 예: 모던 C++ 작성·리뷰 → `cpp-patterns`, C 테스트 → `c-testing` 참조
- 예: Pro*C(`*.pc`)·ecpg(`*.pgc`) 임베디드 SQL → `embedded-sql` 참조

### 구성
각 스킬 파일은 다음 3요소로 작성한다.
1. **언제 사용하는지** — 적용 트리거
2. **어떻게 동작하는지** — 핵심 절차·도구
3. **예시** — 구체 코드/명령

frontmatter는 `name`(파일명과 일치)·`description`에 더해 **`triggers`** 를 계약 필드로 가진다:

```yaml
triggers:
  paths: ["**/*.py"]                  # 관련 파일 패턴 (경로 무관 스킬은 빈 배열)
  keywords: ["Python", "타입 힌트"]   # 작업 설명에 등장하는 활성화 키워드 (필수, 1개 이상)
```

`triggers`는 스킬 선택의 결정론 힌트다 — 편집 대상 경로가 `paths`와 매칭되거나 작업 설명에
`keywords`가 등장하면 해당 스킬을 우선 참조한다. 형식은 `tests/skill_meta.bats`가 CI에서 강제한다.

### 분류
| 카테고리 | 스킬 |
|---|---|
| 시스템 프로그래밍 | `latency-critical-systems` `linux-system-network-programming` `trading-systems` `performance-profiling` `build-debug` `memory-check` `cpp-testing` `error-handling` |
| 언어별 패턴·테스팅 | `cpp-patterns` `c-testing` `rust-patterns` `rust-testing` `rust-library-crate` `golang-patterns` `golang-testing` `go-http-patterns` `python-patterns` `python-testing` |
| 백엔드·웹 | `backend-patterns` `frontend-patterns` `frontend-design-direction` `frontend-a11y` `design-system` `api-design` `fastapi-patterns` `make-interfaces-feel-better` |
| 데이터·DB | `json-contracts` `database-migrations` `postgres-patterns` `redis-patterns` `embedded-sql` |
| 제품·기획·아키텍처 | `product-lens` `product-capability` `plan-orchestrate` `architecture-decision-records` `hexagonal-architecture` `agent-architecture-audit` |
| 워크플로·보안·기타 | `tdd-workflow` `verification-loop` `research-routing` `security-review` `security-scan` `docker-patterns` `deployment-patterns` `agentic-engineering` |
| 네트워크 | `network-interface-health` `data-throughput-accelerator` |

### 새 스킬 추가
`skills/새스킬.md` 생성 → `name`·`description` frontmatter를 달고 "언제 / 어떻게 / 예시" 3요소로 작성.

---

## 4. Hooks (`hooks/`)

### 사용법
훅은 직접 실행하지 않는다. Claude Code의 **이벤트가 발생하면 자동 실행**된다.

### 등록된 훅 (이 레포 기준)
| 훅 스크립트 | 이벤트 | 동작 |
|---|---|---|
| `git-bus-check.sh` | `UserPromptSubmit` | 업스트림 브랜치의 새 커밋 감지 (작성 CLI 판별 없음). fetch는 기본 300초 간격 스로틀 — `GIT_BUS_FETCH_INTERVAL`로 조정 |
| `doc-drift-check.sh` | `PostToolUse` (`Edit\|Write`) | 기능 파일(스크립트·rules·agents 등) 변경 시 README/docs 갱신 알림 (세션당 1회) |
| `session-start.sh` | `SessionStart` | 최근 세션 파일 경로 안내 |
| `ua-stale-check.sh` | `SessionStart` | Understand-Anything 지식그래프(`.understand-anything/meta.json`)가 HEAD보다 N커밋 뒤처지면 `/understand` 재실행 안내 — 임계값 `UA_STALE_THRESHOLD`(기본 1) |
| `pre-compact.sh` | `PreCompact` | 컨텍스트 압축 전 상태 스냅샷 저장 |
| `session-end.sh` | `Stop` | 종료 시 스냅샷 + `last-seen-commit` 갱신 |

> `doc-drift-check.sh`는 **문서를 자동 작성하지 않는다** — 자동 생성은 드리프트·노이즈·비용 위험이 커서
> "갱신 필요" 알림만 한다. 인덱스 누락은 `tests/check_index.sh`가 잡는다.

### 등록 방법
`~/.claude/settings.json`의 `hooks` 섹션에 이벤트별로 등록한다.

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "bash \"__HOME__/.claude/hooks/git-bus-check.sh\"" }
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

> **검증된 범위**: 위 훅들은 **메인 세션** 이벤트에서 동작이 확인됐다. 서브에이전트(Task 도구)의
> 도구 호출에도 `PostToolUse` 등이 발화하는지는 미검증이며(감사
> [2026-08-22-harness-runtime-audit](issue/2026-08-22-harness-runtime-audit.md) Q2 [추정] —
> 확정 실험은 [task/2026-08-25-hook-subagent-experiment](task/2026-08-25-hook-subagent-experiment.md)),
> 컨텍스트 조립 과정은 관측 수단이 없다(같은 감사 B-10).

### 상태표시줄 (`statusline-command.sh`)

Claude Code 상태표시줄은 `settings.template.json`의 `statusLine.command`로 자동 등록된다.
직접 실행하는 사용자 명령이 아니라 Claude Code가 상태 JSON을 stdin으로 전달할 때 렌더링된다.

표시 정보:

- 현재 모델과 git 브랜치
- 컨텍스트 사용률과 입력·출력 token 합계
- 현재 세션 비용
- 최근 5시간 비용 예산 잔여율
- 주간 비용 예산 잔여율과 다음 토요일 정오까지 남은 시간

상태 파일:

| 파일 | 역할 |
| --- | --- |
| `~/.claude/usage_limits.json` | 선택적 사용자 예산 설정 |
| `~/.claude/usage_track.json` | 최근 7일 비용 증가분 기록 |
| `~/.claude/usage_last.json` | 직전 렌더의 세션 비용 저장 |

예산을 바꾸려면 다음 파일을 만든다.

```json
{
  "limit_5h": 5.0,
  "limit_weekly": 35.0
}
```

파일이 없으면 기본값은 5시간 `$5.00`, 주간 `$35.00`이다. 이 값은 서비스 제공자의 실제 사용
한도나 청구 정책을 조회하는 기능이 아니라 **로컬 비용 추적용 사용자 기준값**이다.

주의:

- `jq`, `awk`, GNU `date -d`가 필요하다.
- 상태표시줄은 `usage_track.json`과 `usage_last.json`을 갱신하므로 순수 표시 전용 함수가 아니다.
- macOS 기본 BSD `date`와 Windows 네이티브 셸에서는 시간 계산이 호환되지 않을 수 있다.
- 추적값은 Claude Code가 stdin으로 제공한 세션 비용의 렌더 간 증가분을 누적한 근사치다.

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
| `*.java` `pom.xml` `build.gradle*` | `rules/java/*` |
| `*.rs` `Cargo.toml` | `rules/rust/*` |
| `*.py` | `rules/python/*` |
| `*.js` `*.ts` | `rules/javascript/*` |
| `Dockerfile` `*.Dockerfile` `docker-compose*.yml` `compose*.yml` | `rules/docker/*` |
| `*.css` `*.scss` `*.html` `*.jsx` `*.tsx` `*.vue` | `rules/web/design-quality.md` |
| `*.sh` | `rules/bash/*` |

각 언어 폴더는 `coding-style · hooks · patterns · security · testing` 5개 파일을 기본으로 한다
(Python은 `fastapi`·`data-handling` 추가, web은 `design-quality` 단일 파일).

---

## 6. Install · Update · Sync (`arachne`)

Arachne는 macOS/Linux에서 `install.sh`, Windows에서 `install.ps1`을 통해 설치되며,
설치 후에는 공통으로 `arachne` 커맨드로 관리할 수 있습니다.

### Windows 설치

Claude Code·Codex CLI·Gemini CLI 자체를 아직 설치하지 않았다면
[WINDOWS-SETUP.md](WINDOWS-SETUP.md)에서 Git for Windows·Node.js 준비, 각 CLI 설치와 인증,
네이티브 PowerShell/WSL2 선택 기준을 먼저 확인합니다.

```powershell
git clone https://github.com/jomarusoup/Arachne.git "$HOME\Arachne"
Set-Location "$HOME\Arachne"
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Install
```

- 관리자 권한 없이 디렉터리는 junction, 파일은 hard link로 연결하며 실패 시 복사합니다.
- `~\.local\bin`을 사용자 PATH에 등록하고 `arachne.cmd`, `tws.cmd`, `docs-sync.cmd` 래퍼를
  생성합니다. 새 터미널부터 PATH 변경이 적용됩니다.
- Claude 훅 실행에는 Git for Windows의 `bash.exe`가 필요합니다.
- `tws`는 Windows 네이티브 미지원이며 WSL 또는 별도 tmux 환경에서만 사용할 수 있습니다.
- Windows PowerShell에서는 `arachne -Target codex -Install`처럼 PowerShell 인자 형식도 사용할 수 있습니다.

### 설치 및 업데이트 흐름
1. **심볼릭 링크**: `CLAUDE.md`, `commands/`, `agents/` 등을 `~/.claude/`에 연결하여 레포 수정이 즉시 반영되게 합니다.
2. **설정 생성**: `settings.template.json`을 기반으로 홈 경로를 치환하여 `~/.claude/settings.json`을 생성합니다.
3. **CLI 등록**: `~/.local/bin/`에 `arachne`(관리), `tws`(워크스페이스), `docs-sync`(문서 동기화) 커맨드를 등록합니다.

### 지원 플랫폼과 전제

| 환경 | 상태 | 전제 |
|---|---|---|
| Linux | 지원 | Bash, Git, 표준 Unix 도구 |
| Windows + WSL2 | 조건부 | Linux 호환 경로지만 이 저장소 CI에서 별도 검증하지 않음 |
| macOS | 지원 | 기본 설치 지원. 전체 기여자 테스트는 Homebrew coreutils 필요 |
| Windows 네이티브 | 부분 지원 | `install.ps1` 설치 + Copilot 통합 타깃 + **Git Bash 훅 런타임 스모크**(`tests/smoke_hooks.sh`)를 CI 검증(#40) |

설치기와 기여자 테스트의 도구 요구사항은 다르다. 기능별 정확한 범위는
[COMPATIBILITY.md](COMPATIBILITY.md)를 따른다. Windows 네이티브에서는 PowerShell 설치기를
사용하되 Bash 기반 훅과 위임 래퍼에는 Git for Windows가 필요하다.

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
| `arachne -i`, `--install` | 의존성 사전 점검(경고만) + `~/.claude/` 심볼릭 링크 + `settings.json` 생성 + dotfiles 병합 + bin 등록 (재설치) + 확장 도구(UA·taste-skill·codegraph) 자동 설치·최신 갱신 |
| `arachne -i --with-ua` | 위 설치 + 확장 도구를 Understand-Anything 만으로 한정 |
| `arachne -i --with-extras` | (하위 호환) 기본 동작과 동일 |
| `arachne -u`, `--update` | 대화형 선택: Arachne 업데이트/재설치, Understand-Anything 갱신, codegraph 갱신 (비대화형은 전체 갱신) |
| `arachne -u --with-ua` | 업데이트 + Understand-Anything 플러그인만 갱신 |
| `arachne -u --with-extras` | (하위 호환) 업데이트 + 확장 도구 전체 동기화 |
| `arachne --extras [--all\|--ua\|--taste\|--codegraph]` | 확장 도구만 단독 설치(무인자=대화형 항목별 선택) |
| `arachne -c`, `--check` | Claude·Gemini·Codex·Copilot 연결 상태 점검 — 심볼릭 댕글링·병합본 stale 탐지 |
| `arachne -n <P> [DIR] --profile <PROFILE>`, `--new` | 신규 프로젝트 스캐폴딩. `--no-git`, `minimal|python|web|python-web|cpp|rust` 지원 |
| `arachne init-ci [DIR] --profile <PROFILE>`, `--init-ci` | 기존 프로젝트에 profile 기반 검증 runner와 workflow 생성/갱신 |
| `arachne project-check [DIR]`, `--project-check` | 프로젝트의 `.arachne/verify.sh`를 실행하고 실패 상태를 그대로 반환 |
| `arachne feedback new/list/submit` | Arachne 개선 피드백을 프로젝트 로컬에 기록하고 명시 확인 후 GitHub Issue로 제출 |
| `arachne -s`, `--session` | tmux 워크스페이스 매니저 실행 (= `tws`, 8장 참고) |
| `arachne -e`, `--export-settings` | 현재 `~/.claude/settings.json` → 레포 `settings.template.json`으로 역추출 |
| `arachne -d`, `--export-dotfiles` | 로컬 `~/.bash_profile`·`~/.vimrc`의 변경 → 레포 `dotfiles/`로 역추출 |
| `arachne -v`, `--version` | 버전 정보 출력 |

Windows PowerShell 설치기는 현재 설치·업데이트·점검·버전 기능을 지원합니다.
프로젝트 스캐폴딩, settings/dotfiles 내보내기, tmux 세션 관리는 macOS/Linux 또는 WSL에서 실행합니다.

Web 계열 profile은 `docs/design/DESIGN.md`를 제품 디자인 정본으로 생성한다. `/design`은
`docs/design/DESIGN.md` → `docs/design/README.md` → 루트 `DESIGN.md` 순서로 읽으며, 상세 계약은
[DESIGN-DOCS.md](DESIGN-DOCS.md)가 정본이다.

### Project Feedback

Arachne 자체의 불편, 결함, 개선 의견은 사용 프로젝트 안에서 먼저 초안으로 기록한다.

```bash
arachne feedback new "설치 문서 개선"
arachne feedback list
arachne feedback submit docs/feedback/YYYY-MM-DD-HHMMSS-arachne-feedback.md
```

`submit`은 본문을 먼저 출력하고 `YES` 확인 전에는 전송하지 않는다. 토큰, API key, 사용자 절대 경로
같은 민감정보 후보가 있으면 기본 제출을 중단한다. 제출 성공 시 GitHub Issue URL과 제출 시각을
피드백 문서에 기록한다.

> 하위호환: 옛 단어형(`install` / `update` / `session` / `export-settings` / `export-dotfiles`)도 별칭으로 여전히 동작한다.

### 확장 도구 (codegraph · taste-skill · Understand-Anything)

`arachne -i` 설치가 확장 도구까지 **자동으로 설치·최신 갱신**한다 (미설치는 설치, 기설치는
git pull/plugin update — 멱등). 전역(`~/.claude` 사용자 스코프 + PATH)에 1회 설치되면 모든
프로젝트에서 쓸 수 있다. 설치되면 전역 규칙·planner가 자동으로 이들을 우선 사용하도록
유도하고(조사=codegraph, 디자인=taste-skill, 구조 파악=UA), 미설치면 `sgrep`·기본 감각·Grep
으로 자동 폴백한다.

```bash
arachne -i                       # 설치 + 확장 도구 전체 자동 설치·갱신
arachne -i --with-ua             # 설치 + 확장 도구는 Understand-Anything 만
arachne -u                       # 대화형: Arachne / Understand-Anything / codegraph 선택 갱신
arachne -u --with-ua             # 업데이트 + Understand-Anything 만
arachne --extras                 # 확장 도구만 단독: 대화형 항목별 [Y/n]
arachne --extras --all           # 확장 도구만 셋 다 (비대화형)
arachne --extras --codegraph     # 개별 (--taste / --ua 동일)
```

각 도구의 GitHub·설치·커맨드·워크플로 접점은 [docs/tools/](tools/README.md) 참고:
[codegraph](tools/codegraph.md) · [taste-skill](tools/taste-skill.md) ·
[Understand-Anything](tools/understand-anything.md) · [extras-setup](tools/extras-setup.md).

### 사용 프로젝트 검증

Arachne 자체 `.github/workflows/ci.yml`은 Arachne 저장소만 검증한다. 다른 프로젝트가 Arachne를
사용한다고 해서 중앙 CI가 자동 실행되지는 않는다. 각 프로젝트에서 다음 구조를 버전 관리한다.

```text
.arachne/
├── profile         # Arachne가 관리하는 CI profile
├── verify.sh       # Arachne가 관리하는 공통 runner
└── commands        # 프로젝트가 관리하는 검증 명령, 한 줄에 하나
.github/workflows/
└── arachne.yml     # main push/PR에서 verify.sh 실행
```

기존 프로젝트 초기화:

```bash
arachne init-ci --profile python-web
```

profile별 기본 명령과 GitHub 런타임은 자동 생성된다. 상세 계약은
[PROJECT-CI.md](PROJECT-CI.md), 도구 기준은 [PYTHON-WEB-PROFILE.md](PYTHON-WEB-PROFILE.md)를
따른다.

명령은 위에서 아래로 프로젝트 루트에서 실행되며 첫 실패 상태가 그대로 반환된다. `init-ci`를 다시
실행하면 관리 파일인 `verify.sh`와 workflow는 최신 템플릿으로 갱신하고 사용자 소유
`.arachne/commands`는 보존한다.

로컬 검증:

```bash
arachne project-check
```

Claude Code의 `/git`은 `.arachne/verify.sh`가 있는 프로젝트에서 이 명령을 커밋 전에 실행한다.
GitHub Actions는 같은 파일을 `bash .arachne/verify.sh`로 실행한다.

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
  등록: arachne, tws, docs-sync -> bin
```

> **부작용 주의**
> - `settings.json`은 매번 템플릿에서 **재생성**된다. 직접 수정한 값이 있으면 먼저 `arachne -e`로 템플릿에 반영해야 유실되지 않는다 (직전 값은 `settings.json.bak`에 보존).
> - dotfiles는 `# === ARACHNE BEGIN/END ===` 마커 **안쪽만** 갱신하므로 마커 밖 사용자 설정은 안전하다.
> - 셸에 즉시 반영하려면 `source ~/.bash_profile`.

### 왜 어느 위치에서 실행해도 동작하나

`arachne`는 `~/.local/bin/arachne → install.sh` 심볼릭 링크다. `install.sh`는 POSIX 호환
`ResolvePath`로 심링크를 해석해 **실제 레포 경로**를 찾으므로, 현재 작업 디렉터리와 무관하게 올바른 레포에서
`git pull`·재설치가 수행된다.

### 트러블슈팅

| 증상 | 원인·해결 |
| ---- | --------- |
| `arachne: command not found` | `~/.local/bin`이 PATH에 없음. `export PATH="$HOME/.local/bin:$PATH"`를 `.bash_profile`에 추가 후 `source` |
| `git pull` 단계에서 인증 실패 | 레포 원격이 SSH(`git@github.com:...`)이므로 SSH 키 등록 필요 |
| 새 CLI 스크립트가 명령으로 안 잡힘 | `install.sh`의 `BIN_TARGETS`에 `"스크립트명:커맨드명"` 추가 후 `arachne -i` 재실행 |

---

## 7. Tmux Workspace Manager (`-s`)

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
