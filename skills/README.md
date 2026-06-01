# Skills

Claude Code 세션에서 호출 가능한 워크플로·도메인 스킬 모음 (17개).

`origin: Harness` — Harness 전용 작성  
`origin: ECC` — everything-claude-code에서 그대로 가져옴  
`origin: ECC (modified)` — ecc 기반으로 Harness 방향에 맞게 수정

---

## Harness 전용

| 스킬 | 설명 |
|---|---|
| `build-debug` | C/C++ 빌드·GDB 디버그 절차 |
| `memory-check` | valgrind·ASan·TSan 메모리 검사 |

## 시스템 프로그래밍

| 스킬 | 출처 | 설명 |
|---|---|---|
| `cpp-testing` | ECC | GoogleTest/CTest·sanitizer |
| `latency-critical-systems` | ECC (mod) | IPC·epoll·소켓 저지연 시스템 |
| `error-handling` | ECC (mod) | C/C++·TypeScript·Python·Go 에러 처리 |

## 언어별 패턴·테스팅

| 스킬 | 출처 | 설명 |
|---|---|---|
| `golang-patterns` | ECC | 이디엄틱 Go 패턴 |
| `golang-testing` | ECC | 테이블 드리븐·벤치마크·퍼징 |
| `python-patterns` | ECC | PEP8·타입 힌트·파이썬닉 패턴 |
| `python-testing` | ECC | pytest·픽스처·모킹·커버리지 |

## TDD·검증

| 스킬 | 출처 | 설명 |
|---|---|---|
| `tdd-workflow` | ECC | Red-Green-Refactor 범용 워크플로 |
| `verification-loop` | ECC | Claude Code 세션 검증 시스템 |

## 공통·보안

| 스킬 | 출처 | 설명 |
|---|---|---|
| `security-review` | ECC | 보안 리뷰 체크리스트 |
| `security-scan` | ECC | Claude Code 설정 보안 스캔 |

## 인프라

| 스킬 | 출처 | 설명 |
|---|---|---|
| `docker-patterns` | ECC | Docker/Compose 패턴 |

## 네트워크

| 스킬 | 출처 | 설명 |
|---|---|---|
| `network-config-validation` | community | 라우터·스위치 설정 사전 검증 |
| `network-interface-health` | community | 인터페이스 오류·CRC·플래핑 진단 |
| `netmiko-ssh-automation` | community | Python Netmiko SSH 자동화 |
