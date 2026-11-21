---
Title: "arachne -t --check가 프로젝트 요구 도구(clang·개발 헤더·DB 서버)를 점검하지 못함"
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

# arachne -t --check가 프로젝트 요구 도구(clang·개발 헤더·DB 서버)를 점검하지 못함

- **상태**: draft
- **Arachne 버전**: 1.5.0
- **실행 환경**: Rocky Linux 9.8 (dnf), Claude Code CLI
- **관련 명령**: `arachne -t --check`, `arachne -t`
- **제출 URL**:
- **제출 시각**:

## 요약

`arachne -t --check`는 하네스 기본 그룹(필수·C/C++·Rust·Python 린터·DB 클라이언트 등)만 점검한다. C 서버 + PostgreSQL + WebSocket 수신 프로젝트가 실제로 필요로 하는
**clang 계열(libFuzzer·clang-tidy), 개발 헤더 라이브러리, DB 서버, Rust 린터·포매터**가 점검 대상에 없고, **프로젝트별 요구 도구를 선언할 방법**도 없다.
스킬(`c-testing` 등)은 퍼징·정적 분석을 권장하는데 도구 점검은 그 전제를 확인하지 않아, 첫 빌드·검증 시점에야 누락이 드러난다.

## 기대 동작

- C/C++ 그룹이 sanitizer·퍼징·정적 분석에 필요한 도구(clang, clang-tidy, libFuzzer 지원 여부)를 점검한다.
- 프로젝트가 필요한 시스템 라이브러리(예: libpq, libcurl, libwebsockets, jansson)와 서비스(PostgreSQL 서버)를 선언하면 `-t --check`가 함께 점검하고 설치 명령을 안내한다.
- Rust 그룹이 `cargo` 외에 `rustfmt`·`clippy`를 점검한다.

## 실제 동작

2026-11-21 `arachne -t --check` 출력(요약):

- `C/C++ 시스템 — 누락: cmake perf cppcheck clang-format / 설치됨: gcc g++ make gdb valgrind strace ltrace` — `clang`·`clang-tidy`는 점검 항목에 없다.
- `Rust — 누락: cargo` — `rustfmt`·`clippy`는 점검 항목에 없다.
- `DB 클라이언트 — 누락: sqlite3 / 설치됨: psql` — DB **서버**와 개발 헤더(`pg_config`)는 점검하지 않는다.
- 개발 헤더 라이브러리(pkg-config 기반) 점검 항목이 없다.
- 프로젝트가 요구하는 도구를 하네스에 알리는 파일·옵션이 문서에서 확인되지 않는다.

같은 서버에서 직접 확인한 결과: `clang`·`clang-tidy`·`cppcheck`·`libpq`·`libcurl`·`libwebsockets`·`jansson` 개발 파일이 모두 없고, PostgreSQL은 클라이언트 16만 설치되어 있었다.

## 재현 절차

1. clang이 설치되지 않은 Rocky 9 서버에서 `arachne -t --check`를 실행한다.
2. 출력의 C/C++ 그룹에 clang 계열이 없음을 확인한다.
3. `command -v clang clang-tidy cargo`, `pkg-config --exists libpq libcurl libwebsockets jansson`을 실행해 하네스가 알려 주지 않은 누락을 확인한다.

## 영향

- libFuzzer 퍼징(`c-testing`)과 clang-tidy 정적 분석을 쓰려는 프로젝트가 첫 CI 실행에서 실패한 뒤에야 누락을 안다.
- 프로젝트 문서(`AGENTS.md`)에 필요한 패키지를 수동으로 나열하고 사람이 대조해야 한다.

## 요청

1. C/C++ 그룹에 `clang`, `clang-tidy`(Rocky: `clang`, `clang-tools-extra`)를 추가하고 libFuzzer 사용 가능 여부(`-fsanitize=fuzzer`)를 확인해 주세요.
2. Rust 그룹에 `rustfmt`·`clippy` 점검을 추가해 주세요.
3. 프로젝트 파일(예: `.arachne/tools`)에 필요한 명령·pkg-config 패키지·서비스를 선언하고 `arachne -t --check --project`로 점검하는 기능을 검토해 주세요.
4. 점검 결과에 배포판별 설치 명령(Rocky: AppStream·EPEL·CRB 구분)을 함께 보여 주세요. 일부 `-devel` 패키지는 CRB 저장소가 필요할 수 있습니다.

## 민감정보 점검

- [x] API key, token, password, cookie, session ID를 포함하지 않는다.
- [x] 비공개 프로젝트 코드, 고객 데이터, 운영 로그 원문을 포함하지 않는다.
- [x] 로컬 사용자명이나 절대 경로가 필요한 경우 마스킹했다.
- [ ] 외부 전송 전 본문 전체를 사람이 검토했다.

## 추가 메모

- 같은 조회 중 서드파티 저장소(PGDG)의 GPG 서명 검증 오류로 `dnf` 조회가 실패했다. 이는 서버 상태 문제이지 하네스 결함은 아니다. 다만 `arachne -t` 설치 경로가 저장소 오류를 만났을 때 안내하는 메시지가 있는지는 확인하지 않았다.
- `jansson-devel`이 기본 저장소 조회에 나오지 않았다(CRB 필요 가능성, 미확인).
