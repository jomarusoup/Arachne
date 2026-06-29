---
Title: "[task] Arachne 기능 문서화 커버리지 보강"
creation: 2026-06-07
modification: 2026-06-09
status: "in progress"
tags:
 - "arachne"
 - "task"
 - "documentation"
 - "priority/medium"
aliases:
 - "documentation-coverage-hardening"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-documentation-coverage-audit]]

# [task] Arachne 기능 문서화 커버리지 보강

- **상태**: in-progress
- **우선순위**: medium
- **담당**: Codex
- **관련 문서**: [기능 문서화 감사](../issue/2026-06-07-documentation-coverage-audit.md)

## 목표

코드에 존재하는 사용자 기능과 CI 계약이 README 및 세부 문서에서 발견 가능하고 정확하게
설명되도록 하며, 문서 드리프트를 반복적으로 줄일 수 있는 검증 경로를 마련한다.

## 범위

- 포함:
  - CI 전용 운영 문서
  - 위임 래퍼 환경변수 명칭
  - 테스트 문서의 현재 범위
  - 상태표시줄 비용 추적 설명
  - docs-sync 구형 설정 호환 설명
  - Windows 지원 표의 실제 구현 기준 교정
  - 고정된 테스트 개수 등 시간에 따라 낡는 문구 제거
- 제외:
  - Windows Copilot 통합 구현
  - Windows Git Bash 런타임 구현
  - CI 자체의 신규 플랫폼 job 추가

## 작업 목록

- [x] `docs/CI.md`에 현재 CI의 실행·운영·한계를 상세히 작성한다.
- [x] README, tests README, GLOSSARY에서 CI 문서를 연결한다.
- [x] `GTASK_MODEL`, `CTASK_MODEL`을 정식 환경변수로 교정한다.
- [x] `tests/README.md`에 현재 Bats와 Windows 테스트 범위를 반영한다.
- [x] 상태표시줄 비용 추적 파일·설정·플랫폼 의존성을 사용자 문서에 추가한다.
- [x] docs-sync 구형 3컬럼 설정 호환과 5컬럼 전환 방법을 문서화한다.
- [x] Windows 지원 표를 “설치 지원”과 “런타임 검증 범위”로 나눠 교정한다.
- [x] AI 엔지니어링 노트의 고정 테스트 개수를 제거하거나 자동 계산 근거로 교체한다.
- [x] CI에서 `jq`를 플랫폼별 필수 의존성으로 설치하고 코드·문서를 일치시킨다.
- [ ] 문서 기능 목록과 실제 CLI 도움말 간 드리프트 검사 방안을 설계한다.

## 검증

```bash
git diff --check
bash tests/check_index.sh
bats tests/*.bats
shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh
```

문서 링크가 유효하고, 코드에 선언된 명령·환경변수·지원 범위와 사용자 문서가 일치해야 한다.

## 완료 조건

- 감사 문서의 미해결 항목이 모두 문서화되거나 별도 구현 task로 연결된다.
- 핵심 기능을 찾기 위해 소스 코드를 직접 읽어야 하는 항목이 남지 않는다.
- CI와 로컬 검증 명령이 같은 계약을 설명한다.
- 변경 후 전체 문서·테스트 검증이 통과한다.

## 진행 기록

### 2026-06-07

- 코드 진입점, 환경변수, hook, 테스트, CI와 사용자 문서를 대조했다.
- CI 운영 문서와 기능 문서화 감사 문서를 추가했다.
- 환경변수 오표기와 테스트 목록 드리프트를 우선 교정했다.
- 상태표시줄, docs-sync 구형 설정, Windows 지원 표, 고정 테스트 개수를 교정했다.

### 2026-06-09

- CI의 Ubuntu, Rocky, macOS job이 jq를 명시 설치하는 현재 계약을 재확인해 관련 항목을 완료했다.
- CLI 도움말과 문서 자동 대조는 별도 자동화가 필요하므로 task를 계속 in-progress로 유지한다.
