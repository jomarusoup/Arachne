---
Title: "ADR-0002 systems(cpp·rust) project profile"
creation: 2026-07-17
modification: 2026-07-17
tags:
 - "arachne"
 - "decision"
 - "cpp"
 - "rust"
aliases:
 - "adr-systems-profiles"
---
MOC:: [[Arachne]]
FROM:: [[0001-python-web-profile]]

# ADR-0002: systems(cpp·rust) project profile

## 상태

Accepted

## 배경

Arachne의 규칙·스킬·에이전트 계층은 시스템 프로그래밍(C/C++·Rust)이 가장 두텁지만,
프로젝트 CI 계약(profile)은 python·web 계열만 제공해 systems 프로젝트는 `minimal`
(공백 검사만)로 시작해야 했다 — 개발 중 품질 계층과 부트스트랩 계층의 비대칭.

## 결정

`cpp`·`rust` profile을 추가해 `arachne -n`/`init-ci`가 빌드+테스트+sanitizer 게이트를
시작점으로 생성한다.

- **cpp**: CMake(기본, Makefile 대체 주석) → ASan/UBSan 플래그 빌드 → ctest.
  TSan·cppcheck·valgrind는 주석 게이트 (TSan은 ASan과 동시 사용 불가 — 별도 빌드).
- **rust**: `cargo fmt --check` → `clippy -D warnings` → `build/test --locked`.
  cargo-audit·nextest·miri는 주석 게이트.
- workflow(arachne.yml): `rust`는 dtolnay/rust-toolchain@stable(+rustfmt·clippy),
  `cpp`는 러너 사전 설치 도구(gcc·cmake·ctest) 사용 — 추가 셋업 없음.

## 근거

- 메모리 검사(ASan/TSan/valgrind)는 rules/common/testing.md 가 시스템 코드에 필수로
  규정 — 검증 계약에도 기본 게이트로 반영하는 것이 자기규칙 일관성.
- `.arachne/commands`는 프로젝트 소유(재실행 시 보존)라 템플릿은 강제가 아닌 시작점 —
  F-06(언어 도구 비강제)의 정신 유지: 안 맞으면 프로젝트가 편집한다.
- sanitizer 기본값을 ASan+UBSan으로 한 것은 오탐 없이 즉시 가치가 있고 CI 비용이 낮아서.
  TSan은 ASan과 배타적이라 opt-in.

## 영향

- `ValidateProjectProfile`·usage·docs(USAGE·PROJECT-CI·README)·tests 가 6개 profile로 확장.
- design docs 생성(`ProfileHasDesignDocs`)은 web 계열 전용 그대로 — systems 프로필 무관.
