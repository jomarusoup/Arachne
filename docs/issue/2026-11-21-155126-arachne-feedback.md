---
Title: "C 서버·Rust+egui 클라이언트 프로젝트용 스킬·리뷰어 공백"
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

# C 서버·Rust+egui 클라이언트 프로젝트용 스킬·리뷰어 공백

- **상태**: draft
- **Arachne 버전**: 1.5.0
- **실행 환경**: Rocky Linux 9.8, Claude Code CLI
- **관련 명령**: `agents/`, `commands/`, `skills/`, `objectives/freeze-manifest.txt`
- **제출 URL**:
- **제출 시각**:

## 요약

Arachne ADR-0008은 메인 클라이언트를 **Rust + egui**로, 서버 메인을 **C 중심**으로 정했다. 그런데 이 구성을 직접 지원하는 자산이 부족하다.
특히 클라이언트 수신 구조 스킬(`desktop-data-client`)은 Electron·TypeScript 기준이고 D-07로 아카이브 대상이라, **Rust 클라이언트를 위한 대체 자산이 없다.**
C 전용 리뷰어, systemd 패턴, 언어 중립 골든 테스트 등도 비어 있다. 하네스 자산이 동결 상태라 추가에는 ADR이 필요하므로, 수확 원칙에 따라 공백을 기록한다.

## 기대 동작

C 서버 + Rust 클라이언트 + PostgreSQL + systemd 운영 프로젝트가 규칙·스킬·리뷰어로 지원받는다.

## 실제 동작 (2026-11-21 확인)

| # | 공백 | 확인 방법·근거 |
|---|---|---|
| 1 | **Rust + egui 클라이언트 스킬 없음.** 수신 스레드·UI 분리·화면 주기 병합·갭 재요청을 다루는 스킬이 `desktop-data-client`(Electron·TS)뿐이고 D-07 아카이브 대상 | `skills/` 본문에서 egui를 다루는 스킬을 찾지 못함. `docs/OBJECTIVES.md`·ADR-0008에만 egui 언급 |
| 2 | **C 전용 리뷰어·커맨드 없음.** `rust-reviewer`·`/rust-review`는 있으나 C는 범용 `code-reviewer`만 | `agents/`·`commands/` 목록 |
| 3 | **systemd 서비스·타이머 패턴 없음** (유닛 작성·샌드박싱·`Restart`·타이머 의존·`runs` 확인 패턴) | `skills/*/SKILL.md`에서 systemd 언급 0건. `deployment-patterns`는 일반 배포 |
| 4 | **언어 중립 골든 테스트 방법 없음** (입력 파일 → 기대 출력 파일, 언어별 러너, 케이스 공유, 기대값 독립 생성) | `golden` 언급 스킬은 `golang-testing`(Go golden file, 아카이브 대상)뿐. `api-contracts`의 공유 테스트 벡터가 가장 가깝다 |
| 5 | **C WebSocket 수신 패턴 없음** (libwebsockets, 재연결·백오프·하트비트·끊긴 구간 gap 기록) | websocket 언급 스킬은 `api-contracts`·`vite-patterns`·`desktop-data-client`·`go-http-patterns`(웹·Go 기준) |
| 6 | **DB 역할별 GRANT로 "테이블 단일 작성자"를 강제하는 모델** | `postgres-patterns`가 GRANT·최소 권한을 언급하는 것까지만 확인, 깊이 미확인 |
| 7 | **주문 게이트웨이 안전장치**(킬 스위치 파일·멱등 키·승인 유효시간·미확정 차단·감사 로그) | `trading-systems` 스킬이 이 용도에 맞는지 미확인 |

## 재현 절차

1. `ls skills agents commands`로 목록을 확인한다.
2. `grep -rli "egui\|systemd" skills/*/SKILL.md`, `grep -rli "golden" skills/*/SKILL.md`로 위 표의 근거를 확인한다.
3. `docs/task/2026-11-20-harness-direction-plan.md`의 D-07에서 `desktop-data-client` 아카이브 결정을 확인한다.

## 영향

- 프로젝트가 이 영역을 프로젝트 `AGENTS.md`·자체 문서에 규칙으로 직접 적어야 한다. 하네스 규칙이 아니라 프로젝트 규칙이 되어 다른 프로젝트로 재사용되지 않는다.
- 클라이언트 수신 구조(ADR-0008의 "클라이언트는 서버를 막지 않는다", 코어 crate·UI 분리)는 하네스의 핵심 목표인데 이를 지원하는 스킬이 아카이브로 사라질 예정이다.

## 요청 (우선순위)

| 우선순위 | 요청 |
|---|---|
| 높음 | `desktop-data-client`를 **Rust + egui 기준으로 재작성**해 대체(코어 crate·UI 분리, 수신 스레드, 갭 재요청, 화면 주기 병합, 가짜 데이터로 개발)하고, 재작성 전에 TS판을 아카이브하지 않는 순서를 검토해 주세요 |
| 높음 | C 전용 리뷰어(`c-reviewer`)와 `/c-review` 커맨드 (소유권 주석·`goto cleanup`·고정소수점·sanitizer 게이트 점검 항목) |
| 높음 | 언어 중립 골든 테스트 스킬 (케이스 디렉터리 규약, 언어별 러너, 기대값 생성 기록) |
| 중간 | systemd 서비스·타이머 스킬 (샌드박싱 옵션·`runs` 의존·재시작·로그) |
| 중간 | C WebSocket 수신(libwebsockets) 패턴을 `c-server-patterns` 또는 `stream-pipeline-patterns`에 절로 추가 |
| 낮음 | PostgreSQL 역할별 GRANT·단일 작성자 모델을 `postgres-patterns`에 절로 추가 |
| 확인 | `trading-systems`의 범위가 주문 게이트웨이 안전장치를 포함하는지 문서화 |

동결 규칙(`objectives/freeze-manifest.txt`)상 신규 자산은 ADR + 같은 PR의 행 추가가 필요하다는 점을 알고 있다. 이 문서는 그 ADR의 근거 기록으로 쓰는 것을 전제로 한다.

## 민감정보 점검

- [x] API key, token, password, cookie, session ID를 포함하지 않는다.
- [x] 비공개 프로젝트 코드, 고객 데이터, 운영 로그 원문을 포함하지 않는다.
- [x] 로컬 사용자명이나 절대 경로가 필요한 경우 마스킹했다.
- [ ] 외부 전송 전 본문 전체를 사람이 검토했다.

## 추가 메모

- 6·7번은 "없다"가 아니라 "이 용도에 충분한지 확인하지 못했다"는 뜻이다. 하네스 담당자가 해당 스킬 본문을 보고 판단해 주기 바란다.
