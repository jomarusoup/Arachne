---
Title: "[task] macOS sed CI 호환성 수정"
creation: 2026-06-09
modification: 2026-06-09
tags:
 - "arachne"
 - "task"
 - "priority/high"
 - "ci"
 - "macos"
aliases:
 - "macos-sed-ci-fix"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-09-macos-sed-inplace-ci]]

# [task] macOS `sed` CI 호환성 수정

- **상태**: done
- **우선순위**: high
- **담당**: Codex
- **관련 문서**: [macOS sed issue](../issue/2026-06-09-macos-sed-inplace-ci.md), [CI.md](../CI.md)

## 목표

macOS와 Linux에서 같은 `tests/install.bats`가 통과하도록 GNU 전용 `sed -i` 의존을 제거한다.

## 범위

- 포함:
  - macOS CI 실패 로그 확인
  - Copilot stale fixture 변조 방식의 GNU/BSD 호환 수정
  - Bash 정적 검사와 전체 Bats 실행
- 제외:
  - 실제 macOS runner를 로컬에서 재현
  - CI 플랫폼 구성 변경

## 작업 목록

- [x] 실패한 macOS CI step과 테스트를 식별한다.
- [x] GNU 전용 `sed -i` 호출을 이식 가능한 방식으로 교체한다.
- [x] 정적 검사와 전체 Bats를 실행한다.
- [x] task 상태와 검증 결과를 갱신한다.

## 검증

```bash
git diff --check
bash -n ./*.sh hooks/*.sh tests/*.sh
shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh
bats tests/*.bats
bash tests/validate_settings.sh
bash tests/check_index.sh
bash tests/check_convention_sync.sh
```

모든 로컬 검증이 통과하고 다음 `verify-macos` job에서 Bats 101개가 통과해야 한다.

## 완료 조건

- 테스트 코드에 GNU 전용 `sed -i` 호출이 없다.
- 로컬 전체 검증이 통과한다.
- CI 문서와 진행 기록이 실제 원인 및 수정과 일치한다.

## 진행 기록

### 2026-06-09

- CI run `27146410199` 확인: Ubuntu, Rocky, Windows는 통과했고 macOS Bats 테스트 75만 실패했다.
- 원인 분리: UTF-8/Bash 문제가 아니라 BSD `sed`와 호환되지 않는 `sed -i` 문법이었다.
- 구현: `sed` 결과를 임시 파일에 기록한 뒤 `mv`로 원본을 교체하도록 수정했다.
- 검증 통과:
  - `git diff --check`
  - `bash -n ./*.sh hooks/*.sh tests/*.sh`
  - `shellcheck -S warning ./*.sh hooks/*.sh tests/*.sh`
  - `bats tests/install.bats` - 29개 통과
  - `bats tests/*.bats` - 101개 통과
  - `bash tests/validate_settings.sh`
  - `bash tests/check_index.sh`
  - `bash tests/check_convention_sync.sh`
- 미실행: 현재 환경에 macOS가 없어 실제 BSD `sed` runner 확인은 PR의 `verify-macos` job에서 수행한다.
