# Git History Rewrite Instructions

## Problem
Commits containing hardcoded passwords need to be removed from git history.

## Solution Options

### Option 1: BFG Repo-Cleaner (Easiest, Recommended)

1. **Download BFG:**
   ```powershell
   # Download from: https://rtyley.github.io/bfg-repo-cleaner/
   # Or use chocolatey: choco install bfg-repo-cleaner
   ```

2. **Create passwords.txt file with strings to remove:**
   ```powershell
   # Create file with one password per line
   @"
   YourWiFiPassword
   YourNordVPNUsername
   YourNordVPNPassword
   "@ | Out-File -FilePath passwords.txt -Encoding ASCII
   ```

3. **Clone fresh mirror:**
   ```powershell
   git clone --mirror https://github.com/garrisonneely/raspberry-pi-travel-router.git
   ```

4. **Run BFG:**
   ```powershell
   java -jar bfg.jar --replace-text passwords.txt raspberry-pi-travel-router.git
   ```

5. **Clean and push:**
   ```powershell
   cd raspberry-pi-travel-router.git
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive
   git push --force
   ```

### Option 2: Git Filter-Branch (More control, slower)

```powershell
cd C:\Users\garri\OneDrive\TravelRouter

# Backup first!
git branch backup-before-rewrite

# Rewrite history to remove specific file versions
git filter-branch --force --index-filter `
  "git rm --cached --ignore-unmatch scripts/install.sh || true" `
  --prune-empty --tag-name-filter cat -- --all

# Note: This removes ALL history of install.sh
# You'll need to re-add the cleaned version

# Force push
git push origin --force --all
git push origin --force --tags
```

### Option 3: Start Fresh (Nuclear option)

If you don't care about commit history:

```powershell
cd C:\Users\garri\OneDrive\TravelRouter

# Save current files
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupDir = "C:\Users\garri\TravelRouter_backup_$timestamp"
Copy-Item -Path . -Destination $backupDir -Recurse -Exclude .git

# Remove git history
Remove-Item -Path .git -Recurse -Force

# Reinitialize
git init
git add .
git commit -m "Initial commit - clean history"

# Force push to remote
git remote add origin https://github.com/garrisonneely/raspberry-pi-travel-router.git
git branch -M main
git push -u origin main --force
```

## Important Notes

1. **Coordinate with collaborators** - They'll need to re-clone
2. **Update any open PRs** - They'll need to be recreated
3. **Backup first** - Always create a backup before rewriting history
4. **GitHub may cache** - Contact GitHub support if sensitive data still visible

## After Rewriting

Tell collaborators to:
```bash
git fetch origin
git reset --hard origin/main
```

Or just:
```bash
rm -rf repository
git clone https://github.com/garrisonneely/raspberry-pi-travel-router.git
```

## Verify Clean

After rewriting, search for passwords:
```powershell
git log --all --full-history --source -S 'YourPassword'
```

Should return nothing.
