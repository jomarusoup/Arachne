---
Title: "프로젝트 CI profile이 단일 언어·고정 레이아웃이라 혼합 구조 프로젝트에 맞지 않음"
creation: 2026-11-21
modification: 2026-11-21
status: "draft"
tags:
 - "arachne"
 - "feedback"
aliases:
 - "arachne-feedback"
---
MOC:: [[MIT-BE]]
FROM:: [[empty]]

# 프로젝트 CI profile이 단일 언어·고정 레이아웃이라 혼합 구조 프로젝트에 맞지 않음

- **상태**: draft
- **Arachne 버전**: 1.5.0
- **실행 환경**: Rocky Linux 9.8, Claude Code CLI
- **관련 명령**: `arachne init-ci --profile <profile>`, `.arachne/verify.sh`, `/verify`
- **제출 URL**:
- **제출 시각**:

## 요약

프로젝트 CI는 `.arachne/profile`에 **profile 하나**(`minimal|python|web|python-web|cpp|rust|c-system`)만 둘 수 있다.
C 서버 + Rust 클라이언트(Cargo workspace) + SQL 계약 + 언어 중립 골든 테스트처럼 **여러 언어·디렉터리 규약이 섞인 프로젝트**는 어느 profile도 맞지 않는다.
`c-system` profile은 스타터 키트(`src/log`·`src/shm`·`tools/`·`sql/`·`conf/`·`docs/ops/`)를 복사하고 그 경로를 검증하는 명령을 기본으로 가져, 프로젝트가 자체 레이아웃을 쓰면 충돌하거나 무의미한 검사가 된다.

## 기대 동작

- 프로젝트가 profile 여러 개를 조합하거나(예: C + Rust), commands 조각을 합성할 수 있다.
- 스타터 키트를 복사하지 않거나, 복사 경로를 바꿀 수 있다.
- 지원 profile이 없는 구조라도 `minimal`에서 출발해 언어별 검사 블록을 쉽게 붙일 수 있는 예시가 있다.

## 실제 동작

- `docs/PROJECT-CI.md`에는 profile이 7개 단일 값으로 정의돼 있고, CI 런타임 준비는 "`.arachne/profile`을 읽어 런타임(Python·Node·Rust)을 준비하는 데만 쓴다"고 적혀 있다. 여러 런타임을 동시에 준비하는 방법은 문서에서 확인하지 못했다.
- `templates/project/profiles/c-system/commands`는 `make -C src/log test`, `make -C src/shm test`, `make -C tools`, `bash sql/apply-schema.sh --dialect postgres --dir sql ...`을 기본 포함한다. 이 경로가 없는 프로젝트에서는 주석 처리·삭제를 사람이 해야 한다.
- 프로젝트가 `minimal`을 선택하면 `commands`는 `git diff --check` 한 줄이라, `/verify`가 코드를 전혀 검증하지 못한다.

## 재현 절차

1. 프로젝트에서 `.arachne/profile`이 `minimal`인 상태로 `cat .arachne/commands`를 본다(`git diff --check`뿐).
2. 레이아웃이 `server/src/<프로세스>/`, `server/lib/`, `server/utl/`, `contracts/schema/`, `client/`(Cargo workspace)인 프로젝트에서 `arachne init-ci --profile c-system`을 실행했을 때 복사될 키트 경로(`src/log`·`tools/`·`sql/`)와 비교한다.
3. `--profile`에 `c-system,rust`처럼 둘을 주는 방법을 `docs/PROJECT-CI.md`에서 찾는다 — 방법이 확인되지 않는다.

## 영향

- 프로젝트가 `minimal` + 수동 `commands` 작성으로 우회해야 하고, 하네스가 제공하는 `c-system` 검증(ASan/UBSan 모듈 테스트, 스키마 명명 점검, 네이밍 사전 검사)을 일부만 가져다 쓸 수 있다.
- 첫 마일스톤(M0)에서 빈 CI가 "통과"로 보이는 상태가 오래 남을 수 있다.

## 요청

1. profile 복수 지정(`--profile c-system,rust`) 또는 `commands.d/` 조각 합성을 지원해 주세요.
2. `init-ci`에 `--no-kit`(키트 복사 안 함)과 `--kit-map src=...,tools=...`(경로 매핑) 옵션을 추가해 주세요.
3. 키트 없이 쓸 수 있는 `c-system-lite`(C 빌드·asan·valgrind·lint 블록만) profile을 검토해 주세요.
4. `sql/apply-schema.sh` 등 키트 스크립트의 대상 디렉터리를 인자화해 주세요.
5. `minimal` profile의 `commands`에 언어별 검사 블록 예시(주석)를 넣어 혼합 프로젝트가 출발점으로 쓸 수 있게 해 주세요.

## 민감정보 점검

- [x] API key, token, password, cookie, session ID를 포함하지 않는다.
- [x] 비공개 프로젝트 코드, 고객 데이터, 운영 로그 원문을 포함하지 않는다.
- [x] 로컬 사용자명이나 절대 경로가 필요한 경우 마스킹했다.
- [ ] 외부 전송 전 본문 전체를 사람이 검토했다.

## 추가 메모

- 프로젝트의 디렉터리 이름(`utl/`, `contracts/schema/`)은 `c-system` 키트(`tools/`, `sql/`)와 의미가 같지만 이름이 다르다. 키트 경로 매핑 옵션이 있으면 하네스 검증을 그대로 재사용할 수 있다.
