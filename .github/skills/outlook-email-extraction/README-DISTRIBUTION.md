# Outlook Email to ADO Work Item - Complete Distribution Package

## 📦 What's in This Package

This package contains everything needed to automate MOS support email processing:

```
outlook-email-extraction/
├── Install-Dependencies.bat          # ONE-TIME setup (run as admin)
├── Run-Email-Processing.bat          # Regular use (double-click anytime)
├── SKILL.md                          # Complete skill documentation
├── README-DISTRIBUTION.md            # This file
├── MCP-SERVER-CONFIG.json            # MCP server configuration (optional)
├── DISTRIBUTION-GUIDE.md             # Distribution instructions
└── QUICK-REFERENCE.txt               # Printable quick reference
```

---

## 🚀 Quick Start (3 Steps)

### Step 1: Extract Package
Unzip this folder to: `C:\source\MD\AdminTools\.github\skills\outlook-email-extraction\`

### Step 2: Install Dependencies (ONE TIME)
Right-click → **Run as Administrator**:
```
Install-Dependencies.bat
```
⏱ Takes ~5 minutes

### Step 3: Process Emails (ANYTIME - DRAG AND DROP)

**Create a folder anywhere you want** (Desktop, Downloads, Documents, etc.)

**Drop .eml files into that folder**

**Invoke via your AI assistant with the folder path:**
- Claude Desktop: "process the emails from C:\Users\YourName\Desktop\email-folder"
- GitHub Copilot: "@workspace process the emails from C:\Users\YourName\Desktop\email-folder"

**The skill automatically creates an Archive\ subfolder for processed emails**

---

## 📋 System Requirements

- **Operating System:** Windows 10/11
- **VS Code:** Latest version with GitHub Copilot extension
- **Network:** Internet access to Azure/Microsoft Graph
- **Permissions:** 
  - Local admin rights (for dependency installation)
  - Azure DevOps access (Siepe.Software project)
  - Microsoft 365 email access

---

## 🔧 What Gets Installed

The `Install-Dependencies.bat` script installs:

1. **Azure CLI** - Command-line tools for Azure
2. **Azure DevOps Extension** - ADO integration
3. **Microsoft Graph PowerShell** - Email access
4. **Azure Login** - Authenticates you to Siepe environment

**Organization:** https://siepe.visualstudio.com  
**Project:** Siepe.Software

---

## 🤖 AI Assistant Integration

This skill works with any AI assistant that supports custom skills:

### Supported AI Assistants
- **Claude Desktop** - Use with MCP server integration
- **GitHub Copilot** - Use @workspace or direct skill invocation
- **Other AI Assistants** - Any agent supporting skill/tool execution

### How to Invoke

**Claude Desktop:**
```
process the emails using outlook-email-extraction skill
```

**GitHub Copilot:**
```
@workspace process the emails from C:\source\Outlook\emails
```

**Direct Execution:**
The skill can also be invoked programmatically or through PowerShell scripts.

---

## 📧 Email Folder Structure (DRAG AND DROP)

**You choose where to put emails!** Create a folder anywhere:

```
C:\Users\YourName\Desktop\email-to-ado\     ← Your chosen folder
C:\Users\YourName\Desktop\email-to-ado\Archive\  ← Auto-created for processed emails
```

**To process emails:**
1. Save emails as .eml files (File → Save As → .eml format in Outlook)
2. Create a folder anywhere (Desktop, Downloads, Documents, etc.)
3. Copy .eml files to that folder
4. Invoke via your AI assistant with folder path:
   - Claude: "process the emails from C:\Users\YourName\Desktop\email-folder"
   - Copilot: "@workspace process the emails from [folder path]"
5. Archive subfolder is automatically created for processed emails

---

## 🎯 What the Skill Does

**Automated workflow:**
1. ✅ **Creates folders** - Sets up email/archive structure
2. ✅ **Parses emails** - Extracts sender, subject, body, attachments
3. ✅ **Analyzes screenshots** - AI vision on image attachments
4. ✅ **Investigates issues** - Database queries, log analysis (via AI assistant)
5. ✅ **Classifies type** - Bug (broken) vs Task (setup)
6. ✅ **Estimates time** - 2h (simple), 4h (moderate), 8h (complex)
7. ✅ **Creates ADO work item** - Bug or Task with full context
8. ✅ **Assigns to you** - Auto-assigns to person who ran skill
9. ✅ **Archives email** - Moves to Archive folder

**ADO Work Item Details:**
- **Parent:** Auto-matched User Story (defaults to #85799)
- **Priority:** Based on keywords (urgent, blocking, etc.)
- **Attachments:** Investigation report, original email, screenshots
- **Remaining Work:** Estimated hours from complexity analysis

---

## 🔑 Azure DevOps User Story Mapping

Emails are auto-mapped to User Stories based on keywords:

| User Story | Keywords | Type |
|------------|----------|------|
| **#85755** | price, vendor, MarkIt, ICE, LSEG, bid | Pricing Issues |
| **#85756** | balance, cash, reconciliation, Aristotle | Cash Reconciliation |
| **#85757** | Solvas, normalization, seniority, maturity | Data Normalization |
| **#85758** | new fund, portfolio setup, company setup | Portfolio Setup |
| **#85759** | duplicate, missing identifier, data quality | Data Quality |
| **#85760** | slow query, timeout, performance | Performance |
| **#85761** | SSIS, package failure, ETL, pipeline | SSIS Errors |
| **#85762** | import file, vendor file, missing file | Import Files |
| **#85799** | *DEFAULT* - No match found | General MOS Support |

---

## 🔐 Security Notes

**Credentials:**
- Azure CLI login required (one-time, uses browser auth)
- Microsoft Graph consent required (Mail.Read permission)
- Credentials stored in Windows Credential Manager

**Data:**
- Emails processed locally
- Investigation reports stored in AdminTools/Output/
- Archived emails remain on local disk
- ADO attachments uploaded to Azure DevOps

---

## 🆘 Troubleshooting

### "Azure CLI not found"
Re-run `Install-Dependencies.bat` as Administrator.

### "No emails found"
- Check that emails are .eml format (not .msg)
- Verify emails are in `C:\source\Outlook\emails\`
- Don't put emails in Archive subfolder

### "AI assistant can't find skill"
- Verify skill folder exists: `.github/skills/outlook-email-extraction/`
- Check SKILL.md has proper YAML frontmatter
- Restart your AI assistant/VS Code
- Try direct invocation via Run-Email-Processing.bat

### "Failed to create work item"
- Verify `az devops configure` shows correct organization
- Check you have access to Siepe.Software project
- Run: `az devops project show --project Siepe.Software`

### "Can't access emails"
- Run Microsoft Graph authentication again
- In PowerShell: `Connect-MgGraph -Scopes Mail.Read`

---

## 📞 Support

**For issues with this skill:**
- Contact: Tay Nguyen (tcnguyen@siepe.com)
- Location: C:\source\MD\AdminTools\.github\skills\outlook-email-extraction\

**For ADO/Azure issues:**
- Check Azure DevOps access permissions
- Verify you're in correct organization/project

---

## 📝 Version History

- **v2.2** - Auto-folder creation, time estimation, auto-assignment
- **v2.1** - Bug/Task classification
- **v2.0** - Automated workflow with Mossy integration
- **v1.0** - Basic email extraction

**Last Updated:** 2026-08-02
