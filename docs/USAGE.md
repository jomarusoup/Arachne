# Arachne 사용 가이드

하니스(Claude Code)에서 Arachne의 **skills · agents · 슬래시 커맨드 · hooks · rules · Gemini 협업**을 실제로 어떻게 쓰는지 정리한 상세 가이드.

> README는 "무엇이 있는지"(카탈로그), CLAUDE.md는 "항상 적용되는 지시서", 이 문서는 "어떻게 쓰는지"(how-to)를 담는다.

---

## 0. 전체 구조 한눈에

| 구성 요소 | 위치 | 호출 방식 | 등록·로드 방식 |
|---|---|---|---|
| 슬래시 커맨드 | `commands/*.md` | 채팅에 `/이름` 입력 | YAML frontmatter(`description`) 자동 인식 |
| 에이전트 | `agents/*.md` | Claude가 자동 활성화 / `Task`·`Agent` 호출 | YAML frontmatter(`name`,`tools`,`model`) |
| 스킬(지식) | `skills/*.md` | 관련 작업 시 Claude가 참조 | frontmatter 없음 — 마크다운 본문 |
| 훅 | `hooks/*.sh` | Claude Code 이벤트가 자동 실행 | `settings.json`의 `hooks` 섹션 |
| 규칙 | `rules/**/*.md` | 항상 적용 | `CLAUDE.md`의 `@import` + 확장자 기반 |

모든 항목은 `~/.claude/`에 심볼릭 링크로 연결되어, **레포 수정 = 즉시 반영**된다(`install.sh` 참고).

---

## 1. 슬래시 커맨드 (`commands/`)

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
| `/issue` `/status` | GitHub 이슈 순차 처리 · 프로젝트 현황 |
| `/git` `/handoff` `/save-session` `/learn` | 커밋·푸시 · 전환 저장 · 세션 요약 · 패턴 학습 |

### 새 커맨드 추가
1. `commands/새이름.md` 생성
2. frontmatter에 `description` 작성
3. 본문에 단계별 절차 작성 → 저장 즉시 `/새이름`으로 사용 가능

---

## 2. 에이전트 (`agents/`)

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

### 병렬 실행
독립적인 작업은 여러 에이전트를 동시에 돌릴 수 있다(예: 모듈 A 보안 분석 + 모듈 B 성능 검토 + 모듈 C 리뷰 → 3개 동시).

---

## 3. 스킬 — 도메인 지식 (`skills/`)

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
| 언어별 패턴·테스팅 | `rust-patterns` `rust-testing` `golang-patterns` `golang-testing` `go-http-patterns` |
| 워크플로·보안·기타 | `tdd-workflow` `verification-loop` `security-review` `security-scan` `docker-patterns` |
| 네트워크 | `network-config-validation` `network-interface-health` `netmiko-ssh-automation` |

### 새 스킬 추가
`skills/새스킬.md` 생성 → "언제 / 어떻게 / 예시" 3요소로 작성. frontmatter 불필요.

---

## 4. 훅 (`hooks/`)

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

## 5. 규칙 (`rules/`)

### 사용법
규칙은 **항상 자동 적용**된다 — 별도 호출 없음.

- **공통 규칙**(`rules/common/*.md`)은 `CLAUDE.md`의 `@import`로 모든 세션에 로드된다.
- **언어별 규칙**(`rules/<언어>/*.md`)은 해당 확장자 파일을 편집할 때 자동 활성화된다.

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

## 6. Claude ↔ Gemini 협업

### 역할 분담
| 작업 | 담당 |
|---|---|
| 기능 기획 · 요구사항 · 설계 문서 · 아키텍처 | **Gemini** (`gemini -p "..."`) |
| README.md 갱신 · 브레인스토밍 · 우선순위 결정 | **Gemini** |
| 코드 구현 · 버그 수정 · 리팩터링 · 설정 관리 | **Claude** |

### 위임 워크플로
```
1. Claude가 위임 트리거 감지 → "gemini -p '...'" 안내
2. 사용자가 별도 터미널에서 Gemini 실행
3. Gemini가 파일 수정 → git commit → git push   (= Gemini의 "응답")
4. Claude가 다음 메시지 입력 시 자동 감지 (gemini-check.sh)
5. Claude가 변경 확인 후 후속 구현 진행
```

> 두 AI 사이에 직접 채널은 없다. **git 히스토리가 메시지 버스** 역할을 한다.

### 감지 메커니즘
| 구성 요소 | 역할 |
|---|---|
| `hooks/gemini-check.sh` | `UserPromptSubmit` 훅 — 매 입력마다 현재 HEAD ↔ 기준점 비교 |
| `.claude/last-seen-commit` | Claude가 마지막으로 확인한 커밋 해시 (gitignore, 추적 안 됨) |
| `hooks/session-end.sh` | 세션 종료 시 현재 HEAD를 기준점에 기록 |

현재 HEAD가 기준점과 다르면 새 커밋 목록·변경 파일을 박스 UI로 출력하고 기준점을 갱신(중복 알림 방지)한다. 기준점 파일이 없으면 최초 1회는 조용히 기록만 한다.

---
## 7. 설치 · 업데이트 · 동기화 (`arachne`)

Arachne는 `install.sh`를 통해 설치되며, 설치 후에는 `arachne` 커맨드로 관리할 수 있습니다.

### 설치 및 업데이트 흐름
1. **심볼릭 링크**: `CLAUDE.md`, `commands/`, `agents/` 등을 `~/.claude/`에 연결하여 레포 수정이 즉시 반영되게 합니다.
2. **설정 생성**: `settings.template.json`을 기반으로 홈 경로를 치환하여 `~/.claude/settings.json`을 생성합니다.
3. **CLI 등록**: `~/.local/bin/`에 `arachne`(관리), `tws`(워크스페이스) 커맨드를 등록합니다.

### dotfiles 병합 메커니즘 (Safe Merge)
기존의 단순 심볼릭 링크 방식 대신, 사용자 홈 디렉토리의 `.bash_profile`, `.vimrc` 파일에 Arachne 설정을 **병합**합니다.

- **동작 원리**: 파일 내에 `# === ARACHNE BEGIN ===`과 `# === ARACHNE END ===` 마커를 삽입하고, 그 사이에만 설정을 주입합니다.
- **안전성**: 마커 외부의 기존 사용자 설정은 전혀 건드리지 않으므로 재실행해도 안전합니다.
- **멱등성**: 이미 섹션이 존재하면 해당 내용만 최신으로 교체하고, 없으면 파일 끝에 추가합니다.

### 주요 명령어
```bash
# 최신 상태로 업데이트 (git pull + 재설치 통합)
arachne update

# settings.json 변경사항을 레포 템플릿에 반영
arachne --export-settings

# 로컬에서 수정한 dotfiles 설정을 레포(dotfiles/)로 역추출
arachne --export-dotfiles
```

---

## 8. Tmux 워크스페이스 매니저 (`session`)

Claude Code는 터미널을 점유하므로, 여러 프로젝트나 테스트 환경을 동시에 관리하기 위해 `arachne session` (또는 `tws`) 명령어를 제공합니다.

### 주요 기능
- **대화형 메뉴**: `arachne session` 입력 시 세션 생성, 목록 확인, 접속, 삭제를 번호 입력만으로 처리합니다.
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

