# PipeWatch Data Refresh Skill

## 📦 Complete Automation System for Script Adapter Failure Tracking

Automated weekly backfill of PipeWatch execution statistics from Enterprise database with comprehensive 30-day failure tracking.

---

## 🚀 Quick Start

### 1. Run System Test
```powershell
cd C:\source\MD\AdminTools\.github\skills\pipewatch-data-refresh
.\Test-PipeWatch-Refresh.ps1
```

### 2. Run Backfill (Manual)
```powershell
.\Update-PipeWatch-ExecutionStats.ps1
```

### 3. Setup Weekly Schedule
```powershell
.\Setup-PipeWatch-Schedule.ps1
```

---

## 📁 Files in This Directory

| File | Purpose | Type |
|------|---------|------|
| **SKILL.md** | Complete Mossy skill documentation | Documentation |
| **DATA_SOURCE_MAP.md** | Database schema and JSON structure reference | Documentation |
| **Update-PipeWatch-ExecutionStats.ps1** | Main backfill script (production) | PowerShell Script |
| **Test-PipeWatch-Refresh.ps1** | System validation test | PowerShell Script |
| **Setup-PipeWatch-Schedule.ps1** | Task Scheduler configuration helper | PowerShell Script |
| **README.md** | This file | Documentation |

---

## 🎯 What This System Does

### Data Collection
- ✅ Queries **Enterprise.ScriptAdapter.tScriptConfigurationHistory** for last 30 days
- ✅ Aggregates execution metrics (count, duration min/max/avg)
- ✅ Detects failures (timeout errors, exceptions)
- ✅ Calculates failure rates and trends

### Output Generation
- ✅ Updates **job-names-list-enriched.json** with `execution_stats` object
- ✅ Creates **backup file** before modification
- ✅ Generates **failed jobs CSV report**
- ✅ Produces **detailed execution log**

### Focus Area
- ✅ Script Adapter jobs (have execution history)
- ❌ Email Adapter jobs (no execution history table)
- ❌ Report Subscription jobs (no execution history table)

---

## 📊 Execution Stats Schema

The system adds/updates this structure in the JSON:

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
    "last_error_message": "Script has failed due to timeout of 1000 seconds",
    "duration_range": "0-35 sec"
  }
}
```

---

## 🔧 Configuration

### Database Connection
- **Server:** mos-sql-p.mos.siepe.local,52155
- **Database:** Enterprise
- **Authentication:** Windows Integrated (SSO)
- **Tables:** ScriptAdapter.tScriptConfiguration, ScriptAdapter.tScriptConfigurationHistory

### File Paths
- **JSON Input/Output:** `C:\source\PipeWatch\public\docs\job-names-list-enriched.json`
- **Logs:** `C:\source\MD\AdminTools\Output\backfill-log-YYYYMMDD_HHMMSS.txt`
- **Failed Jobs Report:** `C:\source\MD\AdminTools\Output\failed-jobs-report-YYYYMMDD_HHMMSS.csv`

### Parameters
- **LookbackDays:** Default 30 (customizable via -LookbackDays parameter)
- **OutputPath:** Customizable via -OutputPath parameter
- **LogPath:** Customizable via -LogPath parameter

---

## 📅 Scheduling

### Recommended Schedule
**Every Monday at 6:00 AM**

Why Monday morning?
- Weekend data included
- Fresh metrics for weekly planning
- Low database load time

### Setup Instructions
```powershell
# Run the setup script
.\Setup-PipeWatch-Schedule.ps1

# Verify scheduled task
Get-ScheduledTask -TaskName "PipeWatch Weekly Data Refresh"

# Test task immediately
Start-ScheduledTask -TaskName "PipeWatch Weekly Data Refresh"
```

---

## 🔍 Usage Examples

### Standard Backfill
```powershell
.\Update-PipeWatch-ExecutionStats.ps1
```

### Custom Lookback Period
```powershell
.\Update-PipeWatch-ExecutionStats.ps1 -LookbackDays 60
```

### Custom Output Path (for testing)
```powershell
.\Update-PipeWatch-ExecutionStats.ps1 -OutputPath "C:\temp\test-output.json"
```

### Via Mossy Agent
```
@Mossy refresh pipewatch data
```

---

## 🐛 Troubleshooting

### Issue: SSL Certificate Error with Invoke-Sqlcmd
**Symptom:** "Certificate chain was issued by an authority that is not trusted"

**Solution:** The backfill script uses `sqlcmd.exe` instead of `Invoke-Sqlcmd` to avoid SSL issues. If you see this error in test scripts, it's safe to ignore - production script uses sqlcmd.

---

### Issue: No Stats Updated
**Cause:** No Script Adapter executions in lookback period

**Solution:**
1. Increase lookback days: `.\Update-PipeWatch-ExecutionStats.ps1 -LookbackDays 60`
2. Verify database has recent data:
   ```powershell
   sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Enterprise" -Q "SELECT TOP 5 ScriptConfigurationID, StartTime FROM ScriptAdapter.tScriptConfigurationHistory ORDER BY StartTime DESC"
   ```

---

### Issue: JSON Backup Files Accumulating
**Solution:** Clean up old backups (keep last 5):
```powershell
Get-ChildItem "C:\source\PipeWatch\public\docs\job-names-list-enriched_backup_*.json" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -Skip 5 | 
    Remove-Item -Force
```

---

## 📈 Performance

**Expected Execution Time:** 2-3 minutes

**Breakdown:**
- Database query (with aggregation): ~60s
- JSON parsing: ~10s
- Update and save: ~15s
- Report generation: ~10s

**Database Impact:** Read-only queries, no UPDATE/INSERT operations

---

## 🧪 Testing

Run the validation test before production use:

```powershell
.\Test-PipeWatch-Refresh.ps1
```

**Expected Output:**
```
========================================
PipeWatch Data Refresh System Test
========================================

[1/6] Testing database connectivity...
  ✓ Database connected - 1500+ active Script Adapters found

[2/6] Testing execution history query...
  ✓ Query successful - 500000+ executions in last 30 days

[3/6] Testing JSON file access...
  ✓ JSON file loaded - 6033 jobs, 112 categories

[4/6] Testing backfill script...
  ✓ Backfill script found - 15.13 KB

[5/6] Testing output directory...
  ✓ Output directory writable

[6/6] Testing sample execution stats query...
  ✓ Stats query successful - Sample results:
    Tool ID 1463: 538 runs, avg 1s
    Tool ID 1230: 423 runs, avg 2s
    Tool ID 1551: 392 runs, avg 15s

========================================
Test Results
========================================
Passed: 6/6
Failed: 0/6

✓ All tests passed! System ready for production use.
```

---

## 📚 Documentation

### Full Documentation
See [SKILL.md](SKILL.md) for complete Mossy skill documentation including:
- Investigation procedures
- Failure analysis techniques
- ADO ticket integration
- Advanced usage patterns

### Database Schema Reference
See [DATA_SOURCE_MAP.md](DATA_SOURCE_MAP.md) for:
- Complete table schemas
- Query patterns
- Data mapping details
- SQL examples

---

## 🔗 Integration with Mossy

This skill integrates with the Mossy support agent system.

### Skill Metadata
```yaml
skill_name: pipewatch-data-refresh
category: PipeWatch ETL Monitoring
keywords: pipewatch, backfill, execution history, script adapter, failure tracking
skill_status: ready
version: 1.0.0
```

### Invocation
```
@Mossy refresh pipewatch data
@Mossy backfill pipewatch execution stats
@Mossy check pipewatch failures
```

---

## 📝 Change Log

### Version 1.0.0 (2026-07-30)
- ✅ Initial release
- ✅ 30-day execution history backfill
- ✅ Failure tracking and analysis
- ✅ Automated report generation
- ✅ Task Scheduler integration
- ✅ Comprehensive documentation

---

## 👤 Author
**Mossy** (MOS Support Agent)  
Date: 2026-07-30

---

## 📧 Support
For issues or questions:
- Review [SKILL.md](SKILL.md) troubleshooting section
- Check [DATA_SOURCE_MAP.md](DATA_SOURCE_MAP.md) for schema details
- Contact: Back Office SQL Engineers team
