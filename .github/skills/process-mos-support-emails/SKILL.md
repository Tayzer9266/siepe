# Process MOS Support Emails and Create Tasks

**Purpose:** Automatically process .eml files from Desktop emails folder, analyze content to match to Feature 85696 user stories, invoke Mossy's investigation skills, create enriched Azure DevOps tasks with analysis attachments, then archive processed emails.

**When to Use:** 
- User asks to "process MOS support emails"
- User wants to "process emails in the emails folder"
- User requests "review new support emails and create tickets"
- User says "run Mossy on the emails and create tasks"
- Automated daily/weekly workflow to convert emails to investigated work items

**Parent Feature:** [Feature 85696 - MOS Support Agent Automation](https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/85696)

**Email Source:** `C:\Users\tcnguyen\Desktop\emails.lnk` → `C:\source\Outlook\emails\`  
**Archive Destination:** `C:\source\Outlook\emails\Archive\`

---

## Prerequisites

1. **Azure DevOps CLI Installed & Authenticated:**
   ```powershell
   az --version  # Verify installation
   az devops configure --defaults organization=https://siepe.visualstudio.com project=Siepe.Software
   az login
   ```

2. **Mossy Agent Available:**
   - Mossy agent must be configured and accessible for skill invocation
   - Mossy has access to MSSQL MCP server for database queries

3. **Email Folder Structure:**
   ```
   C:\source\Outlook\emails\          # Source folder (via Desktop shortcut)
   C:\source\Outlook\emails\Archive\  # Archive destination
   C:\source\Outlook\emails\Output\   # Investigation reports output
   ```

---

## Workflow Overview

```
┌──────────────────────────┐
│ 1. Scan Email Folder     │
│    (.eml files)          │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ 2. Parse Email Content   │
│    Extract metadata      │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ 3. Match to User Story   │
│    (8 categories)        │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ 4. Invoke Mossy Skills   │
│    Run investigation     │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ 5. Create ADO Task       │
│    + Attach analysis     │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│ 6. Archive Email         │
│    Move to Archive/      │
└──────────────────────────┘
```

---

## Step 1: Scan Email Folder for .eml Files

**Email files are dropped into:**
```
C:\source\Outlook\emails\
```

**Via Desktop shortcut:** `C:\Users\tcnguyen\Desktop\emails.lnk`

**PowerShell to list pending emails:**

```powershell
Get-ChildItem "C:\source\Outlook\emails" -Filter "*.eml" | 
    Select-Object Name, LastWriteTime, Length | 
    Format-Table -AutoSize
```

**Example output:**
```
Name                                                          LastWriteTime        Length
----                                                          -------------        ------
Push Balances and Transactions to Aristotle DW _ 7_1–7_27.eml  7/28/2026 2:15 PM   45678
Re Important Solvas not feeding MOS Portal.eml                 7/28/2026 3:42 PM   23456
```

---

## Step 2: Parse Email Content and Extract Attachments

### 2.1 Extract Full Email Body and Metadata

**.eml files use MIME format with multiple parts:**

```powershell
# Parse .eml file
$emlContent = Get-Content $emlPath -Raw

# Extract metadata
$subject = if ($emlContent -match '(?m)^Subject:\s*(.+)$') { $matches[1].Trim() }
$from = if ($emlContent -match '(?m)^From:\s*(.+)$') { $matches[1].Trim() }
$date = if ($emlContent -match '(?m)^Date:\s*(.+)$') { $matches[1].Trim() }

# Extract body (text or HTML)
# Look for Content-Type: text/plain or text/html sections
# Decode quoted-printable or base64 encoding if present
```

### 2.2 Extract Image Attachments from MIME Parts

**Support emails often contain error screenshots - these are CRITICAL context:**

```powershell
# Find MIME boundaries
if ($emlContent -match 'boundary="?([^";\s]+)"?') {
    $boundary = $matches[1]
    
    # Split by boundary
    $parts = $emlContent -split "--$boundary"
    
    foreach ($part in $parts) {
        # Check if this part is an image
        if ($part -match 'Content-Type:\s*(image/\w+)') {
            $imageType = $matches[1]
            
            # Extract filename
            if ($part -match 'filename="?([^";\r\n]+)"?') {
                $filename = $matches[1]
            }
            
            # Extract base64 data
            if ($part -match 'Content-Transfer-Encoding:\s*base64') {
                # Find base64 data block
                $base64Data = $part -replace '(?s).*?\r?\n\r?\n', '' | 
                              Where-Object { $_ -match '^[A-Za-z0-9+/=]+$' }
                
                # Decode and save
                $imageBytes = [Convert]::FromBase64String($base64Data)
                $imagePath = "C:\source\Outlook\emails\Output\Attachments\$filename"
                [IO.File]::WriteAllBytes($imagePath, $imageBytes)
                
                Write-Host "  Extracted image: $filename" -ForegroundColor Cyan
            }
        }
    }
}
```

### 2.3 Analyze Images with AI Vision

**After extracting images, analyze them:**

```typescript
// Agent workflow - use view_image tool
const extractedImages = listFiles("C:\\source\\Outlook\\emails\\Output\\Attachments");

const imageAnalysis = [];
for (const imagePath of extractedImages) {
    const analysis = await viewImage(imagePath);
    
    imageAnalysis.push({
        filename: path.basename(imagePath),
        description: analysis.description,
        errorType: detectErrorType(analysis), // SQL error, UI error, Excel error, etc.
        keyDetails: extractKeyDetails(analysis)
    });
}
```

**Image analysis adds context:**
- SQL error messages and codes
- UI element names and states
- Excel cell values and formulas
- Log file timestamps and errors
- Data values visible in screenshots

### 2.4 Quality Gate - Minimum Context Required

**Do NOT create task unless we have:**
- ✅ Full email body text (not just subject)
- ✅ All attachments extracted
- ✅ Images analyzed (if present)
- ✅ Mossy investigation completed (if skill available)

**If any of these fail, log to manual review and skip task creation.**

---

## Step 3: Feature 85696 User Story Mapping

**Feature #85696 has 8 child User Stories representing different MOS Support categories:**

| User Story | ID | Category | Keywords | Mossy Skills |
|------------|-----|----------|----------|--------------|
| **Price Exception Investigation & Resolution** | #85755 | Pricing Issues | price, pricing, Markit, LSEG, ICE, vendor, price exception, price mismatch, Solvas price, SecurityMaster, position mark, bid price | check-market-price, bulk-price-validation |
| **Cash Reconciliation Automation** | #85756 | Cash Issues | cash, balance, reconciliation, SFR, cash rec, balance mismatch, discrepancy, cash flow | check-cash-reconciliation |
| **Data Normalization & Quality Checks** | #85757 | Data Quality | normalization, mapping, data quality, missing data, validation, data integrity, CUSIP, ISIN, identifiers | (future skill) |
| **SSIS Pipeline Error Diagnosis** | #85758 | ETL Errors | SSIS, PowerShell, job failed, package error, ETL, integration services, script error, pipeline, Seq logs | check-ssis-errors |
| **Portfolio/Company Setup Verification** | #85759 | Setup Tasks | new portfolio, fund setup, account setup, onboarding, portfolio configuration, company setup | (future skill) |
| **Performance Optimization Analysis** | #85760 | Performance | slow, performance, timeout, query optimization, hanging, long running, execution plan | (future skill) |
| **Vendor File Delivery Monitoring** | #85761 | Data Feeds | feed, import, integration, vendor file, data delivery, import error, file delivery, SFTP, missing file | (future skill) |
| **Work Item Creation & Task Assignment** | #85762 | Meta/Admin | workflow, approval, stuck, task creation, assignment, escalation | (none - administrative) |

### Matching Logic

**For each email, calculate confidence score for each User Story:**

1. **Extract keywords** from email subject + body (case-insensitive)
2. **Count exact keyword matches** against each User Story's keyword list
3. **Calculate confidence:**
   - 3+ matches = 90-100% (High Confidence)
   - 2 matches = 75-89% (Medium Confidence)
   - 1 match = 60-74% (Low Confidence)
   - 0 matches = Below threshold (manual review)

4. **Select User Story with highest confidence score ≥ 60%**

5. **Create task under that User Story (not Feature #85696 directly)**

---

## Step 3: Invoke Mossy Investigation Skills

**Before creating the task, run Mossy's investigation skills to enrich the task with analysis:**

### Available Mossy Skills by User Story

| User Story | Mossy Skills to Invoke | Investigation Output |
|------------|----------------------|---------------------|
| #85755 (Price Exception) | `check-market-price` or `bulk-price-validation` | SQL query results, price comparison, discrepancy analysis |
| #85756 (Cash Reconciliation) | `check-cash-reconciliation` | Balance validation, transaction traces, reconciliation report |
| #85758 (SSIS Errors) | `check-ssis-errors` | Seq log analysis, error traces, root cause identification |
| Others | (Future skills or manual investigation) | N/A - create task without investigation |

### Mossy Invocation Pattern

```typescript
// Pseudo-code for agent workflow
const emailData = parseEml(emailFile);

// Extract full email content
const emailBody = emailData.textBody || emailData.htmlBodyAsText;
const attachments = extractAttachments(emailFile); // Images, Excel, PDFs

// Analyze images (if present)
const imageAnalysis = [];
for (const attachment of attachments.images) {
    const imagePath = saveAttachment(attachment);
    const analysis = await viewImage(imagePath);
    imageAnalysis.push({
        filename: attachment.name,
        analysis: analysis,
        errorDetected: detectErrorInImage(analysis)
    });
}

// Build comprehensive context for Mossy
const fullContext = `
Email Subject: ${emailData.subject}
From: ${emailData.from}
Date: ${emailData.date}

--- FULL EMAIL BODY ---
${emailBody}

--- ATTACHMENTS ---
${attachments.map(a => `- ${a.name} (${a.type})`).join('\n')}

--- IMAGE ANALYSIS ---
${imageAnalysis.map(img => `
Image: ${img.filename}
Analysis: ${img.analysis.description}
Error Type: ${img.errorDetected?.type || 'None'}
Key Details: ${img.errorDetected?.details || 'N/A'}
`).join('\n---\n')}
`;

// Determine matched user story
const matchedUserStory = determineUserStory(emailData.subject + ' ' + emailBody);
const mossySkill = getMossySkill(matchedUserStory);

if (mossySkill) {
    // Run Mossy investigation with FULL context
    const investigationResult = runSubagent({
        agentName: "Mossy",
        description: `Investigate ${emailData.subject}`,
        prompt: `
            Analyze this MOS support email with full context:
            
            ${fullContext}
            
            Use skill: ${mossySkill}
            
            Provide:
            1. Summary of the issue from email + screenshots
            2. Root cause analysis
            3. SQL query results (if applicable)
            4. Recommended resolution steps
            5. Markdown report suitable for task description
        `
    });
    
    // Save investigation report
    const reportPath = `C:\\source\\Outlook\\emails\\Output\\Investigation_${timestamp}.md`;
    fs.writeFileSync(reportPath, investigationResult);
    
    return {
        hasInvestigation: true,
        report: investigationResult,
        attachments: attachments,
        imageAnalysis: imageAnalysis
    };
} else {
    // No Mossy skill available - still include full email context
    console.warn(`No Mossy skill for User Story #${matchedUserStory}`);
    
    return {
        hasInvestigation: false,
        fullEmailBody: emailBody,
        attachments: attachments,
        imageAnalysis: imageAnalysis
    };
}
```

### Investigation Report Format

**Mossy generates markdown reports in this format:**

```markdown
# Investigation Report: {Email Subject}

**Date:** {Timestamp}
**Email From:** {Sender}
**Skill Used:** {Mossy skill name}
**User Story:** #{User Story ID}

---

## Email Summary

{Brief summary of the request}

---

## Investigation Steps

1. {Step 1 description}
   - SQL query executed
   - Results: ...

2. {Step 2 description}
   - Analysis performed
   - Findings: ...

---

## Root Cause Analysis

{Detailed root cause explanation}

---

## Recommended Resolution

{Actionable steps to resolve the issue}

---

## Supporting Evidence

### Query 1: {Description}
```sql
{SQL query}
```

**Results:**
{Query results formatted as table}

---

## Attachments

- Investigation_Report_{timestamp}.md (this file)
- Query_Results_{timestamp}.csv (if applicable)
```
Full Context:**

```markdown
## Email Details

**From:** {sender email} ({sender name})
**To:** mos-support@siepe.com
**Date:** {received date}
**Original Subject:** {email subject}

---

## Full Email Content

{COMPLETE email body - all text, not just summary}

{If HTML email, extract and include formatted text}

---

## Attachments Received

{For each attachment:}
### 📎 {filename}
**Type:** {file type}
**Size:** {file size}

{If image:}
**Screenshot Analysis:**
- **Error Type Detected:** {SQL error / UI error / Excel error / None}
- **Key Details Visible:** {list key information from screenshot}
- **Error Message:** "{exact error text visible}"
- **Relevant Data:** {values, IDs, dates visible in screenshot}

{If Excel file:}
**Excel File Contents:** {sheet names, data range}

---

## Mossy Investigation Summary

**Matched User Story:** #{user story ID} - {user story title}
**Skill Used:** {mossy skill name}
**Confidence:** {confidence percentage}%
**Keywords Found:** {list of matched keywords}

### Issue Summary from Email + Screenshots

{Mossy's summary combining email text + screenshot analysis}

### Investigation Findings

{Summary of Mossy's investigation - auto-generated from skill execution}
All Files to Task

**After creating the task, attach Mossy's investigation reports AND email attachments:**

```powershell
# Upload investigation report as attachment
az boards work-item relation add `
    --id $taskId `
    --relation-type AttachedFile `
    --target-id "C:\source\Outlook\emails\Output\Investigation_${timestamp}.md"

# Upload query results (if exists)
if (Test-Path "C:\source\Outlook\emails\Output\Results_${timestamp}.csv") {
    az boards work-item relation add `
        --id $taskId `
        --relation-type AttachedFile `
        --target-id "C:\source\Outlook\emails\Output\Results_${timestamp}.csv"
}

# Upload ALL extracted attachments (images, Excel, PDFs)
$attachmentFolder = "C:\source\Outlook\emails\Output\Attachments\$timestamp"
if (Test-Path $attachmentFolder) {
    Get-ChildItem $attachmentFolder -File | ForEach-Object {
        az boards work-item relation add `
            --id $taskId `
            --relation-type AttachedFile `
            --target-id $_.FullName
        
        Write-Host "  Attached: $($_.Name)" -ForegroundColor Green
    }
}
```

**Note:** Azure DevOps CLI `az boards work-item relation add` with `AttachedFile` may require REST API for file uploads. Alternative approach using REST API:

```powershell
# Upload file via REST API
$attachmentUrl = "https://siepe.visualstudio.com/Siepe.Software/_apis/wit/attachments?fileName=$filename&api-version=7.0"
$fileBytes = [IO.File]::ReadAllBytes($filePath)

$headers = @{
    "Authorization" = "Bearer $env:AZURE_DEVOPS_TOKEN"
    "Content-Type" = "application/octet-stream"
}

$uploadResponse = Invoke-RestMethod -Uri $attachmentUrl -Method POST -Body $fileBytes -Headers $headers

# Link attachment to work item
$linkUrl = "https://siepe.visualstudio.com/Siepe.Software/_apis/wit/workitems/${taskId}?api-version=7.0"
$patchDoc = @(
    @{
        op = "add"
        path = "/relations/-"
        value = @{
            rel = "AttachedFile"
            url = $uploadResponse.url
            attributes = @{
                comment = "Email attachment: $filename"
            }
        }
    }
) | ConvertTo-Json -Depth 10

Invoke-RestMethod -Uri $linkUrl -Method PATCH -Body $patchDoc -Headers $headers -ContentType "application/json-patch+json"
```

**Critical: Attach screenshots so engineers can see exactly what the user reported.** --description $enrichedDescription `
    --assigned-to "tcnguyen@siepe.com" `
    --area "Siepe.Software\Back Office SQL Engineers" `
    --fields "System.Tags=mos-support,email-automated,$skillCategory" `
    --parent $matchedUserStoryId `  # e.g., 85755 for Price Exception
    --output json
```
**Task Description Template with Investigation:**

```markdown
## Email Details

**From:** {sender email} ({sender name})
**To:** mos-support@siepe.com
**Date:** {received date}
**Original Subject:** {email subject}

---

## Email Content

{email body text}

---

## Mossy Investigation Summary

**Matched User Story:** #{user story ID} - {user story title}
**Skill Used:** {mossy skill name}
**Confidence:** {confidence percentage}%
**Keywords Found:** {list of matched keywords}

### Investigation Findings

{Summary of Mossy's investigation - auto-generated from skill execution}

### Root Cause

{Root cause identified by Mossy - if applicable}

### Recommended Resolution

{Action items from Mossy's analysis}

---

## Attachments

📎 Investigation Report: [Investigation_{timestamp}.md](path to file)
📎 Query Results: [Results_{timestamp}.csv](path to file) (if applicable)

---

## Original Email File

`C:\source\Outlook\emails\Archive\{emailFileName}.eml`
```

---

## Step 5: Attach Investigation Reports to Task

**After creating the task, attach Mossy's investigation reports:**

```powershell
# Upload investigation report as attachment
az boards work-item relation add `
    --id $taskId `
    --relation-type AttachedFile `
    --target-id "C:\source\Outlook\emails\Output\Investigation_${timestamp}.md"

# Upload query results (if exists)
if (Test-Path "C:\source\Outlook\emails\Output\Results_${timestamp}.csv") {
    az boards work-item relation add `
        --id $taskId `
        --relation-type AttachedFile `
        --target-id "C:\source\Outlook\emails\Output\Results_${timestamp}.csv"
}
```

**Note:** Azure DevOps CLI `az boards work-item relation add` with `AttachedFile` may require REST API for file uploads. Alternative approach:

```powershell
# Post investigation notes as comments instead
$investigationContent = Get-Content "C:\source\Outlook\emails\Output\Investigation_${timestamp}.md" -Raw

az boards work-item discussion create `
    --id $taskId `
    --text $investigationContent
```

---

## Step 6: Archive Processed Email

**After task creation, move email to Archive folder:**

```powershell
$sourceFile = "C:\source\Outlook\emails\$emailFileName"
$archiveFolder = "C:\source\Outlook\emails\Archive"
$archiveFile = Join-Path $archiveFolder $emailFileName

# Move email to archive
Move-Item -Path $sourceFile -Destination $archiveFile -Force

Write-Host "✅ Email archived: $archiveFile" -ForegroundColor Green
```

**Archive folder structure:**

```
C:\source\Outlook\emails\Archive\
├── Push Balances and Transactions to Aristotle DW _ 7_1–7_27.eml
├── Re Important Solvas not feeding MOS Portal.eml
└── {other processed emails}
```

---

## Step 7: Agent-Driven Workflow (No PowerShell Script)

**This workflow MUST be executed by the Mossy agent directly - PowerShell cannot invoke agents or analyze images.**

**When user invokes:**

```
@mossy process the emails
```

**Mossy's execution workflow:**

1. **Scan email folder:** List .eml files in `C:\source\Outlook\emails\`
2. **For each email:**
   - Parse full MIME structure
   - Extract complete email body
   - Extract all attachments (images, Excel, PDFs)
   - Analyze images with `view_image` tool
   - Match to User Story based on keywords
   - Check for duplicate tasks across all 8 User Stories
   - Invoke appropriate investigation skill with full context
   - **Quality Gate:** Only proceed if investigation succeeds
   - Create task with enriched description
   - Attach investigation report + all email attachments
   - Archive email to `Archive\` folder
3. **Return summary:** Tasks created, emails processed, any skipped

---

## Usage Examples

### Example 1: Process All Emails

**User command:**
```
@mossy process the emails in the emails folder and create tasks
```

**Mossy's output:**
```
Reading email folder: C:\source\Outlook\emails\
Found 2 .eml files to process

========================================
Email 1/2: Push Balances and Transactions to Aristotle DW
========================================

Extracting email content...
  ✓ Email body: 3,245 characters
  ✓ Found 2 attachments:
    - error_screenshot.png (124 KB)
    - balance_report.xlsx (45 KB)

Analyzing screenshots...
  📸 error_screenshot.png:
    - Error Type: SQL Error
    - Error Message: "Arithmetic overflow error converting IDENTITY to data type int"
    - Database: Aristotle
    - Timestamp: 2026-07-28 10:15:23

Matching to User Story...
  ✓ Matched: #85761 - Vendor File Delivery Monitoring
  ✓ Confidence: 82%
  ✓ Keywords: push, data, delivery, feed

Running Mossy investigation...
  ✓ Skill: import-file-investigation
  ✓ Analysis complete: 2 SQL queries, root cause identified
  ✓ Investigation saved: Investigation_20260728_152130.md

Creating Azure DevOps task...
  ✓ Task #85763 created under User Story #85761
  ✓ Attached: Investigation_20260728_152130.md
  ✓ Attached: error_screenshot.png
  ✓ Attached: balance_report.xlsx

✓ Email archived: Archive\Push Balances and Transactions to Aristotle DW _ 7_1–7_27.eml

========================================
Email 2/2: Re Important Solvas not feeding MOS Portal
========================================

Extracting email content...
  ✓ Email body: 1,847 characters
  ✓ No attachments

Matching to User Story...
  ✓ Matched: #85757 - Data Normalization & Quality Checks
  ✓ Confidence: 68%
  ✓ Keywords: Solvas, feed, MOS, data

Running Mossy investigation...
  ✓ Skill: data-normalization
  ✓ Analysis complete: 3 SQL queries, issue identified
  ✓ Investigation saved: Investigation_20260728_152245.md

Creating Azure DevOps task...
  ✓ Task #85764 created under User Story #85757
  ✓ Attached: Investigation_20260728_152245.md

✓ Email archived: Archive\Re Important Solvas not feeding MOS Portal.eml

========================================
Processing Complete
========================================

✅ Processed: 2 emails
✅ Created: 2 tasks (#85763, #85764)
❌ Skipped: 0 emails

All emails successfully processed and archived.
```

### Example 2: Email with Insufficient Context

**Scenario:** Email has no body, no attachments, just subject line

**Mossy's behavior:**
```
Email: "Issue with MOS"
  ⚠ Email body empty (0 characters)
  ⚠ No attachments
  ⚠ No context for investigation

❌ SKIPPED: Insufficient context - task would be useless
📝 Logged to: Output\ManualReview_20260728.txt
📧 Email NOT archived (left in folder for manual review)
```

### Example 3: Investigation Failure

**Scenario:** Cannot match to User Story or investigation skill fails

**Mossy's behavior:**
```
Email: "General question about reporting"
  ✓ Email body: 512 characters
  ⚠ Confidence: 25% (below 60% threshold)
  ⚠ No clear User Story match

❌ SKIPPED: Low confidence match - manual classification needed
📝 Logged to: Output\LowConfidence_20260728.txt
📧 Email NOT archived (left in folder for manual review)
```

---

## Key Implementation Details

### Email Parsing (.eml format)

The agent uses file reading and regex to extract fields from .eml MIME format:

```typescript
// Read .eml file
const emlContent = readFile(emlPath);

// Extract metadata
const subject = emlContent.match(/^Subject:\s*(.+)$/m)?.[1]?.trim();
const from = emlContent.match(/^From:\s*(.+)$/m)?.[1]?.trim();
const date = emlContent.match(/^Date:\s*(.+)$/m)?.[1]?.trim();

// Extract MIME boundary for multipart emails
const boundary = emlContent.match(/boundary="?([^";\s]+)"?/)?.[1];

// Split into MIME parts and extract:
// - Text/HTML body
// - Image attachments (decode base64)
// - Excel/PDF attachments
```

### User Story Confidence Scoring

```typescript
// Calculate confidence based on keyword matches in email body + subject
const keywordMatches = countKeywordMatches(emailBody + ' ' + subject, userStoryKeywords);

const confidence = 
    keywordMatches >= 3 ? 90 + Math.min(keywordMatches * 2, 10) :  // 90-100%
    keywordMatches >= 2 ? 75 :   // Medium confidence
    keywordMatches >= 1 ? 60 :   // Low confidence
    0;                           // No match

// Only create task if confidence >= 60%
```

### Duplicate Detection Across All User Stories

```powershell
# Check all 8 User Stories for existing tasks
$allUserStories = @(85755, 85756, 85757, 85758, 85759, 85760, 85761, 85762)

foreach ($userStoryId in $allUserStories) {
    $relations = az boards work-item show --id $userStoryId --query "relations" | ConvertFrom-Json
    $childLinks = $relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Forward" }
    
    foreach ($link in $childLinks) {
        $childId = $link.url -replace '.*/', ''
        $task = az boards work-item show --id $childId | ConvertFrom-Json
        $existingTasks += @{
            Id = $childId
            Title = $task.fields.'System.Title'
            ParentId = $userStoryId
        }
    }
}

# Normalize and compare
$normalizedSubject = $emailSubject -replace '^(RE|FW|Fwd):\s*', '' | ForEach-Object { $_.Trim() }
$duplicate = $existingTasks | Where-Object { 
    $_.Title.Trim() -replace '^(RE|FW|Fwd):\s*', '' -eq $normalizedSubject
}
```

---

## Troubleshooting

### Issue: Emails Not Found

**Symptom:** "No .eml files found" message

**Solutions:**
1. Check Desktop shortcut points to correct folder:
   ```powershell
   $shell = New-Object -ComObject WScript.Shell
   $shortcut = $shell.CreateShortcut("C:\Users\tcnguyen\Desktop\emails.lnk")
   $shortcut.TargetPath  # Should show C:\source\Outlook\emails
   ```

2. Verify .eml files exist:
   ```powershell
   Get-ChildItem "C:\source\Outlook\emails" -Filter "*.eml"
   ```

### Issue: Tasks Not Creating

**Symptom:** Script runs but no tasks created

**Solutions:**
1. Check Azure DevOps CLI authentication:
   ```powershell
   az account show
   az devops configure --list
   ```

2. Run in dry-run mode to see matching:
   ```powershell
   .\Process-EmailFolder-CreateTasks.ps1 -DryRun
   ```

3. Check confidence scores - may be below 60% threshold

### Issue: Mossy Investigation Not Running

**Symptom:** Tasks created but no investigation reports

**Causes:**
- User Story has no Mossy skills configured yet
- Only US #85755, #85756, #85758 have skills currently

**Solution:** Investigation is optional - tasks will still be created without it

---

## Future Enhancements

1. **Mossy Skill Integration via runSubagent**
   - Currently placeholder - needs actual Mossy invocation
   - Will use `runSubagent` tool to invoke Mossy with email context
   - Mossy returns investigation markdown for attachment

2. **Additional User Story Skills**
   - US #85757: Data normalization skill
   - US #85759: Portfolio setup validation skill
   - US #85760: Performance analysis skill
   - US #85761: Vendor file monitoring skill

3. **Email Attachment Handling**
   - Extract attachments from .eml files
   - Save to Output folder
   - Attach to ADO tasks

4. **Rich Email Parsing**
   - HTML body support
   - Multi-part MIME handling
   - Embedded images extraction

---

## Related Files

| File | Purpose |
|------|---------|
| [C:\source\Outlook\Process-EmailFolder-CreateTasks.ps1](C:\source\Outlook\Process-EmailFolder-CreateTasks.ps1) | Main automation script |
| [C:\source\MD\AdminTools\MOSSupportTaskTaxonomy.md](C:\source\MD\AdminTools\MOSSupportTaskTaxonomy.md) | Keyword-to-skill mapping reference |
| [Feature #85696](https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/85696) | Parent feature with 8 user stories |
| C:\source\Outlook\emails\ | Email source folder |
| C:\source\Outlook\emails\Archive\ | Processed emails archive |
| C:\source\Outlook\emails\Output\ | Investigation reports output |

---

## Summary

This skill enables fully automated MOS support email processing:

✅ **Automated email discovery** from Desktop emails folder  
✅ **Intelligent User Story matching** across 8 categories  
✅ **Mossy investigation integration** for enriched analysis  
✅ **Automatic task creation** under appropriate User Story  
✅ **Investigation report attachments** as task discussions  
✅ **Email archiving** to keep inbox clean  
✅ **Duplicate detection** across all User Stories  

**Result:** Zero-touch email-to-task conversion with enriched investigation data.


1. ✅ Extract emails using outlook-email-extraction skill
2. ✅ Analyze each email against MOSSupportTaskTaxonomy
3. ✅ Check for duplicates by subject line
4. ✅ Create tasks under User Story #85696 for actionable emails
5. ✅ Report summary to user

**Mossy's response template:**

```
✅ Processed MOS support emails from the last 7 days

📊 Summary:
- Total Emails: 23
- Tasks Created: 8
- Skipped (duplicates): 5
- Skipped (out of scope): 10

📝 Created Tasks:
1. #85710 - Price Exception for IMDBKLNS (Skill: bulk-price-validation, 95%)
2. #85711 - SSIS Package Failed - Daily Cash Rec (Skill: check-ssis-errors, 92%)
3. #85712 - Slow Query on Position Report (Skill: optimize-performance, 88%)
...

🔗 View all tasks: https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/85696
```

---

## Troubleshooting

### "No emails found"

**Cause:** No new emails in mos-support@siepe.com inbox

**Solution:** Check Outlook connection, verify date range

### "Duplicate tasks created for email threads"

**Cause:** Subject normalization not working properly

**Solution:** Check that RE:/FW: prefixes are being removed correctly

### "Low confidence scores for valid support requests"

**Cause:** Email uses different terminology than skill keywords

**Solution:** Update MOSSupportTaskTaxonomy.md with additional keywords

### "Azure DevOps authentication failed"

**Cause:** Not logged in to Azure DevOps CLI

**Solution:**
```powershell
az login
az devops configure --defaults organization=https://siepe.visualstudio.com project=Siepe.Software
```

---

## Advanced Configuration

### Customize Confidence Thresholds

Edit the script to adjust when tasks are created:

```powershell
# Default: Create task if confidence >= 60%
if ($highestConfidence -ge 60) { ... }

# More strict: Create only for high confidence
if ($highestConfidence -ge 80) { ... }
```

### Add Custom Skill Mappings

```powershell
$skillKeywords["custom-skill-name"] = @("keyword1", "keyword2", "keyword3")
```

### Assign to Different User

```powershell
--assigned-to "different.user@siepe.com"
```

### Add to Different Sprint

```powershell
--iteration "Siepe.Software\Sprint 2026-08"
```

---

## Integration with Existing Skills

This skill **orchestrates** other skills:

1. **outlook-email-extraction** - Retrieves emails from inbox
2. **MOSSupportTaskTaxonomy** - Provides skill keyword mappings
3. **Azure DevOps CLI** - Creates work items

---

## Success Criteria

✅ **Email Extraction:** All mos-support emails from specified time range retrieved  
✅ **Skill Matching:** 90%+ accuracy in matching emails to correct skills  
✅ **Duplicate Prevention:** No duplicate tasks created for email threads  
✅ **Task Quality:** Task descriptions contain full email context  
✅ **Traceability:** Link from task back to original email file  

---

**Status:** ✅ Ready to Use  
**Version:** 1.0  
**Last Updated:** 2026-07-28  
**Parent User Story:** [#85696](https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/85696)
