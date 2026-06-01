---
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
  - "**/Cargo.lock"
---
# Rust 훅

> [common/hooks.md](../common/hooks.md) 를 확장한다.

## PostToolUse — 편집 후 자동 실행

- **cargo fmt** — `.rs` 파일 편집 후 자동 포맷
- **cargo clippy** — 편집 후 린트 (`-- -D warnings`)
- **cargo check** — 빠른 타입·빌드 검증 (전체 빌드 전 선행)

## 커밋 전 체크

```bash
cargo fmt --check                          # 포맷 미준수 감지
cargo clippy --all-targets -- -D warnings  # 경고를 에러로 차단
cargo check --all-features                 # 빌드 검증
cargo nextest run                          # 테스트 (또는 cargo test)
cargo audit                                # 의존성 취약점
```

> 저지연 프로젝트는 핫패스 변경 시 `cargo bench` 추가 — p99 회귀 시 푸시 차단.
