################################################################################
# FILE NAME   : setup-extras.ps1
# DESCRIPTION : Arachne 확장 도구 통합 설치 (Windows / PowerShell)
#               - Understand-Anything · taste-skill : Claude Code 로컬 마켓플레이스
#               - codegraph                         : 독립 CLI(PATH) + Arachne 래퍼
#               대화형 선택 메뉴 + 비대화형 플래그. 멱등 — 재실행 안전.
# DATA        : 2026-06-14
# Modification: 2026-06-15
################################################################################

param(
    [switch]$All,
    [switch]$Ua,
    [switch]$Taste,
    [switch]$Codegraph,
    [switch]$NoClone,
    [switch]$Update,
    [Alias("y")]
    [switch]$Yes,
    [Alias("h")]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#-------------------------------------------------------------------------------
# 전역 경로 — 스크립트 위치 기준 + 홈/클론 경로
#-------------------------------------------------------------------------------
$SCRIPT:REPO_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPT:HOME_DIR = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$SCRIPT:CLAUDE_DIR = Join-Path $SCRIPT:HOME_DIR ".claude"
$SCRIPT:SETTINGS_TEMPLATE = Join-Path $SCRIPT:REPO_DIR "settings.template.json"
$SCRIPT:SETTINGS_LIVE = Join-Path $SCRIPT:CLAUDE_DIR "settings.json"

$SCRIPT:UA_CLONE = if ($env:UA_CLONE) { $env:UA_CLONE } else { Join-Path $SCRIPT:HOME_DIR "Understand-Anything" }
$SCRIPT:TASTE_CLONE = if ($env:TASTE_CLONE) { $env:TASTE_CLONE } else { Join-Path $SCRIPT:HOME_DIR "taste-skill" }
$SCRIPT:CODEGRAPH_CLONE = if ($env:CODEGRAPH_CLONE) { $env:CODEGRAPH_CLONE } else { Join-Path $SCRIPT:HOME_DIR "codegraph" }

# 원격 저장소 URL — 클론이 없을 때 자동 git clone 출처 (env 로 override 가능)
$SCRIPT:UA_URL = if ($env:UA_URL) { $env:UA_URL } else { "https://github.com/Egonex-AI/Understand-Anything.git" }
$SCRIPT:TASTE_URL = if ($env:TASTE_URL) { $env:TASTE_URL } else { "https://github.com/Leonxlnx/taste-skill.git" }
$SCRIPT:CODEGRAPH_URL = if ($env:CODEGRAPH_URL) { $env:CODEGRAPH_URL } else { "https://github.com/colbymchenry/codegraph.git" }

$SCRIPT:UA_PLUGIN = "understand-anything@understand-anything"
$SCRIPT:UA_MARKET = "understand-anything"
$SCRIPT:TASTE_PLUGIN = "taste-skill@taste-skill"
$SCRIPT:TASTE_MARKET = "taste-skill"

$SCRIPT:LOG_PREFIX = "[Arachne-extras]"

################################################################################
# FUNCTION    : Log* — 접두어 붙은 로그 출력
################################################################################
function LogInfo { param([string]$Msg) Write-Output "$SCRIPT:LOG_PREFIX $Msg" }
function LogWarn { param([string]$Msg) Write-Warning "$SCRIPT:LOG_PREFIX $Msg" }

################################################################################
# FUNCTION    : ShowUsage
# DESCRIPTION : 사용법 출력
################################################################################
function ShowUsage {
    Write-Output "Usage: setup-extras.ps1 [OPTION]..."
    Write-Output ""
    Write-Output "Arachne extras (Understand-Anything / taste-skill / codegraph)"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  -All          install every detected extra (non-interactive)"
    Write-Output "  -Ua           Understand-Anything plugin only"
    Write-Output "  -Taste        taste-skill plugin only"
    Write-Output "  -Codegraph    codegraph CLI (+wrapper) only"
    Write-Output "  -NoClone      do not git clone when a clone is missing"
    Write-Output "  -Update       update existing clones/plugins/CLI to latest"
    Write-Output "  -y, -Yes      assume yes to all prompts"
    Write-Output "  -h, -Help     this help"
    Write-Output ""
    Write-Output "UA/taste-skill are local marketplaces; a missing clone is auto-git-cloned"
    Write-Output "(disable with -NoClone). codegraph installs via npm (no clone needed)."
    Write-Output ""
    Write-Output "Env (clone path): UA_CLONE, TASTE_CLONE, CODEGRAPH_CLONE"
    Write-Output "Env (source URL): UA_URL, TASTE_URL, CODEGRAPH_URL"
}

################################################################################
# FUNCTION    : Clone-Repo
# DESCRIPTION : 로컬 클론이 없으면 git clone (멱등). -NoClone 이면 클론 안 함.
#               -Update 면 기존 클론에 git pull. 이미 있으면 덮어쓰지 않는다.
# PARAMETERS  : string Label - 표시 이름
#               string Url   - 원격 저장소 URL
#               string Clone - 로컬 클론 경로
# RETURNED    : bool (클론 사용 가능 여부)
################################################################################
function Clone-Repo {
    param([string]$Label, [string]$Url, [string]$Clone)

    $hasGitDir = Test-Path (Join-Path $Clone ".git")
    $hasManifest = Test-Path (Join-Path $Clone ".claude-plugin\marketplace.json")
    if ($hasGitDir -or $hasManifest) {
        if ($Update -and $hasGitDir -and ($null -ne (Get-Command git -ErrorAction SilentlyContinue))) {
            LogInfo "${Label}: git pull (update) - $Clone"
            try { & git -C $Clone pull --ff-only } catch { LogWarn "${Label}: git pull failed - $Clone" }
        } else {
            LogInfo "${Label}: clone already present - $Clone"
        }
        return $true
    }
    if (Test-Path $Clone) {
        LogWarn "${Label}: $Clone is not a git clone; check manually"
        return $false
    }
    if ($NoClone) {
        LogWarn "${Label}: clone missing + -NoClone; skip ($Clone)"
        return $false
    }
    if ($null -eq (Get-Command git -ErrorAction SilentlyContinue)) {
        LogWarn "${Label}: git not installed; cannot clone ($Clone)"
        return $false
    }

    LogInfo "${Label}: git clone $Url -> $Clone"
    try {
        & git clone --depth 1 $Url $Clone
        return $true
    } catch {
        LogWarn "${Label}: git clone failed - $Url"
        return $false
    }
}

################################################################################
# FUNCTION    : Confirm
# DESCRIPTION : [Y/n] 프롬프트 — Yes 면 즉시 true
# PARAMETERS  : string Prompt - 질문 문구
# RETURNED    : bool
################################################################################
function Confirm {
    param([string]$Prompt)
    if ($Yes) { return $true }
    $reply = Read-Host "$SCRIPT:LOG_PREFIX $Prompt [Y/n]"
    return ($reply -notmatch '^(n|no)$')
}

################################################################################
# FUNCTION    : Set-EnabledPlugin
# DESCRIPTION : JSON 파일의 enabledPlugins[Key]=true 설정 (PowerShell 네이티브)
# PARAMETERS  : string File - 대상 JSON
#               string Key  - plugin@marketplace
# RETURNED    : bool (성공 여부)
################################################################################
function Set-EnabledPlugin {
    param([string]$File, [string]$Key)

    if (-not (Test-Path $File)) { return $false }
    $json = Get-Content -Raw $File | ConvertFrom-Json

    if (-not $json.PSObject.Properties.Match('enabledPlugins').Count) {
        $json | Add-Member -NotePropertyName 'enabledPlugins' -NotePropertyValue ([pscustomobject]@{})
    }
    if ($json.enabledPlugins.PSObject.Properties.Match($Key).Count) {
        $json.enabledPlugins.$Key = $true
    } else {
        $json.enabledPlugins | Add-Member -NotePropertyName $Key -NotePropertyValue $true
    }
    ($json | ConvertTo-Json -Depth 20) | Set-Content -Encoding UTF8 $File
    return $true
}

################################################################################
# FUNCTION    : Sync-EnabledPlugin
# DESCRIPTION : enabledPlugins 항목을 템플릿(핵심)과 라이브 settings.json 에 반영.
#               템플릿 반영으로 arachne -i 재생성 시에도 활성화가 보존된다.
# PARAMETERS  : string Key - plugin@marketplace
################################################################################
function Sync-EnabledPlugin {
    param([string]$Key)

    if (Set-EnabledPlugin $SCRIPT:SETTINGS_TEMPLATE $Key) {
        LogInfo "settings.template.json synced enabledPlugins: $Key"
    } else {
        LogWarn "failed to update settings.template.json; preserve via 'arachne -e' after: $Key"
    }
    try { Set-EnabledPlugin $SCRIPT:SETTINGS_LIVE $Key | Out-Null } catch { }
}

################################################################################
# FUNCTION    : Setup-PluginRepo
# DESCRIPTION : 클론(없으면 git clone) → 마켓플레이스 등록 → 플러그인 설치 (멱등).
#               -Update 면 클론 pull + marketplace/plugin update.
# PARAMETERS  : string Label, Url, Clone, Market, Plugin
################################################################################
function Setup-PluginRepo {
    param([string]$Label, [string]$Url, [string]$Clone, [string]$Market, [string]$Plugin)

    if ($null -eq (Get-Command claude -ErrorAction SilentlyContinue)) {
        LogWarn "${Label}: claude CLI not found; skip plugin install"
        return
    }
    if (-not (Clone-Repo $Label $Url $Clone)) { return }
    if (-not (Test-Path (Join-Path $Clone ".claude-plugin\marketplace.json"))) {
        LogWarn "${Label}: marketplace.json missing ($Clone); skip"
        return
    }

    LogInfo "=== $Label setup ==="
    $markets = (& claude plugin marketplace list 2>$null) -join "`n"
    if ($markets -match [regex]::Escape($Market)) {
        if ($Update) {
            LogInfo "update marketplace: $Market"
            try { & claude plugin marketplace update $Market } catch { LogWarn "marketplace update failed: $Market" }
        } else {
            LogInfo "marketplace already registered: $Market"
        }
    } else {
        LogInfo "register marketplace: $Clone"
        & claude plugin marketplace add $Clone
    }

    $plugins = (& claude plugin list 2>$null) -join "`n"
    $pluginName = $Plugin.Split("@")[0]
    if ($plugins -match [regex]::Escape($pluginName)) {
        if ($Update) {
            LogInfo "update plugin: $Plugin"
            try { & claude plugin update $pluginName } catch { LogWarn "plugin update failed: $Plugin" }
        } else {
            LogInfo "plugin already installed: $Plugin"
        }
    } else {
        LogInfo "install plugin: $Plugin (scope: user)"
        & claude plugin install $Plugin --scope user
    }
    Sync-EnabledPlugin $Plugin
}

################################################################################
# FUNCTION    : Install-Codegraph
# DESCRIPTION : codegraph CLI 를 PATH 에 설치 (멱등) — 클론 installer → npm 폴백.
#               래퍼(commands/codegraph.md)는 레포에 항상 존재.
################################################################################
function Install-Codegraph {
    LogInfo "=== codegraph setup ==="
    if ($null -ne (Get-Command codegraph -ErrorAction SilentlyContinue)) {
        if ($Update -and ($null -ne (Get-Command npm -ErrorAction SilentlyContinue))) {
            LogInfo "update codegraph (npm -g @latest)"
            try { & npm install -g "@colbymchenry/codegraph@latest" } catch { LogWarn "codegraph update failed" }
        } else {
            LogInfo "codegraph already installed"
        }
        return
    }

    $cloneInstaller = Join-Path $SCRIPT:CODEGRAPH_CLONE "install.ps1"
    if (Test-Path $cloneInstaller) {
        LogInfo "install codegraph (clone install.ps1)"
        & $cloneInstaller
    } elseif ($null -ne (Get-Command npm -ErrorAction SilentlyContinue)) {
        LogInfo "install codegraph (npm -g @colbymchenry/codegraph)"
        & npm install -g "@colbymchenry/codegraph"
    } else {
        LogWarn "cannot install codegraph; neither clone ($SCRIPT:CODEGRAPH_CLONE) nor npm present"
        return
    }

    if ($null -ne (Get-Command codegraph -ErrorAction SilentlyContinue)) {
        LogInfo "codegraph OK"
    } else {
        LogWarn "codegraph not on PATH; add its bin dir to PATH"
    }
}

#-------------------------------------------------------------------------------
# 진입점
#-------------------------------------------------------------------------------
if ($Help) {
    ShowUsage
    return
}

$explicit = $All -or $Ua -or $Taste -or $Codegraph
$wantUa = $false
$wantTaste = $false
$wantCg = $false

if ($explicit) {
    $wantUa = $All -or $Ua
    $wantTaste = $All -or $Taste
    $wantCg = $All -or $Codegraph
} elseif ($Yes) {
    $wantUa = $true; $wantTaste = $true; $wantCg = $true
} elseif ([Environment]::UserInteractive) {
    Write-Output "$SCRIPT:LOG_PREFIX extras setup - choose per item."
    $hasGit = ($null -ne (Get-Command git -ErrorAction SilentlyContinue))

    if ((Test-Path $SCRIPT:UA_CLONE) -or $hasGit) {
        $wantUa = Confirm "Install Understand-Anything plugin? (auto-clone if missing -> $SCRIPT:UA_CLONE)"
    } else { LogInfo "Understand-Anything clone missing + git absent; skip ($SCRIPT:UA_CLONE)" }

    if ((Test-Path $SCRIPT:TASTE_CLONE) -or $hasGit) {
        $wantTaste = Confirm "Install taste-skill plugin? (auto-clone if missing -> $SCRIPT:TASTE_CLONE)"
    } else { LogInfo "taste-skill clone missing + git absent; skip ($SCRIPT:TASTE_CLONE)" }

    if ((Test-Path $SCRIPT:CODEGRAPH_CLONE) -or ($null -ne (Get-Command npm -ErrorAction SilentlyContinue))) {
        $wantCg = Confirm "Install codegraph CLI (+/codegraph wrapper)?"
    } else { LogInfo "codegraph clone/npm missing; skip" }
} else {
    ShowUsage
    return
}

if ($wantUa) { Setup-PluginRepo "Understand-Anything" $SCRIPT:UA_URL $SCRIPT:UA_CLONE $SCRIPT:UA_MARKET $SCRIPT:UA_PLUGIN }
if ($wantTaste) { Setup-PluginRepo "taste-skill" $SCRIPT:TASTE_URL $SCRIPT:TASTE_CLONE $SCRIPT:TASTE_MARKET $SCRIPT:TASTE_PLUGIN }
if ($wantCg) { Install-Codegraph }

LogInfo "extras setup done (plugins activate after Claude Code restart)"
