---
Title: "[bug] 특정 CLI 타깃 설치가 공통 dotfiles와 전체 bin까지 변경함"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/low"
aliases:
 - "install-target-side-effects"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] 특정 CLI 타깃 설치가 공통 dotfiles와 전체 bin까지 변경함

- **작성일**: 2026-06-07
- **심각도**: LOW
- **영역**: `install.sh:install`, `install_shared`
- **상태**: 해결됨 — 1342d21 (install_shared 를 all 한정, 타깃 설치 격리). task [[2026-06-07-install-update-safety]]

## 문제

`install.sh -i --target codex`처럼 특정 타깃을 지정해도 `install()` 마지막에서
항상 `install_shared`를 실행한다.

그 결과 다음이 함께 변경된다.

- `~/.bash_profile`
- `~/.vimrc`
- 감지 시 `~/.zshrc`
- `~/.local/bin`의 모든 Arachne 명령 링크

## 재현 결과

Codex 타깃만 설치한 임시 HOME에 `.codex/AGENTS.md`뿐 아니라 dotfiles와 `arachne`, `tws`,
Gemini/Codex 위임 래퍼, `atask`, `docs-sync` 링크가 모두 생성됐다.

## 영향

- 타깃 옵션의 최소 변경 기대를 위반한다.
- Codex 규칙만 갱신하려다 셸 설정과 명령 링크가 변경될 수 있다.
- 장애 복구 시 변경 범위가 커져 원인 격리가 어렵다.

## 원인

공통 설치가 “최초 설치에 필요한 bootstrap”과 “모든 타깃에서 항상 필요한 단계”로 구분되지 않았다.

## 수정 방향

1. `--target shared` 또는 `--with-shared`를 분리한다.
2. 최초 무인자 설치와 `--target all`에서만 shared를 기본 실행한다.
3. 특정 타깃은 해당 도구 파일만 변경한다.
4. help에 부작용 범위를 명확히 표시한다.

## 회귀 테스트

- `--target codex`가 `.codex` 외 홈 파일을 만들지 않음
- `--target gemini`가 dotfiles를 수정하지 않음
- `--target all`은 기존 전체 설치 유지
- `--with-shared` 명시 시 공통 자산 설치

## 완료 조건

- 타깃 옵션과 실제 변경 범위가 일치한다.
- 복구·재설치 작업이 최소 권한과 최소 변경 원칙을 따른다.
