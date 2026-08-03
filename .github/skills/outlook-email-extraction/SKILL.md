---
skill_name: outlook-email-extraction
title: Outlook Email Extraction & Automated Processing (Mossy Workspace Edition)
description: Extract, search, and AUTOMATE processing of Microsoft Outlook emails from Mossy workspace folder. NEW v2.5.0 - DYNAMIC SPRINT EDITION - Automatically finds current sprint User Story under Feature 35679 (CAMOS BAU Support Tracker). Email folder fixed at C:\source\MD\AdminTools\email-workitem\ (same level as .github\) for consistency. Batch loop processing - handles ALL emails in folder automatically. Parses emails, classifies as Bug or Task, creates ADO work items under the latest sprint User Story, estimates time to resolve, auto-assigns to user, inherits parent Iteration, and archives processed emails. Works with any AI assistant (Claude, Copilot, etc.). Simple workflow focused on designated workspace folder.
version: 2.5.0
output_format: text_files, json, markdown_reports, ado_bugs_and_tasks
last_updated: 2026-08-02
apply_to:
  - pattern: "**/*"
    when_user_mentions:
      - "outlook"
      - "email"
      - "inbox"
      - "search email"
      - "find email"
      - "retrieve email"
      - "email from"
      - "extract email"
      - "process the emails"
      - "process emails"
      - "create tasks from emails"
      - "automated email processing"
---

# Outlook Email Extraction & Automated Processing Skill

## Purpose

**v2.5.0 - DYNAMIC SPRINT EDITION:** Automatically finds the current sprint User Story under **Feature 35679 (CAMOS BAU Support Tracker)** instead of hardcoding User Story ID. This ensures work items are always created under the most recent sprint without manual updates.

**v2.4.0 - MOSSY WORKSPACE EDITION:** For Mossy agent, email folder is fixed at workspace root `C:\source\MD\AdminTools\email-workitem\` alongside `.github\` for consistency. This differs from the portable standalone versions (Output\ and Desktop\) which use relative paths.

**v2.2 AUTO-ASSIGNMENT & TIME ESTIMATION:** Work items automatically assigned to person who invoked skill (from $env:USERNAME). Time to resolve estimated based on complexity (2h simple, 4h moderate, 8h complex). Folder structure auto-created if missing.

**v2.1 BUG/TASK CLASSIFICATION:** Automatically determines whether issues are Bugs (broken/incorrect) or Tasks (setup/enhancement). All work items require parent User Story.

**v2.0 AUTOMATED WORKFLOW:** Complete email-to-task automation! Process MOS support emails end-to-end: parse emails → analyze screenshots → database investigations → classify Bug vs Task → create ADO work items with attachments → archive processed emails. Works with any AI assistant.

**v1.0 BASIC:** Extract Microsoft Outlook emails using Microsoft Graph API and save them to local files for:
- Finding ticket-related communications
- Verifying data push confirmations
- Searching for stakeholder requests
- Documenting email threads
- Investigating historical communications

**Mossy Email Folder Location:** Fixed workspace root - `C:\source\MD\AdminTools\email-workitem\`

---

## When to Use

**✅ AUTOMATED WORKFLOW (v2.5) - Use when:**
- User says **"process emails to work item"** or **"process the emails"**
- **MOSSY WORKSPACE**: Email folder is fixed at workspace root for consistency
- **AUTOMATIC SPRINT DETECTION**: Script queries Feature 35679 to find current sprint's User Story
- Email folder location: `C:\source\MD\AdminTools\email-workitem\`
- User has .eml files in the email-workitem folder
- Simple email-to-task conversion - no complex investigation
- Works with any AI assistant (Claude, Copilot, or others)

**📁 MOSSY EMAIL FOLDER (FIXED WORKSPACE PATH):**
- Location: `C:\source\MD\AdminTools\email-workitem\`
- Fixed at workspace root (same level as `.github\` folder)
- Consistent across all Mossy skill invocations
- Auto-creates `processed\` subfolder for archiving
- Different from portable standalone versions (Output\ and Desktop\ use relative paths)
- No user input needed for folder path

**📋 PARENT USER STORY (DYNAMIC SPRINT DETECTION):**
- Queries: **Feature 35679 - CAMOS BAU Support Tracker** (grandparent)
- Automatically finds: Latest sprint User Story under Feature 35679
- Method: Queries all child User Stories, sorts by creation date, uses most recent
- Example: Feature 35679 → User Story #86322 (08.26a) → Current sprint
- Link: https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/35679
- No manual updates needed when sprint changes
- Always uses current sprint automatically

**✅ BASIC EXTRACTION (v1.0) - Use when:**
- User asks to "find email about [topic]"
- User mentions "check my inbox for [something]"
- User needs to retrieve email confirmation
- User wants to search emails by subject, sender, or date
- Investigating ticket history requires email context
- Need to document stakeholder communications (without creating tasks)

**Common Requests:**
- "Process emails to work item" (automatically checks C:\source\MD\AdminTools\email-workitem\)
- "Process the emails" (automatically checks C:\source\MD\AdminTools\email-workitem\)
- "@mossy process emails to work item"
- Skill automatically uses: `C:\source\MD\AdminTools\email-workitem\`
- No need to specify folder path - it's fixed at workspace root

---

---

## 🚀 Quick Start for New Users

**For first-time setup, just run these two batch files:**

### Step 1: Install Dependencies (ONE TIME ONLY)

**Right-click** → **Run as Administrator**

```
Install-Dependencies.bat
```

**What it installs:**
- Azure CLI
- Azure DevOps extension
- Microsoft Graph PowerShell modules
- Configures ADO defaults (organization: siepe.visualstudio.com)

**Time:** ~5 minutes

---

### Step 2: Process Emails (MOSSY WORKSPACE FOLDER)

**Place .eml files in the Mossy workspace email folder:**

For Mossy agent, the email folder is fixed at workspace root:

**Mossy Path (Fixed):**
- `C:\source\MD\AdminTools\email-workitem\` (same level as `.github\` folder)
- Archive: `C:\source\MD\AdminTools\email-workitem\processed\`

**Note:** The standalone versions (Output\ and Desktop\) use portable relative paths, but Mossy uses this fixed workspace root path for consistency.

**Tell your AI assistant:**

```
"Process the emails"
```
or
```
"@mossy process emails to work item"
```

**That's it!** The skill will:
- Parse emails
- Analyze screenshots  
- Investigate issues
- Estimate time to resolve
- Create ADO work items assigned to you
- Archive processed emails

---

## Prerequisites

1. **Microsoft Graph PowerShell Module** - Installed by Install-Dependencies.bat
2. **Microsoft 365 Account** - User must have Outlook/Exchange access
3. **Azure CLI** - Installed by Install-Dependencies.bat
4. **Permissions** - Mail.Read, Mail.ReadBasic, ADO project access
5. **Network Access** - Internet connection to Microsoft Graph API

---

## Manual Setup (Advanced Users Only)

**Most users should use Install-Dependencies.bat instead**

### Step 1: Initial Setup (One-Time)

**Run the setup script:**

```powershell
cd C:\source\Outlook
.\Setup-OutlookAccess.ps1
```

**What it does:**
1. ✅ Installs Microsoft Graph PowerShell module (if not present)
2. ✅ Opens browser for Microsoft 365 authentication
3. ✅ Requests Mail.Read permissions
4. ✅ Tests email access by retrieving last 5 emails
5. ✅ Keeps connection active for subsequent operations

**Expected Output:**
```
✅ Microsoft Graph module already installed
✅ Connected successfully!
   User: tcnguyen@siepe.com
   Scopes: Mail.Read, Mail.ReadBasic
✅ Email access successful! Recent emails:
   📨 RE: Aristotle Data Push Request
      From: hassan@example.com
      Date: 2026-07-28...
```

**Note:** Connection persists across PowerShell sessions. Re-run if disconnected.

---

## Step 2: Retrieve All Recent Emails

**Get last 50 emails sent to mos-support@siepe.com from this week (last 7 days):**

```powershell
cd C:\source\Outlook
.\Get-OutlookEmails.ps1
```

**With custom parameters:**

```powershell
# Get last 100 emails from last 14 days
.\Get-OutlookEmails.ps1 -Count 100 -DaysBack 14

# Filter by subject
.\Get-OutlookEmails.ps1 -Subject "Aristotle" -DaysBack 30

# Filter by sender
.\Get-OutlookEmails.ps1 -From "hassan@" -DaysBack 7

# Search different mailbox
.\Get-OutlookEmails.ps1 -To "myemail@siepe.com"

# Combine filters
.\Get-OutlookEmails.ps1 -Subject "Data Push" -From "hassan" -Count 20 -DaysBack 14
```

**Parameters:**
- `-Count` - Number of emails to retrieve (default: 50)
- `-DaysBack` - How many days back to search (default: 7)
- `-To` - Filter by recipient address (default: "mos-support@siepe.com")
- `-Subject` - Filter by subject contains text
- `-From` - Filter by sender email contains text
- `-OutputFolder` - Where to save (default: C:\source\Outlook)

**Output Structure:**
Emails are organized in date-based subfolders:
```
C:\source\Outlook\
├── 2026-07-28\               # Date folder (YYYY-MM-DD)
│   ├── 143020_Data_Push_Complete.txt
│   ├── 150315_Price_Exception_Review.txt
│   └── 162530_Aristotle_Fund_Setup.txt
├── 2026-07-27\
│   ├── 091520_Cash_Reconciliation.txt
│   └── ...
├── EmailSummary_20260728_153045.txt      # Summary with file locations
└── EmailsBackup_20260728_153045.json     # JSON backup of all emails
```

**Console Output:**
```
✅ Retrieved 23 emails

💾 Saved summary to: C:\source\Outlook\EmailSummary_20260728_153045.txt
💾 Saved JSON backup to: C:\source\Outlook\EmailsBackup_20260728_153045.json

📊 Emails organized by date:

  📅 2026-07-28 - 15 emails
     [14:30:20] Data Push Complete
     [15:03:15] Price Exception Review
     [16:25:30] Aristotle Fund Setup

  📅 2026-07-27 - 8 emails
     [09:15:20] Cash Reconciliation Issue
     ...

📊 Email Summary:
  📨 RE: Pacific Life Data Push - Complete
     From: hassan@siepe.com
     Date: 2026-07-28T14:23:00Z
```

---

## Step 3: Search Specific Emails

**Search for specific keywords in mos-support@siepe.com inbox (last 7 days):**

```powershell
cd C:\source\Outlook
.\Search-OutlookEmails.ps1 -SearchTerm "Aristotle"
```

**Search Examples:**

```powershell
# Find emails about data pushes (this week)
.\Search-OutlookEmails.ps1 -SearchTerm "data push"

# Find emails about specific funds (last 30 days)
.\Search-OutlookEmails.ps1 -SearchTerm "IMDBKLNS" -DaysBack 30

# Find emails about ticket numbers
.\Search-OutlookEmails.ps1 -SearchTerm "#85164" -DaysBack 60

# Search different mailbox
.\Search-OutlookEmails.ps1 -SearchTerm "price exception" -To "myemail@siepe.com"
```

**Search Behavior:**
- Searches both **subject** and **body** content
- Filters to **mos-support@siepe.com** by default (override with `-To` parameter)
- Searches last **7 days** by default (override with `-DaysBack` parameter)
- Case-insensitive
- Partial match (contains)
- Returns up to 50 most recent matches

**Output Structure:**
Same as retrieval - emails saved in date-based subfolders:
```
C:\source\Outlook\
├── 2026-07-28\
│   ├── 143020_Data_Push_Complete.txt      # Email file
│   └── ...
├── SearchSummary_Aristotle_20260728.txt   # Summary with locations
```

**Console Output:**
```
🔍 Searching Outlook emails for: 'Aristotle'

✅ Found 12 emails

💾 Saved search summary to: C:\source\Outlook\SearchSummary_Aristotle_20260728.txt

📊 Search results organized by date:

  📅 2026-07-28 - 5 emails
     [14:23:00] RE: Aristotle Data Push Request - Complete
     [16:15:30] Aristotle Fund Setup Questions

  📅 2026-07-27 - 7 emails
     [10:30:45] Aristotle Position Marks Review
     ...

✅ Done! Emails organized in date folders under C:\source\Outlook
```

---

## Step 4: Analyze Retrieved Emails

**Browse emails by date:**

```powershell
# List all date folders
Get-ChildItem C:\source\Outlook -Directory | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }

# Open today's emails folder
explorer C:\source\Outlook\2026-07-28

# Open specific email
code C:\source\Outlook\2026-07-28\143020_Data_Push_Complete.txt
```

**Or use PowerShell to filter:**

```powershell
# Read and filter JSON data
$emails = Get-Content C:\source\Outlook\Emails_20260728_153045.json | ConvertFrom-Json

# Find emails from specific sender
$emails | Where-Object { $_.From.EmailAddress.Address -like "*hassan*" } | 
    Select-Object Subject, ReceivedDateTime

# Find emails with attachments
$emails | Where-Object { $_.HasAttachments -eq $true } | 
    Select-Object Subject, ReceivedDateTime
```

---

## Common Use Cases

### Use Case 1: Verify Data Push Confirmation

**Scenario:** Need to confirm that a data push email was received

```powershell
# Search for recent data push emails
.\Search-OutlookEmails.ps1 -SearchTerm "data push" -DaysBack 3

# Or filter by sender
.\Get-OutlookEmails.ps1 -From "hassan" -Subject "push" -DaysBack 7
```

### Use Case 2: Find Ticket-Related Emails

**Scenario:** Investigating ticket #85164, need related emails

```powershell
# Search by ticket number
.\Search-OutlookEmails.ps1 -SearchTerm "85164" -DaysBack 30

# Or by ticket subject
.\Search-OutlookEmails.ps1 -SearchTerm "Position Load Issue" -DaysBack 14
```

### Use Case 3: Track Stakeholder Communications

**Scenario:** Need all emails from a specific person about a project

```powershell
# Get all emails from Hassan about Aristotle
.\Get-OutlookEmails.ps1 -From "hassan" -Subject "Aristotle" -Count 50 -DaysBack 30
```

### Use Case 4: Document Email Thread

**Scenario:** Need to save email conversation for documentation

```powershell
# Get emails about specific topic
.\Search-OutlookEmails.ps1 -SearchTerm "Pacific Life IMDBKLNS" -DaysBack 14

# Emails are now organized in date folders, open summary to see locations
code C:\source\Outlook\SearchSummary_Pacific_Life_IMDBKLNS_*.txt

# Or browse the date folder directly
explorer C:\source\Outlook\2026-07-28
```

---

## Troubleshooting

### "Not connected to Microsoft Graph"

**Error:** Running Get/Search scripts returns connection error

**Solution:**
```powershell
cd C:\source\Outlook
.\Setup-OutlookAccess.ps1
```

Re-authenticate with your Microsoft 365 account.

### "Module Microsoft.Graph not found"

**Error:** Setup script can't find Graph module

**Solution:**
```powershell
# Install manually with admin rights
Install-Module Microsoft.Graph -Scope CurrentUser -Force

# Then run setup
.\Setup-OutlookAccess.ps1
```

### "Permission denied" or "Insufficient privileges"

**Error:** Can't access emails due to permissions

**Solution:**
1. Disconnect current session: `Disconnect-MgGraph`
2. Re-run setup: `.\Setup-OutlookAccess.ps1`
3. Grant requested permissions in browser
4. Check with IT if Mail.Read scope is blocked

### No Emails Found

**Error:** Search returns 0 results but emails should exist

**Possible Causes:**
- Date range too narrow (increase `-DaysBack`)
- Search term misspelled
- Emails in different folder (scripts only search Inbox)
- Filter too restrictive

**Solution:**
```powershell
# Broaden search
.\Search-OutlookEmails.ps1 -SearchTerm "Aristotle" -DaysBack 90

# Remove filters
.\Get-OutlookEmails.ps1 -Count 100 -DaysBack 30
```

---

## Advanced Usage

### Get Emails from Specific Date Range

```powershell
# Retrieve emails, then filter in PowerShell
$emails = Get-Content C:\source\Outlook\Emails_20260728_153045.json | ConvertFrom-Json

# Filter by specific date
$targetDate = Get-Date "2026-07-28"
$emails | Where-Object { 
    (Get-Date $_.ReceivedDateTime).Date -eq $targetDate.Date 
} | Select-Object Subject, From, ReceivedDateTime
```

### Export to CSV for Excel Analysis

```powershell
# Load emails
$emails = Get-Content C:\source\Outlook\Emails_20260728_153045.json | ConvertFrom-Json

# Export to CSV
$emails | Select-Object Subject, 
    @{N='From';E={$_.From.EmailAddress.Address}}, 
    ReceivedDateTime, 
    HasAttachments, 
    @{N='BodyPreview';E={$_.BodyPreview.Substring(0, [Math]::Min(100, $_.BodyPreview.Length))}} |
    Export-Csv C:\source\Outlook\Emails_Export.csv -NoTypeInformation

# Open in Excel
.\Emails_Export.csv
```

### Combine Multiple Searches

```powershell
# Search multiple terms
$terms = @("Aristotle", "Pacific Life", "IMDBKLNS")
foreach ($term in $terms) {
    .\Search-OutlookEmails.ps1 -SearchTerm $term -DaysBack 14
}

# Results saved as separate files
Get-ChildItem C:\source\Outlook\Search_*.txt | Sort-Object LastWriteTime -Descending
```

---

## Integration with MOS Support Workflow

### Example: Verify Data Push Request

**User Request:** "Check if Hassan sent confirmation email about Aristotle data push"

**Mossy Workflow:**
1. Search emails: `.\Search-OutlookEmails.ps1 -SearchTerm "Aristotle data push" -DaysBack 3`
2. Review results in output file
3. Confirm email received and extract details
4. Document in investigation report

**Example Output:**
```markdown
## Email Verification

Searched Outlook for: "Aristotle data push"
Date Range: Last 3 days

**Result:** ✅ Confirmation email found

**Email Details:**
- From: hassan@siepe.com
- Date: 2026-07-28 14:23:00
- Subject: RE: Pacific Life Data Push - Complete
- Content: Data push completed successfully for IMDBKLNS, PLCOP, MSCIT
- File: C:\source\Outlook\Search_Aristotle_data_push_20260728_153245.txt
```

---

## Files Reference

**Scripts:**
- `C:\source\Outlook\Setup-OutlookAccess.ps1` - Initial setup and authentication
- `C:\source\Outlook\Get-OutlookEmails.ps1` - Retrieve and save emails
- `C:\source\Outlook\Search-OutlookEmails.ps1` - Search for specific emails

**Output:**
- `C:\source\Outlook\Emails_*.json` - Email data in JSON format
- `C:\source\Outlook\Emails_*.txt` - Email data in text format
- `C:\source\Outlook\Search_*.txt` - Search results

---

## Limitations

- ❌ Only searches **Inbox** folder (not Sent, Drafts, or custom folders)
- ❌ Attachments not downloaded (only metadata shown)
- ❌ Max 50 results per search (Graph API limitation)
- ❌ Requires active internet connection
- ❌ Subject to Microsoft Graph API rate limits
- ✅ Works with Exchange Online / Microsoft 365 Outlook
- ✅ Does NOT work with local .PST files or IMAP accounts

---

## Security & Privacy

- ✅ Uses Microsoft Graph API (official Microsoft authentication)
- ✅ Requires explicit user consent for Mail.Read permission
- ✅ Emails saved locally (not sent to external services)
- ✅ JSON/text files contain full email content (treat as sensitive data)
- ⚠️ Do NOT commit email files to Git repositories
- ⚠️ Add `C:\source\Outlook\*.json` and `*.txt` to .gitignore

---

## Success Criteria

- ✅ Setup completes without errors
- ✅ Can retrieve recent emails successfully
- ✅ Search returns relevant results
- ✅ Output files created in C:\source\Outlook\
- ✅ Email content readable and complete
- ✅ Can disconnect and reconnect successfully

---

## AUTOMATED WORKFLOW: Process CAMOS BAU Support Emails

**NEW in v2.5:** Dynamic sprint detection! Automatically finds current sprint User Story under Feature 35679 (CAMOS BAU Support Tracker). No more manual updates when sprints change. Simple automated email processing for designated folder that parses emails, classifies as Bug/Task, creates ADO work items under the current sprint's User Story, and archives processed emails.

**🔒 CRITICAL:** Archival is MANDATORY and AUTOMATIC. After each successful task creation, the email is IMMEDIATELY moved from designated folder to `processed/` to prevent duplicate processing. Failed emails remain in folder for automatic retry on next run.

### When to Use This Workflow

**✅ Use when:**
- User says "process the emails" or "@mossy process the emails"
- MOS support emails are waiting in `C:\source\Outlook\emails\` folder
- User wants automated ticket creation from support emails
- Multiple emails need investigation and task creation

**❌ Do NOT use when:**
- Just searching/retrieving emails (use basic search/retrieval above)
- Emails don't map to User Stories (requires manual review)
- Only need email extraction without investigation

### Workflow Overview

```
┌─────────────────────────────────────────────────────────────┐
│  0. Find Current Sprint User Story (NEW v2.5.0)              │
│     - Query Feature 35679 (CAMOS BAU Support Tracker)       │
│     - Get all child work items                               │
│     - Filter for User Stories only                           │
│     - Sort by creation date (most recent first)              │
│     - Use latest User Story as parent for all work items     │
│     - Extract parent's Iteration Path                        │
│     - Example: Feature 35679 → User Story #86322 (current)   │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  1. Check Designated Folder (AUTOMATIC)                      │
│     - ALWAYS check: C:\source\MD\AdminTools\email-workitem\  │
│     - No user input needed - skill knows where to look       │
│     - CREATE processed\ subfolder if doesn't exist           │
│     - Scan for .eml files to process                         │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Scan & Loop Through ALL Emails                           │
│     - Get ALL .eml files from designated folder             │
│     - LOOP: Process each email in sequence                   │
│     - Extract sender, subject, body, attachments             │
│     - Download all image attachments                         │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Classify Work Item Type (Bug vs Task)                    │
│     - Check for Bug keywords: "error", "broken", "failing",  │
│       "incorrect", "blank", "missing", "discrepancy"         │
│     - Check for Task keywords: "setup", "configure", "new",  │
│       "review", "investigate"                                │
│     - Default to Bug if any incorrect behavior found         │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Estimate Time to Resolve                                 │
│     - Simple review/setup: 2 hours                           │
│     - Moderate investigation: 4 hours                        │
│     - Complex multi-system issue: 8 hours                    │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Classify Work Item Type (Bug vs Task)                    │
│     - Check for bug keywords (broken, error, failing, etc.)  │
│     - Check investigation findings (data issues, failures)   │
│     - Check screenshots (error messages, blank fields)       │
│     - Default to Bug if any incorrect behavior found         │
│     - Use Task for setup/configuration/enhancement work      │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Estimate Time to Resolve                                 │
│     - Simple review/setup: 2 hours                           │
│     - Moderate investigation: 4 hours                        │
│     - Complex multi-system issue: 8 hours                    │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Create Azure DevOps Bug/Task (THREE-STEP PROCESS)       │
│     - STEP 0: Parent already determined in workflow step 0   │
│       * Current sprint User Story found from Feature 35679   │
│       * Iteration Path extracted from parent work item       │
│       * Child MUST inherit parent's sprint assignment        │
│     - STEP 1: Create work item with CONCISE summary         │
│       * READ email content from .eml file                    │
│       * PARSE plain text from MIME multipart format          │
│       * BUILD concise single-paragraph description:          │
│         - Problem + brief context (300 chars max)            │
│         - Email metadata (From, Date)                        │
│         - Reference to attached email for full details       │
│       * Prevents Azure DevOps field truncation              │
│       * Set title, assigned-to, estimate, --iteration        │
│       * NOTE: Cannot set parent in --fields parameter        │
│     - STEP 2: Add parent relation (REQUIRED)                 │
│       * az boards work-item relation add --relation-type     │
│         parent --target-id $ParentUserStoryId                │
│       * This is the ONLY way to properly link parent         │
│     - STEP 3: Upload original .eml file as attachment        │
│       * Uses Azure DevOps REST API (CLI doesn't support      │
│         file attachments)                                    │
│       * Get token, upload file, link to work item            │
│       * Provides complete email with headers for reference   │
│     - DYNAMIC: Parent = Current Sprint User Story (from      │
│       Feature 35679)                                         │
│     - Set priority based on issue severity                   │
│     - Set time estimate (step 5):                            │
│       * Bug: RemainingWork field                             │
│       * Task: Estimate field                                 │
│     - Assign to person who invoked the skill (from $env:     │
│       USERNAME)                                              │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Archive Processed Emails (MANDATORY - AUTOMATIC)         │
│     - CREATE processed/ folder if it doesn't exist           │
│     - AUTOMATICALLY move ORIGINAL .eml files from designated │
│       folder to processed/ subfolder                         │
│     - Happens IMMEDIATELY after successful work item creation│
│     - Prevents re-processing of same emails                  │
│     - Archive is permanent record of processed emails        │
│     - Leaves emails in place ONLY if processing failed       │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  8. Loop Back or Complete                                    │
│     - IF more emails in folder: LOOP BACK to step 2         │
│     - IF all emails processed: Generate summary report       │
│     - Display all work items created with IDs and titles     │
│     - Show total count of Bugs and Tasks created             │
└─────────────────────────────────────────────────────────────┘
```

### Parent User Story (DYNAMIC SPRINT DETECTION)

**This skill uses Feature 35679 (CAMOS BAU Support Tracker) as the grandparent.**

All work items created from the Mossy workspace email folder are **AUTOMATICALLY** assigned to the **current sprint's User Story** by querying Feature 35679 and finding the most recent User Story child.

**Feature 35679 - CAMOS BAU Support Tracker**
- Link: https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/35679
- Grandparent for all CAMOS BAU support work
- Contains sprint-specific User Stories as children
- Script queries this Feature to find current sprint User Story

**📋 Dynamic Sprint Detection Logic:**
1. Query Feature 35679 for all child work items
2. Filter for work items of type "User Story"
3. Sort User Stories by creation date (descending)
4. Select the most recent User Story as the parent
5. Example: Feature 35679 → User Story #86322 (08.26a) ← Current sprint

**Why Dynamic Detection?**
- No manual updates needed when sprint changes
- Always uses correct current sprint User Story
- Survives sprint rollovers automatically
- Eliminates hardcoded User Story IDs

### Work Item Type Classification (Bug vs Task)

**CRITICAL:** Mossy must determine whether to create a **Bug** or **Task** based on issue nature.

**📋 Classification Rules:**

| Work Item Type | When to Use | Keywords | Examples |
|----------------|-------------|----------|----------|
| **Bug** | Something is **broken**, not working as designed, data corruption, system failure | not working, broken, error, failing, incorrect data, blank field, missing data, discrepancy, mismatch, crash, timeout, null | • Seniority field blank in MOS Portal<br>• Balance discrepancies<br>• SSIS package failures<br>• Incorrect price calculations<br>• Data normalization failures |
| **Task** | New functionality, enhancements, configuration, setup, manual investigation needed | setup, configure, new fund, new portfolio, add feature, enhancement, investigate, review | • New fund setup<br>• Portfolio configuration<br>• Manual price review<br>• Add new data source<br>• Performance optimization |

**🔍 Classification Logic (Apply in Order):**

1. **Check for Bug Keywords:**
   - Email contains: "not working", "broken", "error", "failing", "incorrect", "blank", "missing", "discrepancy", "mismatch", "null", "crash"
   - Investigation found: data corruption, system errors, failed processes
   - Screenshot shows: error messages, blank fields where data expected, red highlighted issues
   - Root cause: system/pipeline failure, bad data, regression
   - **→ Create as Bug**

2. **Check for Task Keywords:**
   - Email contains: "setup", "configure", "new fund", "new portfolio", "add", "please review"
   - Investigation needed: manual review, configuration change, new entity creation
   - No system failure identified
   - **→ Create as Task**

3. **Default Classification:**
   - If unclear, classify as **Bug** if investigation found ANY incorrect behavior
   - If purely exploratory/setup work with no error, classify as **Task**

**💡 Examples:**

| Email Subject | Classification | Reason |
|---------------|----------------|--------|
| "Solvas not feeding MOS Portal - Seniority field blank" | **Bug** | Data not appearing where expected (blank field) |
| "Balance discrepancies - Trestles CLO funds" | **Bug** | Incorrect financial data (discrepancy) |
| "SSIS package failing for vendor import" | **Bug** | System failure (failing) |
| "Setup new fund - Pacific Life CLO 5" | **Task** | New entity setup (setup) |
| "Please review pricing for CUSIP 12345" | **Task** | Manual investigation (review) |
| "Add maturity field to normalization" | **Task** | New functionality (add) |

**🚨 MANDATORY: Parent User Story Assignment**

**EVERY** Bug or Task **MUST** have a parent User Story assigned.

**Parent is DYNAMICALLY determined from Feature 35679:**
- Feature 35679 - CAMOS BAU Support Tracker (grandparent)
- Script queries Feature 35679 to find current sprint User Story
- Most recent User Story child becomes the parent
- Example: Feature 35679 → User Story #86322 (current sprint) → Tasks/Bugs
- Automatically updates when new sprints are created

**🚨 MANDATORY: Iteration Must Match Parent**

**EVERY** created work item **MUST** inherit the parent's Iteration Path.

**Implementation:**
- After finding current sprint User Story, extract its Iteration Path
- Set `--iteration "$parentIteration"` when creating child work item
- Ensures sprint alignment and proper backlog organization
- Example: Parent in `Siepe.Software\08.26a` → Child also in `Siepe.Software\08.26a`

**📊 Parent Assignment Priority:**
- Email found in `C:\source\MD\AdminTools\email-workitem\` → Parent = Current Sprint User Story (from Feature 35679)
- No category match / ambiguous / general support issue → **Parent = Current Sprint User Story**

### Quality Gate Rules (CRITICAL)

**"If you are unable to attach an analysis then you should not even create a tasks"**  
**"The tasks does not even have enough context, if it does not have enough context don't create the tasks it will be useless"**

**Task creation ONLY happens when ALL conditions are met:**

1. ✅ **Email body fully extracted** - Not just headers
2. ✅ **All attachments downloaded and analyzed** - Screenshots processed with view_image
3. ✅ **Parent Iteration Path retrieved** - Child must inherit parent's sprint
3. ✅ **Mossy investigation completed successfully** - Investigation report generated
4. ✅ **Sufficient context for action** - Investigation report has database findings, root cause, or next steps

**Skip task creation (but keep investigation report) when:**
- ❌ Email parsing failed or incomplete
- ❌ Attachments couldn't be downloaded
- ❌ Mossy investigation returned errors
- ❌ Investigation report has no actionable findings
- ❌ Database queries returned no results
- ❌ Cannot determine root cause or next steps

### Example Invocation

**User says:** `@mossy process emails to work item`

**Agent Response:**
```
=== Email Processing Workflow (MOSSY WORKSPACE) ===

[Step 0/8] Finding current sprint User Story...
  Querying Feature #35679 (CAMOS BAU Support Tracker)...
  Found 4 child work items, filtering for User Stories...
  ✅ Current Sprint User Story: #86322
  Title: CAMOS BAU Support 08.26a
  Iteration: Siepe.Software\08.26a
  All child work items will inherit this iteration

[Step 1/8] Checking Mossy workspace email folder...
  Email folder: C:\source\MD\AdminTools\email-workitem\
  ✅ Folder exists
  ✅ processed\ subfolder exists

[Step 2/8] Scanning for emails...
  Found 3 email(s):
     - US Diameter Trade Validation.eml
     - Solvas not feeding MOS Portal.eml
     - Trestles CLO Balance Discrepancies.eml

[Step 3/8] Processing emails...

📧 Email 1: "US Diameter Trade Validation - Secondary Sale XEROX"
   ├─ Parent: User Story #86322 (CAMOS BAU Support 08.26a) ← Auto-detected
   ├─ Classification: 📋 TASK (trade review, no error)
   ├─ Estimate: 2 hours
   ├─ Work Item Created: Task #86446 ✅
   └─ Archived: ✅ AUTOMATIC (moved to processed/)

📧 Email 2: "Solvas not feeding MOS Portal - Seniority blank"
   ├─ Parent: User Story #86322 (CAMOS BAU Support 08.26a) ← Auto-detected
   ├─ Classification: 🐛 BUG (blank field where data expected)
   ├─ Estimate: 4 hours
   ├─ Work Item Created: Bug #86445 ✅
   └─ Archived: ✅ AUTOMATIC (moved to processed/)

📧 Email 3: "Trestles CLO Balance Discrepancies"
   ├─ Parent: User Story #86322 (CAMOS BAU Support 08.26a) ← Auto-detected
   ├─ Classification: 🐛 BUG (balance discrepancy)
   ├─ Estimate: 4 hours
   ├─ Work Item Created: Bug #86447 ✅
   └─ Archived: ✅ AUTOMATIC (moved to processed/)

✅ Processing Complete
   - Emails processed: 3
   - Work items created: 3 (2 Bugs, 1 Task)
     • Bug #86445 (Solvas seniority blank field)
     • Task #86446 (US Diameter Trade Validation)  
     • Bug #86447 (Trestles balance discrepancy)
   - All assigned to: tcnguyen@siepe.com ✅
   - All parented to: User Story #86322 (current sprint) ✅
   - Emails AUTOMATICALLY archived: 3 → processed/
   - Designated folder: Empty (all processed successfully)
```

### PowerShell Implementation

**For manual invocation (not needed when using Mossy agent):**

```powershell
# Process all .eml files in emails folder
cd C:\source\MD\AdminTools
.\Process-MOSSupportEmails.ps1
```

**What it does:**
1. **Sets up email processing folder structure** (if not already created):
   - Always checks Mossy workspace folder: `C:\source\MD\AdminTools\email-workitem\`
   - Creates `processed\` subfolder if it doesn't exist
   - Ensures infrastructure is ready before processing
2. **Scans designated folder for ALL .eml files**
   - Gets complete list of unprocessed emails
   - Processes in alphabetical order
3. **LOOPS through each email file** (processes ALL emails in folder)
4. Parses each email (MIME format) - sender, subject, body, attachments
5. Classifies as Bug (broken/incorrect) or Task (setup/review)
6. **Estimates time to resolve** based on complexity:
   - Simple review/setup: 2 hours
   - Moderate investigation: 4 hours
   - Complex multi-system issue: 8 hours
7. Creates ADO Bug/Task (THREE-STEP PROCESS):
   - STEP 0: Queries parent for Iteration Path (MANDATORY)
     * **Retrieves**: Parent #86322's System.IterationPath field
     * **Ensures**: Child inherits parent's sprint assignment
     * **Uses**: `az boards work-item show --id 86322`
   - STEP 1: Creates work item with CONCISE email summary
     * **READS** email content from .eml file (parses MIME multipart format)
     * **BUILDS** concise single-paragraph description (prevents truncation):
       - Problem statement with brief context (300 chars max)
       - Email metadata (From, Date)
       - Reference to attached email for full details
     * Cleans quoted-printable encoding (=92, =93, etc.)
     * Keeps description under 500 characters for Azure DevOps compatibility
     * Sets title, description, assigned-to, estimate, **--iteration**
   - STEP 2: Adds parent relation (CRITICAL - must be separate command)
     * **Uses**: `az boards work-item relation add --relation-type parent --target-id 86322`
     * **Cannot use**: `--fields "System.Parent=86322"` (doesn't work for parent links)
   - STEP 3: Uploads original .eml file as attachment
     * **Uses**: Azure DevOps REST API (Azure CLI doesn't support file attachments)
     * Gets access token → uploads file → links to work item
     * Provides complete email with headers for reference
   - **Sets parent to User Story #86322 (CAMOS BAU Support 08.26a)** - HARDCODED
   - **Sets Iteration to match parent** - MANDATORY for sprint alignment
   - Sets priority (High/Medium based on keywords like "blocking", "urgent")
   - Sets Estimate/RemainingWork hours (from step 6)
   - **Assigns to person who invoked skill** (detected from $env:USERNAME)
8. **AUTOMATICALLY moves ORIGINAL .eml files to Archive folder (MANDATORY)**
   - Archive/ folder already exists (created in step 1)
   - **MOVES** (not copies) the ORIGINAL email file IMMEDIATELY after successful task creation
   - Archive/ folder becomes permanent storage of processed original emails
   - Prevents duplicate processing (file no longer exists in main folder)
   - Only skips move if task creation failed (so original email can be retried)
9. **Continues loop until all emails processed**
10. Generates summary report with all work items created

### Investigation Report Structure

Each investigation creates a markdown file with:

**Header:**
- Email subject, sender, date
- User Story mapping
- Priority assessment
- Screenshot analysis summary

**Body:**
- Email body content (full text)
- Screenshot analysis (if attachments present)
  - Visual data extraction
  - Error messages identified
  - Key observations
- Database investigation findings
  - SQL queries executed
  - Results summary
  - Data discrepancies found
- Root cause hypothesis
- Recommended next steps

**Footer:**
- Files generated (reports, queries)
- Related tickets/user stories
- Assignee recommendations

**Example:** `CashReconciliation_TrestlesCLO_20260728.md`

```markdown
# CAMOS BAU Support Investigation
**Email:** Re Trestles CLO 3, 4, 9 & 10 – Push Transactions & Balances to Aristotle DW
**From:** hassan@siepe.com  
**Date:** 2026-07-28  
**User Story:** #86322 (CAMOS BAU Support 08.26a)

## Screenshot Analysis

**image001.png** - Balance Reconciliation Dashboard

Extracted Data:
- BLCLO3: Cash difference -$25,246.58
- BLCLO4: Cash difference -$25,246.58 (identical - suggests common transaction)
- BLCLO9: Cash difference -$100,986.30
- BLCLO10: Cash difference -$176,726.03
- **Total discrepancy:** $328,205.49

## Database Investigation

Queried MOS Production for transaction history...

[Database findings, root cause, next steps]

## Recommended Actions

1. Investigate common transaction for BLCLO3/BLCLO4 (identical amounts)
2. Review balance rollover logic for all 4 funds
3. Compare Aristotle DW vs MOS ledger entries

**Priority:** MEDIUM-HIGH (large dollar amount but no blocking issue)
```

### ADO Work Item Creation Details

**Work Item Type:** Determined by classification logic (Bug or Task)

**MANDATORY Fields:**

```powershell
# LOOP STRUCTURE: Process ALL emails in folder (MOSSY WORKSPACE)
# Mossy uses fixed workspace root path for consistency
$emailFolder = "C:\source\MD\AdminTools\email-workitem"
$archiveFolder = Join-Path $emailFolder "processed"

# Ensure folders exist
if (!(Test-Path $emailFolder)) {
    New-Item -Path $emailFolder -ItemType Directory | Out-Null
}
if (!(Test-Path $archiveFolder)) {
    New-Item -Path $archiveFolder -ItemType Directory | Out-Null
}

# Get all .eml files to process
$emailFiles = Get-ChildItem $emailFolder -Filter *.eml -ErrorAction SilentlyContinue
Write-Host "Found $($emailFiles.Count) email(s) to process" -ForegroundColor Cyan

# Track results
$results = @()

# LOOP: Process each email
foreach ($emailFile in $emailFiles) {
    Write-Host "`n📧 Processing: $($emailFile.Name)" -ForegroundColor Yellow
    $emailFilePath = $emailFile.FullName
    
    # Parse email headers and body
    $content = Get-Content $emailFilePath -Raw
    $lines = $content -split "`r?`n"
    
    # [Extract subject, from, date - code from previous sections]
    # ... email parsing code here ...
    
    # Determine work item type based on classification logic
    $workItemType = if ($isBug) { "Bug" } else { "Task" }
    
    # PARENT IS REQUIRED - fail if not found
if (-not $parentUserStory) {
    Write-Error "❌ No parent User Story found for email. Cannot create work item."
    return
}

# ITERATION MUST MATCH PARENT - query parent for Iteration Path
$parentWI = az boards work-item show --id 86322 --output json | ConvertFrom-Json
$parentIteration = $parentWI.fields.'System.IterationPath'
Write-Host "  Parent Iteration: $parentIteration" -ForegroundColor Gray

# Work item creation using Azure CLI (Step 1: Create with full email context)

# Extract email body from .eml file (parse plain text content)
$bodyStarted = $false
$bodyLines = @()
foreach ($line in $lines) {
    if ($bodyStarted) {
        $bodyLines += $line
    }
    if ($line -match "^$" -and !$bodyStarted) {
        $bodyStarted = $true
    }
}
$emailBody = ($bodyLines -join "`n").Trim()

# Extract plain text section from MIME multipart email
$emailBodyText = ""
$plainTextStart = $emailBody.IndexOf("Content-Type: text/plain")
if ($plainTextStart -ge 0) {
    $remainingText = $emailBody.Substring($plainTextStart)
    $nextBoundary = $remainingText.IndexOf("--_000_")
    if ($nextBoundary -gt 0) {
        $plainSection = $remainingText.Substring(0, $nextBoundary)
        $contentStart = $plainSection.IndexOf("`n`n") + 2
        if ($contentStart -gt 1) {
            $emailBodyText = $plainSection.Substring($contentStart).Trim()
            # Clean quoted-printable encoding
            $emailBodyText = $emailBodyText -replace "=92", "'" -replace "=93", '"' -replace "=94", '"' -replace "=\r?\n", "" -replace "=20", " "
        }
    }
}

# Analyze email content for CONCISE problem summary
# Keep description short to avoid Azure DevOps field truncation
# Full details available in attached .eml file
$emailPreview = $emailBodyText.Substring(0, [Math]::Min(500, $emailBodyText.Length))

# Build concise single-paragraph description
$description = "PROBLEM: $emailSubject. "

# Add brief analysis if email content is available
if ($emailBodyText.Length -gt 100) {
    # Extract first meaningful paragraph for context
    $firstPara = $emailPreview -split "`n`n" | Where-Object { $_.Trim().Length -gt 50 } | Select-Object -First 1
    if ($firstPara) {
        $description += $firstPara.Substring(0, [Math]::Min(300, $firstPara.Length)) + "... "
    }
}

$description += "From: $emailFrom | Date: $emailDate | See attached email for full details."

# Get parent's Iteration to ensure consistency
$parentWI = az boards work-item show --id 86322 --output json | ConvertFrom-Json
$parentIteration = $parentWI.fields.'System.IterationPath'

$workItemJson = az boards work-item create `
    --type $workItemType `
    --title "$emailSubject" `
    --description $description `
    --iteration "$parentIteration" `
    --project "Siepe.Software" `
    --assigned-to "$env:USERNAME@siepe.com" `
    --fields "Microsoft.VSTS.Common.Priority=2" `
            "$estimateField=$estimateHours" `
    --org "https://siepe.visualstudio.com/" `
    --output json

$workItem = $workItemJson | ConvertFrom-Json
$workItemId = $workItem.id

# Step 2: Add parent relation (REQUIRED - System.Parent field doesn't work in --fields)
az boards work-item relation add `
    --id $workItemId `
    --relation-type parent `
    --target-id 86322 `
    --org "https://siepe.visualstudio.com/"

# Step 3: Upload original email as attachment using REST API
# Azure CLI doesn't support file attachments, must use REST API
Write-Host "  Step 3: Uploading email attachment..." -ForegroundColor Cyan

# Get Azure access token for ADO API
$token = (az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 | ConvertFrom-Json).accessToken

# Upload file to ADO attachments endpoint
$fileName = Split-Path $emailFilePath -Leaf
$uploadUrl = "https://siepe.visualstudio.com/_apis/wit/attachments?fileName=$fileName&api-version=7.0"
$uploadHeaders = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/octet-stream"
}
$fileBytes = [System.IO.File]::ReadAllBytes($emailFilePath)
$uploadResponse = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $uploadHeaders -Body $fileBytes
$attachmentUrl = $uploadResponse.url

# Link attachment to work item
$workItemUrl = "https://siepe.visualstudio.com/_apis/wit/workitems/$workItemId`?api-version=7.0"
$patchHeaders = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json-patch+json"
}
$patchBody = "[{`"op`":`"add`",`"path`":`"/relations/-`",`"value`":{`"rel`":`"AttachedFile`",`"url`":`"$attachmentUrl`",`"attributes`":{`"comment`":`"Original email file`"}}}]"
Invoke-RestMethod -Uri $workItemUrl -Method Patch -Headers $patchHeaders -Body $patchBody | Out-Null

Write-Host "  ✅ Email attachment uploaded" -ForegroundColor Green

# Archive the processed email
$archivePath = Join-Path $archiveFolder $fileName
Move-Item -Path $emailFilePath -Destination $archivePath -Force
Write-Host "  ✅ Archived to: $archivePath" -ForegroundColor Green

Write-Host "✅ Created $workItemType #$workItemId under User Story #86322" -ForegroundColor Green
Write-Host "   Iteration: $parentIteration" -ForegroundColor Gray

# Track result
$results += [PSCustomObject]@{
    WorkItemId = $workItemId
    Type = $workItemType
    Title = $emailSubject
    Iteration = $parentIteration
}

} # End of foreach loop

# Display summary
Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              PROCESSING COMPLETE - ALL EMAILS              ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "  Total emails processed: $($results.Count)" -ForegroundColor Green
Write-Host "  Work items created:" -ForegroundColor White
foreach ($result in $results) {
    Write-Host "    • $($result.Type) #$($result.WorkItemId) - $($result.Title)" -ForegroundColor Gray
}
```

**Classification Variables:**

```powershell
# Bug indicators (check in this order)
$bugKeywords = @(
    "not working", "broken", "error", "failing", "incorrect", 
    "blank", "missing", "discrepancy", "mismatch", "null", 
    "crash", "timeout", "failed", "exception", "issue"
)

# Task indicators
$taskKeywords = @(
    "setup", "configure", "new fund", "new portfolio", 
    "add", "please review", "enhancement", "investigate"
)

# Check email + investigation for bug keywords
$isBug = $false
foreach ($keyword in $bugKeywords) {
    if ($emailBody -match $keyword -or $investigationReport -match $keyword) {
        $isBug = $true
        Write-Host "🐛 Classified as BUG (found keyword: '$keyword')" -ForegroundColor Red
        break
    }
}

# Check screenshots for error indicators
if ($screenshotAnalysis -match "error|blank|red highlight|missing|incorrect") {
    $isBug = $true
    Write-Host "🐛 Classified as BUG (screenshot shows error/missing data)" -ForegroundColor Red
}

# If not bug, check for task indicators
if (-not $isBug) {
    foreach ($keyword in $taskKeywords) {
        if ($emailBody -match $keyword) {
            Write-Host "📋 Classified as TASK (found keyword: '$keyword')" -ForegroundColor Cyan
            break
        }
    }
}

# Parent User Story (HARDCODED to #86322 - CAMOS BAU Support)
$parentUserStory = "86322"  # ALWAYS use CAMOS BAU Support 08.26a

# Parent is ALWAYS #86322 for this skill
Write-Host "✅ Parent User Story: #86322 (CAMOS BAU Support 08.26a)" -ForegroundColor Green
Write-Host "   Email folder: C:\source\MD\AdminTools\email-workitem\" -ForegroundColor Cyan

Write-Host "✅ Work Item Type: $workItemType" -ForegroundColor Green
```

**Attachments uploaded:**
```powershell
# Upload investigation report
$reportAttachment = az boards attachment upload `
    --file-path "C:\source\MD\AdminTools\Output\CashReconciliation_TrestlesCLO_20260728.md"

# Upload original email
$emailAttachment = az boards attachment upload `
    --file-path "C:\source\Outlook\Archive\Re Trestles CLO...eml"

# Upload screenshot
$screenshotAttachment = az boards attachment upload `
    --file-path "C:\source\MD\AdminTools\Output\Attachments\image001.png"

# Link all attachments to task
az boards work-item relation add --id $taskId --relation-type "AttachedFile" --target-id $reportAttachment
az boards work-item relation add --id $taskId --relation-type "AttachedFile" --target-id $emailAttachment
az boards work-item relation add --id $taskId --relation-type "AttachedFile" --target-id $screenshotAttachment
```

### Archive Management (MANDATORY - AUTOMATIC)

**CRITICAL:** Archival is **MANDATORY** and happens **AUTOMATICALLY** after **EVERY** processing attempt, regardless of success or failure.

**🔒 IMPORTANT:** We **MOVE the ORIGINAL .eml file** (not a copy) from `emails/` to `Archive/` folder.

**⚠️ REQUIREMENT - ALWAYS ARCHIVE:** Every email in `emails/` folder **MUST** be moved to `Archive/` after processing attempt to prevent re-processing on subsequent runs. This applies to:
- ✅ Successfully processed emails (task created)
- ✅ Emails that don't qualify for processing (no investigation needed)
- ✅ Emails where task creation failed (Azure CLI errors, etc.)
- ✅ Emails with parsing errors or incomplete data
- ✅ **ALL emails - NO EXCEPTIONS**

**Duplicate Handling:** Before moving emails to Archive/, check if files already exist:
- **DELETE existing duplicates** from Archive/ first (they were already processed)
- This prevents "file already exists" errors when moving newly processed emails
- Ensures emails/ folder gets emptied after EVERY run

**When archival happens:**
- ✅ **AUTOMATICALLY after EVERY email processing attempt**
- ✅ **MOVES original .eml file** from `emails/` to `Archive/` immediately
- ✅ Archive/ folder becomes **permanent storage** of all processed emails
- ✅ Prevents duplicate processing (file no longer in emails/ folder)
- ✅ No user action required

**NO EXCEPTIONS:** There are **NO scenarios** where emails remain in `emails/` folder. After processing, `emails/` folder **MUST BE EMPTY**.

```powershell
# AUTOMATIC archival after EVERY processing attempt (MANDATORY - NO EXCEPTIONS)
$sourcePath = "C:\source\Outlook\emails\$emailFileName"
$destPath = "C:\source\Outlook\emails\Archive\$emailFileName"

# Check if file already exists in Archive (prevent "file already exists" error)
if (Test-Path $destPath) {
    Write-Host "⚠️  File already exists in Archive: $emailFileName" -ForegroundColor Yellow
    Write-Host "   → Removing duplicate from Archive first..." -ForegroundColor Gray
    Remove-Item $destPath -Force
}

# ALWAYS MOVE (not copy) the ORIGINAL email file to Archive - NO EXCEPTIONS
Move-Item $sourcePath -Destination "C:\source\Outlook\emails\Archive\" -Force

if ($taskCreated -and $taskId) {
    Write-Host "✅ Archived ORIGINAL (task created successfully): $emailFileName" -ForegroundColor Green
    Write-Host "   → ADO Task: #$taskId" -ForegroundColor Gray
    Write-Host "   → Moved to: C:\source\Outlook\emails\Archive\$emailFileName" -ForegroundColor Gray
} else {
    Write-Host "✅ Archived ORIGINAL (no task created - prevents re-processing): $emailFileName" -ForegroundColor Yellow
    Write-Host "   → Reason: Task creation skipped/failed, but email archived to prevent duplicate processing" -ForegroundColor Gray
    Write-Host "   → Moved to: C:\source\Outlook\emails\Archive\$emailFileName" -ForegroundColor Gray
    Write-Host "   → Note: Investigate report still generated in Output/ folder if applicable" -ForegroundColor Cyan
}

# Verify archive at end of batch processing (emails/ MUST be empty)
$remainingEmails = Get-ChildItem "C:\source\Outlook\emails\*.eml"
if ($remainingEmails.Count -eq 0) {
    Write-Host "✅ All emails archived - emails/ folder is EMPTY (CORRECT)" -ForegroundColor Green
} else {
    Write-Host "❌ CRITICAL: $($remainingEmails.Count) email(s) remain in emails/ folder" -ForegroundColor Red
    Write-Host "   → THIS SHOULD NOT HAPPEN - ALL emails must be archived" -ForegroundColor Red
    Write-Host "   → Check archival logic - emails will be re-processed on next run" -ForegroundColor Yellow
}

$archivedEmails = Get-ChildItem "C:\source\Outlook\emails\Archive\*.eml"
Write-Host "📁 Archive contains $($archivedEmails.Count) ORIGINAL email(s)" -ForegroundColor Cyan
```

**Archive structure (ORIGINAL email files moved here):**
```
C:\source\Outlook\emails\Archive\
├── Push Balances and Transactions to Aristotle DW _ 7_1–7_27.eml  [ORIGINAL]
├── RE Push Balances and Transactions to Aristotle DW _ 7_1–7_27.eml  [ORIGINAL]
├── Re Important Solvas not feeding MOS Portal - Seniority, Maturity.eml  [ORIGINAL]
└── Re Trestles CLO 3, 4, 9 & 10 – Push Transactions & Balances to Aristotle DW.eml  [ORIGINAL]
```

**Retention:** Archive folder is **permanent storage of ALL processed email files** (ORIGINAL .eml files, NOT copies). This includes:
- Emails that created ADO tasks successfully
- Emails that didn't qualify for processing (no investigation needed)
- Emails where task creation failed (manual intervention needed)

**Why archive everything:** Prevents duplicate processing on subsequent runs. Once an email is in Archive/, it will never be scanned again, even if task creation failed. Investigation reports remain in Output/ folder for review.

### Error Handling

**Email parsing failure:**
```
❌ Email 2: Failed to parse "corrupted_email.eml"
   Error: MIME parsing exception
   Action: Skipped (investigate manually)
```

**Screenshot analysis failure:**
```
⚠️  Email 3: Screenshot download failed
   File: image.png (404 not found)
   Action: Investigation continues WITHOUT screenshot analysis
   Quality Gate: May FAIL if screenshot was critical
```

**Mossy investigation error:**
```
❌ Email 4: Investigation failed
   Skill: check-cash-reconciliation
   Error: Database connection timeout
   Action: Investigation report NOT created
   Quality Gate: ❌ FAIL - Task NOT created
   Manual Action: Re-run investigation when database is available
```

**Quality gate failure (insufficient context):**
```
⚠️  Email 5: Quality gate FAILED
   Reason: Investigation found no actionable findings
   Investigation Status: ✅ Complete (report saved)
   Task Creation: ❌ SKIPPED (not enough context)
   Archival: ❌ SKIPPED (email remains in emails/ folder for manual review)
   Manual Action: Review investigation report, add findings, create task manually if needed
```

**Archival behavior:**
```
✅ Email 1-3: Successfully processed
   └─ Tasks created: #86445, #86446, #86447
   └─ Archival: ✅ AUTOMATIC (moved to Archive/)
   └─ Status: Designated folder is now empty

❌ Email 4: Processing failed
   └─ Task creation: Failed
   └─ Archival: ❌ SKIPPED
   └─ Status: Email remains in designated folder
   └─ Next run: Will automatically retry this email
```

### Success Metrics

**Per email processed:**
- ✅ Email body extracted completely
- ✅ Email classified (Bug or Task)
- ✅ Time estimate calculated (2h/4h/8h)
- ✅ Work item created under User Story #86322
- ✅ Work item assigned to user who invoked skill
- ✅ **ORIGINAL email file AUTOMATICALLY moved to Archive (mandatory after successful task creation)**

**Overall workflow:**
- ✅ All .eml files in designated folder processed
- ✅ Summary report generated
- ✅ **Designated folder empty (all successfully processed ORIGINAL emails AUTOMATICALLY moved to Archive/)**
- ✅ **Any failed emails remain in folder for retry (original files not moved)**
- ✅ ADO tasks created with parent #86322
- ✅ **Archive/ folder contains ORIGINAL processed email files (permanent storage, NOT copies)**

### Troubleshooting

**"Parent link not showing on created work item"**
- Root cause: `--fields "System.Parent=86322"` doesn't work in Azure DevOps CLI
- Solution: Must use two-step process:
  1. Create work item first
  2. Add parent relation: `az boards work-item relation add --id <WORK_ITEM_ID> --relation-type parent --target-id 86322`
- This is already implemented in the skill (v2.3+)
- Verify parent: Check work item in ADO - should show "Parent: User Story #86322"

**"No emails found in emails/ folder"**
- Check: `Get-ChildItem C:\source\Outlook\emails\*.eml`
- Solution: Place .eml files in the folder first

**"Task creation failed - output suppressed"**
- Azure CLI may suppress output in some contexts
- Check task creation manually: `az boards work-item show --id <TASK_ID>`
- Fallback: Create tasks manually using investigation reports

**"Quality gate failed - no context"**
- Review investigation report in Output/ folder
- Check if database queries returned results
- Verify screenshot analysis extracted useful data
- If valid issue, create task manually with additional context

**"Archive folder already has these files"**

This should NOT happen because archival MOVES (not copies) the original file immediately after task creation. If you see this error:

```powershell
# Check what ORIGINAL files are in Archive
Get-ChildItem "C:\source\Outlook\Archive\*.eml" | Select-Object Name, LastWriteTime

# If emails were already processed, the ORIGINAL files should already be in Archive
# and should NOT exist in emails/ folder anymore

# Do NOT clear Archive - it contains your ORIGINAL email files (permanent record)

# Instead, check if emails in emails/ folder are duplicates:
Get-ChildItem "C:\source\Outlook\emails\*.eml" | Select-Object Name

# If truly duplicates (someone put them back), remove from emails/ folder:
Remove-Item "C:\source\Outlook\emails\[DUPLICATE_EMAIL].eml" -Force
```

**Note:** Archive folder contains the ORIGINAL .eml files (permanent storage). Never delete from Archive unless you're certain you want to permanently lose the original email.

### Version History

**v2.3.6 (2026-08-02)** - BATCH PROCESSING LOOP
- ✅ Processes ALL emails in folder in a single invocation
- ✅ Loops through each .eml file automatically
- ✅ Archives each email after successful processing
- ✅ Generates summary report with all work items created
- ✅ No need to run skill multiple times - processes entire batch

**v2.3.5 (2026-08-02)** - MANDATORY ITERATION INHERITANCE
- ✅ Child work items MUST inherit parent's Iteration Path
- ✅ Queries parent #86322 for Iteration Path before creating work item
- ✅ Sets `--iteration "$parentIteration"` during work item creation
- ✅ Ensures sprint alignment and proper backlog organization
- ✅ Prevents orphaned work items in wrong sprints

**v2.3.4 (2026-08-02)** - CONCISE DESCRIPTIONS (ANTI-TRUNCATION)
- ✅ Descriptions now concise to prevent Azure DevOps field truncation
- ✅ Single-paragraph format: Problem + brief context + metadata
- ✅ Keeps descriptions under 500 characters for reliability
- ✅ Full email details always available in attached .eml file
- ✅ Eliminates truncation issues while maintaining context

**v2.3.3 (2026-08-02)** - AUTOMATIC EMAIL ANALYSIS IN STEP 1
- ✅ Email analysis now AUTOMATIC during work item creation (not optional)
- ✅ Step 1 reads email, analyzes content, builds comprehensive description
- ✅ Description includes: Problem summary, root cause, affected items, resolution steps
- ✅ No separate "read and summarize" command needed - happens automatically
- ✅ Work items created with full context from the start

**v2.3.2 (2026-08-02)** - ENHANCED EMAIL PARSING & ANALYSIS
- ✅ Improved email body extraction - properly parses MIME multipart emails
- ✅ Cleans quoted-printable encoding (=92, =93, etc.)
- ✅ Extracts plain text content from complex email formats
- ✅ Smart description handling - short emails get full content, long emails get summary
- ✅ Optional post-creation analysis - can add detailed problem summary after work item created
- ✅ Verified REST API attachment upload working correctly

**v2.3.1 (2026-08-02)** - ENHANCED CONTEXT & ATTACHMENTS
- ✅ Full email body extracted and included in work item description
- ✅ Comprehensive description format: From, Date, Subject, Full Body, Next Steps
- ✅ Original .eml file uploaded as attachment (complete email with headers)
- ✅ Three-step work item creation: Create → Add Parent → Upload Attachment

**v2.3 (2026-08-02)** - CAMOS BAU SUPPORT SPECIFIC
- ✅ Hardcoded parent to User Story #86322 (CAMOS BAU Support 08.26a)
- ✅ Automatic designated folder checking (no user input needed)
- ✅ Simplified workflow - no investigation routing to other skills
- ✅ **Fixed parent link creation**: Two-step process using `az boards work-item relation add`
- ✅ Auto-assignment to user who invoked skill
- ✅ Time estimation (2h/4h/8h based on complexity)
- ✅ Bug vs Task classification
- ✅ Automatic archival to Archive\ subfolder

**v2.0 (2026-07-28)** - AUTOMATED WORKFLOW ADDED
- ✅ Complete email-to-task automation
- ✅ Screenshot analysis with AI vision
- ✅ Quality gates for task creation
- ✅ **MANDATORY automatic archiving: MOVES ORIGINAL .eml files after successful task creation**
- ✅ Archive prevents duplicate processing (original files moved immediately, not copied)
- ✅ Archive/ folder is permanent storage of original processed emails
- ✅ Failed emails remain in emails/ folder for automatic retry (originals not moved)
- ✅ Multi-user story support
- ✅ Investigation report generation
- ✅ Error handling and fallbacks

**v1.0 (2026-07-28)** - Initial Release
- Basic email retrieval via Microsoft Graph
- Search functionality
- Manual export to files

---

**Status:** ✅ Production Ready  
**Version:** 2.0 (Automated Workflow)  
**Last Updated:** 2026-07-28
