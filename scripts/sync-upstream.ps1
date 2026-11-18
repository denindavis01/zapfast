<#
.SYNOPSIS
    Checks for upstream updates from crmne/zapfast and updates the fork and local build only when new updates exist.

.DESCRIPTION
    1. Fetches latest commits from 'upstream/main'.
    2. Compares local 'main' with 'upstream/main'.
    3. If there are NO new commits, exits immediately with code 0.
    4. If new commits exist:
       - Displays the incoming commits.
       - Confirms the working directory is clean.
       - Rebases local 'main' onto 'upstream/main'.
       - Compiles the release binary (with Strawberry Perl configured).
       - Installs the updated binary to LocalAppData.
       - Pushes the rebased branch to the fork ('origin/main --force-with-lease').

.PARAMETER CheckOnly
    Only checks if updates exist and reports the status without modifying git or building.

.PARAMETER SkipBuild
    Rebases and pushes to the fork without compiling or reinstalling the binary.

.PARAMETER Force
    Forces rebase and rebuild even if no new upstream commits were detected.
#>

param (
    [switch]$CheckOnly = $false,
    [switch]$SkipBuild = $false,
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

# Navigate to the repository root directory
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

Write-Host "==> Checking for updates from upstream repository (crmne/zapfast)..." -ForegroundColor Cyan

# 1. Fetch latest upstream/main
try {
    git fetch upstream main --quiet
} catch {
    Write-Error "Failed to fetch upstream/main. Please check network connectivity and remote configuration."
    exit 1
}

# 2. Check if upstream/main has commits not present in local main
$BehindCount = (git rev-list --count main..upstream/main).Trim()

if ($BehindCount -eq "0" -and -not $Force) {
    Write-Host "==> Up to date: No new commits found on upstream/main. Exiting without changes." -ForegroundColor Green
    exit 0
}

Write-Host "==> Found $BehindCount new commit(s) on upstream/main:" -ForegroundColor Yellow
git log --oneline -n 15 main..upstream/main

if ($CheckOnly) {
    Write-Host "==> CheckOnly mode enabled. No changes applied." -ForegroundColor Cyan
    exit 0
}

# 3. Ensure working directory is clean before rebasing
$Status = (git status --porcelain).Trim()
if ($Status) {
    Write-Error "Working directory is not clean. Stash or commit your working changes before updating:`n$Status"
    exit 1
}

# 4. Rebase main onto upstream/main
Write-Host "==> Rebasing local main onto upstream/main..." -ForegroundColor Cyan
git checkout main
$rebaseOutput = git rebase upstream/main 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Git rebase encountered conflicts or failed:`n$rebaseOutput`nRun 'git rebase --abort' to reset."
    exit 1
}
Write-Host "==> Rebase completed cleanly." -ForegroundColor Green

# 5. Build and install release executable (unless -SkipBuild is passed)
if (-not $SkipBuild) {
    Write-Host "==> Compiling release executable..." -ForegroundColor Cyan
    $origPath = $env:PATH
    $env:PATH = "C:\Strawberry\perl\bin;C:\Strawberry\c\bin;" + $env:PATH
    
    cargo build --release
    $buildExit = $LASTEXITCODE
    $env:PATH = $origPath

    if ($buildExit -ne 0) {
        Write-Error "Cargo build failed with exit code $buildExit."
        exit $buildExit
    }

    Write-Host "==> Installing updated binary to LocalAppData..." -ForegroundColor Cyan
    Stop-Process -Name zapfast -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $installDir = "$env:LOCALAPPDATA\Programs\ZapFast"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }
    Copy-Item -Force "target\release\zapfast.exe" "$installDir\zapfast.exe"
    Write-Host "==> Installed zapfast.exe to $installDir\zapfast.exe." -ForegroundColor Green
}

# 6. Push updated branch to GitHub fork
Write-Host "==> Pushing updated main branch to fork (origin main)..." -ForegroundColor Cyan
git push origin main --force-with-lease
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push to origin/main with --force-with-lease."
    exit $LASTEXITCODE
}

Write-Host "==> Fork origin/main updated successfully!" -ForegroundColor Green
Write-Host "==> All steps finished." -ForegroundColor Green
