# Job Resequencing Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration

## Description
Analyze ETL job schedules, dependencies, and execution patterns using **Maestro** job orchestrator and MOS execution logs to recommend optimal job sequencing. Enhanced with job workflow diagram analysis and execution timeline screenshot interpretation. Check job execution status for specific dates using PipeWatch/Dashboard stored procedures. Rebuild and resequence job workflows when timing issues or dependencies need adjustment. Calculate success rates and identify failure patterns. Integrate with SSIS error investigation when jobs fail.

**Key Capabilities:**
- **Job Status Checking:** Verify if a job ran successfully on a specific date using Dashboard.pJobResearch
- **Failure Analysis:** Find when jobs last failed, calculate success rates, and identify failure patterns
- **Execution Statistics:** Count total executions, analyze gaps, and track reliability metrics
- **Job Sequence Analysis:** Research complete job workflows including EmailAdapter → ScriptAdapter → ReportSubscription chains
- **Sequence Rebuilding:** Reorder, add, or remove jobs from sequences in Maestro configuration
- **Dependency Analysis:** Infer job dependencies from execution timing patterns
- **Performance Trending:** Analyze success rates, duration patterns, and execution anomalies
- **Error Investigation:** Integrate with check-ssis-errors skill for root cause analysis

**Job Orchestration Systems:**
- **Maestro** - Primary job scheduler at Siepe (GitHub: https://github.com/siepe-software/maestro)
- **SSIS Packages** - Logged in `Feeds.dbo.tSSISImportEventLog`
- **Solvas Loaders** - Logged in `Solvas_AM.dbo.Process_Log`
- **Generic Import Jobs** - File pickup jobs in `Feeds.dbo.vGenericImportJob`
- **PipeWatch Dashboard** - Job monitoring UI with search and timeline views

## When to Use This Skill
- User mentions "resequence", "reschedule", "update timing", "job dependencies", "rebuild sequence"
- User asks "did [job name] run on [date]?" or "check if subscription [ID] ran yesterday"
- User provides job name, subscription ID, or Report Subscription identifier
- Request to optimize job dependencies or analyze execution timing
- Investigate why a job failed or ran slow on a specific date
- Find the latest job execution status
- Calculate success rate and identify failure patterns
- Find when a job last failed or analyze failure history
- Rebuild or modify job sequences when jobs run in wrong order
- Add or remove jobs from existing sequences
- Fix timing issues or race conditions between jobs
- Verify job completion for business date reconciliation

**Common User Requests:**
- "Did the AOD CashFlow Report run on 2026-07-26?"
- "Check if subscription 500001979 ran yesterday"
- "When was the last time subscription 500001147 failed?"
- "What is the success rate for this job?"
- "Find all failures for subscription 500001311 in the last 30 days"
- "Resequence the AOD CashFlow Report to fix timing issues"
- "Why did subscription 500001311 fail on 2026-07-25?"
- "Show me the complete job sequence for subscription 500001979"

## Input Requirements

### Phase 0: Analyze Job Workflow Screenshots and Wiki

**Step 0.1: Screenshot Analysis**
```powershell
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - Job dependency diagrams showing workflow chains
# - PipeWatch timeline screenshots with execution times
# - Job sequence flowcharts
# - Error screenshots from job failures
```

**Step 0.2: Fetch Wiki Documentation**
```powershell
$wikiPath = "/Job-Orchestration-Best-Practices"  # Update with actual path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_JobOrchestration.md" -Encoding UTF8
```

**For Job Status Checking:**
- **Subscription ID** - Report Subscription ID (e.g., 500001979, 500001311) OR
- **Job Name** - Name or pattern to find subscription (e.g., "AOD CashFlow Report")
- **Target Date** (optional) - Specific date to check (default: today, format: YYYY-MM-DD)

**For Job Schedule Analysis:**
- **Job Name** - Name of the job to analyze (e.g., "MiddleOfficeTradeLoad", "Pricing", "ASSET_LOADER")
- **Job Type** (optional) - "SSIS", "Solvas", "Report Subscription", "Script Adapter", "Maestro"

**Optional Parameters:**
- **Target Date** - Specific date to analyze (default: today)
- **Dependency Analysis** - Include upstream/downstream jobs (default: yes)
- **Execution History Days** - Number of days to review (default: 7 for status checks, 30 for analysis)

---

## Quick Start Examples

### Example 1: Check Job Status for Specific Date

**User Request:**
```
"Did the AOD CashFlow Report run on 2026-07-26?"
```

**Mossy Response:**
```markdown
🔍 Checking AOD CashFlow Report status for 2026-07-26...

[Runs query to find subscription ID by name]
Found: Subscription ID 500001979

[Executes: EXEC Dashboard.pJobResearch @ReportSubscriptionID = '500001979']

✅ **Status: Success** - All jobs completed

**Job Sequence Results:**
1. ✅ EmailAdapter - AOD CashFlow Receive (06:15:00 - 06:15:30)
2. ✅ ScriptAdapter - AOD CashFlow Processor (06:16:00 - 06:18:00)
3. ✅ ReportSubscription - AOD CashFlow Report (06:19:00 - 06:22:00)
4. ✅ EmailAdapter - AOD CashFlow Send (06:22:30 - 06:23:00)

**Total Duration:** 8 minutes 30 seconds
**All steps completed successfully on 2026-07-26**
```

### Example 2: Check by Subscription ID

**User Request:**
```
"Check if subscription 500001979 ran yesterday"
```

**Mossy Response:**
```markdown
🔍 Checking subscription 500001979 status for 2026-07-26...

[Executes: EXEC Dashboard.pJobResearch @ReportSubscriptionID = '500001979']

❌ **Status: Failed** - Job sequence encountered errors

**Job Sequence Results:**
1. ✅ EmailAdapter - AOD CashFlow Receive (06:15:00 - 06:15:30)
2. ❌ ScriptAdapter - AOD CashFlow Processor (06:16:00 - FAILED)
   Error: File access denied - source file locked by another process
3. ⚪ ReportSubscription - Not executed (blocked by step 2 failure)
4. ⚪ EmailAdapter - Not executed (blocked by step 2 failure)

**Root Cause:** ScriptAdapter failed due to file locking issue

**Next Steps:**
Would you like me to investigate the ScriptAdapter error in detail using the check-ssis-errors skill?
```

### Example 3: Resequence Job

**User Request:**
```
"Resequence subscription 500001979 to fix the timing issues"
```

**Mossy Response:**
```markdown
🔄 Analyzing job sequence for subscription 500001979...

[Executes: EXEC Dashboard.pJobResearch @ReportSubscriptionID = '500001979']
[Analyzes current sequence structure and timing]

**Current Sequence Analysis:**
- Job sequence has race condition between steps 1-2
- ScriptAdapter starts immediately after EmailAdapter publish
- File validation missing - causes 15% failure rate

**Recommended Changes:**
1. Add file validation step between EmailAdapter and ScriptAdapter
2. Add 30-second delay + retry logic in ScriptAdapter
3. Update listen message to include validation confirmation

**Implementation:**
- Update Maestro configuration in GitHub
- Add explicit dependency with file ready check
- Test in DEV environment before PROD deployment

Would you like me to draft the Maestro YAML configuration for these changes?
```

### Example 4: Check for Failures and Calculate Success Rate

**User Request:**
```
"When was the last time subscription 500001147 failed?"
```

**Mossy Response:**
```markdown
🔍 Analyzing failure history for subscription 500001147...

[Executes queries to check for failures:]
1. Checking for @Status=False entries
2. Checking for noErrorOnDelivery:False entries
3. Calculating execution statistics

✅ **Perfect Success Record**

**Execution Statistics:**
- **Total Executions:** 68
- **Successful:** 68 (100%)
- **Failed:** 0 (0%)
- **First Execution:** June 10, 2026 at 09:45:10
- **Last Execution:** July 27, 2026 at 09:45:16
- **Days Spanned:** 47 days

**Analysis:**
This job has **never failed** since deployment. It maintains a perfect 100% success rate with:
- ✅ Consistent daily execution at ~09:45 AM
- ✅ All completion messages published successfully
- ✅ Zero delivery errors
- ✅ No execution gaps (excluding weekends)

**Reliability:** Excellent - No resequencing or troubleshooting needed.
```

**Alternative Response (When Failures Exist):**
```markdown
🔍 Analyzing failure history for subscription 500001147...

❌ **Failures Detected**

**Execution Statistics:**
- **Total Executions:** 45
- **Successful:** 42 (93.3%)
- **Failed:** 3 (6.7%)

**Recent Failures:**
| Date | Time | Status |
|------|------|--------|
| 2026-07-15 | 09:45:12 | Failed - @Status=False |
| 2026-07-10 | 09:45:15 | Failed - Delivery Error |
| 2026-07-05 | 09:45:10 | Failed - @Status=False |

**Last Failure:** July 15, 2026 at 09:45:12

**Failure Pattern:**
- Failures occur approximately every 5-7 days
- No consistent day-of-week pattern detected
- All failures during normal execution window (09:45 AM)

**Next Steps:**
Would you like me to investigate the July 15th failure in detail using the check-ssis-errors skill?
```

---

## Database Connection

**MOS Production:**
- **Server:** `mos-sql-p.mos.siepe.local,52155`
- **Databases:** `Core`, `Feeds`, `Solvas_AM`, `Reference`
- **Authentication:** Windows Integrated Security

**Query Execution:**
```powershell
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Feeds" -Q "[SQL QUERY]"
```

---

## Workflow Steps

### Step 1: Identify Job Type and Recent Executions

Determine if the job is an SSIS package, Solvas loader, Generic Import Job, or Maestro job.

#### 1a. Check SSIS Package Execution (Feeds Database)

**Purpose:** Find SSIS package executions, status, duration, and error details

**Query:**
```sql
-- Find SSIS package executions by name
SELECT TOP 20
    'Feeds.SSIS' AS LogSource, 
    ssis.RefDataSetID,
    ssis.PackageName AS ProcessName,
    'SSIS' AS ProcessType,
    ssis.EventDate AS EventDate,
    CASE 
        WHEN ssis.EventType IN ('PackageEnd', 'OnPostExecute') AND ssis.EventCode = 0 THEN 'Success'
        WHEN ssis.EventType IN ('OnError', 'PackageError') OR ssis.EventCode <> 0 THEN 'Failed'
        WHEN ssis.EventType IN ('PackageStart', 'OnPreExecute') THEN 'Running'
        ELSE 'Warning'
    END AS Status,
    COALESCE(ssis.PackageDuration, ssis.ContainerDuration) AS DurationSeconds,
    ssis.InsertCount AS RecordsProcessed,
    ssis.DeleteCount AS RecordsFailed,
    CASE WHEN ssis.EventCode <> 0 THEN 1 ELSE 0 END AS ErrorCount,
    ssis.EventDescription AS ErrorMessage,
    ssis.EventID AS SourceEventID
FROM [Feeds].[dbo].[tSSISImportEventLog] ssis
WHERE ssis.PackageName LIKE '%{PackageName}%'
  AND ssis.EventDate >= DATEADD(DAY, -7, GETDATE())
ORDER BY ssis.EventDate DESC;
```

**Parameters:**
- `{PackageName}` = SSIS package name (e.g., 'TradeLoader', 'PricingImport')
- Filter to last 7 days (adjustable)

**Expected Output:**
| ProcessName | EventDate | Status | DurationSeconds | RecordsProcessed | ErrorMessage |
|-------------|-----------|--------|-----------------|------------------|--------------|
| TradeLoader_SSIS | 2026-07-26 02:15:00 | Success | 120 | 5420 | NULL |
| TradeLoader_SSIS | 2026-07-25 02:14:30 | Success | 115 | 5380 | NULL |
| TradeLoader_SSIS | 2026-07-24 02:18:00 | Failed | 45 | 0 | Timeout waiting for upstream file |

**Use Cases:**
- Check if SSIS package ran successfully today
- Identify average execution duration
- Find error patterns or failure causes
- Validate data processing volume (InsertCount)

#### 1b. Check Solvas Loader Execution (Solvas_AM Database)

**Purpose:** Find Solvas Asset Loader and Trade Loader executions, status, and errors

**Query:**
```sql
-- Find Solvas loader executions
SELECT TOP 20
    'Solvas.' + processed_by AS LogSource,
    CASE processed_by
        WHEN 'ASSET_LOADER' THEN 'Solvas Asset Loader'
        WHEN 'TRADE_LOADER' THEN 'Solvas Trade Loader'
        ELSE 'Solvas ' + processed_by
    END AS ProcessName,
    'Loader' AS ProcessType,
    start_time AS EventDate,
    CASE process_status
        WHEN 'OK  ' THEN 'Success'
        WHEN 'ERR ' THEN 'Failed'
        WHEN 'VALD' THEN 'Success'
        WHEN 'LOAD' THEN 'Running'
        WHEN 'BEG ' THEN 'Running'
        ELSE 'Warning'
    END AS Status,
    DATEDIFF(SECOND, start_time, end_time) AS DurationSeconds,
    total_records_count AS RecordsProcessed,
    CASE WHEN process_status = 'ERR ' THEN total_records_count ELSE 0 END AS RecordsFailed,
    CASE WHEN process_status = 'ERR ' THEN 1 ELSE 0 END AS ErrorCount,
    COALESCE(error_message, error_body) AS ErrorMessage,
    process_id AS SourceEventID
FROM [Solvas_AM].[dbo].[Process_Log]
WHERE processed_by LIKE '%{LoaderName}%'
  AND start_time >= DATEADD(DAY, -7, GETDATE())
ORDER BY start_time DESC;
```

**Parameters:**
- `{LoaderName}` = 'ASSET_LOADER', 'TRADE_LOADER', or pattern
- Solvas loaders run after MOS data is prepared

**Expected Output:**
| ProcessName | EventDate | Status | DurationSeconds | RecordsProcessed | ErrorMessage |
|-------------|-----------|--------|-----------------|------------------|--------------|
| Solvas Asset Loader | 2026-07-26 02:30:00 | Success | 45 | 320 | NULL |
| Solvas Trade Loader | 2026-07-26 02:35:00 | Success | 60 | 1240 | NULL |
| Solvas Asset Loader | 2026-07-25 02:32:00 | Failed | 10 | 0 | FK constraint violation on entity_id |

**Use Cases:**
- Verify Solvas loaders completed after SSIS packages
- Identify downstream dependency timing
- Troubleshoot Solvas-specific errors (FK violations, data validation)

#### 1c. Check Generic Import Job Configuration (Feeds Database)

**Purpose:** Find file pickup jobs (Generic Import Jobs) and their source folders

**Query:**
```sql
-- Find Generic Import Job by ID or name
SELECT 
    GenericImportJobID,
    Name AS JobName,
    SourceFolder,
    FileName,
    FileExtension,
    ArchiveLocation,
    RefRecStatusID
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1  -- Active jobs only
  AND (Name LIKE '%{JobName}%' OR GenericImportJobID = {JobID})
ORDER BY Name;
```

**Parameters:**
- `{JobName}` = Pattern to search (e.g., 'Sycamore', 'Markit', 'ICE')
- `{JobID}` = Specific GenericImportJobID (e.g., 2136)

**Example Query:**
```sql
-- Find all Sycamore-related import jobs
SELECT GenericImportJobID, Name, SourceFolder, FileName
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1
  AND (Name LIKE '%Sycamore%' OR SourceFolder LIKE '%Sycamore%')
ORDER BY Name;
```

**Expected Output:**
| GenericImportJobID | JobName | SourceFolder | FileName |
|--------------------|---------|--------------|----------|
| 2350 | Sycamore Price Import | \\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\Sycamore\Prices | SycamorePrices_*.csv |
| 2351 | Sycamore Position Import | \\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\Sycamore\Positions | SycamorePositions_*.csv |

**Use Cases:**
- Find SFTP/network folder locations for file pickups
- Identify file naming patterns for import jobs
- Verify import job configuration before troubleshooting
- Check archive locations for processed files

#### 1d. Get Report Subscription and File Path Details (Cross-Database)

**Purpose:** Enrich job information with Subscription ID and File Root Paths for comprehensive job documentation

**Query:**
```sql
-- Get Report Subscription with linked Generic Import Job file paths
SELECT 
    -- Report Subscription Info
    rs.SubscriptionID,
    rs.Name AS JobName,
    rs.Description,
    rs.ReportID,
    SUBSTRING(
        rs.XmlDoc,
        CHARINDEX('<CompletionPubSub>', rs.XmlDoc) + 19,
        CHARINDEX('</CompletionPubSub>', rs.XmlDoc) - CHARINDEX('<CompletionPubSub>', rs.XmlDoc) - 19
    ) AS CompletionPubSub,
    
    -- Generic Import Job Info (File Paths)
    gi.GenericImportJobID,
    gi.SourceFolder AS FileRootPath,
    gi.FileName AS FileNamePattern,
    gi.ArchiveLocation,
    
    -- Job Type Classification
    CASE 
        WHEN gi.GenericImportJobID IS NOT NULL THEN 'File Import + Report'
        WHEN rs.SubscriptionID IS NOT NULL THEN 'Report Only'
        ELSE 'Unknown'
    END AS JobType

FROM 
    Core.Report.tSubscriptionXml rs
    LEFT JOIN Feeds.dbo.vGenericImportJob gi 
        ON RTRIM(LTRIM(rs.Name)) = RTRIM(LTRIM(gi.Name))
        AND gi.RefRecStatusID = 1

WHERE 
    rs.RefRecStatusID = 1
    AND rs.Name LIKE '%{JobName}%'  -- Replace with job pattern

ORDER BY 
    rs.Name;
```

**Parameters:**
- `{JobName}` = Job name pattern (e.g., 'Aristotle US Bank', 'Sycamore', 'Price')

**Example Query:**
```sql
-- Get Aristotle US Bank Daily Price Checks details
SELECT 
    rs.SubscriptionID,
    rs.Name AS JobName,
    gi.GenericImportJobID,
    gi.SourceFolder AS FileRootPath,
    gi.FileName AS FileNamePattern,
    gi.ArchiveLocation
FROM 
    Core.Report.tSubscriptionXml rs
    LEFT JOIN Feeds.dbo.vGenericImportJob gi 
        ON RTRIM(LTRIM(rs.Name)) = RTRIM(LTRIM(gi.Name))
        AND gi.RefRecStatusID = 1
WHERE 
    rs.RefRecStatusID = 1
    AND rs.SubscriptionID = 500002382;  -- Aristotle US Bank Daily Price Checks
```

**Expected Output:**
| SubscriptionID | JobName | GenericImportJobID | FileRootPath | FileNamePattern | ArchiveLocation |
|----------------|---------|--------------------|--------------|-----------------|--------------------|
| 500002382 | Aristotle US Bank Daily Price Checks | 2349 | \\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Aristotle\USBank\Prices | Siepe.40ZZ.Aristotle_ZU.*_USB_Acctg_DailyPriceChecks_FI.xlsx | \\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Aristotle\USBank\Prices\Archive |

**Use Cases:**
- **PipeWatch Dashboard**: Display Subscription ID and File Root Path in job drill-down
- **Job Resequencing**: Identify all file dependencies for a job
- **Troubleshooting**: Quickly locate file drop locations when files are missing
- **Documentation**: Comprehensive job metadata for operations runbooks

**Tables Used:**
- **Core.Report.tSubscriptionXml** - Report Subscription configuration
- **Feeds.dbo.vGenericImportJob** - File import job configuration

#### 1e. Get Reference Data Set (Latest Processing Dates)

**Purpose:** Find the most recent reference data set dates (data processing batches)

**Query:**
```sql
-- Get recent reference data sets
SELECT TOP 100 
    RefDataSetID,
    RefDataSetDate,
    CreatedDate,
    CreatedUser,
    RefRecStatusID
FROM feeds.dbo.vrefdataset 
ORDER BY createddate DESC;
```

**Use Cases:**
- Identify latest data processing date
- Verify if data for a specific date has been processed
- Check RefDataSetID for linking SSIS logs to data batches

#### 1f. Enrich PipeWatch Dashboard with File Path Metadata

**Purpose:** Add Subscription ID, Generic Import Job ID, and File Root Paths to PipeWatch job list UI for operational troubleshooting

**Location:** `C:\source\PipeWatch\`

**Process Overview:**
1. Query database to get enriched job metadata (Subscription IDs + File Paths)
2. Run Python generator script to create enriched JSON
3. Verify UI displays new fields automatically

**Step 1: Generate Enriched Job List JSON**

```powershell
# Navigate to PipeWatch
cd C:\source\PipeWatch

# Run job list generator (enriches with file paths)
python scripts/generators/generate_job_list.py
```

**Enrichment Query (in generate_job_list.py):**
```sql
-- Get Report Subscriptions with linked Generic Import Job file paths
SELECT 
    rs.SubscriptionID,
    rs.Name AS JobName,
    gi.GenericImportJobID,
    gi.SourceFolder AS FileRootPath,
    gi.FileName AS FileNamePattern,
    gi.ArchiveLocation
FROM 
    Core.Report.tSubscriptionXml rs
    LEFT JOIN Feeds.dbo.vGenericImportJob gi 
        ON RTRIM(LTRIM(rs.Name)) = RTRIM(LTRIM(gi.Name))
        AND gi.RefRecStatusID = 1
WHERE 
    rs.RefRecStatusID = 1;
```

**Step 2: Verify JSON Output**

```powershell
# Check enriched job data
Get-Content "C:\source\PipeWatch\public\docs\job-names-list.json" | ConvertFrom-Json | 
    ForEach-Object { $_.categories } | 
    ForEach-Object { $_.jobs } | 
    Where-Object { $_.file_root_path -ne $null } | 
    Select-Object -First 3 job_description, subscription_id, file_root_path
```

**Expected Output:**
```
job_description       : Aristotle US Bank Daily Price Checks | ReceiveService
subscription_id       : 500002382
delivery_frequency    : Daily
file_root_path        : \\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Aristotle\USBank\Prices

job_description       : Abry Liquid Credit CLO 2025-1, Ltd.
subscription_id       : 500002281
delivery_frequency    : Daily
file_root_path        : \\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\WATC\Abry
```

**Step 3: UI Display (Automatic)**

The PipeWatch UI (`public/index.html`) automatically displays enriched fields in job detail modals:

**Displayed Fields:**
- 📋 **Subscription ID** - Report Subscription identifier
- � **Delivery Frequency** - How often the report runs (Daily, Weekly, etc.)
- 📥 **Import Job ID** - Generic Import Job identifier
- 📁 **File Root Path** - Full UNC path where files are dropped
- 📄 **File Pattern** - Filename pattern for import files
- 📦 **Archive Location** - Where processed files are moved

**UI Code Location:** `C:\source\PipeWatch\public\index.html` (lines 830-880)

**Coverage Statistics:**
- **Jobs with File Paths:** 554 out of 1,028 (54%)
- **Jobs with Delivery Frequency:** 1,028 out of 1,028 (100%)
- **Jobs without File Paths:** 474 (Report-only jobs, no file imports)

**Use Cases:**
- **Troubleshooting Missing Files:** Quickly find file drop location when "file not found" errors occur
- **Job Configuration:** Verify file patterns and archive locations for Generic Import Jobs
- **Subscription Lookup:** Cross-reference Subscription IDs between Maestro and MOS database
- **Operations Documentation:** Complete job metadata in one place for support investigations

**Files Modified:**
- `C:\source\PipeWatch\scripts\generators\generate_job_list.py` - Enrichment query and JSON generation
- `C:\source\PipeWatch\public\index.html` - UI rendering of enriched fields (lines 830-860)
- `C:\source\PipeWatch\public\docs\job-names-list.json` - Enriched job data output

**Matching Logic:**
```python
# Name matching handles suffixes like "| ReceiveService" and "| Email"
job_base_name = job_name.split(" | ")[0].strip()
if job_base_name in file_path_lookup:
    # Add file path fields to job entry
```

#### Finding File Root Paths for Subscriptions Without Generic Import Jobs

**Problem:** ~54% of Report Subscriptions (474 out of 1,028 jobs) don't have matching Generic Import Jobs, so their file paths aren't automatically enriched.

**Step 1: Identify Subscriptions Without File Paths**

```powershell
# Query for all subscriptions without Generic Import Job matches
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" -Q "
SELECT 
    rs.SubscriptionID, 
    rs.Name AS JobName 
FROM 
    Core.Report.tSubscriptionXml rs 
WHERE 
    rs.RefRecStatusID = 1 
    AND NOT EXISTS (
        SELECT 1 
        FROM Feeds.dbo.vGenericImportJob gi 
        WHERE RTRIM(LTRIM(rs.Name)) = RTRIM(LTRIM(gi.Name)) 
        AND gi.RefRecStatusID = 1
    ) 
ORDER BY rs.Name
" -W -h-1 -s"|" -o "subscriptions_without_file_paths.txt"
```

**Step 2: Locate File Root Paths**

**Method A: Check Network Share Directories**
```powershell
# Common client file drop locations
$baseClientPath = "\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD"

# Example client folders:
# - Abry jobs → \\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Abry
# - WATC jobs → \\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\WATC
# - Aristotle jobs → \\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Aristotle\USBank\Prices
# - Sycamore jobs → \\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Sycamore

# List all client folders
Get-ChildItem $baseClientPath -Directory | Select-Object Name
```

**Method B: Check XmlDoc for File Path References**
```sql
-- Some subscriptions may have file paths in their XML configuration
SELECT 
    rs.SubscriptionID,
    rs.Name,
    CAST(rs.XmlDoc AS NVARCHAR(MAX)) AS XmlDoc
FROM 
    Core.Report.tSubscriptionXml rs
WHERE 
    rs.SubscriptionID = {TargetSubscriptionID};
```

**Method C: Check Maestro Job Configuration**
- Navigate to Maestro GitHub: https://github.com/siepe-software/maestro
- Search for Report Subscription ID or job name in YAML configuration files
- Look for file path or folder references

**Step 3: Add Manual File Path Override**

Edit `C:\source\PipeWatch\scripts\generators\generate_job_list.py` and add to `MANUAL_FILE_PATH_OVERRIDES` dictionary:

```python
# Manual File Path Overrides (for jobs without matching Generic Import Jobs)
MANUAL_FILE_PATH_OVERRIDES = {
    # Subscription ID -> File Path Override
    500001978: {  # Abry and Diameter Western Alliance (WATC) - Cash Files
        'file_root_path': r'\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\WATC',
        'file_name_pattern': None,  # Unknown - leave None if not known
        'archive_location': None    # Unknown - leave None if not known
    },
    500002186: {  # Abry and Diameter Western Alliance (WATC) - Position Files
        'file_root_path': r'\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\WATC',
        'file_name_pattern': None,
        'archive_location': None
    },
    # Add more manual overrides here as needed
}
```

**Step 4: Regenerate Job List**

```powershell
# Navigate to PipeWatch
cd C:\source\PipeWatch

# Run generator with manual overrides applied
& ".\venv\Scripts\python.exe" scripts/generators/generate_job_list.py
```

**Output:**
```
Fetching all jobs from database...
Fetching Report Subscription and File Path details...
Applying manual file path overrides...
  Applied override for Subscription ID 500001978: Abry and Diameter Western Alliance (WATC) -  Cash Files
  Applied override for Subscription ID 500002186: Abry and DIameter Western Alliance (WATC) -  Position Files
  Enriched 930 jobs with file path data
✓ Created: public\docs\job-names-list.json
  Jobs with enriched data: 554/1028
```

**Step 5: Verify in PipeWatch UI**

1. Refresh PipeWatch dashboard (http://localhost:8000)
2. Search for the subscription ID (e.g., "500001978")
3. Click "View Details →"
4. Verify the **📁 File Root Path** field now displays the manual override path

**Common Client File Path Patterns:**
| Client/Fund | File Root Path Pattern |
|-------------|------------------------|
| Abry | `\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Abry` |
| WATC | `\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\WATC` |
| Aristotle US Bank | `\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Aristotle\USBank\[SubFolder]` |
| Sycamore | `\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Sycamore` |
| Diameter | `\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Diameter` |

**When to Add Manual Overrides:**
- User reports missing file location when troubleshooting
- Investigating "file not found" errors for a specific subscription
- Building comprehensive documentation for a client's jobs
- Creating PipeWatch drill-down for frequently-used jobs

#### Automated Generation of Comprehensive File Path Overrides

**Purpose:** Automatically generate file path mappings for ALL subscriptions without Generic Import Jobs by matching job names to network share client folders.

**Location:** `C:\source\PipeWatch\scripts\generators\analyze_subscription_file_paths.ps1`

**Step 1: Run Automated Analysis Script**

```powershell
cd C:\source\PipeWatch\scripts\generators
.\analyze_subscription_file_paths.ps1
```

**What It Does:**
1. Queries all subscriptions without Generic Import Job matches (~956 subscriptions)
2. Lists all client folders in `\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD`
3. Matches job names to client folders using pattern recognition:
   - "Abry" → `Abry` folder
   - "WATC" → `WATC` folder
   - "Aristotle" → `Aristotle` folder
   - "Sycamore" → `Sycamore` folder
   - "US Bank"/"USBank" → `USBank` folder
   - etc.
4. Generates `file_path_overrides.py` with ~660 automatic mappings
5. Saves unmatched subscriptions to `unmatched_subscriptions.txt` for manual review

**Output Files:**
- `file_path_overrides.py` - Python dictionary with 660+ subscription file path mappings (3,306 lines)
- `unmatched_subscriptions.txt` - 294 subscriptions that couldn't be auto-mapped

**Example Output:**
```
✓ Generated file_path_overrides.py with 660 mapped subscriptions
✓ Saved 294 unmatched subscriptions to unmatched_subscriptions.txt
```

**Generated Override Format:**
```python
MANUAL_FILE_PATH_OVERRIDES = {
    500001978: {  # Abry and Diameter Western Alliance (WATC) - Cash Files
        'file_root_path': r'\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\WATC',
        'file_name_pattern': None,
        'archive_location': None
    },
    500002365: {  # ABRY ASF III 2, LP MML
        'file_root_path': r'\\mos.siepe.local\SHARED\CLIENTS\998\MOS\PROD\Abry',
        'file_name_pattern': None,
        'archive_location': None
    },
    # ... 658 more entries
}
```

**Step 2: Integration with PipeWatch Generator**

The `generate_job_list.py` script automatically imports `file_path_overrides.py`:

```python
# Import comprehensive manual file path overrides (660 subscriptions mapped)
try:
    with open(os.path.join(os.path.dirname(__file__), 'file_path_overrides.py'), 'r') as f:
        override_code = f.read()
        exec(override_code)
except FileNotFoundError:
    print("Warning: file_path_overrides.py not found, using minimal overrides")
    MANUAL_FILE_PATH_OVERRIDES = {}
```

**Coverage Statistics After Automation:**
- **Total Subscriptions:** 1,028
- **Auto-Matched via Generic Import Jobs:** 368 (36%)
- **Auto-Matched via Manual Overrides:** 660 (64%)
- **Total Enriched:** 1,028 (100%)
- **Unmatched (for manual review):** 294

#### Enriching Script Adapters with PowerShell Script Paths

**Purpose:** Add PowerShell script file locations to all Script Adapter jobs for troubleshooting and code review.

**Database Source:**
```sql
SELECT 
    ScriptConfigurationID,
    Name,
    ScriptPath
FROM 
    Enterprise.ScriptAdapter.vScriptConfigurationActive
```

**Example Data:**
| ScriptConfigurationID | Name | ScriptPath |
|-----------------------|------|------------|
| 1463 | Abry ALC Compliance Collateral Details Data File | C:\Siepe\Data\Scripts\PROD\Abry_ALC_DataFile_Import.ps1 |
| 1385 | Abry Invoice Billing Transaction | C:\Siepe\Data\Scripts\PROD\Abry_ClearParConsolidated_Invoice.ps1 |
| 1520 | Abry LevPro Trade | C:\Siepe\Data\Scripts\PROD\AbryLevProTradeImportNormalize.ps1 |

**Integration in generate_job_list.py:**

```python
# Fetch Script Adapter script paths
print("Fetching Script Adapter script paths...")
script_adapter_query = """
SELECT 
    ScriptConfigurationID,
    Name,
    ScriptPath
FROM 
    Enterprise.ScriptAdapter.vScriptConfigurationActive
"""
cursor.execute(script_adapter_query)
script_adapter_cols = [column[0] for column in cursor.description]
script_adapter_rows = cursor.fetchall()

# Create lookup dictionary: ScriptConfigurationID -> script path
script_adapter_lookup = {}
for row in script_adapter_rows:
    row_dict = dict(zip(script_adapter_cols, row))
    script_id = row_dict.get('ScriptConfigurationID')
    if script_id:
        script_adapter_lookup[script_id] = {
            'script_path': row_dict.get('ScriptPath')
        }

print(f"  Enriched {len(script_adapter_lookup)} Script Adapters with script paths")
```

**UI Display (in job detail modal):**
```javascript
// Add Script Adapter script path if available
if (job.script_path) {
    html += '<div style="margin-top: 16px; padding-top: 16px; border-top: 1px solid #d1d5db;">';
    html += `<div><strong>💻 PowerShell Script Path:</strong> 
             <div style="background: #f3f4f6; padding: 8px; border-radius: 4px; 
             margin-top: 4px; font-family: 'Courier New', monospace; 
             font-size: 13px;">${job.script_path}</div></div>`;
    html += '</div>';
}
```

**Coverage:** 309 Script Adapters enriched with script paths

**Use Cases:**
- **Code Review:** Quickly locate PowerShell script for a failing Script Adapter job
- **Troubleshooting:** Open script file directly when investigating job errors
- **Documentation:** Reference actual implementation when analyzing job logic
- **Dependency Analysis:** Find which scripts use which MOS stored procedures or file paths

#### Enriching Report Subscriptions with Delivery Frequency

**Purpose:** Add delivery frequency (Daily, Weekly, Monthly, etc.) to Report Subscription jobs for understanding job scheduling patterns.

**Database Source:**
```sql
-- Get Report Subscription with Delivery Frequency
SELECT 
    rs.SubscriptionID,
    rs.Name AS JobName,
    df.Name AS DeliveryFrequency,
    df.Description AS FrequencyDescription,
    rs.DeliveryFrequencyID
FROM 
    Core.Report.tSubscriptionXml rs
    LEFT JOIN Core.Report.tDeliveryFrequency df 
        ON rs.DeliveryFrequencyID = df.DeliveryFrequencyID
WHERE 
    rs.RefRecStatusID = 1
ORDER BY 
    rs.Name;
```

**Delivery Frequency Reference:**
| DeliveryFrequencyID | Name | Description |
|---------------------|------|-------------|
| 1 | Hourly | Every hour at the specified hour |
| 2 | Daily | Daily basis: every day or every weekday |
| 3 | Weekly | Weekly basis: where you can specify a given set of days of the week |
| 4 | Monthly | Every n-number of months on a set day of the month |
| 5 | Yearly | Every n-number of years on a set day of the year |
| 6 | OnEvent | Every time a specific real-time message or event occurs from the Pub/Sub service |
| 500000001 | None | No scheduled time, run once only |

**Example Query Result:**
```
SubscriptionID  JobName                                      DeliveryFrequency
500000001       Solvas Portfolio Extracts - Weekdays         Daily
500000002       Email Adapter Check Messages - 0:00          Daily
500000007       RegressionTest_Delivery_Service              OnEvent
500002382       Aristotle US Bank Daily Price Checks         Daily
```

**Integration in generate_job_list.py:**

```python
# Fetch delivery frequency data for Report Subscriptions
print("Fetching Report Subscription delivery frequency...")
frequency_query = """
SELECT 
    rs.SubscriptionID,
    df.Name AS DeliveryFrequency,
    df.Description AS FrequencyDescription
FROM 
    Core.Report.tSubscriptionXml rs
    LEFT JOIN Core.Report.tDeliveryFrequency df 
        ON rs.DeliveryFrequencyID = df.DeliveryFrequencyID
WHERE 
    rs.RefRecStatusID = 1
"""
cursor.execute(frequency_query)
frequency_cols = [column[0] for column in cursor.description]
frequency_rows = cursor.fetchall()

# Create lookup dictionary: SubscriptionID -> delivery frequency
frequency_lookup = {}
for row in frequency_rows:
    row_dict = dict(zip(frequency_cols, row))
    subscription_id = row_dict.get('SubscriptionID')
    if subscription_id:
        frequency_lookup[subscription_id] = {
            'delivery_frequency': row_dict.get('DeliveryFrequency'),
            'frequency_description': row_dict.get('FrequencyDescription')
        }

print(f"  Enriched {len(frequency_lookup)} Report Subscriptions with delivery frequency")
```

**Enriching Job Object:**
```python
# Get delivery frequency if this is a ReportSubscription job
delivery_frequency = None
frequency_description = None
if tool == 'ReportSubscription' and file_data.get('subscription_id'):
    freq_data = frequency_lookup.get(file_data.get('subscription_id'), {})
    delivery_frequency = freq_data.get('delivery_frequency')
    frequency_description = freq_data.get('frequency_description')

job_obj = {
    'job_description': j['description'],
    'tool_id': j['tool_id'],
    'listen_message': j['listen'],
    'publish_message': j['publish'],
    # Report Subscription enrichments
    'subscription_id': file_data.get('subscription_id'),
    'delivery_frequency': delivery_frequency,
    'frequency_description': frequency_description,
    # ... other fields ...
}
```

**UI Display (in job detail modal):**
```javascript
// Add delivery frequency for Report Subscriptions
if (job.delivery_frequency) {
    html += `<div style="margin-bottom: 8px;"><strong>📅 Delivery Frequency:</strong> 
             <span style="background: #dbeafe; color: #1e40af; padding: 2px 8px; 
             border-radius: 4px; font-weight: 600;">${job.delivery_frequency}</span></div>`;
    
    if (job.frequency_description) {
        html += `<div style="margin-bottom: 8px; font-size: 12px; color: #6b7280;">
                 ${job.frequency_description}</div>`;
    }
}
```

**Coverage:** All 1,028 Report Subscriptions enriched with delivery frequency

**Use Cases:**
- **Scheduling Analysis:** Understand how frequently a report runs
- **Job Optimization:** Identify candidates for frequency reduction
- **Troubleshooting:** Determine if a job should have run based on frequency
- **Documentation:** Complete job metadata for operations runbooks

#### Enriching Email Adapters with Email Configuration

**Purpose:** Add email account addresses, subject patterns, and file paths to Email Adapter jobs for email troubleshooting and monitoring.

**Database Source:**
```sql
-- Get Email Adapter Configuration with Email Addresses and File Paths
SELECT 
    mc.MessageConfigurationID,
    mc.Name AS JobName,
    c.Username AS EmailAccount,
    ms.Sender AS AllowedSender,
    mc.Subject AS EmailSubject,
    mc.AttachmentMoveLocation AS FilePath
FROM 
    Enterprise.EmailAdapter.vMessageConfigurationActive mc
    LEFT JOIN Enterprise.EmailAdapter.vConfigurationActive c 
        ON mc.ConfigurationID = c.ConfigurationID
    LEFT JOIN Enterprise.EmailAdapter.vMessageSenderActive ms 
        ON mc.MessageConfigurationID = ms.MessageConfigurationID
ORDER BY 
    mc.Name;
```

**Key Fields:**
- **EmailAccount** - The receiving email account (e.g., MOSData@siepe.com)
- **AllowedSender** - Email address pattern for allowed senders (e.g., *@garnetcredit.com)
- **EmailSubject** - Regex pattern for email subject matching
- **FilePath** - Where email attachments are saved after processing

**Example Query Result:**
```
MessageConfigurationID  JobName                                  EmailAccount            EmailSubject
1123                    AMAPS 4 SMA (DIA FC)                     MOSData@siepe.com       AMAPS 4 SMA \(DIA FC\) LLC.*
1006                    Diameter US Bank Trustee Load Holdings   MOSData@siepe.com       Diameter - US Bank Trustee Load
1008                    Solvas Trade Loader                      MOSData@siepe.com       .*Solvas Trade Loader.*
```

**Integration in generate_job_list.py:**

```python
# Fetch Email Adapter configuration (email addresses, subjects, file paths)
print("Fetching Email Adapter configuration...")

# Connect to Enterprise database for EmailAdapter tables
conn_str_enterprise = (
    "Driver={SQL Server};"
    "Server=mos-sql-p.mos.siepe.local,52155;"
    "Database=Enterprise;"
    "Trusted_Connection=yes;"
)
conn_enterprise = pyodbc.connect(conn_str_enterprise, timeout=30)
cursor_enterprise = conn_enterprise.cursor()

email_adapter_query = """
SELECT 
    mc.MessageConfigurationID,
    mc.Name AS JobName,
    c.Username AS EmailAccount,
    ms.Sender AS AllowedSender,
    mc.Subject AS EmailSubject,
    mc.AttachmentMoveLocation AS FilePath
FROM 
    EmailAdapter.vMessageConfigurationActive mc
    LEFT JOIN EmailAdapter.vConfigurationActive c 
        ON mc.ConfigurationID = c.ConfigurationID
    LEFT JOIN EmailAdapter.vMessageSenderActive ms 
        ON mc.MessageConfigurationID = ms.MessageConfigurationID
"""
cursor_enterprise.execute(email_adapter_query)
email_adapter_cols = [column[0] for column in cursor_enterprise.description]
email_adapter_rows = cursor_enterprise.fetchall()

# Create lookup dictionary: MessageConfigurationID -> email config
email_adapter_lookup = {}
for row in email_adapter_rows:
    row_dict = dict(zip(email_adapter_cols, row))
    message_id = row_dict.get('MessageConfigurationID')
    if message_id:
        email_adapter_lookup[message_id] = {
            'email_account': row_dict.get('EmailAccount'),
            'allowed_sender': row_dict.get('AllowedSender'),
            'email_subject': row_dict.get('EmailSubject'),
            'file_path': row_dict.get('FilePath')
        }

print(f"  Enriched {len(email_adapter_lookup)} Email Adapters with email addresses and file paths")

cursor_enterprise.close()
conn_enterprise.close()
```

**Enriching Job Object:**
```python
# Get Email Adapter configuration if this is an EmailAdapter job
email_account = None
allowed_sender = None
email_subject = None
email_file_path = None
if tool == 'EmailAdapter' and j['tool_id']:
    email_data = email_adapter_lookup.get(j['tool_id'], {})
    email_account = email_data.get('email_account')
    allowed_sender = email_data.get('allowed_sender')
    email_subject = email_data.get('email_subject')
    email_file_path = email_data.get('file_path')

job_obj = {
    'job_description': j['description'],
    'tool_id': j['tool_id'],
    'listen_message': j['listen'],
    'publish_message': j['publish'],
    # ... other fields ...
    # Add Email Adapter fields
    'email_account': email_account,
    'allowed_sender': allowed_sender,
    'email_subject': email_subject,
    'email_file_path': email_file_path
}
```

**UI Display (in job detail modal):**
```javascript
// Add Email Adapter configuration if available
if (job.email_account || job.email_subject || job.email_file_path) {
    html += '<div style="margin-top: 16px; padding-top: 16px; border-top: 1px solid #d1d5db;">';
    html += '<h4 style="margin: 0 0 12px 0; color: #7c3aed; font-size: 16px;">📧 Email Configuration</h4>';
    
    if (job.email_account) {
        html += `<div style="margin-bottom: 8px;"><strong>📬 Email Account:</strong> 
                 <code style="background: #ede9fe; color: #5b21b6; padding: 2px 8px; border-radius: 4px;">${job.email_account}</code></div>`;
    }
    
    if (job.allowed_sender) {
        html += `<div style="margin-bottom: 8px;"><strong>✉️ Allowed Sender:</strong> 
                 <code style="background: #e0e7ff; color: #3730a3; padding: 2px 8px; border-radius: 4px;">${job.allowed_sender}</code></div>`;
    }
    
    if (job.email_subject) {
        html += `<div style="margin-bottom: 8px;"><strong>📝 Subject Pattern:</strong> 
                 <div style="background: #f3f4f6; padding: 8px; border-radius: 4px; margin-top: 4px; 
                 font-family: 'Courier New', monospace; font-size: 12px;">${job.email_subject}</div></div>`;
    }
    
    if (job.email_file_path) {
        html += `<div><strong>📁 Attachment Save Location:</strong> 
                 <div style="background: #f3f4f6; padding: 8px; border-radius: 4px; margin-top: 4px; 
                 font-family: 'Courier New', monospace; font-size: 13px; word-break: break-all;">${job.email_file_path}</div></div>`;
    }
    
    html += '</div>';
}
```

**Coverage:** All 78 EmailAdapter jobs enriched with email configuration

**Use Cases:**
- **Email Troubleshooting:** Identify which email account receives specific client files
- **Subject Pattern Debugging:** Understand why emails aren't being processed (subject mismatch)
- **File Location:** Quickly find where email attachments are saved
- **Sender Whitelisting:** Verify allowed sender patterns for email security

#### Final Enrichment Summary

**Complete PipeWatch Job Enrichment Fields:**

| Job Type | Enriched Fields |
|----------|-----------------|
| **Report Subscription** | 📋 Subscription ID<br>📥 Generic Import Job ID<br>📁 File Root Path<br>📄 File Name Pattern<br>📦 Archive Location<br>📅 Delivery Frequency<br>📝 Frequency Description |
| **Script Adapter** | 💻 PowerShell Script Path |
| **Email Adapter** | 📬 Email Account<br>✉️ Allowed Sender Pattern<br>📝 Email Subject Pattern<br>📁 Attachment Save Location |
| **Generic Import Job** | (via Report Subscription linkage) |

**Full Regeneration Command:**
```powershell
cd C:\source\PipeWatch

# Step 1: Generate comprehensive file path overrides (optional - already done)
.\scripts\generators\analyze_subscription_file_paths.ps1

# Step 2: Regenerate job list with all enrichments
& ".\venv\Scripts\python.exe" scripts/generators/generate_job_list.py
```

**Expected Output:**
```
Fetching all jobs from database...
Fetching Report Subscription and File Path details...
Applying manual file path overrides...
  Applied override for Subscription ID 500001978: Abry and Diameter Western Alliance (WATC) - Cash Files
  [... 659 more overrides ...]
  Enriched 930 jobs with file path data
Fetching Report Subscription delivery frequency...
  Enriched 956 Report Subscriptions with delivery frequency
Fetching Script Adapter script paths...
  Enriched 309 Script Adapters with script paths
Fetching Email Adapter configuration...
  Enriched 80 Email Adapters with email addresses and file paths
✓ Created: public\docs\job-names-list.json
  Jobs with enriched data: 1028/1028 (100%)
```

**Files Reference:**
- `C:\source\PipeWatch\scripts\generators\analyze_subscription_file_paths.ps1` - Auto-generate file path overrides
- `C:\source\PipeWatch\scripts\generators\file_path_overrides.py` - 660 subscription file path mappings
- `C:\source\PipeWatch\scripts\generators\generate_job_list.py` - Main enrichment script
- `C:\source\PipeWatch\public\docs\job-names-list.json` - Enriched job data output
- `C:\source\PipeWatch\public\index.html` - UI rendering (lines 830-880)

---

### Step 2: Analyze Job Dependencies (Maestro)

**Maestro Job Scheduler:**
- **GitHub:** https://github.com/siepe-software/maestro
- **Purpose:** Orchestrates SSIS packages, Report Subscriptions (RS), Script Adapters (SA)
- **Job Types:** 
  - SSIS Packages (data imports, transformations)
  - Report Subscriptions (RS) - Scheduled report generation
  - Script Adapters (SA) - Custom scripts for file delivery, processing

**Dependency Mapping Strategy:**

Since Maestro dependencies are configured in the job orchestration system (not directly queryable from SQL), use these strategies:

#### Option A: Infer Dependencies from Execution Timing

**Query:**
```sql
-- Analyze SSIS execution timing patterns to infer dependencies
WITH PackageTiming AS (
    SELECT 
        ssis.PackageName,
        ssis.EventDate,
        CAST(ssis.EventDate AS DATE) AS ExecutionDate,
        DATEPART(HOUR, ssis.EventDate) AS ExecutionHour,
        DATEPART(MINUTE, ssis.EventDate) AS ExecutionMinute,
        COALESCE(ssis.PackageDuration, ssis.ContainerDuration) AS DurationSeconds,
        CASE 
            WHEN ssis.EventType IN ('PackageEnd', 'OnPostExecute') AND ssis.EventCode = 0 THEN 'Success'
            ELSE 'NotSuccess'
        END AS Status
    FROM [Feeds].[dbo].[tSSISImportEventLog] ssis
    WHERE ssis.EventDate >= DATEADD(DAY, -30, GETDATE())
      AND ssis.EventType IN ('PackageEnd', 'OnPostExecute')  -- End events only
)
SELECT 
    PackageName,
    AVG(ExecutionHour) AS AvgExecutionHour,
    AVG(ExecutionMinute) AS AvgExecutionMinute,
    AVG(DurationSeconds) AS AvgDurationSeconds,
    COUNT(*) AS ExecutionCount,
    SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS SuccessRatePercent
FROM PackageTiming
WHERE Status = 'Success'  -- Only successful runs for timing analysis
GROUP BY PackageName
ORDER BY AvgExecutionHour, AvgExecutionMinute;
```

**Output:**
| PackageName | AvgExecutionHour | AvgExecutionMinute | AvgDurationSeconds | ExecutionCount | SuccessRatePercent |
|-------------|------------------|--------------------|--------------------|----------------|-------------------|
| SecurityMasterImport | 1 | 30 | 600 | 30 | 100.0 |
| TradeLoader_SSIS | 2 | 15 | 120 | 30 | 98.3 |
| PricingImport | 2 | 45 | 300 | 30 | 96.7 |

**Analysis:**
- Jobs with earlier execution times are likely **upstream dependencies**
- Jobs with later execution times are likely **downstream consumers**
- Consistent timing suggests hard-coded scheduling (not dynamic dependencies)

#### Option B: Query Maestro Configuration (If Available)

**Note:** Maestro job dependencies are typically configured in YAML or JSON configuration files in the Maestro repository. If you have access to the Maestro database or API, query job dependency configuration directly.

**Example Maestro Job Configuration (YAML):**
```yaml
job:
  name: "MiddleOfficeTradeLoad"
  schedule: "0 2 * * *"  # 02:00 daily
  dependencies:
    - "SecurityMasterImport"  # Must complete first
    - "PortfolioDataSync"     # Must complete first
  timeout: "30m"
```

**Action:**
- Review Maestro job configuration files in GitHub repo
- Identify hard dependencies (jobs that MUST complete first)
- Identify soft dependencies (preferred but not required)

#### Option C: Check Normalization Views (Data Flow Dependencies)

**Query:**
```sql
-- Find normalization views (data flow mappings)
SELECT 
    NormalizationViewID,
    NormalizationViewType,
    Name,
    SourceTable,
    DestinationTable
FROM feeds.dbo.vnormalizationview
WHERE NormalizationViewType LIKE '%{ViewTypePattern}%'
ORDER BY Name;
```

**Parameters:**
- `{ViewTypePattern}` = Pattern to search (e.g., 'inst%con%cash%' for contract cashflow normalization)

**Example:**
```sql
-- Find all contract cashflow normalization views
SELECT *
FROM feeds.dbo.vnormalizationview
WHERE normalizationviewtype LIKE '%inst%con%cash%';
```

**Use Cases:**
- Understand data lineage (source → destination mappings)
- Identify which tables/views depend on upstream data sources
- Validate normalization configuration for troubleshooting

---

### Step 3: Analyze Execution History and Performance Trends
---

### Step 3: Analyze Execution History and Performance Trends

**Purpose:** Calculate median/average duration, identify outliers, and assess success rate

#### 3a. SSIS Package Performance Over Time

**Query:**
```sql
-- Calculate SSIS package performance statistics
WITH PackageStats AS (
    SELECT 
        ssis.PackageName,
        CAST(ssis.EventDate AS DATE) AS ExecutionDate,
        COALESCE(ssis.PackageDuration, ssis.ContainerDuration) AS DurationSeconds,
        CASE 
            WHEN ssis.EventType IN ('PackageEnd', 'OnPostExecute') AND ssis.EventCode = 0 THEN 1
            ELSE 0
        END AS IsSuccess,
        ssis.InsertCount AS RecordsProcessed
    FROM [Feeds].[dbo].[tSSISImportEventLog] ssis
    WHERE ssis.PackageName LIKE '%{PackageName}%'
      AND ssis.EventDate >= DATEADD(DAY, -30, GETDATE())
      AND ssis.EventType IN ('PackageEnd', 'OnPostExecute')  -- End events only
)
SELECT 
    PackageName,
    COUNT(*) AS TotalExecutions,
    SUM(IsSuccess) AS SuccessfulRuns,
    SUM(IsSuccess) * 100.0 / COUNT(*) AS SuccessRatePercent,
    AVG(DurationSeconds) AS AvgDurationSeconds,
    MIN(DurationSeconds) AS MinDurationSeconds,
    MAX(DurationSeconds) AS MaxDurationSeconds,
    STDEV(DurationSeconds) AS StdDevDuration,
    AVG(RecordsProcessed) AS AvgRecordsProcessed
FROM PackageStats
GROUP BY PackageName;
```

**Expected Output:**
| PackageName | TotalExecutions | SuccessfulRuns | SuccessRatePercent | AvgDurationSeconds | MinDuration | MaxDuration | AvgRecordsProcessed |
|-------------|-----------------|----------------|--------------------|--------------------|-------------|-------------|---------------------|
| TradeLoader_SSIS | 30 | 29 | 96.7 | 120.5 | 95 | 180 | 5420 |

**Analysis:**
- **Success Rate < 95%:** Investigate failure patterns
- **High StdDev:** Inconsistent performance, identify slow days
- **MaxDuration >> AvgDuration:** Outliers exist, check for specific dates
- **Declining RecordsProcessed:** Potential data quality issues

#### 3b. Solvas Loader Performance Over Time

**Query:**
```sql
-- Calculate Solvas loader performance statistics
WITH LoaderStats AS (
    SELECT 
        processed_by AS LoaderName,
        CAST(start_time AS DATE) AS ExecutionDate,
        DATEDIFF(SECOND, start_time, end_time) AS DurationSeconds,
        CASE WHEN process_status IN ('OK  ', 'VALD') THEN 1 ELSE 0 END AS IsSuccess,
        total_records_count AS RecordsProcessed
    FROM [Solvas_AM].[dbo].[Process_Log]
    WHERE processed_by LIKE '%{LoaderName}%'
      AND start_time >= DATEADD(DAY, -30, GETDATE())
)
SELECT 
    LoaderName,
    COUNT(*) AS TotalExecutions,
    SUM(IsSuccess) AS SuccessfulRuns,
    SUM(IsSuccess) * 100.0 / COUNT(*) AS SuccessRatePercent,
    AVG(DurationSeconds) AS AvgDurationSeconds,
    MIN(DurationSeconds) AS MinDurationSeconds,
    MAX(DurationSeconds) AS MaxDurationSeconds,
    AVG(RecordsProcessed) AS AvgRecordsProcessed
FROM LoaderStats
GROUP BY LoaderName;
```

**Expected Output:**
| LoaderName | TotalExecutions | SuccessfulRuns | SuccessRatePercent | AvgDurationSeconds | MinDuration | MaxDuration | AvgRecordsProcessed |
|------------|-----------------|----------------|--------------------|--------------------|-------------|-------------|---------------------|
| ASSET_LOADER | 30 | 30 | 100.0 | 45.2 | 40 | 55 | 320 |
| TRADE_LOADER | 30 | 28 | 93.3 | 62.8 | 50 | 120 | 1240 |

**Red Flags:**
- **TRADE_LOADER at 93.3% success** - Investigate 2 failures
- **MaxDuration 120s vs Avg 62.8s** - Significant outlier (double normal time)

#### 3c. Identify Execution Anomalies (Last 7 Days)

**Query:**
```sql
-- Find recent failed or slow executions
SELECT TOP 20
    'SSIS' AS JobType,
    ssis.PackageName AS JobName,
    ssis.EventDate,
    CASE 
        WHEN ssis.EventCode <> 0 THEN 'FAILED'
        WHEN COALESCE(ssis.PackageDuration, ssis.ContainerDuration) > 
             (SELECT AVG(COALESCE(PackageDuration, ContainerDuration)) * 2
              FROM [Feeds].[dbo].[tSSISImportEventLog] 
              WHERE PackageName = ssis.PackageName) THEN 'SLOW'
        ELSE 'OK'
    END AS Issue,
    COALESCE(ssis.PackageDuration, ssis.ContainerDuration) AS DurationSeconds,
    ssis.EventDescription AS ErrorMessage
FROM [Feeds].[dbo].[tSSISImportEventLog] ssis
WHERE ssis.EventDate >= DATEADD(DAY, -7, GETDATE())
  AND ssis.EventType IN ('PackageEnd', 'OnPostExecute', 'OnError', 'PackageError')
  AND (ssis.EventCode <> 0 OR 
       COALESCE(ssis.PackageDuration, ssis.ContainerDuration) > 
       (SELECT AVG(COALESCE(PackageDuration, ContainerDuration)) * 2
        FROM [Feeds].[dbo].[tSSISImportEventLog] 
        WHERE PackageName = ssis.PackageName))
ORDER BY ssis.EventDate DESC;

UNION ALL

SELECT TOP 20
    'Solvas' AS JobType,
    'Solvas ' + processed_by AS JobName,
    start_time AS EventDate,
    CASE 
        WHEN process_status = 'ERR ' THEN 'FAILED'
        WHEN DATEDIFF(SECOND, start_time, end_time) > 
             (SELECT AVG(DATEDIFF(SECOND, start_time, end_time)) * 2
              FROM [Solvas_AM].[dbo].[Process_Log]
              WHERE processed_by = pl.processed_by) THEN 'SLOW'
        ELSE 'OK'
    END AS Issue,
    DATEDIFF(SECOND, start_time, end_time) AS DurationSeconds,
    COALESCE(error_message, error_body) AS ErrorMessage
FROM [Solvas_AM].[dbo].[Process_Log] pl
WHERE start_time >= DATEADD(DAY, -7, GETDATE())
  AND (process_status = 'ERR ' OR 
       DATEDIFF(SECOND, start_time, end_time) > 
       (SELECT AVG(DATEDIFF(SECOND, start_time, end_time)) * 2
        FROM [Solvas_AM].[dbo].[Process_Log]
        WHERE processed_by = pl.processed_by))
ORDER BY start_time DESC;
```

**Expected Output:**
| JobType | JobName | EventDate | Issue | DurationSeconds | ErrorMessage |
|---------|---------|-----------|-------|-----------------|--------------|
| SSIS | TradeLoader_SSIS | 2026-07-24 02:18:00 | FAILED | 45 | Timeout waiting for upstream file |
| Solvas | Solvas TRADE_LOADER | 2026-07-23 02:45:00 | SLOW | 180 | NULL |
| SSIS | PricingImport | 2026-07-22 03:15:00 | FAILED | 0 | Connection timeout to vendor SFTP |

**Action:**
- Review each anomaly for root cause
- Check if failures correlate with dependency delays
- Identify patterns (weekends, month-end, specific vendors)

---

### Step 4: Calculate Optimal Start Time

**Algorithm:**

```typescript
// 1. Find latest upstream completion time from Step 2 analysis
latestUpstreamEnd = max(upstreamJob.avgExecutionHour:avgExecutionMinute + avgDurationSeconds)

// 2. Add buffer for data availability and system stability
dataAvailabilityBuffer = 5 minutes

// 3. Round to nearest 5-minute interval (Maestro schedule granularity)
proposedStartTime = roundUp(latestUpstreamEnd + dataAvailabilityBuffer, 5 minutes)

// 4. Check for conflicts with other jobs (avoid resource contention)
if (conflictsWithOtherJobs(proposedStartTime)) {
    proposedStartTime = findNextAvailableSlot(proposedStartTime)
}

// 5. Validate against business constraints
if (proposedStartTime < 01:00 or proposedStartTime > 06:00) {
    // Nightly processing window constraint (typical MOS window: 01:00-06:00)
    flag_for_manual_review = true
}

// 6. Consider downstream dependencies
if (downstreamJobs.exists && proposedStartTime + jobDuration > downstreamJob.startTime) {
    flag_for_manual_review = true  // Risk of cascading delays
}
```

**Example Calculation:**

**Scenario:** Resequencing "TradeLoader_SSIS"

**Upstream Jobs (from Step 2):**
- SecurityMasterImport: Completes at 01:40:00 (avg)
- MarketDataImport: Completes at 01:52:00 (avg)
- PortfolioDataSync: Completes at 01:48:00 (avg)

**Current Job:**
- TradeLoader_SSIS: Currently starts at 02:00:00
- Average duration: 2 minutes (120 seconds)

**Calculation:**
```
Latest upstream completion: 01:52:00 (MarketDataImport)
+ Buffer: 00:05:00
= 01:57:00

Rounded to 5-min: 02:00:00
Current start time: 02:00:00

✅ Recommendation: Keep current schedule (optimal)
   - All upstream jobs have completed by 01:52:00
   - 8-minute buffer before TradeLoader starts (exceeds 5-min minimum)
   - No conflicts with other jobs at 02:00:00
```

**Alternative Scenario - Opportunity to Run Earlier:**
```
If MarketDataImport consistently completes by 01:45:00 (not 01:52:00):

Latest upstream: 01:45:00
+ Buffer: 00:05:00
= 01:50:00

Rounded to 5-min: 01:50:00
Current start time: 02:00:00

⚠️ Recommendation: Consider moving to 01:50:00 or 01:55:00
   - Could run 5-10 minutes earlier
   - Risk: Low (upstream jobs have 5+ minute buffer)
   - Benefit: Faster data availability for downstream consumers (Solvas loaders)
```

**Risk Assessment Factors:**

| Factor | Low Risk | Medium Risk | High Risk |
|--------|----------|-------------|-----------|
| **Upstream Buffer** | > 10 minutes | 5-10 minutes | < 5 minutes |
| **Success Rate** | > 98% | 95-98% | < 95% |
| **Duration Variability** | StdDev < 20% of Avg | StdDev 20-50% of Avg | StdDev > 50% of Avg |
| **Downstream Impact** | No tight dependencies | Some dependencies | Critical path job |

---

### Step 5: Check MOS Dashboard Reports (Optional)

**Purpose:** Verify if the job is associated with MOS dashboard reports or monitoring

**Query:**
```sql
-- Find dashboard reports related to job or process
SELECT 
    DashboardReportID,
    DashboardID,
    Title,
    StatusProc,
    RefRecStatusID,
    CreatedDate,
    CreatedUser
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%{JobKeyword}%')  -- Case-insensitive search
  AND RefRecStatusID = 1  -- Only active reports
ORDER BY CreatedDate DESC;
```

**Parameters:**
- `{JobKeyword}` = Search term (e.g., 'Cashflow', 'Trade', 'Pricing')

**Example:**
```sql
-- Find all Cashflow-related dashboard reports
SELECT 
    DashboardReportID,
    DashboardID,
    Title,
    StatusProc
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%Cashflow%')
  AND RefRecStatusID = 1
ORDER BY CreatedDate DESC;
```

**Use Cases:**
- Identify if job failures affect dashboard reports
- Check StatusProc for report generation procedures
- Coordinate timing with dashboard refresh schedules

---

### Step 6: Generate Recommendations

Create a comprehensive summary:

#### 6a. Current Schedule Analysis

**Template:**
```markdown
## Current Schedule: {JobName}

- **Job Type:** {SSIS / Solvas / Report Subscription / Script Adapter}
- **Current Start Time:** {HH:MM} (if known from Maestro)
- **Average Duration:** {X} minutes ({Y} seconds)
- **Success Rate:** {Z}% (last 30 days)
- **Average Records Processed:** {N} records

## Upstream Dependencies (Inferred from Timing)

| Upstream Job | Avg Completion Time | Buffer to {JobName} Start | Status |
|--------------|---------------------|---------------------------|--------|
| SecurityMasterImport | 01:40 | 20 min | ✅ Sufficient |
| MarketDataImport | 01:52 | 8 min | ✅ Adequate |
| PortfolioDataSync | 01:48 | 12 min | ✅ Sufficient |

**Analysis:**
- All upstream dependencies complete with adequate buffer (5+ minutes)
- No timing conflicts observed in last 30 days
- Current schedule is **optimal**
```

#### 6b. Proposed Changes (If Resequencing Needed)

**Scenario 1: No Changes Needed**
```markdown
## Recommendation: ✅ Keep Current Schedule

**Rationale:**
- Upstream dependencies have adequate completion buffers
- Job success rate is high (> 95%)
- Duration is consistent and predictable
- No downstream cascade risks

**Alternative (Optional):**
- Could move to {earlier_time} to run 5 minutes earlier
- Risk: Low
- Benefit: Faster data availability for downstream consumers
```

**Scenario 2: Resequencing Recommended**
```markdown
## Recommendation: ⚠️ Adjust Schedule

**Current Issues:**
- Insufficient buffer from upstream job "{JobName}" (only 2 minutes)
- High failure rate (85%) correlated with dependency delays
- Duration variability (StdDev 50% of average)

**Proposed Changes:**
1. **Delay start time** from 02:00 to 02:10
   - Increases buffer from 2 min to 12 min
   - Reduces risk of starting before upstream data is ready
   
2. **Add explicit dependency check** in Maestro configuration
   - Wait for "MarketDataImport" completion signal
   - Prevents race conditions

**Risk Assessment:**
- Low risk of implementation issues
- High benefit: Expected success rate increase from 85% to 98%
- Downstream impact: Minimal (10-minute delay acceptable for non-critical consumers)
```

---

### Step 7: Generate Maestro Configuration Changes (If Needed)

**Maestro Configuration:**
- Job schedules are defined in Maestro configuration files (YAML/JSON)
- Located in Maestro GitHub repository: https://github.com/siepe-software/maestro
- Changes require pull request review and deployment

**If resequencing is recommended, generate Maestro configuration template:**

#### Example Maestro Job Configuration (YAML):

```yaml
# File: maestro-config/jobs/middle-office-trade-load.yaml
job:
  name: "MiddleOfficeTradeLoad"
  type: "SSIS"
  package_name: "TradeLoader_SSIS"
  
  # Updated schedule (cron format: minute hour day month dayofweek)
  # OLD: "0 2 * * *"  # 02:00 daily
  # NEW: "55 1 * * *"  # 01:55 daily (5 minutes earlier)
  schedule: "55 1 * * *"
  
  # Explicit dependencies (wait for these jobs to complete first)
  dependencies:
    - job_name: "SecurityMasterImport"
      type: "hard"  # Must complete before this job starts
      timeout: "30m"
    - job_name: "MarketDataImport"
      type: "hard"
      timeout: "45m"
    - job_name: "PortfolioDataSync"
      type: "soft"  # Preferred but not required
      timeout: "15m"
  
  # Job execution parameters
  timeout: "30m"  # Maximum execution time
  retry_count: 2  # Number of retries on failure
  retry_delay: "5m"  # Delay between retries
  
  # Notifications
  notify_on_failure: true
  notify_recipients:
    - "mos-support@siepe.com"
  
  # Metadata
  description: "Load trade data from middle office systems"
  owner: "MOS Operations Team"
  criticality: "high"  # high, medium, low
```

**Change Summary for Pull Request:**

```markdown
## Maestro Configuration Change: MiddleOfficeTradeLoad

**Type:** Schedule Adjustment  
**Priority:** Medium  
**Impact:** Low (earlier execution, no downstream breaking changes)

### Changes
- **Schedule:** 02:00 → 01:55 (5 minutes earlier)
- **Added explicit dependencies:** SecurityMasterImport, MarketDataImport, PortfolioDataSync

### Rationale
- Dependency analysis shows all upstream jobs complete by 01:52 on average
- Current 8-minute buffer can be reduced to 3 minutes safely
- Earlier execution provides faster data availability for Solvas loaders
- Added explicit dependencies to prevent race conditions

### Risk Assessment
- **Risk Level:** Low
- **Buffer from upstream:** 3-8 minutes (acceptable)
- **Historical success rate:** 98%
- **Downstream impact:** Minimal (Solvas loaders have flexible timing)

### Testing Plan
1. Deploy to DEV environment
2. Monitor 3 consecutive successful runs
3. Compare execution timing with production baseline
4. Validate Solvas loader timing not impacted
5. Deploy to PROD with rollback plan

### Rollback Plan
If issues arise, revert schedule to "0 2 * * *" (02:00) immediately.
```

**Action:**
- **DO NOT modify Maestro configuration directly** - requires DevOps review
- Generate configuration template for manual implementation
- Create GitHub pull request with change summary
- Save configuration to `investigations/MaestroConfig_{JobName}_{Date}.yaml`
- Document in ADO ticket for tracking

---

### Step 8: Generate Comprehensive Analysis Report

Create a detailed markdown report for the ADO ticket:

**Filename:** `JobResequencing_{JobName}_{Date}.md`  
**Example:** `JobResequencing_TradeLoader_20260726.md`

**Template:**

```markdown
# Job Resequencing Analysis: {JobName}

**Work Item:** #{WorkItemID} (if applicable)  
**Analysis Date:** {CurrentDate}  
**Analyzed By:** Mossy Agent  
**Database:** MOS Production (mos-sql-p.mos.siepe.local,52155)

---

## Executive Summary

**Current Status:** {OPTIMAL / SUB-OPTIMAL / REQUIRES ATTENTION}

**Key Findings:**
- ✅/⚠️/❌ {Finding 1}
- ✅/⚠️/❌ {Finding 2}
- ✅/⚠️/❌ {Finding 3}

**Recommendation:** {Keep current schedule / Adjust to {new_time} / Investigate failures before resequencing}

---

## Job Details

### Current Configuration

| Property | Value |
|----------|-------|
| **Job Name** | {JobName} |
| **Job Type** | {SSIS / Solvas / Report Subscription / Script Adapter} |
| **Current Schedule** | {HH:MM} daily (if known from Maestro) |
| **Average Duration** | {X} minutes ({Y} seconds) |
| **Success Rate (30 days)** | {Z}% ({successful} / {total} runs) |
| **Average Records Processed** | {N} records |
| **Last Successful Run** | {Date Time} |
| **Last Failed Run** | {Date Time} (if any) |

### Execution History (Last 30 Days)

| Metric | Value |
|--------|-------|
| Total Executions | {N} |
| Successful | {M} ({percent}%) |
| Failed | {F} ({percent}%) |
| Average Duration | {X} seconds |
| Min Duration | {Y} seconds |
| Max Duration | {Z} seconds |
| Std Dev Duration | {S} seconds |

**Performance Trend:**
- {Consistent / Improving / Degrading / Highly variable}
- Notable outliers: {List any dates with 2x+ normal duration}

---

## Dependency Analysis

### Upstream Jobs (Inferred from Execution Timing)

| Upstream Job | Avg Completion Time | Buffer to {JobName} | Status |
|--------------|---------------------|---------------------|--------|
| {Job1} | {HH:MM} | {X} minutes | ✅ Sufficient (>10 min) / ⚠️ Adequate (5-10 min) / ❌ Insufficient (<5 min) |
| {Job2} | {HH:MM} | {Y} minutes | ✅/⚠️/❌ {Status} |

**Analysis:**
- {Summary of dependency timing}
- {Identification of critical path jobs}
- {Any correlated failures between dependencies and this job}

### Downstream Jobs (Dependent on This Job)

| Downstream Job | Avg Start Time | Dependency Type | Impact of Delay |
|----------------|----------------|-----------------|-----------------|
| {Job1} | {HH:MM} | Hard / Soft | High / Medium / Low |
| {Job2} | {HH:MM} | Hard / Soft | High / Medium / Low |

**Analysis:**
- {Summary of downstream dependencies}
- {Critical downstream consumers}
- {Acceptable delay tolerance}

---

## Recent Issues (Last 7 Days)

### Failures

{If no failures:}
✅ No failures detected in the last 7 days.

{If failures exist:}
| Date | Issue | Duration | Error Message |
|------|-------|----------|---------------|
| {Date} | FAILED | {X}s | {Error} |
| {Date} | FAILED | {Y}s | {Error} |

**Failure Pattern Analysis:**
- {Common error types}
- {Correlation with dependency delays}
- {Day-of-week patterns}

### Slow Executions (>2x Average Duration)

{If no slow runs:}
✅ No slow executions detected.

{If slow runs exist:}
| Date | Duration | Expected Duration | Delta |
|------|----------|-------------------|-------|
| {Date} | {X}s | {Y}s | +{Z}s ({percent}% slower) |

**Root Cause:**
- {Analysis of why these runs were slow}

---

## Recommendations

### Option 1: {Keep Current Schedule / Adjust Schedule / Add Dependencies}

**Proposed Change:**
- Current: {HH:MM}
- Proposed: {HH:MM}
- Change: {+/- X minutes}

**Rationale:**
- {Reason 1}
- {Reason 2}
- {Reason 3}

**Risk Assessment:**
- **Risk Level:** Low / Medium / High
- **Upstream Buffer:** {X} minutes ({adequate / insufficient})
- **Downstream Impact:** {description}
- **Failure Risk:** {Low / Medium / High}

**Implementation Steps:**
1. Update Maestro configuration (see Maestro YAML section below)
2. Create pull request in Maestro GitHub repo
3. Deploy to DEV environment for testing
4. Monitor 3 consecutive successful runs
5. Deploy to PROD with rollback plan

**Rollback Plan:**
- If issues detected, revert to current schedule: {HH:MM}
- Estimated rollback time: < 5 minutes
- No data loss or corruption risk

---

## Maestro Configuration (If Changes Needed)

```yaml
{Generated YAML configuration from Step 7}
```

---

## SQL Queries Used

### Query 1: SSIS Execution History
```sql
{SQL query from Step 1a}
```

### Query 2: Dependency Timing Analysis
```sql
{SQL query from Step 2}
```

### Query 3: Performance Statistics
```sql
{SQL query from Step 3}
```

---

## Next Steps

### Immediate Actions
1. [ ] {Action 1}
2. [ ] {Action 2}
3. [ ] {Action 3}

### Follow-up (Post-Implementation)
1. [ ] Monitor success rate for 1 week after change
2. [ ] Verify downstream jobs not impacted
3. [ ] Update runbook documentation with new timing
4. [ ] Close ADO ticket with results

---

## Appendix: Raw Data

### SSIS Execution Log Sample
{Table of recent executions from Step 1}

### Solvas Loader Log Sample (If Applicable)
{Table of Solvas executions from Step 1b}

---

**Report Generated:** {DateTime}  
**Analysis Duration:** {X} minutes  
**Data Sources:** Feeds.dbo.tSSISImportEventLog, Solvas_AM.dbo.Process_Log, feeds.dbo.vGenericImportJob
```

**Action:**
- Generate report with all analysis findings
- Attach to ADO ticket as markdown file
- Save locally to `investigations/` folder
- Include all SQL queries used for reproducibility

---

---

## Example Usage

**User Input:**
```
"Can you resequence the MiddleOfficeTradeLoad job?"
```

**Mossy Response:**
```markdown
## 🎯 Summary
Analyzed MiddleOfficeTradeLoad job scheduling. Current timing is **optimal**.

## 📋 Findings
- Job runs nightly at 02:00 (15-min duration)
- 3 upstream dependencies all complete by 01:52
- 5-minute buffer provides adequate safety margin
- 98% success rate over last 30 days

## ✅ Recommendations
**No changes needed.** Current schedule is well-optimized.

**Optional Optimization:** Could shift 5 minutes earlier to 01:55 for marginal efficiency gain, but current timing is safe and proven.

## 📊 Details
[Detailed analysis saved to: investigations/JobResequencing_MiddleOfficeTradeLoad_20260722.md]
```

---

## Error Handling & Troubleshooting

### Common Issues and Resolutions

#### Issue 1: Job Not Found in SSIS Logs

**Symptom:**
```
❌ No results found for job "{JobName}" in Feeds.dbo.tSSISImportEventLog
```

**Possible Causes:**
1. **Incorrect job name** - SSIS package name doesn't match search pattern
2. **Date range too narrow** - Job hasn't run in the last 7 days
3. **Job type mismatch** - It's a Solvas loader, not an SSIS package

**Resolution:**
```sql
-- Try broader search pattern
SELECT DISTINCT PackageName
FROM [Feeds].[dbo].[tSSISImportEventLog]
WHERE PackageName LIKE '%{partial_name}%'
  AND EventDate >= DATEADD(DAY, -30, GETDATE())
ORDER BY PackageName;

-- Common SSIS package naming patterns:
-- - TradeLoader_SSIS
-- - PricingImport_SSIS
-- - SecuritiesMasterRefresh
-- - PositionDataSync
```

**Suggestion List:**
Did you mean one of these SSIS packages?
- TradeLoader_SSIS
- PricingImport_SSIS
- MarketDataImport
- PortfolioDataSync

---

#### Issue 2: Database Connection Failure

**Symptom:**
```
❌ Cannot connect to MOS Production database (mos-sql-p.mos.siepe.local,52155)
Error: Login failed for user 'DOMAIN\username'
```

**Checklist:**
1. ✅ Database server is online: `mos-sql-p.mos.siepe.local,52155`
2. ✅ You have Windows Integrated Security access to MOS Production
3. ✅ VPN is connected (if working remotely)
4. ✅ SQL Server port 52155 is not blocked by firewall
5. ✅ Account has read permissions on Feeds, Core, Solvas_AM, Reference databases

**Test Connection:**
```powershell
# Test connection to MOS Production
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Feeds" -Q "SELECT @@SERVERNAME, DB_NAME()"
```

**Expected Output:**
```
SERVERNAME       DB_NAME
-----------      -------
MOS-SQL-P        Feeds
```

**Connection Details:**
- See: `MOSSystemConnectionsReference.md` for full connection string details
- Server: mos-sql-p.mos.siepe.local,52155
- Databases: Core, Feeds, Solvas_AM, Reference
- Authentication: Windows Integrated Security

---

#### Issue 3: No Execution History (Job Never Ran)

**Symptom:**
```
⚠️ No execution history found for "{JobName}" in the last 30 days.
```

**Possible Causes:**
1. **New job** - Job was recently added and hasn't executed yet
2. **Manual job** - Job runs on-demand, not on schedule
3. **Disabled job** - Job was disabled in Maestro
4. **Wrong database** - Job logs are in a different location (e.g., Report Subscription logs)

**Resolution:**
1. Check Maestro configuration in GitHub repo to verify job exists and is enabled
2. Check if it's a Report Subscription (RS) or Script Adapter (SA) - different log locations
3. Expand date range to 60-90 days
4. Check Seq logs for job execution evidence: https://seq.siepe.com/

---

#### Issue 4: Solvas Loader Not Found

**Symptom:**
```
❌ No results for Solvas loader "{LoaderName}"
```

**Resolution:**
```sql
-- List all Solvas loaders
SELECT DISTINCT processed_by AS LoaderName
FROM [Solvas_AM].[dbo].[Process_Log]
WHERE start_time >= DATEADD(DAY, -30, GETDATE())
ORDER BY processed_by;

-- Common Solvas loaders:
-- - ASSET_LOADER
-- - TRADE_LOADER
-- - PORTFOLIO_LOADER
```

---

#### Issue 5: Generic Import Job Not Found

**Symptom:**
```
❌ No Generic Import Job found matching "{JobName}"
```

**Resolution:**
```sql
-- List all active Generic Import Jobs
SELECT 
    GenericImportJobID,
    Name,
    SourceFolder
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1  -- Active only
ORDER BY Name;

-- Search by keywords: Sycamore, Markit, ICE, LSEG, Pricing, Trade, Position
```

---

#### Issue 6: Script Adapter Execution History Returns Zero Results

**Symptom:**
```
❌ No execution stats found for Script Adapters in Enterprise.ScriptAdapter.tScriptConfigurationHistory
Query shows: Retrieved execution stats for 0 Script Adapters
```

**Cause:**
The `RefRecStatusID` field in `tScriptConfigurationHistory` uses different values than other tables:
- **WRONG:** `RefRecStatusID = 1` (this is used in tSubscriptionXml for "Active" configuration)
- **CORRECT:** `RefRecStatusID IN (5, 6)` (actual execution records)

**Actual Values in tScriptConfigurationHistory:**
```sql
-- Check what RefRecStatusID values exist
SELECT DISTINCT RefRecStatusID, COUNT(*) AS Total
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE StartTime >= DATEADD(DAY, -30, GETDATE())
GROUP BY RefRecStatusID;

-- Results show:
-- RefRecStatusID = 5: ~108,000 records
-- RefRecStatusID = 6: ~95,000 records
-- RefRecStatusID = 2: ~13 records
```

**Resolution:**
Remove the `RefRecStatusID = 1` filter entirely or change to `RefRecStatusID IN (5, 6)`:

```sql
-- ✅ CORRECT - Get execution statistics without RefRecStatusID filter
SELECT 
    ScriptConfigurationID,
    COUNT(*) AS TotalExecutions,
    MIN(DATEDIFF(SECOND, StartTime, EndTime)) AS MinDurationSeconds,
    MAX(DATEDIFF(SECOND, StartTime, EndTime)) AS MaxDurationSeconds,
    AVG(DATEDIFF(SECOND, StartTime, EndTime)) AS AvgDurationSeconds,
    MAX(StartTime) AS LastExecutionStart,
    MAX(EndTime) AS LastExecutionEnd
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE StartTime >= DATEADD(DAY, -30, GETDATE())
  AND EndTime IS NOT NULL
  -- DO NOT FILTER BY RefRecStatusID = 1
GROUP BY ScriptConfigurationID;
```

**Key Points:**
- ✅ `tScriptConfigurationHistory` logs **all executions** regardless of success/failure
- ✅ Filter by `StartTime` and `EndTime IS NOT NULL` for completed runs
- ❌ Do NOT filter by `RefRecStatusID = 1` (this returns zero results)
- ✅ If you need to filter by status, use `RefRecStatusID IN (5, 6)` for active executions
- ✅ Expected result: ~200+ Script Adapters with execution history in last 30 days

**PipeWatch Integration:**
The Python script `add_execution_timing.py` previously had this bug:
```python
# ❌ WRONG - Returns zero results
WHERE RefRecStatusID = 1  -- Active/Success only

# ✅ FIXED - Returns 200+ Script Adapters
WHERE StartTime >= DATEADD(DAY, -30, GETDATE())
  AND EndTime IS NOT NULL
```

After removing the incorrect filter, PipeWatch successfully enriched **236 jobs** with timing data from **206 Script Adapters** (25.8% coverage).

---

---

## PipeWatch Job Status Checking

### Purpose
Check if a job ran successfully on a specific date using the PipeWatch/MOS Dashboard stored procedure.

### When to Use
- User asks "did the AOD CashFlow Report run on 2026-07-26?"
- User asks "check if subscription 500001979 ran yesterday"
- User wants to verify if a job completed successfully for a specific business date
- Investigating missing reports or data for a specific date

### Method 1: Query Job Research by Subscription ID

**Stored Procedure:**
```sql
-- Get complete job sequence for a Report Subscription
EXEC [Dashboard].[pJobResearch] @ReportSubscriptionID = '{SubscriptionID}'
```

**Parameters:**
- `{SubscriptionID}` - Report Subscription ID (e.g., 500001979, 500001311)

**Example:**
```sql
-- Check AOD CashFlow Report sequence (subscription 500001979)
EXEC [Dashboard].[pJobResearch] @ReportSubscriptionID = '500001979'
```

**Expected Output:**
```
JobSequence  JobType           JobName                           JobID      Status    StartTime            EndTime              Duration
-----------  ----------------  --------------------------------  ---------  --------  -------------------  -------------------  --------
1            EmailAdapter      AOD CashFlow Report - Receive     1234       Success   2026-07-26 06:15:00  2026-07-26 06:15:30  30
2            ScriptAdapter     AOD CashFlow Data Processor       5678       Success   2026-07-26 06:16:00  2026-07-26 06:18:00  120
3            ReportSubscription AOD CashFlow Report              500001979  Success   2026-07-26 06:19:00  2026-07-26 06:22:00  180
4            EmailAdapter      AOD CashFlow Report - Send        1235       Success   2026-07-26 06:22:30  2026-07-26 06:23:00  30
```

**Analysis:**
- **All steps Success:** ✅ Job completed successfully
- **Any step Failed:** ❌ Job sequence failed - investigate the failed step
- **Missing steps:** ⚠️ Job may not have been triggered

### Method 2: Query by Report Subscription Name

**Query:**
```sql
-- Find subscription ID by name pattern
SELECT 
    rs.SubscriptionID,
    rs.Name AS JobName,
    rs.Description
FROM 
    Core.Report.tSubscriptionXml rs
WHERE 
    rs.RefRecStatusID = 1
    AND rs.Name LIKE '%{JobNamePattern}%'
ORDER BY 
    rs.Name;
```

**Example:**
```sql
-- Find AOD CashFlow Report subscription
SELECT 
    rs.SubscriptionID,
    rs.Name AS JobName,
    rs.Description
FROM 
    Core.Report.tSubscriptionXml rs
WHERE 
    rs.RefRecStatusID = 1
    AND rs.Name LIKE '%AOD%CashFlow%'
ORDER BY 
    rs.Name;
```

**Then use the SubscriptionID with pJobResearch:**
```sql
EXEC [Dashboard].[pJobResearch] @ReportSubscriptionID = '500001979'
```

### Method 3: Check Job Execution for Specific Date

**Query:**
```sql
-- Check if SSIS job ran on specific date
SELECT 
    ssis.PackageName,
    ssis.EventDate,
    CASE 
        WHEN ssis.EventType IN ('PackageEnd', 'OnPostExecute') AND ssis.EventCode = 0 THEN 'Success'
        WHEN ssis.EventType IN ('OnError', 'PackageError') OR ssis.EventCode <> 0 THEN 'Failed'
        WHEN ssis.EventType IN ('PackageStart', 'OnPreExecute') THEN 'Running'
        ELSE 'Warning'
    END AS Status,
    COALESCE(ssis.PackageDuration, ssis.ContainerDuration) AS DurationSeconds,
    ssis.InsertCount AS RecordsProcessed,
    ssis.EventDescription AS ErrorMessage
FROM [Feeds].[dbo].[tSSISImportEventLog] ssis
WHERE ssis.PackageName LIKE '%{PackageName}%'
  AND CAST(ssis.EventDate AS DATE) = '{TargetDate}'
  AND ssis.EventType IN ('PackageEnd', 'OnPostExecute', 'OnError', 'PackageError')
ORDER BY ssis.EventDate DESC;
```

**Parameters:**
- `{PackageName}` - SSIS package name pattern
- `{TargetDate}` - Target date in format YYYY-MM-DD (e.g., '2026-07-26')

**Example:**
```sql
-- Did TradeLoader run successfully on 2026-07-26?
SELECT 
    ssis.PackageName,
    ssis.EventDate,
    CASE 
        WHEN ssis.EventType IN ('PackageEnd', 'OnPostExecute') AND ssis.EventCode = 0 THEN 'Success'
        WHEN ssis.EventType IN ('OnError', 'PackageError') OR ssis.EventCode <> 0 THEN 'Failed'
        ELSE 'Warning'
    END AS Status,
    COALESCE(ssis.PackageDuration, ssis.ContainerDuration) AS DurationSeconds,
    ssis.EventDescription AS ErrorMessage
FROM [Feeds].[dbo].[tSSISImportEventLog] ssis
WHERE ssis.PackageName LIKE '%TradeLoader%'
  AND CAST(ssis.EventDate AS DATE) = '2026-07-26'
  AND ssis.EventType IN ('PackageEnd', 'OnPostExecute', 'OnError')
ORDER BY ssis.EventDate DESC;
```

### Method 4: Check via PipeWatch Web UI

**PipeWatch Dashboard:**
- **URL:** http://localhost:8000 (local) or http://pipewatch.mos.siepe.local (production)
- **Search:** Use search box to find job by name, subscription ID, or keyword
- **Timeline View:** Check time slot containers to see when jobs ran
- **Job Details:** Click "View Details →" to see subscription ID, file paths, execution history

**Steps:**
1. Open PipeWatch dashboard
2. Search for job name (e.g., "AOD CashFlow") or subscription ID (e.g., "500001979")
3. Locate job in timeline or search results
4. Check execution status indicators:
   - ✅ Green - Successful
   - ❌ Red - Failed
   - ⏳ Yellow - Running
   - ⚪ Gray - Not run yet
5. Click job for detailed execution logs and error messages

### Method 5: Check LogBook Entries (Report Subscription Execution Logs)

**Purpose:** Query the Enterprise LogBook to find when Report Subscriptions ran successfully by checking for completion messages.

**Query:**
```sql
-- Check if Report Subscription ran successfully on specific date
SELECT 
    EntryDateTime,
    ExceptionMessage,
    MachineName,
    UserName
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%{PublishMessage}%'
    AND CONVERT(DATE, EntryDateTime) = '{TargetDate}'
ORDER BY EntryDateTime DESC
```

**Parameters:**
- `{PublishMessage}` - The publish message from the job sequence (e.g., 'ReportSubscription.Geneva.FileShare.Completed.Balances', 'SFTP.Diameter.HedgeServ.BankLoans')
- `{TargetDate}` - Target date in format MM/DD/YYYY (e.g., '07/26/2026')

**Example 1: Check Geneva Balances Report**
```sql
SELECT 
    EntryDateTime,
    ExceptionMessage,
    MachineName
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%ReportSubscription.Geneva.FileShare.Completed.Balances%'
    AND CONVERT(DATE, EntryDateTime) = '07/26/2026'
ORDER BY EntryDateTime DESC
```

**Expected Output (Success):**
```
EntryDateTime                ExceptionMessage                                                     MachineName
---------------------------  ------------------------------------------------------------------  ------------
2026-07-26 14:32:15.123     ReportSubscription.Geneva.FileShare.Completed.Balances              MOS-APP-01
2026-07-26 14:32:10.456     Processing ReportSubscription.Geneva.FileShare.Completed.Balances   MOS-APP-01
```

**Example 2: Check Diameter HedgeServe BankLoan**
```sql
SELECT 
    EntryDateTime,
    ExceptionMessage,
    MachineName
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%SFTP.Diameter.HedgeServ.BankLoans%'
    AND CONVERT(DATE, EntryDateTime) = '07/26/2026'
ORDER BY EntryDateTime DESC
```

**How to Find Publish Message:**
1. Use `Dashboard.pJobResearch` to get job sequence
2. Look at the `PublishMessage` column for the ReportSubscription step
3. Use that message in the LogBook query

**Interpretation:**
- **Records found:** ✅ Job ran successfully on that date
- **No records found:** ❌ Job did not run or failed before publishing completion message
- **Multiple records:** Job may have run multiple times (check timestamps)

**Use Cases:**
- Verify Report Subscription execution when SSIS logs don't show the job
- Check execution history for event-driven jobs (not scheduled)
- Confirm message publishing for downstream job triggering
- Audit trail for compliance and troubleshooting

### Method 6: Find Job Failures and Execution Statistics

**Purpose:** Identify when jobs failed, analyze failure patterns, and calculate success rates for Report Subscriptions.

#### 6a. Check for Failed Executions (Report Subscriptions)

**Query to find jobs with Status=False:**
```sql
-- Find failed Report Subscription executions
SELECT 
    EntryDateTime,
    SUBSTRING(ExceptionMessage, 1, 200) AS Message
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%Subscription with Id {SubscriptionID}%'
    AND ExceptionMessage LIKE '%@Status=False%'
ORDER BY EntryDateTime DESC
```

**Example:**
```sql
-- Find failures for subscription 500001147
SELECT 
    EntryDateTime,
    SUBSTRING(ExceptionMessage, 1, 200) AS Message
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%500001147%'
    AND ExceptionMessage LIKE '%@Status=False%'
ORDER BY EntryDateTime DESC
```

**Interpretation:**
- **No results:** Job has never failed (100% success rate)
- **Results found:** Shows exact date/time of failures with error details

#### 6b. Check for Delivery Errors

**Query to find delivery failures:**
```sql
-- Find failed deliveries (noErrorOnDelivery:False)
SELECT 
    EntryDateTime,
    SUBSTRING(ExceptionMessage, 1, 200) AS Message
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%Subscription Id {SubscriptionID}%'
    AND ExceptionMessage LIKE '%noErrorOnDelivery:False%'
ORDER BY EntryDateTime DESC
```

#### 6c. Calculate Execution Statistics

**Query to get total execution count:**
```sql
-- Count total successful executions
SELECT COUNT(*) AS TotalSuccessfulExecutions
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%Subscription with Id {SubscriptionID} Completed%'
```

**Query to get execution date range:**
```sql
-- Get first and last execution dates
SELECT 
    MIN(EntryDateTime) AS FirstExecution,
    MAX(EntryDateTime) AS LastExecution,
    DATEDIFF(DAY, MIN(EntryDateTime), MAX(EntryDateTime)) AS DaysSpanned
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%Subscription with Id {SubscriptionID} Completed%'
```

**Example: Complete execution analysis for subscription 500001147:**
```sql
-- Combined query for comprehensive execution statistics
WITH Executions AS (
    SELECT 
        EntryDateTime,
        CASE 
            WHEN ExceptionMessage LIKE '%@Status=True%' THEN 1
            ELSE 0
        END AS IsSuccess
    FROM Enterprise.dbo.tLogBookEntry
    WHERE ExceptionMessage LIKE '%500001147%'
        AND ExceptionMessage LIKE '%pSubscriptionHistoryI%'
)
SELECT 
    COUNT(*) AS TotalExecutions,
    SUM(IsSuccess) AS SuccessfulExecutions,
    COUNT(*) - SUM(IsSuccess) AS FailedExecutions,
    CAST(SUM(IsSuccess) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS SuccessRatePercent,
    MIN(EntryDateTime) AS FirstExecution,
    MAX(EntryDateTime) AS LastExecution,
    DATEDIFF(DAY, MIN(EntryDateTime), MAX(EntryDateTime)) AS DaysSpanned
FROM Executions
```

**Expected Output:**
```
TotalExecutions  SuccessfulExecutions  FailedExecutions  SuccessRatePercent  FirstExecution           LastExecution
---------------  --------------------  ----------------  ------------------  -----------------------  -----------------------
68               68                    0                 100.00              2026-06-10 09:45:10.877  2026-07-27 09:45:16.713
```

#### 6d. Find All Error Messages Related to a Job

**Query to find any error/exception messages:**
```sql
-- Search for error messages related to subscription
SELECT 
    EntryDateTime,
    SUBSTRING(ExceptionMessage, 1, 250) AS ErrorMessage,
    MachineName
FROM Enterprise.dbo.tLogBookEntry
WHERE (ExceptionMessage LIKE '%{SubscriptionID}%' 
       OR ExceptionMessage LIKE '%{JobName}%'
       OR ExceptionMessage LIKE '%{PublishMessage}%')
    AND (ExceptionMessage LIKE '%error%' 
         OR ExceptionMessage LIKE '%fail%' 
         OR ExceptionMessage LIKE '%exception%'
         OR ExceptionMessage LIKE '%@Status=False%')
    AND EntryDateTime >= DATEADD(DAY, -90, GETDATE())
ORDER BY EntryDateTime DESC
```

**Example for Diameter HedgeServe BankLoan:**
```sql
SELECT 
    EntryDateTime,
    SUBSTRING(ExceptionMessage, 1, 250) AS ErrorMessage
FROM Enterprise.dbo.tLogBookEntry
WHERE (ExceptionMessage LIKE '%500001147%' 
       OR ExceptionMessage LIKE '%SFTP.Diameter.HedgeServ.BankLoans%'
       OR ExceptionMessage LIKE '%Diameter_HedgeServ_BankLoans%')
    AND (ExceptionMessage LIKE '%error%' 
         OR ExceptionMessage LIKE '%fail%' 
         OR ExceptionMessage LIKE '%exception%'
         OR ExceptionMessage LIKE '%@Status=False%')
    AND EntryDateTime >= DATEADD(DAY, -90, GETDATE())
ORDER BY EntryDateTime DESC
```

#### 6e. Analyze Execution Patterns

**Query to find execution gaps (missing days):**
```sql
-- Find days with no executions (potential skipped days or failures)
WITH ExecutionDates AS (
    SELECT DISTINCT CAST(EntryDateTime AS DATE) AS ExecutionDate
    FROM Enterprise.dbo.tLogBookEntry
    WHERE ExceptionMessage LIKE '%Subscription with Id {SubscriptionID} Completed%'
),
DateRange AS (
    SELECT DATEADD(DAY, n, (SELECT MIN(ExecutionDate) FROM ExecutionDates)) AS ExpectedDate
    FROM (SELECT TOP 100 ROW_NUMBER() OVER (ORDER BY object_id) - 1 AS n 
          FROM sys.objects) nums
    WHERE DATEADD(DAY, n, (SELECT MIN(ExecutionDate) FROM ExecutionDates)) <= (SELECT MAX(ExecutionDate) FROM ExecutionDates)
)
SELECT dr.ExpectedDate AS MissingDate
FROM DateRange dr
LEFT JOIN ExecutionDates ed ON dr.ExpectedDate = ed.ExecutionDate
WHERE ed.ExecutionDate IS NULL
    AND DATEPART(WEEKDAY, dr.ExpectedDate) NOT IN (1, 7)  -- Exclude weekends
ORDER BY dr.ExpectedDate
```

#### 6f. Response Template for Failure Analysis

**When failures are found:**
```markdown
❌ **Failures Detected**

**Total Executions:** {X}  
**Failed Executions:** {Y}  
**Success Rate:** {Z}%  

**Recent Failures:**
| Date | Time | Error Message |
|------|------|---------------|
| 2026-07-20 | 09:45:15 | {error detail} |
| 2026-07-15 | 09:45:12 | {error detail} |

**Failure Pattern:**
- {Analysis of when failures occur}
- {Common error themes}
- {Potential root causes}

**Next Steps:**
Would you like me to investigate these failures using the check-ssis-errors skill?
```

**When no failures are found:**
```markdown
✅ **Perfect Success Record**

**Total Executions:** {X}  
**Failed Executions:** 0  
**Success Rate:** 100%  
**First Execution:** {date}  
**Last Execution:** {date}  

This job has **never failed** since deployment and maintains a perfect reliability record.
```

---

## Job Sequence Rebuilding

### Purpose
Rebuild or resequence a job workflow when jobs need to be reordered, added, or removed from a sequence.

### When to Use
- User asks "resequence the AOD CashFlow Report"
- User asks "rebuild the sequence for subscription 500001979"
- Jobs are running in wrong order causing failures
- Need to add new job to existing sequence
- Need to remove deprecated job from sequence

### Understanding Job Sequences

**Job Sequence Components:**
1. **EmailAdapter (Receive)** - Receives input file via email
2. **ScriptAdapter** - Processes/transforms data from file
3. **ReportSubscription** - Generates report from processed data
4. **EmailAdapter (Send)** - Delivers report via email

**Typical Sequence Flow:**
```
EmailAdapter (Receive File)
    ↓ (publishes: "AOD.CashFlow.FileReceived")
ScriptAdapter (Process Data)
    ↓ (publishes: "AOD.CashFlow.DataProcessed")
ReportSubscription (Generate Report)
    ↓ (publishes: "AOD.CashFlow.ReportGenerated")
EmailAdapter (Send Report)
```

### Step 1: Research Current Sequence

**Query:**
```sql
-- Get current job sequence for a subscription
EXEC [Dashboard].[pJobResearch] @ReportSubscriptionID = '{SubscriptionID}'
```

**Example Output:**
```
JobSequence  JobType           JobName                           ListenMessage                 PublishMessage
-----------  ----------------  --------------------------------  ----------------------------  -----------------------------
1            EmailAdapter      AOD CashFlow - Receive            (trigger)                     AOD.CashFlow.FileReceived
2            ScriptAdapter     AOD CashFlow Processor            AOD.CashFlow.FileReceived     AOD.CashFlow.DataProcessed
3            ReportSubscription AOD CashFlow Report              AOD.CashFlow.DataProcessed    AOD.CashFlow.ReportGenerated
4            EmailAdapter      AOD CashFlow - Send               AOD.CashFlow.ReportGenerated  (end)
```

**Document Current State:**
- Note all job IDs, types, and message dependencies
- Identify problematic jobs or gaps in sequence
- Check for circular dependencies or missing links

### Step 2: Identify Required Changes

**Common Resequencing Scenarios:**

#### Scenario A: Job Running Too Early
```
Problem: ScriptAdapter runs before EmailAdapter finishes
Current: ScriptAdapter listens to "AOD.CashFlow.FileReceived"
Issue: File might not be fully written when ScriptAdapter starts

Solution: Add buffer or change to explicit dependency
```

#### Scenario B: Missing Dependency
```
Problem: Report generates before data is validated
Current: ReportSubscription listens to "AOD.CashFlow.DataProcessed"
Missing: Data validation step

Solution: Insert new ScriptAdapter for validation between steps 2-3
```

#### Scenario C: Wrong Publish/Listen Messages
```
Problem: Job 3 never triggers because Job 2 publishes wrong message
Current: Job 2 publishes "AOD.CashFlow.Complete" but Job 3 listens for "AOD.CashFlow.DataProcessed"

Solution: Update Job 2 to publish correct message
```

### Step 3: Update Job Configuration in Maestro

**Maestro Configuration Files:**
- **Location:** https://github.com/siepe-software/maestro
- **File Format:** YAML or JSON
- **Job Types:** EmailAdapter, ScriptAdapter, ReportSubscription, SSIS

**Example Maestro Job Configuration:**
```yaml
jobs:
  - name: "AOD CashFlow - Receive"
    type: "EmailAdapter"
    tool_id: 1234
    schedule: "0 6 * * *"  # 06:00 daily
    listen: null  # Triggered by email arrival
    publish: "AOD.CashFlow.FileReceived"
    
  - name: "AOD CashFlow Processor"
    type: "ScriptAdapter"
    tool_id: 5678
    schedule: null  # Event-driven
    listen: "AOD.CashFlow.FileReceived"
    publish: "AOD.CashFlow.DataProcessed"
    dependencies:
      - "AOD CashFlow - Receive"  # Explicit dependency
    
  - name: "AOD CashFlow Report"
    type: "ReportSubscription"
    tool_id: 500001979
    schedule: null  # Event-driven
    listen: "AOD.CashFlow.DataProcessed"
    publish: "AOD.CashFlow.ReportGenerated"
    dependencies:
      - "AOD CashFlow Processor"
    
  - name: "AOD CashFlow - Send"
    type: "EmailAdapter"
    tool_id: 1235
    schedule: null  # Event-driven
    listen: "AOD.CashFlow.ReportGenerated"
    publish: null  # End of sequence
    dependencies:
      - "AOD CashFlow Report"
```

**Key Fields to Verify:**
- `listen` - Message this job waits for (null for triggers)
- `publish` - Message this job sends when complete
- `dependencies` - Explicit job names that must complete first
- `schedule` - Cron expression (null for event-driven jobs)
- `tool_id` - ID from MOS database (EmailAdapter.MessageConfigurationID, ScriptAdapter.ScriptConfigurationID, Report.SubscriptionID)

### Step 4: Make Changes in Maestro

**Process:**
1. Clone Maestro repository: `git clone https://github.com/siepe-software/maestro.git`
2. Create feature branch: `git checkout -b job-resequencing/aod-cashflow-{YYYYMMDD}`
3. Edit job configuration file (YAML/JSON)
4. Validate YAML syntax: `yamllint config/jobs/aod_cashflow.yaml`
5. Commit changes: `git commit -m "Resequence AOD CashFlow Report - Fix timing issue #85498"`
6. Push branch: `git push origin job-resequencing/aod-cashflow-{YYYYMMDD}`
7. Create pull request in GitHub
8. Request review from DevOps team
9. Deploy to DEV environment for testing
10. Deploy to PROD after successful DEV validation

### Step 5: Verify Sequence After Changes

**Verification Checklist:**
- [ ] All jobs have correct listen/publish messages
- [ ] No circular dependencies (Job A → Job B → Job A)
- [ ] No orphaned jobs (jobs with no listener for their publish message)
- [ ] Schedule conflicts resolved (no resource contention)
- [ ] Buffer time adequate between steps (5+ minutes recommended)
- [ ] Downstream jobs won't be delayed beyond acceptable thresholds

**Test in DEV Environment:**
```sql
-- Trigger job sequence manually in DEV
EXEC [Dashboard].[pTriggerJobSequence] 
    @ReportSubscriptionID = '{SubscriptionID}',
    @Environment = 'DEV',
    @TestDate = '2026-07-27'
```

**Monitor Execution:**
```sql
-- Check execution status
EXEC [Dashboard].[pJobResearch] @ReportSubscriptionID = '{SubscriptionID}'

-- Expected output shows all jobs in correct order with Success status
```

### Step 6: Document Changes

**Create Investigation Report:**
```markdown
## Job Resequencing: AOD CashFlow Report (Subscription 500001979)

### Changes Made
- Updated ScriptAdapter "AOD CashFlow Processor" to wait for explicit file write completion
- Changed listen message from "AOD.CashFlow.FileReceived" to "AOD.CashFlow.FileReceived.Validated"
- Added 5-minute buffer between EmailAdapter and ScriptAdapter

### Rationale
- Previous sequence had race condition: ScriptAdapter started before file was fully written
- 15% failure rate correlated with file access errors
- New sequence adds file validation step to confirm file is ready

### Testing Results
- DEV testing: 10/10 successful runs
- PROD monitoring: 100% success rate after deployment (7 days, 7 runs)

### Rollback Plan
- Revert listen message to "AOD.CashFlow.FileReceived"
- Estimated rollback time: < 5 minutes
```

---

## Investigating Failed Jobs

### When a Job Fails

If a job status check reveals failures, use the **check-ssis-errors** skill to investigate:

**Invocation:**
```
"Check SSIS errors for TradeLoader on 2026-07-26"
"Investigate why AOD CashFlow Report failed yesterday"
"Analyze SSIS package errors for subscription 500001979"
```

**The check-ssis-errors skill will:**
1. Query Seq logs for error messages and stack traces
2. Analyze SSIS execution logs from Feeds.dbo.tSSISImportEventLog
3. Check database state for data issues (missing records, constraint violations)
4. Investigate pipeline errors (lookup failures, data flow issues, schema mismatches)
5. Provide root cause analysis and remediation steps

### Integration with Investigation Skills

**Available Investigation Skills:**
- **check-ssis-errors** - SSIS package failure diagnosis
- **bulk-price-validation** - Price exception investigation
- **remove-process-dashboard-reports** - Dashboard report cleanup

**Workflow:**
1. **Check job status** (this skill) → Identify which job failed and when
2. **Investigate failure** (check-ssis-errors) → Find root cause
3. **Fix issue** → Apply remediation (data fix, config change, resequencing)
4. **Verify fix** (this skill) → Confirm job now runs successfully
5. **Document** → Update runbook with findings and prevention steps

**Example Integration:**
```
User: "Did the AOD CashFlow Report run on 2026-07-26?"
Mossy: [Runs job status check using pJobResearch]
      ❌ AOD CashFlow Report failed at step 2 (ScriptAdapter)
      
User: "Why did it fail?"
Mossy: [Invokes check-ssis-errors skill]
      🔍 Root Cause: File access error - source file was locked by another process
      💡 Solution: Add retry logic with 30-second delay
      
User: "Can you resequence it to prevent this?"
Mossy: [Uses job-resequencing procedures from this skill]
      ✅ Updated sequence with file validation step and retry logic
      📋 Testing in DEV environment...
```

---

## Reference Links

- **Maestro GitHub:** https://github.com/siepe-software/maestro
- **MOS System Connections:** MOSSystemConnectionsReference.md
- **Seq Logs:** https://seq.siepe.com/
- **Job Management Portal:** https://portal.mos.siepe.local/jobManagement
- **PipeWatch Dashboard:** http://localhost:8000 (local) or http://pipewatch.mos.siepe.local (production)
- **Related Skills:** 
  - `check-ssis-errors` - Diagnose SSIS package failures, PowerShell script errors, ETL job issues
  - `bulk-price-validation` - Investigate price exceptions and vendor pricing issues
  - `remove-process-dashboard-reports` - Clean up dashboard reports

---

## Tools Used

- **Database Queries:** SQL Server queries via `run_in_terminal` with sqlcmd
- **File Operations:** `create_file` for saving reports and Maestro configurations
- **Date Calculations:** PowerShell `Get-Date` for timing analysis
- **Text Analysis:** `grep_search` for finding job patterns in logs

---

## Success Criteria

✅ Job identified correctly (SSIS, Solvas, or Generic Import Job)  
✅ Execution history retrieved (last 7-30 days)  
✅ Dependencies inferred from execution timing patterns  
✅ Performance statistics calculated (avg duration, success rate, outliers)  
✅ Optimal start time calculated with risk assessment  
✅ Recommendations provided (keep schedule / adjust / add dependencies)  
✅ Maestro YAML configuration generated (if changes needed)  
✅ Comprehensive analysis report created and saved to investigations/  
✅ All SQL queries documented for reproducibility

---

**Remember:** Always prioritize **data availability** and **dependency completion** over aggressive optimization. A stable pipeline is better than a fast but fragile one! 🌿
