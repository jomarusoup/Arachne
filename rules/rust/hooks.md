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
cargo test --doc                           # doc 예제 (nextest 미포함 — 별도 필수)
cargo audit                                # 의존성 취약점
```

> 저지연 프로젝트는 핫패스 변경 시 `cargo bench` 추가 — p99 회귀 시 푸시 차단.

## 라이브러리·crate 추가 게이트

배포용 crate 는 위에 더해 다음을 CI job 으로 둔다 (`skills/rust-library-crate.md`):

```bash
cargo +1.65.0 build                        # MSRV 고정 검증 (rust-version 과 일치)
cargo doc --all-features --no-deps         # 문서 빌드 (broken 링크 차단)
./test                                     # feature-matrix (대표 조합 전수)
```

> 다중 플랫폼(linux·macos·windows-msvc/gnu)·크로스 타깃·`scheduled` cron 으로
> 생태계 드리프트 감지. GitHub Actions 는 `permissions: contents: read` 최소 권한.
