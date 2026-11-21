---
Title: "Arachne 목표 정본 — 북극성·범위·계층·운영 원칙"
creation: 2026-11-20
modification: 2026-11-21
status: "in progress"
tags:
 - "arachne"
 - "objectives"
aliases:
 - "objectives"
---
MOC:: [[Arachne]]
FROM:: [[2026-11-20-harness-direction-plan]]

# Arachne 목표 정본

> **단일 정본.** 하네스의 목표와 예산은 이 문서와 [`objectives/budgets.yaml`](../objectives/budgets.yaml)에만
> 둔다. rules·eval·CI는 이 두 파일을 **참조만** 하고 수치나 목표를 복사하지 않는다.
> 결정 배경은 [ADR-0007](decisions/0007-harness-direction-lowlatency.md), 실행 계획은
> [하네스 방향 계획](task/2026-11-20-harness-direction-plan.md).

## 1. 북극성

리눅스에서 **정확하고 장애가 격리된 저지연 시스템**, 그리고 그 성능을 병목 없이 받쳐 주는
**클라이언트**를 만드는 데 이 하네스가 실제로 기여해야 한다.

**우선순위: 정확성 > 장애 격리 > 성능 > 개발 효율.**
성능을 위해 검증(테스트·sanitizer·불변식 검사)을 덜어내는 변경은 기각한다.

## 2. 범위

| 구분 | 대상 |
|---|---|
| 메인 언어 | C, C++, Rust, Go |
| 유틸 언어 | Python, Shell |
| 웹 | 모니터링 전용 |
| 성능 클라이언트 | 네이티브 직접 개발 |
| 범위 밖 (아카이브 대상) | Java, FastAPI, React, TypeScript, Electron, 디자인 계열 |

## 3. 계층 정의

### 서버

| 계층 | 정의 | 언어 |
|---|---|---|
| 메인 | 지연 예산 경로 위 상주 프로세스 | C, C++, Rust |
| 보조 | 핫패스 밖 상주 컨트롤 플레인 | Go 주력 |
| 유틸 | 단발 운영 도구 | 핵심 데이터 구조를 만지면 C·Rust·cgo Go / 조회는 Shell / 가공은 Python / 오프라인 배포는 Go 정적 바이너리 |

### 클라이언트

| 계층 | 정의 |
|---|---|
| 메인 | 네이티브 |
| 보조 | 모니터링 웹 |
| 유틸 | 리플레이어, 송신기 등 |

### 공통 제약

- **Go는 핫패스 금지.** 메인 계층의 지연 예산 경로에 Go 코드(cgo 콜백 포함)를 두지 않는다.
  보조 계층이 공유메모리를 읽는 cgo 리더는 읽기 전용 매핑이고 메인의 진행을 막지 않으면 핫패스가 아니다.
- **의존 방향은 메인 ← 보조 ← 유틸.** 보조·유틸이 메인에 의존하고, 메인은 보조·유틸 없이 동작한다.
  보조·유틸의 장애가 메인의 정확성이나 지연 예산을 침범하면 결함이다.
- **핫패스 할당 0.** 워밍업 이후 메인 계층의 지연 예산 경로에서 동적 할당을 하지 않는다
  (예산 `server.main.hotpath_alloc`).
- **클라이언트는 서버를 막지 않는다.** 느린 클라이언트 때문에 서버 메인의 송신 경로가 블로킹되는
  시간은 0이다(예산 `client.main.server_send_block_time`). 따라잡지 못하는 클라이언트의 처리는
  서버의 진행을 멈추지 않는 방식으로만 한다.
- **유틸은 메인을 늦추지 않는다.** 유틸 실행 중 메인 지연 증가분은 실측 후 예산으로 정한다
  (예산 `server.util.main_latency_delta_while_running`).
- **계약 정본은 메인 소유**: 공유메모리 C 헤더, `frame_codec`, REST. 보조·유틸·클라이언트는 정본에서
  생성하거나 정본의 테스트 벡터로 검증한다.
- **상태 변경 유틸의 의무**: 조회가 기본 동작, 변경은 `--apply`로만, dry-run 제공, 락, 감사 로그.

## 4. 운영 원칙

1. **수확 원칙** — 하네스 자산은 실제 작업에서 같은 실패가 **2회 이상** 반복될 때만 추가한다.
2. **실행 우선** — 같은 실패를 막는 수단이 둘 다 있으면 문장 규칙보다 훅·검사 스크립트·템플릿·측정 도구를 택한다.
3. **단일 정본** — 목표와 예산은 이 문서와 `objectives/budgets.yaml`에만 둔다.
4. **측정 후 변경** — eval 기준선 확보(계획 작업 3-6) 이후 기존 자산의 변경·삭제는 eval 전후 비교가 필수다.
5. **축소 지향** — 모델이 좋아질수록 하네스는 줄어야 한다. 제거 실험(ablation)을 정기적으로 한다.

## 5. 동결 (2026-11-20부터)

- **신규 규칙(`rules/`)·에이전트(`agents/`)·커맨드(`commands/`) 아래 모든 파일과 신규 스킬(`skills/` 최상위 항목)
  추가를 동결한다.** 강제: [`tests/freeze.bats`](../tests/freeze.bats)가
  [`objectives/freeze-manifest.txt`](../objectives/freeze-manifest.txt) 밖의 항목을 거부한다.
  아카이브(삭제)는 허용된다 — 매니페스트에서 해당 행을 지운다.
- 해제·예외는 ADR로만 하고, 같은 PR에서 매니페스트를 갱신한다. 강제:
  [`tests/check_freeze_adr.sh`](../tests/check_freeze_adr.sh)(CI `verify-freeze`)가 매니페스트 항목 행이 추가된
  diff에 `docs/decisions/` 신규 ADR이 없으면 실패한다.
- 2단계(시스템 루프) 동안 허용되는 하네스 변경은 범위 밖 자산 아카이브뿐이다.

## 6. 금지와 경계

- `~/.claude`의 항목들은 이 저장소 main 체크아웃을 가리킨다. 개선 작업은 **worktree에서만** 한다.
  main 자동 병합은 금지다.
- 회사 시스템의 소스·수치·구조를 반입하지 않는다(공개 저장소). 참조는 오픈소스(Aeron, LMAX Disruptor,
  Chronicle Queue, Seastar 등)의 설계 패턴·측정 방법론·실패 사례로 한정한다.
- 멀티-CLI 재도입, 새 언어 프로필 추가, 실행 과제로 이어지지 않는 문서 작성은 하지 않는다.
- push는 사용자 확인 후에만 한다(`rules/common/workflow.md`).

## 7. 예산

수치는 [`objectives/budgets.yaml`](../objectives/budgets.yaml)이 정본이다. 형식 검사는
[`tests/objectives.bats`](../tests/objectives.bats). 모든 항목은 `status`·`source`를 가지며,
`status: 실측 대기`인 항목은 `value: null`이다 — 출처 없는 수치는 넣지 않는다.
