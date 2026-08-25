---
Title: "[task] PC-8 실험 — PreToolUse·PostToolUse의 서브에이전트 발화 확정"
creation: 2026-08-25
modification: 2026-08-25
status: "to do"
tags:
 - "arachne"
 - "task"
 - "priority/medium"
aliases:
 - "hook-subagent-experiment"
---
MOC:: [[Arachne]]
FROM:: [[2026-08-22-harness-runtime-audit]]

# [task] PC-8 실험 — PreToolUse·PostToolUse의 서브에이전트 발화 확정

- **상태**: to do
- **우선순위**: medium
- **담당**: unassigned
- **관련 문서**: [[2026-08-22-harness-runtime-audit]] (Q2 [추정] 잔여), [[0003-dynamic-workflows-adoption]] (PC-8)

## 목표

감사 Q2에서 [추정]으로 남은 "PostToolUse·PreToolUse 훅이 서브에이전트(Task 도구)의
도구 호출에도 발화하는가"를 실험 1회로 확정한다. 결과는 C-08(프롬프트 의존 게이트)의
구조 계층 이관 설계 — 훅으로 막을 수 있는가 vs CI 단독인가 — 를 가른다.

## 범위

- 포함: 실험 1회 + 결과를 감사 보고서 Q2에 "검증 결과"로 추가 기록
- 제외: 훅 신설·수정(결과 확정 후 별도 task), Q1(rules 주입 — 미해결 확정 종료)

## 작업 목록

- [ ] 실험: Write·Edit 도구를 가진 에이전트(`tdd` 또는 `debugger`)에 스크래치 `*.sh` 파일
  편집을 지시하고, `doc-drift-check.sh`(PostToolUse Edit|Write) 알림 출현 여부 +
  세션 마커 `${ARACHNE_STATE_DIR:-$HOME/.claude}/.docdrift-seen-<session_id>` 생성
  여부를 파일시스템 증거로 확인
- [ ] 결과를 감사 보고서 Q2 절에 기록 (발화함 / 발화 안 함 / 관측 불가 — (b)를 (a)로
  읽지 않는다)
- [ ] "발화 안 함"이면 ADR-0003 반증 조건 4 발동 검토(강제 지점 CI 단독 재설계 —
  ADR 개정 발의)

## 검증

```bash
ls -la ~/.claude/.docdrift-seen-* 2>/dev/null   # 실험 전후 마커 비교
```

기대: 실험 전후 마커·알림의 유무가 판정 근거로 기록된다.

## 완료 조건

- 감사 보고서 Q2의 [추정] 표기가 실험 근거를 갖춘 확정 판정으로 갱신된다.

## 진행 기록

### 2026-08-25

- task 생성: ADR-0003 결과 절 "PC-8은 도입과 무관하게 수행"에서 파생.
