---
Title: "ADR-0004 3-레인 협업 런타임 제거 — 규약 배포 계층 유지"
creation: 2026-08-29
modification: 2026-08-29
tags:
 - "arachne"
 - "decision"
 - "multi-cli"
aliases:
 - "adr-remove-3lane"
---
MOC:: [[Arachne]]
FROM:: [[2026-08-22-harness-runtime-audit]]

# ADR-0004: 3-레인 협업 런타임 제거 — 규약 배포 계층 유지

## 상태

Accepted (2026-08-29 사용자 승인)

## 배경

3-레인 협업(Claude 오케스트레이터 / Codex tester·fixer / Gemini reader·advisor)은 위임 래퍼
(`gemini-task`/`codex-task`)·가용성 폴백(`arachne-task`)·쿼터 쿨다운·경고 훅으로 구현돼 있었다.
그러나:

1. **실사용 0** — 운용 머신은 솔로 모드(Codex·Gemini CLI 미설치)로, 래퍼 호출은 전부 127
   가드로 끝났다(계측 실측). 사용자 확인: 현재 전 머신 Claude Code만 사용, 타 도구는 미래 가능성.
2. **결함 백로그 집중** — [감사](../issue/2026-08-22-harness-runtime-audit.md)의
   B-01~03(쿼터 오판)·B-07(훅 순서 중복)·B-08(백오프 부재)·C-01~04(상태 파일 경합 일체)가
   전부 이 런타임에 있다. 제거로 수리 필요 자체가 소멸한다.
3. **매 세션 토큰 비용** — `rules/common/workflow.md`(3-레인 다이제스트)가 매 세션 로드됐다.
4. **문서 3중화** — USAGE·MULTI-CLI·ARCHITECTURE가 같은 구조를 중복 서술(감사 B-1 계열).

## 결정

**3-레인 협업 런타임을 `archive/multi-cli/`로 이동해 현역에서 제거한다.
규약 배포 계층은 유지한다.**

| 계층 | 조치 | 이유 |
| --- | --- | --- |
| 위임 래퍼 3종·`atask-quota-warn.sh` 훅·전용 테스트 4종·계측(MetricAppend) | **archive 이동** + settings/install/CI 배선 해제 | 실사용 0, 결함 집중 |
| `rules/common/workflow.md` | 3-레인 다이제스트 제거 → 전역 행동 규칙만 | 매 세션 로드 비용 |
| `AGENTS.md`(SSOT)·install.sh의 Gemini/Codex/Copilot 어댑터 | **유지** | 업계 표준 규약 파일 + 미감지 시 graceful skip으로 무해, 타 도구 재도입 발판 |
| `/handoff` 커맨드 | 유지 (문구 일반화) | 솔로에서도 세션 인계에 유효 |
| 감사·ADR-0003 등 기록 문서 | 원문 유지 | 기록은 재작성하지 않는다 |

## 대안

- **현상 유지**: 결함 수리(PC-1~4) 비용을 계속 지불하면서 사용되지 않는 구조를 유지 — 기각.
- **완전 삭제**: git 히스토리에만 의존 — 사용자가 "나중에 다른 툴 사용 가능성"을 밝혀
  archive 보존 선택.
- **비활성화(등록만 해제)**: 파일이 현역 트리에 남아 인덱스·테스트·문서 동기화 비용 지속 — 기각.

## 결과

- 결함 백로그 9건(B-01~03·07·08, C-01~04) 수리 대상에서 소멸 —
  [[2026-08-25-pc-defect-repair]] task 범위 축소(B-04·05·11 잔존).
- 계측 기준선([[2026-08-25-metrics-baseline]]) 조기 종결 — 측정 대상 소멸.
  ADR-0003의 재평가 트리거 중 "오프로드 절약 실측" 축은 무의미해지고,
  "감사 fan-out 한계 2회 문서화" 축만 유효하게 남는다(ADR-0003 자체는 유지).
- 재도입 절차는 [archive/multi-cli/README.md](../../archive/multi-cli/README.md)가 정본 —
  재도입 시 미수리 결함 선수리 + 본 ADR supersede 필요.

## 검증

```bash
bats tests/*.bats && bash tests/check_index.sh && bash tests/check_convention_sync.sh \
  && bash tests/validate_settings.sh
grep -rn 'gtask\|ctask\|atask' install.sh install.ps1 settings.template.json .github/workflows/  # 0건
```
