################################################################################
# FILE NAME   : install_windows.ps1
# DESCRIPTION : Windows PowerShell 설치기의 링크, 설정, 병합 동작 검증
# DATA        : 2026-06-07
# Modification: 2026-06-07
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
# PARAMETERS  : string[] arguments - 설치기 인자
################################################################################
function RunInstaller {
    param([string[]]$Arguments)

    $env:ARACHNE_HOME = $SCRIPT:TEST_HOME
    $env:ARACHNE_SKIP_PATH = "1"
    & $SCRIPT:INSTALLER @Arguments
}

try {
    New-Item -ItemType Directory -Path $SCRIPT:TEST_HOME -Force | Out-Null

    #---------------------------------------------------------------------------
    # Claude 설치 및 Windows 경로 치환
    #---------------------------------------------------------------------------
    RunInstaller @("-Install", "-Target", "claude")
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
    RunInstaller @("-Install", "-Target", "gemini")
    AssertTrue (Test-Path (Join-Path $SCRIPT:TEST_HOME ".gemini\GEMINI.md")) "Gemini file"

    $codex_dir = Join-Path $SCRIPT:TEST_HOME ".codex"
    New-Item -ItemType Directory -Path $codex_dir -Force | Out-Null
    $codex_path = Join-Path $codex_dir "AGENTS.md"
    [System.IO.File]::WriteAllText($codex_path, "USER-CONTENT`n")
    RunInstaller @("-Install", "-Target", "codex")
    RunInstaller @("-Install", "-Target", "codex")
    $codex_text = [System.IO.File]::ReadAllText($codex_path)
    AssertTrue ($codex_text.Contains("USER-CONTENT")) "Codex user content preserved"
    $marker_count = ([regex]::Matches($codex_text, "<!-- === ARACHNE BEGIN === -->")).Count
    AssertTrue ($marker_count -eq 1) "Codex marker is idempotent"

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
