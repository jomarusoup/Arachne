---
Title: "확장 도구 설치 메커니즘 (setup-extras)"
creation: 2026-06-14
modification: 2026-07-01
tags:
 - "arachne"
 - "tools"
 - "install"
aliases:
 - "extras-setup"
 - "setup-extras"
---
MOC:: [[Arachne]]
FROM:: [[arachne-tools]]

# 확장 도구 설치 메커니즘 — `setup-extras`

[arachne-tools](README.md)의 세 도구를 설치·갱신·제거하는 크로스플랫폼 스크립트와
Arachne installer 연동을 설명한다.

## 파일

| 파일 | 플랫폼 | 역할 |
| --- | --- | --- |
| `setup-extras.sh` | Linux · macOS | 도구 설치 본체 (bash) |
| `setup-extras.ps1` | Windows | 동일 동작 (PowerShell, 네이티브 JSON 처리) |
| `install.sh` / `install.ps1` | 공통 | `--with-ua`·`--with-extras` 플래그 · `--extras` 단독 커맨드로 위 스크립트 호출 |
| `commands/codegraph.md` | 공통 | `/codegraph` 슬래시 커맨드 래퍼 (commands/ 는 `~/.claude/commands` 로 심볼릭) |

## 진입점 3가지

```bash
arachne --extras                # 단독 실행 (대화형 선택 메뉴)
arachne -i --with-ua            # 설치(재설치)와 함께 Understand-Anything 만
arachne -u --with-ua            # 업데이트와 함께 Understand-Anything 만
arachne -i --with-extras        # 설치(재설치)와 함께
arachne -u --with-extras        # 업데이트(git pull→재설치)와 함께 (멱등)
bash ~/Arachne/setup-extras.sh  # 스크립트 직접 호출
```

Windows:

```powershell
arachne -Extras
arachne -i -WithUa
arachne -u -WithUa
arachne -i -WithExtras
pwsh ~/Arachne/setup-extras.ps1
```

## 옵션 (setup-extras)

| Bash | PowerShell | 동작 |
| --- | --- | --- |
| `--all` | `-All` | 감지된 도구 전부 설치 (비대화형) |
| `--ua` | `-Ua` | Understand-Anything 만 |
| `--taste` | `-Taste` | taste-skill 만 |
| `--codegraph` | `-Codegraph` | codegraph 만 |
| `--no-clone` | `-NoClone` | 클론이 없어도 git clone 안 함 (기존 클론만) |
| `--update` | `-Update` | 기존 클론·플러그인·CLI 를 최신으로 갱신 |
| `-y`, `--yes` | `-y`, `-Yes` | 모든 프롬프트에 yes (감지된 전부) |
| `-h`, `--help` | `-h`, `-Help` | 도움말 |

선택 플래그를 하나도 주지 않으면 **터미널이면 대화형 항목별 선택**, 비터미널이면 도움말을
출력한다 (무인자=안전 원칙).

UA·taste-skill 은 Claude Code **로컬 마켓플레이스**라 로컬 클론이 필요하다. 클론이 없으면
아래 URL 에서 **자동으로 `git clone`** 한다(`--no-clone` 으로 비활성, git 미설치면 스킵).
codegraph 는 npm 전역 설치가 기본이라 클론이 필요 없다.

### 클론 위치 / 출처 override

| 클론 경로 env | 기본값 | 출처 URL env | 기본값 |
| --- | --- | --- | --- |
| `UA_CLONE` | `$HOME/Understand-Anything` | `UA_URL` | `github.com/Egonex-AI/Understand-Anything` |
| `TASTE_CLONE` | `$HOME/taste-skill` | `TASTE_URL` | `github.com/Leonxlnx/taste-skill` |
| `CODEGRAPH_CLONE` | `$HOME/codegraph` | `CODEGRAPH_URL` | `github.com/colbymchenry/codegraph` |

### 업데이트 (`--update`)

`arachne -u` 는 확장 도구도 **선택적으로 갱신**한다(대화형 선택 유지, 무인자=안전 원칙).
선택된 항목에 대해:

| 계층 | 갱신 동작 |
| --- | --- |
| UA · taste-skill 클론 | `git -C <clone> pull --ff-only` |
| 마켓플레이스 | `claude plugin marketplace update <market>` |
| 플러그인 | `claude plugin update <plugin>` |
| codegraph | `npm install -g --prefix $HOME/.local @colbymchenry/codegraph@latest` |

각 단계는 best-effort — 실패해도 경고만 남기고 다음으로 진행한다.

## 동작 상세

### A계층 — Claude 플러그인 (UA · taste-skill)

```
0. 클론 없으면 git clone <URL> <클론>        # 로컬 마켓플레이스 확보 (--no-clone 면 스킵)
1. 클론의 .claude-plugin/marketplace.json 존재 확인
2. claude plugin marketplace add <클론>     # 로컬 디렉터리를 마켓플레이스로 (멱등)
3. claude plugin install <plugin>@<market> --scope user
4. settings.template.json 의 enabledPlugins 에 키 추가  ← 핵심
5. settings.json(라이브)에도 멱등 보강
```

식별자:

| 도구 | `plugin@marketplace` |
| --- | --- |
| Understand-Anything | `understand-anything@understand-anything` |
| taste-skill | `taste-skill@taste-skill` |

### B계층 — codegraph CLI

```
1. 이미 PATH 에 codegraph 있으면 스킵 (멱등) — --update 면 @latest 로 갱신
2. 클론의 install.sh(unix)/install.ps1(win) 실행 → ~/.local/bin
   (클론 없으면 npm install -g --prefix $HOME/.local @colbymchenry/codegraph 폴백)
3. codegraph --version 으로 확인
```

> `--prefix $HOME/.local` 은 시스템 디렉터리(`/usr/lib`) 쓰기 권한 부족(EACCES)을 피한다.
> `~/.local/bin` 은 Arachne dotfiles 가 PATH 에 넣어 둔다.

`/codegraph` 래퍼(`commands/codegraph.md`)는 레포에 항상 존재하므로 별도 생성하지 않는다.

## 재설치 내구성 (가장 중요한 설계)

`arachne -i`는 `~/.claude/settings.json`을 `settings.template.json`에서 **통째로 재생성**한다.
따라서 `claude plugin install`만으로 켠 플러그인은 **다음 `arachne -i`에서 사라진다.**

setup-extras는 이를 막기 위해 `settings.template.json`의 `enabledPlugins`에도 키를 써넣는다.

- 마켓플레이스 등록은 Arachne가 건드리지 않는 `~/.claude/plugins/known_marketplaces.json`에
  들어가므로 자동 유지된다.
- 플러그인 활성화만 템플릿에 반영하면 재설치에도 살아남는다.

검증 (실제 확인된 동작):

```bash
arachne -i --target claude       # settings.json 재생성
jq '.enabledPlugins | keys[]' ~/.claude/settings.json | grep -E 'understand|taste'
# → 두 플러그인 모두 그대로 유지됨
```

> `settings.template.json` 변경은 Arachne 레포 변경이다. 커밋하면 다른 머신에서도
> (Syncthing/git) 동일 플러그인이 재설치 시 켜진다.

## 멱등성

전 과정이 재실행 안전하다. 이미 등록된 마켓플레이스·설치된 플러그인·PATH의 codegraph는
"이미 …" 로그만 남기고 건너뛴다. JSON 동기화도 키 추가/갱신이라 중복되지 않는다.

## 제거

```bash
# 플러그인
claude plugin uninstall understand-anything@understand-anything
claude plugin uninstall taste-skill@taste-skill
claude plugin marketplace remove understand-anything
claude plugin marketplace remove taste-skill
# settings.template.json 의 enabledPlugins 에서 해당 키도 직접 삭제 (재설치 방지)

# codegraph
sh ~/codegraph/install.sh --uninstall    # 또는 npm uninstall -g @colbymchenry/codegraph
```

## 문제해결

| 증상 | 원인 / 해결 |
| --- | --- |
| `claude CLI 미감지 — 플러그인 설치 스킵` | Claude Code CLI 미설치. codegraph는 영향 없음 |
| `마켓플레이스 매니페스트 없음` | 클론 경로 오류 → `UA_CLONE` 등으로 지정 |
| 플러그인이 안 보임 | **Claude Code 재시작** 필요 (`claude plugin list` 로 enabled 확인) |
| `codegraph 가 PATH 에 없음` | `~/.local/bin` 을 PATH 에 추가 (Arachne dotfiles가 보통 처리) |
| 재설치 후 플러그인 사라짐 | `settings.template.json` 에 enabledPlugins 키 누락 → setup-extras 재실행 |
