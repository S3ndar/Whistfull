<#
    setup_git.ps1 - one-time version control setup for the Whistly project.

    Run it once, from anywhere:
        powershell -ExecutionPolicy Bypass -File .\setup_git.ps1

    What it does:
      1. Initialises a git repository in this folder (safe if one already exists)
      2. Tops up .gitignore with the Flutter/Android entries that were missing
      3. Makes a baseline commit of the current, pre-modification code
      4. If the GitHub CLI is installed, offers to create a PRIVATE repo and push

    Nothing here is destructive: it never deletes files and never rewrites history.
#>

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

Write-Host ''
Write-Host '=== Whistly - git setup ===' -ForegroundColor Cyan
Write-Host "Folder: $PSScriptRoot"
Write-Host ''

# --- 1. git present? ---------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'git is not installed or not on PATH.' -ForegroundColor Red
    Write-Host 'Install it from https://git-scm.com/download/win then re-run this script.'
    exit 1
}

# --- 2. init -----------------------------------------------------------------
if (Test-Path '.git') {
    Write-Host 'A git repository already exists here - skipping init.' -ForegroundColor Yellow
} else {
    git init -b main | Out-Null
    Write-Host 'Initialised a new git repository (branch: main).' -ForegroundColor Green
}

# Keep Windows checkouts byte-identical to what is committed.
git config core.autocrlf false

# --- 3. top up .gitignore ----------------------------------------------------
$needed = @(
    '',
    '# --- added by setup_git.ps1 ---',
    '.gradle/',
    'android/.gradle/',
    'android/.kotlin/',
    'android/local.properties',
    'android/key.properties',
    '*.jks',
    '*.keystore',
    'ios/Flutter/Generated.xcconfig',
    'ios/Flutter/flutter_export_environment.sh',
    '_backup_pre_claude/',
    '.flutter-plugins',
    '.flutter-plugins-dependencies'
)

$existing = @()
if (Test-Path '.gitignore') { $existing = Get-Content '.gitignore' }

$toAdd = $needed | Where-Object { $_ -eq '' -or $_.StartsWith('#') -or ($existing -notcontains $_) }
# Drop the header/blank line if nothing real is being added.
$realAdditions = $toAdd | Where-Object { $_ -ne '' -and -not $_.StartsWith('#') }

if ($realAdditions.Count -gt 0) {
    Add-Content -Path '.gitignore' -Value $toAdd
    Write-Host "Added $($realAdditions.Count) entries to .gitignore." -ForegroundColor Green
} else {
    Write-Host '.gitignore already covers everything - no changes.' -ForegroundColor Yellow
}

# --- 4. baseline commit ------------------------------------------------------
git add -A

$staged = git diff --cached --name-only
if (-not $staged) {
    Write-Host 'Nothing to commit - working tree already matches HEAD.' -ForegroundColor Yellow
} else {
    $count = ($staged | Measure-Object).Count
    git commit -m "Baseline: Whistly as of the pre-fix code audit" -m "Snapshot taken before applying the audit fixes, so every later change is reviewable with 'git diff' and revertable with 'git checkout .'." | Out-Null
    Write-Host "Committed $count files as the baseline." -ForegroundColor Green
}

# --- 5. optional GitHub push -------------------------------------------------
Write-Host ''
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $answer = Read-Host 'GitHub CLI found. Create a PRIVATE GitHub repo and push? (y/N)'
    if ($answer -eq 'y' -or $answer -eq 'Y') {
        $name = Read-Host 'Repository name [whistly]'
        if ([string]::IsNullOrWhiteSpace($name)) { $name = 'whistly' }
        gh repo create $name --private --source . --remote origin --push
        Write-Host "Pushed to GitHub as '$name' (private)." -ForegroundColor Green
    } else {
        Write-Host 'Skipped GitHub. Local history is still in place.'
    }
} else {
    Write-Host 'GitHub CLI (gh) is not installed, so nothing was pushed.' -ForegroundColor Yellow
    Write-Host 'Your history is safe locally. To put it on GitHub later:'
    Write-Host ''
    Write-Host '    winget install GitHub.cli' -ForegroundColor Gray
    Write-Host '    gh auth login' -ForegroundColor Gray
    Write-Host '    gh repo create whistly --private --source . --remote origin --push' -ForegroundColor Gray
}

Write-Host ''
Write-Host 'Done. Useful from here on:' -ForegroundColor Cyan
Write-Host '    git status          what changed'
Write-Host '    git diff            the actual edits, line by line'
Write-Host '    git checkout .      throw away all uncommitted changes'
Write-Host ''
