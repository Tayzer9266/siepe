---
skill_name: remove-process-dashboard-reports
title: Remove Process Dashboard Reports
description: Remove reports from the Process Dashboard (Operations Dashboard) in AdminTools using manual UI or SQL stored procedures
version: 1.1
database: mos-prod, citi-trustee-prod
output_format: markdown
apply_to:
  - pattern: "**/*"
    when_user_mentions:
      - "process dashboard"
      - "operations dashboard"
      - "delete report"
      - "remove report"
      - "dashboard report"
      - "cashflow report"
---

# Remove Process Dashboard Reports

## Purpose
This skill provides step-by-step instructions for soft-deleting reports from the Process Dashboard (Operations Dashboard) in AdminTools. The agent will execute the soft delete stored procedure after validation checks pass. Reports are marked as inactive (RefRecStatusID = 3) rather than permanently deleted, preserving audit history.

**Agent Capability:** The agent CAN and WILL execute the `[Core].[Process].[pDashboardReportD]` stored procedure to soft-delete reports after safety validation.

## When to Use This Skill

Use this skill when a ticket involves:
- Removing outdated or duplicate reports from Process Dashboard
- Cleaning up reports containing specific keywords (e.g., "Cashflow")
- Decommissioning reports after process changes
- Troubleshooting issues with incorrect dashboard configurations

**Example Ticket Keywords:**
- "Delete Cashflow reports from Operations Dashboard"
- "Remove Process Dashboard repor

**Execution Mode:** Agent will EXECUTE soft deletion after validation checks pass. This is not an investigation-only skill.t"
- "Clean up dashboard reports"
- "Decommission dashboard report"

## Required Inputs

From the ticket, extract:
1. **Database/Environment:** Which database (MOS, Citi Trustee, etc.)
2. **Report Identifier:** Report name/title or **specific** keyword pattern to match
3. **Verification Required:** Whether to report which reports will be deleted before executing

### ⚠️ Keyword Specificity Requirements

**CRITICAL:** Keywords must be specific enough to avoid accidental deletion of unrelated reports.

**Minimum Specificity Criteria:**
- Keyword must be **domain-specific** (business term, process name, report category)
- OR keyword must match fewer than **10 reports** per database
- OR keyword must be combined with additional filters (date range, creator, etc.)

**Acceptable Keywords (Domain-Specific):**
- ✅ **GOOD:** "Cashflow" (specific business process, even if 8 chars)
- ✅ **GOOD:** "Reconciliation" (specific function)
- ✅ **GOOD:** "Attribution" (specific domain term)
- ✅ **GOOD:** "Compliance" (specific category)
- ✅ **GOOD:** "Pricing" (specific process)

**Unacceptable Keywords (Too Generic):**
- ❌ **BAD:** "Report" (generic word, matches hundreds)
- ❌ **BAD:** "Daily" (generic frequency, matches many unrelated reports)
- ❌ **BAD:** "Summary" (generic type, too broad)
- ❌ **BAD:** "Data" (generic term, matches everything)
- ❌ **BAD:** "Process" (generic term, matches everything)

**Partial Match Considerations:**
- ⚠️ **CAUTION:** "Cash" (partial, may match Cash, Cashflow, Cash Reconciliation)
- ✅ **BETTER:** "Cashflow" (complete business term)

**Safety Rule:** If keyword matches > 10 reports, **STOP** and ask user to provide more specific criteria or additional filters.

## Requirements Validation

**CRITICAL:** Before proceeding with deletion, validate that all required information is available in the ticket. If the skill confidence is adequate but requirements are missing, the agent MUST post missing requirements to the ticket discussion.

### Required Information Checklist

| Requirement | Location | Example | Status Check |
|-------------|----------|---------|-------------|
| **Database/Environment** | Ticket title/description | MOS Production, Citi Trustee | Required |
| **Report Identifier** | Ticket description | "Cashflow", "Daily Reconciliation Report" | Required |
| **Scope Confirmation** | Ticket context | Delete all matching, or specific report ID | Required |
| **Verification Requested** | Ticket description | "Please confirm before deleting" | Optional |

### Validation Script

```powershell
# Step 1: Fetch ticket details
$ticketId = <TICKET_ID>
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json

$description = $ticket.fields.'System.Description'
$title = $ticket.fields.'System.Title'

# Step 2: Check for required information
$missingReqs = @()

# Check for database/environment
if ($description -notmatch '(MOS|Citi|CitiTrustee|database|environment)' -and $title -notmatch '(MOS|Citi|Operations|Process Dashboard)') {
    $missingReqs += "- **Database/Environment**: Which database should reports be removed from? (e.g., MOS Production, Citi Trustee Production)"
}

# Check for report identifier
if ($description -notmatch '(report|dashboard|title|name):\s*[\w\s]+' -and $description -notmatch 'delete|remove') {
    $missingReqs += "- **Report Identifier**: Which reports should be deleted? Please provide:\n  - Specific report name/title, OR\n  - Domain-specific keyword (e.g., \"Cashflow\", \"Reconciliation\", \"Attribution\"), OR\n  - Specific DashboardReportID(s)"
}

# Check for scope clarity
if ($description -notmatch '(all|specific|report id|\\d+)' -and $description -match 'report') {
    $missingReqs += "- **Deletion Scope**: Please clarify:\n  - Delete ALL reports matching keyword? OR\n  - Delete specific report(s) by ID? OR\n  - Delete reports matching additional criteria (date range, creator, dashboard)?"
}

# Step 3: If requirements missing, post to discussion
if ($missingReqs.Count -gt 0) {
    $comment = @"
### ⚠️ Missing Requirements for Process Dashboard Report Removal

This ticket was identified for dashboard report deletion, but the following required information is missing:

$($missingReqs -join "`n`n")

**Keyword Specificity Requirements:**
- Keywords must be domain-specific (business process terms)
- Generic words like \"Report\", \"Daily\", \"Summary\" are NOT acceptable (too broad)
- Acceptable keywords: \"Cashflow\", \"Reconciliation\", \"Attribution\", \"Compliance\", \"Pricing\"
- If keyword matches > 10 reports, you will be asked for more specific criteria

**Safety Process:**
1. Agent will first query to find matching reports
2. If > 10 reports match, agent will request more specific criteria
3. Agent will list all reports to be deleted for your review
4. Agent will execute soft deletion (reports marked inactive, not permanently deleted)

**Next Steps:**
Please provide the missing information above so the investigation can proceed.

**Skill Status:** Investigation paused until requirements are complete.
"@

    # Post comment to ticket
    az boards work-item update --id $ticketId `
        --org "https://siepe.visualstudio.com/" `
        --discussion "$comment"
    
    Write-Host "❌ Requirements validation failed. Posted missing requirements to ticket #$ticketId discussion."
    exit 1
}

Write-Host "✅ All requirements present. Proceeding with investigation..."
```

### When to Skip Investigation

**STOP and post requirements** if:
- ✋ No database/environment specified
- ✋ No report identifier or keyword provided
- ✋ Keyword is too generic ("Report", "Daily", "Summary")
- ✋ Unclear if deletion should apply to all matches or specific reports

**Proceed with investigation** if:
- ✅ Database clearly identified (MOS, Citi Trustee)
- ✅ Domain-specific keyword provided ("Cashflow", "Reconciliation", etc.)
- ✅ Scope is clear (all matching, or specific IDs)
- ✅ Ticket intent is unambiguous (delete/remove/clean up)

---

## Database Connection

### MOS Production
```
Server: mos-sql-p.mos.siepe.local,52155
Database: Core
Schema: Process
Auth: Windows Authentication
```

### Citi Trustee Production (CA)
```
Server: ca-sql-p.cititrustee.aws,52155
Database: Core
Schema: Process
Auth: Windows Authentication
```

**Important Notes:**
- Citi Trustee uses the CA (Citi Advisor) server naming convention
- The server is hosted on AWS infrastructure (`.cititrustee.aws` domain)
- Use standard port 52155 (same as MOS)
- **DO NOT** use `citi-trustee-sql-p.mos.siepe.local` - this server does not exist

**Reference:** See [MOSSystemConnectionsReference.md](../../MOSSystemConnectionsReference.md) for full connection details.

## RefRecStatusID Values

The `RefRecStatusID` field indicates the status of dashboard reports:

| RefRecStatusID | Status | Description |
|----------------|--------|-------------|
| **1** | Active | Report is currently active and visible in Process Dashboard |
| **3** | Removed/Inactive | Report has been soft-deleted or marked inactive |

**Important:**
- When searching for reports to delete, filter by `RefRecStatusID = 1` to find only **active** reports
- After deletion via `pDashboardReportD`, reports will have `RefRecStatusID = 3` (inactive/removed)
- **Do NOT count RefRecStatusID = 3 as needing deletion** - these are already removed
- Records with any RefRecStatusID value are preserved in the database for audit history
- Database query confirms only values 1 and 3 are used in production

**Example Query to Count Only Active Reports:**
```sql
-- Count ONLY active reports (RefRecStatusID = 1)
SELECT COUNT(*) AS ActiveReports
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE '%cashflow%'
  AND RefRecStatusID = 1;  -- Only active reports
```

## Investigation Steps

### Step 1: Identify Reports to Remove (WITH VALIDATION)

**Query to find reports by keyword:**
```sql
-- Find reports by title keyword
SELECT 
    DashboardReportID,
    DashboardID,
    Title,
    StatusProc,
    RefRecStatusID,
    CreatedDate,
    CreatedUser
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')  -- Case-insensitive search
  AND RefRecStatusID = 1  -- Only active reports
ORDER BY CreatedDate DESC;
```

**⚠️ VALIDATION CHECKPOINT:**

1. **Count the results:** If > 10 reports match, keyword is TOO GENERAL
2. **Review all titles:** Ensure they are all related to the deletion request
3. **Check for false positives:** Look for reports that shouldn't be deleted
4. **If unsure:** Add more specific filters or ask user for clarification

**Enhanced Query with Count Check:**
```sql
-- Check how many reports will be affected BEFORE deleting
DECLARE @MatchCount INT;

SELECT @MatchCount = COUNT(*)
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')
  AND RefRecStatusID = 1;

PRINT 'Reports matching keyword "' + '{keyword}' + '": ' + CAST(@MatchCount AS VARCHAR(10));

-- Show all matches for manual review
SELECT 
    DashboardReportID,
    DashboardID,
    Title,
    StatusProc,
    CreatedDate,
    CreatedUser
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')
  AND RefRecStatusID = 1
ORDER BY CreatedDate DESC;

-- Safety check
IF @MatchCount > 10
BEGIN
    PRINT '⚠️ WARNING: Keyword matches more than 10 reports. Please review carefully or use more specific criteria.';
END
ELSE IF @MatchCount = 0
BEGIN
    PRINT '⚠️ No reports found matching keyword "' + '{keyword}' + '".';
END
ELSE
BEGIN
    PRINT '✅ Found ' + CAST(@MatchCount AS VARCHAR(10)) + ' report(s). Safe to proceed after manual review.';
END
```

**Example for "Cashflow" reports:**
```sql
-- Step 1: Count matches first
DECLARE @MatchCount INT;
SELECT @MatchCount = COUNT(*) 
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE '%cashflow%' AND RefRecStatusID = 1;
PRINT 'Found ' + CAST(@MatchCount AS VARCHAR(10)) + ' reports matching "Cashflow"';

-- Step 2: Review all matches
SELECT 
    DashboardReportID,
    DashboardID,
    Title,
    StatusProc,
    RefRecStatusID,
    CreatedDate,
    CreatedUser
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE '%cashflow%'
  AND RefRecStatusID = 1
ORDER BY CreatedDate DESC;
```

**Expected Output:**
| DashboardReportID | DashboardID | Title | StatusProc | RefRecStatusID | CreatedDate |
|-------------------|-------------|-------|------------|----------------|-------------|
| 123 | 10 | Daily Cashflow Report | Core.Process.pGetCashflow | 1 | 2025-01-15 |
| 124 | 10 | Cashflow Summary | Core.Process.pGetCashflowSummary | 1 | 2025-02-20 |

**✅ Safety Check Passed:** Only 2 reports match (< 10 threshold)

**Document these findings in your report.**

**✅ If safety checks pass:** Proceed to Step 3 (Execute Deletion)  
**❌ If > 10 reports match:** STOP and request more specific criteria from user

---

### Step 1.5: Additional Filtering Options (If Needed)

**If keyword matches too many reports, add more specific filters:**

```sql
-- Filter by specific dashboard
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')
  AND DashboardID = {specificDashboardID}
  AND RefRecStatusID = 1;

-- Filter by creator
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')
  AND CreatedUser = '{specificUser}'
  AND RefRecStatusID = 1;

-- Filter by date range
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')
  AND CreatedDate >= '{startDate}'
  AND CreatedDate <= '{endDate}'
  AND RefRecStatusID = 1;

-- Combine multiple keywords (more specific)
WHERE (LOWER(Title) LIKE LOWER('%{keyword1}%') AND LOWER(Title) LIKE LOWER('%{keyword2}%'))
  AND RefRecStatusID = 1;
  
-- Example: Match "Daily" AND "Cashflow"
WHERE (LOWER(Title) LIKE '%daily%' AND LOWER(Title) LIKE '%cashflow%')
  AND RefRecStatusID = 1;
```

**Best Practice:** Always prefer the most specific criteria to minimize risk.

---

### Step 2: Method A - Manual Removal via AdminTools UI

**Navigation Path:**
1. Open browser to AdminTools: https://mos-tools-p.mos.siepe.local/ProcessDashboard#!/
2. Navigate to: **Editors** → **Process Dashboard**
3. Locate the report by title
4. Click **Delete Report** button
5. Confirm deletion in prompt

**Stored Procedure Called (Background):**
- UI internally calls: `Process.pProcessesIU` (saves process/report structure)

**Verification:**
```sql
-- Verify report is soft-deleted (RefRecStatusID = 3)
SELECT 
    DashboardReportID,
    Title,
    RefRecStatusID,
    CreatedDate,
    CreatedUser
FROM [Core].[Process].[tDashboardReport]
WHERE DashboardReportID = {reportId};
-- Expected: RefRecStatusID = 3 (soft-deleted, record still exists for audit)
```
Execute Soft Deletion via Stored Procedure

**AGENT EXECUTES THIS STEP** after validation passes.
---

### Step 3: Method B - SQL Removal via Stored Procedure

**For Single Report Deletion:**
```sql
-- Delete a specific dashboard report by ID
EXEC [Core].[Process].[pDashboardReportD]
    @DashboardReportID = {reportId},  -- Replace with actual DashboardReportID
    @Login = '{username}';            -- Replace with your username
```

**Example:**
```sql
EXEC [Core].[Process].[pDashboardReportD]
    @DashboardReportID = 123,
    @Login = 'SIEPE\tcnguyen';
```

**For Multiple Reports (Loop with Safety Checks):**
```sql
-- Delete multiple reports matching criteria (WITH SAFETY VALIDATION)
DECLARE @ReportID INT;
DECLARE @ReportTitle NVARCHAR(500);
DECLARE @Username VARCHAR(100) = 'SIEPE\tcnguyen';
DECLARE @TotalCount INT;
DECLARE @ProcessedCount INT = 0;

-- SAFETY CHECK 1: Count total reports
SELECT @TotalCount = COUNT(*)
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE '%cashflow%'
  AND RefRecStatusID = 1;

PRINT '═══════════════════════════════════════';
PRINT 'DELETION SAFETY CHECK';
PRINT '═══════════════════════════════════════';
PRINT 'Total reports to delete: ' + CAST(@TotalCount AS VARCHAR(10));

-- SAFETY CHECK 2: If > 10 reports, require manual review
IF @TotalCount > 10
BEGIN
    PRINT '⚠️ WARNING: More than 10 reports will be deleted!';
    PRINT '⚠️ Please review the list carefully before proceeding.';
    PRINT '⚠️ Consider using more specific criteria.';
    RETURN; -- Exit without deleting
END

IF @TotalCount = 0
BEGIN
    PRINT '⚠️ No reports found matching criteria.';
    RETURN;
END

-- SAFETY CHECK 3: List all reports that will be deleted
PRINT '';
PRINT 'Reports to be soft-deleted:';
SELECT 
    DashboardReportID,
    Title,
    CreatedDate,
    CreatedUser
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE '%cashflow%'
  AND RefRecStatusID = 1
ORDER BY CreatedDate DESC;

PRINT '';
PRINT '═══════════════════════════════════════';
PRINT 'Proceeding with soft deletion...';
PRINT '═══════════════════════════════════════';

-- Proceed with deletion
DECLARE report_cursor CURSOR FOR
SELECT DashboardReportID, Title
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE '%cashflow%'
  AND RefRecStatusID = 1;

OPEN report_cursor;
FETCH NEXT FROM report_cursor INTO @ReportID, @ReportTitle;

WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT 'Soft-deleting Report ID: ' + CAST(@ReportID AS VARCHAR(10)) + ' - ' + @ReportTitle;
    
    EXEC [Core].[Process].[pDashboardReportD]
        @DashboardReportID = @ReportID,
        @Login = @Username;
    
    SET @ProcessedCount = @ProcessedCount + 1;
    FETCH NEXT FROM report_cursor INTO @ReportID, @ReportTitle;
END;

CLOSE report_cursor;
DEALLOCATE report_cursor;

PRINT '';
PRINT '✅ Completed: ' + CAST(@ProcessedCount AS VARCHAR(10)) + ' of ' + CAST(@TotalCount AS VARCHAR(10)) + ' reports soft-deleted.';
```

---

### Step 4: Verify Soft Deletion

**Query to confirm reports are soft-deleted:**
```sql
-- Check that reports are soft-deleted (RefRecStatusID = 3)
SELECT 
    DashboardReportID,
    Title,
    RefRecStatusID,
    StatusProc,
    CreatedDate,
    CreatedUser
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')
ORDER BY CreatedDate DESC;
-- Do NOT filter by RefRecStatusID to see both active and deleted reports
```

**Expected Result:**
- Reports should have `RefRecStatusID = 3` (soft-deleted/inactive)
- Records still exist in database for audit trail
- Reports no longer appear in active dashboard views

---

## Key Stored Procedures

### Primary Soft Delete Procedure
```sql
[Core].[Process].[pDashboardReportD]
```
**Purpose:** Soft-deletes a single dashboard report by ID (sets RefRecStatusID = 3)  
**Behavior:** Marks report as inactive rather than permanently deleting  
**Parameters:**
- `@DashboardReportID` (BIGINT) - Report ID to delete
- `@Login` (VARCHAR) - Username performing the deletion

**Alternative:** `Process.pSubscriptionProcessReportD` (for subscription-specific reports)

**Important:** This is a SOFT DELETE operation that preserves audit history

### Bulk Update Procedure
```sql
[Core].[Process].[pProcessesIU]
```
**Purpose:** Inserts/Updates entire process structure (called by UI when saving)  
**Parameters:**
- `@ProcessesXml` (XML) - Serialized process/report structure
- `@Login` (VARCHAR) - Username performing the update

---

## Output Format

### Investigation Report Template

```markdown
# Process Dashboard Report Removal - Ticket #{TicketNumber}

**Date:** {Date}  
**Database:** {Database}  
**Keyword:** "{SearchKeyword}"  
**Keyword Length:** {Length} characters  
**Executed By:** {Username}

## Keyword Validation

**Specificity Check:**
- Keyword length: {Length} characters (\u2705 \u2265 8 or \u274c < 8)
- Reports matched: {Count} (\u2705 < 10 or \u26a0\ufe0f \u2265 10)
- False positives reviewed: YES \u2705 / NO \u274c
- Approval obtained: YES \u2705

**Validation Status:** \u2705 PASSED / \u274c FAILED

---

## Summary
Soft-deleted {Count} report(s) from Process Dashboard matching keyword "{Keyword}".

## Reports Identified for Removal

### Pre-Deletion Validation Query
```sql
-- Count check performed:
DECLARE @MatchCount INT;
SELECT @MatchCount = COUNT(*)
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')
  AND RefRecStatusID = 1;
-- Result: {Count} reports (Safety threshold: < 10)
```

### Reports List

| DashboardReportID | Title | StatusProc | CreatedDate | CreatedUser |
|-------------------|-------|------------|-------------|-------------|
| {ID1} | {Title1} | {Proc1} | {Date1} | {User1} |
| {ID2} | {Title2} | {Proc2} | {Date2} | {User2} |
| ... | ... | ... | ... | ... |

**Total Reports Found:** {Count}
**All Reports Reviewed:** YES \u2705
**False Positives Found:** NONE \u2705

## Removal Method
- [ ] Manual via AdminTools UI (Editors → Process Dashboard)
- [x] SQL via `Process.pDashboardReportD` stored procedure

## SQL Executed

```sql
-- Reports deleted:
{SQL statements executed}
```

## Verification Results

```sql
-- Post-deletion verification query (shows all reports including soft-deleted):
SELECT 
    DashboardReportID,
    Title,
    RefRecStatusID,
    CreatedDate,
    CreatedUser
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')
ORDER BY CreatedDate DESC;
```

**Result:** All {Count} reports show RefRecStatusID = 3 (soft-deleted)
**Active reports remaining:** 0 (when filtering by RefRecStatusID = 1)

## Status
✅ **COMPLETED** - All {Count} reports successfully soft-deleted by agent

## Execution Summary
- **Method:** Automated via stored procedure `[Core].[Process].[pDashboardReportD]`
- **Executed by:** MOS Support Agent
- **Soft Delete:** Reports marked as inactive (RefRecStatusID = 3)
- **Audit Trail:** Original records preserved in database
- **Reversible:** Reports can be reactivated if needed by updating RefRecStatusID = 1

## ADO Comment
```
Investigation completed for ticket #{TicketNumber}.

Soft-deleted {Count} Process Dashboard reports matching keyword "{Keyword}":
- Report ID {ID1}: {Title1}
- Report ID {ID2}: {Title2}
- ...

All reports verified as soft-deleted (RefRecStatusID = 3).
Audit history preserved - records still exist in database.

Stored Procedure Used: [Core].[Process].[pDashboardReportD]
Database: {Database}
```
```

---

## Example Tickets Resolved

### Ticket #82117
**Title:** "Remove Cashflow Reports from Process Dashboard"  
**Agent Execution:**
1. Validated keyword "Cashflow" (domain-specific ✅)
2. Found 3 Cashflow reports in Citi Trustee (IDs: 10, 15, 22)
3. Found 2 Cashflow reports in MOS (IDs: 45, 67)
4. Safety check: 5 reports < 10 threshold ✅
5. **EXECUTED** `Process.pDashboardReportD` for each report ID
6. Verified soft deletion via query (RefRecStatusID = 3 for all)
7. Generated investigation report with results
8. Posted results to ADO ticket

**Resolution Time:** 8 minutes (fully automated)  
**Method:** Agent executed stored procedure after validation
**Resolution Time:** 8 minutes  
**Method:** SQL stored procedure

---

##Agent validates before executing deletion:**

- [ ] Keyword is domain-specific (business term, NOT generic word like "Report", "Daily")
- [ ] Count matches ≤ 10 reports (safety threshold)
- [ ] Reviewed ALL matching reports (no false positives detected)
- [ ] Verified database/environment is correct
- [ ] Confirmed this is soft delete (RefRecStatusID = 3)
- [ ] Documented report IDs and titles in investigation report

**If ALL checks pass:** Agent EXECUTES `pDashboardReportD` stored procedure  
**If ANY check fails:** Agent STOPS and requests clarification from user

**Examples:**
- ✅ "Cashflow" - Domain-specific → Agent proceeds with execution
- ❌ "Report" - Generic term → Agent STOPS, asks for specifics
- ❌ "Daily" - Generic frequency → Agent STOPS, asks for specifics
- ⚠️ 15 reports matched → Agent STOPS (exceeds 10-report threshold), asks for more specific criteria
- ❌ "Report" - Generic term, STOP and ask for specifics
- ❌ "Daily" - Generic frequency, STOP and ask for specifics

---

## Common Issues & Troubleshooting

### Issue 0: Keyword Too General
**Symptom:** Query returns 10+ reports, some unrelated to request  
**Cause:** Keyword is too generic (e.g., "Report", "Daily", "Data", "Summary")  
**Solution:** Request domain-specific terms or add compound filters

**Examples of Generic vs. Domain-Specific:**

```sql
-- ❌ GENERIC - DO NOT USE:
WHERE LOWER(Title) LIKE '%report%'   -- Matches hundreds of unrelated reports!
WHERE LOWER(Title) LIKE '%daily%'    -- Matches daily pricing, daily NAV, daily trades, etc.
WHERE LOWER(Title) LIKE '%data%'     -- Matches everything!

-- ✅ DOMAIN-SPECIFIC - ACCEPTABLE:
WHERE LOWER(Title) LIKE '%cashflow%'         -- Specific business process (OK even alone)
WHERE LOWER(Title) LIKE '%reconciliation%'   -- Specific function
WHERE LOWER(Title) LIKE '%attribution%'      -- Specific domain term

-- ✅ COMPOUND - MORE PRECISE:
WHERE (LOWER(Title) LIKE LOWER('%daily%') AND LOWER(Title) LIKE LOWER('%Cashflow%'))  -- Generic + Domain-specific
WHERE DashboardID = 5 AND LOWER(Title) LIKE LOWER('%Cashflow%')               -- With context filter
```

**Action:** If user provides generic keyword ("Report", "Daily"), **STOP** and ask for the business process or domain term instead.

### Issue 1: Report Not Found
**Symptom:** Query returns no results for expected report  
**Cause:** Report may already be soft-deleted (RefRecStatusID = 0 or 3)  
**Solution:** Remove the `RefRecStatusID = 1` filter to see all reports including inactive ones

```sql
-- View all reports including inactive/soft-deleted:
SELECT DashboardReportID, Title, RefRecStatusID, CreatedDate
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%keyword%')
ORDER BY RefRecStatusID DESC, CreatedDate DESC;
-- RefRecStatusID = 1: Active (needs deletion)
-- RefRecStatusID = 3: Removed/Inactive (already done)
```

**Action:** Reports with RefRecStatusID = 3 are already removed and should NOT be counted as needing deletion.

### Issue 2: Foreign Key Constraint Error
**Symptom:** Cannot delete report due to FK constraint  
**Cause:** Report may have dependent records (subscriptions, actions)  
**Solution:** Check `tReportSubscription` or related tables; delete dependencies first

### Issue 3: Permission Denied
**Symptom:** Cannot execute stored procedure  
**Cause:** Insufficient database permissions  
**Solution:** Verify Windows authentication and execute permissions on `Process` schema

---

## Generate and Attach Investigation Report

After completing the report removal process, save the investigation report and attach it to the ADO ticket for documentation.

### Step 1: Save Markdown Report

```powershell
# Define file path
$ticketId = {TicketNumber}
$keyword = "{Keyword}"
$date = Get-Date -Format "yyyyMMdd"
$fileName = "RemoveProcessDashboardReports_${keyword}_${ticketId}_${date}.md"
$outputPath = "C:\source\MD\AdminTools\Output\$fileName"

# Write markdown content to file
$markdownContent | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ Investigation report generated: $fileName"
```

### Step 2: Attach to ADO Ticket

```powershell
# Upload file as attachment to ADO ticket
az boards work-item relation add `
    --id $ticketId `
    --relation-type AttachedFile `
    --target-id (az boards attachment upload --file-path $outputPath --output tsv) `
    --org "https://siepe.visualstudio.com/" `
    --output json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Report attached to TASK #$ticketId"
} else {
    Write-Host "❌ Failed to attach report to ticket"
}
```

### Step 3: Post Summary Comment

```powershell
# Post brief comment referencing the detailed markdown report
$comment = "🗑️ Dashboard report removal complete - see attached report for removed items and verification"

az boards work-item update --id $ticketId `
    --org "https://siepe.visualstudio.com/" `
    --discussion "$comment"

Write-Host "✅ Brief summary posted to TASK #$ticketId"
```

---

## Related Skills

- **check-ssis-errors:** If report deletion is related to fixing ETL pipeline issues
- **check-data-quality:** If removing duplicate/incorrect reports

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.1 | 2026-07-07 | Fixed Citi Trustee database connection (ca-sql-p.cititrustee.aws,52155); Added RefRecStatusID documentation (1=Active, 3=Removed); Clarified that RefRecStatusID=3 reports are already removed and only values 1 and 3 exist in production | System |
| 1.0 | 2026-07-06 | Initial skill creation with domain-specific keyword validation, safety thresholds, and soft delete | System |

**Safety Features:**
- Domain-specific keyword validation (business terms vs. generic words)
- Accepts: "Cashflow", "Reconciliation", "Attribution", "Compliance"
- Rejects: "Report", "Daily", "Data", "Summary"
- Match count threshold (≤10 reports)
- Pre-deletion review checklist
- Soft delete only (RefRecStatusID = 3)
- Compound filtering options
- False positive detection

---

## References

- **AdminTools URL:** https://mos-tools-p.mos.siepe.local/ProcessDashboard#!/
- **Code:** `Libraries/ProcessDashboard/ProcessDashboard.Data/ProcessProvider.cs`
- **UI:** `Applications/AdminTools/Web/Areas/ProcessDashboard/js/components/processEditor/`
- **Stored Procedure:** `[Core].[Process].[pDashboardReportD]`
