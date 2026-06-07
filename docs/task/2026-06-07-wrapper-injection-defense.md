---
Title: "[task] 위임 래퍼 입력 경계·최소권한 가드 도입 (프롬프트 인젝션 방어)"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "project"
 - "task"
 - "security"
 - "priority/high"
aliases:
 - "wrapper-injection-defense"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-postmerge-02-wrapper-input-boundary]]

# [task] 위임 래퍼 입력 경계·최소권한 가드 도입

- **상태**: planned
- **우선순위**: high
- **담당**: unassigned
- **관련 문서**: #38, [[2026-06-07-postmerge-02-wrapper-input-boundary]], [AI-ENGINEERING-NOTES §3](../AI-ENGINEERING-NOTES.md)

## 목표

`gtask`/`ctask`/`atask`가 신뢰할 수 없는 외부 콘텐츠를 지시와 구분해 전달하고, 쓰기 모드(`-w`)가
무경고로 실행되지 않게 하여 간접 프롬프트 인젝션·의도치 않은 트리 변경 위험을 낮춘다.

## 범위

- 포함: `gemini-task.sh`, `codex-task.sh`, `arachne-task.sh`, 관련 문서, `tests/*.bats`
- 제외: 모델 내부 안전성(통제 불가), 네트워크 격리

## 작업 목록

- [ ] 외부 콘텐츠를 지시와 **구획 분리**하는 입력 규약 도입(예: `<<UNTRUSTED>> ... <<END>>` 마커 + 처리 지시)
- [ ] `-w`(workspace-write) 모드에 경고 출력 또는 환경변수 opt-in(`CASK_ALLOW_WRITE` 등)
- [ ] 위임 결과를 트리에 반영하기 전 `git diff` 검토를 유도하는 안내/가드
- [ ] 문서에 "신뢰할 수 없는 콘텐츠를 위임 입력에 직접 넣지 말 것" 경고 추가(USAGE·MULTI-CLI)
- [ ] 회귀 테스트: `-w` 경고 노출, 구획 마커 주입 검증
- [ ] `shellcheck` + 전체 bats 통과

## 검증

```bash
ctask -w "x"            # 경고 또는 opt-in 요구 확인
bats tests/atask.bats tests/*.bats
```

쓰기 모드가 무경고로 실행되지 않고, 외부 콘텐츠가 지시와 분리돼 전달된다.

## 완료 조건

- `-w` 위임이 명시적 동의 없이 실행되지 않는다.
- 외부 콘텐츠 구획 규약이 코드·문서·테스트에 반영된다.
- AI-ENGINEERING-NOTES §6의 주제3 상태가 "미적용" → "적용"으로 갱신 가능.

## 진행 기록

### 2026-06-07

- task 생성: 노트 §3 방어 원칙이 코드에 미반영(가장 큰 지식↔코드 격차)이라 우선순위 high로 분리.
