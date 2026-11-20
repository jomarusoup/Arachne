---
Title: "ADR-0007 하네스 방향 전환 — 저지연 시스템 북극성, 네이티브 클라이언트, 동결과 평가 우선"
creation: 2026-11-20
modification: 2026-11-20
tags:
 - "arachne"
 - "decision"
 - "objectives"
aliases:
 - "adr-harness-direction"
---
MOC:: [[Arachne]]
FROM:: [[2026-11-20-harness-direction-plan]]

# ADR-0007: 하네스 방향 전환 — 저지연 시스템 북극성, 네이티브 클라이언트, 동결과 평가 우선

## 상태

Accepted (2026-11-20 사용자 확정 — 방향·범위·계층·운영 원칙·단계는 사용자가 확정한 사항)

## 배경

1. W6 인벤토리 기준 하네스는 스킬 65·에이전트 12·커맨드 24로 커졌고, 상시 로드 지시 파일만
   약 9.8k 토큰(추정)이다([계획 §1.1](../task/2026-11-20-harness-direction-plan.md#11-상시-로드-자산)).
   자산이 실제 작업 성과에 기여하는지 측정하는 수단(eval)이 없다.
2. [ADR-0006](0006-roadmap-2026q4.md) D-02(Electron 통일)의 근거인
   [처리량 PoC](../issue/2026-10-05-throughput-poc-result.md)는 macOS M1 localhost에서 **수신·해석만** 쟀다.
   디코딩·상태 갱신·렌더링·장시간 GC·RSS 추세는 측정하지 않았다(PoC "측정의 한계").
3. 실제 목표는 Linux 저지연 시스템과 그 성능을 받쳐 주는 클라이언트다. 웹·Java·FastAPI·React 계열
   자산은 이 목표에 쓰이지 않는다.

## 결정

1. **목표 정본을 둔다.** 북극성·우선순위·범위·계층·운영 원칙은 [`docs/OBJECTIVES.md`](../OBJECTIVES.md),
   예산 수치는 [`objectives/budgets.yaml`](../../objectives/budgets.yaml)에만 둔다. rules·eval·CI는 참조만 한다.
2. **우선순위는 정확성 > 장애 격리 > 성능 > 개발 효율.** 성능을 위해 검증을 덜어내는 변경은 기각한다.
3. **클라이언트는 네이티브 직접 개발한다.** 툴킷은 계획 결정 D-01에서 정한다.
4. **신규 규칙·스킬 추가를 동결한다.** `tests/freeze.bats`가 강제한다. 해제는 ADR로만 한다.
5. **변경은 측정 후에.** eval 기준선(계획 3-6) 이후 기존 자산 변경·삭제는 eval 전후 비교를 거친다.
6. **push는 사용자 확인 후에만** 한다. main 자동 병합은 금지, 개선 작업은 worktree에서만 한다.

### 대체하는 기존 결정

| 기존 | 내용 | 이 ADR의 처리 |
|---|---|---|
| ADR-0006 D-02 | 데스크톱 클라이언트 TypeScript(Electron) 통일 | **대체** — 네이티브 직접 개발 |
| ADR-0006 D-12 (typescript-reviewer 신설), D-13 (`rules/react/` 신설) | 웹·TS 자산 | **대체** — 범위 밖, 계획 2-1에서 아카이브 |
| ADR-0006 D-06 | "Rust는 C 모듈의 점진 이식 대상" | **확장** — Rust는 메인 계층 상주 언어이자 유틸 언어. C 서버 골격(epoll·불투명 핸들)은 유지 |
| ADR-0005 D08 | "클라이언트는 런타임 이식성에 위임" | **클라이언트 부분만 대체** — 서버 리눅스 전용 허용은 유지 |
| ADR-0006 D-09·D-20·D-21 | 개발 Mac·키체인 전제 | **비밀값 보관 결정은 유지**, 성능 예산의 기준은 홈랩 Linux 장비 |
| ADR-0004 | AGENTS.md·어댑터를 "재도입 대비"로 유지 | **보류** — 멀티-CLI 재도입은 하지 않는다. 어댑터 처리는 계획 결정 D-08 |

ADR-0003(dynamic workflows 미도입)은 이 ADR과 독립이다. 5단계 개선 루프는 systemd 타이머와
`claude -p` 스크립트이며 dynamic workflows가 아니다. 0003의 지위는 계획 결정 D-13.

## 대안

- **현행 유지 + 스킬 보강**: 측정 없이 자산이 계속 늘어난다. 기여 여부를 판정할 수 없어 기각.
- **Electron 유지, 렌더링 측정 후 재판정**: 범위가 네이티브로 확정됐고, 웹 계열 자산 유지 비용이 남는다. 기각.
- **즉시 대규모 정리(아카이브 + 다이어트)**: 기준선 없이 지우면 효과를 알 수 없다. 아카이브는 2단계,
  다이어트·제거 실험은 eval 기준선 이후(4단계)로 미룬다.

## 결과

- 실행 계획과 결정 레지스터: [하네스 방향 계획](../task/2026-11-20-harness-direction-plan.md).
- 1단계 산출물: `docs/OBJECTIVES.md`, `objectives/budgets.yaml`(수치는 "실측 대기"),
  `objectives/freeze-manifest.txt`, `tests/objectives.bats`, `tests/freeze.bats`, `docs/template/failure.md`,
  `rules/common` 3개·`commands/git.md`의 push 전 확인 전환.
- ADR-0005·0006 본문은 기록이므로 고치지 않는다. 대체 관계는 이 ADR이 정본이다.

## 검증

```bash
bats tests/objectives.bats tests/freeze.bats
bash tests/check_index.sh && bash tests/check_convention_sync.sh
grep -rnE '자동 (git )?push|자동 푸시' rules commands   # 0건
```
