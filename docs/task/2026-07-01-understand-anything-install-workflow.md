---
Title: "[task] Understand-Anything 설치 연동과 원격 대시보드 문서화"
creation: 2026-07-01
modification: 2026-07-01
status: "done"
tags:
 - "arachne"
 - "task"
 - "priority/medium"
 - "understand-anything"
aliases:
 - "understand-anything-install-workflow"
---
MOC:: [[Arachne]]
FROM:: [[tools/understand-anything]]

# [task] Understand-Anything 설치 연동과 원격 대시보드 문서화

- **상태**: done
- **우선순위**: medium
- **담당**: Codex
- **관련 문서**: [tools/understand-anything](../tools/understand-anything.md), [tools/extras-setup](../tools/extras-setup.md)

## 목표

Understand-Anything 사용 흐름을 문서화하고, Arachne 설치·업데이트 시 UA만 함께 설치할 수 있는
명시적 옵션을 제공한다.

## 범위

- 포함:
  - Unix `install.sh`의 `--with-ua`
  - Windows `install.ps1`의 `-WithUa`
  - 원격 CLI 환경에서 SSH 터널로 dashboard를 보는 방법
  - 프로젝트 업데이트 후 `understand` 재실행 기준
  - 설치 옵션 회귀 테스트
- 제외:
  - 실제 외부 플러그인 저장소 vendoring
  - `.understand-anything/knowledge-graph.json` 커밋 정책 결정

## 작업 목록

- [x] `--with-ua` / `-WithUa` 설치 옵션 추가
- [x] extras 스크립트 경로 테스트 오버라이드 추가
- [x] Understand-Anything 사용법과 원격 dashboard 접속 문서화
- [x] Arachne 설치 로그를 단계형 prefix로 명확화
- [x] 설치 문서와 빠른 시작 문서 갱신
- [x] 회귀 테스트 추가
- [x] 정적 검사와 테스트 실행

## 검증

```bash
bash -n install.sh setup-extras.sh
shellcheck -S warning install.sh setup-extras.sh
bats tests/install.bats
```

기대 결과: shell syntax가 유효하고 install 테스트가 통과한다.

## 완료 조건

- `arachne -i --with-ua`가 `setup-extras.sh --ua`를 호출한다.
- `arachne -u --with-ua`가 `setup-extras.sh --ua --update`를 호출한다.
- 문서에서 원격 dashboard 접속과 프로젝트 변경 후 재분석 흐름을 확인할 수 있다.

## 진행 기록

### 2026-07-01

- task 생성.
- `--with-ua`/`-WithUa` 옵션과 문서 보강을 완료했다.
- `install.sh`/`install.ps1`에 `[Arachne][STEP|RUN|SKIP|DONE|WARN]` 형식의 명확한 출력 prefix를 추가했다.
