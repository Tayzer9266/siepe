# Quick Start: Deploy Mossy to siepe-software/support-tools

**Repository:** https://github.com/siepe-software/support-tools  
**Cost:** **FREE** (GitHub Actions unlimited minutes for public repos)  
**Setup Time:** 10 minutes

---

## ✅ Step-by-Step Setup

### Step 1: Clone the Repository

```powershell
# Navigate to your source folder
cd C:\source

# Clone the support-tools repo
git clone https://github.com/siepe-software/support-tools.git
cd support-tools

# Or if you already have it cloned, just navigate to it
cd C:\source\support-tools
git pull origin main
```

---

### Step 2: Add Mossy Agent Files

```powershell
# Create directory structure for Mossy
mkdir -p .github/workflows
mkdir -p mossy-automated-agent

# Copy Mossy files from AdminTools
cp C:\source\MD\AdminTools\.github\skills\ado-mossy-review\Invoke-ClaudeAPI.psm1 mossy-automated-agent\
cp C:\source\MD\AdminTools\.github\skills\ado-mossy-review\Process-MossyReview-Automated.ps1 mossy-automated-agent\
cp C:\source\MD\AdminTools\.github\skills\ado-mossy-review\CLOUD_DEPLOYMENT_GUIDE.md mossy-automated-agent\

# Copy GitHub Actions workflow
cp C:\source\MD\AdminTools\.github\workflows\mossy-review.yml .github\workflows\
```

---

### Step 3: Update Workflow Path

The GitHub Actions workflow needs to reference the correct path in the `support-tools` repo.

Edit `.github/workflows/mossy-review.yml` and update this section:

**Change FROM:**
```yaml
      - name: Process Mossy Review tickets
        shell: pwsh
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # Navigate to script directory
          cd .github\skills\ado-mossy-review
```

**Change TO:**
```yaml
      - name: Process Mossy Review tickets
        shell: pwsh
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # Navigate to script directory
          cd mossy-automated-agent
```

Also update artifact path:

**Change FROM:**
```yaml
      - name: Upload investigation reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: investigation-reports-${{ github.run_number }}
          path: Output/AutomatedInvestigations/*.md
```

**Change TO:**
```yaml
      - name: Upload investigation reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: investigation-reports-${{ github.run_number }}
          path: mossy-automated-agent/Output/*.md
```

---

### Step 4: Create README for Mossy

Create `mossy-automated-agent/README.md`:

```markdown
# Mossy Automated Agent

**Purpose:** Automatically process Azure DevOps tickets tagged "Mossy Review" using Claude API

## How It Works

1. **Scheduled Execution:** Runs every 6 hours via GitHub Actions
2. **Query ADO:** Finds all tickets tagged "Mossy Review"
3. **Analyze with Claude:** Sends ticket details to Claude API for analysis
4. **Execute SQL Queries:** Runs investigation queries against MOS databases
5. **Generate Report:** Creates markdown investigation report
6. **Post to ADO:** Adds report as comment and updates tags

## Files

- `Invoke-ClaudeAPI.psm1` - PowerShell module for Claude API calls
- `Process-MossyReview-Automated.ps1` - Main automation script
- `CLOUD_DEPLOYMENT_GUIDE.md` - Full deployment documentation

## Setup

See [CLOUD_DEPLOYMENT_GUIDE.md](CLOUD_DEPLOYMENT_GUIDE.md) for complete setup instructions.

### Quick Setup

1. Add GitHub Secrets:
   - `ANTHROPIC_API_KEY` - Your Claude API key
   - `AZURE_DEVOPS_PAT` - Azure DevOps Personal Access Token

2. Enable GitHub Actions workflow: `.github/workflows/mossy-review.yml`

3. Run manually or wait for scheduled execution (every 6 hours)

## Cost

**$0/month** - GitHub Actions is free for public repos with unlimited minutes!

## Author

Mossy (MOS Support Agent) - 2026
```

---

### Step 5: Add GitHub Secrets

1. Go to: https://github.com/siepe-software/support-tools/settings/secrets/actions

2. Click **"New repository secret"**

3. Add these secrets:

**Secret 1: ANTHROPIC_API_KEY**
- Name: `ANTHROPIC_API_KEY`
4. Value: `sk-ant-api03-YOUR_API_KEY_HERE` (get from https://console.anthropic.com/)

**Secret 2: AZURE_DEVOPS_PAT** (if needed for ADO CLI)
- Name: `AZURE_DEVOPS_PAT`
- Value: Your Azure DevOps Personal Access Token
- Get from: https://dev.azure.com/mosdata/_usersSettings/tokens
- Scopes needed: Work Items (Read & Write), Project and Team (Read)

---

### Step 6: Commit and Push

```powershell
# Check what files were added
git status

# Add Mossy files
git add .github/workflows/mossy-review.yml
git add mossy-automated-agent/

# Commit
git commit -m "Add Mossy automated agent for ADO ticket investigation"

# Push to GitHub
git push origin main
```

---

### Step 7: Enable and Test Workflow

1. **Go to GitHub Actions:**  
   https://github.com/siepe-software/support-tools/actions

2. **Find "Mossy Automated Review Agent" workflow**

3. **Click "Run workflow" button** (manual trigger)

4. **Select branch:** main

5. **Optional inputs:**
   - Max tickets: 5 (default)
   - Dry run: true (recommended for first test)

6. **Click "Run workflow"**

7. **Watch execution:**
   - Click on the running workflow
   - View real-time logs
   - Check for errors

8. **Download investigation reports:**
   - After workflow completes
   - Go to workflow run → Artifacts
   - Download `investigation-reports-XXX.zip`

---

## 🎉 That's It!

### What Happens Now?

✅ **Automatic execution every 6 hours** (computer OFF!)  
✅ **Processes up to 5 "Mossy Review" tickets per run**  
✅ **Generates investigation reports with SQL queries**  
✅ **Posts reports to ADO tickets automatically**  
✅ **Updates tags: "Mossy Review" → "Mossy Review - Complete"**  
✅ **Completely FREE** (unlimited GitHub Actions minutes)

---

## Manual Execution (Local Testing)

You can also run the script locally from your computer:

```powershell
# Set API key environment variable
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."

# Navigate to Mossy directory
cd C:\source\support-tools\mossy-automated-agent

# Run in dry-run mode (don't post to ADO)
.\Process-MossyReview-Automated.ps1 -MaxTicketsToProcess 2 -DryRun

# Run for real (posts to ADO)
.\Process-MossyReview-Automated.ps1 -MaxTicketsToProcess 5
```

---

## Monitoring

### View Execution History
- Go to: https://github.com/siepe-software/support-tools/actions
- Click on "Mossy Automated Review Agent" workflow
- See all past runs, logs, and artifacts

### Email Notifications
- GitHub sends email on workflow failures
- Configure in: Settings → Notifications

### Execution Logs
- Each workflow run has detailed logs
- Shows SQL queries executed
- Shows tickets processed
- Shows errors (if any)

---

## Troubleshooting

### Workflow Fails with "API key not provided"
- Check GitHub Secrets are set correctly
- Verify secret name is exactly `ANTHROPIC_API_KEY`

### Workflow Fails with "Cannot connect to ADO"
- Check `AZURE_DEVOPS_PAT` secret is set
- Verify PAT has correct scopes (Work Items Read/Write)
- Check PAT hasn't expired

### Workflow Fails with "Cannot connect to database"
- GitHub Actions runners cannot access on-prem MOS database
- **Solution:** Use Azure-hosted database replica OR Azure Hybrid Runbook Worker

### No Tickets Processed
- Check tickets have "Mossy Review" tag (exact match)
- Check tickets are not in "Closed" or "Removed" state
- Check ADO query in script matches your project name

---

## Cost Analysis

**GitHub Actions (Public Repo):**
- ✅ **FREE** - Unlimited minutes
- ✅ No credit card required
- ✅ Concurrent workflows allowed
- ✅ Artifact storage: 500 MB free

**Monthly Execution:**
- 4 runs/day × 30 days = 120 runs/month
- ~3 minutes per run = 360 minutes/month
- **Total cost:** $0/month

**Compare to:**
- Azure Automation: ~$7/month
- AWS Lambda: ~$2/month
- Azure VM: ~$25/month

---

## Next Steps

1. ✅ **Test workflow manually** (dry-run mode)
2. ✅ **Verify investigation reports** (download artifacts)
3. ✅ **Run for real** (posts to ADO)
4. ✅ **Monitor execution** (check GitHub Actions logs)
5. ✅ **Adjust schedule** (if needed - edit cron in workflow)

---

## Future Enhancements

- 📧 Email alerts for critical failures (high failure rate)
- 📊 PowerBI dashboard integration
- 🤖 Auto-create Bug work items for confirmed issues
- 📸 Screenshot analysis (upload screenshots to ADO ticket comments)
- 🔔 Teams/Slack notifications

---

**Repository:** https://github.com/siepe-software/support-tools  
**Workflow:** https://github.com/siepe-software/support-tools/actions  
**Author:** Mossy (MOS Support Agent)  
**Date:** 2026-07-31
