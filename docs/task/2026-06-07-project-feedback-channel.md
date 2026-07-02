---
Title: "[task] 사용 프로젝트에서 Arachne로 피드백 전달 경로 구축"
creation: 2026-06-07
modification: 2026-07-01
status: "done"
tags:
 - "arachne"
 - "task"
 - "feedback"
 - "workflow"
 - "priority/medium"
aliases:
 - "project-feedback-channel"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [task] 사용 프로젝트에서 Arachne로 피드백 전달 경로 구축

- **상태**: done
- **우선순위**: medium
- **담당**: unassigned
- **관련 문서**: [Task 작성 규약](README.md)

## 목표

Arachne로 생성하거나 관리하는 프로젝트에서 발견한 Arachne 자체의 불편, 결함, 개선 의견을
프로젝트 로컬에 안전하게 기록하고, 사용자가 내용을 검토한 뒤 Arachne GitHub Issue로 명시적으로
제출할 수 있는 표준 경로를 제공한다.

## 범위

- 포함:
  - 신규 프로젝트의 `docs/feedback/` 디렉터리와 피드백 템플릿
  - `arachne feedback new`, `list`, `submit` 명령
  - Arachne 버전, 실행 환경, 기대·실제 동작, 재현 방법을 포함하는 표준 형식
  - 제출 전 미리보기와 사용자 확인
  - 토큰, 경로, 프로젝트 코드, 로그 등 민감정보 검토 경고
  - GitHub Issue 생성 결과와 제출 상태의 로컬 기록
  - Linux, macOS, WSL, Windows PowerShell 동작 경계 문서화
- 제외:
  - 사용자 확인 없는 자동 제출
  - 비공개 프로젝트 파일이나 로그의 자동 첨부
  - GitHub CLI 설치·로그인·조직 정책 자동 변경
  - 피드백을 자동으로 Arachne `docs/task/`에 편입하는 기능

## 작업 목록

- [x] `docs/template/feedback.md`에 필수 필드와 민감정보 점검 항목을 정의한다.
- [x] 신규 프로젝트 스캐폴딩에 `docs/feedback/`과 피드백 템플릿을 포함한다.
- [x] `arachne feedback new`가 날짜 기반 파일명으로 로컬 초안을 생성한다.
- [x] `arachne feedback list`가 제출 상태별 피드백 목록을 출력한다.
- [x] `arachne feedback submit`이 제출 내용을 먼저 출력하고 명시적 확인을 요구한다.
- [x] `submit`이 `gh` 설치·인증·저장소 접근 가능 여부를 검증한 뒤 GitHub Issue를 생성한다.
- [x] 제출 성공 시 Issue URL과 제출 시각을 로컬 피드백 문서에 기록한다.
- [x] 제출 실패 시 원본 문서를 변경하지 않고 원인을 사용자에게 출력한다.
- [x] 토큰 형태와 절대 경로 등 명백한 민감정보 후보가 있으면 기본 제출을 중단한다.
- [x] 동일 피드백의 중복 제출을 방지하거나 명확히 경고한다.
- [x] Bash 경로 단위·통합 테스트와 Windows PowerShell 경계 문서를 추가한다.
- [x] README와 사용 가이드에 issue, task, feedback의 역할과 전달 흐름을 문서화한다.

## 검증

```bash
bats tests/feedback.bats tests/new_project.bats
shellcheck install.sh
bash tests/check_index.sh
```

```powershell
pwsh -File .\tests\install_windows.ps1
```

GitHub API 호출은 mock 또는 격리된 테스트 저장소를 사용하며, 테스트가 실제 운영 Issue를 생성하지
않아야 한다. 제출 취소·미인증·민감정보 감지·네트워크 실패에서도 로컬 초안이 보존되어야 한다.

## 완료 조건

- 사용 프로젝트에서 Arachne 피드백을 작업 흐름을 벗어나지 않고 기록할 수 있다.
- 사용자 확인 전에는 어떤 내용도 외부로 전송되지 않는다.
- 제출된 피드백은 Arachne GitHub Issue URL로 추적할 수 있다.
- 프로젝트 문제는 `docs/issue/`, 실행 계획은 `docs/task/`, Arachne 개선 의견은
  `docs/feedback/`이라는 구분이 문서와 스캐폴딩에서 일관된다.
- 지원 플랫폼별 사용 가능 명령과 제약이 실제 구현 및 테스트 결과와 일치한다.

## 진행 기록

### 2026-06-07

- 권장 전달 방식으로 “프로젝트 로컬 기록 후 사용자 검토를 거쳐 GitHub Issue로 명시적 제출”을
  채택했다.
- 자동 제출은 비공개 코드, 로그, 경로가 외부로 유출될 위험이 있어 제외하기로 했다.
- 공식 접수 후 Arachne의 `docs/issue/`에서 조사하고, 구현이 결정된 항목은 관련
  `docs/task/`에서 그룹화하는 흐름으로 정리했다.

### 2026-07-01

- task 인벤토리 정리: 규약상 상태 값은 `planned`가 아니라 `to do`로 표준화했다.
- 정리 당시에는 구현이 아직 착수되지 않았고, 모든 체크박스가 열린 상태였다.
- 완료: `docs/template/feedback.md`, `docs/feedback/` 스캐폴딩, `arachne feedback new/list/submit`
  명령을 추가했다.
- 제출 경로는 `gh auth status`, `gh repo view`, `gh issue create`를 확인하고, 전송 전 본문 미리보기와
  `YES` 확인을 요구한다. 테스트는 `ARACHNE_FEEDBACK_YES=1`과 mock `gh`로 실제 Issue 생성을 막는다.
- 안전장치: 토큰 패턴과 사용자 절대 경로 후보를 기본 차단하고, 이미 제출된 문서는 재제출을 거부한다.
- 검증: `bats ../tests/feedback.bats ../tests/new_project.bats ../tests/docs_cli_contract.bats` 포함 핵심
  41건 통과, `bash -n`, `shellcheck`, `git diff --check` 통과.
- Windows PowerShell 전용 feedback 구현은 범위에서 제외했다. Windows 사용자는 Git Bash/WSL의
  `install.sh` 경로에서 동일 명령을 사용한다.
- 상태 → **done**.
