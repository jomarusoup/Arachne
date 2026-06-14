---
Title: "Understand-Anything 사용법"
creation: 2026-06-14
modification: 2026-06-14
tags:
 - "arachne"
 - "tools"
 - "understand-anything"
 - "codebase-analysis"
aliases:
 - "understand-anything"
 - "UA"
---
MOC:: [[Arachne]]
FROM:: [[arachne-tools]]

# Understand-Anything

LLM 기반 코드베이스 분석 플러그인. 대화형 지식 그래프, 가이드 투어, 심층 설명을 생성한다.
Claude Code 플러그인으로 통합되어 `/understand*` 슬래시 커맨드를 제공한다.

- 저장소: <https://github.com/Egonex-AI/Understand-Anything>
- 통합: 로컬 마켓플레이스 `understand-anything@understand-anything` ([extras-setup.md](extras-setup.md))

## 설치

```bash
git clone https://github.com/Egonex-AI/Understand-Anything.git ~/Understand-Anything
arachne --extras --ua          # 또는: bash ~/Arachne/setup-extras.sh --ua
# Claude Code 재시작 후 /understand 사용 가능
```

## 커맨드

| 커맨드 | 용도 |
| --- | --- |
| `/understand` | 코드베이스 분석 + 지식 그래프 생성 (기본 진입점) |
| `/understand-dashboard` | 인터랙티브 대시보드(그래프 시각화) 열기 |
| `/understand-chat <질문>` | 코드베이스에 대해 자연어 질의 |
| `/understand-diff` | 현재 변경(diff)의 영향 분석 |
| `/understand-explain <경로>` | 특정 파일·함수 심층 설명 |
| `/understand-onboard` | 신규 팀원용 온보딩 가이드 생성 |
| `/understand-domain` | 비즈니스 도메인 지식(도메인·플로우·단계) 추출 |
| `/understand-knowledge <wiki경로>` | Karpathy 패턴 LLM wiki 지식 베이스 분석 |

## 기본 흐름

```
/understand                                 # 최초 분석 (.understand-anything/ 생성)
/understand-dashboard                       # 그래프 탐색
/understand-chat How does the payment flow work?
/understand-explain src/auth/login.ts       # 특정 파일 심층 설명
/understand-diff                            # 내 변경의 영향 파악
/understand                                 # 재실행 — 변경 파일만 증분 분석
```

## 옵션·특징

- **언어** — `/understand --language ko` (지원: en·zh·zh-TW·ja·ko·ru). 최초 실행 시 대화
  언어를 감지해 확인을 묻고, 선택은 `.understand-anything/config.json`에 저장된다.
- **증분 분석** — 재실행 시 변경된 파일만 다시 분석한다.
- **자동 갱신** — `/understand --auto-update` 로 post-commit 훅을 걸면 커밋마다 그래프를
  구조 변경 감지 기반으로 증분 갱신한다(코스메틱 변경엔 토큰 0).
- **범위 지정** — `/understand src/frontend` 로 대규모 모노레포의 하위 디렉터리만.

## Arachne 워크플로와의 접점

`development-workflow §0 조사·재사용`, `issue-workflow 범위 파악` 단계에서 코드베이스
구조·도메인을 빠르게 파악할 때 사용한다. 변경 영향 분석은 `/understand-diff`가,
심볼 단위 정밀 추적은 [codegraph](codegraph.md)가 보완한다.

> 산출물 `.understand-anything/`(graph·meta·config)는 프로젝트별로 생성된다.
> 프로젝트 저장소에 커밋할지는 팀 정책에 따른다.
