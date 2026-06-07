# Windows Setup — Claude Code · Codex CLI · Gemini CLI

Windows에서 세 CLI와 Arachne를 처음 설치하는 절차를 정리한다. 이 문서는 **Windows 11 +
PowerShell 7 또는 Windows PowerShell 5.1**을 기준으로 하며, Windows 10에서는 지원되는 최신
빌드가 필요하다.

## 1. 설치 방식 선택

| 방식 | 권장 상황 | Arachne 경로 |
|---|---|---|
| **Windows 네이티브 (권장)** | PowerShell, Windows Terminal, Windows 파일 시스템에서 작업 | `install.ps1` |
| **WSL2** | Linux 도구 체인, tmux, Linux 컨테이너 중심 작업 | WSL 안에서 `install.sh` |

Arachne의 Windows 래퍼(`gask.cmd`, `cask.cmd`, `atask.cmd`)는 Windows에 설치된 CLI를
호출한다. WSL에 설치한 CLI는 별도 Linux 환경이므로 Windows 설치와 설정·PATH·홈 디렉터리를
공유하지 않는다.

> 한 프로젝트에서는 Windows 네이티브와 WSL 중 하나를 주 실행 환경으로 정한다. Windows의
> `C:\Users\<USER>\...`와 WSL의 `/home/<user>/...`에 CLI를 각각 설치하면 설정 파일과 인증
> 상태도 각각 관리해야 한다.

## 2. 공통 준비

### 2.1 Windows Terminal, Git for Windows, Node.js 설치

PowerShell을 일반 사용자 권한으로 열고 설치 가능한 패키지를 먼저 확인한다.

```powershell
winget search --id Microsoft.WindowsTerminal
winget search --id Git.Git
winget search --id OpenJS.NodeJS.LTS
```

다음 명령으로 공통 도구를 설치한다.

```powershell
winget install --id Microsoft.WindowsTerminal --exact
winget install --id Git.Git --exact
winget install --id OpenJS.NodeJS.LTS --exact
```

설치 후 **터미널을 완전히 닫고 다시 연 다음** 버전을 확인한다.

```powershell
git --version
node --version
npm --version
Get-Command bash
```

`Get-Command bash`가 실패하면 Git for Windows의 기본 경로를 확인한다.

```powershell
Test-Path "C:\Program Files\Git\bin\bash.exe"
```

Arachne의 Claude 훅과 위임 래퍼는 `bash.exe`를 사용한다. Git이 다른 위치에 설치되었다면 해당
Git `bin` 디렉터리를 사용자 PATH에 추가한다.

### 2.2 PowerShell 실행 정책

현재 사용자 범위의 정책을 확인한다.

```powershell
Get-ExecutionPolicy -List
```

조직 정책이 허용한다면 현재 사용자에게만 원격 서명 정책을 적용할 수 있다.

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

정책을 변경할 수 없는 환경에서는 Arachne 설치 명령에만
`-ExecutionPolicy Bypass`를 사용한다. 조직에서 강제한 `MachinePolicy` 또는 `UserPolicy`는
임의로 우회하지 말고 관리자 정책을 따른다.

## 3. Claude Code 설치

Claude Code는 Windows 10 이상에서 WSL 또는 Git for Windows를 지원한다. Arachne의 네이티브
Windows 설치에서는 Git for Windows 방식이 가장 단순하다.

### 3.1 npm으로 설치

```powershell
npm install -g @anthropic-ai/claude-code
claude --version
```

`sudo npm install -g`는 Windows에서도 필요하지 않다. 권한 오류가 발생하면 관리자 PowerShell로
반복하기 전에 `npm config get prefix`와 사용자 PATH를 확인한다.

### 3.2 Git Bash 경로 지정

기본 Git for Windows 설치를 Claude Code가 찾지 못할 때만 사용자 환경변수를 설정한다.

```powershell
[Environment]::SetEnvironmentVariable(
    "CLAUDE_CODE_GIT_BASH_PATH",
    "C:\Program Files\Git\bin\bash.exe",
    "User"
)
```

새 터미널을 열고 확인한다.

```powershell
$env:CLAUDE_CODE_GIT_BASH_PATH
claude doctor
```

### 3.3 인증 및 첫 실행

작업할 Git 저장소에서 실행한다.

```powershell
Set-Location C:\path\to\project
claude
```

첫 실행 화면에서 브라우저 로그인을 진행한다. 조직에서 Anthropic Console/API 키 또는 클라우드
공급자 인증을 사용한다면 조직 정책에 맞는 인증 방식을 선택한다.

설치 상태와 런타임 문제는 다음 명령으로 점검한다.

```powershell
claude doctor
```

업데이트는 Claude Code의 자동 업데이트를 사용하거나 수동으로 실행한다.

```powershell
claude update
```

## 4. Codex CLI 설치

OpenAI의 현재 공식 저장소는 Windows용 PowerShell 설치 스크립트를 제공한다. Arachne
Windows 환경에서는 이 네이티브 설치 방식을 우선 권장한다.

### 4.1 공식 PowerShell 설치

다운로드 URL을 검토할 수 있는 환경에서는 스크립트를 파일로 받은 뒤 내용을 확인하고 실행한다.

```powershell
$installer = Join-Path $env:TEMP "codex-install.ps1"
Invoke-WebRequest "https://chatgpt.com/codex/install.ps1" -OutFile $installer
Get-Content $installer
powershell -ExecutionPolicy Bypass -File $installer
```

공식 문서의 단축 설치 명령은 다음과 같다.

```powershell
powershell -ExecutionPolicy Bypass -Command `
    "irm https://chatgpt.com/codex/install.ps1 | iex"
```

설치 후 새 터미널에서 확인한다.

```powershell
codex --version
Get-Command codex
```

### 4.2 npm 대안

Node.js가 이미 설치되어 있다면 npm으로도 설치할 수 있다.

```powershell
npm install -g @openai/codex
codex --version
```

네이티브 설치와 npm 설치를 동시에 유지하지 않는다. `Get-Command codex -All`에 여러 경로가
나오면 실제로 실행되는 첫 경로를 확인하고 한 설치 방식만 남긴다.

### 4.3 인증 및 첫 실행

프로젝트 루트에서 Codex를 시작한다.

```powershell
Set-Location C:\path\to\project
codex
```

첫 실행 안내에서 ChatGPT 계정 로그인을 선택하고 브라우저 인증을 완료한다. Codex 사용 권한과
사용량은 로그인한 ChatGPT 플랜 또는 조직 정책을 따른다.

API 키 기반 구성이 필요한 환경에서는 키를 코드나 저장소에 기록하지 말고 현재 PowerShell
세션에만 주입한다.

```powershell
$env:OPENAI_API_KEY = Read-Host "OPENAI_API_KEY"
codex
Remove-Item Env:OPENAI_API_KEY
```

로그인 상태를 명시적으로 설정해야 할 때는 다음 명령을 사용한다.

```powershell
codex login
```

## 5. Gemini CLI 설치

Gemini CLI의 표준 설치 방식은 Node.js와 npm을 사용한다.

### 5.1 npm으로 설치

안정 채널 최신 버전을 전역 설치한다.

```powershell
npm install -g @google/gemini-cli@latest
gemini --version
Get-Command gemini
```

설치 없이 일회성으로 확인하려면 `npx`를 사용할 수 있다.

```powershell
npx @google/gemini-cli
```

`npx`는 매번 패키지를 확인하는 실행 방식이므로 Arachne의 `gask` 위임 대상에는 전역 설치를
사용한다.

### 5.2 Google 계정 인증

프로젝트 루트에서 실행한다.

```powershell
Set-Location C:\path\to\project
gemini
```

첫 실행의 인증 선택 화면에서 **Sign in with Google**을 선택하고 브라우저 로그인을 완료한다.
조직의 Gemini Code Assist 라이선스를 사용한다면 조직에서 지정한 Google Cloud 프로젝트가
필요할 수 있다.

현재 세션에 프로젝트를 지정하는 예:

```powershell
$env:GOOGLE_CLOUD_PROJECT = "your-project-id"
gemini
```

### 5.3 Gemini API 키 대안

Google AI Studio에서 발급한 키를 사용하는 경우 현재 세션에만 입력한다.

```powershell
$env:GEMINI_API_KEY = Read-Host "GEMINI_API_KEY"
gemini
Remove-Item Env:GEMINI_API_KEY
```

키를 `$PROFILE`, 저장소의 `.env`, `settings.json` 또는 문서에 평문으로 커밋하지 않는다.
지속 저장이 필요하면 조직의 시크릿 관리자나 Windows 자격 증명 관리 정책을 사용한다.

업데이트:

```powershell
npm update -g @google/gemini-cli
```

## 6. Arachne 설치 및 세 CLI 연결

세 CLI 설치와 인증을 마친 뒤 Arachne를 설치한다.

```powershell
git clone https://github.com/jomarusoup/Arachne.git "$HOME\Arachne"
Set-Location "$HOME\Arachne"
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Install
```

`install.ps1`은 감지된 CLI에 다음 설정을 연결한다.

| CLI | Arachne가 연결하는 설정 |
|---|---|
| Claude Code | `~\.claude\CLAUDE.md`, `rules`, `hooks`, `skills`, `settings.json` |
| Gemini CLI | `~\.gemini\GEMINI.md` → Arachne `AGENTS.md` |
| Codex CLI | `~\.codex\AGENTS.md`에 Arachne 마커 구간 병합 |

새 터미널을 열고 전체 상태를 확인한다.

```powershell
arachne -Check
claude --version
codex --version
gemini --version
Get-Command arachne, claude, codex, gemini, bash
```

특정 CLI 설정만 다시 연결할 수도 있다.

```powershell
arachne -Install -Target claude
arachne -Install -Target codex
arachne -Install -Target gemini
```

위임 래퍼의 등록 여부:

```powershell
Get-Command gask, cask, atask
```

## 7. WSL2로 설치하는 대안

Codex는 WSL2를 공식 지원하고, Claude Code도 WSL 1/2를 지원한다. Linux 도구 체인과 `tws`
사용이 중요하다면 WSL2 안에 세 CLI와 Arachne를 모두 설치한다.

관리자 PowerShell:

```powershell
wsl --install
```

재부팅 후 WSL 버전을 확인한다.

```powershell
wsl --list --verbose
```

Ubuntu 터미널에서 Git과 Node.js LTS를 설치한 뒤 세 CLI를 설치한다. Node.js 버전 관리자는
`nvm` 또는 `fnm` 등 한 가지만 선택한다.

```bash
node --version
npm --version
git --version

npm install -g @anthropic-ai/claude-code
npm install -g @openai/codex
npm install -g @google/gemini-cli@latest

claude --version
codex --version
gemini --version
```

WSL 홈에 Arachne를 별도로 설치한다.

```bash
git clone https://github.com/jomarusoup/Arachne.git ~/Arachne
cd ~/Arachne
./install.sh
arachne -c
```

WSL에서 작업하는 저장소는 가능하면 `/mnt/c/...`보다 Linux 파일 시스템의
`~/projects/...`에 둔다. 파일 감시, 권한, 링크, 빌드 성능 문제가 줄어든다.

## 8. 문제 해결

### 명령을 찾을 수 없음

```powershell
Get-Command node, npm, bash, claude, codex, gemini -ErrorAction SilentlyContinue
npm config get prefix
$env:Path -split ";"
```

설치 직후라면 터미널을 완전히 다시 연다. npm 전역 prefix의 디렉터리가 사용자 PATH에 없으면
Node.js 설치를 복구하거나 해당 prefix를 PATH에 추가한다.

### PowerShell에서 `.ps1 cannot be loaded`

```powershell
Get-ExecutionPolicy -List
```

조직 정책을 확인하고, Arachne 설치에 한해서만 다음처럼 프로세스 단위 우회를 사용한다.

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Install
```

### 브라우저 로그인이 열리지 않음

- 기본 브라우저와 인터넷 연결을 확인한다.
- 회사 프록시·VPN·방화벽이 각 공급자의 로그인 및 API 도메인을 차단하는지 확인한다.
- 원격 터미널이라면 CLI가 표시하는 URL 또는 장치 코드를 로컬 브라우저에서 연다.
- Windows와 WSL의 인증 상태는 별개이므로 실제 실행 중인 환경에서 다시 로그인한다.

### 같은 명령이 여러 개 설치됨

```powershell
Get-Command claude -All
Get-Command codex -All
Get-Command gemini -All
```

Windows 네이티브, npm, WSL 설치를 섞었는지 확인한다. PowerShell에서 실행할 CLI는 Windows
PATH에, WSL에서 실행할 CLI는 Linux PATH에 각각 하나만 유지하는 것이 안전하다.

## 9. 공식 문서

- [Claude Code 설정](https://docs.anthropic.com/en/docs/claude-code/getting-started)
- [Claude Code CLI 레퍼런스](https://docs.anthropic.com/en/docs/claude-code/cli-usage)
- [Codex 공식 저장소](https://github.com/openai/codex)
- [Codex 설치 요구사항](https://github.com/openai/codex/blob/main/docs/install.md)
- [Codex와 ChatGPT 플랜](https://help.openai.com/en/articles/11369540-codex-in-chatgpt)
- [Gemini CLI 공식 저장소](https://github.com/google-gemini/gemini-cli)
- [Gemini CLI 시작 가이드](https://github.com/google-gemini/gemini-cli/blob/main/docs/get-started/index.md)
- [Microsoft WSL 설치](https://learn.microsoft.com/windows/wsl/install)
- [Microsoft WinGet install](https://learn.microsoft.com/windows/package-manager/winget/install)
