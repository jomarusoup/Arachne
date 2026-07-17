# Skills

Claude Code 세션에서 호출 가능한 워크플로·도메인 스킬 모음 (42개 현역 + archive/ 보관 9개).

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

## 언어별 패턴·테스팅

| 스킬 | 설명 |
|---|---|
| `golang-patterns` | 이디엄틱 Go 패턴 |
| `golang-testing` | 테이블 드리븐·벤치마크·퍼징 |
| `rust-patterns` | tokio 비동기, lock-free, zero-copy, 저지연 Rust |
| `rust-testing` | criterion 벤치마크, proptest, flamegraph |
| `go-http-patterns` | Go HTTP 서버, gRPC, graceful shutdown |
| `python-patterns` | EAFP·타입힌트·컨텍스트매니저·`__slots__` (자원/메모리 사고 선행 학습) |
| `python-testing` | pytest·TDD·픽스처·autospec 모킹·async 테스트 |

## Java 백엔드

| 스킬 | 설명 |
|---|---|

## 백엔드·웹

| 스킬 | 설명 |
|---|---|
| `backend-patterns` | 레포지토리·서비스 레이어·N+1·캐싱·큐 (Python/FastAPI + 시스템 전환 이식 맵) |
| `frontend-patterns` | React·Next 합성·상태·가상화·a11y·React 19(서버 컴포넌트·액션·낙관적 UI) |
| `frontend-design-direction` | UI 구현 전 목적·사용자·톤·밀도·시각 방향 결정 |
| `frontend-a11y` | 키보드·focus·semantic HTML·label·contrast·motion 접근성 |
| `design-system` | spacing·radius·color·typography·component state 토큰 관리 |
| `api-design` | REST 설계 — 리소스 네이밍·상태 코드·봉투·커서/오프셋 페이지네이션·버전·레이트리밋 |
| `fastapi-patterns` | FastAPI 프로덕션 — 앱 팩토리·DI·스키마 분리·async·중앙 에러 핸들러·테스트 |
| `make-interfaces-feel-better` | 동심 radius·광학 정렬·모션·히트 영역 등 UI 폴리시 디테일 |

## 데이터·DB

| 스킬 | 설명 |
|---|---|
| `json-contracts` | Python(Pydantic v2)·TypeScript 간 JSON wire contract — datetime·Decimal·missing/null·schema versioning |
| `database-migrations` | Alembic migration 안전 운영 — expand-contract·CONCURRENTLY·backfill·forward-fix |
| `postgres-patterns` | PostgreSQL 설계·운영 — 타입·제약·인덱스 선택·EXPLAIN 증거·pool/timeout·RLS |
| `redis-patterns` | Redis 운영 — namespace·TTL jitter·stampede·negative cache·Lua/MULTI·lock token·Streams·fallback |

## TDD·검증

| 스킬 | 설명 |
|---|---|
| `tdd-workflow` | Red-Green-Refactor 범용 워크플로 |
| `verification-loop` | Claude Code 세션 검증 시스템 |

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

## 인프라

| 스킬 | 설명 |
|---|---|
| `docker-patterns` | Docker/Compose 패턴 |
| `deployment-patterns` | 배포·rollback·healthcheck·migration·observability 기준 |

## 네트워크

| 스킬 | 설명 |
|---|---|
| `network-interface-health` | 인터페이스 오류·CRC·플래핑 진단 |
| `data-throughput-accelerator` | queue·batch·DB write·network I/O 처리량 병목 개선 |

## 메타·하네스

| 스킬 | 설명 |
|---|---|
| `agentic-engineering` | eval-우선 실행·작업 분해·비용 인식 모델 라우팅 (하네스 설계·운영 관점) |

---

> 비활성 도메인 스킬(Java/Spring·네트워크 장비 9개)은 [archive/](archive/README.md)에 보관 — 복원 방법 포함.
