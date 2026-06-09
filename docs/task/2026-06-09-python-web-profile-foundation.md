---
Title: "[task] Python·Web profile 기반 구축"
creation: 2026-06-09
modification: 2026-06-09
tags:
 - "arachne"
 - "task"
 - "priority/high"
aliases:
 - "python-web-profile-foundation"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-09-python-web-improvement-roadmap]]

# [task] Python·Web profile 기반 구축

- **상태**: in-progress
- **우선순위**: high
- **담당**: Codex
- **관련 문서**: [[2026-06-09-python-web-harness-assessment]], [[2026-06-09-ecc-python-web-gap-analysis]], [[2026-06-09-documentation-freshness-audit]]

## 목표

Arachne 사용 프로젝트가 `minimal`, `python`, `web`, `python-web` profile 중 하나를 선택해 로컬과
GitHub Actions에서 동일한 검증 계약을 생성하도록 한다. 동시에 Python/Web 기본 스택과 문서 정본을
명시해 후속 rules·skills 확장의 기준을 만든다.

## 범위

- 포함:
  - `new`, `init-ci`의 `--profile` 지원
  - profile별 `.arachne/commands` 템플릿
  - Python/Web GitHub Actions 런타임 준비
  - profile 보존·갱신 계약과 회귀 테스트
  - README, 문서 인덱스, Python/Web profile, 프로젝트 CI, 호환성 문서
  - 기본 스택 및 profile 소유권 ADR
- 제외:
  - Django·Next.js 세부 rules/skills
  - 기존 전역 rules의 물리적 선택 설치
  - 멀티 모델 자동 오케스트레이션
  - 사용 프로젝트의 실제 의존성 파일 생성

## 작업 목록

- [x] profile CLI 계약에 대한 실패 테스트를 추가한다.
- [x] profile별 프로젝트 CI 템플릿과 설치 로직을 구현한다.
- [x] profile 재실행 시 사용자 commands 보존 정책을 검증한다.
- [x] Python/Web 기본 스택과 확장 기준을 ADR로 기록한다.
- [x] README와 docs 정본·인덱스·호환성 설명을 갱신한다.
- [x] Bash 문법, Bats, ShellCheck, 문서 인덱스 검사를 실행한다.
- [ ] GitHub 다중 플랫폼 CI를 통과한다.

## 검증

```bash
bash -n install.sh templates/project/verify.sh
bats tests/project_ci.bats tests/new_project.bats tests/install.bats
shellcheck install.sh templates/project/verify.sh
bash tests/check_index.sh
git diff --check
```

profile별 생성 파일, 사용자 명령 보존, 잘못된 profile 거부, 기존 minimal 기본값 호환성이 모두
검증되어야 한다.

## 완료 조건

- `arachne init-ci --profile python-web`가 profile과 검증 명령을 생성한다.
- `arachne new ... --profile web`이 Web profile 프로젝트를 생성한다.
- 기존 무인자 호출은 `minimal`로 동작한다.
- GitHub Actions가 선택 profile에 필요한 Python/Node 런타임만 준비한다.
- 사용자 수정 `.arachne/commands`는 명시적 profile 변경에서도 자동 덮어쓰지 않는다.
- 사용자 문서에서 설치·검증·지원 범위를 소스 탐색 없이 확인할 수 있다.

## 진행 기록

### 2026-06-09

- idea 감사 결과를 실행 작업으로 승격했다.
- PR #42 프로젝트 CI와 PR #43 감사 문서를 `main`에 병합했다.
- 대규모 ECC 복사 대신 project profile과 CI 계약을 우선 구현하기로 결정했다.
- `minimal`, `python`, `web`, `python-web` profile과 조건부 Python/Node workflow를 구현했다.
- 신규 profile 및 문서 계약 테스트를 포함한 Bats 117개가 통과했다.
- ShellCheck, Bash 문법, settings, 문서 인덱스, 공통 규약 동기화 검사가 통과했다.
- GitHub CI는 PR 생성 후 결과를 기록한다.
