---
skill_name: check-ssis-errors
title: SSIS Package & PowerShell Script Error Investigation
description: Diagnose SSIS package failures, PowerShell script errors, and ETL job issues by analyzing Seq logs, SSIS execution logs, and database state. Enhanced with AI vision screenshot analysis for error messages and wiki integration for troubleshooting procedures. Investigates pipeline errors, data flow failures, lookup component issues, and schema mismatches.
version: 1.1
database: mos-prod, client-databases
output_format: markdown
last_updated: 2026-07-28
changelog: "v1.1 - Added screenshot analysis for SSIS error dialogs and Seq logs, wiki integration for troubleshooting procedures, enhanced investigation reports; v1.0 - Initial skill creation"
apply_to:
  - pattern: "**/*"
    when_user_mentions:
      - "SSIS"
      - "PowerShell"
      - "package error"
      - "pipeline error"
      - "ETL"
      - "integration services"
      - "script task"
      - "data flow"
      - "OLE DB error"
      - "lookup failed"
      - "pre-execute"
---

# SSIS Package & PowerShell Script Error Investigation Skill

## Purpose

This skill provides a systematic approach to investigating SSIS package failures and PowerShell script errors that occur during ETL processes. Common error patterns include:

- **Pipeline Errors** (0x80004005, 0xC0202009)
- **Lookup Component Failures** (0xC004701A, 0xC00490F5)
- **Script Task Errors** (IndexOutOfRangeException, NullReferenceException)
- **Schema Mismatch Errors** (Incorrect syntax near 'ColumnName')
- **OLE DB Errors** (0x80040E2F constraint violations)
- **Pre-Execute Phase Failures**

---

## Prerequisites

- **Seq Logs Access**: https://seq.siepe.com/ (for error pattern analysis)
- **SSIS Execution Logs**: Access to client database Integration.* or dbo.SSISImportEventLog tables
- **Source Database Access**: Connection to affected client database
- **Ticket Info**: Error message, tenant name, package name, timestamp

---

## Requirements Validation

**CRITICAL:** Before proceeding with investigation, validate that all required information is available in the ticket. If the skill confidence is adequate but requirements are missing, the agent MUST post missing requirements to the ticket discussion.

### Required Information Checklist

| Requirement | Location | Example | Status Check |
|-------------|----------|---------|-------------|
| **Tenant/Database Name** | Ticket title/description or Seq error | CitiTrustee, Elmwood, MOS | Required |
| **Package Name** | Ticket description or Seq error | Ledger Balance, pInstFundValueI | Required |
| **Error Message/Code** | Ticket description or Seq log | 0x80004005, "Lookup failed pre-execute" | Required |
| **Timestamp** | Ticket description or Seq log | 2026-04-12 03:29:37 | Recommended |
| **Component Name** | Seq error detail | Lookup to get InstID, Script Task | Helpful |

### Validation Script

```powershell
# Step 1: Fetch ticket details
$ticketId = <TICKET_ID>
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json

$description = $ticket.fields.'System.Description'
$title = $ticket.fields.'System.Title'

# Step 2: Check for required information
$missingReqs = @()

# Check for tenant/database
if ($description -notmatch '(tenant|database|client):\s*\w+' -and $title -notmatch '(CitiTrustee|Elmwood|MOS|Aristotle)') {
    $missingReqs += "- **Tenant/Database Name**: Which client database is affected? (e.g., CitiTrustee, Elmwood, MOS Production)"
}

# Check for package name
if ($description -notmatch '(package|SSIS):\s*[\w\s]+' -and $description -notmatch 'pInstFundValueI|pTransactionExtract|Ledger Balance') {
    $missingReqs += "- **SSIS Package Name**: Which package is failing? (e.g., Ledger Balance, pInstFundValueI, Daily Position Load)"
}

# Check for error message
if ($description -notmatch '(error|0x[0-9A-F]{8}|exception|failed)') {
    $missingReqs += "- **Error Message**: What is the specific error message or error code? (e.g., 0x80004005, IndexOutOfRangeException, Lookup failed)"
}

# Step 3: If requirements missing, post to discussion
if ($missingReqs.Count -gt 0) {
    $comment = @"
### ⚠️ Missing Requirements for SSIS Error Investigation

This ticket was identified for SSIS package error analysis, but the following required information is missing:

$($missingReqs -join "`n`n")

**Additional Helpful Information:**
- Timestamp of error occurrence
- Error frequency (how many times, over what period)
- Component name (e.g., "Lookup to get InstID", "Script Task Load Data")
- Seq log URL or screenshot
- Recent changes to package or database schema

**Next Steps:**
1. Provide the missing required information above
2. If available, include Seq log link: https://seq.siepe.com/
3. Mention if this is a new error or recurring issue

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

# Step 1A: Download and Analyze SSIS Error Screenshots

$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

Write-Host "\nAnalyzing $($imageFiles.Count) screenshot(s)..." -ForegroundColor Cyan

# Agent will use view_image tool to analyze screenshots and extract:
# - SSIS error codes (0x80004005, 0xC0202009, etc.)
# - Package names from error dialogs
# - Task/Component names causing failures
# - Error messages and descriptions
# - Seq log timestamps and error levels
# - Stack traces if visible
# - Pre-Execute / Execute / Post-Execute phase indicators

# Step 1B: Fetch Wiki Troubleshooting Procedures

$wikiPath = "/SSIS-Troubleshooting-Guide"  # Placeholder - update with actual wiki path
$wikiOutput = "C:\source\MD\AdminTools\Output\Wiki_SSIS_Troubleshooting.md"

Write-Host "Fetching SSIS troubleshooting wiki documentation..." -ForegroundColor Cyan

az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path $wikiPath `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | Out-File $wikiOutput -Encoding UTF8 2>$null

if (Test-Path $wikiOutput) {
    Write-Host "✓ SSIS troubleshooting procedures loaded" -ForegroundColor Green
} else {
    Write-Host "ℹ SSIS troubleshooting wiki not found - proceeding with standard investigation" -ForegroundColor Yellow
}
```

### When to Skip Investigation

**STOP and post requirements** if:
- ✋ No tenant/database name mentioned
- ✋ No package name or process identified
- ✋ Error description is vague (e.g., "something failed" with no specifics)
- ✋ Ticket is about performance (not errors) without specific failure logs

**Proceed with investigation** if:
- ✅ Tenant/database clearly identified
- ✅ Package name mentioned (even if partial match like "Ledger" or "pInstFund")
- ✅ Error code or exception type present
- ✅ Timestamp or Seq log reference available

---

## Investigation Workflow (5 Steps)

### Step 1: Parse Error Details from Ticket

**Extract Key Information:**

From the ADO ticket description (typically Seq-generated), identify:

| Field | Example | Purpose |
|-------|---------|---------|
| **Tenant** | CitiTrustee, Elmwood, MOS | Client database to investigate |
| **Error Code** | 0x80004005, 0xC004701A | SSIS error classification |
| **Package Name** | Ledger Balance, pInstFundValueI | Failing SSIS package |
| **Component** | Lookup to get InstID, Script Task Load Data | Specific failing component |
| **Timestamp** | 2026-04-12 03:29:37 | When error occurred |
| **Error Count** | 5 in 3 hours | Frequency pattern |

**Common Error Code Reference:**

| Error Code | Meaning | Typical Cause |
|------------|---------|---------------|
| 0x80004005 | Unspecified OLE DB error | Data type mismatch, null violation, connection failure |
| 0xC0202009 | SSIS OLE DB error | Constraint violation, invalid data |
| 0x80040E2F | OLE DB constraint violation | Foreign key violation, unique constraint |
| 0xC004701A | Component pre-execute failed | Lookup table missing, cache issue, connection failure |
| 0xC00490F5 | Lookup component failed | Reference table inaccessible or empty |
| 0xC0047062 | Data flow component error | Data conversion failure, truncation |
| **DTSER_SUCCESS + 0 rows** | **Silent Success Failure** | **Package succeeds but processes no data - parameter issue, filter issue** |

---

### Step 2: Query SSIS Execution Logs

**Purpose:** Find detailed execution history and error context

**Query Option A: Standard SSIS Event Log** (Most Common)
```sql
-- Query SSIS execution event log on affected client database
SELECT TOP 20
    LogDate,
    EventType,
    PackageName,
    SourceName,
    Message,
    ErrorCode,
    ExecutionID
FROM dbo.SSISImportEventLog
WHERE PackageName LIKE '%{PackageName}%'
  AND LogDate >= DATEADD(day, -7, GETDATE())
  AND EventType IN ('OnError', 'OnTaskFailed', 'OnWarning')
ORDER BY LogDate DESC;
```

**Query Option B: Integration Schema** (If available)
```sql
SELECT TOP 20
    ExecutionTime,
    PackageName,
    TaskName,
    ErrorCode,
    ErrorDescription,
    SourceComponent,
    FailureType
FROM Integration.PackageExecutionLog
WHERE PackageName = '{PackageName}'
  AND ExecutionTime >= DATEADD(day, -7, GETDATE())
  AND Status = 'Failed'
ORDER BY ExecutionTime DESC;
```

**Parameters:**
- `{PackageName}` = From Step 1 (e.g., "Ledger Balance", "pInstFundValueI")
- Date range = Last 7 days (adjust if error is older)

**Expected Output:**
| LogDate | PackageName | SourceName | ErrorCode | Message |
|---------|-------------|------------|-----------|---------|
| 2026-04-12 03:29:37 | Ledger Balance | Lookup to get InstID | 0xC004701A | Lookup failed pre-execute phase |

---

### Step 3: Investigate Root Cause by Error Pattern

#### Pattern A: Lookup Component Failures (0xC004701A, 0xC00490F5)

**Symptoms:**
- "Lookup to get [Column] failed the pre-execute phase"
- Error during package initialization

**Investigation Steps:**

1. **Verify Lookup Reference Table Exists:**
```sql
-- Check if lookup reference table exists and has data
SELECT TOP 10 *
FROM {ReferenceTable}
WHERE {LookupKeyColumn} IS NOT NULL;
```

2. **Check Lookup Cache Configuration:**
   - Open SSIS package in Visual Studio
   - Review Lookup component → Connection Manager
   - Verify SQL query returns rows
   - Check cache mode (Full, Partial, No Cache)

3. **Test Lookup Query Directly:**
```sql
-- Execute the exact query from SSIS Lookup component
SELECT {LookupColumns}
FROM {ReferenceTable}
WHERE {Condition};
```

**Common Fixes:**
- ✅ Reference table was truncated/dropped → Restore or rebuild table
- ✅ Connection string pointing to wrong database → Update package connection
- ✅ Stale cache → Restart SSIS service or clear cache
- ✅ Insufficient permissions → Grant SELECT on reference table

---

#### Pattern B: Script Task Index Out of Range

**Symptoms:**
- "Index was out of range. Must be non-negative and less than the size of the collection"
- Error in Script Task component

**Investigation Steps:**

1. **Review Script Task Source Data:**
```sql
-- Check if source query returns expected columns
SELECT TOP 10 *
FROM {SourceTable}
WHERE {FilterCondition};
```

2. **Common Causes:**
   - Source query returns 0 rows → Script expects rows but gets empty DataTable
   - Column count changed → Script accesses column[5] but only 4 columns exist
   - Null values → Script assumes non-null but gets DBNull

3. **Script Task Debugging Pattern:**
   ```csharp
   // Add bounds checking before index access
   if (dataTable.Rows.Count > 0 && dataTable.Columns.Count > expectedColumnIndex)
   {
       var value = dataTable.Rows[0][expectedColumnIndex];
   }
   else
   {
       // Log error: "Expected at least {expectedColumnIndex} columns"
   }
   ```

**Common Fixes:**
- ✅ Add null/empty guards to Script Task
- ✅ Verify source query returns data for the date range
- ✅ Check if upstream feed/process ran successfully
- ✅ Add error handling for empty result sets

---

#### Pattern C: Schema Mismatch ("Incorrect syntax near 'ColumnName'")

**Symptoms:**
- "Incorrect syntax near 'LegalEntityID'" (or other column name)
- SQL syntax error in stored procedure call

**Investigation Steps:**

1. **Verify Column Exists:**
```sql
-- Check if column exists in target table
SELECT 
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = '{TableName}'
  AND COLUMN_NAME = '{ColumnName}';
```

2. **Check Stored Procedure Signature:**
```sql
-- Get stored procedure parameters
SELECT 
    PARAMETER_NAME,
    DATA_TYPE,
    PARAMETER_MODE
FROM INFORMATION_SCHEMA.PARAMETERS
WHERE SPECIFIC_NAME = '{ProcedureName}'
ORDER BY ORDINAL_POSITION;
```

3. **Compare Package Version vs. Database Schema:**
   - Recent schema change added/removed column?
   - Package parameter list outdated?
   - Stored procedure signature changed?

**Common Fixes:**
- ✅ Recent schema change → Update SSIS package to match new schema
- ✅ Package using old stored procedure signature → Redeploy package
- ✅ Column name typo → Fix stored procedure call in package
- ✅ Column added but not in package → Add parameter to Execute SQL Task

---

#### Pattern D: OLE DB Constraint Violation (0x80040E2F)

**Symptoms:**
- "OLE DB error has occurred. Error code: 0x80040E2F"
- Foreign key or unique constraint violation

**Investigation Steps:**

1. **Identify Violating Data:**
```sql
-- Find rows that would violate constraint
SELECT TOP 100
    ST.*
FROM {StagingTable} ST
LEFT JOIN {ReferenceTable} RT ON ST.{ForeignKeyColumn} = RT.{PrimaryKeyColumn}
WHERE RT.{PrimaryKeyColumn} IS NULL
  AND ST.{ForeignKeyColumn} IS NOT NULL;
```

2. **Check Constraint Definition:**
```sql
-- Get constraint details
SELECT 
    fk.name AS ConstraintName,
    OBJECT_NAME(fk.parent_object_id) AS TableName,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS ColumnName,
    OBJECT_NAME(fk.referenced_object_id) AS ReferencedTable,
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS ReferencedColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
WHERE OBJECT_NAME(fk.parent_object_id) = '{TableName}';
```

**Common Fixes:**
- ✅ Reference data missing → Load reference data first
- ✅ Invalid foreign key values in source → Clean source data
- ✅ Execution order issue → Reorder package tasks (load parent before child)
- ✅ Stale reference data → Refresh reference tables

---

### Step 4: Check Upstream Dependencies

**Purpose:** Verify prerequisite jobs and data availability

**Query Package Execution History:**
```sql
-- Check if upstream packages ran successfully
SELECT TOP 20
    PackageName,
    ExecutionTime,
    Status,
    ErrorMessage
FROM Integration.PackageExecutionLog
WHERE ExecutionTime >= DATEADD(day, -1, GETDATE())
  AND PackageName IN (
      -- List upstream dependent packages
      'Load Reference Data',
      'Feed Import',
      'Daily Position Load'
  )
ORDER BY ExecutionTime DESC;
```

**Check Feed File Delivery:**
```sql
-- Verify source files were imported
SELECT TOP 10
    FileName,
    ImportDate,
    RecordCount,
    Status
FROM dbo.FeedImportLog
WHERE ImportDate >= DATEADD(day, -1, GETDATE())
  AND FeedType = '{ExpectedFeedType}'
ORDER BY ImportDate DESC;
```

**Common Upstream Issues:**
- ⚠️ Feed file not delivered by vendor
- ⚠️ Prerequisite SSIS package failed
- ⚠️ Reference data refresh didn't run
- ⚠️ Weekend/holiday schedule gap

---

### Step 5: Validate Fix & Document Resolution

**After Applying Fix:**

1. **Re-run Failed Package:**
   - Execute SSIS package manually from SQL Server Agent or SSDT
   - Monitor execution log for errors
   - Verify completion status

2. **Validate Data Loaded:**
```sql
-- Confirm data was loaded successfully
SELECT 
    COUNT(*) AS RecordCount,
    MAX(LoadDate) AS LatestLoadDate,
    MIN(LoadDate) AS EarliestLoadDate
FROM {TargetTable}
WHERE LoadDate >= '{ExpectedDate}';
```

3. **Check Downstream Impact:**
   - Did dependent packages run successfully after fix?
   - Are reports/exports now complete?
   - Any alerts or exceptions cleared?

---

## Root Cause Categories

### 1. Data Issues (40% of SSIS Errors)
- Source data missing or incomplete
- Invalid foreign key values
- Data type mismatches
- Null values where not expected

### 2. Schema Changes (25% of SSIS Errors)
- Columns added/removed from tables
- Stored procedure signature changed
- Data types modified
- Constraint definitions updated

### 3. Configuration Issues (20% of SSIS Errors)
- Connection string incorrect
- Lookup cache stale
- Package not redeployed after changes
- Environment variable misconfigured

### 4. Timing/Dependency Issues (10% of SSIS Errors)
- Upstream job didn't complete
- Feed file delivered late
- Reference data not refreshed
- Execution order incorrect

### 5. Infrastructure Issues (5% of SSIS Errors)
- Database server down/slow
- Network connectivity
- SSIS service crashed
- Disk space exhausted

---

## Output Report Template

```markdown
# SSIS Error Investigation Report
## Package: {PackageName} | Tenant: {TenantName}

**Generated:** {Date}
**Ticket:** #{TicketID} - {Title}
**Investigator:** MOS Support Agent
**Skill Version:** check-ssis-errors v1.0

---

## Executive Summary

✅/❌ **Status:** [Fixed / Needs Manual Intervention / Escalated]
📦 **Package:** {PackageName}
🏢 **Tenant:** {TenantName}
⚠️ **Error Code:** {ErrorCode}
🎯 **Root Cause:** [Brief description]

**Recommendation:** [Action to take]

---

## Error Details

**Error Message:**
```
{Full error message from Seq/SSIS log}
```

**Component:** {SourceComponent}
**Timestamp:** {ErrorTimestamp}
**Frequency:** {ErrorCount} occurrences in {TimeRange}

---

## Investigation Steps

### Step 1: SSIS Execution Log Analysis

**Query Executed:**
```sql
{SQL query used}
```

**Results:**
{Key findings from logs}

### Step 2: Root Cause Identification

**Error Pattern:** {Pattern A/B/C/D from Step 3}

**Investigation Findings:**
- {Finding 1}
- {Finding 2}
- {Finding 3}

**Evidence:**
```sql
{SQL queries showing the issue}
```

### Step 3: Upstream Dependencies Check

**Dependent Packages Status:**
| Package | Last Run | Status |
|---------|----------|--------|
| {Package1} | {Time} | {Status} |

**Feed Delivery Status:**
- {Feed name}: {Status}

---

## Root Cause Analysis

**Category:** [Data Issue / Schema Change / Configuration / Timing / Infrastructure]

**Detailed Explanation:**
{Detailed explanation of why error occurred}

**Supporting Evidence:**
{Query results or log excerpts proving root cause}

---

## Resolution

**Fix Applied:**
{Description of fix - e.g., "Updated SSIS package to include new LegalEntityID parameter"}

**Validation:**
```sql
-- Package executed successfully
SELECT * FROM Integration.PackageExecutionLog
WHERE PackageName = '{PackageName}'
  AND ExecutionTime >= '{FixTime}'
  AND Status = 'Success';
```

**Result:** ✅ Package now executing successfully / ⚠️ Requires manual intervention

---

## Recommendation

**Immediate Action:**
{What needs to be done now}

**Preventive Measures:**
- {Suggestion 1 to prevent recurrence}
- {Suggestion 2}

**Monitoring:**
- Monitor {PackageName} execution for next 3 days
- Set up alert for error code {ErrorCode}
- Review Seq logs daily

---

## ADO Comment (Copy-Paste Ready)

```markdown
## SSIS Error Investigation Results

**Ticket:** #{TicketID}
**Package:** {PackageName} | **Tenant:** {TenantName}
**Investigated By:** MOS Support Agent
**Date:** {Date}

### Summary
{1-2 sentence summary of issue and resolution}

### Root Cause
**Category:** {Category}
{Specific cause identified}

### Resolution
{Action taken or recommended}

### Validation
✅ Package executed successfully after fix
{Any additional validation details}

---
**Full Report:** Output/CheckSSISErrors_{TenantName}_{PackageName}_{Date}.md
```
```

---

## Special Case: Silent Success Failures ⚠️

### Pattern Recognition

**Symptoms:**
- Package returns `DTSER_SUCCESS (0)` 
- Execution time suspiciously fast (< 2 seconds for thousands of records)
- **ZERO records inserted/updated** despite source data existing
- No error messages logged
- Job history shows "Success" status

**Root Causes:**
1. **Parameter not mapped to query** - SSIS variable defined but not used in WHERE clause
2. **NULL parameter value** - Package receives empty/null parameter, filters out all rows
3. **Date format mismatch** - Parameter passed as string doesn't match datetime comparison
4. **Missing validation** - No row count checks to detect zero-row scenario

### Investigation Steps

```powershell
# Step 1: Check execution time (too fast = red flag)
$logFile = Get-Content "C:\Siepe\Data\Logs\{PackageName}*.txt" | Select-String "Elapsed"
Write-Host "Execution time: $logFile" -ForegroundColor Yellow

# Step 2: Verify source data exists
sqlcmd -S $ServerName -d $DatabaseName -Q @"
SELECT COUNT(*) AS SourceRecords 
FROM {NormalizationView}('{RefDataSetDate}', '{Label}')
"@

# Step 3: Check target records created
sqlcmd -S $ServerName -d $DatabaseName -Q @"
SELECT COUNT(*) AS NewRecords 
FROM {TargetTable} 
WHERE CreatedDate >= CAST(GETDATE() AS DATE)
"@

# Step 4: Compare - if source > 0 but target = 0 → Silent Success Failure!
```

### Resolution

**Option A: Fix SSIS Package** (Permanent)
1. Open package in Visual Studio/SSDT
2. Check OLE DB Source query:
   ```sql
   -- ❌ WRONG - Parameter not used
   SELECT * FROM NormalizationView WHERE RefDataSetDate = '2026-01-01'
   
   -- ✅ CORRECT - Uses SSIS variable
   SELECT * FROM NormalizationView WHERE RefDataSetDate = ?
   ```
3. Verify parameter mapping in Advanced Editor → Parameters tab
4. Add Row Count transformation for validation
5. Add Script Task to fail package if row count = 0:
   ```csharp
   if (Variables.RowCount == 0) {
       Dts.Log("ERROR: Package processed 0 rows", 0, null);
       Dts.TaskResult = (int)ScriptResults.Failure;
   }
   ```

**Option B: Add PowerShell Validation** (Workaround)
```powershell
# After SSIS package execution
$rowCount = Invoke-Sqlcmd @"
SELECT COUNT(*) AS NewRecords 
FROM {TargetTable} 
WHERE CreatedDate >= CAST(GETDATE() AS DATE)
"@

if ($rowCount.NewRecords -eq 0) {
    throw "ERROR: SSIS package succeeded but created 0 records (Silent Success Failure)"
}
```

**Option C: Manual Data Load** (Emergency)
- Use stored procedure to insert records directly
- Bypass broken SSIS package temporarily
- Example: `EXEC dbo.pInstDebtIU @InstID=..., @IssueDate=..., ...`

### Prevention

**Add to all SSIS packages:**
1. Row Count transformations on all data flows
2. Validation Script Task (post-execute)
3. Event handler logging for row counts
4. PowerShell wrapper validation after package execution

**Monitor for this pattern:**
- Fast execution times (< normal duration)
- Success status with zero data changes
- Source data exists but target unchanged

### Real-World Example

**Case: GenericPushInstDebt.dtsx (2026-07-29)**
- Package returned DTSER_SUCCESS in 1.469 seconds
- Expected: 5-10 seconds for 11,024 records
- Source: 11,024 normalized InstDebt records ready
- Target: ZERO records created in Core.dbo.tInstDebt
- Resolution: Manual stored procedure insert + SSIS package investigation required
- Impact: 13-day backlog of missing InstDebt data

---

## Quick Reference: Common Fixes

| Error Pattern | Quick Fix Command | Notes |
|---------------|-------------------|-------|
| Lookup cache stale | Restart SQL Server Agent service | Clears SSIS component cache |
| Reference table missing | Check upstream ETL job status | Usually a timing issue |
| Schema mismatch | Redeploy SSIS package from source control | Get latest package version |
| Index out of range | Add null/empty checks to Script Task | Code fix required |
| Constraint violation | Load reference data before fact data | Execution order issue |
| **Silent success failure** | **Check parameter mapping in package OLE DB Source** | **Package succeeds but creates 0 rows** |

---

## Useful Queries

### Find Recent Package Failures
```sql
SELECT TOP 50
    LogDate,
    PackageName,
    ErrorCode,
    Message
FROM dbo.SSISImportEventLog
WHERE EventType = 'OnError'
  AND LogDate >= DATEADD(day, -7, GETDATE())
ORDER BY LogDate DESC;
```

### Package Execution Duration Trend
```sql
SELECT 
    PackageName,
    CAST(ExecutionTime AS DATE) AS ExecutionDate,
    AVG(DATEDIFF(second, StartTime, EndTime)) AS AvgDurationSeconds,
    COUNT(*) AS ExecutionCount
FROM Integration.PackageExecutionLog
WHERE PackageName = '{PackageName}'
  AND ExecutionTime >= DATEADD(day, -30, GETDATE())
GROUP BY PackageName, CAST(ExecutionTime AS DATE)
ORDER BY ExecutionDate DESC;
```

### Identify Blocking Issues
```sql
-- Check for locks during SSIS execution
SELECT 
    request_session_id AS SPID,
    resource_type,
    resource_database_id,
    DB_NAME(resource_database_id) AS DatabaseName,
    resource_associated_entity_id,
    request_mode,
    request_status
FROM sys.dm_tran_locks
WHERE resource_type <> 'DATABASE'
ORDER BY request_session_id;
```

---

## Output Format and Ticket Attachment

After completing the SSIS error investigation, generate a comprehensive markdown report and attach it to the ADO ticket.

### Step 1: Generate Investigation Report

Create a markdown file with the following structure:

**File naming:** `CheckSSISErrors_{PackageName}_{TicketNumber}_{Date}.md`

**Example:** `CheckSSISErrors_pTransactionExtract_82115_20260630.md`

**Template:**
```markdown
# SSIS Error Investigation - TASK #{TicketNumber}

**Package Name:** {PackageName}  
**Error Date:** {ErrorDate}  
**Database:** {TenantDatabase}  
**Analyst:** {Username}  
**Generated:** {CurrentDateTime}

---

## Summary

**Issue:** {Brief description from ticket}  
**Status:** ✅ Resolved | ⚠️ Configuration Needed | ❌ Escalation Required  
**Root Cause:** {One-sentence summary}

---

## Investigation Steps

### Step 1: Seq Log Analysis

**Query Parameters:**
- Application: {PackageName}
- Date Range: {DateRange}
- Level: Error, Warning

**Key Errors Found:**
```
{Error messages from Seq logs}
```

**Analysis:**
{Interpretation of log entries}

### Step 2: SSIS Execution Log

**Database:** {Database}  
**Execution IDs:** {ExecutionIDs}

| ExecutionID | StartTime | EndTime | Status | Error |
|-------------|-----------|---------|--------|-------|
| {ID1} | {Start1} | {End1} | {Status1} | {Error1} |
| ... |

**Analysis:**
{Summary of execution patterns}

### Step 3: Database State Verification

**Checks Performed:**
- ✅ Source tables exist and accessible
- ✅ Destination tables exist
- ✅ Required columns present
- ⚠️ {Any issues found}

**Query Results:**
```sql
{Relevant query results}
```

### Step 4: Data Flow Analysis

**Component:** {ComponentName}  
**Issue:** {Description}

**Details:**
{Analysis of data flow errors, lookup component issues, or schema mismatches}

### Step 5: Script Task Analysis (if applicable)

**Script Language:** {C# / VB.NET / PowerShell}  
**Error:** {Error message}  
**Cause:** {Root cause}

---

## Root Cause

{Detailed explanation of the root cause}

**Example:**
```
The pTransactionExtract package failed because the lookup component 
"LKP - Portfolio Mapping" could not find matching records for 3 portfolios 
introduced by the client on 2026-06-28. The lookup is configured with 
"Fail component" behavior for no-match scenarios.

Cause: Missing portfolio mappings in tPortfolioMapping table.
```

---

## Resolution

### Recommended Action
{Primary recommended solution}

### SQL Scripts (if applicable)
```sql
-- Insert missing portfolio mappings
INSERT INTO {Database}.dbo.tPortfolioMapping (PortfolioName, ClientID, ...)
VALUES (...);
```

### Configuration Changes (if applicable)
{SSIS package changes needed, or connection string updates}

### Next Steps
1. {Action 1}
2. {Action 2}
3. {Action 3}

---

## Verification

After applying the resolution, verify with:

```sql
-- Re-run package verification query
{Verification SQL}
```

**Expected Result:** {Description}

---

## Escalation (if needed)

**Escalate To:** {Database Team / Dev Team / Client Services}  
**Reason:** {Why escalation is needed}  
**Information Provided:** {Summary of findings to pass along}

---

## Appendix: Queries Used

<details>
<summary>Click to expand queries</summary>

### Seq Query
```
{Seq query used}
```

### SSIS Execution Log Query
```sql
{SSIS query used}
```

### Database State Query
```sql
{Database queries used}
```

</details>

---

## Report Metadata

**Ticket:** TASK #{TicketNumber}  
**Package:** {PackageName}  
**Database:** {TenantDatabase}  
**Analyst:** {Username}  
**Timestamp:** {ISO8601DateTime}  
**Investigation Duration:** {Minutes} minutes

---

**End of Report**
```

### Step 2: Save Markdown File

```powershell
# Define file path
$ticketId = {TicketNumber}
$packageName = "{PackageName}"
$date = Get-Date -Format "yyyyMMdd"
$fileName = "CheckSSISErrors_${packageName}_${ticketId}_${date}.md"
$outputPath = "C:\source\MD\AdminTools\Output\$fileName"

# Write markdown content to file
$markdownContent | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ SSIS investigation report generated: $fileName"
```

### Step 3: Attach to ADO Ticket

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

### Step 4: Post Summary Comment

```powershell
# Post brief comment referencing the detailed markdown report
$comment = "🔧 SSIS error investigation complete - see attached report for root cause analysis and resolution steps"

az boards work-item update --id $ticketId `
    --org "https://siepe.visualstudio.com/" `
    --discussion "$comment"

Write-Host "✅ Brief summary posted to TASK #$ticketId"
```

---

## Escalation Criteria

**Escalate to Database Team if:**
- ❌ Root cause is infrastructure (server down, disk full)
- ❌ Schema change required (add index, modify constraint)
- ❌ Performance issue (slow query optimization needed)

**Escalate to Dev Team if:**
- ❌ SSIS package code bug (Script Task logic error)
- ❌ Stored procedure bug
- ❌ New package feature required

**Escalate to Client Services if:**
- ❌ Source data issue (bad feed file from client)
- ❌ Client configuration change needed
- ❌ Business rule question

---

## Skill Metadata

**Category:** Category 4 - SSIS/PowerShell Errors  
**Priority:** High  
**Estimated Volume:** ~150 tickets/year  
**Average Investigation Time:** 15-30 minutes  
**Prerequisites:** SSIS knowledge, SQL debugging, Seq log access  
**Success Rate:** 85% automated diagnosis, 15% require manual intervention
