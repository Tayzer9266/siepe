---
skill_name: job-execution-duration
title: Job Execution Duration Analysis
description: Look up how long a MOS job takes to run by analyzing Script Adapter execution history through Enterprise.ScriptAdapter.tScriptConfigurationHistory table or pub/sub message timestamps in the Enterprise log book. Calculates duration between trigger message receipt and completion message publication.
version: 1.1
database: mos-prod (Enterprise, Core)
output_format: text
last_updated: 2026-07-28
apply_to:
  - pattern: "**/*"
    when_user_mentions:
      - "how long"
      - "duration"
      - "execution time"
      - "runtime"
      - "performance"
      - "last successful"
      - "when did it run"
      - "job history"
---

# Job Execution Duration Analysis Skill

## Purpose

This skill provides execution duration and timing information for MOS jobs (Report Subscriptions and Script Adapters) by analyzing:
1. **Script Adapters**: Direct execution logs in `Enterprise.ScriptAdapter.tScriptConfigurationHistory` (preferred method)
2. **Report Subscriptions**: Pub/sub message timestamps in `Enterprise.dbo.tLogBookEntry`

---

## When to Use

- User asks "how long does job X take to run?"
- User asks "when did job Y last run successfully?"
- User needs to know the execution duration of a Script Adapter
- User wants to see execution history for a job
- Performance analysis of job runtimes

---

## Input Requirements

You need ONE of the following identifiers:
1. **Script Adapter ID** (tool_id) - e.g., 1422
2. **Report Subscription ID** - e.g., 500002455
3. **Job Name** - e.g., "Solvas Position Import"

If given a Report Subscription, look up its associated Script Adapter child jobs first.

---

## Step 1: Identify Job Type

Determine if the job is:
1. **Script Adapter** (tool_id or ScriptConfigurationID) - Use execution history table
2. **Report Subscription** (subscription_id) - Use pub/sub messages

### Get Script Adapter Configuration

```sql
-- Get Script Adapter configuration (use tool_id from PipeWatch or direct ScriptConfigurationID)
SELECT 
    ScriptConfigurationID,
    Name,
    Description,
    PubSubSubject,      -- Message the job LISTENS for (trigger/start)
    CompletionPubSub,   -- Message the job PUBLISHES when done (completion)
    ScriptPath,
    TimeOut,
    AllowConcurrent,
    CreatedDate,
    CreatedUser
FROM Enterprise.ScriptAdapter.vScriptConfigurationActive
WHERE ScriptConfigurationID = <SCRIPT_ADAPTER_ID>;
```

---

## Step 2A: Script Adapter Execution History (PREFERRED METHOD)

**Use this for Script Adapters - it's faster and more reliable!**

The `Enterprise.ScriptAdapter.tScriptConfigurationHistory` table logs ALL Script Adapter executions with precise StartTime and EndTime.

### Get Recent Executions with Duration

```sql
-- Get last 10 executions for a Script Adapter with calculated durations
SELECT TOP 10
    ScriptConfigurationID,
    StartTime,
    EndTime,
    DATEDIFF(SECOND, StartTime, EndTime) AS DurationSeconds,
    CONCAT(
        DATEDIFF(SECOND, StartTime, EndTime) / 60, ' min ',
        DATEDIFF(SECOND, StartTime, EndTime) % 60, ' sec'
    ) AS FormattedDuration,
    JobDetail
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE ScriptConfigurationID = <SCRIPT_ADAPTER_ID>
  AND StartTime >= DATEADD(DAY, -7, GETDATE())  -- Last 7 days
ORDER BY StartTime DESC;
```

### Get Today's Executions

```sql
-- Get all executions for today
SELECT 
    ScriptConfigurationID,
    StartTime,
    EndTime,
    DATEDIFF(SECOND, StartTime, EndTime) AS DurationSeconds,
    JobDetail
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE ScriptConfigurationID = <SCRIPT_ADAPTER_ID>
  AND CAST(StartTime AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY StartTime DESC;
```

### Get Execution Statistics

```sql
-- Get min, max, avg execution times for last 30 days
SELECT 
    ScriptConfigurationID,
    COUNT(*) AS TotalExecutions,
    MIN(DATEDIFF(SECOND, StartTime, EndTime)) AS MinSeconds,
    MAX(DATEDIFF(SECOND, StartTime, EndTime)) AS MaxSeconds,
    AVG(DATEDIFF(SECOND, StartTime, EndTime)) AS AvgSeconds,
    CONCAT(
        AVG(DATEDIFF(SECOND, StartTime, EndTime)) / 60, ' min ',
        AVG(DATEDIFF(SECOND, StartTime, EndTime)) % 60, ' sec'
    ) AS AvgFormattedDuration
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE ScriptConfigurationID = <SCRIPT_ADAPTER_ID>
  AND StartTime >= DATEADD(DAY, -30, GETDATE())
GROUP BY ScriptConfigurationID;
```

**Table Schema:**
- `ScriptConfigurationHistoryID`: Unique execution ID
- `ScriptConfigurationID`: Script Adapter ID (tool_id in PipeWatch)
- `StartTime`: When the script started executing
- `EndTime`: When the script completed
- `JobDetail`: Execution details/parameters
- `CreatedDate`: When this log entry was created
- `CreatedUser`: User/service that ran the script
- `RefRecStatusID`: Status code (typically 5 or 6 for execution records; do NOT filter by RefRecStatusID = 1)

---

## Step 2B: Report Subscription Execution via Pub/Sub Messages (FALLBACK METHOD)

**Use this for Report Subscriptions or when Script Adapter doesn't have execution history logs.**

This method relies on pub/sub messages logged in `Enterprise.dbo.tLogBookEntry`.

### Find Job Start Time (Trigger Message Received)

```sql
-- Find when the job was triggered (received its PubSubSubject message)
SELECT TOP 5
    EntryDateTime AS StartTime,
    CAST(ExceptionMessage AS VARCHAR(500)) AS Message
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%<PubSubSubject>%'
  AND ExceptionMessage LIKE '%Received message to check on event jobs%'
ORDER BY EntryDateTime DESC;
```

### Find Job Completion Time (Completion Message Published)

```sql
-- Find when the job completed (published its CompletionPubSub message)
SELECT TOP 5
    EntryDateTime AS CompletionTime,
    CAST(ExceptionMessage AS VARCHAR(500)) AS Message
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%<CompletionPubSub>%'
  AND ExceptionMessage LIKE '%Published message%'
ORDER BY EntryDateTime DESC;
```

---

## Step 3: Calculate Duration

### Match Start/Completion Pairs

For each execution, match the trigger message timestamp with the next completion message timestamp:

```sql
-- Find matched start/completion pairs with duration calculation
WITH Triggers AS (
    SELECT 
        EntryDateTime AS StartTime,
        ROW_NUMBER() OVER (ORDER BY EntryDateTime DESC) AS RowNum
    FROM Enterprise.dbo.tLogBookEntry
    WHERE ExceptionMessage LIKE '%<PubSubSubject>%'
      AND ExceptionMessage LIKE '%Received message to check on event jobs%'
      AND EntryDateTime >= DATEADD(DAY, -7, GETDATE())
),
Completions AS (
    SELECT 
        EntryDateTime AS CompletionTime,
        ROW_NUMBER() OVER (ORDER BY EntryDateTime DESC) AS RowNum
    FROM Enterprise.dbo.tLogBookEntry
    WHERE ExceptionMessage LIKE '%<CompletionPubSub>%'
      AND ExceptionMessage LIKE '%Published message%'
      AND EntryDateTime >= DATEADD(DAY, -7, GETDATE())
)
SELECT TOP 10
    t.StartTime,
    c.CompletionTime,
    DATEDIFF(SECOND, t.StartTime, c.CompletionTime) AS DurationSeconds,
    DATEDIFF(MINUTE, t.StartTime, c.CompletionTime) AS DurationMinutes,
    CONCAT(
        DATEDIFF(MINUTE, t.StartTime, c.CompletionTime), ' min ',
        DATEDIFF(SECOND, t.StartTime, c.CompletionTime) % 60, ' sec'
    ) AS FormattedDuration
FROM Triggers t
INNER JOIN Completions c ON t.RowNum = c.RowNum
WHERE c.CompletionTime > t.StartTime
ORDER BY t.StartTime DESC;
```

---

## Step 3: Report Results

### Example Output for Script Adapter (using tScriptConfigurationHistory)

```
Script Adapter 1537: "Move CashFlow source files"

Script Path: C:\Siepe\Data\Scripts\PROD\Move_CashFlowSourceFiles_ToUniqueFolders.ps1

Last Execution:
- Date: July 28, 2026
- Start Time: 2:23:32 AM
- End Time: 2:23:35 AM
- Duration: 3 seconds

Recent Executions (today):
- 2:23:32 AM → 2:23:35 AM: 3 sec
- 2:23:27 AM → 2:23:30 AM: 3 sec
- 2:23:24 AM → 2:23:26 AM: 2 sec
- 2:23:19 AM → 2:23:22 AM: 3 sec

Typical Duration: 2-3 seconds
Execution Count (last 7 days): 15 runs
```

### Example Output for Report Subscription (using pub/sub messages)

```
Report Subscription 500001979: "AOD CashFlow Report"

Last Execution:
- Date: July 28, 2026
- Start Time: 2:23:29 AM
- End Time: 2:23:32 AM
- Duration: 3 seconds

Trigger Message: Cashflow.AOD
Completion Message: ReportSubscription.Move.CashFlowSourceFiles

Recent Executions (last 7 days):
- Typically runs in 3-25 seconds
- Occasionally takes up to 20 minutes (1,241 seconds) during heavy load
```

### Example Output for Script Adapter with Pub/Sub (fallback method)

```
Script Adapter Job 1422: "Solvas Position Import,Normalize,Push - After Aristotle prices"

Script Path: C:\Siepe\Data\Scripts\PROD\SolvasPortfolio_PositionOnly_CurrentDay.ps1

Last Successful Execution:
- Date: July 27, 2026
- Start Time: 9:30:04 PM
- End Time: 10:00:00 PM
- Duration: 29 minutes 56 seconds (~30 minutes)

Trigger Message: ScriptAdapter.CVET.RestructurePriceLoader.C-0
Completion Message: ScriptAdapter.AristotleEODPricing.Run
```

---

## Alternative: Query Recent Executions with Duration

```sql
-- Get last 10 executions with calculated durations
DECLARE @PubSubSubject NVARCHAR(500) = 'ScriptAdapter.CVET.RestructurePriceLoader.C-0';
DECLARE @CompletionPubSub NVARCHAR(500) = 'ScriptAdapter.AristotleEODPricing.Run';

SELECT TOP 10
    StartLog.EntryDateTime AS StartTime,
    CompletionLog.EntryDateTime AS CompletionTime,
    DATEDIFF(SECOND, StartLog.EntryDateTime, CompletionLog.EntryDateTime) AS DurationSeconds,
    CONCAT(
        DATEDIFF(SECOND, StartLog.EntryDateTime, CompletionLog.EntryDateTime) / 60, ' min ',
        DATEDIFF(SECOND, StartLog.EntryDateTime, CompletionLog.EntryDateTime) % 60, ' sec'
    ) AS Duration
FROM 
    (SELECT EntryDateTime, ROW_NUMBER() OVER (ORDER BY EntryDateTime DESC) AS rn
     FROM Enterprise.dbo.tLogBookEntry
     WHERE ExceptionMessage LIKE '%' + @PubSubSubject + '%'
       AND EntryDateTime >= DATEADD(DAY, -30, GETDATE())) StartLog
INNER JOIN
    (SELECT EntryDateTime, ROW_NUMBER() OVER (ORDER BY EntryDateTime DESC) AS rn
     FROM Enterprise.dbo.tLogBookEntry
     WHERE ExceptionMessage LIKE '%' + @CompletionPubSub + '%'
       AND EntryDateTime >= DATEADD(DAY, -30, GETDATE())) CompletionLog
    ON StartLog.rn = CompletionLog.rn
WHERE CompletionLog.EntryDateTime > StartLog.EntryDateTime
ORDER BY StartLog.EntryDateTime DESC;
```

---

## PowerShell Execution Patterns

### Method 1: Script Adapter Execution History (Preferred)

```powershell
# Get Script Adapter execution history directly from execution table
$scriptId = 1537

$query = @"
SELECT TOP 10
    ScriptConfigurationID,
    StartTime,
    EndTime,
    DATEDIFF(SECOND, StartTime, EndTime) AS DurationSeconds,
    CONCAT(
        DATEDIFF(SECOND, StartTime, EndTime) / 60, ' min ',
        DATEDIFF(SECOND, StartTime, EndTime) % 60, ' sec'
    ) AS FormattedDuration,
    JobDetail
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE ScriptConfigurationID = $scriptId
  AND StartTime >= DATEADD(DAY, -7, GETDATE())
ORDER BY StartTime DESC
"@

$executions = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" `
    -Database "Enterprise" `
    -Query $query `
    -TrustServerCertificate

# Get Script Adapter name
$configQuery = @"
SELECT Name, ScriptPath FROM Enterprise.ScriptAdapter.vScriptConfigurationActive
WHERE ScriptConfigurationID = $scriptId
"@

$config = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" `
    -Database "Enterprise" `
    -Query $configQuery `
    -TrustServerCertificate

Write-Host "Script Adapter $scriptId`: $($config.Name)"
Write-Host "Script Path: $($config.ScriptPath)"
Write-Host "`nLast Execution:"
$last = $executions[0]
Write-Host "  Start: $($last.StartTime)"
Write-Host "  End: $($last.EndTime)"
Write-Host "  Duration: $($last.DurationSeconds) seconds ($($last.FormattedDuration))"
```

### Method 2: Pub/Sub Message Matching (Fallback for Report Subscriptions)

```powershell
# Get Script Adapter configuration
$scriptId = 1422
$query = @"
SELECT 
    ScriptConfigurationID,
    Name,
    PubSubSubject,
    CompletionPubSub,
    ScriptPath
FROM Enterprise.ScriptAdapter.vScriptConfigurationActive
WHERE ScriptConfigurationID = $scriptId
"@

$config = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" `
    -Database "Enterprise" `
    -Query $query `
    -TrustServerCertificate

# Get last execution start time
$triggerQuery = @"
SELECT TOP 1 EntryDateTime
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%$($config.PubSubSubject)%'
  AND ExceptionMessage LIKE '%Received message to check on event jobs%'
ORDER BY EntryDateTime DESC
"@

$startTime = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" `
    -Database "Enterprise" `
    -Query $triggerQuery `
    -TrustServerCertificate

# Get completion time
$completionQuery = @"
SELECT TOP 1 EntryDateTime
FROM Enterprise.dbo.tLogBookEntry
WHERE ExceptionMessage LIKE '%$($config.CompletionPubSub)%'
  AND ExceptionMessage LIKE '%Published message%'
  AND EntryDateTime > '$($startTime.EntryDateTime)'
ORDER BY EntryDateTime
"@

$endTime = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" `
    -Database "Enterprise" `
    -Query $completionQuery `
    -TrustServerCertificate

# Calculate duration
$duration = New-TimeSpan -Start $startTime.EntryDateTime -End $endTime.EntryDateTime

Write-Host "Job: $($config.Name)"
Write-Host "Start: $($startTime.EntryDateTime)"
Write-Host "End: $($endTime.EntryDateTime)"
Write-Host "Duration: $($duration.TotalMinutes) minutes ($($duration.TotalSeconds) seconds)"
```

---

## Troubleshooting

### Which Method Should I Use?

**Decision Tree:**
1. **Is it a Script Adapter?** → Use `Enterprise.ScriptAdapter.tScriptConfigurationHistory` (Method 1)
   - ✅ Direct execution logs with precise StartTime/EndTime
   - ✅ Faster and more reliable
   - ✅ Includes all executions regardless of pub/sub configuration
   
2. **Is it a Report Subscription?** → Use pub/sub messages (Method 2)
   - Report Subscriptions don't log to tScriptConfigurationHistory
   - Match trigger message → completion message timestamps

3. **Script Adapter with no CompletionPubSub?** → Use Method 1 (execution history table)
   - Many Script Adapters don't publish completion messages
   - The execution history table captures all runs

### No Execution Logs Found in tScriptConfigurationHistory

If the execution history table is empty for a Script Adapter:
1. Verify the ScriptConfigurationID is correct
2. Check if the job has run recently (last 30 days)
3. The job may never have been executed
4. Fall back to Method 2 (pub/sub messages) if the job has PubSubSubject/CompletionPubSub

**CRITICAL: RefRecStatusID Filter Issue**

If your query returns **ZERO results** when you know the Script Adapter has executed recently:

**Cause:** You're filtering by `RefRecStatusID = 1` which is INCORRECT for execution history.

```sql
-- ❌ WRONG - Returns zero results
SELECT * FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE ScriptConfigurationID = 1537
  AND RefRecStatusID = 1;  -- This is wrong!

-- ✅ CORRECT - Returns actual execution records
SELECT * FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE ScriptConfigurationID = 1537
  AND StartTime >= DATEADD(DAY, -30, GETDATE())
  AND EndTime IS NOT NULL;
```

**Explanation:**
- `RefRecStatusID = 1` is used in configuration tables (like `tSubscriptionXml`) to mean "Active"
- In `tScriptConfigurationHistory`, execution records use `RefRecStatusID IN (5, 6)`
- **Best practice:** Don't filter by RefRecStatusID in execution history queries
- Instead, filter by `StartTime` range and `EndTime IS NOT NULL` for completed runs

**Verification:**
```sql
-- Check what RefRecStatusID values actually exist
SELECT DISTINCT RefRecStatusID, COUNT(*) AS RecordCount
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE StartTime >= DATEADD(DAY, -30, GETDATE())
GROUP BY RefRecStatusID;

-- Results should show:
-- RefRecStatusID = 5: ~108,000 records
-- RefRecStatusID = 6: ~95,000 records
-- (NOT RefRecStatusID = 1)
```

This issue affected PipeWatch's `add_execution_timing.py` script - after removing the `RefRecStatusID = 1` filter, it successfully retrieved timing data for **206 Script Adapters** instead of zero.

### No Execution Logs Found in Pub/Sub Messages

If no pub/sub execution logs are found:
1. Verify the Script Adapter ID is correct
2. Check if the job has run recently (check last 30 days)
3. Verify the PubSubSubject and CompletionPubSub are not NULL
4. Check if the job is event-driven vs scheduled
5. Try Method 1 (tScriptConfigurationHistory) instead

### Mismatched Start/Completion Times (Pub/Sub Method)

If start/completion pairs don't match:
1. The job may still be running
2. The job may have failed before publishing completion message
3. Check for error messages in the log:
   ```sql
   SELECT TOP 10 EntryDateTime, CAST(ExceptionMessage AS VARCHAR(500))
   FROM Enterprise.dbo.tLogBookEntry
   WHERE ExceptionMessage LIKE '%<ScriptPath>%'
     AND ExceptionMessage LIKE '%error%'
   ORDER BY EntryDateTime DESC;
   ```

### Report Subscription to Script Adapter Mapping

If given a Report Subscription ID, find its Script Adapter children:

```sql
-- Get Script Adapters triggered by a Report Subscription
SELECT 
    sa.ScriptConfigurationID,
    sa.Name,
    sa.PubSubSubject,
    sa.CompletionPubSub
FROM Enterprise.ScriptAdapter.vScriptConfigurationActive sa
WHERE sa.PubSubSubject LIKE '%ReportSubscription%' 
   OR sa.PubSubSubject IN (
       SELECT CompletionPubSub 
       FROM Core.Report.tSubscriptionXml 
       WHERE SubscriptionID = <REPORT_SUBSCRIPTION_ID>
   );
```

Or use PipeWatch's job-names-list-enriched.json to find children hierarchically.

---

## Success Criteria

- ✅ Successfully identified job type (Script Adapter or Report Subscription)
- ✅ Retrieved job configuration (name, script path, pub/sub messages)
- ✅ Found execution history using appropriate method:
  - For Script Adapters: `Enterprise.ScriptAdapter.tScriptConfigurationHistory`
  - For Report Subscriptions: Pub/sub message matching
- ✅ Calculated duration between start and completion
- ✅ Reported results with formatted date/time and duration
- ✅ Identified execution patterns (min/max/avg duration if applicable)
- ✅ Identified if job is still running or failed to complete

---

## Example Execution Workflows

### Example 1: Script Adapter Execution Time (Preferred Path)

**User Question:** "How long does job 1537 take to run?"

**Agent Response:**
1. Identify job type: Script Adapter (tool_id 1537)
2. Query `Enterprise.ScriptAdapter.tScriptConfigurationHistory` for recent executions
3. Get last 10 executions with StartTime, EndTime, Duration
4. Calculate statistics: min, max, avg duration
5. Report:
   - Job name: "Move CashFlow source files"
   - Script path: C:\Siepe\Data\Scripts\PROD\Move_CashFlowSourceFiles_ToUniqueFolders.ps1
   - Last execution: 2:23:32 AM - 2:23:35 AM (3 seconds)
   - Typical duration: 2-3 seconds

### Example 2: Report Subscription Execution Time

**User Question:** "How long did the AOD CashFlow Report job take to run?"

**Agent Response:**
1. Identify job type: Report Subscription (ID 500001979)
2. Get trigger message: `Cashflow.AOD`
3. Get completion message: `ReportSubscription.Move.CashFlowSourceFiles`
4. Query pub/sub messages from `Enterprise.dbo.tLogBookEntry`
5. Match trigger timestamps with completion timestamps
6. Calculate duration: Completion Time - Trigger Time
7. Report:
   - Report name: "AOD CashFlow Report"
   - Last execution: 2:23:29 AM - 2:23:32 AM (3 seconds)
   - Typical duration: 3-25 seconds

### Example 3: Script Adapter with Pub/Sub Fallback

**User Question:** "How long does job 1422 take to run?"

**Agent Response:**
1. Identify job type: Script Adapter 1422
2. Try Method 1: Query `Enterprise.ScriptAdapter.tScriptConfigurationHistory`
3. If no data, fall back to Method 2: Pub/sub messages
4. Extract PubSubSubject: `ScriptAdapter.CVET.RestructurePriceLoader.C-0`
5. Extract CompletionPubSub: `ScriptAdapter.AristotleEODPricing.Run`
6. Query for recent trigger messages (start time)
7. Query for recent completion messages (end time)
8. Calculate duration: End Time - Start Time
9. Report:
   - Job name: "Solvas Position Import,Normalize,Push"
   - Script path: C:\Siepe\Data\Scripts\PROD\SolvasPortfolio_PositionOnly_CurrentDay.ps1
   - Last execution: 9:30:04 PM - 10:00:00 PM (29 min 56 sec)

---

## Notes

### Data Sources

1. **`Enterprise.ScriptAdapter.tScriptConfigurationHistory`** (Primary for Script Adapters)
   - Direct execution logs with precise StartTime and EndTime
   - Logs ALL Script Adapter executions
   - Includes JobDetail field for execution parameters
   - Most reliable source for Script Adapter durations

2. **`Enterprise.dbo.tLogBookEntry`** (For Report Subscriptions and fallback)
   - Pub/sub messages are recorded when events occur
   - The `PubSubSubject` is the TRIGGER (job starts listening)
   - The `CompletionPubSub` is the COMPLETION (job publishes when done)
   - Duration = Time between receiving trigger and publishing completion

### Important Considerations

- **Script Adapters**: Always try `tScriptConfigurationHistory` FIRST
- **Report Subscriptions**: Must use pub/sub message matching
- Some Script Adapters don't publish completion messages (CompletionPubSub is NULL)
- Some jobs may have multiple concurrent executions if `AllowConcurrent = True`
- Log retention may vary; recommend checking last 30 days
- For jobs without execution logs, consider adding logging to the PowerShell script itself

### Performance Tips

- The `tScriptConfigurationHistory` table is faster to query than parsing log messages
- Use date filters (last 7 or 30 days) to improve query performance
- For statistics, aggregate by ScriptConfigurationID to see execution patterns

---

## PipeWatch Integration

### Overview

This execution timing data is integrated into the PipeWatch dashboard to show real-time job performance metrics.

**Files:**
- `c:\source\PipeWatch\scripts\generators\add_execution_timing.py` - Enriches job data with execution stats
- `c:\source\PipeWatch\public\index.html` - Displays timing badges and drill-down details
- `c:\source\PipeWatch\update-execution-timing.bat` - Batch script to refresh timing data
- `c:\source\PipeWatch\EXECUTION_TIMING_README.md` - Full integration documentation

### Data Enrichment

The Python script `add_execution_timing.py` queries `Enterprise.ScriptAdapter.tScriptConfigurationHistory` and adds these fields to each Script Adapter job:

```json
{
  "execution_stats": {
    "total_runs": 145,
    "avg_duration_seconds": 3,
    "min_duration_seconds": 2,
    "max_duration_seconds": 5,
    "last_start": "2026-07-28 02:23:32",
    "last_end": "2026-07-28 02:23:35"
  },
  "last_run_duration": "3s",
  "typical_duration": "2-3s"
}
```

### UI Display

**Timing Badges** appear on each Script Adapter row:
- **Green badge** (last_run_duration): Most recent execution time
- **Blue badge** (typical_duration): Average duration range

**Script Adapter Drill-Down** shows detailed stats when clicking the green arrow:
- Total successful runs (last 30 days)
- Last execution: Start time, end time, duration
- Duration range: Min, max, average
- Script path and configuration details

### UI Implementation Pattern (CRITICAL)

**Problem Pattern to Avoid:**

When rendering hierarchical jobs with expandable sections, don't confuse different types of drilldown content:

```javascript
// ❌ WRONG - Mixes children and sequence items
const hasChildren = allChildren.length > 0 || hasSequenceItems;

// This causes Script Adapters with sequences but NO children to:
// 1. Create empty children containers (0 children)
// 2. Get toggleChildren handler instead of toggleScriptAdapterSection
// 3. Break the Script Adapter drill-down feature
```

**Correct Pattern:**

```javascript
// ✅ CORRECT - Separate actual children from other expandable content
const hasActualChildren = allChildren.length > 0;
const hasChildren = hasActualChildren;  // Only for child jobs, not sequences

// Then check content type for toggle behavior:
if (hasChildren && allChildren.length > 0) {
    // Create children container
    // Attach toggleChildren handler (expands child Script Adapters)
} else if (job.full_script_path || job.script_path) {
    // Attach toggleScriptAdapterSection handler (shows execution stats panel)
}
```

**Key Principles:**

1. **Separate flags for separate behaviors**
   - `hasChildren` = has child jobs to render recursively
   - `hasSequenceItems` = has workflow steps (shown in separate "View Sequence" button)
   - `hasScriptDetails` = has Script Adapter details to drill down

2. **Check both condition AND array length before creating containers**
   ```javascript
   // Must verify both: flag is true AND array has items
   if (hasChildren && allChildren.length > 0) { ... }
   ```

3. **Job hierarchy determines toggle behavior**
   - **Report Subscriptions** (depth 0) with children → toggleChildren
   - **Script Adapters** (depth 1) with no children → toggleScriptAdapterSection
   - Both use the same green arrow element, but different handlers

### Troubleshooting UI Issues

**Symptom:** Green arrows on Script Adapters don't work, console shows "Created children container with 0 children"

**Root Cause:** `hasChildren` flag is true because of sequence items, even though `allChildren.length` is 0

**Fix:** Update the condition to check actual children count:
```javascript
const hasChildren = allChildren.length > 0;  // Don't include hasSequenceItems
```

**Symptom:** Report Subscription arrows work but Script Adapter arrows don't

**Root Cause:** Children rendering logic is in wrong block, or handler attachment logic doesn't check for script details

**Fix:** Ensure handler attachment follows this structure:
```javascript
if (hasChildren) {
    // Children container + toggleChildren handler
    // Render children recursively
} else if (job.full_script_path || job.script_path) {
    // toggleScriptAdapterSection handler only (no container)
}
```

### Update Workflow

To refresh execution timing data in PipeWatch:

```powershell
# Quick update (timing only)
cd c:\source\PipeWatch
.\update-execution-timing.bat

# Full pipeline update (all data)
.\update-pipewatch-data.bat
```

The batch scripts handle the complete data flow from database → enriched JSON → UI display.

