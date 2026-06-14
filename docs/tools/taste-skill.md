---
Title: "taste-skill 사용법"
creation: 2026-06-14
modification: 2026-06-14
tags:
 - "arachne"
 - "tools"
 - "taste-skill"
 - "frontend"
 - "design"
aliases:
 - "taste-skill"
---
MOC:: [[Arachne]]
FROM:: [[arachne-tools]]

# taste-skill

AI가 만든 프론트엔드의 품질을 끌어올리는 **안티-슬롭(anti-slop) 디자인 스킬** 모음.
보일러플레이트 느낌의 UI 대신 레이아웃·타이포그래피·모션·여백을 강화한다.
참조 이미지 보드를 만드는 이미지 생성 스킬도 포함한다.

- 저장소: <https://github.com/Leonxlnx/taste-skill>
- 통합: 로컬 마켓플레이스 `taste-skill@taste-skill` ([extras-setup.md](extras-setup.md))

## 설치

```bash
git clone https://github.com/Leonxlnx/taste-skill.git ~/taste-skill
arachne --extras --taste       # 또는: bash ~/Arachne/setup-extras.sh --taste
# Claude Code 재시작 후 스킬 자동 발견
```

> Claude Code 플러그인으로 설치하면 스킬이 자동 로드된다. (비-Claude 도구는 저장소의
> `npx skills add` 경로를 쓴다 — Arachne 통합과는 별개.)

## 스킬 목록

**구현 스킬 (코드 출력)**

| 스킬 | 용도 |
| --- | --- |
| `design-taste-frontend` (taste-skill) | 🆕 v2 기본 스킬. 브리프 추론 → 디자인 언어 결정 → VARIANCE/MOTION/DENSITY 세 다이얼 조정. GSAP 스켈레톤·em-dash 금지·redesign 감사 프로토콜 |
| `design-taste-frontend-v1` | 원본 v1 (특정 동작에 의존하는 프로젝트용 보존판) |
| `gpt-taste` | GPT/Codex용 엄격 변형 — 높은 레이아웃 변동, 강한 GSAP, 공격적 안티-슬롭 |
| `redesign-existing-projects` | 기존 프로젝트: UI 감사 후 레이아웃·여백·위계·스타일 수정 |
| `high-end-visual-design` (soft) | 차분하고 고급스러운 UI — 부드러운 대비·여백·프리미엄 폰트·스프링 모션 |
| `industrial-brutalist-ui` | 브루탈리즘 스타일 |
| `minimalist-ui` | 미니멀 스타일 |
| `stitch-design-taste` | stitch 스타일 |
| `image-to-code` | 이미지 우선 파이프라인 — 레퍼런스 생성·분석 후 그에 맞춰 구현 |
| `full-output-enforcement` (output) | 모델이 반쯤 만든 작업을 낼 때 — placeholder 없이 완전 출력 강제 |

**이미지 생성 스킬 (참조 이미지만 출력)**

| 스킬 | 용도 |
| --- | --- |
| `imagegen-frontend-web` | 웹 프론트엔드 레퍼런스 보드 |
| `imagegen-frontend-mobile` | 모바일 프론트엔드 레퍼런스 보드 |
| `brandkit` | 브랜드 키트 레퍼런스 |

## 사용

스킬은 작업 맥락에 따라 Claude가 자동으로 꺼내 쓰거나, 명시적으로 요청한다.

```
"이 랜딩 페이지를 taste-skill로 다시 디자인해줘 — 고급스럽고 여백 넉넉하게"
"redesign 스킬로 이 대시보드 UI 감사부터 해줘"
```

## Arachne 워크플로와의 접점

`rules/web/design-quality.md`(안티-템플릿 정책)와 `skills/frontend-patterns.md`·
`make-interfaces-feel-better.md`를 보완한다. 웹/프론트엔드 작업 시 디자인 품질 게이트로
함께 사용한다.

**행동 배선** — `rules/web/design-quality.md`의 "프론트엔드 코드 작성 전" 6번에서, 설치돼 있으면
taste-skill 을 안티-슬롭 정책의 **실행 도구로 우선 적용**하도록 지정한다(기존 UI 개선은
`redesign-skill`, 새 랜딩/포트폴리오는 `taste-skill` 본체). 미설치면 그 파일의 원칙을 직접 적용한다.
