---
Title: "Understand-Anything 사용법"
creation: 2026-06-14
modification: 2026-07-01
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
Claude Code에서는 `/understand*` 슬래시 커맨드로, Codex에서는 스킬명 또는 자연어 요청으로
사용한다.

- 저장소: <https://github.com/Egonex-AI/Understand-Anything>
- 통합: 로컬 마켓플레이스 `understand-anything@understand-anything` ([extras-setup.md](extras-setup.md))

## 설치

### 요구사항

- Node.js 22 이상
- pnpm 10 이상
- git 저장소 안에서 실행 권장

확인:

```bash
node --version
pnpm --version
```

> `npm`만 있으면 부족하다. Understand-Anything의 분석기와 대시보드는 플러그인 워크스페이스를
> 빌드하기 위해 `pnpm`을 사용한다. `mnpm`이 아니라 `pnpm`이다.

Rocky/RHEL 계열에서 시스템 루트에 설치하려면 관리자 권한으로 Node.js 22 모듈과 pnpm을 준비한다.

```bash
sudo dnf module reset nodejs -y
sudo dnf module enable nodejs:22 -y
sudo dnf install nodejs -y
sudo npm install -g pnpm@10
```

권한이 없으면 사용자 또는 프로젝트 로컬 Node.js 22 + pnpm을 PATH 앞쪽에 둔 뒤 사용한다.

### Arachne 확장 도구 설치

```bash
git clone https://github.com/Egonex-AI/Understand-Anything.git ~/Understand-Anything
arachne -i --with-ua        # 하네스 설치/재설치와 함께 UA만 멱등 설정
arachne --extras --ua          # 또는: bash ~/Arachne/setup-extras.sh --ua
# Claude Code 재시작 후 /understand 사용 가능
```

`--with-ua`는 하네스 설치 흐름에 Understand-Anything만 붙인다. taste-skill·codegraph까지 전부
같이 설치하려면 기존 `arachne -i --with-extras`를 사용한다. 업데이트도 동일하다.

```bash
arachne -u --with-ua        # git pull -> 재설치 -> UA 클론/플러그인 갱신
```

Windows PowerShell:

```powershell
arachne -Install -WithUa
arachne -Update -WithUa
```

## Claude에서 사용

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

한국어 산출물을 원하면 분석 단계에서 언어를 지정한다.

```text
/understand --language ko
/understand-dashboard
/understand-chat "이 프로젝트의 인증 흐름을 설명해줘"
/understand-diff
```

## Codex에서 사용

Codex에서는 Claude처럼 `/understand` 슬래시 커맨드 목록이 UI에 보이지 않을 수 있다. 대신 설치된
스킬 이름이나 자연어 요청으로 호출한다.

```text
understand-anything:understand 스킬로 현재 프로젝트를 분석해줘. --language ko 옵션을 사용해줘.
```

```text
Understand Anything으로 현재 repo 분석해줘. 결과는 한국어로 만들어줘.
```

그래프 생성 후 대시보드:

```text
understand-anything:understand-dashboard로 그래프 대시보드를 실행해줘.
```

그래프 기반 질문:

```text
Understand Anything 그래프를 사용해서 이 프로젝트 구조를 한국어로 설명해줘.
```

변경 영향 분석:

```text
understand-anything:understand-diff로 현재 변경사항의 영향 범위를 분석해줘.
```

## 기본 흐름

```
/understand --language ko                   # 최초 분석 (.understand-anything/ 생성)
/understand-dashboard                       # 그래프 탐색
/understand-chat How does the payment flow work?
/understand-explain src/auth/login.ts       # 특정 파일 심층 설명
/understand-diff                            # 내 변경의 영향 파악
/understand                                 # 재실행 — 변경 파일만 증분 분석
```

Codex CLI 환경에서는 같은 흐름을 자연어로 요청한다.

```text
understand
understand-dashboard
```

대시보드는 뷰어이므로 먼저 `.understand-anything/knowledge-graph.json`이 있어야 한다. 없으면
`understand`부터 실행한다.

### ignore 정책

최초 분석 때 `.understand-anything/.understandignore`가 없으면 starter 파일을 만든다. 기본값은
모두 주석이므로 사용자가 제외할 항목을 고른 뒤 계속한다.

Arachne 저장소처럼 문서 자체가 하네스 자산인 경우 `agents/`, `commands/`, `rules/`, `skills/`의
Markdown은 분석에 포함하는 편이 좋다. 일반 프로젝트에서는 아래처럼 산출물·테스트·문서 디렉터리를
제외할 수 있다.

```gitignore
.understand-anything/
docs/
tests/
*.test.*
*.spec.*
**/*_test.go
```

`docs/`와 `tests/`를 제외하면 그래프는 런타임 코드·설정·스크립트 중심으로 작아진다. 제외 정책을
바꾼 뒤에는 `understand --full`로 다시 만드는 편이 안전하다.

## 옵션·특징

- **언어** — `/understand --language ko` (지원: en·zh·zh-TW·ja·ko·ru). 최초 실행 시 대화
  언어를 감지해 확인을 묻고, 선택은 `.understand-anything/config.json`에 저장된다.
- **증분 분석** — 재실행 시 변경된 파일만 다시 분석한다.
- **자동 갱신** — `/understand --auto-update` 로 post-commit 훅을 걸면 커밋마다 그래프를
  구조 변경 감지 기반으로 증분 갱신한다(코스메틱 변경엔 토큰 0).
- **범위 지정** — `/understand src/frontend` 로 대규모 모노레포의 하위 디렉터리만.

## 대시보드 주의사항

- 대시보드는 `.understand-anything/knowledge-graph.json`이 있어야 열린다. 먼저 `/understand` 또는
  Codex의 `understand-anything:understand` 요청으로 그래프를 생성한다.
- 대시보드는 그래프 파일의 텍스트를 보여준다. 한국어 대시보드 내용을 원하면 그래프 생성 단계에서
  `--language ko`를 사용한다.
- 실행 시 Vite 개발 서버가 토큰이 포함된 URL을 출력한다. `?token=...`이 빠진 URL은 접근 게이트에
  막힐 수 있다.

### 원격 CLI에서 맥북 브라우저로 보기

원격 서버의 Codex/Claude CLI에서 대시보드를 띄우면 URL의 `127.0.0.1`은 **원격 서버 자신**이다.
맥북 브라우저에서 보려면 맥북 터미널에서 SSH local port forwarding을 연다.

```bash
ssh -p <ssh-port> -N -L 5173:127.0.0.1:5173 <user>@<remote-host>
```

그 다음 맥북 브라우저에서 dashboard가 출력한 토큰 URL을 연다.

```text
http://127.0.0.1:5173/?token=<dashboard-token>
```

맥북의 5173 포트가 이미 사용 중이면 로컬 포트만 바꾼다.

```bash
ssh -p <ssh-port> -N -L 15173:127.0.0.1:5173 <user>@<remote-host>
```

```text
http://127.0.0.1:15173/?token=<dashboard-token>
```

`ssh -N -L ...` 명령은 정상이어도 출력 없이 계속 대기한다. OpenSSH가
`connection is not using a post-quantum key exchange algorithm` 경고를 낼 수 있는데, 이는 터널
실패가 아니라 서버 KEX 알고리즘에 대한 보안 경고다.

### 프로젝트 업데이트 후

- 파일 몇 개 수정: `understand` 재실행 — 기존 `meta.json`과 fingerprint baseline이 있으면 변경 파일
  중심으로 증분 분석한다.
- 구조가 크게 바뀜, ignore 정책 변경, 그래프가 이상함: `understand --full`
- 그래프가 이미 있고 화면만 다시 보고 싶음: `understand-dashboard`

## Arachne 워크플로와의 접점

`development-workflow §0 조사·재사용`, `issue-workflow 범위 파악` 단계에서 코드베이스
구조·도메인을 빠르게 파악할 때 사용한다. 변경 영향 분석은 `/understand-diff`가,
심볼 단위 정밀 추적은 [codegraph](codegraph.md)가 보완한다.

**행동 배선** — `agents/planner.md`의 Architecture Review(Codebase Analysis) 단계에서, 가용하면
`/understand` 지식 그래프·`/understand-explain`을 먼저 참고해 아키텍처 레이어와 의존 방향을
잡도록 지정한다. 미설치면 planner 는 Grep/Glob 으로 구조를 직접 훑는다.

> 산출물 `.understand-anything/`(graph·meta·config)는 프로젝트별로 생성된다.
> 프로젝트 저장소에 커밋할지는 팀 정책에 따른다.
