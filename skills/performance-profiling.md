---
name: performance-profiling
description: 저지연 시스템 성능 프로파일링 워크플로. Go pprof, C/C++ perf/VTune, Rust flamegraph. 병목 식별 → 최적화 → 벤치 검증 사이클.
origin: Harness
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
