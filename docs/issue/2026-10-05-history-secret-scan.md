---
Title: "[audit] git 이력 비밀값·개인정보 1회 점검 (2026-10-05)"
creation: 2026-10-05
modification: 2026-10-05
status: "done"
tags:
 - "arachne"
 - "security"
 - "issue"
 - "severity/low"
aliases:
 - "history-secret-scan-2026-10"
---
MOC:: [[Arachne]]
FROM:: [[2026-10-05-roadmap-w1]]

# [audit] git 이력 비밀값·개인정보 1회 점검

- **작성일**: 2026-10-05
- **심각도**: low (실제 비밀값·개인정보 없음)
- **영역**: 저장소 전체 이력 (`git log --all -p`)
- **상태**: done

이 문서는 로드맵 결정 D-19에 따라 저장소 이력 전체를 한 번 점검한 결과다. 앞으로 새 커밋은
`hooks/guard-secrets.sh`가 커밋 직전에 검사하므로, 이 점검은 가드가 생기기 전에 들어간 내용을
확인하는 용도다. **값은 기록하지 않고 위치(커밋·파일)만 남긴다.**

## 결과

비밀값 패턴에 10건이 걸렸고, 모두 실제 비밀값이 아니었다. 개인정보(검증 자리가 맞는
주민등록번호, Luhn이 맞는 카드번호)는 0건이었다.

| 유형 | 커밋 | 파일 | 판정 |
| --- | --- | --- | --- |
| API 키 접두(`sk-`) | `225aa9c` | `docs/issue/2026-06-07-*` 4개 | 오탐 — 링크 속 파일명 `atask-correctness-…`의 일부 |
| API 키 접두(`sk-`) | `3e56ab6` | `docs/task/2026-06-07-atask-correctness-hardening.md` | 오탐 — 위와 같음 |
| API 키 접두(`sk-`) | `6dba1fe` | `tests/feedback.bats` | 테스트용 가짜 키 |
| PG 접속 문자열 | `1bf77dd`, `66f1308` | `skills/docker-patterns`, `skills/deployment-patterns` | 문서 예시(`user:pass` 형태) |

## 후속 조치

- 교체(rotate)할 비밀값은 없다.
- 첫 번째 오탐은 가드의 버그를 드러냈다. `sk-` 앞에 단어 경계가 없어서 파일명이 들어간 문서를
  커밋할 때마다 막혔을 것이다. 같은 날 키 패턴 세 개(`AKIA`·`sk-`·`gh*_`)에 단어 경계를 넣고
  회귀 테스트를 추가했다(`tests/guard_hooks.bats`).

## 재현

```bash
git log --all -p --no-color --format='@@COMMIT %h' | awk '...'   # 패턴은 hooks/guard-secrets.sh 와 동일
```
