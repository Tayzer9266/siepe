# ========================================
# PIPEWATCH DATA REFRESH - QUICK REFERENCE
# ========================================

## 🎯 Purpose
Weekly backfill of Script Adapter execution statistics with 30-day failure tracking

## 📍 Location
C:\source\MD\AdminTools\.github\skills\pipewatch-data-refresh\

## ⚡ Quick Commands

### Run Backfill (Standard)
cd C:\source\MD\AdminTools\.github\skills\pipewatch-data-refresh
.\Update-PipeWatch-ExecutionStats.ps1

### Run Backfill (60-day lookback)
.\Update-PipeWatch-ExecutionStats.ps1 -LookbackDays 60

### Test System
.\Test-PipeWatch-Refresh.ps1

### Setup Weekly Schedule
.\Setup-PipeWatch-Schedule.ps1

### Via Mossy
@Mossy refresh pipewatch data

## 📊 What Gets Updated

Target File: C:\source\PipeWatch\public\docs\job-names-list-enriched.json

Added to each Script Adapter job:
{
  "execution_stats": {
    "total_executions_30d": 538,
    "avg_duration_seconds": 1,
    "last_failed_time": "2026-07-15 14:32:05",
    "days_since_failure": 15,
    "total_failures_30d": 3,
    "failure_rate": 0.56,
    "last_error_message": "Script has failed due to timeout..."
  }
}

## 📁 Output Files

1. Updated JSON:
   C:\source\PipeWatch\public\docs\job-names-list-enriched.json

2. Backup (before changes):
   C:\source\PipeWatch\public\docs\job-names-list-enriched_backup_YYYYMMDD_HHMMSS.json

3. Execution Log:
   C:\source\MD\AdminTools\Output\backfill-log-YYYYMMDD_HHMMSS.txt

4. Failed Jobs Report:
   C:\source\MD\AdminTools\Output\failed-jobs-report-YYYYMMDD_HHMMSS.csv

## 🗄️ Database Source

Server: mos-sql-p.mos.siepe.local,52155
Database: Enterprise
Tables:
  - ScriptAdapter.tScriptConfiguration (config)
  - ScriptAdapter.tScriptConfigurationHistory (execution history)

## ⏱️ Performance

Expected Duration: 2-3 minutes
Database Load: Read-only queries, minimal impact
Lookback Period: 30 days (default)

## ⚠️ Troubleshooting

Issue: No stats updated
Solution: Increase lookback days or verify database has recent data

Issue: SSL certificate error
Solution: Backfill script uses sqlcmd (no SSL issues). Test script SSL errors can be ignored.

Issue: Backup files accumulating
Solution: Delete old backups (keep last 5):
  Get-ChildItem "C:\source\PipeWatch\public\docs\job-names-list-enriched_backup_*.json" | 
      Sort-Object LastWriteTime -Descending | Select-Object -Skip 5 | Remove-Item -Force

## 📅 Recommended Schedule

Every Monday at 6:00 AM (configured via Setup-PipeWatch-Schedule.ps1)

## 📚 Documentation

SKILL.md - Complete Mossy skill documentation
DATA_SOURCE_MAP.md - Database schema reference
README.md - Usage guide and examples

## 🔧 Manual Query Examples

# Check active Script Adapters
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Enterprise" -Q "SELECT COUNT(*) FROM ScriptAdapter.tScriptConfiguration WHERE RefRecStatusID = 1"

# Check recent executions
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Enterprise" -Q "SELECT TOP 5 ScriptConfigurationID, StartTime, EndTime, JobDetail FROM ScriptAdapter.tScriptConfigurationHistory ORDER BY StartTime DESC"

# Check failures in last 7 days
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Enterprise" -Q "SELECT ScriptConfigurationID, StartTime, JobDetail FROM ScriptAdapter.tScriptConfigurationHistory WHERE JobDetail LIKE '%failed%' AND StartTime >= DATEADD(day, -7, GETDATE())"

## 📊 View Results

# Count jobs with stats
$json = Get-Content "C:\source\PipeWatch\public\docs\job-names-list-enriched.json" -Raw | ConvertFrom-Json
$allJobs = $json.categories | ForEach-Object { $_.jobs }
$withStats = $allJobs | Where-Object { $_.execution_stats }
Write-Host "Jobs with execution_stats: $($withStats.Count)"

# Show failed jobs
$failed = $withStats | Where-Object { $_.execution_stats.last_failed_time }
$failed | Select-Object job_description, @{N='Days Ago';E={$_.execution_stats.days_since_failure}}, @{N='Failures';E={$_.execution_stats.total_failures_30d}} | Sort-Object 'Days Ago' | Format-Table

## ✅ Success Indicators

✓ Script completes in 2-3 minutes
✓ 287+ jobs updated with execution_stats
✓ Backup file created
✓ Log file shows no errors
✓ Failed jobs report generated (if failures exist)

## 🆘 Support

Author: Mossy (MOS Support Agent)
Date: 2026-07-30
Version: 1.0.0
