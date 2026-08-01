# Mossy Automated Agent - Cloud Deployment Guide

**Created:** 2026-07-31  
**Version:** 1.0  
**Status:** Proof of Concept Ready

---

## 🎯 Overview

The automated Mossy agent scripts are **cloud-agnostic** and can run on multiple platforms. This guide compares all deployment options with cost breakdowns.

**What You Have:**
- ✅ `Invoke-ClaudeAPI.psm1` - PowerShell module for calling Claude API
- ✅ `Process-MossyReview-Automated.ps1` - Main automation script
- ✅ Works on Windows, Linux, or macOS (PowerShell Core)

---

## 💰 Cost Comparison

| Platform | Cost | Computer OFF? | Setup Difficulty | Best For |
|----------|------|---------------|------------------|----------|
| **GitHub Actions (Public Repo)** | **$0** | ✅ YES | ⭐ Easy | **BEST VALUE** - Free unlimited minutes |
| **GitHub Actions (Private Repo)** | **$0-8/month** | ✅ YES | ⭐ Easy | Free tier: 2,000 min/month |
| **Azure Automation** | **$5-10/month** | ✅ YES | ⭐⭐ Medium | Managed PowerShell runbooks |
| **Azure Functions** | **$2-5/month** | ✅ YES | ⭐⭐⭐ Hard | Serverless, event-driven |
| **Azure VM** | **$20-50/month** | ✅ YES | ⭐⭐ Medium | Full control, Windows Server |
| **AWS Lambda** | **$1-3/month** | ✅ YES | ⭐⭐⭐ Hard | Serverless, cheapest compute |
| **AWS EC2** | **$10-40/month** | ✅ YES | ⭐⭐ Medium | Full control, Linux/Windows |
| **Local Task Scheduler** | **$0** | ❌ NO | ⭐ Easy | Computer must stay on |

**Recommended:** **GitHub Actions (Public Repo)** - Completely free, unlimited minutes, easy setup!

---

## 🏆 OPTION 1: GitHub Actions (FREE!) - RECOMMENDED

### ✅ Advantages

- ✅ **FREE** for public repos (unlimited minutes)
- ✅ **FREE** for private repos (2,000 minutes/month = ~67 hours)
- ✅ Runs 24/7 even when computer is OFF
- ✅ Native PowerShell support (Windows, Linux, macOS runners)
- ✅ GitHub Secrets for API key storage (secure)
- ✅ Cron scheduling (hourly, daily, weekly)
- ✅ Full Git version control
- ✅ Email notifications on failure
- ✅ Detailed execution logs
- ✅ No credit card required for public repos

### 📋 Setup Steps

#### 1. Create GitHub Repository

```powershell
# Navigate to AdminTools
cd C:\source\MD\AdminTools

# Initialize Git (if not already done)
git init

# Create .gitignore (exclude secrets and output files)
# (Already created!)

# Create GitHub repo (via GitHub website or CLI)
gh repo create mossy-automated-agent --public --description "Automated MOS support ticket investigation with Claude API"
```

#### 2. Create GitHub Actions Workflow

Create file: `.github/workflows/mossy-review.yml`

```yaml
name: Mossy Automated Review

on:
  # Run every 6 hours
  schedule:
    - cron: '0 */6 * * *'  # Every 6 hours
    # - cron: '0 9 * * *'  # Daily at 9 AM UTC
    # - cron: '0 0 * * 1'  # Weekly on Monday
  
  # Allow manual trigger
  workflow_dispatch:

jobs:
  process-mossy-review:
    runs-on: windows-latest  # Use Windows runner for native PowerShell
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup PowerShell
        shell: pwsh
        run: |
          Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
          Write-Host "OS: $($PSVersionTable.OS)"
      
      - name: Install Azure CLI
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Process Mossy Review tickets
        shell: pwsh
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          cd .github/skills/ado-mossy-review
          .\Process-MossyReview-Automated.ps1 -MaxTicketsToProcess 5
      
      - name: Upload investigation reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: investigation-reports
          path: C:\source\MD\AdminTools\Output\AutomatedInvestigations\*.md
          retention-days: 30
```

#### 3. Store API Key in GitHub Secrets

**GitHub Website:**
1. Go to your repo → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `ANTHROPIC_API_KEY`
4. Value: `sk-ant-api03-YOUR_API_KEY_HERE` (get from https://console.anthropic.com/)
5. Click "Add secret"

**Also add:**
- Name: `AZURE_CREDENTIALS` (for Azure DevOps CLI access)
- Value: Azure service principal JSON (if needed for ADO access)

#### 4. Push to GitHub

```powershell
git add .
git commit -m "Add automated Mossy agent with GitHub Actions"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/mossy-automated-agent.git
git push -u origin main
```

#### 5. Test Workflow

- Go to repo → Actions → "Mossy Automated Review" → "Run workflow"
- Watch real-time logs
- Download investigation reports as artifacts

### 📊 Cost Breakdown (GitHub Actions)

**Public Repo:**
- ✅ **FREE** - Unlimited minutes
- ✅ No credit card required

**Private Repo:**
- Free tier: 2,000 minutes/month
- Example: 5-minute runs every 6 hours = 20 runs/day = 100 min/day = 3,000 min/month
- **Cost:** ~$8/month for extra 1,000 minutes ($0.008/min)

**Recommendation:** Use public repo for FREE unlimited automation!

---

## 💵 OPTION 2: AWS (Cheapest Cloud Option)

### ✅ Advantages

- ✅ Runs 24/7 even when computer is OFF
- ✅ **Cheapest cloud compute** (~$1-3/month for Lambda)
- ✅ AWS Lambda: Serverless, pay-per-execution
- ✅ AWS Secrets Manager: Secure API key storage
- ✅ EventBridge: Scheduled triggers (cron)
- ✅ CloudWatch Logs: Execution logs and monitoring
- ✅ Global infrastructure (low latency)

### 📋 Setup Options

#### Option 2A: AWS Lambda (Serverless - CHEAPEST)

**What It Is:**
- Serverless function that runs on-demand
- PowerShell Core runtime supported
- Pay only for execution time (100ms granularity)
- 1M requests/month FREE tier

**Setup Steps:**

1. **Create Lambda Function**
   - Runtime: PowerShell Core 7.4
   - Handler: `Process-MossyReview-Automated.ps1`
   - Timeout: 15 minutes
   - Memory: 512 MB

2. **Upload PowerShell Scripts**
   - Package scripts in ZIP file
   - Include `Invoke-ClaudeAPI.psm1` and `Process-MossyReview-Automated.ps1`
   - Upload to Lambda

3. **Store API Key in AWS Secrets Manager**
   ```powershell
   aws secretsmanager create-secret `
       --name MossyClaudeAPIKey `
       --secret-string "sk-ant-api03-YOUR_API_KEY_HERE"
   ```

4. **Modify Script to Read from Secrets Manager**
   ```powershell
   # In Process-MossyReview-Automated.ps1
   $secretJson = aws secretsmanager get-secret-value --secret-id MossyClaudeAPIKey --query SecretString --output text
   $APIKey = $secretJson
   ```

5. **Create EventBridge Rule (Schedule)**
   - Schedule: `cron(0 */6 * * ? *)` (every 6 hours)
   - Target: Lambda function

**Cost Breakdown:**

| Component | Usage | Cost |
|-----------|-------|------|
| Lambda execution | 120 invocations/month × 3 min | **$0.60/month** |
| Lambda requests | 120 requests/month | **$0.00** (free tier) |
| Secrets Manager | 1 secret | **$0.40/month** |
| EventBridge | 120 triggers/month | **$0.00** (free) |
| CloudWatch Logs | ~1 GB/month | **$0.50/month** |
| **TOTAL** | | **~$1.50/month** |

**Free Tier:**
- First 1M requests: FREE
- First 400,000 GB-seconds: FREE
- Likely **$0-2/month** in first year

---

#### Option 2B: AWS EC2 (Full Control)

**What It Is:**
- Virtual machine (Windows or Linux)
- Full control, always-on or scheduled start/stop
- Task Scheduler (Windows) or cron (Linux)

**Setup Steps:**

1. **Launch EC2 Instance**
   - Instance type: `t3.micro` (1 vCPU, 1 GB RAM)
   - OS: Windows Server 2022 or Amazon Linux 2
   - Storage: 20 GB SSD

2. **Install PowerShell Core** (if Linux)
   ```bash
   wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.0/powershell-7.4.0-linux-x64.tar.gz
   tar -xzf powershell-7.4.0-linux-x64.tar.gz -C /opt/microsoft/powershell/7
   ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
   ```

3. **Copy Scripts to EC2**
   ```powershell
   scp -i mykey.pem *.ps1 ec2-user@<IP>:/home/ec2-user/mossy/
   ```

4. **Setup Cron Job** (Linux)
   ```bash
   crontab -e
   # Add line:
   0 */6 * * * /usr/bin/pwsh /home/ec2-user/mossy/Process-MossyReview-Automated.ps1
   ```

5. **Setup Task Scheduler** (Windows)
   - Same as local setup
   - Use PowerShell script from proof-of-concept

**Cost Breakdown:**

| Component | Usage | Cost |
|-----------|-------|------|
| EC2 instance (t3.micro) | 730 hours/month (always-on) | **$7.50/month** |
| EBS storage | 20 GB SSD | **$2.00/month** |
| Data transfer | ~1 GB/month | **$0.00** (free tier) |
| **TOTAL** | | **~$9.50/month** |

**Cost Optimization:**
- Use spot instances: **$3/month** (60% cheaper)
- Stop instance when not running: **$2/month** (storage only)
- Free tier (first 12 months): **$0/month**

---

## ⚙️ OPTION 3: Azure Automation (Managed Service)

### ✅ Advantages

- ✅ Runs 24/7 even when computer is OFF
- ✅ **Managed PowerShell runbooks** (no server management)
- ✅ Native Azure DevOps integration
- ✅ Hybrid Runbook Worker (can access on-prem databases)
- ✅ Built-in scheduling
- ✅ Azure Key Vault integration

### 📋 Setup Steps

1. **Create Automation Account**
   ```powershell
   az automation account create `
       --name MossyAutomation `
       --resource-group MOS-Support `
       --location eastus
   ```

2. **Import PowerShell Modules**
   - Upload `Invoke-ClaudeAPI.psm1` to Automation Account modules

3. **Create Runbook**
   - Name: `Process-MossyReview`
   - Type: PowerShell
   - Upload `Process-MossyReview-Automated.ps1`

4. **Store API Key in Azure Key Vault**
   ```powershell
   az keyvault secret set `
       --vault-name MossyKeyVault `
       --name ClaudeAPIKey `
       --value "sk-ant-api03-..."
   ```

5. **Schedule Runbook**
   - Frequency: Every 6 hours
   - Runbook: Process-MossyReview
   - Parameters: MaxTicketsToProcess=5

**Cost Breakdown:**

| Component | Usage | Cost |
|-----------|-------|------|
| Automation runtime | 120 runs × 3 min = 360 min | **$7.20/month** ($0.002/min) |
| Key Vault | 1 secret, 120 operations | **$0.03/month** |
| **TOTAL** | | **~$7.23/month** |

---

## 📊 FINAL RECOMMENDATION

### 🏆 Best Option: **GitHub Actions (Public Repo)**

**Why:**
1. ✅ **Completely FREE** (unlimited minutes)
2. ✅ Easy setup (copy/paste YAML file)
3. ✅ Secure API key storage (GitHub Secrets)
4. ✅ Version control built-in
5. ✅ Great for open-source/shareable automation
6. ✅ No cloud provider account needed
7. ✅ Runs 24/7 even when computer is OFF

### 🥈 Runner-Up: **AWS Lambda**

**Why:**
1. ✅ Cheapest cloud option (~$1-2/month)
2. ✅ Serverless (no server management)
3. ✅ Pay only for execution time
4. ✅ Free tier (first year)

### 🥉 Third Place: **Azure Automation**

**Why:**
1. ✅ Native PowerShell support
2. ✅ Easy Azure DevOps integration
3. ✅ Can access on-prem MOS database (Hybrid Worker)
4. ⚠️ More expensive (~$7/month)

---

## 🔒 Security Best Practices (All Platforms)

### API Key Storage

**❌ NEVER do this:**
```powershell
$APIKey = "sk-ant-api03-..."  # Hardcoded in script
```

**✅ ALWAYS do this:**

**GitHub Actions:**
```yaml
env:
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

**AWS Secrets Manager:**
```powershell
$APIKey = (aws secretsmanager get-secret-value --secret-id MossyClaudeAPIKey).SecretString
```

**Azure Key Vault:**
```powershell
$APIKey = (Get-AzKeyVaultSecret -VaultName "MossyKeyVault" -Name "ClaudeAPIKey").SecretValueText
```

### Network Security

- ✅ Use HTTPS for all API calls (Claude API is HTTPS-only)
- ✅ Restrict database access to cloud runner IPs (firewall rules)
- ✅ Use Azure DevOps PAT (Personal Access Token) for ADO access
- ✅ Enable audit logging for all secret access

---

## 🚀 Quick Start Guide

### Option 1: GitHub Actions (FREE)

```powershell
# 1. Initialize Git repo
cd C:\source\MD\AdminTools
git init

# 2. Create GitHub repo
gh repo create mossy-automated-agent --public

# 3. Create workflow file
mkdir -p .github/workflows
# Copy mossy-review.yml (see above)

# 4. Add API key to GitHub Secrets
# Go to repo → Settings → Secrets → Actions → New secret
# Name: ANTHROPIC_API_KEY
# Value: sk-ant-api03-...

# 5. Push to GitHub
git add .
git commit -m "Add Mossy automation"
git push -u origin main

# 6. Test workflow
# Go to repo → Actions → Run workflow
```

**Total time:** 10 minutes  
**Total cost:** $0/month  
**Computer OFF:** ✅ YES

---

## 📈 Scaling & Performance

### Expected Execution Time

- Single ticket analysis: ~2-3 minutes
- 5 tickets: ~10-15 minutes
- 10 tickets: ~20-30 minutes

### GitHub Actions Minutes

**Public repo:**
- Unlimited minutes = process 100+ tickets/day for FREE

**Private repo:**
- 2,000 free minutes/month = ~130 tickets/month
- Extra minutes: $0.008/min = $0.16 per ticket

### AWS Lambda Execution

- $0.0000166667 per GB-second
- 512 MB × 180 seconds = ~$0.0015 per ticket
- 120 tickets/month = **$0.18/month**

---

## 🎓 Summary

| Platform | Cost | Setup Time | Computer OFF? | Recommended For |
|----------|------|------------|---------------|-----------------|
| **GitHub Actions (Public)** | **$0** | 10 min | ✅ | **Everyone - START HERE** |
| GitHub Actions (Private) | $0-8 | 10 min | ✅ | Private code |
| AWS Lambda | $1-3 | 30 min | ✅ | Cost optimization |
| AWS EC2 | $10-40 | 20 min | ✅ | Full control needed |
| Azure Automation | $7-10 | 15 min | ✅ | Azure-heavy environments |

---

## ✅ Next Steps

1. ✅ **DONE:** Created proof-of-concept PowerShell scripts
   - `Invoke-ClaudeAPI.psm1` - API helper module
   - `Process-MossyReview-Automated.ps1` - Main automation script

2. **Choose deployment platform:**
   - **Recommended:** GitHub Actions (FREE!)
   - Alternative: AWS Lambda (cheapest cloud)
   - Alternative: Azure Automation (managed service)

3. **Setup deployment:**
   - Follow quick start guide above
   - Store API key securely in platform secrets
   - Configure schedule (every 6 hours recommended)

4. **Test automation:**
   - Run workflow manually
   - Verify ticket analysis works
   - Check investigation reports

5. **Monitor and iterate:**
   - Review execution logs
   - Adjust MaxTicketsToProcess as needed
   - Add email notifications (optional)

---

**🎉 You now have everything needed to run Mossy 24/7 in the cloud - even when your computer is OFF!**

**Total cost:** **$0/month** (GitHub Actions public repo)  
**Setup time:** **10 minutes**  
**Maintenance:** **Zero** (fully automated)
