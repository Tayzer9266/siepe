---
skill_name: outlook-email-extraction
title: Outlook Email Extraction & Automated Processing
description: Extract, search, and AUTOMATE processing of Microsoft Outlook emails using Microsoft Graph API. NEW v2.0 - Complete workflow automation - parses emails, analyzes screenshots with AI vision, invokes Mossy investigations, classifies as Bug or Task, creates ADO work items with mandatory parent User Story (defaults to #85799 if no match), and archives processed emails. Quality gates ensure work items have full context before creation.
version: 2.2
output_format: text_files, json, markdown_reports, ado_bugs_and_tasks
last_updated: 2026-07-29
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

**v2.2 NEW - DEFAULT PARENT FALLBACK:** All work items automatically assigned parent User Story - defaults to #85799 (General MOS Support) if no specific category match found. Work item creation never fails due to missing parent.

**v2.1 BUG/TASK CLASSIFICATION:** Automatically determines whether issues are Bugs (broken/incorrect) or Tasks (setup/enhancement). All work items require parent User Story.

**v2.0 AUTOMATED WORKFLOW:** Complete email-to-task automation! Process MOS support emails end-to-end: parse emails → analyze screenshots → invoke Mossy investigations → classify Bug vs Task → create ADO work items with attachments → archive processed emails.

**v1.0 BASIC:** Extract Microsoft Outlook emails using Microsoft Graph API and save them to local files for:
- Finding ticket-related communications
- Verifying data push confirmations
- Searching for stakeholder requests
- Documenting email threads
- Investigating historical communications

**Output Location:** `C:\source\Outlook\`

---

## When to Use

**✅ AUTOMATED WORKFLOW (v2.0) - Use when:**
- User says **"@mossy process the emails"** or **"process the emails"**
- MOS support emails waiting in `C:\source\Outlook\emails\` folder need investigation
- Need to create ADO tasks from support emails automatically
- Want screenshot analysis + investigation + task creation all in one step

**✅ BASIC EXTRACTION (v1.0) - Use when:**
- User asks to "find email about [topic]"
- User mentions "check my inbox for [something]"
- User needs to retrieve email confirmation
- User wants to search emails by subject, sender, or date
- Investigating ticket history requires email context
- Need to document stakeholder communications (without creating tasks)

**Common Requests:**
- "Find emails from Hassan about Aristotle"
- "Search for emails about data push"
- "Get emails from last week about pricing"
- "Retrieve confirmation emails"
- "Find ticket #85164 related emails"

---

## Prerequisites

1. **Microsoft Graph PowerShell Module** - Installed automatically on first run
2. **Microsoft 365 Account** - User must have Outlook/Exchange access
3. **Permissions** - Mail.Read, Mail.ReadBasic scopes
4. **Network Access** - Internet connection to Microsoft Graph API

---

## Step 1: Initial Setup (One-Time)

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

## AUTOMATED WORKFLOW: Process MOS Support Emails (Feature #85696)

**NEW in v2.0:** Complete automated email processing workflow that parses emails, analyzes screenshots, invokes Mossy investigations, creates ADO tasks with attachments, and archives processed emails.

**🔒 CRITICAL:** Archival is MANDATORY and AUTOMATIC. After each successful task creation, the email is IMMEDIATELY moved from `emails/` to `Archive/` to prevent duplicate processing. Failed emails remain in `emails/` folder for automatic retry on next run.

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
│  1. Parse Emails (.eml files from emails/ folder)           │
│     - Extract sender, subject, body, attachments             │
│     - Download all image attachments                         │
│     - Match issue to User Story based on keywords            │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Analyze Screenshots with AI Vision                       │
│     - view_image tool on all downloaded images               │
│     - Extract error messages, data, visual context           │
│     - Document findings in investigation reports             │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Invoke Mossy Investigation Skill                         │
│     - Match to skill (cash-reconciliation, data-             │
│       normalization, etc.)                                   │
│     - Run database queries, log analysis                     │
│     - Generate investigation markdown report                 │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  4. QUALITY GATE: Check Investigation Completeness           │
│     - ✅ Full email body extracted                           │
│     - ✅ All attachments downloaded and analyzed             │
│     - ✅ Mossy investigation completed successfully          │
│     - ✅ Investigation has sufficient context                │
│     - ❌ SKIP work item creation if ANY check fails          │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Classify Work Item Type (Bug vs Task)                    │
│     - Check for bug keywords (broken, error, failing, etc.)  │
│     - Check investigation findings (data issues, failures)   │
│     - Check screenshots (error messages, blank fields)       │
│     - Default to Bug if any incorrect behavior found         │
│     - Use Task for setup/configuration/enhancement work      │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Create Azure DevOps Bug/Task (ONLY if quality passes)   │
│     - Create Bug or Task based on classification (step 5)    │
│     - REQUIRED: Parent User Story (from mapping table)       │
│     - Set priority based on issue severity                   │
│     - Upload investigation report markdown file              │
│     - Upload original .eml email file(s)                     │
│     - Upload analyzed screenshot images                      │
│     - Assign to team member                                  │
└──────────────────┬──────────────────────────────────────────┘
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Archive Processed Emails (MANDATORY - AUTOMATIC)         │
│     - AUTOMATICALLY move ORIGINAL .eml files from emails/    │
│       to Archive/ folder                                     │
│     - Happens IMMEDIATELY after successful work item creation│
│     - Prevents re-processing of same emails                  │
│     - Archive is permanent record of processed emails        │
│     - Leaves emails in place ONLY if processing failed       │
└─────────────────────────────────────────────────────────────┘
```

### User Story Mapping

Emails are automatically matched to User Stories based on keywords:

| User Story | Keywords | Investigation Skill |
|------------|----------|---------------------|
| **#85755** - Pricing Issues | price, vendor, MarkIt, ICE, LSEG, bid, pricing exception | check-market-price |
| **#85756** - Cash Reconciliation | balance, cash, reconciliation, Aristotle, push transactions, SFR | check-cash-reconciliation |
| **#85757** - Data Normalization | Solvas, normalization, mapping, seniority, maturity, spread | data-normalization |
| **#85758** - Portfolio Setup | new fund, new portfolio, setup, company setup | portfolio-setup |
| **#85759** - Data Quality | duplicate, missing, identifier, data quality | data-quality |
| **#85760** - Performance Issues | slow query, timeout, performance | performance-optimization |
| **#85761** - SSIS Errors | SSIS, package failure, ETL, pipeline error | check-ssis-errors |
| **#85762** - Import File Issues | import file, vendor file, missing file, delivery | import-file-investigation |
| **#85799** - General MOS Support | *DEFAULT* - Used when no specific category match found | (varies based on issue) |

**🔄 Parent Assignment Logic:**
1. Check email content against keyword patterns above
2. If match found → Use specific User Story (#85755-#85762)
3. If NO match found → **DEFAULT to #85799 (General MOS Support)**
4. Parent User Story is **ALWAYS assigned** - work item creation never fails due to missing parent

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

**EVERY** Bug or Task **MUST** have a parent User Story assigned. **Parent is ALWAYS assigned automatically:**

1. **Check email content** against User Story Mapping table keywords
2. **If specific match found** → Use matched User Story (#85755-#85762)
3. **If NO match found** → **Automatically defaults to #85799 (General MOS Support)**
4. **Work item creation NEVER fails** due to missing parent - #85799 catches all unmatched emails

**📊 Parent Assignment Priority:**
- Specific category match (e.g., pricing, cash reconciliation, SSIS errors) → Use specific User Story
- No category match / ambiguous / general support issue → **Default to #85799**

### Quality Gate Rules (CRITICAL)

**"If you are unable to attach an analysis then you should not even create a tasks"**  
**"The tasks does not even have enough context, if it does not have enough context don't create the tasks it will be useless"**

**Task creation ONLY happens when ALL conditions are met:**

1. ✅ **Email body fully extracted** - Not just headers
2. ✅ **All attachments downloaded and analyzed** - Screenshots processed with view_image
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

**User says:** `@mossy process the emails`

**Agent Response:**
```
Processing emails in C:\source\Outlook\emails\...

📧 Email 1: "Push Balances and Transactions to Aristotle DW"
   ├─ Category: Cash Reconciliation → User Story #85756
   ├─ Attachments: None
   ├─ Investigation: check-cash-reconciliation skill
   ├─ Classification: 📋 TASK (manual investigation, no error)
   ├─ Quality Gate: ✅ PASS (full context)
   ├─ Work Item Created: Task #85771 ✅
   └─ Archived: ✅ AUTOMATIC (moved to Archive/)

📧 Email 2: "Re Important Solvas not feeding MOS Portal - Seniority blank"
   ├─ Category: Data Normalization → User Story #85757  
   ├─ Attachments: image.png (Excel screenshot analyzed)
   ├─ Investigation: data-normalization skill
   ├─ Classification: 🐛 BUG (blank field where data expected)
   ├─ Quality Gate: ✅ PASS (screenshot + DB findings)
   ├─ Work Item Created: Bug #85769 ✅
   └─ Archived: ✅ AUTOMATIC (moved to Archive/)

📧 Email 3: "Re Trestles CLO Balance Discrepancies"
   ├─ Category: Cash Reconciliation → User Story #85756
   ├─ Attachments: image001.png (Balance dashboard analyzed)
   ├─ Investigation: check-cash-reconciliation skill
   ├─ Classification: 🐛 BUG (balance discrepancy - incorrect data)
   ├─ Quality Gate: ✅ PASS (screenshot + $328K discrepancy found)
   ├─ Work Item Created: Bug #85770 ✅
   └─ Archived: ✅ AUTOMATIC (moved to Archive/)

✅ Processing Complete
   - Emails processed: 3
   - Screenshots analyzed: 2
   - Investigations completed: 3
   - Work items created: 3 (2 Bugs, 1 Task)
     • Bug #85769 (Solvas seniority blank field)
     • Bug #85770 (Trestles balance discrepancy)  
     • Task #85771 (Aristotle DW push - manual investigation)
   - All work items have parent User Stories ✅
   - Emails AUTOMATICALLY archived: 3 → C:\source\Outlook\emails\Archive\
   - Emails/ folder: Empty (all processed successfully)

📄 Reports saved to: C:\source\MD\AdminTools\Output\
   - DataNormalization_SolvasSeniority_20260728.md
   - CashReconciliation_TrestlesCLO_20260728.md
   - CashReconciliation_PacificLife_20260728.md
   - EmailProcessing_Summary_20260728_212449.md
```

### PowerShell Implementation

**For manual invocation (not needed when using Mossy agent):**

```powershell
# Process all .eml files in emails folder
cd C:\source\MD\AdminTools
.\Process-MOSSupportEmails.ps1
```

**What it does:**
1. Scans `C:\source\Outlook\emails\` for .eml files
2. Parses each email (MIME format) - sender, subject, body, attachments
3. Downloads image attachments to `Output\Attachments\`
4. Matches email to User Story based on keyword detection
5. Invokes Mossy agent with appropriate investigation skill
6. Waits for investigation completion
7. Checks quality gates (full context, attachments analyzed, findings documented)
8. Creates ADO task ONLY if quality gates pass:
   - Sets parent User Story
   - Sets priority (High/Medium based on keywords like "blocking", "urgent")
   - Uploads investigation report .md file
   - Uploads original .eml file(s)
   - Uploads analyzed screenshot images
   - Assigns to team member (default: Tay Nguyen)
9. **AUTOMATICALLY moves ORIGINAL .eml files to Archive folder (MANDATORY)**
   - **MOVES** (not copies) the ORIGINAL email file IMMEDIATELY after successful task creation
   - Archive/ folder becomes permanent storage of processed original emails
   - Prevents duplicate processing (file no longer exists in emails/ folder)
   - Only skips move if task creation failed (so original email can be retried)
10. Generates summary report of all processing

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
# Cash Reconciliation Investigation - Trestles CLO Funds
**Email:** Re Trestles CLO 3, 4, 9 & 10 – Push Transactions & Balances to Aristotle DW
**From:** hassan@siepe.com  
**Date:** 2026-07-28  
**User Story:** #85756 (Cash Reconciliation - SFR Approval Process)

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
# Determine work item type based on classification logic
$workItemType = if ($isBug) { "Bug" } else { "Task" }

# PARENT IS REQUIRED - fail if not found
if (-not $parentUserStory) {
    Write-Error "❌ No parent User Story found for email. Cannot create work item."
    return
}

# Work item creation using Azure CLI
az boards work-item create `
    --type $workItemType `
    --title "Trestles CLO 3, 4, 9 & 10 - Balance rollover breaks ($328K discrepancy)" `
    --description "[Investigation report content]" `
    --project "Siepe.Software" `
    --area "MOS Support" `
    --iteration "Sprint 42" `
    --assigned-to "tcnguyen@siepe.com" `
    --fields "System.Parent=$parentUserStory" `
            "Microsoft.VSTS.Common.Priority=2" `
            "Microsoft.VSTS.Scheduling.OriginalEstimate=6" `
    --org "https://siepe.visualstudio.com/"
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

# Parent User Story (MANDATORY - ALWAYS assigned, defaults to #85799)
$parentUserStory = switch -Regex ($emailBody) {
    "price|vendor|MarkIt|ICE|LSEG|bid|pricing exception" { "85755"; break }
    "balance|cash|reconciliation|Aristotle|push transactions|SFR" { "85756"; break }
    "Solvas|normalization|mapping|seniority|maturity|spread" { "85757"; break }
    "new fund|new portfolio|setup|company setup" { "85758"; break }
    "duplicate|missing|identifier|data quality" { "85759"; break }
    "slow query|timeout|performance" { "85760"; break }
    "SSIS|package failure|ETL|pipeline error" { "85761"; break }
    "import file|vendor file|missing file|delivery" { "85762"; break }
    default { "85799" }  # DEFAULT: General MOS Support (no specific category match)
}

# Parent is ALWAYS assigned - never null
if ($parentUserStory -eq "85799") {
    Write-Host "⚠️  No specific category match - using DEFAULT parent" -ForegroundColor Yellow
    Write-Host "   Email subject: $emailSubject" -ForegroundColor Gray
    Write-Host "   → Parent User Story: #85799 (General MOS Support)" -ForegroundColor Cyan
} else {
    Write-Host "✅ Parent User Story: #$parentUserStory (category matched)" -ForegroundColor Green
}

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
   └─ Tasks created: #85769, #85770, #85771
   └─ Archival: ✅ AUTOMATIC (moved to Archive/)
   └─ Status: Emails/ folder is now empty

❌ Email 4: Processing failed
   └─ Task creation: Failed
   └─ Archival: ❌ SKIPPED
   └─ Status: Email remains in emails/ folder
   └─ Next run: Will automatically retry this email
```

### Success Metrics

**Per email processed:**
- ✅ Email body extracted completely
- ✅ Attachments downloaded and analyzed
- ✅ Mossy investigation completed
- ✅ Investigation report generated (always, even if task skipped)
- ✅ Task created (only if quality gate passes)
- ✅ Task has all attachments (report + email + screenshots)
- ✅ **ORIGINAL email file AUTOMATICALLY moved to Archive (mandatory after successful task creation)**

**Overall workflow:**
- ✅ All .eml files in emails/ folder processed
- ✅ Summary report generated
- ✅ **Emails/ folder empty (all successfully processed ORIGINAL emails AUTOMATICALLY moved to Archive/)**
- ✅ **Any failed emails remain in emails/ folder for retry (original files not moved)**
- ✅ Output/ folder contains all investigation reports
- ✅ ADO tasks created with full context
- ✅ **Archive/ folder contains ORIGINAL processed email files (permanent storage, NOT copies)**

### Troubleshooting

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
