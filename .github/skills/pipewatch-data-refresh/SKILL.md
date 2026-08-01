---
skill_name: pipewatch-data-refresh
category: PipeWatch ETL Monitoring
description: Weekly PipeWatch Script Adapter backfill with 30-day execution history and failure tracking
keywords: pipewatch, backfill, execution history, script adapter, failure tracking, ETL monitoring
skill_status: ready
version: 1.0.0
last_updated: 2026-07-30
author: Mossy (MOS Support Agent)
---

# PipeWatch Data Refresh Skill

## Purpose
Automate weekly backfill of PipeWatch Script Adapter execution statistics from the last 30 days, including comprehensive failure tracking and performance metrics.

## When to Use This Skill

**Trigger Keywords:**
- "refresh pipewatch data"
- "backfill pipewatch execution stats"
- "update script adapter metrics"
- "pipewatch weekly refresh"
- "check pipewatch failures"
- "script adapter failure tracking"

**Use Cases:**
1. **Weekly Maintenance:** Scheduled Monday 6:00 AM data refresh
2. **Failure Investigation:** Identify Script Adapters with recent failures
3. **Performance Monitoring:** Track execution duration trends
4. **Data Quality:** Ensure PipeWatch dashboard has current metrics

## Scope

**In Scope:**
- ✅ Script Adapter jobs (jobs with `script_path` property)
- ✅ 30-day execution history from `Enterprise.ScriptAdapter.tScriptConfigurationHistory`
- ✅ Failure detection and tracking (timeout errors, exceptions)
- ✅ Performance metrics (min/max/avg duration, execution counts)
- ✅ Failed jobs report generation

**Out of Scope:**
- ❌ Email Adapter jobs (no execution history table)
- ❌ Report Subscription jobs (no execution history table)
- ❌ Real-time monitoring (this is a batch backfill process)

## Data Sources

### Primary Database
**Connection:** mos-sql-p.mos.siepe.local,52155  
**Database:** Enterprise

**Tables:**
1. **ScriptAdapter.tScriptConfiguration** - Script Adapter configuration
   - ScriptConfigurationID → tool_id in JSON
   - ScriptPath, TimeOut, PubSubSubject
   
2. **ScriptAdapter.tScriptConfigurationHistory** - Execution history
   - StartTime, EndTime (execution timestamps)
   - JobDetail (error messages)
   - RefRecStatusID (2=Running, 5=Completed)

### Target JSON File
**Path:** `C:\source\PipeWatch\public\docs\job-names-list-enriched.json`
**Size:** 6033 total jobs (287+ Script Adapters with execution history)

**Updated Fields:**
```json
{
  "execution_stats": {
    "total_executions_30d": 538,
    "min_duration_seconds": 0,
    "max_duration_seconds": 35,
    "avg_duration_seconds": 1,
    "last_duration_seconds": 1,
    "last_execution_start": "2026-07-30 07:22:01",
    "last_execution_end": "2026-07-30 07:22:02",
    "last_failed_time": "2026-07-15 14:32:05",
    "days_since_failure": 15,
    "total_failures_30d": 3,
    "failure_rate": 0.56,
    "last_error_message": "Script has failed due to timeout",
    "duration_range": "0-35 sec"
  }
}
```

## Investigation Steps

### Step 1: Validate Prerequisites

**Check database connectivity:**
```powershell
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Enterprise" -Q "SELECT COUNT(*) FROM ScriptAdapter.tScriptConfiguration WHERE RefRecStatusID = 1"
```

**Expected:** Returns count of active Script Adapters (should be 1500+)

**Check JSON file exists:**
```powershell
Test-Path "C:\source\PipeWatch\public\docs\job-names-list-enriched.json"
```

**Expected:** True

---

### Step 2: Run Backfill Script

**Standard 30-day backfill:**
```powershell
cd C:\source\MD\AdminTools\.github\skills\pipewatch-data-refresh
.\Update-PipeWatch-ExecutionStats.ps1
```

**Custom lookback period (e.g., 60 days):**
```powershell
.\Update-PipeWatch-ExecutionStats.ps1 -LookbackDays 60
```

**Custom output path:**
```powershell
.\Update-PipeWatch-ExecutionStats.ps1 -OutputPath "C:\path\to\custom\output.json"
```

**Expected Output:**
- Updates job-names-list-enriched.json with execution_stats
- Creates backup file: `job-names-list-enriched_backup_YYYYMMDD_HHMMSS.json`
- Generates log: `C:\source\MD\AdminTools\Output\backfill-log-YYYYMMDD_HHMMSS.txt`
- Creates failed jobs report: `C:\source\MD\AdminTools\Output\failed-jobs-report-YYYYMMDD_HHMMSS.csv`

---

### Step 3: Verify Results

**Check updated JSON:**
```powershell
$json = Get-Content "C:\source\PipeWatch\public\docs\job-names-list-enriched.json" -Raw | ConvertFrom-Json
$allJobs = $json.categories | ForEach-Object { $_.jobs }
$jobsWithStats = $allJobs | Where-Object { $_.execution_stats }
Write-Host "Jobs with execution_stats: $($jobsWithStats.Count)"
```

**Expected:** 287+ jobs with execution_stats populated

**Check for failed jobs:**
```powershell
$failedJobs = $allJobs | Where-Object { $_.execution_stats.last_failed_time }
Write-Host "Jobs with failures in last 30 days: $($failedJobs.Count)"
$failedJobs | Select-Object job_description, @{N='Days Ago';E={$_.execution_stats.days_since_failure}}, @{N='Total Failures';E={$_.execution_stats.total_failures_30d}} | Sort-Object 'Days Ago' | Format-Table
```

**Expected:** List of jobs with recent failures sorted by most recent

**Review failed jobs report:**
```powershell
# Find latest report
$latestReport = Get-ChildItem "C:\source\MD\AdminTools\Output\failed-jobs-report-*.csv" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Import-Csv $latestReport.FullName | Format-Table
```

---

### Step 4: Analyze Failure Patterns

**Query for timeout failures:**
```powershell
$json = Get-Content "C:\source\PipeWatch\public\docs\job-names-list-enriched.json" -Raw | ConvertFrom-Json
$allJobs = $json.categories | ForEach-Object { $_.jobs; $_.jobs.children } | Where-Object { $_ }
$timeoutFailures = $allJobs | Where-Object { $_.execution_stats.last_error_message -like '*timeout*' }

Write-Host "`n=== TIMEOUT FAILURES ===" -ForegroundColor Red
$timeoutFailures | ForEach-Object {
    Write-Host "`nJob: $($_.job_description)" -ForegroundColor Yellow
    Write-Host "  Tool ID: $($_.tool_id)"
    Write-Host "  Last Failed: $($_.execution_stats.last_failed_time) ($($_.execution_stats.days_since_failure) days ago)"
    Write-Host "  Total Failures: $($_.execution_stats.total_failures_30d)"
    Write-Host "  Failure Rate: $($_.execution_stats.failure_rate)%"
    Write-Host "  Error: $($_.execution_stats.last_error_message)"
}
```

**Query for high failure rates:**
```powershell
$highFailureRate = $allJobs | Where-Object { $_.execution_stats.failure_rate -gt 5 }

Write-Host "`n=== HIGH FAILURE RATE (>5%) ===" -ForegroundColor Red
$highFailureRate | Sort-Object { $_.execution_stats.failure_rate } -Descending | ForEach-Object {
    Write-Host "`n$($_.job_description)" -ForegroundColor Yellow
    Write-Host "  Failure Rate: $($_.execution_stats.failure_rate)% ($($_.execution_stats.total_failures_30d)/$($_.execution_stats.total_executions_30d) runs)"
    Write-Host "  Last Failed: $($_.execution_stats.last_failed_time)"
}
```

---

### Step 5: Generate Summary Report (Markdown)

**Create investigation summary for ADO ticket:**

```powershell
$reportPath = "C:\source\MD\AdminTools\Output\PipeWatch_Refresh_Summary_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"

$json = Get-Content "C:\source\PipeWatch\public\docs\job-names-list-enriched.json" -Raw | ConvertFrom-Json
$allJobs = $json.categories | ForEach-Object { $_.jobs; $_.jobs.children } | Where-Object { $_ }
$jobsWithStats = $allJobs | Where-Object { $_.execution_stats }
$failedJobs = $jobsWithStats | Where-Object { $_.execution_stats.last_failed_time }
$criticalJobs = $failedJobs | Where-Object { $_.execution_stats.days_since_failure -le 7 }

$summary = @"
# PipeWatch Data Refresh Summary
**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Overview
- **Total Jobs Tracked:** $($jobsWithStats.Count)
- **Jobs with Failures (30d):** $($failedJobs.Count)
- **Critical (Failed in last 7 days):** $($criticalJobs.Count)

## Recent Failures (Last 7 Days)

| Job Description | Tool ID | Days Ago | Total Failures | Failure Rate | Error Message |
|----------------|---------|----------|----------------|--------------|---------------|
"@

foreach ($job in ($criticalJobs | Sort-Object { $_.execution_stats.days_since_failure })) {
    $summary += "`n| $($job.job_description) | $($job.tool_id) | $($job.execution_stats.days_since_failure) | $($job.execution_stats.total_failures_30d) | $($job.execution_stats.failure_rate)% | $($job.execution_stats.last_error_message -replace '\|', ' ') |"
}

$summary += @"

## Recommendations
1. **Investigate timeout failures** - Jobs failing due to timeout may need increased TimeOut values
2. **Review high failure rates** - Jobs with >5% failure rate need attention
3. **Monitor critical jobs** - Recent failures (last 7 days) require immediate investigation

## Next Steps
- Review failed-jobs-report CSV for complete list
- Create ADO tasks for jobs with persistent failures
- Update Script Adapter TimeOut settings where needed

---
**Log File:** C:\source\MD\AdminTools\Output\backfill-log-*.txt  
**Failed Jobs Report:** C:\source\MD\AdminTools\Output\failed-jobs-report-*.csv
"@

$summary | Out-File $reportPath -Encoding UTF8
Write-Host "`n✓ Summary report saved to: $reportPath" -ForegroundColor Green
notepad $reportPath
```

---

## Failure Detection Logic

**Timeout Failures:**
```sql
JobDetail LIKE '%has failed due to timeout%'
```

**Error Failures:**
```sql
JobDetail LIKE '%error%' OR JobDetail LIKE '%exception%' OR JobDetail LIKE '%failed%'
```

**Success:**
```sql
EndTime IS NOT NULL AND (JobDetail = '' OR JobDetail IS NULL)
```

**Running Jobs (Excluded):**
```sql
EndTime IS NULL AND RefRecStatusID = 2
```

---

## Scheduling

### Option 1: Windows Task Scheduler (Recommended)

**Create scheduled task for Monday 6:00 AM:**
```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\source\MD\AdminTools\.github\skills\pipewatch-data-refresh\Update-PipeWatch-ExecutionStats.ps1"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 6:00AM
$principal = New-ScheduledTaskPrincipal -UserId "DOMAIN\YourUser" -LogonType S4U
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName "PipeWatch Weekly Data Refresh" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "Weekly backfill of PipeWatch Script Adapter execution statistics"
```

**Verify scheduled task:**
```powershell
Get-ScheduledTask -TaskName "PipeWatch Weekly Data Refresh"
```

### Option 2: Manual via Mossy

**Invoke via chat:**
```
@Mossy refresh pipewatch data
```

Mossy will execute the backfill script and provide summary results.

---

## Troubleshooting

### Issue: "Cannot connect to database"
**Cause:** SQL Server not accessible or authentication failed

**Solution:**
1. Verify SQL Server is running: `Test-NetConnection -ComputerName mos-sql-p.mos.siepe.local -Port 52155`
2. Check Windows Authentication: Ensure you're logged in with domain credentials
3. Test sqlcmd: `sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Enterprise" -Q "SELECT 1"`

---

### Issue: "JSON file not found"
**Cause:** PipeWatch repository not cloned or path incorrect

**Solution:**
1. Verify path exists: `Test-Path "C:\source\PipeWatch\public\docs\job-names-list-enriched.json"`
2. Clone PipeWatch repo: `git clone https://github.com/siepe/PipeWatch.git C:\source\PipeWatch`
3. Check file permissions: Ensure read/write access

---

### Issue: "No execution stats updated"
**Cause:** Query returned no results or all jobs skipped

**Solution:**
1. Check if Script Adapters ran in last 30 days:
   ```sql
   SELECT COUNT(*) FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory 
   WHERE StartTime >= DATEADD(day, -30, GETDATE())
   ```
2. Increase lookback period: `.\Update-PipeWatch-ExecutionStats.ps1 -LookbackDays 60`
3. Verify ScriptConfigurationID matches tool_id in JSON

---

### Issue: "Backup file accumulation"
**Cause:** Multiple backfill runs create many backup files

**Solution:**
Delete old backups (keep last 5):
```powershell
Get-ChildItem "C:\source\PipeWatch\public\docs\job-names-list-enriched_backup_*.json" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -Skip 5 | 
    Remove-Item -Force
```

---

## Output Files

### 1. Updated JSON
**Path:** `C:\source\PipeWatch\public\docs\job-names-list-enriched.json`
**Changes:** execution_stats added/updated for all Script Adapter jobs

### 2. Backup JSON
**Path:** `C:\source\PipeWatch\public\docs\job-names-list-enriched_backup_YYYYMMDD_HHMMSS.json`
**Purpose:** Original file before update (for rollback)

### 3. Execution Log
**Path:** `C:\source\MD\AdminTools\Output\backfill-log-YYYYMMDD_HHMMSS.txt`
**Contents:** Detailed execution log with timestamps, SQL queries, update counts

### 4. Failed Jobs Report
**Path:** `C:\source\MD\AdminTools\Output\failed-jobs-report-YYYYMMDD_HHMMSS.csv`
**Contents:** CSV report of all jobs with failures in last 30 days

### 5. Summary Report (Optional)
**Path:** `C:\source\MD\AdminTools\Output\PipeWatch_Refresh_Summary_YYYYMMDD_HHMMSS.md`
**Contents:** Markdown summary with critical failures and recommendations

---

## Performance Metrics

**Expected Execution Time:**
- Database query: 30-60 seconds
- JSON parsing: 5-10 seconds
- Update and save: 10-15 seconds
- **Total: ~2-3 minutes**

**Database Load:**
- Query scans ~30 days of tScriptConfigurationHistory (millions of rows)
- Aggregation uses efficient CTEs with proper indexes
- Read-only queries (no UPDATE/INSERT operations)

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-07-30 | Initial release with 30-day failure tracking |

---

## Related Skills
- **check-ssis-errors** - SSIS package failure investigation
- **ssis-troubleshooting** - Detailed SSIS error analysis
- **job-execution-duration** - Individual job duration lookup

---

## Support
For issues or questions, contact:
- **Author:** Mossy (MOS Support Agent)
- **Documentation:** C:\source\MD\AdminTools\.github\skills\pipewatch-data-refresh\DATA_SOURCE_MAP.md
- **ADO Project:** Siepe.Software
