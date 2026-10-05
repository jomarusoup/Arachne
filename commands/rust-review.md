---
description: 소유권·unsafe·async 블로킹·Result 처리·FFI 경계·의존성 감사 종합 Rust 리뷰 — rust-reviewer 에이전트 호출
---

# /rust-review — Rust 코드 리뷰

**rust-reviewer** 에이전트를 호출해 Rust 소유권·안전성·동시성 관점의 종합 리뷰를 수행한다.

## 동작

1. **규칙 로드** — 에이전트가 `rules/systems/philosophy.md` §12와 `rules/rust/*.md`를 먼저 읽는다
2. **변경 식별** — `git diff`로 수정된 `.rs`·`Cargo.toml`·`Cargo.lock`·`build.rs`·FFI 헤더 탐색
3. **정적 분석** — `cargo clippy -- -D warnings` · `cargo test` · (가능하면) `cargo deny check`·`cargo audit`
4. **unsafe·FFI** — `// SAFETY:` 근거, NULL·포인터 수명, `#[repr(C)]` 레이아웃 일치, `catch_unwind`
5. **에러 처리** — `let _ =` 무시, `unwrap_or_default` 기본값 은폐, `unwrap`·`expect` 경계
6. **동시성** — async 안 블로킹, `Arc<Mutex>` 확산, 무상한 채널, 원자적 연산 오더링 근거
7. **리포트** — 심각도별 분류

## 언제 사용하나

- `.rs` 모듈·`Cargo.toml` 작성·수정 후, 커밋 전
- C 모듈을 Rust로 옮기거나 FFI 경계를 바꿨을 때
- 의존성을 추가·갱신했을 때

품질·주석·네이밍 같은 공통 항목은 `code-reviewer`와 함께 실행한다. DB 접근 코드는 `/database-review`.

## 리뷰 카테고리

### CRITICAL (반드시 수정)
- `// SAFETY:` 근거 없는 `unsafe`, NULL 미검사 C 포인터 역참조
- `extern "C"` 함수에서 panic이 C로 넘어감 (`catch_unwind` 누락)
- 경계 구조체 `#[repr(C)]` 누락·크기 불일치, C 정수를 `enum`으로 직접 변환
- 쿼리 `format!` 결합, 셸 `-c` 명령 결합, 비밀값·개인정보 `Debug` 출력

### HIGH (수정 권장)
- `let _ =`·`.ok()`로 `Result` 무시, `unwrap_or_default()`로 실패 은폐
- 외부 입력 경로의 `unwrap`·`expect`
- async 안 블로킹 호출, `.await` 너머 `std::sync::Mutex` 가드
- `Arc<Mutex<T>>` 확산, 근거 없는 `unbounded` 채널
- 빌림으로 충분한 `clone()`, 핫패스 할당

### MEDIUM (검토)
- cargo-deny·audit 미적용, 사유 없는 `#[allow]`
- `bool` 플래그 조합 상태, 합의 없는 `pub` API 변경

## 자동 검사

```bash
cargo clippy --all-targets -- -D warnings
cargo test
cargo +nightly miri test                     # unsafe·FFI 모듈이 있을 때
cargo deny check && cargo audit
grep -rnE 'let _ = |\.unwrap\(\)|unbounded' src/
```

## 흔한 수정 패턴

```rust
// 무시된 Result
let _ = file.sync_all();                                  // BAD
file.sync_all().context("주문 로그 fsync 실패")?;          // GOOD

// async 안 블로킹
std::thread::sleep(Duration::from_millis(10));            // BAD
tokio::time::sleep(Duration::from_millis(10)).await;      // GOOD

// 무상한 채널
let (tx, rx) = tokio::sync::mpsc::unbounded_channel();    // BAD
let (tx, rx) = tokio::sync::mpsc::channel(STORE_QUEUE_CAP); // GOOD (send().await = 백프레셔)
```

## 승인 기준

| 상태 | 조건 |
| ---- | ---- |
| 승인 | CRITICAL·HIGH 없음 |
| 경고 | HIGH만 존재 (주의 후 머지) |
| 차단 | CRITICAL 존재 |

## 연계

- 공통 품질·주석·네이밍은 `code-reviewer`, DB 접근은 `/database-review`
- 커밋 전 검증은 `/verify`
- 규칙 `rules/rust/*.md`·`rules/systems/philosophy.md`, 스킬 `rust-patterns` · `rust-testing` · `c-to-rust-migration` · `stream-pipeline-patterns`
- 에이전트: `agents/rust-reviewer.md`
