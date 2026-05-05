---
Title: CLAUDE
creation: 2026-05-05
modification: 2026-05-05
tags:
aliases:
---
> FROM::

# Claude Code 글로벌 지시서

실제 Global로 사용에 바로 적용 가능한 Agent, Skill, Hooks, Commands, Rule 및 MCP등 여러 세팅이다.

@rules/common/workflow.md
@rules/common/coding-style.md
@rules/common/patterns.md
@rules/common/issue-workflow.md
@rules/common/ui-layout.md

## Architecture

이 프로젝트의 구성요소는 아래와 같습니다.

- agents/ - 위임을 위한 전문 하위 에이전트(기획자, 코드 검토자, TDD 가이드 등)
- skill/ - 워크플로 정의 및 도메인 지식 (코딩 표준, 패턴, 테스팅)
- commands/ - 사용자가 호출하는 슬래시 명령어(/tdd, /plan, /e2e 등)
- hooks/ - 트리거 기반 자동화(세션 지속성, 사전/사후 도구 후크)
- rules/ - 항상 지침을 준수하세요 (보안, 코딩 스타일, 테스트 요구 사항)
- mcp-configs/ - 외부 통합을 위한 MCP 서버 구성
- tests/ - 스크립트 및 유틸리티용 테스트 모음

##  Developmnet Notes

- 패키지 관리자 감지: npm, pnpm, yarn, bun ( `CLAUDE_PACKAGE_MANAGER`환경 변수 또는 프로젝트 설정을 통해 구성 가능)
- 에이전트 형식: YAML 프런트매터(이름, 설명, 도구, 모델)가 포함된 Markdown
- 스킬 형식: 사용 시점, 작동 방식, 예시를 명확하게 구분한 마크다운 형식
- 스킬 배치: skills/ 폴더에 정리되어 있으며, ~/.claude/skills/ 경로에서 생성/가져오기됩니다. 자세한 내용은 docs/SKILL-PLACEMENT-POLICY.md를 참조하세요.
- 후크 형식: 매처 조건 및 명령/알림 후크가 포함된 JSON

