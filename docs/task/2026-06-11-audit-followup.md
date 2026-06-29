---
Title: "[task] 아키텍처 감사 후속 — 잔존 항목 추적"
creation: 2026-06-11
modification: 2026-06-11
status: "to do"
tags:
 - "arachne"
 - "task"
 - "audit"
 - "priority/medium"
aliases:
 - "audit-followup"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-11-architecture-audit]]

# [task] 아키텍처 감사 후속 — 잔존 항목 추적

- **상태**: planned (트리거 대기 항목 포함)
- **우선순위**: medium
- **담당**: unassigned
- **관련 문서**: [[2026-06-11-architecture-audit]], CHANGELOG-AUDIT.md

## 목표

2026-06-11 아키텍처 감사에서 **자동 수정하지 않고 남긴 항목**을 잃어버리지 않게 추적한다.
각 항목에 "언제 하는가"(트리거)를 명시해, 시점이 오기 전에는 작업하지 않는다(과투자 방지).

## 완료된 것 (이 task 범위 아님)

- 1차 자동 패치 A-01~A-11, 2차 Phase 2 패치 A-12~A-19 — 전부 CHANGELOG-AUDIT.md에 기록.
- F-06(minimal profile)은 "의도적 최소 게이트"로 **결정 확정** — PROJECT-CI.md에 문서화 완료.

## 잔존 항목과 트리거

### 1. F-01 — uninstall + 복구 가이드 [HIGH]

- **내용**: `arachne --uninstall`(심볼릭·bin·dotfile 마커·settings 제거) + RECOVERY 문서
  (`.bak` 의미, 수동 복원 절차). 현재 `.bak`은 재설치마다 덮어써 1세대만 남는다.
- **트리거**: **다른 사람 또는 새 머신에 Arachne를 배포하는 시점.** 단일 사용자·기존 머신
  동안은 보류.

### 2. F-03 — statusline macOS 호환 [MEDIUM]

- **내용**: `statusline-command.sh`의 주간 리셋 계산이 GNU `date -d` 전용 — BSD date(macOS
  기본)에서 고장. epoch 산술로 이식하거나 macOS 분기.
- **트리거**: **macOS 머신을 실제 사용하기 시작할 때.** 현 주력(Rocky/RHEL)에선 영향 없음.

### 3. F-07 후속 — 릴리스 태그·CHANGELOG 정책 [LOW]

- **내용**: VERSION 파일 단일화는 완료(A-14). 남은 것: 버전 올리는 기준, git tag 규칙,
  사용자용 CHANGELOG(감사용 CHANGELOG-AUDIT와 별개) 운영 여부 결정.
- **트리거**: 외부 배포 시작 또는 "특정 시점으로 롤백"이 실제로 필요해질 때 (F-01과 함께).

### 4. 운영 로그 표준 (감사 Missing Design #3) [MEDIUM]

- **내용**: 훅은 전부 quiet-fail인데 실패가 어디에도 안 남는다. `~/.claude/logs/`에
  best-effort 로그(크기 상한·로테이션) 정의.
- **트리거**: 훅 동작 문제를 한 번이라도 사후 추적해야 했을 때.

### 5. Phase 4 — 구조 단순화 (대규모, 승인 필요) [보류]

자동 수정 금지 범위. 각각 별도 승인 후 진행:

- **5a. 언어 자산 pack화** — Python·Web=기본 설치, systems(C/C++/Rust/Go)·network=opt-in.
  현재 2·3순위 언어 자산이 전체의 60%+. *트리거: rules/skills 유지보수가 실제로 부담될 때,
  또는 시스템 프로그래밍 프로젝트가 장기간 없을 때.*
- **5b. install.sh 분리** — 설치(install)와 프로젝트 CI(init-ci/project-check/new)를 별 파일로.
  *트리거: install.sh가 1,200줄을 넘거나 profile이 5종 이상이 될 때.*
- **5c. 3-레인 문서 사본 축소** — 사람용 문서(README·USAGE·MULTI-CLI·ARCHITECTURE)의 중복
  표를 줄이고 workflow.md(SSOT) 링크로 수렴. *A-13의 토큰 검사로 드리프트 위험이 낮아져
  긴급도 하락 — 무기한 보류 가능.*

### 6. 별도 트랙 — data-handling-hardening P1 (이 task 아님)

`/database-review` 커맨드, `docs/DATA-HANDLING.md`, DB fixture CI gate는
[[2026-06-09-data-handling-hardening]]의 P1 체크리스트를 따른다. **다음 작업으로 가장 권장.**

## 검증

각 항목 착수 시 공통:

```bash
shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh
bats tests/*.bats
bash tests/validate_settings.sh && bash tests/check_index.sh && bash tests/check_convention_sync.sh
```

## 완료 조건

- 모든 항목이 ① 구현 완료 ② 명시적 폐기 결정 ③ 트리거 미도래 보류 중 하나로 분류 유지된다.
- 트리거가 도래한 항목은 별도 task로 승격해 진행한다.

## 진행 기록

### 2026-06-11

- 감사 1차(A-01~A-11)·2차(A-12~A-19) 패치 완료 후 잔존 항목을 이 task로 이관.
- F-06은 작업이 아니라 설계 결정으로 종결(PROJECT-CI.md 명시).
