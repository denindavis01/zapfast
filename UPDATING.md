# Updating & Syncing with Upstream

This document explains the fork workflow for ZapFast, how to keep `main` as an exact tracking mirror of the upstream maintainers' repository (`crmne/zapfast`), how custom features are managed in separate branches, and how to build and install daily-driver updates.

---

## 1. Branch Strategy & Repository Layout

This repository follows standard open-source fork best practices:

- **`main`**: Pure tracking mirror of `upstream/main`. Never commit custom changes or edits directly to `main`. This allows `main` to always fast-forward cleanly without conflict.
- **`custom`**: Your personal daily-driver branch. Contains your custom features, sync tools, and local preferences rebased on top of `main`.
- **`feature/contact-and-group-enhancements`**: Isolated feature branch containing only the profile picture viewing and group member search feature, ready for upstream PR review if desired.

### Remote Configuration
- **`origin`**: Your GitHub fork (`https://github.com/denindavis01/zapfast.git`)
- **`upstream`**: The original repository (`https://github.com/crmne/zapfast.git`)

Verify at any time with:
```powershell
git remote -v
```

---

## 2. Syncing Upstream Updates (Manual Workflow)

When the upstream maintainer releases new commits, sync your repository in two clean steps:

### Step 1: Update the pristine `main` branch
```powershell
# Fetch upstream
git fetch upstream main

# Fast-forward your local main
git checkout main
git merge --ff-only upstream/main

# Push clean mirror to your GitHub fork
git push origin main
```

### Step 2: Rebase your `custom` branch
```powershell
# Switch to custom branch
git checkout custom

# Rebase onto the newly updated main
git rebase main

# Push the rebased branch to your GitHub fork
git push origin custom --force-with-lease
```

*(If Git encounters a merge conflict during rebase, resolve the conflict markers, run `git add <file>`, and run `git rebase --continue`).*

---

## 3. Automated Upstream Sync Script

A standalone PowerShell script [`scripts/sync-upstream.ps1`](scripts/sync-upstream.ps1) automates the entire process:
1. Checks `upstream/main` for new commits. If none exist, it exits immediately.
2. Fast-forwards `main` and pushes it to `origin/main`.
3. Rebases `custom` onto `main`.
4. Compiles the optimized release build with Strawberry Perl.
5. Installs the new binary to `$env:LOCALAPPDATA\Programs\ZapFast\zapfast.exe`.
6. Pushes `origin/custom --force-with-lease`.

### Running manually:
```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\sync-upstream.ps1"
```

Available flags:
- `-CheckOnly`: Check for updates and list new commits without modifying git or building.
- `-SkipBuild`: Only fast-forward `main`, rebase `custom`, and push to fork without rebuilding/reinstalling.
- `-Force`: Rebase and rebuild even if no new upstream commits are detected.

---

## 4. Building and Installing Manually

If you prefer to compile manually:

### Prerequisites (Windows)
- **Rust Toolchain**: `cargo` / `rustc`
- **Strawberry Perl**: Required to compile `openssl-sys` (installed at `C:\Strawberry\perl\bin`).

### Step 1: Compile the release build
```powershell
git checkout custom
$env:PATH = "C:\Strawberry\perl\bin;C:\Strawberry\c\bin;" + $env:PATH
cargo build --release
```

### Step 2: Close running ZapFast process
```powershell
Stop-Process -Name zapfast -ErrorAction SilentlyContinue
```

### Step 3: Install the new executable
```powershell
Copy-Item -Force "target\release\zapfast.exe" "$env:LOCALAPPDATA\Programs\ZapFast\zapfast.exe"
```

---

## 5. Daily Scheduled Task (T3 Code)

To have T3 Code automatically run the check:
1. Type `/schedule` in the T3 Code chat prompt.
2. Set frequency to **Daily** (e.g., 09:00 AM).
3. Set prompt instruction:
   ```text
   Run the upstream update check for ZapFast:
   powershell -ExecutionPolicy Bypass -File "D:\Projects\zapfast\scripts\sync-upstream.ps1"
   If there are no new updates, finish immediately. If updates were found and applied, report the rebase and build outcome. If any merge conflicts occur, alert me with the conflicting files.
   ```
