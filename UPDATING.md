# Updating & Syncing with Upstream

This document explains how to sync this fork with new updates from the original repository (`crmne/zapfast`), keep your custom features conflict-free, and build/install the updated application.

---

## 1. Remote Configuration

Your repository is set up with two remotes:
- **`origin`**: Your GitHub fork (`https://github.com/denindavis01/zapfast.git`)
- **`upstream`**: The original repository (`https://github.com/crmne/zapfast.git`)

You can verify this at any time by running:
```powershell
git remote -v
```

---

## 2. Syncing Upstream Updates (Rebase Workflow)

To get the latest improvements and bug fixes from the main developer without creating merge clutter or conflicts, always use **git rebase**. This replays your custom commits on top of the newest upstream release.

### Step 1: Ensure your working directory is clean
```powershell
git status
```
*(If you have uncommitted edits, commit or stash them before proceeding).*

### Step 2: Fetch the latest upstream changes
```powershell
git fetch upstream
```

### Step 3: Rebase your `main` branch onto upstream
```powershell
git checkout main
git rebase upstream/main
```

### Step 4 (If a conflict occurs):
If Git pauses during the rebase due to overlapping edits:
1. Open the conflicted file(s) and resolve the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
2. Stage the resolved files:
   ```powershell
   git add <resolved-file>
   ```
3. Continue the rebase:
   ```powershell
   git rebase --continue
   ```
*(To abort and return to the previous state at any time, run `git rebase --abort`).*

### Step 5: Update your GitHub fork
Because the rebase places your commits cleanly at the tip of upstream's latest history:
```powershell
git push origin main --force-with-lease
```

---

## 3. Building and Installing the New Version

Once you have synced and verified the code, build and install the updated release to your system.

### Prerequisites (Windows)
- **Rust Toolchain**: `cargo` / `rustc`
- **Strawberry Perl**: Required on Windows to compile `openssl-sys` (already installed at `C:\Strawberry\perl\bin`).

### Step 1: Compile the optimized release build
Run in PowerShell from the repository root (`D:\Projects\zapfast`):
```powershell
$env:PATH = "C:\Strawberry\perl\bin;C:\Strawberry\c\bin;" + $env:PATH
cargo build --release
```
The compiled executable will be located at `target\release\zapfast.exe`.

### Step 2: Close any running ZapFast process
ZapFast runs in the background and system tray. Make sure to quit it first:
```powershell
Stop-Process -Name zapfast -ErrorAction SilentlyContinue
```

### Step 3: Install the new executable
Copy the compiled release into your local programs directory:
```powershell
Copy-Item -Force "target\release\zapfast.exe" "$env:LOCALAPPDATA\Programs\ZapFast\zapfast.exe"
```

All shortcuts (Start Menu, Taskbar, Desktop) will now run your updated build. Your chats, media cache, and accounts remain intact.

---

## 4. Automated Upstream Sync Script

A standalone script [`scripts/sync-upstream.ps1`](scripts/sync-upstream.ps1) checks upstream and only updates when new commits are found. If there are no new commits on `upstream/main`, it exits immediately without modifying your git tree, rebuilding, or touching any processes.

### Running manually
```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\sync-upstream.ps1"
```

Available flags:
- `-CheckOnly`: Check for updates and list new commits without rebasing or building.
- `-SkipBuild`: Only rebase and push to fork without rebuilding/reinstalling.
- `-Force`: Rebase and rebuild even if no new upstream commits are detected.

---

## 5. Daily Scheduled Task (T3 Code)

To have T3 Code automatically run this check every day:
1. Type `/schedule` in the T3 Code chat prompt.
2. Set the frequency to **Daily** (e.g. at 09:00 AM).
3. Set the prompt instruction to:
   ```text
   Run the upstream update check for ZapFast:
   powershell -ExecutionPolicy Bypass -File "D:\Projects\zapfast\scripts\sync-upstream.ps1"
   If there are no new updates, finish immediately. If updates were found and applied, report the rebase and build outcome. If any merge conflicts occur, alert me with the conflicting files.
   ```
