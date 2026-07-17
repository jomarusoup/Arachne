################################################################################
# FILE NAME   : install_windows.ps1
# DESCRIPTION : Windows PowerShell 설치기의 링크, 설정, 병합 동작 검증
# DATA        : 2026-06-07
# Modification: 2026-07-17
################################################################################

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SCRIPT:REPO_DIR = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SCRIPT:INSTALLER = Join-Path $SCRIPT:REPO_DIR "install.ps1"
$SCRIPT:TEST_HOME = Join-Path ([System.IO.Path]::GetTempPath()) "arachne-win-$([guid]::NewGuid())"

################################################################################
# FUNCTION    : AssertTrue
# DESCRIPTION : 조건이 거짓이면 테스트 실패 예외 발생
# PARAMETERS  : bool condition - 검증 조건
#               string message - 실패 메시지
################################################################################
function AssertTrue {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "ASSERT FAILED: $Message"
    }
}

################################################################################
# FUNCTION    : RunInstaller
# DESCRIPTION : 격리 홈을 사용해 Windows 설치기 실행
# PARAMETERS  : string target - 설치 대상
################################################################################
function RunInstaller {
    param([string]$Target)

    $env:ARACHNE_HOME = $SCRIPT:TEST_HOME
    $env:ARACHNE_SKIP_PATH = "1"
    # -Install 이 확장 도구를 항상 설치·갱신하므로 존재하지 않는 스텁 경로로 격리(SKIP)
    $env:ARACHNE_EXTRAS_SCRIPT = Join-Path $SCRIPT:TEST_HOME "no-extras-stub.ps1"
    & $SCRIPT:INSTALLER -Install -Target $Target
}

try {
    New-Item -ItemType Directory -Path $SCRIPT:TEST_HOME -Force | Out-Null

    #---------------------------------------------------------------------------
    # Claude 설치 및 Windows 경로 치환
    #---------------------------------------------------------------------------
    RunInstaller -Target "claude"
    AssertTrue (Test-Path (Join-Path $SCRIPT:TEST_HOME ".claude\CLAUDE.md")) "Claude file"
    AssertTrue (Test-Path (Join-Path $SCRIPT:TEST_HOME ".claude\commands")) "commands directory"

    $settings_path = Join-Path $SCRIPT:TEST_HOME ".claude\settings.json"
    $settings_text = [System.IO.File]::ReadAllText($settings_path)
    AssertTrue (-not $settings_text.Contains("__HOME__")) "settings placeholder removed"
    AssertTrue ($settings_text.Contains($SCRIPT:TEST_HOME.Replace("\", "/"))) "forward slash home path"
    $null = $settings_text | ConvertFrom-Json

    #---------------------------------------------------------------------------
    # Gemini 연결과 Codex 마커 병합 멱등성
    #---------------------------------------------------------------------------
    RunInstaller -Target "gemini"
    AssertTrue (Test-Path (Join-Path $SCRIPT:TEST_HOME ".gemini\GEMINI.md")) "Gemini file"

    $codex_dir = Join-Path $SCRIPT:TEST_HOME ".codex"
    New-Item -ItemType Directory -Path $codex_dir -Force | Out-Null
    $codex_path = Join-Path $codex_dir "AGENTS.md"
    [System.IO.File]::WriteAllText($codex_path, "USER-CONTENT`n")
    RunInstaller -Target "codex"
    RunInstaller -Target "codex"
    $codex_text = [System.IO.File]::ReadAllText($codex_path)
    AssertTrue ($codex_text.Contains("USER-CONTENT")) "Codex user content preserved"
    $marker_count = ([regex]::Matches($codex_text, "<!-- === ARACHNE BEGIN === -->")).Count
    AssertTrue ($marker_count -eq 1) "Codex marker is idempotent"

    #---------------------------------------------------------------------------
    # Copilot 통합 설치와 마커 병합 멱등성
    #---------------------------------------------------------------------------
    $copilot_dir = Join-Path $SCRIPT:TEST_HOME ".copilot"
    $copilot_cli_path = Join-Path $copilot_dir "copilot-instructions.md"
    $copilot_vscode_path = Join-Path $copilot_dir "instructions\arachne.instructions.md"
    New-Item -ItemType Directory -Path $copilot_dir -Force | Out-Null
    [System.IO.File]::WriteAllText($copilot_cli_path, "USER-COPILOT`n")
    RunInstaller -Target "copilot"
    RunInstaller -Target "copilot"
    AssertTrue (Test-Path $copilot_cli_path) "Copilot CLI file"
    AssertTrue (Test-Path $copilot_vscode_path) "Copilot VS Code file"
    $copilot_cli_text = [System.IO.File]::ReadAllText($copilot_cli_path)
    $copilot_vscode_text = [System.IO.File]::ReadAllText($copilot_vscode_path)
    AssertTrue ($copilot_cli_text.Contains("USER-COPILOT")) "Copilot user content preserved"
    $copilot_marker_count = ([regex]::Matches($copilot_cli_text, "<!-- === ARACHNE BEGIN === -->")).Count
    AssertTrue ($copilot_marker_count -eq 1) "Copilot marker is idempotent"
    AssertTrue ($copilot_vscode_text.Contains('applyTo: "**"')) "Copilot VS Code applyTo"

    RunInstaller -Target "all"
    AssertTrue (Test-Path $copilot_vscode_path) "all target installs detected Copilot"
    & $SCRIPT:INSTALLER -Check

    Remove-Item -LiteralPath $copilot_dir -Recurse -Force
    $env:ARACHNE_HOME = $SCRIPT:TEST_HOME
    & (Join-Path $SCRIPT:REPO_DIR "install-copilot.ps1") -RepoDir $SCRIPT:REPO_DIR
    AssertTrue (Test-Path $copilot_cli_path) "standalone Copilot installer CLI file"
    AssertTrue (Test-Path $copilot_vscode_path) "standalone Copilot installer VS Code file"

    #---------------------------------------------------------------------------
    # Windows 명령 래퍼 등록
    #---------------------------------------------------------------------------
    AssertTrue (Test-Path (Join-Path $SCRIPT:TEST_HOME ".local\bin\arachne.cmd")) "arachne wrapper"
    $atask_path = Join-Path $SCRIPT:TEST_HOME ".local\bin\atask.cmd"
    AssertTrue (Test-Path $atask_path) "atask wrapper"
    $atask_text = [System.IO.File]::ReadAllText($atask_path)
    AssertTrue ($atask_text.Contains("/arachne-task.sh")) "Bash wrapper uses slash path"

    Write-Output "[PASS] Windows installer tests"
} finally {
    Remove-Item Env:ARACHNE_HOME -ErrorAction SilentlyContinue
    Remove-Item Env:ARACHNE_SKIP_PATH -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $SCRIPT:TEST_HOME -Recurse -Force -ErrorAction SilentlyContinue
}
