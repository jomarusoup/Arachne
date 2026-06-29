---
Title: "[audit] Arachne 기능 문서화 커버리지 감사"
creation: 2026-06-07
modification: 2026-06-07
status: "done"
tags:
 - "arachne"
 - "documentation"
 - "audit"
 - "severity/medium"
aliases:
 - "documentation-coverage-audit"
---
MOC:: [[Arachne]]
FROM:: [[empty]]

# [audit] Arachne 기능 문서화 커버리지 감사

- **작성일**: 2026-06-07
- **심각도**: MEDIUM
- **영역**: README, `docs/`, `tests/README.md`, CLI 도움말, CI
- **상태**: 코드와 사용자 문서 대조 완료

## 조사 방법

다음 구현 표면을 코드에서 목록화한 뒤 README와 사용자 문서에서 동일 계약이 설명되는지 대조했다.

- `install.sh`, `install.ps1`, `install-copilot.ps1`
- `gemini-task.sh`, `codex-task.sh`, `arachne-task.sh`
- `docs-sync.sh`, `tmux.sh`, `statusline-command.sh`
- `hooks/*.sh`, `settings.template.json`
- `.github/workflows/ci.yml`, `tests/*`
- `commands/`, `agents/`, `skills/`, `rules/`

## 요약

핵심 설치·멀티 CLI·훅·docs-sync·tmux 기능은 대체로 문서화되어 있다. 그러나 CI 운영 설명,
상태표시줄의 실제 비용 추적, 일부 환경변수와 Windows 지원 설명은 누락되거나 구현과 다르다.

| 우선순위 | 항목 | 상태 |
| --- | --- | --- |
| HIGH | Windows 지원 표가 실제 `install.ps1` 존재와 충돌 | 이번 문서 변경에서 교정 |
| HIGH | CI의 `jq` 검사가 선택적이지만 필수 검증처럼 오인 가능 | 문서화, 코드 미해결 |
| MEDIUM | 상태표시줄 비용·예산 추적 파일과 설정법 미문서화 | 이번 문서 변경에서 교정 |
| MEDIUM | `GTASK_MODEL`/`CTASK_MODEL`이 문서에서 구형 이름으로 표기 | 이번 문서 변경에서 교정 |
| MEDIUM | Windows Copilot 통합 설치·CI 검증 누락 | 기존 task로 추적 |
| MEDIUM | Windows Git Bash 훅·atask 런타임 미검증 | 기존 issue/task로 추적 |
| LOW | `tests/README.md`가 atask·Copilot 등 현재 테스트 범위를 충분히 설명하지 않음 | 이번 문서 변경에서 교정 |
| LOW | `docs-sync` 구형 3컬럼 설정 호환이 사용자 문서에 없음 | 이번 문서 변경에서 교정 |
| LOW | 테스트 전용 환경변수 `ARACHNE_HOME`, `ARACHNE_SKIP_PATH` 설명 없음 | CI 문서에 내부 용도로 기록 |
| LOW | AI 엔지니어링 노트의 Bats 테스트 수가 과거 값으로 고정 | 이번 문서 변경에서 교정 |

## 상세 발견

### 1. CI 전용 운영 문서 부재

기존에는 workflow YAML과 `tests/README.md`에 명령만 분산되어 있었다. 다음 내용이 없었다.

- 실행 이벤트와 branch 범위
- Ubuntu/Windows job별 보장 범위
- 단계별 실패 해석
- 로컬에서 CI 전체를 재현하는 방법
- 새 스크립트·테스트를 CI에 연결하는 방법
- branch protection 권장 설정
- CI가 보장하지 않는 범위

이번 변경에서 `docs/CI.md`를 추가해 보완했다.

### 2. settings JSON 검증이 의존성에 따라 SKIP

`tests/validate_settings.sh`는 `jq`가 없으면 JSON 파싱과 필수 키 검사를 생략한다. CI는
`shellcheck`와 `bats`만 명시 설치하므로 이 검사의 강제성은 `ubuntu-latest` 이미지에 의존한다.

개선 방향:

- CI에서 `jq`를 명시 설치한다.
- 또는 Python/Node 등 러너 기본 도구로 JSON 파싱을 강제한다.
- 필수 검사가 SKIP되면 CI가 실패하도록 계약을 명확히 한다.

### 3. 상태표시줄 기능의 상세 미문서화

`statusline-command.sh`는 단순 렌더러가 아니라 다음 상태 파일을 생성·갱신한다.

| 파일 | 역할 |
| --- | --- |
| `~/.claude/usage_limits.json` | 5시간·주간 예산 설정 |
| `~/.claude/usage_track.json` | 최근 7일 비용 델타 기록 |
| `~/.claude/usage_last.json` | 직전 세션 비용과 시각 |

또한 모델명, git 브랜치, 컨텍스트 사용률, token 수, 세션 비용, 5시간·주간 잔여율과 다음 주간
리셋 시간을 표시한다. 현재 README와 MULTI-CLI 문서는 “상태표시줄” 존재만 언급하고 설정 형식,
파일 부작용, `jq`·GNU `date` 의존성을 설명하지 않는다.

### 4. 위임 래퍼 환경변수 오표기

실제 코드:

```text
GTASK_MODEL (구형 GASK_MODEL도 fallback)
CTASK_MODEL (구형 CASK_MODEL도 fallback)
```

기존 `docs/USAGE.md`는 구형 `GASK_MODEL`, `CASK_MODEL`만 정식 이름처럼 설명했다. 이번 변경에서
정식 이름과 구형 호환 이름을 구분해 교정했다.

### 5. Windows 지원 설명 충돌

README와 Windows 가이드는 `install.ps1` 기반 Windows 네이티브 설치를 설명하지만
`docs/USAGE.md` 지원 표에는 “Windows 네이티브 미지원, PowerShell 설치기 없음”이라고 남아 있다.

이는 단순 누락이 아니라 사용자가 설치 경로를 잘못 선택하게 만드는 충돌이다. 다만 Windows
Copilot과 Git Bash 런타임 검증 공백이 남아 있으므로 “완전 지원”으로 단순 변경하기보다 지원 기능과
미검증 범위를 분리해 교정해야 한다.

### 6. Windows Copilot 설치 경로 분리

Unix 통합 설치기는 `--target copilot`을 지원하지만 Windows `install.ps1`은 `copilot` 타깃을
허용하지 않는다. Windows에서는 독립 `install-copilot.ps1`이 필요하며 Windows CI도 이를 검증하지
않는다.

관련 task:

- `docs/task/2026-06-07-windows-copilot-integration.md`

### 7. Windows Bash 런타임 검증 공백

Windows CI는 PowerShell 설치 산출물만 확인한다. 실제 Git Bash에서 hook, `gtask`, `ctask`,
`atask`를 실행하지 않는다.

관련 문서:

- `docs/issue/2026-06-07-postmerge-04-windows-hooks-untested.md`
- `docs/task/2026-06-07-windows-runtime-verification.md`

### 8. docs-sync 구형 설정 호환 미문서화

코드와 테스트는 다음 구형 3컬럼 형식도 지원한다.

```text
name<TAB>remote_root<TAB>local_dir
```

사용자 문서는 현재 5컬럼 형식만 설명한다. 신규 사용자는 5컬럼을 써야 하지만, 기존 설정을
마이그레이션하는 사용자를 위해 호환 범위와 권장 전환 형식을 기록할 필요가 있다.

### 9. 테스트 문서의 범위 드리프트

`tests/README.md`의 테스트 목록에는 `atask.bats`가 없었고 `install.bats` 설명도 Codex/Copilot
병합과 연결 점검까지 반영하지 못했다. 이번 변경에서 현재 테스트 파일 기준으로 교정했다.

`docs/AI-ENGINEERING-NOTES.md`의 Bats 개수는 특정 시점의 숫자로 고정되어 있어 테스트 추가 후
드리프트했다. 숫자를 제거하거나 CI에서 계산한 값을 사용해야 한다.

### 10. 내부 테스트용 환경변수

Windows 설치기는 다음 변수를 지원한다.

- `ARACHNE_HOME`: 실제 사용자 홈 대신 설치 루트를 지정
- `ARACHNE_SKIP_PATH=1`: 사용자 PATH 영구 변경 생략

이는 일반 사용자 기능보다 테스트 격리를 위한 내부 계약에 가깝다. 공개 CLI 레퍼런스에 노출할
필요는 낮지만 CI 유지보수 문서에는 기록되어야 한다.

## 잘 문서화된 기능

다음 기능은 구현과 사용자 문서가 비교적 잘 연결되어 있다.

- Unix 설치·업데이트·점검·내보내기·신규 프로젝트 생성
- Claude/Gemini/Codex/Copilot 규칙 연결 방식
- `gtask`, `ctask`, `atask` 역할과 주요 옵션
- 훅 이벤트와 기본 동작
- tmux 워크스페이스 관리
- docs-sync의 현재 5컬럼 설정, pull/push, dry-run, delete
- Obsidian과 Syncthing 동기화 방식 비교
- commands, agents, skills, rules 인덱스

## 완료 조건

- CI 운영 가이드가 실제 workflow와 연결된다.
- 미문서화·오표기 항목이 task로 그룹화되어 추적된다.
- 사용자에게 영향을 주는 명칭 오류는 즉시 교정된다.
- 남은 항목은 구현과 문서를 함께 수정할 수 있는 검증 가능한 작업으로 분리된다.
