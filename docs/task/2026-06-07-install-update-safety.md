---
Title: "[task] 설치·업데이트 안전성 — 파괴적 재생성·브랜치 검증·타깃 부작용"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
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

- **상태**: done
- **우선순위**: high
- **담당**: Claude (Opus)
- **관련 문서**: #28 #33 #34

## 목표

`arachne -i/-u`가 사용자 설정을 파괴적으로 덮어쓰거나, 잘못된 브랜치·더러운 작업트리에서 실행되거나,
특정 CLI 타깃 설치가 공통 자산까지 건드리는 부작용을 제거해 설치·업데이트를 예측 가능하게 만든다.

## 범위

- 포함: `install.sh`(`install_claude`·`install`·`update_arachne`·`install_shared`), `install.ps1`, `tests/install.bats`
- 제외: dotfiles 병합 로직 자체(이미 멱등)

## 작업 목록

- [x] #28: `settings.json` 이 템플릿 생성본과 다르면(=사용자 수정) 교체 전 경고 + `arachne -e` 안내(.bak 보존)
- [x] #33: `arachne -u`가 pull·재설치 전 브랜치(비-main 경고)·작업트리(dirty면 중단, `ARACHNE_FORCE=1` 우회) 검증
- [x] #34: `install_shared`(dotfiles·전체 bin)를 전체 설치(`all`)에서만 수행, 특정 CLI 타깃은 생략
- [x] 회귀 테스트: 사용자 수정 settings 경고·.bak, dirty 트리 중단·force 우회, 타깃 격리(--target gemini) — `tests/install.bats` 5건
- [x] `shellcheck` + `bats`(80개 green) 통과 / Windows job은 별도(#40 task에서 다룸)
- [x] 부수: `install_claude` 루프 변수 `local` 누락 교정(동적 스코프로 `install()` target 오염하던 잠복 버그)

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

### 2026-06-08

- 3개 이슈 구현 (`install.sh`: `install`·`install_claude`·`update_arachne`).
- 구현 중 **잠복 버그 발견·수정**: `install_claude`의 `for target` 루프가 `local` 미선언이라
  동적 스코프로 `install()`의 `target`을 오염 → `-i` 전체 설치가 공통 설치를 건너뛰던 회귀를
  테스트가 잡아냄. 루프 변수를 `link_target`(local)로 교정.
- 검증: `shellcheck` 통과, `bats tests/*.bats` **80개 전부 green**(신규 5 포함), `check_index.sh` 통과.
- 커밋: **1342d21** (`fix: 설치·업데이트 안전성 (#28·#33·#34)`), origin/main push 완료.
- 설계 메모: #28은 자동 머지 대신 **차이 감지 시 경고 + .bak + arachne -e 안내**(JSON 머지는 위험·복잡).
  #34는 특정 타깃 설치가 공통 인프라를 안 건드리도록 `install_shared`를 `all` 한정.
- 상태 → **done**. GitHub #28·#33·#34 close 예정.
