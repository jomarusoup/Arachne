---
Title: "[docs] 하네스 핵심 역할·플랫폼 호환성 설명 정확화"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "arachne"
 - "documentation"
 - "workflow"
 - "platform"
aliases:
 - "harness-role-platform-accuracy"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [docs] 하네스 핵심 역할·플랫폼 호환성 설명 정확화

- **작성일**: 2026-06-07
- **심각도**: HIGH
- **영역**: README, 아키텍처, 멀티 CLI, 사용법, 워크플로우 규칙, 플랫폼 지원
- **상태**: 문서·CLI 안내 교정 완료, 런타임 개선 과제 분리

## 문제

문서가 하네스의 실제 구현보다 넓은 동작을 보장하는 것처럼 설명했다.

1. `atask`가 Claude 소진 시 Codex/Gemini로 중심과 커밋 권한을 자동 이양한다고 설명했다.
2. 실제 `atask`는 Codex와 Gemini를 각각 역할 제한이 있는 `codex-task`, `gemini-task`로 호출한다.
3. git-bus가 Gemini/Codex 커밋을 판별한다고 설명했지만 구현은 업스트림 HEAD 변화만 본다.
4. 세 CLI가 모두 심볼릭 링크로 즉시 갱신된다고 요약했지만 Codex는 마커 병합 사본이다.
5. macOS에서 BSD `readlink` 경고를 무시할 수 있다고 했지만 핵심 스크립트가 GNU `-f/-e`에 의존한다.
6. Windows 네이티브와 WSL의 지원 경계가 문서에 없었다.

## 조사 근거

| 항목 | 실제 구현 |
|---|---|
| Claude 설정 | `rules/`, commands, agents, hooks 등을 `~/.claude/`에 심볼릭 |
| Gemini 규약 | `AGENTS.md`를 `~/.gemini/GEMINI.md`로 심볼릭 |
| Codex 규약 | `~/.codex/AGENTS.md`에 마커 병합, 재설치 필요 |
| `atask` Codex 단계 | `codex-task` 호출, tester/fixer 프리앰블과 기능 추가 금지 유지 |
| `atask` Gemini 단계 | `gemini-task` 호출, reader/advisor 역할 유지 |
| git-bus | 업스트림 브랜치 HEAD와 `.claude/last-seen-commit` 비교 |
| 플랫폼 의존 | Bash 배열, GNU `readlink -f/-e`, 일부 `date -d`, Unix 심볼릭 링크 |

## 이번 개선

1. “중심 자동 이양”을 “헤드리스 실행 후보 폴백”으로 교정했다.
2. `atask impl`의 성공 종료가 구현 완료나 diff 생성을 보장하지 않는다고 명시했다.
3. 3-레인 위임 모드의 커밋 권한은 Claude에 있고, 다른 중심으로의 전환은 수동 인계라고 명시했다.
4. git-bus를 작성자 판별 기능이 아닌 업스트림 커밋 변화 알림으로 정의했다.
5. Claude/Gemini 심볼릭과 Codex 마커 병합의 반영 시점을 분리했다.
6. Linux, WSL2, macOS, Windows 네이티브 지원 표를 추가했다.
7. `atask-quota-warn` 출력의 “현재 중심”을 “impl 첫 가용 후보”로 교정했다.

## 잔여 개선 과제

문서 정확화만으로 다음 런타임 한계가 해결되지는 않는다.

1. `atask impl`이 역할을 보존하려면 구현 전용 Codex/Gemini 호출 계약이 필요하다.
2. 구현 성공 조건을 종료코드뿐 아니라 diff, 테스트 결과 등으로 검증해야 한다.
3. macOS 정식 지원에는 portable realpath/date helper 또는 OS별 어댑터가 필요하다.
4. Windows 네이티브 지원에는 PowerShell 설치기와 링크·경로·권한 모델 검증이 필요하다.
5. git-bus가 로컬 커밋도 감지해야 한다면 업스트림과 로컬 HEAD를 별도 추적해야 한다.

## 완료 조건

- 사용자 문서와 CLI 도움말이 현재 구현의 역할 경계를 동일하게 설명한다.
- 플랫폼별 지원 여부와 필수 도구가 설치 전에 드러난다.
- 자동화되지 않은 중심 이양과 구현 완료를 자동 지원처럼 표현하지 않는다.
- 잔여 런타임 과제가 문서 정확성 문제와 분리되어 추적 가능하다.
