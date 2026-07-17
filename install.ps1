################################################################################
# FILE NAME   : install.ps1
# DESCRIPTION : Windows용 Arachne 하네스 설치 및 관리 스크립트
# DATA        : 2026-06-07
# Modification: 2026-07-17
################################################################################

[CmdletBinding()]
param(
    [Alias("i")]
    [switch]$Install,

    [Alias("u")]
    [switch]$Update,

    [Alias("c")]
    [switch]$Check,

    [Alias("h")]
    [switch]$Help,

    [Alias("v")]
    [switch]$Version,

    [ValidateSet("claude", "gemini", "codex", "copilot", "all")]
    [string]$Target = "all",

    [switch]$WithUa,

    [switch]$WithExtras,

    [switch]$Extras
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$SCRIPT:REPO_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SCRIPT:ARACHNE_HOME = if ($env:ARACHNE_HOME) {
    $env:ARACHNE_HOME
} elseif ($env:USERPROFILE) {
    $env:USERPROFILE
} else {
    $HOME
}
$SCRIPT:CLAUDE_DIR = Join-Path $SCRIPT:ARACHNE_HOME ".claude"
$SCRIPT:LOCAL_BIN = Join-Path $SCRIPT:ARACHNE_HOME ".local\bin"
$SCRIPT:ARACHNE_TAG = "ARACHNE"
# 버전 정본은 레포 루트 VERSION 파일 (F-07: 설치기별 하드코딩 드리프트 방지)
$SCRIPT:VERSION_FILE = Join-Path $SCRIPT:REPO_DIR "VERSION"
$SCRIPT:ARACHNE_VERSION = if (Test-Path $SCRIPT:VERSION_FILE) {
    (Get-Content $SCRIPT:VERSION_FILE -Raw).Trim()
} else {
    "unknown"
}
$SCRIPT:UTF8_NO_BOM = New-Object System.Text.UTF8Encoding($false)

$SCRIPT:LINK_TARGETS = @(
    "CLAUDE.md",
    "statusline-command.sh",
    "commands",
    "agents",
    "rules",
    "hooks",
    "skills"
)

$SCRIPT:BASH_COMMANDS = [ordered]@{
    "tws" = "tmux.sh"
    "gtask" = "gemini-task.sh"
    "gemini-task" = "gemini-task.sh"
    "ctask" = "codex-task.sh"
    "codex-task" = "codex-task.sh"
    "atask" = "arachne-task.sh"
    "arachne-task" = "arachne-task.sh"
    "docs-sync" = "docs-sync.sh"
}

################################################################################
# FUNCTION    : WriteArachneLog
# DESCRIPTION : Arachne PowerShell 스크립트의 사용자 출력 형식을 통일
# PARAMETERS  : string Level   - STEP|RUN|SKIP|DONE|WARN|ERROR
#               string Message - 출력할 메시지
################################################################################
function WriteArachneLog {
    param(
        [string]$Level,
        [string]$Message
    )

    $line = "[Arachne][$Level] $Message"
    switch ($Level) {
        "WARN" { Write-Warning $line }
        "ERROR" { Write-Error $line }
        default { Write-Output $line }
    }
}

################################################################################
# FUNCTION    : WriteUtf8
# DESCRIPTION : UTF-8 BOM 없이 텍스트 파일 저장
# PARAMETERS  : string path    - 출력 파일 경로
#               string content - 저장할 본문
################################################################################
function WriteUtf8 {
    param(
        [string]$Path,
        [string]$Content
    )

    [System.IO.File]::WriteAllText($Path, $Content, $SCRIPT:UTF8_NO_BOM)
}

################################################################################
# FUNCTION    : ShowUsage
# DESCRIPTION : Windows용 CLI 사용법과 의존성 출력
################################################################################
function ShowUsage {
    Write-Output "Usage: arachne [OPTION]"
    Write-Output ""
    Write-Output "Arachne - Windows harness manager"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  -i, -Install          install or reinstall + auto install/update extras"
    Write-Output "  -u, -Update           git pull, then reinstall"
    Write-Output "  -Target T             claude|gemini|codex|copilot|all (default: all)"
    Write-Output "  -WithUa               with -Install/-Update: limit extras to Understand-Anything only"
    Write-Output "  -WithExtras           (compat) same as default: extras auto install+update"
    Write-Output "  -Extras               run extras setup only (interactive menu)"
    Write-Output "  -c, -Check            verify Claude, Gemini, Codex, and Copilot wiring"
    Write-Output "  -h, -Help             show help"
    Write-Output "  -v, -Version          show version"
    Write-Output ""
    Write-Output "Git for Windows bash.exe is required for hooks and delegated commands."
    Write-Output "Tmux (tws) is only available inside WSL or another tmux environment."
}

################################################################################
# FUNCTION    : BackupPath
# DESCRIPTION : 기존 대상이 있으면 .bak으로 이동
# PARAMETERS  : string path - 백업할 파일 또는 디렉터리
################################################################################
function BackupPath {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $backup_path = "${Path}.bak"
    if (Test-Path -LiteralPath $backup_path) {
        Remove-Item -LiteralPath $backup_path -Recurse -Force
    }
    Move-Item -LiteralPath $Path -Destination $backup_path
    Write-Output "  backup: $Path -> $backup_path"
}

################################################################################
# FUNCTION    : LinkPath
# DESCRIPTION : 디렉터리는 junction, 파일은 hard link로 연결하고 불가 시 복사
# PARAMETERS  : string source      - 레포 원본 경로
#               string destination - 사용자 홈 대상 경로
################################################################################
function LinkPath {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        $item = Get-Item -LiteralPath $Destination -Force
        if ($item.LinkType -in @("Junction", "SymbolicLink", "HardLink")) {
            Remove-Item -LiteralPath $Destination -Recurse -Force
        } else {
            BackupPath $Destination
        }
    }

    $source_item = Get-Item -LiteralPath $Source
    try {
        if ($source_item.PSIsContainer) {
            New-Item -ItemType Junction -Path $Destination -Target $Source | Out-Null
            Write-Output "  junction: $Destination -> $Source"
        } else {
            New-Item -ItemType HardLink -Path $Destination -Target $Source | Out-Null
            Write-Output "  hardlink: $Destination -> $Source"
        }
    } catch {
        if (Test-Path -LiteralPath $Destination) {
            Remove-Item -LiteralPath $Destination -Recurse -Force
        }
        if ($source_item.PSIsContainer) {
            Copy-Item -LiteralPath $Source -Destination $Destination -Recurse
        } else {
            Copy-Item -LiteralPath $Source -Destination $Destination
        }
        Write-Warning "[Arachne] link unavailable; copied instead: $Destination"
    }
}

################################################################################
# FUNCTION    : ConvertHomePath
# DESCRIPTION : settings.json용 홈 경로를 슬래시 형식으로 변환
# RETURNED    : JSON과 Git Bash에서 사용할 홈 경로
################################################################################
function ConvertHomePath {
    return $SCRIPT:ARACHNE_HOME.Replace("\", "/")
}

################################################################################
# FUNCTION    : InstallClaude
# DESCRIPTION : Claude Code 자산 연결 및 Windows 호환 settings.json 생성
################################################################################
function InstallClaude {
    Write-Output "[Arachne] Claude install: $SCRIPT:CLAUDE_DIR"
    New-Item -ItemType Directory -Path $SCRIPT:CLAUDE_DIR -Force | Out-Null

    foreach ($target_name in $SCRIPT:LINK_TARGETS) {
        $source_path = Join-Path $SCRIPT:REPO_DIR $target_name
        $target_path = Join-Path $SCRIPT:CLAUDE_DIR $target_name
        LinkPath $source_path $target_path
    }

    $settings_path = Join-Path $SCRIPT:CLAUDE_DIR "settings.json"
    if (Test-Path -LiteralPath $settings_path) {
        Copy-Item -LiteralPath $settings_path -Destination "${settings_path}.bak" -Force
    }
    $template_path = Join-Path $SCRIPT:REPO_DIR "settings.template.json"
    $settings_text = [System.IO.File]::ReadAllText($template_path)
    $settings_text = $settings_text.Replace("__HOME__", (ConvertHomePath))
    WriteUtf8 $settings_path $settings_text
    Write-Output "  create: $settings_path"
}

################################################################################
# FUNCTION    : InstallGemini
# DESCRIPTION : AGENTS.md를 Gemini 전역 지시 파일로 연결
################################################################################
function InstallGemini {
    $gemini_dir = Join-Path $SCRIPT:ARACHNE_HOME ".gemini"
    New-Item -ItemType Directory -Path $gemini_dir -Force | Out-Null
    LinkPath (Join-Path $SCRIPT:REPO_DIR "AGENTS.md") (Join-Path $gemini_dir "GEMINI.md")
}

################################################################################
# FUNCTION    : MergeMarkedFile
# DESCRIPTION : 마커 외부 사용자 내용을 보존하며 소스 본문 병합
# PARAMETERS  : string source      - 삽입할 SSOT 파일
#               string destination - 병합 대상 파일
################################################################################
function MergeMarkedFile {
    param(
        [string]$Source,
        [string]$Destination
    )

    $begin_marker = "<!-- === $SCRIPT:ARACHNE_TAG BEGIN === -->"
    $end_marker = "<!-- === $SCRIPT:ARACHNE_TAG END === -->"
    $user_text = ""

    if (Test-Path -LiteralPath $Destination) {
        $current_text = [System.IO.File]::ReadAllText($Destination)
        $pattern = "(?s)\r?\n?$([regex]::Escape($begin_marker)).*?$([regex]::Escape($end_marker))\r?\n?"
        $user_text = [regex]::Replace($current_text, $pattern, "").TrimEnd()
    }

    $source_text = [System.IO.File]::ReadAllText($Source).TrimEnd()
    $sections = @()
    if ($user_text) {
        $sections += $user_text
    }
    $sections += "$begin_marker`n$source_text`n$end_marker"
    WriteUtf8 $Destination (($sections -join "`n`n") + "`n")
    Write-Output "  merge: $Destination"
}

################################################################################
# FUNCTION    : InstallCodex
# DESCRIPTION : AGENTS.md를 Codex 전역 지시 파일에 마커 병합
################################################################################
function InstallCodex {
    $codex_dir = Join-Path $SCRIPT:ARACHNE_HOME ".codex"
    New-Item -ItemType Directory -Path $codex_dir -Force | Out-Null
    MergeMarkedFile `
        (Join-Path $SCRIPT:REPO_DIR "AGENTS.md") `
        (Join-Path $codex_dir "AGENTS.md")
}

################################################################################
# FUNCTION    : InstallCopilot
# DESCRIPTION : Copilot CLI와 VS Code 사용자 프로필에 AGENTS.md 규약 설치
################################################################################
function InstallCopilot {
    $copilot_dir = Join-Path $SCRIPT:ARACHNE_HOME ".copilot"
    $instructions_dir = Join-Path $copilot_dir "instructions"
    $cli_file = Join-Path $copilot_dir "copilot-instructions.md"
    $vscode_file = Join-Path $instructions_dir "arachne.instructions.md"
    $agents_file = Join-Path $SCRIPT:REPO_DIR "AGENTS.md"

    New-Item -ItemType Directory -Path $instructions_dir -Force | Out-Null
    MergeMarkedFile $agents_file $cli_file

    $agents_text = [System.IO.File]::ReadAllText($agents_file).TrimEnd()
    $vscode_text = @"
---
name: Arachne Shared Rules
description: Arachne AGENTS.md shared coding rules
applyTo: "**"
---

<!-- === $SCRIPT:ARACHNE_TAG BEGIN === -->
$agents_text
<!-- === $SCRIPT:ARACHNE_TAG END === -->
"@
    WriteUtf8 $vscode_file ($vscode_text + "`n")
    Write-Output "  merge: $cli_file"
    Write-Output "  create: $vscode_file"
}

################################################################################
# FUNCTION    : DetectCli
# DESCRIPTION : CLI 홈 디렉터리 또는 실행 파일 존재 여부 검사
# PARAMETERS  : string name - gemini, codex 또는 copilot
# RETURNED    : bool 감지 여부
################################################################################
function DetectCli {
    param([string]$Name)

    $config_path = Join-Path $SCRIPT:ARACHNE_HOME ".$Name"
    return (Test-Path -LiteralPath $config_path) -or
        ($null -ne (Get-Command $Name -ErrorAction SilentlyContinue))
}

################################################################################
# FUNCTION    : NewCommandWrapper
# DESCRIPTION : PowerShell 또는 Bash 스크립트를 호출하는 .cmd 생성
# PARAMETERS  : string command_name - 등록할 명령 이름
#               string script_name  - 레포 내 스크립트 이름
#               bool use_bash       - bash.exe 호출 여부
################################################################################
function NewCommandWrapper {
    param(
        [string]$CommandName,
        [string]$ScriptName,
        [bool]$UseBash
    )

    $script_path = Join-Path $SCRIPT:REPO_DIR $ScriptName
    $wrapper_path = Join-Path $SCRIPT:LOCAL_BIN "${CommandName}.cmd"
    if ($UseBash) {
        $bash_script_path = $script_path.Replace("\", "/")
        $wrapper_text = "@echo off`r`nbash `"$bash_script_path`" %*`r`n"
    } else {
        $wrapper_text = @"
@echo off
if "%~1"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "$script_path" -Help
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "$script_path" %*
)
"@
    }
    WriteUtf8 $wrapper_path $wrapper_text
    Write-Output "  register: ${CommandName}.cmd"
}

################################################################################
# FUNCTION    : RegisterCommands
# DESCRIPTION : Windows 사용자 bin에 arachne 및 Bash 래퍼 등록
################################################################################
function RegisterCommands {
    New-Item -ItemType Directory -Path $SCRIPT:LOCAL_BIN -Force | Out-Null
    NewCommandWrapper "arachne" "install.ps1" $false

    foreach ($command_name in $SCRIPT:BASH_COMMANDS.Keys) {
        NewCommandWrapper $command_name $SCRIPT:BASH_COMMANDS[$command_name] $true
    }

    $skip_path = [Environment]::GetEnvironmentVariable("ARACHNE_SKIP_PATH")
    if ($skip_path -ne "1") {
        $user_path = [Environment]::GetEnvironmentVariable("Path", "User")
        $path_parts = @($user_path -split ";" | Where-Object { $_ })
        if ($SCRIPT:LOCAL_BIN -notin $path_parts) {
            $new_path = (@($path_parts) + $SCRIPT:LOCAL_BIN) -join ";"
            [Environment]::SetEnvironmentVariable("Path", $new_path, "User")
            Write-Output "  user PATH added: $SCRIPT:LOCAL_BIN"
            Write-Output "  reopen the terminal to use arachne."
        }
    }
}

################################################################################
# FUNCTION    : InvokePreflightCheck
# DESCRIPTION : 설치 전 권장 의존성 존재 점검 — 누락 도구와 영향을 경고로만
#               출력하고 설치는 차단하지 않는다
################################################################################
function InvokePreflightCheck {
    $tools = @(
        @{ Cmd = "git";    Impact = "extras clone and -Update unavailable" },
        @{ Cmd = "bash";   Impact = "hooks and delegated commands unavailable (install Git for Windows)" },
        @{ Cmd = "gh";     Impact = "feedback submit / issue / PR flows unavailable" },
        @{ Cmd = "npm";    Impact = "codegraph install and update unavailable" },
        @{ Cmd = "claude"; Impact = "UA / taste-skill plugin install unavailable" }
    )
    $missing_count = 0

    WriteArachneLog "STEP" "preflight: dependency check (warn only; install continues)"
    foreach ($tool in $tools) {
        if (Get-Command $tool.Cmd -ErrorAction SilentlyContinue) { continue }
        WriteArachneLog "WARN" ("preflight: {0} not found; {1}" -f $tool.Cmd, $tool.Impact)
        $missing_count++
    }

    if ($missing_count -eq 0) {
        WriteArachneLog "OK" "preflight: all recommended tools detected"
    } else {
        WriteArachneLog "WARN" "preflight: $missing_count missing; only those features are limited"
    }
}

################################################################################
# FUNCTION    : InstallHarness
# DESCRIPTION : 선택 타깃 설치 후 Windows 공통 명령 등록
################################################################################
function InstallHarness {
    WriteArachneLog "STEP" "install: target=$Target repo=$SCRIPT:REPO_DIR"
    InvokePreflightCheck
    switch ($Target) {
        "claude" { InstallClaude }
        "gemini" { InstallGemini }
        "codex" { InstallCodex }
        "copilot" { InstallCopilot }
        "all" {
            InstallClaude
            if (DetectCli "gemini") {
                InstallGemini
            } else {
                WriteArachneLog "SKIP" "install: Gemini CLI not detected; target=gemini"
            }
            if (DetectCli "codex") {
                InstallCodex
            } else {
                WriteArachneLog "SKIP" "install: Codex CLI not detected; target=codex"
            }
            if (DetectCli "copilot") {
                InstallCopilot
            } else {
                WriteArachneLog "SKIP" "install: Copilot not detected; target=copilot"
            }
        }
    }

    RegisterCommands
    WriteArachneLog "DONE" "install: target=$Target"
}

################################################################################
# FUNCTION    : RunExtras
# DESCRIPTION : 확장 도구 통합 설치 스크립트(setup-extras.ps1) 실행
#               UA·taste-skill 로컬 마켓플레이스 + codegraph CLI(+래퍼)
################################################################################
function RunExtras {
    param([string[]]$ExtraArgs = @())

    $extras = if ($env:ARACHNE_EXTRAS_SCRIPT) {
        $env:ARACHNE_EXTRAS_SCRIPT
    } else {
        Join-Path $SCRIPT:REPO_DIR "setup-extras.ps1"
    }
    if (-not (Test-Path $extras)) {
        WriteArachneLog "SKIP" "extras: setup script not found; path=$extras"
        return
    }
    WriteArachneLog "RUN" "extras: powershell $extras $($ExtraArgs -join ' ')"
    & $extras @ExtraArgs
}

################################################################################
# FUNCTION    : MaybeRunExtras
# DESCRIPTION : -Install/-Update 후 확장 도구 동기화. Claude 타깃에서만 동작.
#               -WithUa 지정 시 Understand-Anything 만 실행하고, 그 외에는 항상
#               전체 확장 도구를 설치·갱신한다(-All -Update 멱등 — 미설치는
#               설치, 기설치는 git pull/plugin update 로 최신화).
# PARAMETERS  : string[] PassArgs - setup-extras.ps1 로 전달 (예: -Update)
################################################################################
function MaybeRunExtras {
    param([string[]]$PassArgs = @())

    if ($Target -ne "all" -and $Target -ne "claude") {
        WriteArachneLog "SKIP" "extras: target=$Target; not a Claude plugin target"
        return
    }

    if ($WithUa) {
        WriteArachneLog "STEP" "extras: Understand-Anything only setup start"
        RunExtras (@("-Ua") + $PassArgs)
        WriteArachneLog "DONE" "extras: Understand-Anything only setup complete"
        return
    }

    #---------------------------------------------------------------------------
    # 기본 동작: 전체 확장 도구를 항상 설치하고 기설치면 최신으로 갱신한다.
    # PowerShell 은 동일 스위치 중복 지정이 바인딩 에러라 PassArgs 에서 제외한다.
    #---------------------------------------------------------------------------
    $forward_args = @($PassArgs | Where-Object { $_ -notin @("-All", "-Update") })
    WriteArachneLog "STEP" "extras: all extras install+update start"
    RunExtras (@("-All", "-Update") + $forward_args)
    WriteArachneLog "DONE" "extras: all extras install+update complete"
}

################################################################################
# FUNCTION    : TestLinkedPath
# DESCRIPTION : 링크 대상 또는 복사 폴백 대상이 존재하는지 검사
# PARAMETERS  : string path - 검사 대상
# RETURNED    : bool 정상 여부
################################################################################
function TestLinkedPath {
    param([string]$Path)

    return Test-Path -LiteralPath $Path
}

################################################################################
# FUNCTION    : CheckHarness
# DESCRIPTION : Windows의 Claude, Gemini, Codex 설치 상태 검사
# RETURNED    : 실패 시 프로세스 종료 코드 1
################################################################################
function CheckHarness {
    $failed = $false
    $claude_file = Join-Path $SCRIPT:CLAUDE_DIR "CLAUDE.md"
    if (TestLinkedPath $claude_file) {
        Write-Output "  [OK] Claude"
    } else {
        Write-Output "  [FAIL] Claude: run arachne -i"
        $failed = $true
    }

    foreach ($cli_name in @("gemini", "codex")) {
        if (-not (DetectCli $cli_name)) {
            Write-Output "  [SKIP] $cli_name"
            continue
        }
        $file_name = if ($cli_name -eq "gemini") { "GEMINI.md" } else { "AGENTS.md" }
        $config_file = Join-Path $SCRIPT:ARACHNE_HOME ".$cli_name\$file_name"
        if (-not (TestLinkedPath $config_file)) {
            Write-Output "  [FAIL] ${cli_name}: run arachne -i -Target $cli_name"
            $failed = $true
            continue
        }

        $config_text = [System.IO.File]::ReadAllText($config_file)
        $source_text = [System.IO.File]::ReadAllText(
            (Join-Path $SCRIPT:REPO_DIR "AGENTS.md")
        ).TrimEnd()
        if ($config_text.Contains($source_text)) {
            Write-Output "  [OK] $cli_name"
        } else {
            Write-Output "  [FAIL] ${cli_name}: stale AGENTS.md"
            $failed = $true
        }
    }

    if (DetectCli "copilot") {
        $copilot_cli_file = Join-Path $SCRIPT:ARACHNE_HOME ".copilot\copilot-instructions.md"
        $copilot_vscode_file = Join-Path $SCRIPT:ARACHNE_HOME ".copilot\instructions\arachne.instructions.md"
        $begin_marker = "<!-- === $SCRIPT:ARACHNE_TAG BEGIN === -->"
        $end_marker = "<!-- === $SCRIPT:ARACHNE_TAG END === -->"
        $source_text = [System.IO.File]::ReadAllText(
            (Join-Path $SCRIPT:REPO_DIR "AGENTS.md")
        ).TrimEnd()
        $copilot_ok = $true

        foreach ($copilot_file in @($copilot_cli_file, $copilot_vscode_file)) {
            if (-not (Test-Path -LiteralPath $copilot_file)) {
                $copilot_ok = $false
                continue
            }
            $config_text = [System.IO.File]::ReadAllText($copilot_file)
            $escaped_begin = [regex]::Escape($begin_marker)
            $escaped_end = [regex]::Escape($end_marker)
            $match = [regex]::Match($config_text, "(?s)$escaped_begin\r?\n(.*?)\r?\n$escaped_end")
            if (-not $match.Success -or $match.Groups[1].Value.TrimEnd() -ne $source_text) {
                $copilot_ok = $false
            }
        }

        if ($copilot_ok) {
            Write-Output "  [OK] Copilot"
        } else {
            Write-Output "  [FAIL] Copilot: run arachne -i -Target copilot"
            $failed = $true
        }
    } else {
        Write-Output "  [SKIP] copilot"
    }

    if ($failed) {
        exit 1
    }
    Write-Output "[Arachne] all detected harnesses are connected"
}

#-------------------------------------------------------------------------------
# 진입점
#-------------------------------------------------------------------------------
if ($Version) {
    $revision = (& git -C $SCRIPT:REPO_DIR rev-parse --short HEAD 2>$null)
    if (-not $revision) {
        $revision = "unknown"
    }
    Write-Output "arachne $SCRIPT:ARACHNE_VERSION ($revision)"
} elseif ($Help) {
    ShowUsage
} elseif ($Check) {
    CheckHarness
} elseif ($Update) {
    & git -C $SCRIPT:REPO_DIR pull
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
    InstallHarness
    # -u 도 -i 와 동일하게 확장 도구 분기 (-WithExtras 면 멱등 설정).
    # update 모드 — 선택된 확장 도구 클론·플러그인·CLI 를 최신으로 갱신.
    MaybeRunExtras @("-Update")
} elseif ($Extras) {
    RunExtras
} elseif ($Install -or $MyInvocation.InvocationName -ne "&") {
    InstallHarness
    MaybeRunExtras
} else {
    ShowUsage
}
