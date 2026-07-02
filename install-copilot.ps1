################################################################################
# FILE NAME   : install-copilot.ps1
# DESCRIPTION : Windows PowerShell용 GitHub Copilot 전역 지침 설치기
# DATA        : 2026-06-07
# Modification: 2026-06-07
################################################################################

[CmdletBinding()]
param(
    [string]$RepoDir = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
$ArachneTag = "ARACHNE"
$HomeDir = if ($env:ARACHNE_HOME) { $env:ARACHNE_HOME } else { $HOME }
$AgentsFile = Join-Path $RepoDir "AGENTS.md"
$CopilotDir = Join-Path $HomeDir ".copilot"
$InstructionsDir = Join-Path $CopilotDir "instructions"
$CliFile = Join-Path $CopilotDir "copilot-instructions.md"
$VsCodeFile = Join-Path $InstructionsDir "arachne.instructions.md"

################################################################################
# FUNCTION    : Write-Utf8File
# DESCRIPTION : Windows PowerShell 5.1과 PowerShell 7에서 BOM 없는 UTF-8 기록
# PARAMETERS  : string Path    - 대상 파일
#               string Content - 기록할 본문
################################################################################
function Write-Utf8File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

################################################################################
# FUNCTION    : Merge-MarkedFile
# DESCRIPTION : 기존 사용자 영역을 보존하고 ARACHNE 마커 구간만 최신 본문으로 교체
# PARAMETERS  : string Path    - 대상 Markdown 파일
#               string Content - 마커 안에 기록할 본문
################################################################################
function Merge-MarkedFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $begin = "<!-- === $ArachneTag BEGIN === -->"
    $end = "<!-- === $ArachneTag END === -->"
    $userContent = ""

    if (Test-Path -LiteralPath $Path) {
        $current = Get-Content -LiteralPath $Path -Raw
        $escapedBegin = [regex]::Escape($begin)
        $escapedEnd = [regex]::Escape($end)
        $pattern = "(?ms)^$escapedBegin\r?\n.*?^$escapedEnd\r?\n?"
        $userContent = [regex]::Replace($current, $pattern, "").TrimEnd()
    }

    $sections = @()
    if ($userContent) {
        $sections += $userContent
    }
    $sections += "$begin`n$($Content.TrimEnd())`n$end"
    Write-Utf8File -Path $Path -Content (($sections -join "`n`n") + "`n")
}

################################################################################
# FUNCTION    : Install-CopilotRules
# DESCRIPTION : Copilot CLI와 VS Code 사용자 프로필에 AGENTS.md 규약 설치
################################################################################
function Install-CopilotRules {
    if (-not (Test-Path -LiteralPath $AgentsFile)) {
        throw "AGENTS.md를 찾을 수 없습니다: $AgentsFile"
    }

    New-Item -ItemType Directory -Force -Path $InstructionsDir | Out-Null
    $agentsContent = Get-Content -LiteralPath $AgentsFile -Raw

    Merge-MarkedFile -Path $CliFile -Content $agentsContent

    $vscodeContent = @"
---
name: Arachne Shared Rules
description: Arachne AGENTS.md shared coding rules
applyTo: "**"
---

<!-- === $ArachneTag BEGIN === -->
$($agentsContent.TrimEnd())
<!-- === $ArachneTag END === -->
"@
    Write-Utf8File -Path $VsCodeFile -Content ($vscodeContent + "`n")

    Write-Host "[Arachne] GitHub Copilot 설치 완료"
    Write-Host "  CLI     : $CliFile"
    Write-Host "  VS Code : $VsCodeFile"
}

Install-CopilotRules
