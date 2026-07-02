---
Title: "ADR-0002 지시서 하네스 + 외부 분석 플러그인 이원 구조"
creation: 2026-07-02
modification: 2026-07-02
tags:
 - "arachne"
 - "decision"
 - "architecture"
 - "plugins"
aliases:
 - "adr-external-analysis-plugins"
---
MOC:: [[Arachne]]
FROM:: [[Arachne]]

# ADR-0002: 지시서 하네스 + 외부 분석 플러그인 이원 구조

## 상태

Accepted

## 배경

Arachne의 콘텐츠 계층(rules·skills·agents·commands)은 마크다운 지시서이고, 분석 엔진은
LLM 세션 자체다. 반면 결정론적(코드로 구현된) 분석 파이프라인 — 저장소 스캔, 지식그래프,
심볼 인덱스 — 은 전부 외부 플러그인이 담당한다:

- **Understand-Anything(UA)**: scan → analyze → knowledge-graph.json (Claude Code 로컬
  마켓플레이스 플러그인, `/understand*` 진입)
- **codegraph**: 심볼 정의·참조·영향 범위 인덱스 (`.codegraph/codegraph.db`, npm CLI)

2026-07-02 전체 구조 감사에서 이 구조가 리스크 1순위로 지적됐다: 스캔·그래프·리포트가
Arachne가 통제하지 못하는 서드파티에 있어, 업스트림 변경·중단 시 대체 수단이 없다.
자체 결정론 분석 계층을 만들 것인지 결정이 필요했다.

## 결정

**이원 구조를 유지한다.** Arachne는 자체 스캐너·그래프·심볼 인덱서를 구현하지 않고,
지시서 하네스(본체) + 외부 분석 플러그인(선택 확장)의 분리를 공식 구조로 확정한다.

대신 Arachne가 **계약 지점(integration contract)** 을 소유한다:

| 계약 지점 | 소유 파일 | 역할 |
| --- | --- | --- |
| 설치·갱신 | `setup-extras.sh` (`arachne --extras`) | 클론·마켓플레이스 등록·버전 갱신, URL·경로 환경변수 오버라이드 |
| 신선도 감시 | `hooks/ua-stale-check.sh` | UA 그래프가 HEAD보다 뒤처지면 세션 시작 시 경고 |
| 조사 라우팅 | `rules/common/performance.md`, `commands/codegraph.md` | codegraph 우선·sgrep 폴백 규칙 |
| 검증 영속화 | `commands/verify.md` STEP 3 (`.arachne/reports/`) | 분석·검증 증거는 플러그인이 아닌 Arachne 규약으로 보존 |
| 폴백 | `sgrep`(dotfiles), 미설치 감지 안내 | 플러그인 부재 시에도 조사 워크플로 동작 |

## 대안

1. **자체 결정론 분석 계층 구현** — 통제력은 얻지만 스캐너·그래프·언어 파서의 유지비가
   하네스 본체(지시서·배선)보다 커진다. UA·codegraph가 이미 80% 이상을 해결하므로
   `development-workflow §0 조사·재사용` 원칙("검증된 구현이 있으면 채택")에 반한다.
2. **UA 포크(fork) 유지** — 업스트림 개선을 수동 추적해야 하고, 로컬 마켓플레이스 사본이
   사실상 스냅샷 역할을 이미 하고 있어 얻는 것이 적다.
3. **플러그인 제거(순수 지시서 하네스)** — 구조 파악·영향 분석을 전부 LLM 재량 grep에
   의존하게 되어 토큰 비용과 재현성이 나빠진다.

## 결과

- 외부 종속 리스크는 수용하되, 위 계약 지점이 완충한다: 로컬 클론이 스냅샷으로 남고
  (`~/.claude/plugins/marketplaces/`), `setup-extras.sh`의 `*_URL`·`*_CLONE` 환경변수로
  포크·미러 전환이 가능하다. 업스트림이 중단되면 그 시점 사본으로 동작이 유지된다.
- 분석 **산출물의 수명 관리**(stale 감지·리포트 영속화)는 Arachne 책임, 분석 **알고리즘**은
  플러그인 책임 — 이 경계를 넘는 기능 요구는 새 ADR로 재검토한다.
- 플러그인 없는 환경(솔로 모드)은 성능 저하만 있고 기능 상실은 없어야 한다 —
  조사 라우팅 규칙이 폴백(sgrep)을 항상 정의한다.
