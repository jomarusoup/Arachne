---
Title: "codegraph 사용법"
creation: 2026-06-14
modification: 2026-06-14
tags:
 - "arachne"
 - "tools"
 - "codegraph"
 - "code-intelligence"
aliases:
 - "codegraph"
---
MOC:: [[Arachne]]
FROM:: [[arachne-tools]]

# codegraph

임의의 코드베이스에 대한 **코드 인텔리전스·지식 그래프** CLI. 심볼 검색, 호출 관계 추적,
변경 영향 분석을 제공한다. Claude 플러그인이 아니라 독립 바이너리로 PATH에 설치되며,
Arachne는 `/codegraph` 슬래시 커맨드 래퍼를 제공한다.

- 저장소: <https://github.com/colbymchenry/codegraph>
- 통합: PATH 설치(`~/.local/bin/codegraph`) + `commands/codegraph.md` ([extras-setup.md](extras-setup.md))

## 설치

```bash
git clone https://github.com/colbymchenry/codegraph.git ~/codegraph
arachne --extras --codegraph   # 또는: bash ~/Arachne/setup-extras.sh --codegraph
codegraph --version            # 확인
```

클론이 없으면 `npm install -g @colbymchenry/codegraph` 로 폴백한다.

## 핵심 커맨드

| 커맨드 | 용도 |
| --- | --- |
| `codegraph init [path]` | 프로젝트 초기화 + 최초 인덱스 (`.codegraph/` 생성) |
| `codegraph index [path]` | 전체 파일 인덱싱 |
| `codegraph sync [path]` | 마지막 인덱스 이후 변경분 동기화 |
| `codegraph status [path]` | 인덱스 상태·통계 |
| `codegraph query <검색어>` | 심볼 검색 |
| `codegraph explore <질의...>` | 관련 심볼 소스 + 호출 경로를 한 번에 |
| `codegraph node <이름>` | 한 심볼의 소스 + 호출자/피호출자 추적 (또는 파일 읽기) |
| `codegraph callers <심볼>` | 해당 심볼을 호출하는 모든 함수/메서드 |
| `codegraph callees <심볼>` | 해당 심볼이 호출하는 모든 함수/메서드 |
| `codegraph impact <심볼>` | 심볼 변경이 영향을 주는 코드 분석 |
| `codegraph affected [files...]` | 변경된 소스에 영향받는 테스트 파일 |
| `codegraph files` | 인덱스 기준 파일 구조 |
| `codegraph install` | codegraph **MCP 서버**를 에이전트(Claude Code·Cursor·Codex 등)에 설치 |
| `codegraph upgrade [version]` | 최신(또는 특정) 릴리스로 업데이트 |

## 기본 흐름

```bash
cd ~/myproject
codegraph init                 # 최초 인덱스
codegraph impact PaymentService.charge   # 이 심볼을 바꾸면 어디가 영향받나
codegraph callers validateToken          # 누가 이 함수를 호출하나
codegraph affected src/auth/*.ts         # 변경에 영향받는 테스트
codegraph sync                 # 코드 바뀐 뒤 인덱스 갱신
```

## `/codegraph` 래퍼

Arachne의 `commands/codegraph.md`가 `/codegraph` 슬래시 커맨드로 노출된다. Claude가
조사 단계에서 이 도구의 존재를 인지하고 적절한 서브커맨드를 골라 실행한다.

```
/codegraph impact AuthMiddleware     # 인자를 그대로 codegraph 에 전달
/codegraph                           # 인자 없으면 --help 확인 후 맥락에 맞게 실행
```

## MCP 통합 (선택)

`/codegraph` 래퍼는 "Claude가 Bash로 CLI를 호출"하는 가벼운 방식이다. 더 깊은 통합을
원하면 codegraph 자체 MCP 서버를 설치할 수 있다:

```bash
codegraph install              # Claude Code 등에 codegraph MCP 서버 등록
```

이 경우 `codegraph_explore`·`codegraph_node` 등이 MCP 도구로 직접 노출된다. 래퍼와
MCP는 양립하며, 팀 선호에 따라 선택한다.

## Arachne 워크플로와의 접점

`development-workflow §0 조사·재사용`, `issue-workflow 범위 파악·의존성 확인` 단계에서
**심볼 단위 영향 분석**의 정본 도구다. 구조·도메인 개관은 [Understand-Anything](understand-anything.md)이,
대규모 입력 요약은 `gemini-task`가 보완한다. 대용량 출력은 컨텍스트에 통째로 끌어오지 말고
필요한 범위만 요약해 토큰을 아낀다(`rules/common/performance.md`).

> 산출물 `.codegraph/`는 프로젝트별로 생성되며 background daemon으로 동작할 수 있다
> (`codegraph daemon` 으로 관리, `codegraph unlock` 으로 stale lock 해제).
