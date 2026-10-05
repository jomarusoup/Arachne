# Skills

Claude Code 세션에서 호출 가능한 워크플로·도메인 스킬 모음 (61개 현역 + archive/ 보관 9개).

---

## 시스템 프로그래밍

| 스킬 | 설명 |
|---|---|
| `build-debug` | C/C++ 빌드·GDB 디버그 절차 |
| `memory-check` | valgrind·ASan·TSan 메모리 검사 |
| `cpp-testing` | GoogleTest/CTest·sanitizer |
| `latency-critical-systems` | IPC·epoll·소켓 저지연 시스템 |
| `error-handling` | C/C++·TypeScript·Go 에러 처리 |
| `trading-systems` | FIX 프로토콜, 오더북, 마켓 데이터, rdtsc 측정 |
| `performance-profiling` | pprof·perf·flamegraph 병목 분석 워크플로 |
| `linux-system-network-programming` | POSIX·socket·epoll·signal·thread·fd 수명 체크리스트 |
| `c-server-patterns` | C 서버 골격 — epoll 루프·모듈 수명(ops 테이블·역순 해제)·signalfd·마스터/워커 fork 후 정리·설정 재적재·graceful shutdown |
| `c-to-rust-migration` | C→Rust 이식 판단·대응표·임베디드 SQL 대책(C 유지 + FFI)·점진 이식·FFI 안전 체크리스트 |
| `operational-logging` | 운영 로그 — 레벨 기준·key=value 형식·거래 ID 추적(`logtrace.sh`)·비동기 링버퍼·폭주 억제·logrotate 재오픈 |
| `naming-dictionary` | 프로젝트 네이밍 사전(`.arachne/naming-dict.tsv`) — 약어 원칙·식별자 구성 순서·신규 약어 등록·`naming-check` 보고 |

## 언어별 패턴·테스팅

| 스킬 | 설명 |
|---|---|
| `cpp-patterns` | C++ Core Guidelines 다이제스트 — RAII·Rule of Zero/Five·concepts·동시성 |
| `c-testing` | cmocka·링커 --wrap 모킹·valgrind/ASan 게이팅 C 테스트 |
| `golang-patterns` | 이디엄틱 Go 패턴 |
| `golang-testing` | 테이블 드리븐·벤치마크·퍼징 |
| `rust-patterns` | tokio 비동기, lock-free, zero-copy, 저지연 Rust |
| `rust-testing` | criterion 벤치마크, proptest, flamegraph |
| `rust-library-crate` | 재사용 crate 저작 — feature flag·no_std·MSRV·퍼징·크로스 플랫폼·docs.rs |
| `go-http-patterns` | Go HTTP 서버, gRPC, graceful shutdown |
| `python-patterns` | EAFP·타입힌트·컨텍스트매니저·`__slots__` (자원/메모리 사고 선행 학습) |
| `python-testing` | pytest·TDD·픽스처·autospec 모킹·async 테스트 |

## 백엔드·웹

| 스킬 | 설명 |
|---|---|
| `backend-patterns` | 레포지토리·서비스 레이어·N+1·캐싱·큐 (Python/FastAPI + 시스템 전환 이식 맵) |
| `frontend-patterns` | React·Next 합성·상태·가상화·a11y·React 19(서버 컴포넌트·액션·낙관적 UI) |
| `frontend-design-direction` | UI 구현 전 목적·사용자·톤·밀도·시각 방향 결정 |
| `frontend-a11y` | 키보드·focus·semantic HTML·label·contrast·motion 접근성 |
| `react-testing` | RTL 쿼리 우선순위·userEvent·MSW·renderHook·외부 스토어 테스트 |
| `vite-patterns` | Vite 프록시(`ws: true`)·`VITE_` 공개 값 규칙·빌드·Electron 렌더러 빌드 |
| `design-system` | spacing·radius·color·typography·component state 토큰 관리 |
| `api-design` | REST 설계 — 리소스 네이밍·상태 코드·봉투·커서/오프셋 페이지네이션·버전·레이트리밋 |
| `fastapi-patterns` | FastAPI 프로덕션 — 앱 팩토리·DI·스키마 분리·async·중앙 에러 핸들러·테스트 |
| `make-interfaces-feel-better` | 동심 radius·광학 정렬·모션·히트 영역 등 UI 폴리시 디테일 |

## 데이터·DB

| 스킬 | 설명 |
|---|---|
| `json-contracts` | Python(Pydantic v2)·C 서버·TypeScript 간 JSON wire contract — datetime·Decimal·int64 문자열·char[N]·missing/null·schema versioning |
| `api-contracts` | 계약 우선 설계 — 경계별 정본 하나(OpenAPI·C 헤더), 변경 절차·호환성 판정, 레이아웃 드리프트 검출, 스트림 계약(공유 테스트 벡터) |
| `database-migrations` | Alembic migration 안전 운영 — expand-contract·CONCURRENTLY·backfill·forward-fix |
| `postgres-patterns` | PostgreSQL 설계·운영 — 타입·제약·인덱스 선택·EXPLAIN 증거·pool/timeout·대량 적재(COPY·파티셔닝)·RLS |
| `oracle-patterns` | Oracle 설계·운영 — 실행 계획 증거·바인드 피킹·''=NULL·C 타입 매핑·시퀀스/IDENTITY·DRCP·대량 경로 |
| `c-data-structures` | C 수신 저장소 자료구조 — 접근 패턴별 선택표(해시·정렬 배열 + bsearch·링버퍼·보조 인덱스)·고정 크기 레코드·CheckSorted |
| `shm-db-patterns` | 공유메모리 ⇄ DB — 세그먼트 헤더 검증·robust 뮤텍스/시퀀스 락·호스트 배열 적재·write-back·정합성·복구 런북 |
| `redis-patterns` | Redis 운영 — namespace·TTL jitter·stampede·negative cache·Lua/MULTI·lock token·Streams·fallback |
| `embedded-sql` | Pro*C(Oracle)·ecpg(PostgreSQL) 임베디드 SQL — 호스트/인디케이터 변수·SQLCA·커서·프리컴파일 빌드 |
| `sql-schema-versioning` | 도구 없는 `.sql` 스키마 버전 규약 — `V<번호>__`·`R__` 명명, 방언 디렉터리, `SCHEMA_HISTORY`, 적용 스크립트, 전진 수정 |

## TDD·검증

| 스킬 | 설명 |
|---|---|
| `tdd-workflow` | Red-Green-Refactor 범용 워크플로 |
| `verification-loop` | Claude Code 세션 검증 시스템 |
| `research-routing` | 모델 선택(Haiku/Sonnet/Opus)·조사 도구 라우팅(codegraph vs sgrep) |

## 제품·기획·아키텍처

| 스킬 | 설명 |
|---|---|
| `product-lens` | 구현 전 사용자·고통·MVP·anti-goal·성공 지표 검증 |
| `product-capability` | 제품 목표를 capability map·acceptance criteria·release slice로 변환 |
| `plan-orchestrate` | 큰 작업을 조사·설계·TDD·구현·검증·문서화 단계로 분해 |
| `architecture-decision-records` | 장기 설계 결정을 `docs/decisions/` ADR로 기록 |
| `hexagonal-architecture` | port/adapter·domain boundary·testable backend 구조 |
| `agent-architecture-audit` | 하네스·자동화 구조의 역할 경계·상태·위임·검증 감사 |

## 보안

| 스킬 | 설명 |
|---|---|
| `security-review` | 보안 리뷰 체크리스트 |
| `security-scan` | Claude Code 설정 보안 스캔 |
| `sensitive-data-handling` | 비밀값·개인정보 기술적 통제 — 최소 수집·파기, 로그·코어 덤프 마스킹, 저장 암호화, argon2id 해시, 합성 테스트 데이터 |

## 인프라

| 스킬 | 설명 |
|---|---|
| `docker-patterns` | Docker/Compose 패턴 |
| `deployment-patterns` | 배포·rollback·healthcheck·migration·observability 기준 |

## 네트워크

| 스킬 | 설명 |
|---|---|
| `network-interface-health` | 인터페이스 오류·CRC·플래핑 진단 |
| `data-throughput-accelerator` | 처리량 원칙 허브 — 처리량 모델·버스트 버퍼 산정·흐름 제어·채널별 손실 정책·순서/갭/재동기화·배치·파티셔닝·관측성 |
| `stream-pipeline-patterns` | 서버 파이프라인 구현(C 우선·Rust 대응) — SPSC 링버퍼·I/O 묶음·버퍼 풀·길이 prefix 프레이밍·팬아웃·스레드 고정 |
| `load-testing` | 요청형(k6)·스트림형(전용 송신기) 부하 측정, coordinated omission 회피, 결과 표 양식, 처리량 PoC |

## 메타·하네스

| 스킬 | 설명 |
|---|---|
| `agentic-engineering` | eval-우선 실행·작업 분해·비용 인식 모델 라우팅 (하네스 설계·운영 관점) |

---

> 비활성 도메인 스킬(Java/Spring·네트워크 장비 9개)은 [archive/](archive/README.md)에 보관 — 복원 방법 포함.
