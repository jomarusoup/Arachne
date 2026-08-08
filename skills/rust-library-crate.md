---
name: rust-library-crate
description: 재사용 Rust 라이브러리·crate 저작 규율 — feature-flag 아키텍처, no_std/alloc 계층화, MSRV, 최소 의존성, 퍼징, 크로스 플랫폼·feature-matrix 테스트, docs.rs. rust-lang/regex 규약 기반.
triggers:
  paths: ["**/Cargo.toml", "**/lib.rs", "**/*.rs"]
  keywords: ["crate", "라이브러리", "no_std", "feature flag", "MSRV", "cargo-fuzz", "docs.rs", "퍼징", "publish"]
---

# Rust 라이브러리·crate 저작

`rust-patterns` 스킬이 **애플리케이션 핫패스**(tokio·lock-free·저지연) 중심이라면,
이 스킬은 **재사용 라이브러리(crate) 저작 규율**을 다룬다. 세계적 수준 범용 crate인
[`rust-lang/regex`](https://github.com/rust-lang/regex) 워크스페이스 규약에서 추출.

## 언제 사용하나

- `crates.io` 배포 또는 사내 재사용 라이브러리 작성
- 여러 소비자가 서로 다른 기능 조합으로 쓸 라이브러리 설계
- `no_std`·임베디드·WASM 지원이 필요한 crate
- feature flag·MSRV·의존성 정책을 설계할 때
- 라이브러리 CI(feature-matrix·크로스 컴파일·퍼징) 구성 시

## 언제 사용하지 않나

- 단일 바이너리 앱·서비스 → `rust-patterns`
- 저지연 핫패스 최적화 → `rust-patterns` + `performance-profiling`
- 테스트 러너·벤치마크 기본 → `rust-testing`

---

## 1. feature-flag 아키텍처 (additive)

기능은 **가산적(additive)**으로 설계한다 — feature 를 켜면 기능이 *추가*될 뿐,
켜고 끄는 조합이 서로의 동작을 바꾸면 안 된다(cargo feature unification 때문).

```toml
[features]
default = ["std"]
# std 없이도 core+alloc 으로 동작 (임베디드·WASM)
std   = ["alloc", "dep:some-optional/std"]
alloc = []
# 무거운/선택적 기능은 세분화 — 소비자가 컴파일 시간·바이너리 크기를 통제
perf-literal = ["dep:aho-corasick", "dep:memchr"]

[dependencies.aho-corasick]
version = "1.0"
optional = true            # feature 로만 끌어옴
default-features = false   # 소비자의 no_std 를 깨지 않도록
```

원칙:
- 선택적 의존성은 `optional = true` + `dep:` 문법으로 feature 에 묶는다.
- 모든 의존성에 `default-features = false` — 하위 crate 의 std 강제 전파 차단.
- feature 하나하나에 **`#` 주석으로 목적**을 단다 (regex 의 `Cargo.toml` 참고).
- `default` 는 "대부분이 원하는 최소" — 무겁거나 nightly 의존 기능은 넣지 않는다.
- **unstable/nightly 의존 기능**은 별도 feature(`unstable`)로 격리.

## 2. no_std / core / alloc 계층화

```rust
#![no_std]                          // lib.rs 최상단

#[cfg(feature = "alloc")]
extern crate alloc;                 // Vec/Box/String 은 alloc 계층

#[cfg(feature = "std")]
extern crate std;
```

- 기본은 `core` 만 가정 → `std::` 대신 `core::` 경로 사용.
- 힙 타입(`Vec`, `Box`, `String`)은 `alloc` feature 뒤에 둔다.
- `HashMap`·`std::io`·스레드는 `std` feature 뒤로 격리.

## 3. crate-root 린트 게이트

라이브러리 lib.rs 최상단에 품질 게이트를 강제한다 (regex-automata 실제 예):

```rust
#![no_std]
#![deny(missing_docs)]                    // 모든 공개 API 에 문서 강제
#![warn(missing_debug_implementations)]   // 모든 타입에 Debug 권장
// feature 조합이 최대일 때만 broken 링크를 에러로 (조합별 링크 깨짐 회피)
#![cfg_attr(all(feature = "std", feature = "nfa"),
            deny(rustdoc::broken_intra_doc_links))]
```

## 4. MSRV (Minimum Supported Rust Version)

```toml
[package]
rust-version = "1.65"    # 선언 = 계약. 올릴 땐 semver-minor 이상 + CHANGELOG 명시
```

- CI 에 **MSRV 고정 job** 을 둔다 (dev-dependencies 는 MSRV 대상에서 제외 — 보통
  "빌드만 되면 통과"). regex 는 `toolchain: 1.65.0` 로 `cargo build`·`cargo doc` 만.
- MSRV 상향은 파괴적 변경에 준한다 — 이유를 CHANGELOG 에 기록.

## 5. 최소 의존성 철학

- 의존성 추가 전: 표준 라이브러리·기존 의존성으로 해결되는지 먼저 확인.
- 추가 시 검토: 다운로드 수·유지보수 상태·`unsafe` 사용량·전이 의존성 폭발.
- **선택적**으로 넣어 소비자가 뺄 수 있게 (`optional = true`).
- `Cargo.lock` — 바이너리·재현 빌드는 커밋, 순수 라이브러리는 커밋하지 않는 것이
  관례이나 CI 재현성 목적이면 커밋 가능(정책을 CONTRIBUTING 에 명시).

## 6. 퍼징 (cargo-fuzz / libfuzzer / OSS-Fuzz)

파서·역직렬화·바이트 처리 crate 는 퍼징이 **필수 방어선**이다. proptest 가
구조적 불변식을, 퍼징이 임의 바이트에 대한 패닉·UB·무한루프를 잡는다.

```rust
// fuzz/fuzz_targets/fuzz_parse.rs
#![no_main]
use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    // 패닉·크래시가 없어야 한다 — 결과의 정확성은 검사하지 않아도 됨
    if let Ok(s) = core::str::from_utf8(data) {
        let _ = mycrate::parse(s);
    }
});
```

```toml
# fuzz/Cargo.toml — arbitrary 로 구조적 입력 생성
[dependencies]
arbitrary = { version = "1.3", features = ["derive"] }
libfuzzer-sys = { version = "0.4", features = ["arbitrary-derive"] }
```

```bash
cargo install cargo-fuzz
cargo fuzz run fuzz_parse                    # 무한 실행 (crash 시 중단)
cargo fuzz run fuzz_parse -- -max_total_time=60
```

- 크래시 재현 코퍼스(`fuzz/regressions/`)는 커밋해 회귀 테스트로 재실행.
- 장기적으로 [OSS-Fuzz](https://google.github.io/oss-fuzz/) 등록을 고려
  (`fuzz/oss-fuzz-build.sh`). 새 타깃 추가 시 빌드 스크립트에도 등록.

## 7. feature-matrix 테스트

feature 조합은 조합 폭발이라 전수는 불가 — **대표 조합**을 스크립트로 고정한다
(regex 의 `./test` 스크립트 패턴).

```bash
#!/bin/bash
set -e
cargo test                                   # default features
cargo test --no-default-features --lib       # no_std 경로
cargo test --doc                             # doc 테스트 (공개 예제 검증)
for f in "std" "std perf-literal" "std unicode"; do
    cargo test --no-default-features --features "$f"
done
```

- `--doc` 를 CI 에 반드시 포함 — 문서 예제가 컴파일·통과해야 문서가 거짓말을 안 한다.
- 느린 통합 테스트 crate 는 `Cargo.toml` 에서 `opt-level = 3` (test·dev 프로파일)로
  빌드해 실행 시간을 줄인다.

## 8. 크로스 플랫폼·엔디안

라이브러리는 소비 환경을 통제할 수 없다 — CI 매트릭스로 방어한다:

- OS: `ubuntu` · `macos` · `windows-msvc` · `windows-gnu`
- 툴체인: `stable` · `beta` · `nightly`
- 크로스 타깃(`cross`): `i686`(32비트) · `aarch64` · `powerpc`·`s390x`(빅엔디안).
  바이트 직렬화·`transmute`·정렬 가정이 빅엔디안/32비트에서 깨지는지 잡는다.
- **scheduled(cron) CI** 로 생태계 드리프트(새 nightly·의존성)를 상시 감지.
- GitHub Actions 는 `permissions: contents: read` 로 **최소 권한** 고정.

## 9. docs.rs·문서화

```toml
[package.metadata.docs.rs]
all-features = true                          # 모든 feature 문서화
rustdoc-args = ["--cfg", "docsrs_regex"]     # doc_cfg 로 feature 배지 표시
```

- 공개 API 문서(`///`)에 **실행되는 예제**를 넣는다 → `cargo test --doc` 가 검증.
- feature 게이트된 API 는 `#[cfg_attr(docsrs, doc(cfg(feature = "...")))]` 로
  "이 기능은 X feature 필요" 배지를 문서에 노출.
- CI 에 `RUSTDOCFLAGS="-D rustdoc::broken_intra_doc_links"` docs job 을 둔다.

## 배포 전 체크리스트

```bash
cargo fmt --all -- --check
cargo clippy --all-targets --all-features -- -D warnings
./test                                       # feature-matrix
cargo test --doc
cargo +nightly miri test                     # unsafe 있으면 UB 검출
cargo +1.65.0 build                          # MSRV 확인
cargo doc --all-features --no-deps           # 문서 빌드
cargo publish --dry-run                      # 패키징·include 검증
cargo semver-checks check-release            # (설치 시) API 호환성
```

- [ ] `CHANGELOG.md` 갱신 (파괴적 변경·MSRV 상향 명시)
- [ ] `version` semver 준수 (공개 API 변경 = major/minor 규칙)
- [ ] `Cargo.toml` 의 `include`/`exclude` 로 패키지에 불필요 파일 제외
