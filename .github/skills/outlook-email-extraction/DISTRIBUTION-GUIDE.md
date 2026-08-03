# 📦 Email Processing Skill - Distribution Package

## Complete! Ready to Distribute

This folder contains everything needed for standalone email-to-ADO automation.

---

## 📁 Package Contents

✅ **SKILL.md** - Complete skill documentation (v2.2)  
✅ **Install-Dependencies.bat** - One-time setup (run as admin)  
✅ **Run-Email-Processing.bat** - Launch processing workflow  
✅ **README-DISTRIBUTION.md** - Setup guide for recipients  
✅ **MCP-SERVER-CONFIG.json** - Optional database integration  
✅ **DISTRIBUTION-GUIDE.md** - This file (distribution instructions)
✅ **QUICK-REFERENCE.txt** - Printable quick reference card  

---

## 🎁 Distribution Instructions

### For You (Sender):

1. **ZIP this folder:**
   ```
   Right-click → Send to → Compressed (zipped) folder
   Name: outlook-email-extraction.zip
   ```

2. **Share the ZIP file** with users via:
   - Email attachment
   - Network share
   - SharePoint/OneDrive
   - Teams chat

3. **Include these instructions:**
   - Extract to: `C:\source\MD\AdminTools\.github\skills\`
   - Run `Install-Dependencies.bat` as Administrator (one time)
   - Double-click `Run-Email-Processing.bat` to use

---

### For Recipients:

See **README-DISTRIBUTION.md** for complete setup instructions.

**Quick Start:**
1. Unzip to recommended location
2. Run Install-Dependencies.bat (as admin, one time)
3. Run Run-Email-Processing.bat anytime
4. Invoke via AI assistant:
   - Claude: "process the emails using outlook-email-extraction skill"
   - Copilot: "@workspace process the emails"

---

## ✨ Features Included

- ✅ Auto-creates folder structure
- ✅ Parses .eml email files
- ✅ AI screenshot analysis
- ✅ Database investigations (via AI assistant)
- ✅ Bug vs Task classification
- ✅ Time estimation (2h/4h/8h)
- ✅ Auto-assigns to user
- ✅ Creates ADO work items
- ✅ Auto-archives processed emails
- ✅ Works with any AI assistant

---

## 🔧 What Gets Installed

**Install-Dependencies.bat installs:**
- Azure CLI
- Azure DevOps extension
- Microsoft Graph PowerShell
- Configures Siepe ADO defaults

**No manual configuration needed!**

---

## 📋 Requirements for Recipients

- Windows 10/11
- VS Code with GitHub Copilot
- Admin rights (for dependency install)
- Azure DevOps access (Siepe.Software)
- Internet connection

---

## 🎯 Use Cases

**Perfect for:**
- MOS support teams processing client emails
- BAU support ticket automation
- Email-driven issue tracking
- Screenshot-based troubleshooting
- Multi-system investigations (pricing, cash, data quality)

**Examples:**
- Pricing discrepancies from vendor files
- Cash reconciliation issues
- Seniority/maturity field problems
- SSIS pipeline failures
- Data normalization errors

---

## 🔐 Security Notes

**Safe to distribute:**
- No hardcoded credentials
- Uses recipient's Azure login
- Uses recipient's ADO permissions
- Work items assigned to recipient

**Recipients will:**
- Login to Azure CLI (browser auth)
- Consent to Microsoft Graph (Mail.Read)
- Use their own ADO account

---

## 📞 Support

**For setup/usage questions:**
- See README-DISTRIBUTION.md (complete guide)
- Contact: Tay Nguyen (tcnguyen@siepe.com)

**For technical issues:**
- Check troubleshooting section in README
- Verify Azure CLI: `az --version`
- Test ADO access: `az devops project show --project Siepe.Software`

---

## 📝 Version

**Current Version:** v2.2 (2026-08-02)

**What's New:**
- Auto-folder creation
- Time estimation
- Auto-assignment to invoking user
- Complete distribution package
- No manual configuration required

---

## 🚀 Next Steps

1. **ZIP this folder**
2. **Share with users**
3. **They follow README-DISTRIBUTION.md**
4. **Done!**

Users can start processing emails within 5-10 minutes of receiving the package.

---

## ✅ Testing Before Distribution

**Verify the package works:**

1. Create test folder: `C:\temp\test-email-skill\`
2. Extract your ZIP there
3. Run Install-Dependencies.bat
4. Copy a test .eml file to `C:\source\Outlook\emails\`
5. Run Run-Email-Processing.bat
6. Invoke via your AI assistant:
   - Claude: "process the emails using outlook-email-extraction skill"
   - Copilot: "@workspace process the emails"
7. Verify work item created in ADO

**If everything works → Ready to distribute!**

---

## 📦 ZIP Command (PowerShell)

```powershell
# Create distribution ZIP
Compress-Archive -Path "C:\source\MD\AdminTools\.github\skills\outlook-email-extraction\*" `
                 -DestinationPath "C:\Users\$env:USERNAME\Desktop\outlook-email-extraction.zip" `
                 -Force

Write-Host "Package ready: Desktop\outlook-email-extraction.zip" -ForegroundColor Green
```

---

**Ready to distribute! 🎉**
