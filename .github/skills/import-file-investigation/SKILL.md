# Import File Investigation Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration

**Purpose:** Investigate missing import files, locate source folders, verify file delivery, and distinguish between import failures vs vendor delivery failures. Enhanced with file delivery log screenshot analysis and SFTP configuration screenshots.

**Use When:**
- User asks about missing files for an import job
- Need to find where files should be delivered (source folder/SFTP location)
- Troubleshooting "DSE" (Data Source Error/Exception) issues
- Vendor files not arriving
- Import jobs failing due to missing files
- Need to verify file delivery patterns

---

## Phase 0: Analyze File Delivery Screenshots and Wiki

**Step 0.1: Screenshot Analysis**
```powershell
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - File delivery log screenshots showing timestamps, statuses
# - SFTP folder screenshots showing directory structure
# - Error screenshots from file processing failures
# - Vendor delivery confirmation emails
```

**Step 0.2: Fetch Wiki Documentation**
```powershell
$wikiPath = "/Vendor-File-Delivery-Locations"  # Update with actual path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_FileDelivery.md" -Encoding UTF8
```

## Phase 1: Identify the Import Job Configuration

### Query Import Job Details

```sql
-- Find import job by name, client, or keyword
SELECT 
    GenericImportJobID,
    Name,
    SourceFolder,
    FileName,
    ArchiveLocation
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1  -- Active jobs only
    AND (
        Name LIKE '%[keyword]%' 
        OR SourceFolder LIKE '%[keyword]%'
    )
ORDER BY Name
```

**Key Fields:**
- `SourceFolder`: Where files should be delivered (pickup location)
- `FileName`: File name pattern to match (wildcards allowed)
- `ArchiveLocation`: Where processed files are moved
- `GenericImportJobID`: Job ID for tracking execution history

**Common Patterns:**
- USBank files: `\\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\[Client]\USBank`
- ICE files: `\\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\ICE`
- LSEG/Markit: Various vendor-specific paths

---

## Phase 2: Verify File Delivery

### Check Source Folder for Expected Files

```powershell
# Check if folder is accessible
$folder = "[SourceFolder from query]"
if (Test-Path $folder) {
    Write-Host "✅ Folder accessible" -ForegroundColor Green
} else {
    Write-Host "❌ Folder not accessible - check permissions/path" -ForegroundColor Red
}

# Look for specific files
Get-ChildItem $folder -Filter "[FilePattern]" | 
    Select-Object Name, LastWriteTime, @{N='SizeMB';E={[math]::Round($_.Length/1MB,2)}} | 
    Format-Table -AutoSize

# Check recent files (last 7 days)
Get-ChildItem $folder -Filter "[FilePattern]" | 
    Where-Object {$_.LastWriteTime -gt (Get-Date).AddDays(-7)} | 
    Sort-Object LastWriteTime -Descending | 
    Format-Table -AutoSize
```

### Check Archive for Last Successful Delivery

```powershell
# Check archive location for last processed files
$archive = "[ArchiveLocation from query]"
Get-ChildItem $archive -Filter "[FilePattern]" -Recurse | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 10 | 
    Format-Table Name, LastWriteTime, @{N='SizeMB';E={[math]::Round($_.Length/1MB,2)}} -AutoSize
```

---

## Phase 3: Check Import Execution History

### Query Recent Import Executions

**Note:** The execution history table structure varies. Common approaches:

```sql
-- Check for execution tracking views
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME LIKE '%Execution%' 
    OR TABLE_NAME LIKE '%Import%History%'
    OR TABLE_NAME LIKE '%Run%'
ORDER BY TABLE_NAME
```

### Check SSIS Package Execution

If import uses SSIS packages, check execution logs:

```sql
-- Recent SSIS executions (SQL Server 2012+)
SELECT TOP 20
    execution_id,
    folder_name,
    project_name,
    package_name,
    created_time,
    status,
    CASE status
        WHEN 1 THEN 'Created'
        WHEN 2 THEN 'Running'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'Failed'
        WHEN 5 THEN 'Pending'
        WHEN 6 THEN 'Ended Unexpectedly'
        WHEN 7 THEN 'Succeeded'
        WHEN 8 THEN 'Stopping'
        WHEN 9 THEN 'Completed'
    END AS StatusDescription
FROM SSISDB.catalog.executions
WHERE package_name LIKE '%[JobName]%'
ORDER BY created_time DESC
```

---

## Phase 4: Root Cause Determination

### Decision Tree

```
Is the source folder accessible?
├─ NO → Check network path, permissions, server availability
└─ YES
    │
    Are files present in source folder?
    ├─ NO → **VENDOR DELIVERY FAILURE**
    │       - Contact vendor/custodian
    │       - Verify SFTP credentials
    │       - Check delivery schedule
    │       - Review vendor connectivity
    │
    └─ YES
        │
        Are files in archive?
        ├─ YES → **FILES ALREADY PROCESSED**
        │        - Check import execution logs
        │        - Verify data in database
        │        - Check if job ran successfully
        │
        └─ NO → **IMPORT FAILURE**
                - Check SSIS logs
                - Review file format/schema
                - Check for validation errors
                - Review error messages in Seq logs
```

### Common Issue Categories

**1. Vendor Delivery Failure** (Most Common)
- Symptoms: Source folder empty or only old files present
- Root Cause: Vendor not sending files
- Resolution: Contact vendor, verify SFTP setup, check schedules

**2. Import Job Not Running**
- Symptoms: Files in source folder, not in archive
- Root Cause: SSIS job disabled, scheduled incorrectly, or service down
- Resolution: Check job schedule, enable job, restart services

**3. Import Validation Failure**
- Symptoms: Files in source folder, error in logs
- Root Cause: Schema mismatch, bad data, format issues
- Resolution: Review error logs, fix file format, update import logic

**4. File Pattern Mismatch**
- Symptoms: Files exist but don't match pattern
- Root Cause: Vendor changed naming convention
- Resolution: Update `FileName` pattern in `tGenericImportJob`

---

## Phase 5: Report Findings

### Standard Report Structure

```markdown
## Investigation Results: [Job Name]

**Issue:** [Brief description]

**Import Job Configuration:**
- Job Name: [Name]
- Job ID: [GenericImportJobID]
- Source Folder: `[SourceFolder]`
- File Pattern: `[FileName]`
- Archive Location: `[ArchiveLocation]`

**File Check Results:**
- ❌/✅ Source folder accessible
- ❌/✅ Files present for [date]
- ❌/✅ Files in archive

**Root Cause:** [Category from decision tree]

[Evidence details]

**Resolution Steps:**
1. [Action item 1]
2. [Action item 2]
3. [Action item 3]
```

---

## Common SQL Queries Reference

### Find All Import Jobs for a Client

```sql
SELECT 
    GenericImportJobID,
    Name,
    SourceFolder,
    FileName
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1
    AND SourceFolder LIKE '%[ClientName]%'
ORDER BY Name
```

### Find Jobs by File Pattern

```sql
SELECT 
    GenericImportJobID,
    Name,
    SourceFolder,
    FileName
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1
    AND FileName LIKE '%[pattern]%'
ORDER BY Name
```

### Get All Active Import Jobs

```sql
SELECT 
    GenericImportJobID,
    Name,
    SourceFolder,
    FileName,
    ArchiveLocation
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1
ORDER BY Name
```

---

## Example Investigation: USBank Holdings Files (TASK 85294)

**Issue:** Missing USBank holdings files for Sycamore (7/22/2026)

**Step 1:** Query found Job ID 2151 - "USBank Pivot Sycamore"
- Source: `\\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\Sycamore\USBank`
- Pattern: `*_Holdings*Detail*.xlsx`

**Step 2:** File check revealed:
- ✅ Folder accessible
- ❌ No files matching pattern for 7/22/2026
- ❌ No data files in last 30 days
- ⚠️ Only old files from December 2025

**Root Cause:** Vendor Delivery Failure - USBank not sending files to SFTP

**Resolution:** Contact USBank to verify delivery schedule and SFTP connectivity

---

## Best Practices

1. **Always query database first** - Don't guess folder locations
2. **Check both source and archive** - Understand full file lifecycle
3. **Look at file timestamps** - Identify when delivery stopped
4. **Verify file patterns** - Ensure wildcards match actual filenames
5. **Document evidence** - Show file counts, dates, sizes
6. **Distinguish vendor vs import issues** - Different teams handle each
7. **Post findings to ADO** - Keep stakeholders informed

---

## Troubleshooting Tips

**Folder not accessible:**
- Check if server is online
- Verify network path syntax (use UNC paths)
- Test with Test-Path in PowerShell
- Confirm user has read permissions

**Files exist but not importing:**
- Compare file name to pattern (exact match required)
- Check file extension (.xlsx vs .xlsm vs .xls)
- Look for date format issues (MM.DD.YYYY vs YYYY-MM-DD)
- Review SSIS execution logs for errors

**Archive search taking forever:**
- Use -Filter parameter to narrow search
- Limit recursion depth
- Query database instead of filesystem
- Use Select-Object -First to limit results

**Can't find execution history:**
- Table structure varies by database
- Use INFORMATION_SCHEMA to find tables
- Check SSISDB.catalog.executions for SSIS
- Review Seq logs as fallback
