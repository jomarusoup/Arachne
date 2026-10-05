---
name: performance-profiling
description: 저지연 시스템 성능 프로파일링 워크플로. Go pprof, C/C++ perf/VTune, Rust flamegraph. 병목 식별 → 최적화 → 벤치 검증 사이클, 기준선 → 변형 비교 → 승격 게이트. 키워드 — 프로파일링, perf, pprof, flamegraph, 병목, 기준선, benchstat, 승격 게이트.
---

# 성능 프로파일링 워크플로

## 언제 사용하나

- 레이턴시 회귀 감지 후 원인 분석
- 핫패스 최적화 전 병목 식별
- CPU·메모리 사용량 비정상 증가
- 릴리즈 전 성능 베이스라인 확인

## 언제 사용하지 않나

- Rust 벤치마크 작성 → `rust-testing` 스킬
- 메모리 누수 분석 → `memory-check` 스킬

---

## 사이클: 측정 → 병목 → 최적화 → 검증

```
1. 베이스라인 측정 (변경 전 수치 저장)
2. flamegraph / pprof 로 핫스팟 확인
3. 단일 병목 수정 (한 번에 하나)
4. 재측정 → 개선 확인
5. 회귀 없으면 커밋
```

## 기준선 → 변형 비교 → 승격 게이트

최적화는 "빨라진 것 같다"로 머지하지 않는다. 기준선과 변형을 같은 조건에서 비교하고, 게이트를 통과한 변형만 승격한다.
원칙은 `rules/systems/philosophy.md` 8절이 정본이다. 이 절은 실행 절차만 다룬다.

### 1. 기준선 고정

- 기준선은 `main`의 커밋 하나로 정한다. 커밋 해시를 결과 파일에 함께 적는다.
- 측정 조건을 기록한다: CPU 모델, 코어 고정(`taskset`), 주파수 고정(`cpupower frequency-set -g performance`), 커널, 컴파일러와 플래그, 입력 데이터셋.
- 워밍업 구간을 버리고 측정한다. 같은 측정을 5회 이상 반복해 분산을 본다.
- 결과는 저장소 밖의 산출물 디렉터리나 CI 아티팩트에 둔다. 예: `bench-results/<해시>.json`.

### 2. 변형 비교

- 변형 하나에 변경 하나만 넣는다. 두 가지를 섞으면 어느 쪽 효과인지 모른다.
- 기준선과 변형을 같은 머신에서 번갈아(A-B-A-B) 실행한다. 시간대에 따른 잡음이 양쪽에 고르게 들어간다.
- 비교 지표는 p50·p99·p99.9, 처리량, 할당 횟수, `perf stat`의 cycles·cache-misses다. 평균만 비교하지 않는다.
- 차이가 반복 측정의 분산보다 작으면 "차이 없음"으로 판정한다.

| 언어 | 기준선 저장 | 변형 비교 |
|---|---|---|
| Rust | `cargo bench -- --save-baseline main` | `cargo bench -- --baseline main` |
| Go | `go test -bench=. -count=10 > base.txt` | `benchstat base.txt variant.txt` |
| C/C++ | 벤치 바이너리 → HDR 히스토그램 파일 | 같은 입력으로 변형 실행 후 백분위 비교 스크립트 |

### 3. 승격 게이트

다음을 모두 만족해야 변형을 머지한다.

- [ ] 목표 지표가 분산을 넘어 개선됐다.
- [ ] 다른 지표가 회귀하지 않았다. p99는 +10%, p99.9는 +20%를 넘지 않는다(아래 지표 기준 표).
- [ ] 정확성 테스트와 새니타이저 빌드가 통과했다. 빠르지만 틀린 변형은 탈락이다.
- [ ] 차분 테스트로 기준 구현과 같은 출력을 확인했다(`rules/c/testing.md`).
- [ ] 커밋 메시지나 PR 본문에 기준선 해시, 측정 조건, 전후 수치를 적었다.

게이트에서 탈락한 변형도 수치와 함께 PR이나 작업 문서에 남긴다. 같은 시도를 반복하지 않기 위해서다.

---

## Go — pprof

```go
// HTTP 엔드포인트로 프로파일 수집
import _ "net/http/pprof"

go func() {
    log.Println(http.ListenAndServe("localhost:6060", nil))
}()
```

```bash
# CPU 프로파일 30초 수집
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30

# 힙 스냅샷
go tool pprof http://localhost:6060/debug/pprof/heap

# goroutine 덤프
go tool pprof http://localhost:6060/debug/pprof/goroutine

# 인터랙티브 분석
(pprof) top10          # 상위 10개 함수
(pprof) list FuncName  # 라인별 상세
(pprof) web            # flamegraph (graphviz 필요)
```

```bash
# 벤치마크에서 직접 프로파일
go test -bench=. -cpuprofile=cpu.out -memprofile=mem.out ./...
go tool pprof cpu.out
```

## C/C++ — perf

```bash
# CPU 이벤트 통계
perf stat -e cycles,instructions,cache-misses ./trading_engine

# 함수별 CPU 사용률 기록
perf record -g -F 999 ./trading_engine
perf report --sort=dso,symbol

# flamegraph 생성
perf script | stackcollapse-perf.pl | flamegraph.pl > perf.svg
```

```bash
# 캐시 미스 분석 (저지연에서 중요)
perf stat -e \
  cache-references,cache-misses,\
  L1-dcache-loads,L1-dcache-load-misses,\
  LLC-loads,LLC-load-misses \
  ./trading_engine
```

## Rust — cargo-flamegraph

```bash
# 설치
cargo install flamegraph

# 바이너리 프로파일링
cargo flamegraph --bin trading_engine -- --config config.toml
# → flamegraph.svg

# 벤치마크 프로파일링
cargo flamegraph --bench order_book -- --bench

# perf 기반 상세 분석
CARGO_PROFILE_RELEASE_DEBUG=true cargo build --release
perf record -g target/release/trading_engine
perf report
```

## 공통: flamegraph 해석

```
넓은 직사각형 = CPU 시간 많이 소비
높은 스택    = 깊은 콜 체인

주목 패턴:
- 예상치 못한 메모리 할당 (malloc/new 상단)
- 시스템 콜 (futex → 락 경합)
- 직렬화/역직렬화 비중
- 캐시 미스 (cache_miss 이벤트 flamegraph)
```

## 저지연 지표 기준

| 지표 | 경보 기준 | 조치 |
|---|---|---|
| p99 레이턴시 | 기준선 +10% | 필수 분석 |
| p999 레이턴시 | 기준선 +20% | 긴급 분석 |
| L1 캐시 미스율 | >5% | 데이터 레이아웃 검토 |
| LLC 미스율 | >1% | 핫 데이터 크기 검토 |
| syscall/tick | >0 (핫패스) | lock-free 전환 검토 |
