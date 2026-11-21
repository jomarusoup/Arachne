---
Title: "혼합 언어 프로젝트(C+Rust+Python) 지원 공백 — Python 범위 밖 결정과 실사용 충돌"
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

# 혼합 언어 프로젝트(C+Rust+Python) 지원 공백 — Python 범위 밖 결정과 실사용 충돌

- **상태**: draft
- **Arachne 버전**: 1.5.0
- **실행 환경**: Rocky Linux 9.8, Claude Code CLI, Arachne 1.5.0 (`~/.claude` 심볼릭 연결)
- **관련 명령**: `arachne init-ci`, `/python-review`, `python-reviewer` 에이전트 (아카이브 예정 자산)
- **제출 URL**:
- **제출 시각**:

## 요약

Arachne ADR-0008(2026-11-21)은 Go·Python 등 GC 런타임 언어를 모든 계층에서 범위 밖으로 정하고, 계획 2-1에서 `python-reviewer`·`/python-review`·`rules/python/`·python profile 등을 아카이브할 예정이다.
같은 날 이 프로젝트(C 서버 + Rust 클라이언트, 투자 판단 에이전트 서버)의 설계는 텍스트 처리 계층(볼트 마크다운 파싱, 한글 출력, 사후 채점, LLM 에이전트)을 Python 프로세스로 두었다.
**하네스를 쓰는 프로젝트가 범위 밖 언어를 쓸 때의 정책(비지원 선언, 대체 권고, 최소 지원)이 문서에 없어서**, 아카이브가 실행되면 해당 코드는 하네스 지원 없이 남는다.

## 기대 동작

- `docs/OBJECTIVES.md` §2가 "범위 밖"의 의미를 **사용 프로젝트 관점에서도** 정한다: 완전 비지원인지, 규칙·리뷰어만 빠지고 사용은 허용인지, 사용 자체를 금지하는지.
- 비지원이 확정이라면, 사용자가 해당 계층을 범위 안 언어(Rust)로 옮길 때 참고할 가이드가 있다(특히 텍스트 처리: 마크다운·느슨한 YAML·NFC 정규화·BOM 처리·한글 출력).

## 실제 동작

- `docs/OBJECTIVES.md` §2는 "범위 밖 (아카이브 대상)"으로 Go·Python·Java·Node·TypeScript를 적을 뿐, 이 언어를 쓰는 프로젝트가 하네스에서 무엇을 기대할 수 있는지는 적지 않았다.
- ADR-0008 결정 3의 근거는 "GC 정지·메모리 증가가 메인과 같은 장비에서 메인을 방해"하는 것이다. 이 프로젝트의 Python 프로세스는 systemd 타이머로 도는 **핫패스 밖 배치**라서 같은 근거가 그대로 적용되는지 문서에서 판단할 수 없다.
- 결과적으로 이 프로젝트는 Python 규칙을 프로젝트 `AGENTS.md`에 자체 유지하고, 리뷰는 범용 `code-reviewer`에 맡겨야 한다.

## 재현 절차

1. `docs/OBJECTIVES.md` §2·§3 공통 제약과 `docs/decisions/0008-language-scope-rust-path.md` 결정 3을 읽는다.
2. `docs/task/2026-11-20-harness-direction-plan.md`의 D-07 행에서 아카이브 대상(`python-reviewer`·`/python-review`·`python/` 규칙 전체·python profile)을 확인한다.
3. 이 프로젝트 `docs/plan/PLAN.md` §3-1과 `AGENTS.md` §7의 Python 프로세스(`ingest`·`barload`·`writer`·`review`·`backtest`·`llm`·`approve`·`api`)를 본다.
4. 계획 2-1이 실행되면 3번 계층의 리뷰·규칙·profile 지원이 사라진다고 예상된다. (2-1 실행 전이라 현재는 자산이 남아 있다.)

## 영향

- 서버 프로세스 8개 중 `src/`(C) 3개를 제외한 5~8개가 하네스 지원 밖이 될 수 있다.
- 프로젝트는 텍스트 계층 언어를 (1) Python 유지 / (2) 전부 Rust / (3) `ingest`·`writer`·`review`·`backtest`만 Rust로 하고 `llm`은 단계 3에서 재결정, 셋 중에서 검토 중이다. 하네스의 정책이 이 결정의 입력이다.

## 요청

1. OBJECTIVES §2에 "범위 밖 언어를 쓰는 프로젝트" 문단을 추가해 지원 수준을 명시해 주세요.
2. **핫패스 밖 배치·타이머 프로세스**에도 GC 런타임 금지가 적용되는지, 예외 조건이 있는지 명시해 주세요(적용이라면 근거 수치는 `budgets.yaml`의 어느 항목인지).
3. Rust로 텍스트 처리 계층을 만드는 경우의 가이드(마크다운·YAML 파서 경계, 입력 검증, 퍼징)를 `rust-patterns` 등에 절로 추가하거나 별도 스킬로 안내해 주세요.
4. 아카이브(2-1) 실행 전에 영향을 받는 프로젝트가 대응할 수 있도록 공지 방식(CHANGELOG·`arachne` 업데이트 메시지)을 정해 주세요.

## 민감정보 점검

- [x] API key, token, password, cookie, session ID를 포함하지 않는다.
- [x] 비공개 프로젝트 코드, 고객 데이터, 운영 로그 원문을 포함하지 않는다.
- [x] 로컬 사용자명이나 절대 경로가 필요한 경우 마스킹했다.
- [ ] 외부 전송 전 본문 전체를 사람이 검토했다.

## 추가 메모

- 이 프로젝트의 설계 문서(`docs/plan/PLAN.md`, `docs/decisions/0007-c-python-process-boundary.md`)는 비공개 저장소 내용이므로 제출 시 링크하지 않고 위 요약만 쓴다.
- 같은 날 내려진 두 결정(하네스 ADR-0008, 프로젝트 설계 v2)이 충돌한 것이라 하네스의 오류 보고가 아니라 **정책 공백 보고**다.
