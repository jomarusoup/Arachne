---
Title: "[plan] 프로그래밍 철학(TPOP 기반) 하네스 이식 및 규칙 충돌 정리"
creation: 2026-09-29
modification: 2026-10-05
status: "in progress"
tags:
 - "arachne"
 - "plan"
 - "rules"
 - "c"
 - "cpp"
 - "rust"
aliases:
 - "philosophy-integration"
---
MOC:: [[Arachne]]
FROM:: [[programming-philosophy]]

# [plan] 프로그래밍 철학(TPOP 기반) 하네스 이식 및 규칙 충돌 정리

> 살아있는 정본 1개. 결정(§3)이 확정되면 단계별로 `docs/task/`로 분해하고,
> 결정 내용은 ADR-0005로 고정한다. 기준 문서는 `programming-philosophy.md`
> (결정 레지스터 D01~D17 + 원칙 본문 §2~§11 + 위임 압축본 §12).

- **상태**: in progress — 결정 확정(2026-10-05), 실행 순서는 `2026-10-05-arachne-roadmap.md` §4 웨이브를 따른다
- **기준 커밋**: `d6e260d` (2026-09-13)
- **관련 문서**: [[programming-philosophy]], [[ARACHNE_AUDIT_2026-09-13]], [[0002-systems-profiles]]

---

## 1. 목표 (Why)

2026-09-29 평가에서 Arachne의 도구·검증 층(sanitizer, clippy, miri, 퍼징, ADR)은 철학을 잘
구현하지만, 원칙 층에는 세 가지 문제가 확인됐다.

1. **규칙 충돌** — 매 세션 로드되는 `rules/common`에 웹/JS 출신 규칙(불변성 절대 원칙)이
   섞여 시스템 코드 규칙과 정면 충돌한다. `code-reviewer`가 올바른 핫패스 제자리 변경을
   HIGH 결함으로 지적하는 구조다.
2. **사실 오류** — `strncpy`를 안전한 대체재로 권고하는 등, 규칙이 틀린 코드를 유도한다.
3. **공백** — 동시성·성능 철학·디버깅 방법론·표기법이 규칙에 없다.

**성공 기준**
- 시스템 언어(C/C++/Rust) 파일 작업 시 로드되는 규칙 사이에 서로 반대되는 지시가 0건.
- §2의 사실 오류 grep 패턴이 저장소에서 0건.
- `rules/common`(매 세션 로드) 용량 증가 없음 — 철학은 paths 지연 로드로만 들어간다.
- 기존 CI(`tests/check_convention_sync.sh`, `tests/check_index.sh`, bats 전체) 통과.
- 검증 시나리오(§6.3)에서 리뷰어가 핫패스 제자리 변경을 결함으로 지적하지 않는다.

## 2. 범위 (What)

| 단계 | 내용 | 결정 의존 | 상태 |
|---|---|---|---|
| P0 | 결정 확정 → ADR-0005 작성 | — | to do |
| P1 | 사실 오류 수정 | 없음 (즉시 가능) | to do |
| P2 | 규칙 충돌 해소 | D18~D22, D03, D16 | to do |
| P3 | 철학 본문 이식 (신규 `rules/systems/`) | D23, D01~D17 | to do |
| P4 | 공백 보강 (에이전트·스킬) | D05, D06, D12 | to do |
| P5 | 검증 및 드리프트 테스트 | — | to do |

## 비범위 (Out of scope)

- Go·Java·Python·JS·Docker·Bash 규칙의 철학 정합성 (불변성 규칙 이동 대상 확인만 한다).
- 하네스로 이미 작성된 외부 프로젝트 코드의 일괄 리네이밍.
- `archive/multi-cli/` 재도입 판단 (ADR-0004 유지).
- 스킬 47개 전수 재작성. 시스템 계열 5개(`latency-critical-systems`, `rust-patterns`,
  `trading-systems`, `cpp-patterns`, `linux-system-network-programming`)만 대상.

---

## 3. 결정 사항 (사용자 확정 필요)

형식: 선택지를 `[x]`로 바꾸고 결정일을 적는다. `(권장)`은 평가 근거에 따른 기본값이다.
기존 D01~D17은 `programming-philosophy.md` §1을 그대로 쓰고, 여기에는 이 하네스 고유의
충돌에서 나온 D18~D23과 **P2에 직접 영향을 주는 기존 결정**만 다시 적는다.

### 3.1 하네스 고유 결정 (신규)

**D18. 불변성 원칙의 적용 범위** — 결정일: 2026-10-05 / 사유: 권장안 채택 + 로드맵 R2(JS 핫패스 예외, C 공유메모리 제자리 갱신 허용)
현재 `rules/common/patterns.md`가 "절대 변경 금지"를 전 언어에 강제한다.
- [x] (권장) **언어별 분리** — 불변성 절대 원칙은 JS/TS·Python 규칙으로 이동. 시스템 언어는
  "가변 상태는 소유자가 하나이고 범위가 명확해야 한다(const 기본, `&mut`/포인터로 소유 명시)"로 대체.
- [ ] **common 유지 + 예외 명시** — 원칙은 두되 "C/C++/Rust 핫패스·사전 할당 버퍼는 예외" 추가.
- [ ] **현행 유지**

**D19. 네이밍 하우스 스타일** — 결정일: 2026-10-05 / 사유: 권장안 채택 + 로드맵 R7(약어는 프로젝트 사전 기준, 기존 파일은 기존 관례 우선)
현재 PascalCase 함수, `g_` 전역, 단일 문자 금지(`i`→`ii`), 구조체 `_t` 접미사.
- [x] (권장) **C/C++는 하우스 스타일 유지, Rust는 생태계 관용** — 회사 코드 관례와 Rust 도구
  (rustfmt·clippy·API Guidelines) 양쪽을 존중. 단, `ii` 규칙은 전 언어 폐지하고
  "이름 길이는 스코프에 비례"로 대체. `_t` 접미사는 POSIX 예약 충돌로 폐지(아래 D19-a).
- [ ] **전 언어 관용** — C는 커널 스타일(snake_case 함수), C++는 Core Guidelines/표준 라이브러리 스타일.
- [ ] **현행 유지** (`ii`·`_t` 포함)
- D19-a. `_t` 접미사 대체: [x] (권장) 접미사 없음(`ConnInfo`) [ ] `_s`/`_e` 등 종류 접미사 [ ] 유지

**D20. 파일·함수 헤더 블록 의무** — 결정일: 2026-10-05 / 사유: 권장안 채택
현재 모든 파일·함수에 `/*###*/`·`/*===*/` 헤더와 `DATA`/`Modification` 날짜 필드 필수.
- [x] (권장) **축소** — 파일 헤더는 유지하되 날짜 필드는 삭제(git 이력이 정본). 함수 헤더는
  공개 API·비자명 함수에만. Rust는 `//!`(모듈)·`///`(항목) 문서 주석으로 대체.
- [ ] **현행 유지**
- [ ] **폐지** — 언어 표준 문서 주석(Doxygen·rustdoc)만 사용.

**D21. 테스트 강제 수준** (기존 D15와 연동) — 결정일: 2026-10-05 / 사유: 권장안 채택
현재 TDD 필수 + 커버리지 80% 일괄.
- [x] (권장) **동시 작성 + 수치 기준은 신규 모듈만** — 기능과 테스트를 같은 변경에, 버그 수정은
  재현 테스트 먼저. 80%는 신규 모듈 게이트로, 레거시 수정에는 "변경 라인 테스트"만.
- [ ] **현행 유지** (TDD·80% 전면)

**D22. `latency-critical-systems` 스킬 처리** — 결정일: 2026-10-05 / 사유: 권장안 채택 + 로드맵 R3(역할 경계)
현재 내용이 웹 서비스(엣지·브라우저 렌더) 지연 중심.
- [x] (권장) **분리** — 현 내용은 `service-latency`(가칭)로 개명, `latency-critical-systems`는
  프로세스 내부 핫패스(캐시라인·거짓 공유·코어 고정·busy-poll·할당 제거·꼬리 지연)로 재작성.
- [ ] **보강만** — 기존 스킬에 "프로세스 내부 핫패스" 절 추가.

**D23. 철학 본문 배치** — 결정일: 2026-10-05 / 사유: 권장안 채택
- [x] (권장) **`rules/systems/` 신설** — `philosophy.md`(원칙) + `decisions.md`(결정 레지스터),
  paths = `*.c *.h *.cpp *.hpp *.cc *.hh *.cxx *.rs Cargo.toml`. 언어 특화 항목은 기존
  `rules/{c,cpp,rust}/patterns.md`에 병합(파일 신설 없음).
- [ ] **언어 디렉터리에 분산** — 각 언어 디렉터리에 `philosophy.md` 추가(공통 부분 3중 중복).
- [ ] **`rules/common/`에 배치** — 매 세션 로드(웹 작업에도 로드, 비권장).

### 3.2 P2에 직접 영향을 주는 기존 결정 (`programming-philosophy.md` §1)

| 결정 | 이 하네스에서 걸리는 지점 | 권장 |
|---|---|---|
| D01 기존 관례 vs 철학 | 하네스로 작업하는 대상이 회사 코드인지 개인 프로젝트인지 | 혼합 — **확정** |
| D03 C++ 에러 모델 | `rules/cpp/security.md`의 `.at()` 권고(예외 발생) vs 핫패스 예외 금지 | 경로 분리 |
| D05 불변식 위반 동작 | `rules/c/coding-style.md`의 "포인터 인자 NULL 체크 필수"(방어적) vs assert | 계층 분리 |
| D06 최적화 착수 | 핫패스 정의 위치가 없음 (`// HOTPATH` 주석 or 문서) | 경로 기반 + 위치 지정 |
| D16 C++ 표준 | `std::expected`(C++23) 권고 vs hooks `-std=c++17` | C++20 + expected는 조건부 — **확정**(C11 / C++20 / Rust 2024) |

나머지 D02·D04·D07~D15·D17은 `(기본)`을 그대로 적용해도 이 계획의 파일 변경에는 영향이 없다.

### 3.3 실행 방식

- [x] (권장) **단계별 PR** — P1 → P2 → P3 → P4 순서로 4개 PR. P1은 결정 없이 먼저 머지 가능.
- [ ] **단일 PR**
- 반영 경로: [x] 로컬 세션에서 브랜치 push → PR [ ] 패치 파일로 받아 직접 적용 — 결정일: 2026-10-05 / 사유: 입력 시트 7-2

---

## 4. 단계별 변경 명세

### P1. 사실 오류 수정 (결정 무관)

| # | 파일 | 현재 | 변경 |
|---|---|---|---|
| E1 | `rules/common/security.md` L32, `AGENTS.md` L86, `agents/code-reviewer.md` L103 | `strcpy` → `strncpy` | `strcpy` → `snprintf` 또는 길이 검사 후 `memcpy` + 명시적 NUL 종료. `strncpy`는 NUL 미보장·0 패딩 비용 명시 |
| E2 | `rules/c/security.md` L18 | `strncpy` + 수동 종료 GOOD 예시 | `snprintf(buf, sizeof(buf), "%s", in)`를 1순위로, `strncpy` 예시는 삭제 또는 "레거시 호환" 주석 |
| E3 | `skills/rust-patterns/SKILL.md` Lock-free 절 | `crossbeam::channel::bounded`를 "SPSC 링버퍼(최고 성능)"로 소개 | MPMC 채널임을 명시. SPSC가 필요하면 전용 SPSC 크레이트 또는 직접 구현(`rules/systems` 동시성 절 참조) |
| E4 | `rules/rust/patterns.md` 저지연 절, `skills/rust-patterns` | 핫패스 조건문에 `likely`/`unlikely` 힌트 | 안정 채널에서는 `#[cold]`로 콜드 경로 표시. 분기 힌트는 측정 근거가 있을 때만 (D06) |
| E5 | `rules/rust/patterns.md` RAII 절 `FeedGuard` | `unsafe { libc::close(..) }`, SAFETY 주석 없음 | `std::os::fd::OwnedFd` 사용 예로 교체. unsafe가 남으면 `// SAFETY:` 논증 추가 |
| E6 | `skills/cpp-patterns/SKILL.md` CP.100 | "`latency-critical-systems` 참조" — 해당 스킬에 lock-free 내용 없음 | P4(D22)에서 재작성된 스킬 절로 링크 갱신. P1에서는 참조를 `rules/systems/philosophy.md` 동시성 절 예정으로 표기 |
| E7 | `rules/cpp/patterns.md` RAII 예제 | 멤버 `file_` (규칙은 `m_snake_case`) | 규칙과 일치하도록 `m_file`로 수정 |
| E8 | `rules/c/coding-style.md` 에러 처리 예제 `OpenFile` | 미사용 `ret`, `perror` 후 -1 반환 | 미사용 변수 제거, 에러 시 `-errno` 반환 관례 또는 호출자에 errno 보존 명시 |
| E9 | `skills/trading-systems/SKILL.md` 핫패스 표 | 락 대신 "스핀락" 권고 | 유저스페이스 스핀락의 선점 위험 명시, 단일 작성자·SPSC 큐 우선으로 수정 (CP.100과 정합) |

**P1 완료 기준**: `grep -rn "strcpy.*→.*strncpy\|→ \`strncpy\`" rules agents AGENTS.md` 0건,
`crossbeam::channel::bounded` 주석에 "SPSC" 0건.

### P2. 규칙 충돌 해소 (D18~D21, D03, D05, D16 의존)

**D18 — 불변성 (권장안 기준)**

| 파일 | 변경 |
|---|---|
| `rules/common/patterns.md` "불변성(매우 중요)" 절 | 삭제. 대신 "공유 가변 상태 최소화, 가변 상태에는 소유자 하나" 한 문단(언어 중립) |
| `rules/javascript/patterns.md`, `rules/python/patterns.md` | 기존 불변성 원문을 이동 (spread·map·filter 예시 포함) |
| `AGENTS.md` L69 | 동일 문장으로 교체 (SSOT 동기화) |
| `agents/code-reviewer.md` L137 "변이 패턴" | "JS/TS·Python 한정"으로 범위 명시. 시스템 언어용 항목 "소유 불명확한 가변 상태 공유"로 대체 |
| `agents/code-reviewer.md` L266·L268 | 불변성 참조를 언어별 규칙으로 갱신 |

**D19·D20 — 네이밍·헤더 (권장안 기준)**

| 파일 | 변경 |
|---|---|
| `rules/common/coding-style.md` | `ii` 규칙 → "이름 길이는 스코프에 비례, 루프 인덱스 `i`/`j` 허용". 헤더 필드에서 `DATA`/`Modification` 삭제. 함수 헤더 적용 범위를 공개 API·비자명 함수로 한정 |
| `rules/c/coding-style.md`, `rules/c/patterns.md`, `rules/c/testing.md` | `_t` 접미사 예시 전부 교체 (`Conn_t` → `Conn` 등, D19-a). 헤더 예시 날짜 필드 삭제 |
| `rules/cpp/coding-style.md` | 헤더 예시 동일 조정 |
| `rules/rust/coding-style.md` | `/*###*/` 헤더 → `//!`·`///`. `ii` 규칙 삭제. 네이밍은 Rust API Guidelines |
| `AGENTS.md` L49·L54 | 네이밍 표와 단일 문자 규칙 동기화 |
| `tests/check_convention_sync.sh` | SYNC_GROUPS 토큰 유지 여부 확인. `PascalCase`·`g_SnakeCase`는 C/C++ 유지(권장안)면 그대로 통과. 전 언어 관용(D19 B안)이면 토큰 목록 갱신 필요 |
| `tests/check_convention_sync.sh`의 기존 헤더 | 하네스 자체 bash 스크립트 헤더에도 D20 적용 여부 결정 (권장: 스크립트는 현행 유지, 신규부터 적용 — D01) |

**D21 — 테스트 강제**: `rules/common/testing.md`, `rules/common/development-workflow.md` §2,
`AGENTS.md` TDD 절, `agents/tdd.md`의 "80% 필수" 문구를 D21 결과로 조정.

**D03·D16 — C++ 정합**

| 파일 | 변경 |
|---|---|
| `rules/cpp/security.md` "`.at()` 사용" | "경계 검사: 비핫패스는 `.at()` 허용, 핫패스는 사전 검증 후 `operator[]` 또는 `std::span` + assert" |
| `rules/cpp/patterns.md` 에러 처리 | D03 결과 반영 (경로 분리 시 `noexcept` 핫패스 규칙 추가) |
| `rules/cpp/hooks.md` `-std=c++17` | D16 결과로 통일. C++20 선택 시 `std::expected`는 "C++23 또는 `tl::expected` 대체" 조건부 표기 |

**D05 — 방어적 NULL 체크**: `rules/c/coding-style.md` "포인터 인자 NULL 체크 필수"를
"외부 경계(공개 API·외부 입력)는 검사, 내부 불변식은 assert" 로 조정.

### P3. 철학 본문 이식 (D23 권장안 기준)

| 파일 | 작업 |
|---|---|
| `rules/systems/philosophy.md` (신규) | `programming-philosophy.md` §2~§11의 `[공통]`·`[Linux/시스템]` 항목 + §12 압축본. frontmatter paths는 D23 목록. P2에서 정리된 하우스 스타일과 충돌하는 문장은 제거(예: 스타일 장의 포매팅은 기존 language coding-style을 정본으로 참조) |
| `rules/systems/decisions.md` (신규) | §1 결정 레지스터(D01~D23) 선택 완료본 + 결정일·사유 |
| `rules/c/patterns.md` | 철학 `[Linux/C]` 항목 병합: EINTR·부분 I/O, 음수 errno, goto 단일 정리 경로(기존과 통합) |
| `rules/cpp/patterns.md` | `[C/C++]` 항목 병합: 소유권 타입 표현, 핫패스 `noexcept`, 메모리 모델, `volatile` 금지 |
| `rules/rust/patterns.md` | `[Rust]` 항목 병합: 시그니처로 소유권, `clone()` 설계 신호, `Arc<Mutex>` 확산 경고, async 블로킹 금지 |
| `rules/common/agents.md` "서브에이전트 규칙 도달 범위" | 위임 시 재기술 대상에 "`rules/systems/philosophy.md` §12 압축본 + 확정 결정 목록" 추가 |
| `rules/README.md` | 자동 활성화 표에 `rules/systems/*` 행 추가 |
| `CLAUDE.md` Architecture 트리 | `systems/` 추가 (`tests/check_index.sh` 검사 4 요구) |
| `AGENTS.md` | 다이제스트 1~2줄만 추가("시스템 언어 작업 시 `rules/systems/` 참조"). 본문은 복제하지 않음 |

**주의**: paths 규칙은 매칭 파일을 다룰 때만 로드되므로, 코드를 아직 열지 않은 설계 단계
(`planner`)에서는 철학이 컨텍스트에 없다. `agents/planner.md`에 "시스템 언어 설계 시
`rules/systems/philosophy.md`를 먼저 Read" 한 줄을 추가한다.

### P4. 공백 보강 (에이전트·스킬)

| 대상 | 작업 | 철학 장 |
|---|---|---|
| `agents/debugger.md` 진단 절차 | 4단계를 "재현 확보 → 최근 변경 의심(`git log`/`git bisect`) → 가설·관찰 증거 분리 기록 → 최소 수정 → 재현 테스트로 고정 → 유사 패턴 검색"으로 확장. 증상표에 TSan 1차, `rr` 추가 | 5장 |
| `agents/code-reviewer.md` 시스템 프로그래밍 절 | 부분 읽기·쓰기, 원자적 연산 오더링 근거 주석, 락 잡은 채 I/O·콜백, 핫패스 할당·예외·숨은 복사, 공개 동작 변경(호환성) 항목 추가 | 4·7·10장 |
| `skills/latency-critical-systems/SKILL.md` | D22 결과대로 분리 또는 보강. 핫패스 내용: 캐시라인 정렬·거짓 공유, 단일 작성자, 코어 고정·busy-poll, 사전 할당, p99/p99.9 측정 조건 | 7·10장 |
| `rules/c/testing.md`, `rules/cpp/testing.md` | libFuzzer 퍼징(외부 입력 파서 필수), 차분 테스트, 장애 주입(부분 쓰기·EINTR) | 6장 |
| `skills/trading-systems/SKILL.md` | 표기법 절: FIX/SBE 스키마 기반 코드 생성, 생성물 커밋 정책 | 9장 |
| `rules/common/performance.md` | 파일명과 내용 불일치(LLM 컨텍스트 관리). 개명 여부는 선택 — 개명 시 `context.md`, 인덱스·링크 갱신 필요. **이번 계획에서는 상단에 "코드 성능은 `rules/systems/philosophy.md` 8장" 한 줄만 추가** | 7장 |
| `docs/decisions/0005-programming-philosophy.md` (신규) | D18~D23 및 핵심 결정 기록 | — |
| 스킬 개수 표기 | D22 분리 시 스킬 47→48. `tests/check_index.sh` 검사 6이 README·CLAUDE.md·AGENTS.md·docs 개수 표기를 확인하므로 전부 갱신 | — |

### P5. 검증

**6.1 자동 테스트**
- `bash tests/check_convention_sync.sh`, `bash tests/check_index.sh`
- `bats tests/*.bats` 전체 (특히 `skill_meta.bats`, `smoke.bats`)
- 링크 해소: `check_index.sh` 검사 7

**6.2 정적 grep 감사 (0건이어야 함)**
- 시스템 언어 규칙 내 불변성 절대 표현: `grep -rn "절대 변경" rules/{common,c,cpp,rust,systems}`
- `strncpy` 권고: P1 완료 기준 참조
- `_t` 예시 (D19-a 폐지 시): `grep -rnE "[A-Z][A-Za-z]+_t\b" rules/c rules/cpp`
- 헤더 날짜 필드 (D20 축소 시): `grep -rn "Modification:" rules/`

**6.3 행동 검증 (실제 세션)**
1. 새 세션에서 C 파일을 열고 epoll 에코 서버의 부분 쓰기 처리를 작성시킨다 →
   EINTR·EAGAIN·부분 쓰기가 반영되는지, `_t`·`ii`가 D19대로 적용되는지 확인.
2. Rust 사전 할당 링버퍼에 `&mut self`로 제자리 쓰는 코드를 `code-reviewer`로 리뷰 →
   "변이 패턴" HIGH가 나오지 않아야 한다.
3. `planner`에 C++ 핫패스 설계를 맡긴다 → 철학 파일을 Read하는지, D03·D06 결정이 반영되는지 확인.
4. `Explore` 위임 시 §12 압축본이 프롬프트에 재기술되는지 확인.

**6.4 컨텍스트 비용**
- 변경 전후 `wc -c rules/common/*.md` 비교 — 증가 없음이 목표(D18 삭제로 오히려 감소 예상).
- `rules/systems/*.md` 합계는 20KB 이하 목표. 초과 시 §12 압축본만 남기고 본문을 스킬로 이동.

---

## 5. 리스크

| 리스크 | 영향 | 대응 |
|---|---|---|
| 네이밍 변경(D19)이 기존 회사 코드 관례와 어긋남 | 하네스가 기존 코드와 다른 스타일을 생성 | D01 "혼합" — 기존 파일은 기존 관례 우선 |
| AGENTS.md와 rules 드리프트 | Codex/Gemini/Copilot이 구 규칙을 봄 | P2·P3마다 `check_convention_sync.sh` 토큰 갱신 |
| paths 규칙이 설계 단계에 미로드 | planner가 철학 없이 설계 | P3 주의 항목(planner Read 지시) |
| 규칙 증가로 컨텍스트 비용 상승 | 응답 품질·속도 저하 | 6.4 용량 목표, common에는 추가하지 않음 |
| 문서 개수 표기 불일치 | CI 실패 | P4 스킬 개수 갱신 체크 |

## 6. 로드맵 연동 개정 (2026-10-05)

이 계획은 `2026-10-05-arachne-roadmap.md`의 트랙 A로 편입됐다. 실행 순서는 로드맵 §4 웨이브를
따르고(P1=W1, P2=W2, P3=W3, P4=W4, P5=W5), 아래 개정을 함께 적용한다.

| # | 대상 | 개정 |
|---|---|---|
| R1 | 철학 D08 | 서버 티어에 한해 "리눅스 전용 허용(격리 필수)". 클라이언트는 런타임 이식성에 위임 |
| R2 | P2 D18 | `rules/javascript`로 옮기는 불변성 원칙에 핫패스 예외(링버퍼·TypedArray·객체 풀 재사용) 명시. C 공유메모리 제자리 갱신은 시스템 규칙에서 정상 패턴 |
| R3 | P4 D22 | 분리된 핫패스 스킬 ↔ `stream-pipeline-patterns`(처리량·흐름 제어) ↔ `shm-db-patterns`(공유 상태·영속) 역할 경계 명시 |
| R4 | P4 `code-reviewer` | 로드맵 B-3·B-4b·F·I 체크 항목과 같은 PR |
| R5 | 착수 프롬프트 | 문서 위치는 로드맵 D-15 결과를 따른다 |
| R6 | P4 스킬 개수 | 각 PR은 자기 증가분만 반영, 최종 일괄 갱신은 로드맵 Z |
| R7 | D01·D19 | C 캡슐화·다형성 표준 패턴 = 불투명 핸들 + 함수 포인터 인터페이스. 약어는 프로젝트 사전(로드맵 I-5) 기준 |
| R8 | D16 | C11 / C++20 / Rust 2024 확정 (입력 시트 3-4 미입력, 가정) |

**task 분해 방식 변경**: 착수 프롬프트 P0의 "P1~P4를 task 문서 4개로 분해"는 로드맵 웨이브 단위 task
문서(`docs/task/2026-10-05-roadmap-w1.md` ~ `-w7.md`)로 대체한다. 각 웨이브 task가 해당 철학 단계를 포함한다.

## 개정 로그

| 날짜 | 요약 |
|---|---|
| 2026-09-29 | 초안 — 2026-09-29 평가(도구층 양호, 원칙층 충돌·오류·공백) 기반 |
| 2026-10-05 | P0 — 결정 D01~D23·실행 방식 확정, 줄 번호 HEAD(`d6e260d`) 유효 확인(표본 7곳), 로드맵 연동 개정 R1~R8(§6), task 분해를 웨이브 단위로 변경 |
