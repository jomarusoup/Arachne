---
Title: "[task] 사용 프로젝트 피드백 4건 분류·반영 (2026-11-21)"
creation: 2026-11-21
modification: 2026-11-21
status: "done"
tags:
 - "arachne"
 - "task"
 - "priority/medium"
aliases:
 - "project-feedback-triage-2026-11-21"
---
MOC:: [[Arachne]]
FROM:: [[2026-11-21-155122-arachne-feedback]]

# [task] 사용 프로젝트 피드백 4건 분류·반영 (2026-11-21)

- **상태**: done
- **우선순위**: medium
- **담당**: Claude Code (분류·즉시 반영분), 사람 (결정 대기분)
- **관련 문서**: [F1 언어 범위 공백](../issue/2026-11-21-155122-arachne-feedback.md),
  [F2 CI profile](../issue/2026-11-21-155123-arachne-feedback.md),
  [F3 도구 점검](../issue/2026-11-21-155125-arachne-feedback.md),
  [F4 스킬·리뷰어 공백](../issue/2026-11-21-155126-arachne-feedback.md),
  [하네스 방향 계획](2026-11-20-harness-direction-plan.md), [OBJECTIVES](../OBJECTIVES.md)

## 목표

C 서버 + Rust 클라이언트 사용 프로젝트가 2026-11-21에 남긴 피드백 4건의 요청을 하나씩
**즉시 반영 / 사람 결정 대기 / 수확 대기**로 분류하고, 동결(OBJECTIVES §5)과 수확 원칙(§4-1)을
어기지 않는 범위만 바로 고친다. 나머지는 근거와 함께 이 문서와 계획 결정 레지스터에 남긴다.

## 범위

- 포함: `lib/toolchain.sh` 도구 카탈로그(F3), OBJECTIVES §2 범위 밖 언어 정책 문단(F1),
  계획 결정 레지스터·위험 메모(F1·F2·F4), issue 인덱스.
- 제외: `rules/`·`agents/`·`commands/`·`skills/` 신규 추가(동결 — ADR 필요),
  프로젝트 CI profile 구조 변경(F2 — 2-2에서 실패 기록 후 4-4 판정), 기존 스킬 본문 보강(수확 대기).

## 분류

판정 기준: 동결 대상 추가는 ADR 없이 하지 않는다. 같은 실패가 1회 기록된 요청은 수확 대기(2회째에 실행
자산 또는 ADR). 이미 정해진 원칙에서 바로 도출되는 문서 공백과 동결 밖 실행 자산(CLI·검사)은 즉시 반영한다.

| 출처 | 요청 | 판정 | 처리 |
|---|---|---|---|
| F1-1 | OBJECTIVES §2에 범위 밖 언어 사용 프로젝트의 지원 수준 | 즉시 반영 | OBJECTIVES §2 "범위 밖 언어를 쓰는 사용 프로젝트" |
| F1-2 | 핫패스 밖 배치·타이머에도 GC 금지가 적용되는지, 근거 예산 | 즉시 반영 (기존 정의에서 도출) | 같은 문단 — 배치·타이머는 유틸 계층, 근거 `server.util.main_latency_delta_while_running` |
| F1-3 | Rust 텍스트 처리 계층 가이드(마크다운·YAML 경계·검증·퍼징) | 수확 대기 (1회) | 2회째 실패 시 `rust-patterns` 절 보강 — 기존 스킬 본문 수정이라 동결 대상은 아니다 |
| F1-4 | 아카이브(2-1) 전 사용 프로젝트 공지 방식 | 즉시 반영 | 계획 2-1 산출물에 공지 항목 추가 (MINOR 커밋 제목 + PR 본문 영향 자산·복원 절차) |
| F2-1 | profile 복수 지정 또는 `commands.d/` 합성 | 보류 확정 (D-18) | 계획 D-18 — 2-2 파이프라인 프로젝트(C + Rust)가 같은 문제를 겪는지 기록 후 4-4에서 판정 |
| F2-2 | `init-ci --no-kit`·`--kit-map` | 보류 확정 (D-18) | D-18에 포함 |
| F2-3 | `c-system-lite` profile | 보류 확정 (D-18) | D-18에 포함. "새 언어 프로필 추가 금지"(§6)와는 별개(언어가 아니라 키트 유무)지만 profile 수를 늘리므로 사람 판단 |
| F2-4 | 키트 스크립트 대상 디렉터리 인자화 | 보류 확정 (D-18) | D-18에 포함 |
| F2-5 | `minimal` commands에 언어별 검사 블록 예시 주석 | 보류 확정 (D-18) | D-18에 포함 — 템플릿 변경이라 4-4(템플릿 승격) 경로 |
| F3-1 | C/C++ 그룹에 clang·clang-tidy | **반영 완료** | `lib/toolchain.sh` 카탈로그 (dnf `clang`·`clang-tools-extra`, apt `clang`·`clang-tidy`) |
| F3-1 | libFuzzer(`-fsanitize=fuzzer`) 사용 가능 여부 | 수확 대기 | 명령 존재 검사 밖(컴파일 시험)이라 별도 설계 필요. 2-8 파이프라인 CI의 `cargo-fuzz`·libFuzzer 단계에서 실패가 나오면 재검토 |
| F3-2 | Rust 그룹에 rustfmt·clippy | **반영 완료** | 카탈로그 + 신규 방식 `rustup:<컴포넌트>` → `rustup component add` 한 번으로 설치, rustup 없으면 안내만 |
| F3-3 | 프로젝트 요구 도구 선언(`.arachne/tools`)·`--check --project` | 보류 확정 (D-18) | D-18과 같은 판정 경로(2-2에서 반복 확인) |
| F3-4 | 배포판별 설치 명령(AppStream·EPEL·CRB) | 수확 대기 | EPEL은 이미 자동 처리. CRB 필요 `-devel` 패키지는 F3-3이 생길 때 함께 |
| F4-1 | `desktop-data-client` Rust + egui 재작성, 재작성 전 TS판 아카이브 보류 | 확정 (D-17 (b)) | 계획 D-17 — 아카이브 시점(2-1 vs 2-7 이후). 재작성 자체는 2-7 산출물에서 4-4 승격 |
| F4-2 | C 전용 리뷰어 `c-reviewer`·`/c-review` | 수확 대기 (1회) | 계획 D-14 집계에 1회로 기록. 2회째에 ADR + 매니페스트 |
| F4-3 | 언어 중립 골든 테스트 스킬 | 수확 대기 (1회) | `api-contracts` 공유 테스트 벡터가 가장 가깝다. 동결 대상 신규 스킬이라 ADR 필요 |
| F4-4 | systemd 서비스·타이머 스킬 | 수확 대기 (1회) | 계획 5-5가 `.timer`·`.service`를 직접 만든다 — 그 실행 결과를 근거로 판단 |
| F4-5 | C WebSocket(libwebsockets) 수신 절 | 수확 대기 (1회) | 기존 스킬 절 보강 후보 |
| F4-6 | PostgreSQL 역할별 GRANT·단일 작성자 | 수확 대기 (1회) | 기존 스킬 절 보강 후보 |
| F4-7 | `trading-systems` 범위가 주문 게이트웨이 안전장치를 포함하는지 | **확인 완료** | 포함: 주문 전 하드 한도 리스크 게이트, 내부·외부 킬스위치(관리 명령·시그널, 해제는 사람만), 중복 ClOrdID 거부(멱등 키 역할), 전 결정 append-only 감사 로그. 미포함: 사람 승인의 유효시간, 응답 미확정 주문이 있을 때 신규 주문 차단. 미포함 2개는 수확 대기 (1회) |

## 작업 목록

- [x] 4건 분류표 작성 (이 문서)
- [x] F3-1·F3-2 도구 카탈로그 + 회귀 테스트 (`tests/toolchain.bats` 3건)
- [x] F1-1·F1-2 OBJECTIVES §2 문단
- [x] F1-4·F2·F4-1·F4-2 계획 반영 (2-1 공지, D-14 집계, D-17·D-18)
- [x] issue 인덱스에 4건 등록
- [x] D-17·D-18 사람 결정 — 권장안대로 확정 (2026-11-21)
- [x] F4-7 `trading-systems` 범위 확인 (`skills/trading-systems/SKILL.md` 208~217행·리스크 게이트 예제)

## 검증

```bash
bats tests/toolchain.bats
shellcheck lib/toolchain.sh
bash tests/check_index.sh
bats tests/*.bats
```

`toolchain.bats`의 신규 3건(기본 카탈로그·component add 묶음·rustup 없음 안내)을 포함해 전부 통과한다.

## 완료 조건

- 분류표의 "즉시 반영" 항목이 모두 반영되고 검증 명령이 통과한다.
- "결정 대기" 항목(D-17·D-18)이 사람 결정으로 확정되거나 다음 task로 넘어간다.
- "수확 대기" 항목은 2회째 기록이 생기기 전까지 이 표가 집계 기준이다.

## 진행 기록

### 2026-11-21

- task 생성: 피드백 4건(F1~F4)을 분류. 즉시 반영은 도구 카탈로그(F3-1·F3-2)와 문서 정책 공백(F1-1·F1-2·F1-4).
- 피드백 원문 4건은 수정하지 않고 그대로 보존한다(초안 상태, 외부 전송 전 검토 미완 표시 포함).
- D-17·D-18 권장안 확정(사람 결정). D-17: `desktop-data-client`는 2-1 대상에서 빼고 2-7 대체 후 아카이브. D-18: 보류, 2-2에서 재발하면 4-4에서 판정.
- 완료 조건 충족으로 `done`. 수확 대기 항목은 위 분류표가 1회차 집계 기준으로 남는다.
