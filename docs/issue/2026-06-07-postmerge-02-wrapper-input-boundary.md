---
Title: "[security] 위임 래퍼에 입력 경계·최소권한 가드 부재 — 간접 프롬프트 인젝션·-w 쓰기 노출"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "postmerge-audit"
 - "issue"
 - "security"
 - "severity/high"
aliases:
 - "wrapper-input-boundary"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-postmerge-audit]]

# [security] 위임 래퍼(gtask/ctask/atask)에 입력 경계·최소권한 가드 부재

- **작성일**: 2026-06-07
- **심각도**: HIGH
- **영역**: `gemini-task.sh`, `codex-task.sh`, `arachne-task.sh`
- **상태**: 코드 확인 완료 (살균·allowlist 0건)
- **GitHub**: #38

## 문제

위임 래퍼는 사용자/파일/stdin 내용을 **그대로** 하위 CLI에 전달한다. 살균·이스케이프·신뢰 경계
구분·allowlist가 없다. 특히 `ctask -w`/`atask -w`는 Codex에 workspace-write를 부여해 파일
쓰기·실행이 가능하다.

## 재현

```bash
# 신뢰할 수 없는 외부 콘텐츠를 위임 입력에 직접 주입
gtask "이 로그 요약: $(cat untrusted_from_web.log)"   # 로그 내 숨은 지시가 모델을 조종 가능
ctask -w "이 이슈 본문대로 수정: $(cat attacker_issue.md)"   # 쓰기 모드 + 외부 지시
```

## 영향

- **간접 프롬프트 인젝션**(AI-ENGINEERING-NOTES §3): 외부 콘텐츠에 심긴 지시가 하위 모델을 조종.
- `-w` 쓰기 + 인젝션 결합 시 작업 트리 변경 위험. 통합·커밋은 Claude(`git diff` 검토 전제)이나,
  비대화·자동화 파이프라인에서는 검토가 누락될 수 있다.

## 원인

위임 래퍼가 "신뢰 경계를 넘는 텍스트를 명령으로 해석할 수 있다"는 LLM 고유 위험을 다루지 않는다.
노트 §3에 정리한 방어 원칙(최소 권한·human-in-loop·신뢰 경계 분리)이 코드에 미반영.

## 수정 방향

1. `-w`(쓰기) 모드에 명시적 경고/확인 또는 환경변수 opt-in.
2. 외부 콘텐츠를 프롬프트 본문과 **구획 분리**해 전달(예: `<<UNTRUSTED>> ... <<END>>` 마커 + 지시).
3. 위임 결과를 트리에 반영하기 전 `git diff` 검토를 도구 차원에서 유도(현재는 정책 문서에만 존재).
4. 문서에 "신뢰할 수 없는 콘텐츠를 위임 입력에 직접 넣지 말 것" 경고 추가.

## 회귀 테스트

`-w` 모드 경고 노출, 구획 마커 주입을 bats로 검증.

## 완료 조건

쓰기 모드 위임이 무경고로 실행되지 않으며, 외부 콘텐츠가 지시와 구분돼 전달된다.
