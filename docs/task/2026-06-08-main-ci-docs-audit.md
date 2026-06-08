---
Title: "[task] main CI와 문서 드리프트 검수"
creation: 2026-06-08
modification: 2026-06-08
tags:
 - "arachne"
 - "task"
 - "priority/high"
 - "ci"
 - "docs"
aliases:
 - "main-ci-docs-audit"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-08-ci-platform-split]]

# [task] main CI와 문서 드리프트 검수

- **상태**: done
- **우선순위**: high
- **담당**: Codex
- **관련 문서**: [CI.md](../CI.md), [tests README](../../tests/README.md), [GLOSSARY.md](../GLOSSARY.md)

## 목표

`main` 브랜치의 실제 CI 결과와 프로젝트 문서가 서로 맞는지 검수하고, 플랫폼별 CI 실패 원인과 문서
드리프트를 수정한다.

## 범위

- 포함:
  - 최신 GitHub Actions 실패 로그 검수
  - Rocky, Windows, macOS CI 실패 원인 수정
  - CI/테스트/용어 문서의 최신 구조 반영
- 제외:
  - 외부 AI 서비스 로그인 E2E
  - Windows 로컬 `pwsh` 실행(현재 작업 환경에 미설치)

## 작업 목록

- [x] `main` 최신 CI 실패 로그를 확인한다.
- [x] Rocky 컨테이너의 `diff` 누락을 보완한다.
- [x] Windows PowerShell 테스트의 `Target` 바인딩 실패를 보완한다.
- [x] macOS Bats 실행 환경의 Bash/UTF-8 전제를 보완한다.
- [x] `docs/CI.md`, `docs/GLOSSARY.md`, `tests/README.md`를 실제 workflow와 대조해 갱신한다.
- [x] 정적 검사와 전체 Bats를 실행한다.

## 검증

```bash
git diff --check
bash -n ./*.sh hooks/*.sh tests/*.sh
shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh
python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml", encoding="utf-8"))'
bats tests/*.bats
bash tests/check_index.sh
bash tests/check_convention_sync.sh
```

## 완료 조건

- 로컬에서 가능한 검증이 통과한다.
- 최신 CI 실패 원인이 task에 기록된다.
- 다음 GitHub Actions 실행에서 확인해야 할 플랫폼 검증이 명확히 남는다.

## 진행 기록

### 2026-06-08

- task 생성: 사용자 요청에 따라 `main`에서 새 `codex-main-audit` 브랜치를 만들고 전체 검수를 시작했다.
- 최신 CI run `27143608279` 확인:
  - `verify-ubuntu`: 통과
  - `verify-rocky`: `diff` command not found로 `tests/new_project.bats` 2건 실패
  - `verify-windows`: `-Install`이 `Target` 값으로 바인딩되어 PowerShell 설치 테스트 실패
  - `verify-macos`: Bats가 한국어 테스트명을 깨진 인코딩으로 처리해 `unknown test name` 다수 발생
- 구현:
  - Rocky job에 `diffutils` 설치를 추가했다.
  - Windows 설치 테스트에서 배열 splatting을 제거하고 `install.ps1 -Install -Target <name>` 직접 호출로 바꿨다.
  - macOS job에 Homebrew `bash`, UTF-8 locale, GNU tool PATH를 명시했다.
  - `docs/CI.md`, `docs/GLOSSARY.md`, `tests/README.md`의 CI/테스트 설명을 최신 구조와 맞췄다.
- 검증 통과:
  - `git diff --check`
  - `bash -n ./*.sh hooks/*.sh tests/*.sh`
  - `shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh`
  - `python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml", encoding="utf-8")); print("yaml ok")'`
  - `bats tests/*.bats` — 101개 통과
  - `bash tests/check_index.sh`
  - `bash tests/check_convention_sync.sh`
- 미실행: 현재 작업 환경에 `pwsh`, Docker/Rocky, macOS가 없어 Windows/Rocky/macOS 실제 runner 통과는
  다음 GitHub Actions 실행에서 확인해야 한다.
