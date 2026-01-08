# Remove Secrets from Git History

GitHub detected hardcoded Dynatrace API tokens in commits:
- `944badb` - deploy.sh:44
- `876fcd0` - deploy.sh:44 and TROUBLESHOOTING-NO-PROBLEMS.md:114

## ✅ What I've Done
- Removed token from `deploy-local.sh`
- Token already removed from `deploy.sh` 
- Token already removed from `docs/TROUBLESHOOTING-NO-PROBLEMS.md`

## ⚠️ Problem
The tokens still exist in **git history** from previous commits. GitHub blocks the push to protect you.

## 🔧 Solutions

### Option 1: Remove Secret from History (Recommended)

Use BFG Repo-Cleaner to remove the secret from all commits:

```bash
# 1. Install BFG (requires Java)
# Download from: https://rtyley.github.io/bfg-repo-cleaner/

# 2. Create a file with the token pattern to remove
echo "dt0c01.YOUR_LEAKED_TOKEN_HERE" > secrets.txt

# 3. Run BFG to remove the secret
java -jar bfg.jar --replace-text secrets.txt .

# 4. Clean up and rewrite history
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# 5. Force push (⚠️ Warning: rewrites history!)
git push origin main --force
```

### Option 2: Use git-filter-repo (Alternative)

```bash
# 1. Install git-filter-repo
pip install git-filter-repo

# 2. Remove the specific token from all commits
git filter-repo --replace-text <(echo "dt0c01.YOUR_LEAKED_TOKEN==>***REMOVED***")

# 3. Force push
git push origin main --force
```

### Option 3: Revoke Token & Allow Push (Quick but less secure)

If this is a demo/test token:

1. **Revoke the exposed token in Dynatrace:**
   - Go to: Settings → Access tokens
   - Find the token starting with `dt0c01.5NKSSH7V...`
   - Click **Revoke**

2. **Generate a new token:**
   - Create a new API token with same permissions
   - Update your local environment: `export DT_TOKEN='new-token'`

3. **Allow the push on GitHub:**
   - Click the URL from the error message:
   ```
   https://github.com/LocTaRND/dynatrace-ai-monitoring-demo/security/secret-scanning/unblock-secret/37z7ctnMbZAZvPedP88UZGHpxhh
   ```
   - Mark the secret as "Used in tests" or "False positive"
   - Push again: `git push`

### Option 4: Squash Commits (Simplest)

If you don't mind losing commit history:

```bash
# 1. Reset to before the problematic commits
git reset --soft origin/main

# 2. Commit all changes as one new commit
git add -A
git commit -m "Update deployment scripts and documentation"

# 3. Force push
git push origin main --force
```

## 🎯 Recommended Approach

For a demo project, **Option 4 (Squash)** is simplest:

```bash
cd /c/DATA/NashTech/Dynatrace/dynatrace-ai-monitoring-demo

# Reset to origin
git reset --soft origin/main

# Stage all changes
git add -A

# Create new commit without secrets
git commit -m "Add troubleshooting docs and fix scripts

- Added diagnostic tools
- Removed hardcoded secrets
- Updated documentation"

# Force push
git push origin main --force
```

## ✅ Verify Clean

After fixing, verify no secrets remain:

```bash
# Check for token patterns
git log -p | grep -i "dt0c01\."

# Should return nothing
```

## 🔐 Best Practices Going Forward

1. **Never commit tokens** - Use environment variables
2. **Use .gitignore** - Already updated to exclude sensitive files
3. **Use git hooks** - Install pre-commit hooks to scan for secrets
4. **Rotate tokens** - Change any exposed tokens immediately

```bash
# Install pre-commit hook to prevent future leaks
pip install detect-secrets
detect-secrets scan --baseline .secrets.baseline
```
