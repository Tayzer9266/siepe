# GitHub Secrets Setup Guide

Your repository is now configured to use GitHub Secrets for secure credential storage.

## ✅ Secrets You've Added

### 1. ANTHROPIC_API_KEY ✓
- **Purpose:** Claude API access for Mossy AI agent
- **Status:** ✅ Added
- **Used by:** 
  - `.github/workflows/mossy-review.yml` - Automated workflow
  - `.github/skills/ado-mossy-review/Process-MossyReview-Automated.ps1`

---

## 🔐 Additional Secret Required

### 2. AZURE_DEVOPS_PAT (Required for Automation)
**You need to add this secret for the GitHub Actions workflow to work!**

**Steps:**

1. **Create Azure DevOps Personal Access Token:**
   - Go to: https://dev.azure.com/mosdata/_usersSettings/tokens
   - Click **"New Token"**
   - Name: `GitHub Actions - Mossy Agent`
   - Scopes needed:
     - ✅ **Work Items**: Read, Write
     - ✅ **Code**: Read (for repository access)
   - Expiration: Choose your preference (90 days, 1 year, custom)
   - Click **"Create"**
   - **Copy the token immediately** (you won't see it again!)

2. **Add to GitHub Secrets:**
   - Go to: https://github.com/Tayzer9266/siepe/settings/secrets/actions
   - Click **"New repository secret"**
   - Name: `AZURE_DEVOPS_PAT`
   - Secret: Paste your ADO Personal Access Token
   - Click **"Add secret"**

---

## 🚀 How These Secrets Are Used

### GitHub Actions Workflow (Automated)

**File:** `.github/workflows/mossy-review.yml`

```yaml
# Step 1: Authenticate with Azure DevOps
- name: Login to Azure DevOps
  env:
    AZURE_DEVOPS_PAT: ${{ secrets.AZURE_DEVOPS_PAT }}
  run: |
    echo $env:AZURE_DEVOPS_PAT | az devops login

# Step 2: Process tickets with Claude API
- name: Process Mossy Review tickets
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    .\Process-MossyReview-Automated.ps1
```

**What it does:**
1. ✅ Runs every 6 hours automatically
2. ✅ Queries ADO for tickets tagged "Mossy Review"
3. ✅ Uses Claude API to investigate each ticket
4. ✅ Posts investigation results back to ADO as comments
5. ✅ Tags tickets as "Mossy Review - Complete"

---

## 💻 Local Development (No Secrets Needed)

**For running scripts locally on your machine:**

```powershell
# Set environment variables (temporary)
$env:ANTHROPIC_API_KEY = "sk-ant-api03-YOUR_KEY_HERE"

# Or use Azure CLI (already logged in)
az login
```

**Local scripts automatically use:**
- Your Windows authentication for MOS database
- Your Azure CLI login for ADO access
- Environment variable for Claude API

**No GitHub secrets needed for local use!**

---

## 🧪 Testing the Workflow

### Manual Trigger (Recommended First Test)

1. Go to: https://github.com/Tayzer9266/siepe/actions
2. Click **"Mossy Automated Review Agent"** workflow
3. Click **"Run workflow"** dropdown
4. Options:
   - **Max tickets:** 1 (for testing)
   - **Dry run:** true (don't post to ADO yet)
5. Click **"Run workflow"** button

**This will:**
- ✅ Test your secrets are working
- ✅ Generate investigation report
- ✅ NOT post to ADO (dry run mode)
- ✅ Upload report as artifact for review

### Review Results

1. Wait for workflow to complete (~2-5 minutes)
2. Click on the run to see details
3. Check **"Artifacts"** section - download investigation reports
4. Review the report to ensure quality
5. If good, run again with `Dry run: false` to post to ADO

---

## 📊 Current Configuration

| Secret | Status | Used By |
|--------|--------|---------|
| `ANTHROPIC_API_KEY` | ✅ Added | Claude API calls |
| `AZURE_DEVOPS_PAT` | ⚠️ **NEEDS SETUP** | ADO authentication |

---

## 🔒 Security Notes

### ✅ Safe Practices
- ✅ Secrets are encrypted by GitHub
- ✅ Secrets never appear in logs
- ✅ Secrets can be rotated anytime
- ✅ Each user has their own local credentials

### ⚠️ Important
- ⚠️ Don't share PAT tokens in tickets/chat
- ⚠️ Rotate tokens every 90 days (recommended)
- ⚠️ Use minimum required scopes for tokens
- ⚠️ Monitor workflow runs for suspicious activity

### 🚨 If a Secret is Compromised
1. **Immediately revoke** the token in Azure DevOps
2. **Delete** the GitHub secret
3. **Create new** token with fresh secret
4. **Update** GitHub secret with new value
5. **Review** recent workflow runs for unauthorized access

---

## 🎯 Next Steps

1. ✅ `ANTHROPIC_API_KEY` - Already added!
2. ⚠️ Add `AZURE_DEVOPS_PAT` (see instructions above)
3. ✅ Test workflow with manual trigger (dry run)
4. ✅ Review investigation report
5. ✅ Enable automated runs

**Once both secrets are added, the automated Mossy agent will run every 6 hours!** 🤖

---

## 📞 Troubleshooting

### "Authentication failed" in workflow
- **Cause:** `AZURE_DEVOPS_PAT` not set or expired
- **Fix:** Create new PAT and update secret

### "API key not provided"
- **Cause:** `ANTHROPIC_API_KEY` not set
- **Fix:** Verify secret name is exactly `ANTHROPIC_API_KEY`

### "No tickets found"
- **Cause:** No ADO tickets tagged "Mossy Review"
- **Fix:** This is normal - workflow will run but skip processing

### Workflow doesn't run automatically
- **Cause:** Workflow file not on `main` branch
- **Fix:** Ensure `.github/workflows/mossy-review.yml` is committed to main

---

**Questions?** Review [SETUP.md](./SETUP.md) for general authentication setup.
