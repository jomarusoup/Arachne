---
Title: "[bug] arachne update가 현재 브랜치와 작업트리를 검증하지 않음"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
tags:
 - "arachne"
 - "workflow"
 - "issue"
 - "severity/medium"
aliases:
 - "update-branch-safety"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-07-workflow-audit]]

# [bug] arachne update가 현재 브랜치와 작업트리를 검증하지 않음

- **작성일**: 2026-06-07
- **심각도**: MEDIUM
- **영역**: `install.sh:update_arachne`
- **상태**: 해결됨 — 1342d21 (arachne -u 브랜치·dirty 검증, ARACHNE_FORCE 우회). task [[2026-06-07-install-update-safety]]

## 문제

`arachne -u`는 현재 저장소에서 그대로 다음 작업을 수행한다.

```bash
git pull
install
```

현재 브랜치, upstream, dirty 상태, pull 방식, 테스트 상태를 확인하지 않는다.

## 실패 시나리오

- 기능 브랜치에서 실행하면 해당 브랜치 내용을 전역 설정으로 설치한다.
- dirty 작업트리에서 pull이 충돌하거나 로컬 변경과 원격 변경이 혼합된다.
- upstream이 다른 원격을 가리키면 예상 밖 소스를 설치한다.
- non-fast-forward pull 정책에 따라 merge commit이 자동 생성될 수 있다.

## 영향

- 검증 전 기능 브랜치가 모든 Claude 세션에 즉시 적용될 수 있다.
- 업데이트 명령이 소스 동기화와 배포를 한 번에 수행해 rollback 지점이 불명확하다.
- 설치 실패 시 pull은 이미 완료되어 부분 업데이트 상태가 된다.

## 원인

`update`가 fetch, 검증, 선택, 설치 단계를 하나의 비원자적 명령으로 결합한다.

## 수정 방향

1. dirty 작업트리면 기본 중단한다.
2. 기본 배포 소스를 `origin/main`으로 명시한다.
3. `git fetch` 후 fast-forward 가능 여부를 확인한다.
4. 현재 브랜치가 main이 아니면 명확히 경고하고 승인 없이는 설치하지 않는다.
5. 설치 전 검증을 실행하거나 검증된 release/tag를 설치한다.
6. pull과 install을 별도 명령으로 분리하는 방안도 고려한다.

## 회귀 테스트

- feature 브랜치에서 기본 update 거부
- dirty 상태에서 거부
- detached HEAD 처리
- upstream 없음 또는 origin 없음 처리
- fast-forward update 후에만 install 실행
- pull 성공/install 실패 시 복구 안내

## 완료 조건

- 사용자가 어떤 ref를 전역 설정으로 배포하는지 명확하다.
- 검증되지 않은 현재 브랜치가 조용히 설치되지 않는다.
