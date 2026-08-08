---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---
# Rust 보안

> [common/security.md](../common/security.md) 를 확장한다.

## unsafe 블록 규칙

- `unsafe` 는 최소 범위로 격리하고 바로 위에 안전성 근거(`// SAFETY:`) 주석 필수
- 안전한 대안이 있으면 `unsafe` 금지 — 성능 측정으로 정당화된 경우만 허용
- crate 단위로 `#![forbid(unsafe_code)]` 우선, 불가피한 모듈만 예외

```rust
// SAFETY: idx < len 을 호출부에서 검증했으므로 경계 내 접근 보장
let tick = unsafe { buf.get_unchecked(idx) };
```

- `// SAFETY:` 는 "안전함"이 아니라 **어떤 불변식이 성립하므로 안전한지** 그 논증을
  적는다 (regex-automata 는 unsafe 57곳마다 근거 주석 병행).
- `unsafe impl` 트레이트에도 각 메서드 구현이 왜 계약을 지키는지 근거를 남긴다.

## 메모리 안전성

- 미정의 동작 검출: `cargo +nightly miri test` (unsafe·FFI 있으면 CI 필수)
- 정수 오버플로 — 핫패스는 `wrapping_*`/`checked_*` 명시, 디버그 빌드 패닉 의존 금지
- FFI 경계에서 널 포인터·정렬·수명 직접 검증
- **바이트 직렬화·`transmute`·정렬 가정**은 빅엔디안·32비트에서 깨질 수 있다 —
  크로스 타깃(`i686`·`s390x` 등) CI 로 검증 (`skills/rust-library-crate.md`)
- **적대적 입력 방어는 퍼징으로** — 파서·역직렬화는 `cargo fuzz` 로 패닉·UB·DoS
  (무한루프·과대 할당) 를 상시 검출 (`rules/rust/testing.md`)

## 비밀값 관리

```rust
let key = std::env::var("API_KEY")
    .expect("API_KEY 환경변수 필요");   // 시작 시점 검증만 expect 허용
```

> 비밀값은 `secrecy::Secret<T>` 로 감싸 로그·`Debug` 출력 노출 차단.

## 공급망 보안

```bash
cargo audit                      # RustSec 취약점 DB 대조
cargo deny check                 # 라이선스·중복·금지 crate 검사
cargo update --locked            # Cargo.lock 고정 빌드
```

- 의존성 추가 시 다운로드 수·관리 상태·`unsafe` 사용량 검토
- `Cargo.lock` 커밋 필수 (바이너리·재현 빌드 보장)
