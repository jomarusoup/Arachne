################################################################################
# FILE NAME   : check_ps_syntax.ps1
# DESCRIPTION : 저장소 내 모든 .ps1 구문 파싱 검사 — Windows 러너 실행 전에
#               Linux pwsh 에서도 PowerShell 구문 오류를 조기 차단한다.
# DATA        : 2026-07-17
################################################################################

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repo_dir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$fail_count = 0

$ps_files = Get-ChildItem -Path $repo_dir -Recurse -Filter *.ps1 |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }

foreach ($ps_file in $ps_files) {
    $tokens = $null
    $parse_errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $ps_file.FullName, [ref]$tokens, [ref]$parse_errors)

    if ($parse_errors -and $parse_errors.Count -gt 0) {
        foreach ($parse_error in $parse_errors) {
            Write-Output ("  [FAIL] {0}:{1} {2}" -f `
                $ps_file.FullName, $parse_error.Extent.StartLineNumber, $parse_error.Message)
        }
        $fail_count++
    } else {
        Write-Output ("  [OK] " + $ps_file.FullName)
    }
}

if ($fail_count -gt 0) {
    Write-Output "[FAIL] PowerShell 구문 오류 — $fail_count 개 파일"
    exit 1
}
Write-Output "[PASS] PowerShell 구문 검사 통과 — $($ps_files.Count) 개 파일"
