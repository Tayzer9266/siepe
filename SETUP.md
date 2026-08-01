# Setup Guide - Mossy Agent Toolkit

This guide will help you set up authentication and configuration for the Mossy Agent Toolkit.

---

## 🔐 Authentication Requirements

### 1. Azure DevOps (Required)

Mossy needs to create work items, query tickets, and post comments to ADO.

**Option A: Azure CLI (Recommended)**
```powershell
# Install Azure CLI if not already installed
winget install Microsoft.AzureCLI

# Login to Azure DevOps
az login
az devops configure --defaults organization=https://dev.azure.com/YourOrg project=YourProject
```

**Option B: Personal Access Token (PAT)**
```powershell
# Create PAT at: https://dev.azure.com/YourOrg/_usersSettings/tokens
# Scopes needed: Work Items (Read, Write), Code (Read)

$env:AZURE_DEVOPS_EXT_PAT = "your-pat-token-here"
```

### 2. MOS Database Access (Required)

**Windows Authentication (Recommended)**
- Your Windows account must have read access to MOS databases
- No additional configuration needed if running on domain-joined machine

**SQL Authentication (Alternative)**
```powershell
# Update connection strings in scripts
$connectionString = "Server=YourServer;Database=Enterprise;User Id=youruser;Password=yourpass;"
```

### 3. Microsoft Outlook (For Email Skills)

**Required for:**
- `email-to-ado-workitem` skill
- Any email processing automation

**Setup:**
- Outlook must be installed and configured with your work email
- COM automation requires Outlook to be installed (not just Outlook Web)

### 4. GitHub Copilot / Claude API (For AI Features)

**Interactive Mode (GitHub Copilot):**
- Already configured if you're using VS Code with Copilot extension
- No additional setup needed

**Autonomous Mode (Claude API):**
```powershell
# Get API key from: https://console.anthropic.com/
$env:ANTHROPIC_API_KEY = "sk-ant-api03-..."
```

---

## 📁 Configuration Files

### 1. Update ADO Settings

Edit each PowerShell script header:
```powershell
# Configuration
$AdoOrg = "https://dev.azure.com/YourOrganization"
$AdoProject = "YourProject"
$FeatureId = 35679  # Your BAU Support Feature ID
```

### 2. Database Connection Strings

Scripts automatically use Windows Authentication to:
- `Enterprise` database (main MOS database)
- `Solvas` database (transaction data)
- `SecurityMaster` database (pricing data)

If using SQL authentication, update the connection string pattern in each script.

---

## 🚀 Skill-Specific Setup

### Email-to-ADO Workitem

**Folder Structure:**
```
C:\Users\{YourUsername}\Desktop\email-to-ado-workitem\
├── Inbox\       (Place .msg files here)
├── Archive\     (Processed emails)
└── Error\       (Failed emails)
```

**Run:**
```powershell
cd .github\skills\email-to-ado-workitem
.\Process-EmailToADO.ps1
```

### Mossy Review Automation

**Scheduled Task Setup:**
```powershell
cd .github\skills\ado-mossy-review
.\Setup-MossyReview-Monitor.ps1  # Sets up Windows scheduled task
```

**Manual Run:**
```powershell
.\Check-MossyReview-WorkItems.ps1
```

---

## 🔒 Security Best Practices

### DO ✅
- ✅ Use Windows Authentication when possible
- ✅ Store PATs in environment variables (not scripts)
- ✅ Use Azure Key Vault for production deployments
- ✅ Set up read-only database access for investigation queries
- ✅ Use `.gitignore` to prevent committing credentials

### DON'T ❌
- ❌ Commit API keys or PATs to Git
- ❌ Share database connection strings in tickets
- ❌ Store passwords in plain text files
- ❌ Grant write access to production databases
- ❌ Use personal credentials for automated systems

---

## 🧪 Testing Your Setup

### 1. Test Azure DevOps Access
```powershell
az boards query --wiql "SELECT [System.Id] FROM WorkItems WHERE [System.Id] = 82115"
```

### 2. Test Database Access
```powershell
# Test Enterprise database connection
Invoke-Sqlcmd -ServerInstance "YourServer" -Database "Enterprise" -Query "SELECT TOP 1 * FROM dbo.tCompany" -TrustServerCertificate
```

### 3. Test Email Processing
```powershell
# Save a test email to Desktop\email-to-ado-workitem\Inbox
# Then run:
.\Process-EmailToADO.ps1 -WhatIf  # Dry run mode
```

---

## 🆘 Troubleshooting

### "Access Denied" Errors

**ADO:**
- Check PAT token hasn't expired
- Verify `az devops configure` defaults are set
- Ensure you have work item create permissions

**Database:**
- Verify Windows account has db_datareader role
- Check VPN/network connectivity to SQL Server
- Try explicit SQL authentication

### Outlook COM Errors

**"Cannot create COM object":**
```powershell
# Repair Outlook installation
# Or reinstall Office with COM support
```

**"Operation failed":**
- Close all Outlook instances before running script
- Check Outlook is configured (not first-run setup)

### Git Push Errors

**Authentication:**
```powershell
# Configure Git credentials
git config --global user.name "Your Name"
git config --global user.email "you@company.com"

# Use GitHub Personal Access Token
git remote set-url origin https://YOUR_PAT@github.com/Tayzer9266/siepe.git
```

---

## 📞 Support

For questions or issues:
1. Check existing ADO tickets tagged "Mossy"
2. Review skill documentation in `.github/skills/`
3. Contact the MOS Support team

---

## 🎯 Next Steps

1. ✅ Complete authentication setup above
2. ✅ Test each authentication method
3. ✅ Update configuration variables in scripts
4. ✅ Run a test investigation
5. ✅ Set up automation (optional)

Ready to investigate! 🚀
