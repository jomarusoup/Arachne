---
Title: "[bug] macOS CI의 GNU sed -i 의존"
creation: 2026-06-09
modification: 2026-06-09
status: "done"
tags:
 - "arachne"
 - "issue"
 - "priority/high"
 - "ci"
 - "macos"
aliases:
 - "macos-sed-inplace-ci"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-08-main-ci-docs-audit]]

# [bug] macOS CI의 GNU `sed -i` 의존

## 증상

GitHub Actions CI run `27146410199`의 `verify-macos` job에서 Bats 101개 중
`check: Copilot 지침이 AGENTS.md와 다르면 stale 탐지`만 실패한다.

```text
sed: 1: "/var/folders/...": invalid command code f
```

## 재현

BSD `sed`를 사용하는 macOS에서 다음 테스트를 실행한다.

```bash
bats tests/install.bats
```

## 원인

`tests/install.bats`가 GNU `sed` 문법인 `sed -i 's/.../...' file`을 사용한다.
BSD `sed`는 `-i` 바로 뒤에 백업 확장자 인자가 필요하므로 파일 경로를 편집 명령으로 해석한다.

## 해결 방향

인플레이스 편집 옵션을 사용하지 않고 `sed` 결과를 임시 파일에 기록한 뒤 원본 경로로 이동한다.
이 방식은 GNU/BSD `sed` 모두에서 같은 동작을 한다.

