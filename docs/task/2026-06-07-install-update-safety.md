---
Title: "[task] 설치·업데이트 안전성 — 파괴적 재생성·브랜치 검증·타깃 부작용"
creation: 2026-06-07
modification: 2026-06-07
tags:
 - "project"
 - "task"
 - "priority/high"
aliases:
 - "install-update-safety"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [task] 설치·업데이트 안전성

- **상태**: planned
- **우선순위**: high
- **담당**: unassigned
- **관련 문서**: #28 #33 #34

## 목표

`arachne -i/-u`가 사용자 설정을 파괴적으로 덮어쓰거나, 잘못된 브랜치·더러운 작업트리에서 실행되거나,
특정 CLI 타깃 설치가 공통 자산까지 건드리는 부작용을 제거해 설치·업데이트를 예측 가능하게 만든다.

## 범위

- 포함: `install.sh`(`install_claude`·`install`·`update_arachne`·`install_shared`), `install.ps1`, `tests/install.bats`
- 제외: dotfiles 병합 로직 자체(이미 멱등)

## 작업 목록

- [ ] #28: `settings.json` 재생성이 사용자 수정값을 파괴하지 않도록 — 변경 감지 시 경고/머지 또는 `-e` 유도
- [ ] #33: `arachne -u`가 현재 브랜치·작업트리 상태를 검증(비-main/dirty면 경고·중단 옵션)
- [ ] #34: `--target <cli>` 설치가 공통 dotfiles·전체 bin을 강제 변경하지 않도록 `install_shared` 범위 조정
- [ ] 회귀 테스트: 사용자 수정 settings 보존, dirty 트리 가드, 타깃 격리 검증
- [ ] `shellcheck` + `bats tests/install.bats` + Windows job 통과

## 검증

```bash
bats tests/install.bats
shellcheck -S warning install.sh
```

타깃 지정 설치가 공통 자산을 건드리지 않고, 사용자 settings가 보존된다.

## 완료 조건

- #28·#33·#34 회귀 테스트 green.
- `arachne -u`가 위험 상태에서 사용자에게 알린다.

## 진행 기록

### 2026-06-07

- task 생성: 설치/업데이트 파괴성·부작용 3개 이슈를 하나의 안전성 작업으로 묶음.
