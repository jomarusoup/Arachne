---
Title: "[plan] 하네스 방향 전환 — 저지연 시스템 북극성·평가 체계·축소"
creation: 2026-11-20
modification: 2026-11-21
status: "in progress"
tags:
 - "arachne"
 - "project"
 - "plan"
aliases:
 - "harness-direction-plan"
---
MOC:: [[Arachne]]
FROM:: [[2026-10-06-harness-inventory]]

# [plan] 하네스 방향 전환 — 전체 기획 정본

> 항상 현재 상태를 반영하는 **살아있는 정본 1개** — 버전별 사본을 만들지 않는다(git 이력이 버전,
> 큰 개정은 아래 개정 로그에 한 줄). 병렬 세션에서는 읽기 전용 상류 문서로 취급하고, 수정은 한
> 세션에서만 한다. 목표·예산 수치는 이 문서에 두지 않는다 — 정본은
> [`docs/OBJECTIVES.md`](../OBJECTIVES.md)와 [`objectives/budgets.yaml`](../../objectives/budgets.yaml)이다.

- **상태**: in progress (1단계 진행 중)
- **관련 문서**: [ADR-0007](../decisions/0007-harness-direction-lowlatency.md),
  [OBJECTIVES](../OBJECTIVES.md), [처리량 PoC 결과](../issue/2026-10-05-throughput-poc-result.md),
  [W6 인벤토리](../issue/2026-10-06-harness-inventory.md)

## 목표 (Why)

리눅스에서 **정확하고 장애가 격리된 저지연 시스템**과, 그 성능을 병목 없이 받쳐 주는
**네이티브 클라이언트**를 만드는 데 이 하네스가 실제로 기여하게 한다.
우선순위는 정확성 > 장애 격리 > 성능 > 개발 효율이다. 성능을 위해 검증을 덜어내는 변경은 기각한다.

성공 기준(모두 실행으로 확인한다):

1. 최소 파이프라인(C 송신 → C 수신·공유메모리 → Rust 유틸 → Rust exporter·모니터링 → Rust 클라이언트)이
   홈랩 기준 장비에서 `budgets.yaml` 예산을 충족한다.
2. eval 기준선이 있고, 하네스 적용 조건이 빈 설정 조건보다 노이즈 범위 밖에서 낫다
   (낫지 않은 자산은 제거 대상이다).
3. 상시 로드 컨텍스트가 8k 토큰 이하다(`claude -p` usage 차분 실측).

## 범위 (What)

- 서버는 C 중심(객체 지향은 패턴), 클라이언트·보조·유틸은 Rust, 조회·조립은 Shell, 웹은 모니터링 전용(Prometheus + Grafana). Go·Python은 범위 밖(ADR-0008, 초안의 C·C++·Rust·Go / Python·Shell을 대체).
- 계층 정의·공통 제약·운영 원칙은 [`docs/OBJECTIVES.md`](../OBJECTIVES.md)가 정본이다.
- 단계 1~5의 작업 단위는 아래 [§2](#2-단계별-작업-분해)에 있다. 확정된 단위는 실행 시 개별 task로 승격한다.

## 비범위 (Out of scope)

- 멀티-CLI 재도입, 새 언어 프로필 추가, 실행 과제로 이어지지 않는 문서 작성.
- 회사 시스템(FEP/OMS 등)의 소스·수치·구조 반입. 참조는 오픈소스(Aeron, LMAX Disruptor,
  Chronicle Queue, Seastar 등)의 설계 패턴·측정 방법론·실패 사례로 한정한다.
- main 자동 병합. 개선 작업은 worktree에서만 한다.
- 1단계 이후 신규 규칙·스킬·에이전트·커맨드 추가(동결 — `tests/freeze.bats`·`tests/check_freeze_adr.sh`가 강제).

---

## 1. 현황 실측 (2026-11-20, `67ab9bb` 기준)

### 1.1 상시 로드 자산

토큰은 **추정치**다(한글 1음절 ≈ 1토큰, 그 외 3.5자 ≈ 1토큰 — 세션 스크래치 `tok.py`).
정확한 값은 작업 1-6의 `claude -p` usage 차분으로 교체한다.

| 자산 | 바이트 | 추정 토큰 | 근거 |
|---|---:|---:|---|
| `CLAUDE.md` (`~/.claude/CLAUDE.md` → 같은 파일) | 12,292 | 3,354 | `ls -la ~/.claude` |
| `rules/README.md` (paths 없음 → 상시) | 2,267 | 682 | 세션 system-reminder에 로드 관측 |
| `rules/common/*` paths 없는 9개 (`hooks.md` 제외) | 18,500 | 5,775 | 최대 `agents.md` 1,039 |
| **소계 — 지시 파일** | **33,059** | **≈ 9,811** | 이미 8k 목표 초과 |
| 스킬 65개 description | 30,080 | ≈ 9,217 | frontmatter 추출 |
| 에이전트 12 / 커맨드 24 description | 2,809 / 2,658 | 863 / 809 | |

관측: Claude Code가 스킬 목록을 예산으로 자른다(이번 세션에서 `performance-profiling` 이후는 이름만
표시) — 스킬 실부하는 9.2k보다 작다. `skills/synced/`(gitignore)·플러그인 스킬도 컨텍스트에
들어오지만 저장소가 통제하지 않는다.

### 1.2 범위 밖 자산 분류

| 종류 | 아카이브 | 판단 필요 (→ 결정 D-07) | 유지 |
|---|---|---|---|
| agents | `fastapi-reviewer`, `react-reviewer`, `typescript-reviewer` | `python-reviewer`(유틸 언어에 전용 리뷰어 필요?), `database-reviewer`(Pro*C·DB가 북극성에 없음) | planner, code-reviewer, tdd, debugger, rust-, go-reviewer, go-build-resolver |
| commands | `fastapi-review`, `react-review`, `ts-review`, `design` | `e2e`(Playwright 절반), `python-review`, `learn`(rules 직접 기록 → 수확 원칙·동결과 충돌) | 나머지 |
| rules | `java/`, `electron/`, `react/`, `web/design-quality`, `web/ui-layout`, `python/fastapi.md` | `javascript/`, `web/security`·`web/performance`(D-02 결과 의존), `python/data-handling`, `docker/` | c, cpp, rust, golang, bash, systems, common |
| skills | fastapi-patterns, frontend-patterns, frontend-design-direction, frontend-a11y, react-testing, vite-patterns, design-system, make-interfaces-feel-better, database-migrations(Alembic) | desktop-data-client(병합·백프레셔 설계는 네이티브에 재사용 가능), backend-patterns(FastAPI 기준), json-contracts(Pydantic·TS), product-capability, product-lens, hexagonal-architecture, redis-patterns, distributed-tracing(TS 절반) | C·C++·Rust·Go·성능·보안 계열 |
| templates | `desktop-data-client/`, `profiles/web`, `profiles/python-web`, `design/DESIGN.md` | throughput-poc `receiver-node`·`report.mjs`(보고서 생성기가 Node), `c-system/src/contract/ts`(C↔TS 벡터 교차 검증), compose-3tier의 jaeger·TS 부분 | c-system, cpp, rust, sql, minimal, python |
| 배포 계층 | — | `AGENTS.md`·Gemini/Codex/Copilot 어댑터·`install-copilot.ps1`(ADR-0004의 "재도입 대비" 근거 소멸) | — |

회사 시스템 반입 점검: `git grep -nIE '\b(FEP|OMS)\b'` → 0건.

### 1.3 메인 4언어 자산 비대칭

| | C | C++ | Rust | Go |
|---|---|---|---|---|
| 전용 리뷰어 | ✗ (범용 code-reviewer) | ✗ | ✓ | ✓ (+ build-resolver) |
| rules | 5개 (최다) | 5개 / 10.0kB | 5개 / 15.8kB | 5개 / 6.3kB |
| `rules/systems` 철학 | ✓ | ✓ | ✓ | ✗ (대상 아님) |
| 전용 스킬 | 10+ | 2 | 4 | 3 |
| 템플릿·프로필 | c-system 골격 | 프로필 commands만, 코드 없음 | 프로필 + `ffi-rust` 예제 | **없음** |
| CI 빌드 단계 | ✓ (c-system·throughput-poc) | **✗** | △ (ffi-rust — cargo 없으면 C만) | **✗** |
| 로컬 툴체인 (`which`) | gcc ✓ | g++ ✓, cmake ✗ | cargo ✗ | go ✗ |

현재 작업 장비: Intel i5-8400 6코어, RHEL9 계열 커널 5.14 — 홈랩 기준 장비 여부는 결정 D-05.

### 1.4 기존 ADR 충돌 지점 (해소는 [ADR-0007](../decisions/0007-harness-direction-lowlatency.md))

| # | 기존 결정 | 충돌 | 처리 |
|---|---|---|---|
| C1 | 0006 D-02 Electron 통일 | 네이티브 직접 개발. PoC는 macOS M1 localhost·수신만(디코딩·렌더·GC 미측정 — PoC 문서 "측정의 한계") | ADR-0007이 대체 |
| C2 | 0006 D-12·D-13 (typescript-reviewer·`rules/react/` 신설) | 아카이브로 뒤집힘 | ADR-0007 기록, 실행은 2-1 |
| C3 | 0006 D-06 "Rust는 C 모듈의 점진 이식 대상" | Rust가 메인 상주·유틸 언어로 확장 | ADR-0007이 대체 |
| C4 | 0006 D-09·D-20·21 (개발 Mac·키체인 전제) | 예산 기준은 홈랩 Linux | 비밀값 보관 결정은 유지, 측정 기준만 ADR-0007 |
| C5 | 0005 D08 "클라이언트는 런타임 이식성에 위임" | 네이티브 클라이언트 | ADR-0007이 클라이언트 부분만 대체 |
| C6 | "Go 핫패스 금지"의 자리 | `rules/systems`는 C·C++·Rust만, 1단계는 규칙 추가 동결 | OBJECTIVES.md에 정본 (결정 D-06) |
| C7 | 0004 AGENTS.md 유지 근거(재도입 대비) | 재도입 금지. `check_convention_sync.sh`가 AGENTS.md 의존 | 결정 D-08 |
| C8 | 0003 상태 Proposed(3개월) | 5단계 루프는 dynamic workflows는 아니나 다중 에이전트 파이프라인 | 결정 D-13 |
| C9 | 자동 push 문구 4곳 (`workflow.md:16`, `development-workflow.md:60`, `git-workflow.md` "커밋 전 자동 실행", `commands/git.md` 6절) | "push 전 확인"으로 전환(확정) | 작업 1-4 |
| C10 | 확정 사항 "~/.claude는 저장소 심볼릭" | 실제는 일반 디렉터리 안 7개 항목(CLAUDE.md·agents·commands·hooks·rules·skills·statusline)이 main 체크아웃을 가리킴 | 위험 R3 — 결과는 같다(main 작업 트리 수정 = 즉시 라이브 반영) |

### 1.5 아카이브 시 CI·tests 수정 지점

- `.github/workflows/ci.yml` 59행 `contract ts-test`(+ Node setup), 63행 `node --test desktop-data-client`,
  66행 compose-3tier 스모크
- profile 목록: `lib/project-ci.sh` 15·22·24·33·40·47~90행(web·python-web·DESIGN.md), `install.sh` 146·148행
- tests: `project_ci.bats` 70~109, `new_project.bats` 80~111, `docs_cli_contract.bats` 19·29·32~35,
  `naming_check.bats` 103(TS 선언 검사)
- 인덱스: `tests/check_index.sh`가 agents·commands·skills를 CLAUDE.md·`docs/USAGE.md`·`skills/README.md`와 대조
- 개수 표기: "65개·24개·12개" — CLAUDE.md, README.md, `skills/README.md`, `docs/ARCHITECTURE.md`
  (`check_index.sh` "문서 개수 표기" 검사)
- 동결 매니페스트: `objectives/freeze-manifest.txt`에서 아카이브한 항목 행 삭제(삭제는 허용, 추가는 ADR 필요)

---

## 2. 단계별 작업 분해

규모: S(반나절 이하) · M(1~2일) · L(3일 이상). 각 단위 = 브랜치·PR 하나.
원칙 4(측정 후 변경)는 작업 3-6(기준선 고정) 이후 발효한다 — 그 전의 변경은 eval 비교 없이 진행한다.

### 1단계 — 기준 문서 (브랜치 `docs/harness-direction`)

| ID | 작업 | 산출물 | 완료 조건 (실행 확인) | 선행 | 규모 | 상태 |
|---|---|---|---|---|---|---|
| 1-1 | 계획 문서 | 이 문서, `docs/task/README.md` 인덱스 | `bash tests/check_index.sh` 통과 | — | S | done |
| 1-2 | 목표·예산 정본 | `docs/OBJECTIVES.md`, `objectives/budgets.yaml` | `bats tests/objectives.bats` 통과 — 모든 항목에 `status`·`source`, "실측 대기" 항목은 `value: null` | 1-1 | S | done |
| 1-3 | ADR-0007 | `docs/decisions/0007-harness-direction-lowlatency.md`, ADR 인덱스 | 인덱스 표에 0007, 다음 번호 0008 | 1-2 | S | done |
| 1-4 | push 전 확인 전환 | `rules/common/{workflow,development-workflow,git-workflow}.md`, `commands/git.md` | `grep -rnE '자동 (git )?push\|자동 푸시' rules commands` 0건, `check_convention_sync.sh` 통과 | — | S | done |
| 1-5 | 동결 + 실패 기록 양식 | `objectives/freeze-manifest.txt`, `tests/freeze.bats`, `tests/check_freeze_adr.sh`, `tests/freeze_adr.bats`, `docs/template/failure.md` | `bats tests/freeze.bats tests/freeze_adr.bats` 통과 — 범위는 rules·agents·commands·skills, 매니페스트 행 추가에 신규 ADR 없으면 CI `verify-freeze` 실패 | 1-2 | S | done |
| 1-6 | 상시 로드 토큰 실측 | `budgets.yaml`의 `context.always_loaded_tokens.measured` | 아래 명령 2조건 × 3회, input 토큰 차분 중앙값 기록 | 1-2, 사용자 실행(과금) | S | to do |
| 1-7 | 관리 규칙 정본 + 문서 지도 재구성 | `docs/MANAGEMENT.md`, `docs/README.md`, 루트 `README.md`, 범위 밖 문서 상단 표시 | `check_index.sh`·`docs_cli_contract.bats` 통과, 관리 규칙마다 강제 수단(또는 "미강제") 명시 | 1-2 | S | done |

1-6 측정 명령(사용자가 실행 — 과금·인증 필요):

```bash
# 하네스 조건
claude -p "ok" --output-format json --max-turns 1 | jq '.usage'
# 빈 설정 조건 (빈 디렉터리 + 인증만)
CLAUDE_CONFIG_DIR="$(mktemp -d)" claude -p "ok" --output-format json --max-turns 1 | jq '.usage'
# 차분 = (input + cache_creation + cache_read)의 조건 간 차이, 3회 중앙값
```

### 2단계 — 시스템 루프

허용되는 하네스 변경은 범위 밖 자산 아카이브(2-1)뿐이다. 실행 자산(검사 스크립트·템플릿·측정 도구)은
파이프라인 프로젝트 안에서 먼저 쓰고, 효과가 확인되면 4단계(4-4)에서 템플릿으로 승격한다.
모든 작업에서 실패를 `docs/template/failure.md` 양식으로 파이프라인 프로젝트의 `docs/failures/`에 기록한다.

| ID | 작업 | 산출물 | 완료 조건 | 선행 | 규모 |
|---|---|---|---|---|---|
| 2-1 | 범위 밖 자산 아카이브 | `archive/out-of-scope/`, §1.5 전 항목 수정, ADR-0004 부분 supersede(D-08 결과에 따라) | CI 4개 잡 통과, `check_index.sh` 통과, freeze-manifest 갱신 | D-07·D-08 결정 | L |
| 2-2 | 파이프라인 프로젝트 생성 + 툴체인 | `arachne -n <이름> --profile c-system`, `arachne -t`로 cargo·cmake | `.arachne/commands` 실행 통과, `cargo --version`·`cmake --version` | D-11 결정 | S |
| 2-3 | C 송신기 + 계약 정본 | `sender/`(throughput-poc 재사용), `contract/`(stream_msg.h·frame_codec·vectors) | 개방 루프 목표 레이트 달성률 ≥ 99.9% (값은 budgets), ASan·UBSan 통과 | 2-2 | M |
| 2-4 | C 수신기 + 공유메모리 갱신 (메인) | `receiver/`, `shm/`(단일 작성자 + 시퀀스 락) | 목표 레이트에서 유실·갭 0, TSan 통과, 수신기 kill -9 후 재기동 시 shm 불변식 검사 통과 | 2-3 | L |
| 2-5 | Rust 조회·덤프 유틸 + 디코더 crate | `tools/shmdump-rs/`, `decoder/`(외부 입력 디코더 — 2-7과 공유) | PROT_READ 매핑(쓰기 시도 시 SIGSEGV 테스트), vectors 교차 검증, 상태 변경 기능이 생기면 조회 기본·`--apply`·dry-run·락·감사 로그 테스트 | 2-4 | M |
| 2-6 | Rust exporter + 모니터링 | `exporter/`(Rust, shm PROT_READ + 시퀀스 락 리더, `/metrics`), Prometheus·Grafana 설정 | exporter kill·지연 주입 시 메인 지연 예산 불변(장애 격리), `cargo test` + Miri(unsafe 리더) 통과 | 2-4, D-02·D-09 | M |
| 2-7 | Rust 네이티브 클라이언트 (egui, macOS·Windows) | 스파이크 → `client/core`(UI 의존 없는 수신·디코더·병합·상태 crate) + `client/desktop`(egui) | 최적화 → 성능 → 디자인 순으로 판정: CPU·수신 경로 할당 → 프레임 시간 p99·신선도·1시간 RSS 추세가 예산 이내, 2-5 디코더 crate로 vectors 디코딩 일치, 수신 스레드가 렌더와 분리, `client/core`가 UI crate에 의존하지 않음 | 2-4, D-01 | L |
| 2-7m | 모바일 클라이언트 (Android·iOS) | 같은 `client/core` + egui 모바일 셸 | 2-7 예산 통과 후 착수. 백그라운드 복귀 시 스냅샷 + 증분 재동기화 통과, 변경 시에만 다시 그림. 네이티브 화면이 필요하면 새 ADR | 2-7 | L |
| 2-8 | 파이프라인 CI | 프로젝트 CI에 C(ASan·UBSan·TSan)·Rust(clippy·`cargo-deny`·`cargo-audit`·디코더 `cargo-fuzz`·Miri) 단계 | 프로젝트 CI 통과 | 2-5~2-7 | S |
| 2-9 | 실패 기록 축적 | `docs/failures/*.md` | 서로 다른 실패 30건 이상(3단계 과제 10~15개 수확용) | 2-3~2-8 진행 중 | — |

### 3단계 — 평가 체계

| ID | 작업 | 산출물 | 완료 조건 | 선행 | 규모 |
|---|---|---|---|---|---|
| 3-1 | eval 소유 사용자·디렉터리 | 별도 사용자(예: `arachne-eval`), `0700` 디렉터리 | 실험자 사용자로 `ls` 시 Permission denied | — | S |
| 3-2 | 과제 수확 | 과제 10~15개(1/3 holdout), 과제마다 입력 스냅샷·지시·심판 | holdout 목록이 공개 저장소·실험자 경로에 없음(`git grep` 0건) | 2-9, D-10 | M |
| 3-3 | 스크립트 심판 + 실행기 | `run-eval.sh`(`claude -p --output-format json --max-turns N`, `timeout`), 심판은 빌드·테스트·속성 검사 스크립트 | 같은 입력에 심판 2회 결과 동일(결정론) | 3-2 | M |
| 3-4 | 노이즈 측정 | 과제당 3~5회 × 2조건(하네스 / 빈 `CLAUDE_CONFIG_DIR`) | 과제별 통과율·토큰·비용의 분포 기록, 노이즈 밴드 산출 | 3-3 | M |
| 3-5 | 예산 수치 실측 | `budgets.yaml` 값 채움 | "실측 대기" 항목 0개, 각 값에 `source`(측정 명령·커밋) | 2-4~2-7, D-03·D-05 | M |
| 3-6 | 기준선 고정 | eval 기준선 보고(모델 ID·하네스 커밋 포함) | 보고 존재 → 원칙 4 발효 | 3-4 | S |

### 4단계 — 하네스 정리 (모든 변경은 eval 전후 비교)

| ID | 작업 | 산출물 | 완료 조건 | 선행 | 규모 |
|---|---|---|---|---|---|
| 4-1 | 컨텍스트 다이어트 | CLAUDE.md 트리 → `docs/ARCHITECTURE.md` 이전, `rules/common` 압축, description 축약 | 1-6 방식 실측 ≤ 8k, eval 통과율 노이즈 밴드 이내 | 3-6, D-04 | M |
| 4-2 | 반복 실패 → 실행 자산 | 2회 이상 반복 실패마다 훅·검사·템플릿 1개와 해당 문장 규칙 삭제 | 해당 실패 재현 과제에서 통과, 규칙 문장 삭제 | 3-6 | M |
| 4-3 | 제거 실험(ablation) | 자산 묶음별 제거 조건 eval 결과 표 | 차이가 노이즈 밴드 이내인 묶음은 아카이브 PR | 3-6 | M |
| 4-4 | 템플릿 승격 | 파이프라인에서 효과 확인된 실행 자산 → `templates/project/` | 하네스 CI에 Rust 빌드 단계(cargo 필수화)와 2-8에서 효과 확인된 검증 도구 추가, 통과 | 2-8 | M |

### 5단계 — 개선 루프 (홈랩, 주 1회)

| ID | 작업 | 산출물 | 완료 조건 | 선행 | 규모 |
|---|---|---|---|---|---|
| 5-1 | 관찰자 | 주간 실패·eval 결과 요약 스크립트 | 지난주 기록에서 후보 1개 이상 또는 "후보 없음" 출력 | 3-6 | S |
| 5-2 | 실험자 | worktree에서 후보 1건 구현, 실험자 전용 사용자 | 실험자가 eval 디렉터리·main 체크아웃에 쓰기 불가(권한 테스트) | 5-1, 3-1 | M |
| 5-3 | 심판 연동 | eval 사용자로 심판 실행, 기준선 대비 판정 | 판정이 스크립트 출력만으로 결정 | 3-3 | S |
| 5-4 | PR 생성 | draft PR, 사람 병합 | main 브랜치 보호(자동 병합 불가) 확인 | 5-3 | S |
| 5-5 | systemd 타이머 + 한도 | `.timer`·`.service`(`RuntimeMaxSec`), `--max-turns`, `timeout`, 주간 지출 한도, 연속 기각 N회 정지 | 한도 초과 주입 시 정지·알림, 연속 기각 시 타이머 비활성화 | 5-1~5-4, D-12 | M |

---

## 3. 결정 레지스터 (사람이 정한다)

| ID | 질문 | 선택지 | 권장안 | 근거 |
|---|---|---|---|---|
| D-01 | 네이티브 클라이언트 툴킷 | (a) Qt 6 (b) Dear ImGui (c) Rust egui·Slint | **확정 (2026-11-21, [ADR-0008](../decisions/0008-language-scope-rust-path.md)): (c) Rust + egui**, 2-7 스파이크로 최종 확인. 폼·텍스트 입력·접근성 요구가 커지면 재판정 | 유실은 언어가 아니라 수신 구조(수신·렌더 스레드 분리, 버퍼 재사용, 시퀀스 갭 재요청)가 결정한다. Rust는 C++과 같은 수준이고, 2-5 유틸과 디코더 crate를 공유하며 외부 입력 해석의 메모리 안전성을 얻는다. egui는 즉시 모드라 화면 주기 병합과 맞는다 |
| D-02 | 모니터링 웹 구성 | (a) Prometheus `/metrics` + Grafana (b) 내장 웹 페이지 | **확정 ([ADR-0008](../decisions/0008-language-scope-rust-path.md)): (a)** | 웹 코드 0줄 → `javascript/`·`web/` 규칙 아카이브(축소 지향). `/metrics`가 REST 계약 정본 역할. Grafana가 죽어도 메인 무관(장애 격리). 15초 단위 추세용이고 개별 지연값 분석은 측정 도구로 한다 |
| D-03 | `budgets.yaml` 초기 수치 출처 | (a) 요구 기반(사람이 목표 레이트 정의) (b) 홈랩 실측 기준선 × 여유율 (c) 공개 벤치 수치 | **확정 ([ADR-0008](../decisions/0008-language-scope-rust-path.md)): 처리량 목표는 (a), 지연·자원 예산은 (b)**. (c)는 방법론만 참조, 수치 반입 금지 | 회사 수치 반입 금지. PoC 수치는 macOS M1이라 기준 장비와 다름. 공개 벤치는 장비가 달라 예산으로 부적합 |
| D-04 | 8k 목표의 측정 범위 | (a) 지시 파일만 (b) `claude -p` usage 차분 전체(지시 + description) | **(b)** — 단일 실측 수치, 조작 불가 | (a)는 추정·누락 위험. 단 (b)는 현재 ≈ 20k 추정이라 4-1 규모가 커진다 → 4단계 진입 시 재확인 |
| D-05 | 홈랩 기준 장비 | (a) 현재 작업 장비(i5-8400 6C) (b) 별도 서버 | **확정 ([ADR-0008](../decisions/0008-language-scope-rust-path.md)): (a)** — `budgets.yaml` `environment`에 CPU·커널·governor(performance)·isolcpus(none) 기록 | 예산은 장비 고정 없이는 비교 불가 |
| D-06 | "Go 핫패스 금지" 위치 | (a) OBJECTIVES.md (b) `rules/golang` (c) 검사 스크립트 | **해소 ([ADR-0008](../decisions/0008-language-scope-rust-path.md))** — OBJECTIVES §3 "GC 런타임 언어 금지"로 일반화, Go는 범위 밖 | 언어 범위에서 빠져 별도 위치가 필요 없다 |
| D-07 | §1.2 "판단 필요" 자산 + Go·Python 자산 | 항목별 아카이브 / 유지 | **확정 ([ADR-0008](../decisions/0008-language-scope-rust-path.md))** — **아카이브**: python-reviewer·`/python-review`, `/learn`, desktop-data-client, backend-patterns·json-contracts·product-*·hexagonal·redis, `javascript/`·`web/*`, `python/` 전체(data-handling 포함), Go 자산(go-reviewer·go-build-resolver·`/go-review`·`/go-build`·`/go-test`·`rules/golang/`·golang-patterns·golang-testing·go-http-patterns), Python profile(`python`·`python-web`). **유지**: database-reviewer·`/database-review`(공유메모리⇄DB 계층), `docker/`. **유지·일부 삭제**: `/e2e`(Playwright 절), distributed-tracing(TS 절). 하네스 자체 테스트가 의존하는 Python fixture는 2-1에서 CI 통과 조건으로 판정 | 범위·계층 정의 대조. GC 런타임 언어 제외(ADR-0008 결정 3) |
| D-08 | AGENTS.md·타 CLI 어댑터 | (a) 전부 유지 (b) 어댑터·`install-copilot.ps1` 아카이브, AGENTS.md는 공용 규약 문서로 유지 (c) 전부 아카이브 | **확정 ([ADR-0008](../decisions/0008-language-scope-rust-path.md)): (b)** | 재도입 금지와 정합. AGENTS.md는 업계 표준 파일이고 컨텍스트 비용 0. `check_convention_sync.sh`는 유지 |
| D-09 | exporter의 데이터 접근 | (a) shm 읽기 전용 매핑 + 시퀀스 락 리더 (b) 메인이 통계 엔드포인트 제공 | **(a) 유지, 구현 언어는 cgo → Rust ([ADR-0008](../decisions/0008-language-scope-rust-path.md))** | (b)는 메인 프로세스에 HTTP 경로를 추가해 장애 격리를 해친다. (a)는 PROT_READ라 exporter 장애가 메인을 오염시키지 못한다. 리더는 핫패스가 아님을 OBJECTIVES 계층 정의로 명시 |
| D-10 | eval·holdout 저장 위치 | (a) 공개 저장소 안 (b) 별도 사용자 소유 비공개 디렉터리, 결과 요약만 저장소 | **(b)** | holdout 오염 방지(R2). 공개 저장소는 학습·실험자 노출 |
| D-11 | 파이프라인 프로젝트 저장소 | (a) 이 저장소 `templates/` 안 (b) 별도 저장소(비공개 시작) | **확정 ([ADR-0008](../decisions/0008-language-scope-rust-path.md)): (b)** | 확정 "프로젝트에서 먼저 쓰고 승격". 실패 기록에 환경 정보가 섞일 수 있어 비공개로 시작 |
| D-12 | 5단계 한도 수치 | 주간 지출 한도·`--max-turns`·timeout·연속 기각 N | 사람이 지정, 정본은 `budgets.yaml` `loop` | 비용 폭주(R4) |
| D-13 | ADR-0003 지위 | (a) Accepted(A)로 확정 (b) 0007로 supersede | **(a)** | 3개월간 (A)로 운용됨. 5단계 루프는 systemd + `claude -p`이며 dynamic workflows가 아니다 |
| D-14 | C·C++ 전용 리뷰어 | (a) 신설 (b) 보류 | **(b)** — 2단계 실패 기록에서 C/C++ 리뷰 누락이 2회 이상이면 신설 | 수확 원칙. 동결 중 |
| D-15 | throughput-poc Node 자산 대체 | `report.mjs`·`receiver-node` | **`report.mjs` → Shell(awk) 우선, 부족하면 Rust로 2-3에서 재작성 후 아카이브 ([ADR-0008](../decisions/0008-language-scope-rust-path.md))**, receiver-node는 PoC 기록용으로 아카이브 | 대체 전 제거 금지(정확성 우선). Python은 범위 밖 |
| D-16 | C↔TS 계약 벡터 검증 대체 | `contract/ts` | **Rust 디코더 crate(2-5 유틸·2-7 클라이언트 공유)가 같은 vectors를 통과한 뒤 아카이브 ([ADR-0008](../decisions/0008-language-scope-rust-path.md))** | 검증을 먼저 대체하고 나중에 제거 |

## 4. 위험과 대응

| ID | 위험 | 대응 |
|---|---|---|
| R1 | **eval 노이즈** — 같은 과제·조건에서도 통과율·비용이 흔들려 개선·퇴행을 오판 | 과제당 3~5회 반복(3-4)으로 노이즈 밴드 산출. 판정은 "차이 > 밴드"일 때만. 모델 ID를 결과에 기록하고 모델이 바뀌면 기준선 재측정. 심판은 스크립트라 심판 쪽 노이즈 0 |
| R2 | **holdout 오염** — 실험자·공개 저장소·학습 데이터에 holdout이 노출되면 과적합 | holdout은 별도 사용자 `0700` 디렉터리(D-10), 실험자 사용자 접근 불가(5-2 권한 테스트). 공개 저장소에는 과제 ID·결과 요약만. 노출 의심 시 해당 과제 폐기·재수확. 과제 원문을 PR·이슈에 붙이지 않는다 |
| R3 | **심볼릭 링크 자기 수정** — `~/.claude`의 7개 항목이 main 체크아웃을 가리켜 main 작업 트리 수정이 즉시 라이브 하네스(훅 포함)를 바꾼다 | 개선 작업은 worktree에서만. 실험자는 자기 worktree를 가리키는 `CLAUDE_CONFIG_DIR`로 실행하고 main 체크아웃에 쓰기 권한 없음. 실험 중 가드 훅(`guard-bash.sh`·`guard-secrets.sh`)은 제거 실험 대상에서 제외. main 자동 병합 금지 + 브랜치 보호 |
| R4 | **비용 폭주** — 반복 eval·주간 루프가 무제한 토큰 소비 | `--max-turns`, `timeout`, systemd `RuntimeMaxSec`, 주간 지출 한도(D-12), 연속 기각 N회 정지, 실행마다 usage를 append-only 원장에 기록하고 한도 초과 시 타이머 비활성화 |
| R5 | **동결 누수** — 1단계 이후 문장 규칙이 다시 늘어남 | `tests/freeze.bats`가 CI에서 추가를 차단, `tests/check_freeze_adr.sh`가 신규 ADR 없는 매니페스트 행 추가를 차단 |
| R6 | **회사 정보 반입** — 공개 저장소에 회사 소스·수치·구조 유입 | 참조는 오픈소스 한정, 예산 출처는 홈랩 실측만(D-03). `check_sensitive_text.sh`·`guard-secrets.sh` 유지. 실패 기록 양식에 반입 점검 체크리스트 |
| R7 | **Goodhart** — eval 과제에 맞춘 하네스 과적합 | holdout 1/3 판정 필수, 공개 과제만 개선되고 holdout이 안 오르면 기각 |
| R8 | **제거 실험이 안전 자산 제거** | 정확성·보안 자산(가드 훅, 비밀 검사, sanitizer 게이트)은 ablation 대상에서 제외하거나 holdout + 보안 과제 통과를 추가 조건으로 |

## 5. 1단계 즉시 착수 목록 (이번 주)

- [x] 1-1 계획 문서 작성
- [x] 1-2 `docs/OBJECTIVES.md`·`objectives/budgets.yaml` 골격 + `tests/objectives.bats`
- [x] 1-3 ADR-0007 + ADR 인덱스
- [x] 1-4 "자동 push" → "push 전 확인" 전환 (rules 3개 + `/git`)
- [x] 1-5 동결 매니페스트 + `tests/freeze.bats` + `tests/check_freeze_adr.sh` + 실패 기록 양식 `docs/template/failure.md`
- [x] 1-7 관리 규칙 정본 `docs/MANAGEMENT.md` + 문서 지도 재구성 (버전 규칙 적용 1.5.0은 PR #57)
- [ ] 1-6 상시 로드 토큰 실측 (사용자 실행 — 과금)
- [x] 결정: D-01·D-02·D-03·D-05·D-07·D-08·D-11 확정, 언어 범위 재정의 ([ADR-0008](../decisions/0008-language-scope-rust-path.md))

## 로드맵

| 단계 | 내용 | 상태 |
| ---- | ---- | ----- |
| 1 | 기준 문서·동결 | in progress |
| 2 | 시스템 루프(파이프라인 직접 개발·실패 기록·아카이브) | to do |
| 3 | 평가 체계(과제·심판·노이즈·예산 실측) | to do |
| 4 | 하네스 정리(다이어트·실행 자산 전환·ablation) | to do |
| 5 | 개선 루프(systemd 주간·사람 병합) | to do |

## 개정 로그

| 날짜       | 요약 |
| ---------- | ---- |
| 2026-11-20 | 초안 — 현황 실측, 단계 분해, 결정 레지스터 D-01~D-16, 위험 R1~R8 |
| 2026-11-21 | 1-7 — 관리 규칙 정본(MANAGEMENT)·독자 경로 문서 지도·루트 README 축소·범위 밖 표시, 버전 규칙(SemVer) 확정 후 1.5.0 |
| 2026-11-21 | 클라이언트 우선순위(최적화 > 성능 > 디자인)·코어/UI 분리·플랫폼 단계(macOS·Windows → Android·iOS) 반영, 2-7 갱신·2-7m 추가, 클라이언트 자원 예산 2개 |
| 2026-11-21 | 결정 확정(ADR-0008) — 서버 C 중심·클라이언트·보조·유틸 Rust, Go·Python 범위 밖, Rust 경계 이식. D-01·02·03·05·07·08·11 확정, D-06 해소, D-09·15·16 언어 대체, 2-2·2-5~2-8·4-4 갱신 |
| 2026-11-21 | PR #57 보완 — 확정 불변식(핫패스 할당 0·클라이언트 송신 블로킹 0)·유틸 지연 예산 추가, 동결 범위에 agents·commands 포함, 매니페스트 행 추가 ↔ ADR 동반 CI 검사 |
