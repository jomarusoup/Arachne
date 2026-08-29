---
Title: MULTI-CLI
creation: 2026-06-05
modification: 2026-08-29
Description: 공통 규약(AGENTS.md) 다중 CLI 배포 가이드 — Claude·Gemini·Codex·Copilot 어댑터
tags:
aliases:
---

# Multi-CLI Guide — 공통 규약(AGENTS.md) 배포

> **운용 형태**: 현재 하네스는 **Claude Code 단독 운용**이다. 과거의 3-레인 협업 런타임
> (위임 래퍼 `gtask`/`ctask`·가용성 폴백 `atask`)은
> [ADR-0004](decisions/0004-remove-3lane-runtime.md)로 [`archive/multi-cli/`](../archive/multi-cli/)에
> 보존·제거됐다(재도입 절차 포함). 이 문서는 **유지되는 계층** — 공통 규약(`AGENTS.md`)을
> 여러 CLI에 배포하는 방법 — 만 다룬다. 제거 전 전체 가이드 원문은
> [archive/multi-cli/MULTI-CLI.md](../archive/multi-cli/MULTI-CLI.md).

## 1. SSOT 배포 — 어댑터 비대칭

`AGENTS.md`가 공통 규약의 단일 진실 공급원(SSOT)이다. import 지원이 도구마다 달라
연결 방식이 비대칭이다:

| CLI | 연결 파일 | 연결 방식 | 반영 시점 | 무엇을 보나 |
| --- | --- | --- | --- | --- |
| **Claude Code** | `~/.claude/rules/` (+ `CLAUDE.md`) | 디렉터리 심볼릭 → **네이티브 자동 로드** | 다음 세션 | `rules/`의 **풀 디테일** (AGENTS.md보다 상세) |
| **Gemini CLI** | `~/.gemini/GEMINI.md` | **AGENTS.md 심볼릭** | **즉시** (재설치 0회) | AGENTS.md 다이제스트 |
| **Codex CLI** | `~/.codex/AGENTS.md` | **AGENTS.md 마커 병합** | `arachne -i --target codex` 재실행 후 | AGENTS.md 다이제스트 |
| **GitHub Copilot** | 저장소 `AGENTS.md` + `~/.copilot/` | 자동 발견 + **마커 병합** | 저장소는 즉시, 전역은 `--target copilot` 후 | AGENTS.md 다이제스트 |

- **공통 규약**(작업 원칙·코딩 스타일·패턴·보안·테스트·git·이슈·언어 포인터)은 `AGENTS.md`에만 둔다.
- **도구 전용 기능**(Claude의 서브에이전트·훅·슬래시 커맨드·모델 라우팅)은 `CLAUDE.md`/`rules/`에만 둔다.
- Codex는 심볼릭이 아니라 **AGENTS.md 수정 후 재병합 필요** — `arachne --check`가 stale을 잡는다.
- 설치는 미감지 도구를 건너뛴다(graceful skip) — Claude 단독 환경에서 비용 0.

## 2. 각 CLI 단독 사용

어느 CLI를 단독으로 띄우든 읽는 공통 규약은 동일하다. 훅·에이전트·커맨드는 Claude 전용이며,
어느 CLI가 작성했든 **최종 게이트는 프로젝트 CI**(`.arachne/verify.sh`·GitHub Actions)다.

```bash
gemini            # 대화형 — ~/.gemini/GEMINI.md(→AGENTS.md) 자동 로드
gemini -p "..."   # 비대화 1회 (헤드리스는 --skip-trust 필요)
codex             # 대화형 — ~/.codex/AGENTS.md(병합본) 자동 로드
codex exec "..."  # 비대화 1회
```

## 3. 상태 점검 — `arachne --check`

설치·심볼릭·병합본의 stale 여부를 점검한다. 상세는 [USAGE](USAGE.md) 설치 절 참고.

## 4. 재도입

다른 CLI를 위임·폴백 구조로 다시 쓰려면 [archive/multi-cli/README.md](../archive/multi-cli/README.md)의
재도입 절차를 따른다 — 감사 미수리 결함 선수리와 ADR-0004 supersede가 선행 조건이다.

> 관련: [AGENTS.md](../AGENTS.md) · [ARCHITECTURE](ARCHITECTURE.md) · [GLOSSARY](GLOSSARY.md)
