---
Title: "[task] Arachne 사용 프로젝트 CI 스캐폴딩"
creation: 2026-06-09
modification: 2026-06-09
tags:
 - "arachne"
 - "task"
 - "priority/high"
 - "ci"
 - "workflow"
aliases:
 - "project-ci-scaffold"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [task] Arachne 사용 프로젝트 CI 스캐폴딩

- **상태**: done
- **우선순위**: high
- **담당**: Codex
- **관련 문서**: [CI.md](../CI.md), [USAGE.md](../USAGE.md), [MULTI-CLI.md](../MULTI-CLI.md)

## 목표

Arachne를 사용하는 프로젝트가 로컬 `/git`과 GitHub의 `main` push/PR에서 동일한 프로젝트 검증을
실행하도록 프로젝트별 검증 스크립트와 workflow를 생성한다.

## 범위

- 포함:
  - `arachne init-ci [DIR]` 프로젝트 CI 초기화
  - `arachne project-check [DIR]` 로컬 검증 실행
  - `arachne new`의 CI 자산 기본 생성
  - `.arachne/commands` 기반 프로젝트별 명령 설정
  - `/git`, README, 사용법, CI 문서 갱신
- 제외:
  - 중앙 Arachne 저장소가 모든 사용 프로젝트를 직접 실행
  - 프로젝트 언어와 테스트 명령의 임의 자동 추측
  - Windows PowerShell 전용 프로젝트 CI 생성기

## 작업 목록

- [x] 기존 CLI·스캐폴딩·`/git` 구조를 조사한다.
- [x] 신규 기능의 실패 테스트를 먼저 추가한다.
- [x] 프로젝트 검증 템플릿과 CLI 명령을 구현한다.
- [x] 신규 프로젝트 스캐폴딩에 CI 자산을 연결한다.
- [x] `/git`과 사용자 문서를 동일 검증 계약으로 갱신한다.
- [x] 전체 정적 검사와 테스트를 실행한다.

## 검증

```bash
git diff --check
bash -n ./*.sh hooks/*.sh tests/*.sh templates/project/*.sh
shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh templates/project/*.sh
bats tests/project_ci.bats tests/new_project.bats tests/git_command.bats
bats tests/*.bats
bash tests/validate_settings.sh
bash tests/check_index.sh
bash tests/check_convention_sync.sh
```

## 완료 조건

- 새 프로젝트와 기존 프로젝트 모두 Arachne 검증 workflow를 생성할 수 있다.
- `/git`과 GitHub Actions가 `.arachne/verify.sh`의 동일한 검증을 실행한다.
- 프로젝트별 명령 실패가 그대로 커밋/CI 실패로 전파된다.
- 전체 로컬 검증과 GitHub Actions가 통과한다.

## 진행 기록

### 2026-06-09

- 조사: 기존 `arachne new`는 README/docs/git만 만들며 프로젝트 CI나 검증 계약은 생성하지 않았다.
- 설계: 외부 Arachne 저장소를 CI 중 내려받지 않고 프로젝트에 버전 관리되는 검증 스크립트와 workflow를
  설치한다. 프로젝트별 명령은 `.arachne/commands`에 명시해 언어 자동 추측으로 인한 오작동을 피한다.
- RED: `project_ci.bats`, `new_project.bats`, `git_command.bats`에 신규 계약 테스트를 추가했다.
- 구현:
  - `arachne init-ci [DIR]`가 관리 runner와 GitHub Actions workflow를 생성·갱신한다.
  - `.arachne/commands`는 프로젝트 소유 파일로 보존하고 한 줄씩 순서대로 실행한다.
  - `arachne project-check [DIR]`가 runner의 실패 상태를 그대로 반환한다.
  - `arachne new`가 새 프로젝트에 CI 자산을 기본 생성한다.
  - `/git`이 프로젝트 CI가 설치된 경우 같은 검증을 커밋 전에 실행한다.
- 보안:
  - `init-ci`가 관리 디렉터리·파일 심볼릭 링크를 거부해 프로젝트 외부 덮어쓰기를 차단한다.
  - GitHub Actions workflow 권한을 `contents: read`로 제한한다.
- 검증 통과:
  - `git diff --check`
  - `bash -n ./*.sh hooks/*.sh tests/*.sh templates/project/*.sh`
  - `shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh templates/project/*.sh`
  - 관련 Bats 23개 통과
  - 전체 Bats 109개 통과
  - `bash tests/validate_settings.sh`
  - `bash tests/check_index.sh`
  - `bash tests/check_convention_sync.sh`
