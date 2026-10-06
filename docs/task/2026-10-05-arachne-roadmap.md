---
Title: "[plan] Arachne 보강 로드맵 — C 시스템·임베디드 SQL·대용량 데이터·보안·정리 (2026 Q4)"
creation: 2026-10-05
modification: 2026-10-05
status: "in progress"
tags:
 - "arachne"
 - "plan"
 - "roadmap"
aliases:
 - "arachne-roadmap"
---
MOC:: [[Arachne]]
FROM:: [[2026-09-13-arachne-audit]]

# [plan] Arachne 보강 로드맵 (2026 Q4)

> 살아있는 정본 1개. 2026-10-05 이후 모든 보강 작업의 **순서와 범위의 정본**이다.
> 전제 사실 §1.4, 결정 §3, 실행 순서 §4, 트랙별 상세 §5.
> 철학 이식은 기존 `2026-09-29-programming-philosophy-integration.md`(이하 "철학 계획")를 그대로
> 쓰되 §3.2 개정 사항만 반영한다. 입력은 `2026-10-05-roadmap-input-sheet.md`.
>
> **작성 원칙**: 모든 규칙·스킬·에이전트·도구는 Arachne 규약(한글 본문, `SKILL.md` 형식, 헤더,
> 방어 기준선 4항, paths 지연 로드)과 대상 스택에 맞춰 작성하며, 예시 코드는 이 하네스의 하우스
> 스타일(PascalCase 함수, `g_` 전역, `m_` 멤버 등)로 새로 쓴다.
>
> **공용·프로젝트 분리 원칙**: 하네스(공용)에는 **방법·판단 기준·도구 골격**을 둔다. 실제 값
> (약어 사전 항목, 공유메모리 레이아웃·키, 테이블 매핑, 운영 절차 세부)은 **프로젝트가 소유**하며
> `c-system` 프로필(§5.I-6)이 그 자리를 만들어 준다.

- **상태**: in progress — W0~W5 완료(PR #54까지), W6 최종 정리 진행 중 (2026-10-06)
- **기준 커밋**: `d6e260d` (2026-09-13)
- **입력 문서**: [[2026-09-13-arachne-audit]], [[2026-09-29-programming-philosophy-integration]], [[2026-09-29-programming-philosophy]], [[2026-10-05-roadmap-input-sheet]]

---

## 1. 배경과 목표

### 1.1 대상 시스템

```
[클라이언트]  웹(TS/React) · 데스크톱(TS/Electron) — Windows / macOS   (C#은 D-02, 현재 가정: TS)
      │  REST/JSON · 바이너리 스트림(TCP) · (필요 시) gRPC
[서버]        C 주력 (C++ 사상을 C 문법으로: 불투명 핸들·함수 포인터 인터페이스) — Linux
              Rust는 C 모듈의 점진 이식 대상
      │  공유메모리(실시간 데이터) ⇄ Pro*C / ecpg 임베디드 SQL (영속)
[DB]          Oracle · PostgreSQL (최신 안정 버전) — 스키마는 개별 .sql 파일로 정의
```

### 1.2 현재 상태 (2026-10-05 조사)

| 영역 | 상태 | 핵심 공백 |
|---|---|---|
| 2026-09-13 감사 | 제안 1~5 적용 완료 | `skills:` 프리로드 재평가, Q1 미검증(서브에이전트 paths 규칙 지연 로드) |
| 원칙 층 | 철학 계획 대기 | 불변성 절대 원칙 충돌, `strncpy` 등 사실 오류, 동시성·성능 철학 공백 |
| C 시스템 | 불투명 포인터·POSIX·소켓 규칙 있음 | 함수 포인터 인터페이스(다형성) 0, 서버 구조 스킬 없음, C→Rust 이식 지침 0 |
| **임베디드 SQL** | `embedded-sql` 302줄 — 호스트·인디케이터 변수, WHENEVER, 커서, 트랜잭션, 바인딩 동적 SQL, 빌드, 이식 | **`.pc`·`.pgc` 편집 시 C 규칙 미로드**(paths 없음), **Pro*C 리뷰어 0**, **호스트 배열(대량 fetch·insert) 0**, **멀티스레드 런타임 컨텍스트 0**, 재접속 0 |
| **데이터 계층** | — | **공유메모리 0, 메모리 복구·조회 도구 0, 자료구조·정렬 선택 지침 0(bsearch·해시 0)** |
| **네이밍** | 공통 규칙(PascalCase·`g_`·30자) | **약어·용어 사전 0, 통일성 검증 도구 0** |
| **운영 로그** | 공통 규칙에 `[DEBUG]`·`[프로젝트명]` 출력 prefix만, C는 포맷 스트링 예시 1건 | **로그 레벨 기준·형식·출력 대상·회전·핫패스 성능·폭주 억제·개인정보 마스킹·추적 도구 전부 0** |
| 대용량 데이터 처리 | `data-throughput-accelerator` 41줄(일반론) | 처리량 모델, 백프레셔, 순서·중복·유실 보장, DB 대량 적재, 클라이언트 대용량 수신 전부 0 |
| DB 운영 | Alembic(Python) 전용 마이그레이션·리뷰어 | `.sql` 버전 관리 규약 0, Oracle SQL 튜닝(실행 계획 증거) 0 |
| 웹/TS | 규칙·react-reviewer·Playwright 양호 | TS 리뷰어 없음, React·웹 보안 규칙 없음, Electron 0 |
| 런타임 분석 | perf·flamegraph 언급 | 원격·오프라인 서버 분석 절차 0, 부하 테스트 0, 분산 추적 0 |
| 보안 | 공통·C·C++ 보안 규칙, security-review·scan, code-reviewer 9항 | **강제 장치 0**: PreToolUse 훅 0, `permissions.deny` 0 |
| 민감정보·개인정보 | Python·Java 규칙에만 존재 | `.env`·키 파일을 모델이 읽을 수 있음, 개인정보 커밋 탐지 0, **C 개인정보·비밀번호 해시 규칙 0**, git 이력 점검 이력 없음 |
| 하네스 무결성 | 스킬 형식 검사만 | agents·commands frontmatter, 개인 경로, 숨은 유니코드 검사 없음. 스킬 예시 SQL `$1` 치환 위험 3건 |
| 문서 위생 | — | 깨진 참조(`docs/plan`), 제거된 런타임 현재형 서술, status 표류 4건, 루트 기록물, 하위 폴더 배치 이탈 |

### 1.3 성공 기준

1. C 서버 + 임베디드 SQL + 공유메모리 구조를 **설계·구현·운영(복구·조회)·리뷰**할 수 있는 규칙·스킬·
   도구 골격이 있다.
2. `.pc`·`.pgc` 편집 시 C 규칙이 로드되고, Pro*C·ecpg 코드가 리뷰 대상이 된다.
3. 프로젝트 약어 사전을 기준으로 식별자의 **미등록 약어·동의어 혼용·금지어·길이**를 자동 보고한다.
3-1. 프로그램 동작 로그가 일관된 레벨·형식으로 남고, 핫패스 성능을 해치지 않으며, 거래·요청 ID로
   프로세스를 넘나들어 추적할 수 있고, 개인정보는 로그에 남지 않는다.
4. 대용량 데이터를 서버·DB·클라이언트 전 구간에서 설계·측정할 수 있고, PoC로 처리량·p99·메모리를
   재현 측정한다.
5. 파괴 명령·검사 우회·비밀값·개인정보 커밋이 훅으로 결정적으로 차단·확인되고, 비밀 파일이 모델
   컨텍스트로 읽히지 않는다. 개인정보는 로그·덤프·조회 도구 출력에서 기본 마스킹된다.
6. 시스템 언어 파일 작업 시 로드되는 규칙 사이 상충 지시 0건 (철학 계획 기준).
7. `rules/common`(매 세션 로드) 용량 증가 0.
8. 최종 정리 후 깨진 참조·status 표류·출처 불명 파일 0건, 모든 개수 표기 일치.
9. 기존 CI 전체 통과 + 신규 검사 편입.

### 1.4 전제 사실 (입력 시트 2026-10-05)

| 항목 | 내용 | 영향 |
|---|---|---|
| 서버 언어 | **C 주력.** C++의 사상(캡슐화 등)을 C 문법으로 구현해 C의 약점 보완. C 코드를 Rust로 옮길 수 있는지 검토 희망 | D-06, E-1, I 트랙, 철학 R7 |
| DB 개발 방식 | **Pro*C·ecpg 임베디드 SQL 주력**, 기존 코드 있음. 최신 안정 버전 | D-07, E-2 |
| 스키마 관리 | 마이그레이션 도구 없음, 테이블·스키마를 **개별 `.sql` 파일**로 정의, 개발 측이 직접 변경 | D-08 |
| 원격 접속 | 개발·운영 서버 모두 ssh 가능 | D-09, E-4 |
| 프로파일링 | **개발·스테이징만 허용**(운영 금지) | E-4 |
| Docker | 로컬 사용 가능 | D-09, E-4 |
| 원격 Claude Code | 설치 가능, **단 인터넷 없는 서버는 미설치** | E-4 오프라인 절차 |
| 개인정보 | 주민등록번호·카드번호·계좌번호·연락처·고객 식별자·**비밀번호** | B-4 |
| 반영 방식 | 단계별 브랜치 → PR | §4 |
| 미입력(가정) | 대용량 수치(1.1), C# 필요 조건(1.2), C++ 표준·빌드·배포판(3-4~3-6), 회사/개인 코드 구분(3-3) | 가정으로 진행, 입력 시 갱신 — 대용량 PoC는 수치를 파라미터로 받음 |

---

## 2. 트랙 구성

| 트랙 | 이름 | 범위 요약 | 상세 |
|---|---|---|---|
| **A** | 철학 이식 | 철학 계획 P0~P5 (+ §3.2 개정) | 철학 계획 |
| **B** | 보안 | 실행 시점 훅, 보안 규칙, 리뷰 보안 항목, 고위험 작업 안전장치, 민감정보·개인정보 보호 | §5.B |
| **C** | TS·웹·데스크톱 클라이언트 | TS 리뷰어, React 규칙, 테스트·빌드 스킬, Electron | §5.C |
| **D** | 대용량 데이터 처리 구조 | 처리량 원칙 허브, 서버 파이프라인, DB 대량 경로, 클라이언트 수신, 스트림 계약, PoC | §5.D |
| **E** | 3티어 스택 | C 서버 구조·C→Rust 이식, 임베디드 SQL 보강·`.sql` 버전 규약, 계약, 원격·오프라인 분석, (조건부) C# | §5.E |
| **F** | 시스템 언어 리뷰 | Rust 리뷰어, 빌드 실패 절차, 삼켜진 에러·주석 표류·무상한 버퍼 | §5.F |
| **G** | 감사 후속 | Q1 실측, `skills:` 프리로드 | §5.G |
| **H** | 하네스 무결성 | 메타 검사, 자리표시자 버그, 크기 경고 | §5.H |
| **I** | **C 시스템 데이터 계층** | 자료구조·정렬 기반 수신 저장소, 공유메모리 ⇄ DB, 메모리 컨트롤·복구 도구, 메모리 조회 도구, 네이밍 사전·검증, **운영 로그**, `c-system` 프로필 | §5.I |
| **Z** | 최종 정리 | 문서·스크립트·지시 파일 인벤토리·최신화·배치 | §5.Z |

---

## 3. 결정 사항

형식: `[x]` + 결정일·근거. 전 결정은 2026-10-05 W0에서 확정됐다(입력 시트 근거 또는 권장안 적용).
결정 요약과 대안·결과는 ADR-0006, 철학 결정은 ADR-0005.

### 3.1 결정

**D-01. 철학 계획 결정 일괄** — D01~D23
- [x] (권장) 권장·기본안 일괄 채택 + §3.2 개정 반영
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-02. 데스크톱 클라이언트 언어** — *확정: TS (2026-10-05 PoC)*
- [x] (권장) **TS(Electron)로 통일, C# 제외** — 서버가 원천 연결을 맡는 구조에서 Node TCP 직접 수신·
  바이너리 디코딩·프레임 단위 묶음 전달로 수신 성능이 충분하다. **W3 PoC(§5.D-6)로 최종 확인**,
  미달 시 C# 트랙(§5.E-5) 활성화. 입력 시트 1.2 중 하나라도 "예"면 재검토.
- [ ] C#(Avalonia) 병행
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
- 확정: 2026-10-05 W3 PoC — Node 수신기가 초당 1만·10만·100만 건에서 목표 100%·유실 0·p99 ≤ 242µs, 포화는 초당 1,000만~2,000만 건 사이([결과](../issue/2026-10-05-throughput-poc-result.md)). 재개 조건: 실제 두 호스트 네트워크에서 요구 레이트의 2배 미달, Windows 대상 하드웨어에서 p99 > 10ms, 실제 디코딩·상태 갱신을 포함한 utility process가 요구 레이트에서 CPU 100%
**D-03. 서버 ↔ 클라이언트 프로토콜**
- [x] (권장) **요청·응답은 REST/JSON, 대용량 스트림은 바이너리 프레이밍(TCP)**, gRPC는 필요 시만 —
  C 서버 주력이므로 gRPC 의존을 기본값으로 두지 않는다.
- [ ] gRPC 포함 · [ ] REST/JSON 단일
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-04. 대용량 스트림 직렬화 형식**
- [x] (권장) **고정 레이아웃 바이너리(C 구조체 정의 정본 + 명시적 엔디언·패딩)** — C 서버에서 할당·변환
  없이 송신, 클라이언트는 `DataView`로 직접 해석.
- [ ] FlatBuffers · [ ] JSON(소량 한정)
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-05. 메시지 브로커**
- [x] (권장) **비범위** — 서버 직접 스트리밍 + 공유메모리. 스킬에는 도입 판단 기준만.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-06. 서버 구조**
- [x] **C 자체 epoll 이벤트 루프 + 불투명 핸들·함수 포인터 인터페이스** (`rules/systems` 기반).
  Rust는 C 모듈의 점진 이식 대상(E-1b). C++·Rust 서비스 프레임워크 스킬은 이번 범위에서 제외.
  — 결정일: 2026-10-05 / 근거: 입력 시트 1.3 (C 주력)

**D-07. 서버의 DB 접근 경로**
- [x] **Pro*C(Oracle)·ecpg(PG) 임베디드 SQL 유지**가 기본. OCI·libpq 직접 사용은 임베디드 SQL로
  불가능한 경우(비동기·파이프라인 등)에만. Rust 이식 모듈의 DB 접근은 E-1b 판단 기준을 따른다.
  — 결정일: 2026-10-05 / 근거: 입력 시트 1.4 (기존 Pro*C·ecpg 자산, 임베디드 개발 주력)

**D-08. 스키마 변경 관리**
- [x] **도구 도입 없이 `.sql` 파일 유지 + 버전 명명 규약** — `V<번호>__<설명>.sql`(버전),
  `R__<설명>.sql`(반복 적용 객체: 뷰·프로시저), 적용 기록 테이블(`SCHEMA_HISTORY`: 버전·설명·체크섬·
  적용 시각·적용자), 방언 분리(`oracle/`·`postgres/`), 적용 스크립트(bash). 형식이 Flyway와 호환되어
  나중에 도구로 전환 가능. — 결정일: 2026-10-05 / 근거: 입력 시트 1.4 (도구 없음·수동 `.sql`)

**D-09. 개발·분석 환경**
- [x] **로컬 Docker + 원격 Linux ssh 병행.** 프로파일링은 **개발·스테이징만**. 인터넷이 있는 서버에는
  Claude Code 설치 가능, **인터넷 없는 서버는 수집 스크립트 실행 → 결과물 회수** 방식.
  — 결정일: 2026-10-05 / 근거: 입력 시트 1.5

**D-10. 파괴 명령 가드 강도**
- [x] (권장) **2단계** — 검사 우회(`--no-verify`, `-c core.hooksPath=`) deny. `DROP`/`TRUNCATE`,
  `git push --force`(`--force-with-lease` 허용), `git reset --hard`, 비임시 경로 `rm -rf`,
  `chmod 777`, **`ipcrm`(공유메모리 삭제)** ask.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-11. 비밀값 탐지 범위**
- [x] (권장) **`git commit` 시 staged diff** — 클라우드 액세스 키, API 키 접두 패턴, 개인키 헤더,
  `password=`, Oracle·PG 접속 문자열(Pro*C `CONNECT :user IDENTIFIED BY` 리터럴 포함).
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-12. 리뷰어 신설 범위**
- [x] (권장) **`typescript-reviewer`·`rust-reviewer` 신설, `database-reviewer`를 임베디드 SQL까지
  확장** — 리뷰어 8 → 10. C는 `code-reviewer` 시스템 절(철학 P4) + I 트랙 체크 항목.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-13. React 규칙 배치**
- [x] (권장) **`rules/react/` 신설**(paths `*.tsx`·`*.jsx`, 3파일 이하). 별도 `rules/typescript`는 만들지 않음.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-14. 서브에이전트 `skills:` 프리로드**
- [x] (권장) 3쌍만 (`tdd`↔`tdd-workflow`, `code-reviewer`↔`verification-loop`, `debugger`↔`memory-check`), +5k 토큰 초과 시 롤백
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-15. 문서 배치**
- [x] (권장) 감사 기록물 → `docs/issue/` · 루트 스크립트 이동 안 함 + README 역할 표 · task README를
  실제 운용(`[plan]`은 `docs/task/`)에 맞춤 · `docs/task/20261005/`는 입력 문서(철학 원문)를
  `docs/idea/`, `[plan]`·입력 시트는 `docs/task/` 평면으로
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-16. 감사 보류 항목 나머지** (신규 훅 이벤트, Gemini `context.fileName`)
- [x] (권장) 기각 유지
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-17. 비밀 파일의 모델 컨텍스트 유입 차단**
- [x] (권장) **`permissions.deny` + Bash 가드 병행**. Read 거부 목록:
  `**/.env`·`**/.env.*`(`.env.example` 허용), `**/*.pem`·`**/*.key`·`**/*.p12`·`**/*.pfx`,
  `**/id_rsa*`·`**/id_ed25519*`, `~/.ssh/**`, `~/.aws/**`, `**/secrets/**`, `**/*credentials*`,
  Oracle `**/wallet/**`·`**/tnsnames.ora`·`**/sqlnet.ora`, `~/.pgpass`, `~/.netrc`,
  `~/.docker/config.json`, 덤프·백업 `**/*.dmp`·`**/*.dump`·`**/export/**`·`**/backup/**`.
  `guard-bash.sh`에 같은 경로를 여는 명령(`cat`·`less`·`grep`·`cp` 등) ask.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-18. 개인정보·고객 데이터 커밋 탐지**
- [x] (권장) **검증식 기반 deny + 데이터 파일 ask** — 주민등록번호(형식+검증 자리)·카드번호(형식+Luhn)
  deny, 전화번호·이메일 다수 ask, 픽스처 경로 밖 데이터 파일(`*.csv`·`*.xlsx`·`*.parquet`·`*.sql` 덤프·
  `*.dmp`·`*.dump`) ask.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-19. git 이력 점검**
- [x] (권장) **W1에 1회 읽기 전용 스캔**, 위치만 보고(값 기록 금지), 교체는 사용자 수행.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-20. 신용정보·회사 정책 처리** (입력 시트 6-2·6-3 미입력 → 권장안)
- [x] (권장) 카드·계좌·주민번호를 다루므로 **신용정보에 해당한다고 보고 보수적으로 설계**. 회사 정책
  문서가 생기면 그 기준을 우선하고, 하네스에는 위치만 링크(내용 복사 금지).
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-21. 비밀값 보관 방식** (입력 시트 6-4 미입력 → 권장안)
- [x] (권장) 개발 Mac은 **OS 키체인**, 서버는 **권한 600 설정 파일 또는 환경변수**(프로세스 시작 시
  읽고 메모리에서 사용 후 소거), `.env`는 로컬 개발 전용(Claude 읽기 차단). 시크릿 매니저 도입 시 갱신.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-22. 네이밍 사전 운영** (I-5)
- [x] (권장) **하네스는 검사 도구·사전 형식·공통 기본 약어만, 프로젝트가 사전 본문 소유**
  (`.arachne/naming-dict.tsv`). 검사는 **보고(WARN)만**, 차단은 하지 않음. 신규·변경 식별자만 대상
  (기존 코드는 D01 기존 관례 우선 — 일괄 리네이밍 금지).
- [ ] 위반 시 CI 실패 · [ ] 하네스가 사전 본문까지 소유
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-23. 공유메모리 방식** (I-2)
- [x] (권장) **POSIX(`shm_open`+`mmap`) 기본, 기존 SysV(`shmget`) 자산은 유지** — 두 방식 모두 스킬에
  기술, 도구는 둘 다 지원. 프로세스 간 동기화는 **robust 프로세스 공유 뮤텍스**(소유 프로세스 사망
  감지·복구) 또는 **단일 작성자 + 시퀀스 락**(읽기 다수) 중 선택 기준 제시.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede
**D-24. 진행 방식** (입력 시트 7-x)
- [x] 단계별 브랜치 → PR — 결정일: 2026-10-05 / 근거: 입력 시트 7-2
- [x] (권장) 웨이브 하나씩 확인받고 진행
- [x] (권장) 우선순위: 1) 보안 강제(B-1·B-4a) 2) C·임베디드 SQL·데이터 계층(A P1~P2, E-2, I) 3) 대용량(D)
  — §4 웨이브 순서가 이미 이 우선순위를 따른다.
- 결정일: 2026-10-05 / 근거: 사용자 "바로 진행" 지시에 따라 권장안 적용(입력 시트 §2 미체크). 변경 시 ADR-0006을 supersede

### 3.2 철학 계획 개정 사항 (W0에서 철학 계획 문서에 반영)

| # | 대상 | 개정 |
|---|---|---|
| R1 | D08 이식성 범위 | 티어별 분리 — 서버는 "리눅스 전용 허용(격리 필수)", 클라이언트는 런타임 이식성에 위임 |
| R2 | P2 D18 불변성 이동 | `rules/javascript`로 옮길 때 핫패스 예외: "UI·도메인 상태는 불변, 대용량 수신·변환 핫패스의 링버퍼·TypedArray·객체 풀 재사용은 의도된 변이로 허용". C의 **공유메모리 제자리 갱신**도 시스템 규칙에서 정상 패턴으로 명시 |
| R3 | P4 `latency-critical-systems` 분리(D22) | 분리된 핫패스 스킬 ↔ D-2 `stream-pipeline-patterns`(처리량·흐름 제어) ↔ I-2 `shm-db-patterns`(공유 상태·영속) 역할 경계 명시 |
| R4 | P4 `code-reviewer` 시스템 절 | B-3·B-4b·F·I 체크 항목과 **같은 PR** |
| R5 | 착수 프롬프트 경로 | D-15 결과로 갱신 |
| R6 | 스킬 개수 | 최종 정리(Z)에서 일괄 갱신 |
| R7 | D01·D19 네이밍 | "C 주력, C++ 사상을 C 문법으로" 반영: **불투명 핸들 + 함수 포인터 인터페이스**를 C 캡슐화·다형성의 표준 패턴으로. 약어는 D-22 사전 기준. 기존 코드는 기존 관례 우선 |
| R8 | D16 언어 표준 | C 표준을 명시(권장 C11, 원자 연산·`_Static_assert` 사용 근거). 입력 3-4 미입력 → 가정 |

---

## 4. 실행 순서 (웨이브)

웨이브 안은 병렬 가능(`/worktree`), 웨이브 사이는 선행 PR 머지가 조건. **웨이브 하나씩 확인받고 진행.**

웨이브별 task 문서: [W1](2026-10-05-roadmap-w1.md) · [W2](2026-10-05-roadmap-w2.md) ·
[W3](2026-10-05-roadmap-w3.md) · [W4](2026-10-05-roadmap-w4.md) · [W5](2026-10-05-roadmap-w5.md) ·
[W6](2026-10-05-roadmap-w6.md) · [W7](2026-10-05-roadmap-w7.md)

**W0 결과 (2026-10-05)**: 결정 D-01~D-24 확정([ADR-0006](../decisions/0006-roadmap-2026q4.md)), 철학 결정
D01~D23 확정([ADR-0005](../decisions/0005-programming-philosophy.md)), 철학 계획 §6 연동 개정, 웨이브 task
분해, H-1 위생(`skills/synced/`는 Claude 앱 스킬 동기화 산출물로 확인 → `.gitignore` 등록).

| 웨이브 | 항목 | 비고 |
|---|---|---|
| **W0 결정·준비** | 미확정 결정 확정 · 철학 P0(ADR-0005) · §3.2 개정 · ADR-0006(로드맵 결정) · task 분해 · H-1 위생 | 규칙 파일 수정 없음 |
| **W1 보안 강제·기반** | **B-1 보안 훅 + B-4a 컨텍스트 차단·개인정보 탐지·이력 스캔** (최우선, 같은 PR) · 철학 P1 · H-2 자리표시자 · H-3 메타 검사 · G-1 Q1 실측 | 서로 파일 안 겹침 |
| **W2 C·임베디드 기반** | 철학 P2 · **E-2a 임베디드 SQL 기반(`.pc` paths·리뷰어·`.sql` 버전 규약)** · **I-5 네이밍 사전·검사** · B-2 · B-4b · C-1 | 철학 P2(D19 네이밍 확정) 머지 후 I-5 |
| **W3 데이터 계층·대용량** | 철학 P3(`rules/systems`) · **I-1 자료구조 · I-2 공유메모리⇄DB · E-2b 호스트 배열·멀티스레드 컨텍스트(=D-3) · I-7 운영 로그** · E-1 C 서버 구조·C→Rust · D-1 · D-2 · E-3/D-4 계약 · **D-6 PoC** | I-2·E-2b 같은 PR. D-6 결과로 D-02 확인 |
| **W4 운영 도구·클라이언트·리뷰** | **I-3 메모리 컨트롤·복구 · I-4 메모리 조회 · I-6 `c-system` 프로필** · 철학 P4 + B-3 + F + I 리뷰 항목(같은 PR) · C-2 · D-5 · E-4 · G-2 · (조건부) E-5 | |
| **W5 통합 검증** | 철학 P5 · 전 트랙 행동 검증(§6) | 수정 없음 |
| **W6 최종 정리** | Z 전체 | 모든 기능 변경 머지 후 |
| **W7 최종 검증** | 자동 검사 전체 + 새 세션 스모크 + 인벤토리 기준선 확정 | |

---

## 5. 트랙별 변경 명세

### A. 철학 이식
철학 계획 §4(P1~P5) 그대로. 개정은 §3.2. 웨이브 배치는 §4.

### B. 보안

**B-1. 실행 시점 보안 훅** (bash, PreToolUse `Bash` 매처, W1)

| 파일 | 작업 |
|---|---|
| `hooks/guard-bash.sh` (신규) | D-10·D-17 판별. 인자 토큰화 후 판정(문자열 안의 `DROP` 오탐 금지), `--force-with-lease` 예외. 출력은 공식 문서의 PreToolUse 결정 JSON 형식 확인 후 작성 |
| `hooks/guard-secrets.sh` (신규) | D-11·D-18. `git commit` 감지 시 `git diff --cached` 스캔. 패턴은 상단 상수 배열, 오탐 허용 목록(픽스처 경로·합성 데이터 표식) |
| `settings.template.json` | PreToolUse 등록, timeout, D-17 `permissions.deny`. `install.sh`가 전역 설정에 반영하는지 확인 |
| `.gitignore` | `.env*`(예시 제외), 키 파일, 덤프 확장자 |
| `tests/guard_hooks.bats` (신규) | 차단·허용 케이스(검증식 통과/불통과 쌍, 픽스처 경로, force-with-lease, `ipcrm`) |
| `rules/common/hooks.md`, `CLAUDE.md` 트리, `docs/ARCHITECTURE.md` | 훅 목록. "가드는 실수 방지용, 보안 경계는 권한 설정" 명시 |

**B-2. 보안 규칙** (W2)

| 파일 | 작업 |
|---|---|
| `rules/web/security.md` (신규, paths) | nonce CSP, 보안 헤더, SRI·서드파티 스크립트 통제 |
| `rules/javascript/security.md` | prototype pollution, 소스맵 비공개, SSR 인젝션, 서드파티 컴포넌트 감사 |
| `rules/rust/security.md` | 바인드 파라미터, newtype 경계 파싱, 외부 응답 에러 일반화. `// SAFETY:`는 철학 P1-E5와 한 번만 |

**B-3. 리뷰·스킬 보안** (W4, 철학 P4와 같은 PR)

| 파일 | 작업 |
|---|---|
| `agents/code-reviewer.md` 보안 절 | 셸 인자 주입, SSRF, **확인-갱신 경합(TOCTOU → `SELECT … FOR UPDATE`·낙관적 버전, Pro*C 포함)**, XXE, 역직렬화, 오탐 기준 |
| `skills/security-review/SKILL.md` | 보안 자동 테스트 절(401/403/400/429), 자리표시자 수정(H-2) |
| `skills/security-scan/SKILL.md` | 숨은 유니코드·bidi 스캔, 설정 파일 자격증명 감사, 외부 링크·명령 가드레일 |
| `skills/trading-systems/SKILL.md` | 고위험 자동 작업 안전장치: 독립 하드 한도, 실행 전 사전 검증, 서킷 브레이커·킬스위치, 전 결정 감사 로그, 입력 오류 한도 |

**B-4. 민감정보·개인정보 보호**

> 대상: 비밀값(키·비밀번호·토큰·DB 접속 정보)과 개인정보(주민등록번호·카드·계좌번호·연락처·고객
> 식별자). 법적 요건 해석은 담당 부서 확인 사항(D-20), 하네스는 기술적 통제만 다룬다.

B-4a. 유입·유출 차단 (W1, B-1과 같은 PR) — D-17·D-18·D-19 구현, 이력 스캔 결과는 위치만 기록한 issue 문서.

B-4b. 처리 규칙·스킬 (W2)

| 파일 | 작업 |
|---|---|
| `skills/sensitive-data-handling/SKILL.md` (신규) | ① 최소 수집·보존·파기 ② 로그·에러·크래시·**코어 덤프** 마스킹(필드 단위) ③ 저장 시 보호(Oracle 컬럼 암호화·TDE, PG `pgcrypto`, 키는 코드·DB 밖) ④ **비밀번호는 저장하지 않고 해시만**(argon2id — C는 libsodium `crypto_pwhash`, 비교는 상수 시간) ⑤ 전송 TLS ⑥ **테스트·개발은 합성 데이터만**, 운영 덤프 반출 금지 ⑦ **공유메모리 내 개인정보: 최소 필드만 적재, 조회 도구 기본 마스킹(I-4)** ⑧ 클라이언트 저장(Electron `safeStorage`·키체인) ⑨ 외부 서비스 전송 금지 ⑩ DB 마스킹 뷰·권한 분리 |
| `rules/c/security.md`, `rules/cpp/security.md`, `rules/rust/security.md`, `rules/javascript/security.md`, `rules/electron/security.md` | 각 1~3줄: 로그 마스킹 방식, 비밀값 메모리 소거(C `explicit_bzero`, Rust `zeroize`), 스킬 링크 |
| `skills/embedded-sql/SKILL.md` 보안 체크 | 호스트 변수 비밀번호 사용 후 소거, `CONNECT` 자격증명 하드코딩 금지, SQL 트레이스 로그의 바인드 값 노출 주의 |
| `rules/common/security.md` | **용량 중립 치환**: "에러 메시지에 민감 정보 미포함" → "로그·에러·덤프·외부 전송·하네스 문서에 비밀값·개인정보 미포함(→ `sensitive-data-handling`)" |
| 리뷰어 | 개인정보 로깅·평문 비밀번호·외부 전송 항목(code·typescript·rust·database 리뷰어, B-3·F·E-2와 같은 PR) |
| `commands/save-session.md`, `commands/handoff.md` | 요약에 비밀값·개인정보 원문 금지 한 줄 |
| `tests/check_sensitive_text.sh` | H-3 개인 경로 검사를 확장: 추적 문서(세션 요약·handoff·issue 포함)의 비밀값·개인정보 패턴 |

### C. TS·웹·데스크톱 클라이언트

**C-1. TS·React** (W2)

| 파일 | 작업 |
|---|---|
| `agents/typescript-reviewer.md` (신규, 읽기 전용) | async 정확성, `!`·`as`·`any` 남용, tsconfig 엄격도 약화, Node `child_process`·경로 순회, 공개 API 반환 타입, 불가능한 상태를 타입으로 차단(branded 수치 타입·판별 유니온), react-reviewer 분담표, 방어 기준선 |
| `commands/ts-review.md` (신규) | `/react-review` 형식 |
| `rules/javascript/coding-style.md` | 공개 API 반환 타입, `Readonly<T>`, R2 핫패스 예외 |
| `rules/react/` (신규) | Hooks 규칙, useEffect 오용, cleanup, stale closure, `useSyncExternalStore`, 상태 위치, RSC 경계, 테스트 쿼리 우선순위 |
| `rules/web/performance.md` (신규, paths) | CWV·번들 예산, 렌더러 성능 예산 |
| `agents/react-reviewer.md` | RSC 경계·폼 소폭, 분담표 |
| `skills/react-testing/SKILL.md`, `skills/vite-patterns/SKILL.md` (신규) | RTL·MSW·훅 테스트 / 프록시·env·빌드(Electron 렌더러) |
| `skills/frontend-patterns`, `skills/frontend-a11y` | 리렌더 최적화·워터폴 / 폼·ARIA·포커스 확장 |
| `agents/debugger.md` | 웹 빌드 실패 절 |

**C-2. Electron** (W4, D-02 TS 시)
`rules/electron/security.md`(paths `**/main/**`·`**/preload/**`·`**/electron*.{ts,js}` — `contextIsolation`·`sandbox`, `nodeIntegration` off, `contextBridge` 최소 API, IPC allowlist + sender 검증, CSP, 네비게이션·새 창 차단, fuses, 업데이트 서명), `rules/electron/patterns.md`(프로세스 역할, 창별 재시작, 메모리 감시, 서명 배포), `/e2e`에 Playwright `_electron` 절.

### D. 대용량 데이터 처리 구조 (도메인 무관)

> 초당 수만~수백만 건 규모 데이터를 받고·변환하고·저장하고·보여주는 구조를 서버·DB·클라이언트 전
> 구간에서 설계·구현·측정한다. 현재 하네스에는 41줄 일반론 스킬뿐이라 전부 신규 작성.
> 공유 상태·영속은 I-2, 수신 저장소 자료구조는 I-1과 역할을 나눈다.

**D-1. 처리량 원칙 허브** (W3) — `skills/data-throughput-accelerator/SKILL.md` 재작성(이름 유지):
처리량 모델(도착률·서비스율·리틀의 법칙, 버스트 버퍼 산정) · 측정 우선(p50/p99/p99.9·큐 깊이·드롭 수) ·
흐름 제어(bounded queue, 백프레셔, 느린 소비자 3택) · **데이터 손실 정책 명시 의무**(전량 보존/최신값
병합/샘플링, 채널별) · 순서·중복·유실 보장(시퀀스·갭 재요청·멱등·스냅샷+증분 재동기화) ·
배치·파이프라이닝 · 파티셔닝 · 영속화 경계 · 관측성 · 트랙 지도(D·I·E-2 링크).

**D-2. 서버 파이프라인** (W3) — `skills/stream-pipeline-patterns/SKILL.md` (신규, **C 우선**, Rust 대응 병기):
큐 선택(SPSC·MPSC·MPMC, C11 원자 연산 링버퍼·캐시라인 패딩 — `rules/systems` 참조) · I/O 묶음
(`recvmmsg`/`sendmmsg`, `writev`, io_uring 판단, `TCP_NODELAY`) · 복사·할당 제거(버퍼 풀·슬랩) ·
프레이밍(길이 prefix·부분 수신 재조립·최대 프레임 상한) · 팬아웃(구독 관리, 클라이언트별 송신 큐 상한,
느린 클라이언트 강등·차단, 묶음 송신) · 스레드 고정·NUMA · Rust 이식 시 tokio bounded mpsc 대응.

**D-3. DB 대량 경로** = E-2b (W3).

**D-4. 스트림 계약** (W3, E-3과 같은 PR): D-04 형식의 **C 헤더 구조체가 정본**(필드 오프셋·엔디언·
`_Static_assert` 크기 고정·버전 필드) · 하위 호환(필드 추가만·예약 영역) · 채널 명세(메시지 종류·순서
보장·손실 정책·재동기화) · TS 디코더 생성·검증(동일 테스트 벡터로 C ↔ TS 상호 검증).

**D-5. 클라이언트 대용량 수신** (W4) — `skills/desktop-data-client/SKILL.md` (신규):
utilityProcess·`worker_threads`에서 Node `net` 직접 수신(백프레셔) / 웹은 Worker + WebSocket(서버 송신 상한
필수) · `DataView` 무할당 디코딩·프레임 재조립 · 화면 주기 묶음·병합, `MessagePort` + Transferable,
`SharedArrayBuffer` 링버퍼 · GC 억제 · 수치 정밀도(정수 스케일·`bigint`·branded) · **클라이언트 측 자료구조
(키 정렬 배열·인덱스 맵 — I-1과 같은 원칙)** · 가상화 그리드 + canvas · Rust → WASM/napi-rs 판단 · 장시간 안정성.

**D-6. PoC·부하 측정** (W3)

| 파일 | 작업 |
|---|---|
| `skills/load-testing/SKILL.md` (신규) | 요청형(k6)·스트림형(전용 송신 시뮬레이터) 부하, coordinated omission 회피, 워밍업, 서버·DB·클라이언트 동시 관측 |
| `templates/project/throughput-poc/` (신규) | **C 송신 시뮬레이터**(목표 레이트·배수·메시지 크기 파라미터) + 수신 계측 골격(C·TS) + 결과 표 양식(처리량·p99·CPU·1시간 메모리) |
| PoC 실행 | 입력 1.1 수치가 없으면 1만·10만·100만 건/초 3단계로 측정, 결과를 issue 문서로 → D-02 확인 |

### E. 3티어 스택

**E-1. C 서버 구조와 Rust 이식** (W3, 철학 P3 후)

| 파일 | 작업 |
|---|---|
| `rules/c/patterns.md` | **함수 포인터 인터페이스(C 다형성)** 절 추가: 연산 테이블 구조체 + 불투명 핸들, 생성·소멸 쌍, 인터페이스 버전 필드 — 기존 불투명 포인터 절과 연결 (R7) |
| `skills/c-server-patterns/SKILL.md` (신규) | epoll 이벤트 루프 골격, 모듈 수명(초기화 순서·역순 해제), 시그널 처리(`signalfd`), 설정 재적재, 프로세스 구조(마스터·워커, `fork` 후 정리), graceful shutdown, 공유메모리·DB 모듈과의 경계(I-2) |
| `skills/c-to-rust-migration/SKILL.md` (신규) | **E-1b 이식 지침**: 대응표(불투명 포인터 → 비공개 필드 구조체+`impl`, 함수 포인터 테이블 → trait, goto 정리 → `Drop`, errno → `Result`, epoll → mio·tokio, 시그널·`fork`·공유메모리 → nix·libc), **임베디드 SQL은 Rust 프리컴파일러가 없음** → DB 계층은 C 유지 + FFI(권장) 또는 `oracle` crate·`sqlx`로 재작성, 점진 이식(bindgen·cbindgen, 모듈 단위 교체, 동일 테스트로 C·Rust 결과 비교), 공유메모리 레이아웃 `#[repr(C)]` 공유, 이식하지 말아야 할 경우(이득 없는 안정 모듈) |

**E-2. 임베디드 SQL·DB 보강**

E-2a (W2) — 기반

| 파일 | 작업 |
|---|---|
| `rules/c/*.md` paths | **`**/*.pc`, `**/*.pgc` 추가** — 임베디드 SQL 편집 시 C 규칙 로드 |
| `agents/database-reviewer.md` | "DB 제품(Oracle/PG) × 접근 방식(ORM/임베디드/네이티브)" 매트릭스. **임베디드 체크**: 인디케이터 변수 누락(NULL 처리), `WHENEVER` 범위 오용, 커서 미닫음, 호스트 변수 버퍼 크기·NUL 종료, `sqlca.sqlerrd[2]` 처리 건수 미확인, 동적 SQL 문자열 연결, 트랜잭션 경계, 단건 루프 → 호스트 배열 권고, 개인정보 컬럼 암호화·마스킹 |
| `skills/sql-schema-versioning/SKILL.md` (신규, D-08) | 버전 명명 규약, `SCHEMA_HISTORY` 테이블 DDL(Oracle·PG), 체크섬, 적용 스크립트(bash: 미적용 버전 순차 적용·실패 시 중단·dry-run), 방언 디렉터리, expand-contract 원칙, 빈 DB·기존 DB 이중 검증, 롤백 대신 전진 수정 |
| `skills/database-migrations/SKILL.md` | description에 "Alembic(Python) 전용" 명시 + `sql-schema-versioning` 링크 |

E-2b (W3, I-2와 같은 PR) — 대량·동시성 (= D-3)

| 파일 | 작업 |
|---|---|
| `skills/embedded-sql/SKILL.md` | **호스트 배열**: 배열 fetch(1회 왕복 N행, `sqlca.sqlerrd[2]`로 누적 건수), 배열 insert·update(`FOR :n`), 배열 크기 산정(메모리·왕복 균형), 부분 실패 처리 / **멀티스레드**: Pro*C `threads=yes`·`EXEC SQL CONTEXT ALLOCATE/USE/FREE`, 스레드별 컨텍스트, ecpg `AT connection`·연결명 / **재접속**: 연결 끊김 오류 분류(ORA-03113·03114·PG 연결 상태) → 재접속·재시도 정책 / 커밋 주기 / PG `COPY`는 ecpg 범위 밖 → libpq 예외 경로 / 생성 코드 valgrind·ASan 검사 |
| `skills/oracle-patterns/SKILL.md` (신규, 짧게) | 실행 계획 증거(`DBMS_XPLAN.DISPLAY_CURSOR`), 바인드 피킹, `''`=NULL, `NUMBER`·시간대 타입, 시퀀스·IDENTITY, 세션 풀·DRCP, 파티션 교환·direct-path 적재 |
| `skills/postgres-patterns/SKILL.md` | 대량 적재(`COPY`·unlogged 스테이징·파티셔닝), `synchronous_commit` 트레이드오프 |

**E-3. 계약 우선 설계** (W3, D-4와 같은 PR)

| 파일 | 작업 |
|---|---|
| `skills/json-contracts/SKILL.md` | 매핑 표에 **C 구조체·TS** 열 (int64 정밀도·Decimal 문자열·고정 길이 문자열 패딩·missing vs null) |
| `skills/api-contracts/SKILL.md` (신규) | 계약 우선 워크플로(소비자·소유자 식별 → 최소 계약 → 소비자 타입 생성 → 제공자 검증 → 증거 비교), 정본 1개 원칙(OpenAPI·C 헤더 스트림 스키마), 계약 변경 절차·호환성 판정, 안티패턴(제공자 추측 구현·정본 중복·컴파일 타입만으로 검증) |

**E-4. 런타임 분석·통합** (W4)

| 파일 | 작업 |
|---|---|
| `skills/remote-linux-analysis/SKILL.md` (신규) | ① **온라인 서버**: ssh 또는 원격 Claude Code, perf·bpftrace·strace·valgrind ② **오프라인 서버(인터넷 없음)**: 수집 스크립트 묶음 전달 → 실행 → 결과 tar 회수 → 로컬 분석 ③ **운영 서버 프로파일링 금지**(D-09) — 운영은 읽기 전용 상태 조회(I-4)만 ④ 바이너리·심볼 일치 ⑤ 결과물 개인정보 마스킹 ⑥ 외부 출력 UNTRUSTED 구획 |
| `templates/project/profiles/c-system/tools/collect.sh` (I-6에 포함) | 오프라인 수집 스크립트 골격(시스템 정보·`ipcs`·프로세스·로그 꼬리·선택적 perf) |
| `skills/distributed-tracing/SKILL.md` (신규, 경량) | C 서버는 요청 ID 전파·구조화 로그 기반 추적, TS는 OpenTelemetry. C에 OTel SDK 강제하지 않음 |
| `templates/project/compose-3tier/` (신규) | C 서버 빌드 컨테이너 + PostgreSQL + Oracle Free, `rules/docker` 준수 |
| `commands/e2e.md` | 3티어 시나리오: compose → 스키마 적용(`sql-schema-versioning`) → Playwright(웹·Electron) |

**E-5. C# 클라이언트** (조건부 — D-02가 C#일 때만, W4)
`rules/csharp/` 5종, `csharp-reviewer`, `/csharp-review`, `skills/dotnet-client-patterns`, 진단 도구 절.

### F. 시스템 언어 리뷰 (W4, 철학 P4·B-3과 같은 PR)

| 파일 | 작업 |
|---|---|
| `agents/rust-reviewer.md` (신규, 읽기 전용) | 소유권·`clone()` 남용, `unsafe`+`// SAFETY:`, async 블로킹, `let _ =` 무시, `unwrap`·`expect` 경계, `Arc<Mutex>` 확산, 무상한 채널, **FFI 경계(C 이식 모듈: 포인터 수명·NULL·`#[repr(C)]` 일치)**, cargo-deny·audit, 방어 기준선 |
| `commands/rust-review.md` (신규) | 기존 형식 |
| `agents/debugger.md` | 빌드 실패 절(Make·링커·**Pro*C·ecpg 프리컴파일 오류**·borrow checker·Cargo), 시도 상한·중단 조건 |
| `agents/code-reviewer.md` | 삼켜진 에러(반환 코드·`errno`·`sqlca` 무시), 주석 표류, 테스트가 실제 동작을 덮는지, 무상한 큐·버퍼, **I 트랙 체크**(공유메모리에 포인터 저장, 헤더 버전 미확인, 락 없이 다중 작성, 정렬 불변식 깨짐) |
| `skills/cpp-patterns`, `skills/rust-patterns`, `skills/rust-testing`, `skills/performance-profiling` | 규칙 ID 색인 / 패턴·테스트 보강 / 기준선 → 변형 비교 → 승격 게이트 |

### G. 감사 후속

| # | 웨이브 | 작업 |
|---|---|---|
| G-1 | W1 | Q1 실측(일반·커스텀·대조군, 실험 취지 비공개), 결과를 `rules/common/agents.md`에 반영 |
| G-2 | W4 | D-14 프리로드 적용·토큰 측정·감사 §6 판정 갱신 |

### H. 하네스 무결성

| # | 웨이브 | 작업 |
|---|---|---|
| H-1 | W0 | `skills/synced/` 출처 확인 → ignore, 스킬 중복 등록 확인, `.DS_Store`·`*.xlsx` ignore |
| H-2 | W1 | 스킬 예시 SQL `$1`·`$2`(`embedded-sql` L237·242, `error-handling` L261, `security-review` L85)의 인자 치환 여부를 공식 문서로 확인 → 치환되면 표기 교체 + 산문 설명 |
| H-3 | W1 | `tests/agent_command_meta.bats`, `tests/check_sensitive_text.sh`(개인 경로·비밀값·개인정보), `tests/check_unicode_safety.sh`, 자리표시자 검사, CI 편입 |
| H-4 | W1 | `check_index.sh` 크기 경고(에이전트 200줄·스킬 400줄·규칙 100줄 WARN) |

### I. C 시스템 데이터 계층

> **공용(하네스)**: 선택 기준·패턴·도구 골격·검사 메커니즘. **프로젝트 소유**: 사전 본문, 세그먼트
> 레이아웃·키, 테이블↔공유메모리 매핑, 운영 절차 세부 — `c-system` 프로필(I-6)이 위치를 만든다.

**I-1. 자료구조·정렬 기반 수신 저장소** (W3) — `skills/c-data-structures/SKILL.md` (신규)

| 절 | 내용 |
|---|---|
| 선택 기준표 | 접근 패턴 → 자료구조: 정확 일치 조회(해시, 개방 주소법), 범위·순서 조회(**키 정렬 배열 + `bsearch`**), 최근 N건·시계열(링버퍼), 다중 키(주 배열 + 보조 인덱스 배열), 삽입 빈도별 정렬 유지 전략(삽입 시 `memmove` vs 버퍼 적재 후 일괄 `qsort`) |
| 레코드 설계 | 고정 크기 레코드, 키 필드를 앞에, 정렬·패딩 명시, `_Static_assert`로 크기 고정, 공유메모리 적재 가능 형태(포인터 금지 → 인덱스·오프셋) |
| 비교 함수 규약 | 키별 비교 함수 1개, 다중 키 비교 순서 문서화, 안정성 필요 여부, 정렬 불변식 검증 함수(디버그 빌드) |
| 조회 API 통일 | `<Domain>Find`·`<Domain>FindRange`·`<Domain>Insert`·`<Domain>Remove` 같은 이름 규칙(D-22 사전과 연동), 반환 규약(인덱스·`-1`·포인터 NULL 중 하나로 통일) |
| 유지보수 | 레이아웃·키 정의는 헤더 하나에, 변경 시 버전 증가(I-2 헤더와 연동), 단위 테스트(정렬 불변식·경계 키) |

**I-2. 공유메모리 ⇄ DB 처리** (W3, E-2b와 같은 PR) — `skills/shm-db-patterns/SKILL.md` (신규)

| 절 | 내용 |
|---|---|
| 방식 선택 | D-23: POSIX vs SysV 비교(이름·권한·정리·`ipcs` 가시성), 크기 산정, huge page 판단 |
| 세그먼트 헤더 | 매직 넘버·레이아웃 버전·레코드 크기·레코드 수·생성 시각·**상태 플래그(초기화 중/정상/복구 중/손상)**·마지막 적재 시퀀스·체크섬 — attach 시 반드시 검증 |
| 동시성 | robust 프로세스 공유 뮤텍스(`PTHREAD_PROCESS_SHARED`+`PTHREAD_MUTEX_ROBUST`, `EOWNERDEAD` → `pthread_mutex_consistent` + 복구) vs 단일 작성자 + 시퀀스 락(읽기 다수) 선택 기준, 락 범위 최소화 |
| DB → 공유메모리 적재 | 기동 시 전량 적재(호스트 배열 fetch, E-2b), 임시 영역에 적재 후 검증 → 상태 플래그 전환(원자적 교체), 적재 중 조회 처리 |
| 공유메모리 → DB 반영 | 변경 큐 또는 더티 플래그, 주기 배치 반영(호스트 배열 update), 체크포인트 시퀀스, 반영 실패 시 재시도·보류 |
| 정합성 | 공유메모리 ↔ DB 대조(건수·체크섬·샘플), 불일치 보고 |
| 금지 사항 | 공유메모리에 포인터 저장, 헤더 검증 없는 attach, 락 없는 다중 작성, 개인정보 불필요 필드 적재 |
| 수명 | 생성·attach·detach·삭제 소유 프로세스 명시, 권한 최소(0600·0640), 재기동 시 재사용 vs 재생성 규칙 |

**I-3. 메모리 컨트롤·복구 도구** (W4) — 골격은 `templates/project/c-system/tools/` (c-system 프로필이 `tools/`로 복사)

| 도구 | 기능 |
|---|---|
| `shmctl.sh` (bash) | `create`·`status`(헤더 요약·attach 프로세스 수)·`remove`(확인 프롬프트 + 소유 프로세스 미실행 확인)·`list`(`ipcs` 래핑). **기본 dry-run**, 실행 로그 기록 |
| `shm_recover` (C) | 헤더 검증 → 손상 판정(매직·버전·체크섬·상태 플래그) → **DB에서 재적재**(I-2 적재 경로 재사용) → 정합성 검증 → 상태 플래그 정상 전환. `--dry-run`·`--verify-only`. 운영 사용 시 확인 절차 |
| `skills/shm-db-patterns` 운영 절 | 복구 런북 템플릿(증상 → 판정 → 조치 → 검증 → 기록), 도구 사용 예 |

**I-4. 메모리 조회 도구** (W4) — `templates/project/c-system/tools/`

| 도구 | 기능 |
|---|---|
| `shm_view` (C) | **읽기 전용 attach**(`SHM_RDONLY`·`PROT_READ`), 세그먼트 목록·헤더 출력, 키 조회(I-1 `bsearch` 재사용)·범위 조회, 레코드 필드 단위 출력(필드 정의 테이블 기반), **개인정보 필드 기본 마스킹**(해제는 명시 옵션 + 감사 로그), 출력 형식(표·CSV) |
| 필드 정의 | 레코드 레이아웃 헤더에서 필드 이름·오프셋·타입·마스킹 여부 표를 생성하는 방식(매크로 테이블) — 레이아웃 변경 시 도구 자동 일치 |

**I-5. 네이밍 직관화·축약·통일성 검증** (W2, 철학 P2 후)

| 파일 | 작업 |
|---|---|
| `rules/common/coding-style.md` | **용량 중립 치환**: "이름만 보고 역할 추측 가능해야 함" 항목을 "약어는 프로젝트 사전(`.arachne/naming-dict.tsv`)에 등록된 것만, 같은 개념은 같은 단어(→ `naming-dictionary`)"로 |
| `skills/naming-dictionary/SKILL.md` (신규) | 사전 형식(TSV: 표준 단어 · 허용 약어 · 의미 · 금지 동의어 · 분류), 약어 원칙(자주 쓰는 긴 단어만, 3~5자, 모음 생략보다 앞부분 유지, 한 단어 한 약어), 식별자 구성 순서(도메인 → 대상 → 동작/속성), 접두·접미 규칙(`g_`·`m_`·`Is/Has`·`Cnt/Len/Idx` 등 공통 기본 약어), 신규 약어 등록 절차, 기존 코드 적용 범위(D-22) |
| `lib/naming-check.sh` (신규) | 식별자 추출(ctags 있으면 사용, 없으면 정규식 폴백) → 표기법별 토큰 분해(PascalCase·snake·`g_`·`m_`) → 사전 대조: **미등록 약어, 동의어 혼용(예: `Cnt`와 `Count` 공존), 금지어, 30자 초과, 단일 문자** 보고. 변경 파일만(`git diff`) 또는 전체 모드. 보고만(D-22) |
| `templates/project/profiles/c-system/naming-dict.tsv` | 공통 기본 약어 20~30개 + 빈 프로젝트 영역 |
| `tests/naming_check.bats` (신규) | 미등록 약어·동의어 혼용·허용 케이스 |
| `commands/verify.md` | C 프로젝트에서 사전 있으면 `naming-check` 실행 단계 |
| `agents/code-reviewer.md` | 신규 식별자의 사전 위반 지적 (F와 같은 PR) |

**I-7. 프로그램 동작(운영) 로그** (W3) — `skills/operational-logging/SKILL.md` (신규, 원칙은 언어 공통·구현은 C 우선)

| 절 | 내용 |
|---|---|
| 레벨 기준 | FATAL(프로세스 종료)·ERROR(요청·작업 실패, 조치 필요)·WARN(자동 복구됨·임계 근접)·INFO(상태 전환·기동/종료·주기 통계)·DEBUG(개발용)·TRACE(건별 상세, 운영 기본 꺼짐). 레벨별 "언제 쓰나" 예시. 공통 규칙의 `[DEBUG]` 임시 출력과 구분(운영 로그는 레벨 체계로) |
| 형식 | 한 줄 한 이벤트, `key=value` 구조화: 시각(µs, 로컬+UTC 정책 명시)·호스트·프로세스명·pid·tid·레벨·모듈·`함수:줄`·**거래/요청 ID**·메시지. grep·awk로 바로 조회 가능한 형태 |
| 남길 것 | 기동·종료(버전·빌드·설정 요약, 비밀값 제외)·외부 연결 수립·끊김·재접속·DB 오류(`sqlca` 코드·메시지·SQL 식별자 — 바인드 값 제외)·공유메모리 상태 전환·복구 실행·주기 처리량 통계(D-1 지표)·관리 명령 실행 |
| 남기지 말 것 | 개인정보·비밀번호·토큰(B-4 마스킹), 핫패스 건별 INFO 로그, 같은 오류의 중복 기록(기록 후 상위로 전달하며 또 기록) |
| 성능 | 레벨 검사 매크로로 비활성 레벨의 인자 평가 회피, 핫패스는 **비동기 로깅**(사전 할당 링버퍼 + 로거 스레드), 버퍼링·주기 flush, **폭주 억제**(같은 메시지 N초당 M건 + 생략 건수 요약) |
| 출력 대상 | 파일 vs syslog/journald 선택 기준, 다중 프로세스 동시 쓰기(`O_APPEND` 원자성은 한 번의 `write` 크기 한계 내 — 프로세스별 파일 또는 로거 프로세스), 디스크 풀 시 동작(로그 때문에 서비스가 멈추지 않게) |
| 회전·보존 | `logrotate`와 재오픈 신호(`SIGHUP`) 처리 vs `copytruncate` 트레이드오프, 보존 기간·파기(B-4), 압축 |
| 장애 시 | 크래시 직전 버퍼 flush 범위(시그널 핸들러 안 async-signal-safe 함수만), 코어 덤프와 로그 시각 대조 |
| 추적 | 거래/요청 ID 생성·전파(클라이언트 → 서버 프로세스 간 → DB 작업), 여러 로그 파일을 ID로 모아 시간순 정렬하는 조회 스크립트 |
| 클라이언트 | Electron·웹 로그 원칙 요약(로컬 파일 회전, 개인정보 금지, 서버 전송 시 동의·마스킹) — D-5 링크 |

| 파일 | 작업 |
|---|---|
| `templates/project/profiles/c-system/src/log/` | C 로거 골격 `log.h`·`log.c`: `LogInit`·`LogShutdown`·`LogReopen`(SIGHUP), 레벨 매크로(`LOG_ERROR(...)` 등 — 파일·줄 자동 삽입), 비동기 링버퍼 모드, 폭주 억제, 마스킹 헬퍼(`LogMaskDigits` 등) |
| `templates/project/profiles/c-system/tools/logtrace.sh` | 거래/요청 ID로 다중 로그 파일 수집·시간순 정렬·레벨 필터 |
| `templates/project/profiles/c-system/conf/logrotate.conf` | 회전 템플릿(재오픈 신호 방식) |
| `rules/c/patterns.md` | 로그 한 절(3~5줄): 레벨 매크로 사용, 핫패스 비동기, `sqlca` 오류 기록 형식, 스킬 링크 |
| `rules/common/coding-style.md` 디버그 출력 표 | **용량 중립 치환**: `[프로젝트명]` 행 설명을 "운영 로그는 레벨 체계(→ `operational-logging`)"로 |
| `agents/code-reviewer.md` | 로그 체크(F와 같은 PR): 개인정보 로그, 핫패스 동기 로그, 에러 경로 로그 누락·중복 기록, 레벨 오용, 사용자 입력을 포맷 문자열로 사용 |

**I-6. `c-system` 프로젝트 프로필** (W4) — `templates/project/profiles/c-system/` (신규)
`Makefile`(gcc + Pro*C·ecpg 프리컴파일 규칙 + sanitizer 타깃) · `verify.sh`(빌드·테스트·valgrind·
`naming-check`) · `tools/`(I-3·I-4·I-7·E-4 수집 골격) · `src/log/`(I-7 로거) · `conf/`(logrotate) · `naming-dict.tsv` · `sql/`(`oracle/`·`postgres/`
버전 규약 디렉터리, D-08) · `docs/shm-layout.md` 템플릿(세그먼트·키·레코드·소유 프로세스 표) ·
`docs/recovery-runbook.md` 템플릿. `lib/project-ci.sh`·`arachne.yml`에 `c-system` 프로필 추가,
`docs/PROJECT-CI.md` 갱신.

### Z. 최종 정리 (W6)

**Z-0. 방법**
1. 전수 인벤토리 표(archive 제외): 마지막 커밋일, status, 기록물 여부, 점검 적중 수, 문서 역할.
2. **문서 역할 4종**: 헌법(CLAUDE.md·rules), 지도(ARCHITECTURE·README·인덱스), 상태(task·plan),
   이력(issue·ADR·감사). 변경 시 해당 역할만 갱신, 역할 중복 문서는 통합.
3. 분류: 유지 / 최신화 / 이동 / archive / 삭제. 스킬은 유지·개선·갱신·폐기·병합 + 근거 한 줄.
4. 고아 탐지: settings 미참조 훅, 링크 없는 문서·스킬, install.sh·bats 미참조 스크립트.
5. 이동·archive·삭제는 `[PLAN]` 승인 후 한 항목씩, 내역을 인벤토리 표에 기록.
6. 기록물 본문 수정 금지(frontmatter·링크만).
7. **문장 품질**: 최신화·보완으로 쓰거나 고치는 모든 문서는 사람이 읽기 쉬운 문장으로 다듬는다(Z-3).

**Z-3. 문서 작성 품질 기준** (Z에서 손대는 모든 살아있는 문서, 신규 문서 포함)

| 기준 | 내용 |
|---|---|
| 독자 먼저 | 문서 첫머리 1~3문장에 "이 문서가 무엇이고 누가 언제 읽는가"를 쓴다 |
| 결론 먼저 | 각 절은 요점부터 쓰고 근거·예외를 뒤에 둔다 |
| 문장 | 한 문장에 한 가지 내용. 명사 나열·조사 생략 전보체("~함", "→" 연쇄)를 피하고 완결된 문장으로 쓴다. 표와 목록은 비교·절차에만 쓴다 |
| 문맥 | 앞 절에서 정의한 용어를 그대로 쓰고, 같은 개념을 다른 말로 바꾸지 않는다. 처음 나오는 약어·내부 용어는 풀어 쓴다 |
| 일관성 | 문서 간 같은 대상은 같은 이름(파일명·트랙명·용어). 용어는 `docs/GLOSSARY.md` 기준 |
| 현재형 | 살아있는 문서는 현재 상태만 쓴다. 과거 경위는 "변경 이력"·ADR로 보내고 본문에 남기지 않는다 |
| 검증 | 수정 후 문서를 처음 읽는 사람 관점으로 한 번 통독한다(서브에이전트에게 "이해 안 되는 문장·문맥이 끊기는 곳" 지적을 맡겨 확인) |

**Z-1. 확인된 점검 항목**

| 대상 | 문제 | 조치 |
|---|---|---|
| `docs/AI-ENGINEERING-NOTES.md` L38·106·114·141 | 제거된 `atask`·`codex-task`를 현행처럼 서술 | ADR-0004 이후 상태로 갱신 |
| `docs/tools/codegraph.md` L91 | "`gemini-task`가 보완" | Explore 위임으로 교체 |
| `docs/task/README.md` | 없는 `docs/plan/PLAN.md` 참조 | D-15 |
| `CLAUDE.md` 트리 | `docs/`·`lib/`·`templates/`·`archive/` 미표기 + 신규 항목 | 갱신 |
| status 표류 | `2026-06-11-audit-followup`, `2026-08-25-pc-defect-repair`, `2026-08-25-hook-subagent-experiment`, in progress 1건 | 커밋 이력 대조 |
| 7월 이전 미갱신 | DATA-HANDLING, PYTHON-WEB-PROFILE, PROJECT-CI, DOCS-SYNC, SYNCTHING-SETUP | 현행 대조 |
| 개수 표기 | README·CLAUDE.md·ARCHITECTURE·skills/README·AGENTS.md | 전 트랙 합산 |
| 루트 기록물·`docs/task/20261005/` | D-15 | 이동 |
| `docs/decisions/README.md` | ADR 표 중간에 `0002` 번호 안내문이 끼어 표가 끊김 | 안내문을 표 아래로 이동 |
| 언어별 coding-style 헤더 예시 (python·golang·bash·javascript 등) | D20(날짜 필드 삭제)이 공통 규격·C/C++에만 반영됨 | 헤더 예시에서 `DATA`·`Modification` 제거 |
| 로컬 bats 판정 신뢰도 | macOS 기본 bash 3.2 는 `set -e` 에서 `[[ ]]`·`!` 실패로 테스트를 멈추지 않아 로컬 통과가 CI(bash 5) 실패를 숨긴다(2026-10-05 W2에서 실제 발생) | `docs/CI.md`에 명시, 마지막 줄이 아닌 단정은 `[ ]`·`grep -q`로 작성하는 규칙을 `rules/bash/testing.md`에 추가 |
| 크기 경고 대상 (`check_index.sh` 검사 8) | 기준 초과 파일 다수 | 역할이 섞였으면 분리, 아니면 압축 |
| `README.md` L206, `docs/ARCHITECTURE.md` L127, `tests/install.bats` L76~78 | 과거형·회귀 가드 | 유지 |

**Z-2. 완료 기준**: 제거 런타임 서술 0, 깨진 참조 0, status 불일치 0, 출처 불명 파일 0, 인벤토리 표가
다음 감사 기준선으로 커밋.

---

## 6. 통합 검증 (W5·W7)

**자동**: bats 전체(`guard_hooks`·`agent_command_meta`·`naming_check` 포함), `check_index.sh`,
`check_convention_sync.sh`, `validate_settings.sh`, 신규 검사(민감 텍스트·유니코드·자리표시자), `shellcheck -S warning`.

**행동 검증 (scratch 프로젝트, `c-system` 프로필로 생성)**

| # | 시나리오 | 기대 |
|---|---|---|
| 1 | `git commit --no-verify` / `push --force-with-lease` / `psql -c "DROP TABLE t"` / `ipcrm -m 1234` | deny / 통과 / ask / ask |
| 2 | 가짜 액세스 키·검증식 통과 주민번호 커밋 / 불통과 숫자열 | deny / 통과 |
| 3 | `.env` Read / `cat .env` / `.env.example` Read | 거부 / ask / 허용 |
| 4 | `.pc` 파일 편집 | `rules/c` 로드 확인 |
| 5 | Pro*C 단건 루프 INSERT·인디케이터 누락·커서 미닫음 | database-reviewer: 호스트 배열 권고·NULL 처리·커서 지적 |
| 6 | 잔고 조회 후 별도 UPDATE(Pro*C) | code-reviewer TOCTOU 지적 |
| 7 | 공유메모리 구조체에 포인터 필드, 헤더 검증 없는 attach | code-reviewer 지적 |
| 8 | 작성 프로세스를 락 보유 중 강제 종료 | 다음 프로세스가 `EOWNERDEAD` 감지 → 복구 경로 실행 |
| 9 | 헤더 매직 훼손 후 `shm_recover --dry-run` → 실행 | 손상 판정 → DB 재적재 → 정합성 통과 → 상태 정상 |
| 10 | `shm_view`로 개인정보 필드 포함 레코드 조회 | 기본 마스킹, 해제 시 감사 로그 |
| 11 | `Cnt`·`Count` 혼용, 미등록 약어 `Usr` 신규 식별자 | `naming-check` WARN 2건 |
| 12 | 정렬 배열 삽입 후 불변식 검증 | 디버그 빌드 검증 통과, 깨뜨리면 실패 |
| 13 | `.sql` 버전 적용 스크립트(빈 DB·기존 DB) | 미적용 버전만 순차 적용, `SCHEMA_HISTORY` 기록 |
| 14 | C 모듈 1개를 Rust로 이식(FFI) 요청 | `c-to-rust-migration` 절차, rust-reviewer FFI 경계 점검 |
| 15 | D-6 PoC 3단계 레이트 | 처리량·p99·메모리 결과 표 |
| 16 | `.ts`에 `forEach(async …)`·`number` 금액 곱셈 / Electron `nodeIntegration: true` | typescript-reviewer 지적 / `rules/electron` 로드·지적 |
| 17 | `/save-session` 후 요약 검사 | `check_sensitive_text.sh` 적중 0 |
| 18 | 오프라인 서버 시나리오: 수집 스크립트 실행 → 결과 회수 | 분석 가능한 묶음, 개인정보 마스킹 |
| 18-1 | 핫패스에서 같은 오류를 초당 1만 회 발생 | 폭주 억제로 N건 + 생략 건수 요약, 처리량 저하 없음 |
| 18-2 | 로그에 카드번호가 들어가는 코드 / `logrotate` 후 `SIGHUP` | 리뷰어 지적·마스킹 헬퍼 권고 / 새 파일로 이어서 기록 |
| 18-3 | 거래 ID 하나로 서버 2개 프로세스 로그 추적 | `logtrace.sh`가 시간순으로 합쳐 출력 |
| 19 | 철학 계획 §6.3 시나리오 1~4 | 철학 계획 기준 |

**컨텍스트 비용**: `rules/common` W0 대비 증가 0(I-5·B-4b는 동일 길이 치환). 신규 paths 규칙
디렉터리별 15KB 이하. 에이전트 8→10, 커맨드 +2, 스킬 증가분은 W6에서 확정(약 +15).

결과: `docs/issue/YYYY-MM-DD-roadmap-verification.md`, 인벤토리 표 부록.

---

## 7. 비범위

- 매 도구 호출 관찰·집계 훅, 컨텍스트 주입 훅, Node·Python 의존 훅
- 다중 CLI 런타임(ADR-0004), Dynamic Workflows(ADR-0003)
- `rules/common` 신규 파일, 별도 `rules/typescript`
- C++·Rust 서비스 프레임워크 스킬(axum·tonic·Asio) — D-06
- OCI·libpq를 기본 DB 접근으로 하는 스킬 — D-07 (예외 경로만 기술)
- 마이그레이션 도구 도입 — D-08
- 메시지 브로커, DB 운영(백업·복제·RAC), 쿠버네티스
- **프로젝트 고유 값**(약어 사전 본문, 세그먼트 레이아웃·키, 테이블 매핑) — 프로젝트 소유
- 기존 코드 일괄 리네이밍(D-22), 기록물 본문 수정, `archive/` 내부 정리
- C# 서버, MySQL·MSSQL, 공격·바운티 지향 보안

## 8. 리스크

| 리스크 | 영향 | 대응 |
|---|---|---|
| 트랙 간 동일 파일 수정 | 머지 충돌 | 웨이브, 같은 PR 묶음(R4·I-2/E-2b·D-4/E-3), `/worktree` |
| 스킬 급증(약 +15) | 선택 정확도 저하 | description 엄격, 역할 경계 교차 링크, Z 판정 병합 |
| 공유메모리 도구 오작동 | 운영 데이터 손상 | 조회는 읽기 전용, 복구·삭제는 dry-run 기본 + 확인 + 로그, 운영 프로파일링 금지 |
| 네이밍 검사 오탐 | 개발 방해 | 보고만(D-22), 변경 식별자만, 사전 등록으로 해소 |
| 하네스가 프로젝트 세부를 흡수 | 공용성 상실 | 공용·프로젝트 분리 원칙, 프로필이 프로젝트 소유 위치 제공 |
| 가드 훅·개인정보 패턴 오탐 | 작업 방해 | 토큰화 판정·검증식·ask 중심·bats |
| `permissions.deny` 과잉 | 정상 파일 읽기 불가 | 예외 명시, 목록 bats 고정 |
| 이력 스캔 결과 노출 | 새 유출 경로 | 위치만 기록 |
| D-02 판단 오류 | 클라이언트 재작업 | W3 PoC 후 확정, E-5 대기 |
| 미입력 전제(대용량 수치·C 표준 등) | 설계 가정 오류 | §1.4 가정 표시, 입력 시 갱신 |
| 신규 문서의 규약 이탈 | 형식·스타일 불일치 | 작성 원칙, `skill_meta.bats`·H-3, 리뷰 |
| 컨텍스트 후반부 대규모 작업 | 품질 저하 | 웨이브당 세션 분리, `/handoff` |

## 개정 로그

| 날짜 | 요약 |
|---|---|
| 2026-10-05 | 초안 — 감사 후속·3티어·보안·TS 초안 3종 통합, 대용량 데이터 트랙(D) 신설, 계약 우선 설계·문서 역할·자리표시자 점검 |
| 2026-10-05 | B-4 민감정보·개인정보 보호 추가 (D-17~D-19) |
| 2026-10-05 | 입력 시트 반영 — C 주력·임베디드 SQL 유지·`.sql` 버전 규약·원격/오프라인 분석(D-06~D-09 확정), 보안 권장안(D-20·D-21), **I 트랙 신설**(자료구조·공유메모리⇄DB·복구·조회 도구·네이밍 사전·`c-system` 프로필, D-22·D-23), E-1·E-2 재구성, C→Rust 이식 지침, 철학 개정 R7·R8, 검증 시나리오 재작성 |
| 2026-10-05 | I-7 프로그램 동작(운영) 로그 추가 — 레벨·형식·성능·폭주 억제·회전·추적·마스킹, C 로거 골격·`logtrace.sh`, 검증 18-1~18-3 |
