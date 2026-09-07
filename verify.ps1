<#
    verify.ps1 - run the full Flutter verification loop and capture everything.

    Usage (from the Whistfull folder):
        powershell -ExecutionPolicy Bypass -File .\verify.ps1

    It runs pub get -> build_runner -> analyze -> test, never stopping early,
    and writes the complete output to verify_output.txt. Send that file back
    to Claude and it can fix the errors directly.

    Nothing here modifies your source. It only builds, generates Hive adapters,
    and reports.
#>

$log = Join-Path $PSScriptRoot 'verify_output.txt'
Set-Location -Path $PSScriptRoot

function Section {
    param([string]$Name)
    $bar = '=' * 70
    Add-Content $log ''
    Add-Content $log $bar
    Add-Content $log "== $Name"
    Add-Content $log $bar
    Write-Host ''
    Write-Host "== $Name" -ForegroundColor Cyan
}

function RunStep {
    param([string]$Name, [string]$Exe, [string[]]$Args)
    Section $Name
    try {
        # Merge stderr into stdout so nothing is lost.
        $out = & $Exe @Args 2>&1 | Out-String
        Add-Content $log $out
        Write-Host $out
        Add-Content $log "[exit code: $LASTEXITCODE]"
        return $LASTEXITCODE
    } catch {
        $msg = "FAILED TO RUN: $($_.Exception.Message)"
        Add-Content $log $msg
        Write-Host $msg -ForegroundColor Red
        return 1
    }
}

# --- start fresh -------------------------------------------------------------
"Whistly verification run - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Set-Content $log
Add-Content $log "Folder: $PSScriptRoot"

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $m = 'flutter is not installed or not on PATH. Nothing else can run.'
    Add-Content $log $m
    Write-Host $m -ForegroundColor Red
    Write-Host "Log written to: $log"
    exit 1
}

Section 'flutter --version'
$v = & flutter --version 2>&1 | Out-String
Add-Content $log $v
Write-Host $v

# --- the loop ----------------------------------------------------------------
$pubCode      = RunStep 'flutter pub get'            'flutter' @('pub','get')
$genCode      = RunStep 'build_runner (Hive adapters)' 'dart'   @('run','build_runner','build','--delete-conflicting-outputs')
$analyzeCode  = RunStep 'flutter analyze'            'flutter' @('analyze')
$testCode     = RunStep 'flutter test'               'flutter' @('test')

# --- summary -----------------------------------------------------------------
Section 'SUMMARY'
$summary = @(
    "pub get      exit $pubCode",
    "build_runner exit $genCode",
    "analyze      exit $analyzeCode",
    "test         exit $testCode"
) -join [Environment]::NewLine
Add-Content $log $summary
Write-Host ''
Write-Host $summary -ForegroundColor Yellow

Write-Host ''
if ($analyzeCode -eq 0 -and $testCode -eq 0) {
    Write-Host 'Clean. Analyze and tests both pass.' -ForegroundColor Green
} else {
    Write-Host 'There are errors - that is expected on the first run.' -ForegroundColor Yellow
    Write-Host 'Send verify_output.txt back to Claude and it will fix them.'
}
Write-Host ''
Write-Host "Full log: $log" -ForegroundColor Cyan
