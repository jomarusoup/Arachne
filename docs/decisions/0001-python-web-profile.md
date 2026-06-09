---
Title: "ADR-0001 Python·Web project profile"
creation: 2026-06-09
modification: 2026-06-09
tags:
 - "arachne"
 - "decision"
 - "python"
 - "web"
aliases:
 - "adr-python-web-profile"
---
MOC:: [[Arachne]]
FROM:: [[2026-06-09-python-web-profile-foundation]]

# ADR-0001: Python·Web project profile

## 상태

Accepted

## 배경

Arachne의 전역 자산은 systems, Python, Web 규칙을 함께 제공하지만 사용 프로젝트의 검증 계약은
`git diff --check`만 생성한다. 전역 자산을 먼저 물리적으로 분리하면 Claude 심볼릭 링크, 다른 CLI의
공통 규약, 업데이트 호환성까지 동시에 바뀌어 위험이 크다.

## 결정

첫 단계 profile은 **프로젝트 CI 계약**에 적용한다.

| profile | 기본 검증 대상 | 기본 도구 |
| --- | --- | --- |
| `minimal` | Git whitespace | Git |
| `python` | format, lint, type, unit, dependency audit | Python 3.12, uv, Ruff, mypy, pytest, pip-audit |
| `web` | lint, type, unit, build, E2E | Node.js 22, Corepack, pnpm, Playwright |
| `python-web` | Python과 Web 전체 | 위 두 profile의 합집합 |

기본값은 기존 호환성을 위해 `minimal`로 둔다. FastAPI와 Vite React를 권장 시작점으로 삼되,
Django와 Next.js는 실제 채택 프로젝트가 생길 때 선택 pack으로 추가한다.

## 소유권

- Arachne 관리: `.arachne/verify.sh`, `.github/workflows/arachne.yml`
- Arachne 초기 생성 후 사용자 소유: `.arachne/commands`
- Arachne 관리: `.arachne/profile`
- 사용 프로젝트 소유: `pyproject.toml`, lockfile, `package.json`, 애플리케이션 코드

profile 재실행은 관리 파일과 profile을 갱신하지만 기존 commands는 보존한다. 새 기본 명령을 적용하려면
사용자가 기존 commands를 삭제한 뒤 다시 초기화하거나 직접 편집한다.

## 결과

- 로컬 `/git`과 GitHub Actions가 동일한 명령을 실행한다.
- profile 선택만으로 필요한 CI 런타임이 준비된다.
- 프로젝트 도구가 준비되지 않았다면 CI는 명확하게 실패한다. “초록색이지만 아무것도 검사하지 않는”
  상태보다 의도된 실패를 우선한다.
- 전역 rules 선택 설치는 후속 ADR에서 별도로 다룬다.
