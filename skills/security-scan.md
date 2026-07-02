---
name: security-scan
description: AgentShield를 사용해 Claude Code 설정(.claude/ 디렉토리)의 보안 취약점·잘못된 설정·인젝션 위험 검사. CLAUDE.md, settings.json, MCP 서버, 훅, 에이전트 정의 확인.
triggers:
  paths: [".claude/**", "**/settings.json"]
  keywords: ["설정 보안", "AgentShield", "MCP 보안", "훅 감사"]
---

# 보안 스캔 스킬

[AgentShield](https://github.com/affaan-m/agentshield)를 사용해 Claude Code 설정을 감사한다.

## 언제 활성화하나

- 새 Claude Code 프로젝트 설정 시
- `.claude/settings.json`, `CLAUDE.md`, MCP 설정 수정 후
- 설정 변경 커밋 전
- 기존 Claude Code 설정이 있는 레포에 온보딩 시
- 정기 보안 위생 점검

## 검사 대상

| 파일            | 확인 항목                                                         |
| --------------- | ----------------------------------------------------------------- |
| `CLAUDE.md`     | 하드코딩된 비밀값, 자동 실행 지시, 프롬프트 인젝션 패턴           |
| `settings.json` | 지나치게 허용적인 허용 목록, 누락된 거부 목록, 위험한 우회 플래그 |
| `mcp.json`      | 위험한 MCP 서버, 하드코딩된 환경변수 비밀값, npx 공급망 위험      |
| `hooks/`        | 인터폴레이션을 통한 커맨드 인젝션, 데이터 유출, 조용한 에러 억제  |
| `agents/*.md`   | 제한 없는 도구 접근, 프롬프트 인젝션 표면, 모델 미지정            |

## 사전 요구사항

AgentShield가 설치되어 있어야 한다:

```bash
# 설치 확인
npx ecc-agentshield --version

# 전역 설치 (권장)
npm install -g ecc-agentshield

# 또는 npx로 직접 실행 (설치 불필요)
npx ecc-agentshield scan .
```

## 사용법

### 기본 스캔

현재 프로젝트의 `.claude/` 디렉토리 대상:

```bash
# 현재 프로젝트 스캔
npx ecc-agentshield scan

# 특정 경로 스캔
npx ecc-agentshield scan --path /path/to/.claude

# 최소 심각도 필터 적용
npx ecc-agentshield scan --min-severity medium
```

### 출력 형식

```bash
# 터미널 출력 (기본값) — 등급 포함 컬러 리포트
npx ecc-agentshield scan

# JSON — CI/CD 통합용
npx ecc-agentshield scan --format json

# 마크다운 — 문서화용
npx ecc-agentshield scan --format markdown

# HTML — 독립형 다크테마 리포트
npx ecc-agentshield scan --format html > security-report.html
```

### 자동 수정

안전한 수정 자동 적용 (자동 수정 가능으로 표시된 항목만):

```bash
npx ecc-agentshield scan --fix
```

이 명령은:
- 하드코딩된 비밀값을 환경변수 참조로 교체
- 와일드카드 권한을 범위 지정 대안으로 강화
- 수동 전용 제안은 수정하지 않음

### 심층 분석

적대적 3-에이전트 파이프라인으로 더 깊은 분석:

```bash
# ANTHROPIC_API_KEY 필요
export ANTHROPIC_API_KEY=your-key
npx ecc-agentshield scan --opus --stream
```

3단계 실행:
1. **공격자 (레드팀)** — 공격 벡터 탐색
2. **방어자 (블루팀)** — 강화 권장사항
3. **감사자 (최종 판정)** — 양쪽 관점 종합

### 보안 설정 초기화

안전한 `.claude/` 설정을 처음부터 스캐폴딩:

```bash
npx ecc-agentshield init
```

생성 항목:
- 범위 지정 권한과 거부 목록이 있는 `settings.json`
- 보안 모범 사례가 있는 `CLAUDE.md`
- `mcp.json` 플레이스홀더

## 심각도 등급

| 등급 | 점수   | 의미          |
| ---- | ------ | ------------- |
| A    | 90-100 | 안전한 설정   |
| B    | 75-89  | 사소한 이슈   |
| C    | 60-74  | 주의 필요     |
| D    | 40-59  | 중요 위험     |
| F    | 0-39   | 심각한 취약점 |

## 결과 해석

### Critical (즉시 수정)
- 설정 파일에 하드코딩된 API 키 또는 토큰
- 허용 목록에 `Bash(*)` (무제한 셸 접근)
- `${file}` 인터폴레이션을 통한 훅의 커맨드 인젝션
- 셸을 실행하는 MCP 서버

### High (운영 전 수정)
- CLAUDE.md의 자동 실행 지시 (프롬프트 인젝션 벡터)
- 권한에 누락된 거부 목록
- 불필요한 Bash 접근 권한을 가진 에이전트

### Medium (권장)
- 훅의 조용한 에러 억제 (`2>/dev/null`, `|| true`)
- PreToolUse 보안 훅 누락
- MCP 서버 설정의 `npx -y` 자동 설치

### Info (인식)
- MCP 서버 설명 누락
- 올바르게 플래그된 금지 지시
