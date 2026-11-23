<#
.SYNOPSIS
    Syncs the fork with upstream/main and updates the custom daily-driver build.

.DESCRIPTION
    1. Fetches latest commits from 'upstream/main'.
    2. Fast-forwards 'main' so it remains a pure 1:1 mirror of upstream/main.
    3. Pushes the pristine 'main' to 'origin/main'.
    4. Rebases 'custom' branch on top of 'main'.
    5. Compiles the release binary (with Strawberry Perl configured).
    6. Installs the updated binary to LocalAppData.
    7. Pushes 'custom' branch to 'origin/custom --force-with-lease'.

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

# 2. Check if upstream/main has new commits not in local main or custom
$UpstreamNewCount = (git rev-list --count main..upstream/main).Trim()
$CustomBehindCount = (git rev-list --count custom..upstream/main).Trim()

if ($UpstreamNewCount -eq "0" -and $CustomBehindCount -eq "0" -and -not $Force) {
    Write-Host "==> Up to date: No new commits found on upstream/main. Exiting without changes." -ForegroundColor Green
    exit 0
}

Write-Host "==> Found $UpstreamNewCount new commit(s) on upstream/main:" -ForegroundColor Yellow
git log --oneline -n 15 main..upstream/main

if ($CheckOnly) {
    Write-Host "==> CheckOnly mode enabled. No changes applied." -ForegroundColor Cyan
    exit 0
}

# 3. Ensure working directory is clean before switching branches/rebasing
$Status = git status --porcelain
if ($Status -and ($Status -join "").Trim()) {
    Write-Error "Working directory is not clean. Stash or commit your working changes before updating:`n$Status"
    exit 1
}

# 4. Fast-forward local 'main' to match 'upstream/main' (pure tracking mirror)
Write-Host "==> Updating tracking branch 'main' to match upstream/main..." -ForegroundColor Cyan
git checkout main
git merge --ff-only upstream/main
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fast-forward 'main' to 'upstream/main'."
    exit 1
}

# Push pristine main to origin/main
Write-Host "==> Pushing clean tracking mirror to fork (origin main)..." -ForegroundColor Cyan
git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push 'main' to 'origin/main'."
    exit 1
}

# 5. Check if upstream developer included custom features (e.g. group member search)
$oldPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
git grep -q -i "member.*search" upstream/main -- src/ui/info.rs
$upstreamHasFeatures = ($LASTEXITCODE -eq 0)
$ErrorActionPreference = $oldPref

if ($upstreamHasFeatures) {
    Write-Host "==> Note: Upstream developer has incorporated your features into upstream/main!" -ForegroundColor Magenta
}

# 6. Rebase 'custom' branch on top of updated 'main'
Write-Host "==> Rebasing 'custom' branch onto updated 'main'..." -ForegroundColor Cyan
git checkout custom
$oldPref = $ErrorActionPreference
$ErrorActionPreference = "Continue"
git rebase main
$rebaseExit = $LASTEXITCODE
$ErrorActionPreference = $oldPref

if ($rebaseExit -ne 0) {
    Write-Error "Git rebase encountered conflicts on branch 'custom'. Run 'git rebase --abort' to reset."
    exit 1
}
Write-Host "==> Rebase completed cleanly." -ForegroundColor Green

# 7. Build and install release executable (unless -SkipBuild is passed)
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

# 8. Push updated custom branch to GitHub fork
Write-Host "==> Pushing updated 'custom' branch to fork (origin custom)..." -ForegroundColor Cyan
git push origin custom --force-with-lease
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push to origin/custom with --force-with-lease."
    exit $LASTEXITCODE
}

Write-Host "==> Fork origin/custom updated successfully!" -ForegroundColor Green
Write-Host "==> All steps finished." -ForegroundColor Green
