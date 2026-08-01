# PipeWatch Data Source Mapping

## Database Schema Reference

### Enterprise.ScriptAdapter.tScriptConfiguration
Primary configuration table for Script Adapter jobs.

**Connection:** mos-sql-p.mos.siepe.local,52155 | Database: Enterprise

| Column Name | Data Type | Nullable | Description |
|------------|-----------|----------|-------------|
| ScriptConfigurationID | int | NO | Primary key - maps to tool_id in JSON |
| Name | nvarchar | NO | Short job name |
| Description | nvarchar | NO | Full job description |
| PubSubSubject | nvarchar | NO | Listen message for pub/sub |
| ScriptPath | nvarchar | NO | Full path to PowerShell script |
| TimeOut | int | NO | Timeout in seconds |
| Documentation | nvarchar | YES | Additional documentation |
| CreatedDate | datetime | NO | Record creation timestamp |
| CreatedUser | nvarchar | NO | Creator username |
| RefRecStatusID | int | NO | 1=Active, 2=Inactive |
| AllowConcurrent | bit | NO | Allow concurrent executions |
| CompletionPubSub | nvarchar | YES | Publish message on completion |

**Example Query:**
```sql
SELECT ScriptConfigurationID, Name, Description, PubSubSubject, 
       ScriptPath, TimeOut, CompletionPubSub
FROM Enterprise.ScriptAdapter.tScriptConfiguration
WHERE RefRecStatusID = 1
ORDER BY Name
```

---

### Enterprise.ScriptAdapter.tScriptConfigurationHistory
Execution history for all Script Adapter runs.

**Connection:** mos-sql-p.mos.siepe.local,52155 | Database: Enterprise

| Column Name | Data Type | Nullable | Description |
|------------|-----------|----------|-------------|
| ScriptConfigurationHistoryID | int | NO | Primary key - unique execution ID |
| ScriptConfigurationID | int | NO | Foreign key to tScriptConfiguration |
| StartTime | datetime | NO | Execution start timestamp |
| EndTime | datetime | YES | Execution end timestamp (NULL if running/timeout) |
| JobDetail | nvarchar | NO | Error message or empty for success |
| CreatedDate | datetime | NO | Record creation timestamp |
| CreatedUser | nvarchar | NO | Service account that ran job |
| RefRecStatusID | int | NO | 2=Running, 5=Completed |

**Failure Detection Logic:**
- **Timeout Failure:** JobDetail LIKE '%has failed due to timeout%'
- **Running Job:** EndTime IS NULL AND RefRecStatusID = 2
- **Success:** EndTime IS NOT NULL AND (JobDetail = '' OR JobDetail IS NULL)

**Example Failure Query:**
```sql
-- Get failed executions in last 30 days
SELECT 
    ScriptConfigurationID,
    StartTime,
    EndTime,
    JobDetail,
    DATEDIFF(second, StartTime, ISNULL(EndTime, GETDATE())) as DurationSeconds
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE StartTime >= DATEADD(day, -30, GETDATE())
  AND (
      JobDetail LIKE '%failed%' 
      OR JobDetail LIKE '%error%' 
      OR JobDetail LIKE '%exception%'
  )
ORDER BY StartTime DESC
```

---

## JSON File Mapping

### job-names-list-enriched.json
**Location:** C:\source\PipeWatch\public\docs\job-names-list-enriched.json

**Structure:**
- **total_jobs:** 6033 (Script Adapters + Report Subscriptions + Email Adapters)
- **total_categories:** 112 (grouped by source_tool and schedule_time)

**Job Properties:**
| JSON Field | Source | Description |
|-----------|--------|-------------|
| tool_id | ScriptConfigurationID | Unique identifier |
| job_description | Name + Description | Human-readable job name |
| listen_message | PubSubSubject | Pub/sub trigger message |
| publish_message | CompletionPubSub | Completion message |
| script_path | ScriptPath | PowerShell script path |
| execution_stats | tScriptConfigurationHistory | 30-day execution metrics |

**execution_stats Schema:**
```json
{
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
```

---

## Data Collection Strategy

### Phase 1: Script Adapter Jobs Only
Focus on jobs with **script_path** property (Script Adapters with execution history).

**Query Pattern:**
```sql
-- Aggregate 30-day execution stats per Script Adapter
SELECT 
    h.ScriptConfigurationID as tool_id,
    COUNT(*) as total_executions_30d,
    MIN(DATEDIFF(second, h.StartTime, h.EndTime)) as min_duration_seconds,
    MAX(DATEDIFF(second, h.StartTime, h.EndTime)) as max_duration_seconds,
    AVG(DATEDIFF(second, h.StartTime, h.EndTime)) as avg_duration_seconds,
    MAX(h.StartTime) as last_execution_start,
    MAX(h.EndTime) as last_execution_end,
    (SELECT TOP 1 StartTime 
     FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory h2
     WHERE h2.ScriptConfigurationID = h.ScriptConfigurationID
       AND h2.JobDetail LIKE '%failed%'
       AND h2.StartTime >= DATEADD(day, -30, GETDATE())
     ORDER BY StartTime DESC) as last_failed_time,
    (SELECT COUNT(*) 
     FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory h3
     WHERE h3.ScriptConfigurationID = h.ScriptConfigurationID
       AND h3.JobDetail LIKE '%failed%'
       AND h3.StartTime >= DATEADD(day, -30, GETDATE())) as total_failures_30d
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory h
WHERE h.StartTime >= DATEADD(day, -30, GETDATE())
  AND h.EndTime IS NOT NULL  -- Exclude running jobs
GROUP BY h.ScriptConfigurationID
```

### Phase 2: Skip Non-Trackable Jobs
- **Email Adapters:** No execution history table (email-based triggers)
- **Report Subscriptions:** No execution history table (report delivery only)

---

## Update Frequency
- **Recommended:** Weekly (every Monday 6:00 AM)
- **Trigger:** Manual via Mossy skill OR scheduled Task
- **Duration:** ~2-3 minutes for full backfill

---

## File Outputs
1. **job-names-list-enriched.json** - Updated with execution_stats
2. **backfill-log-{timestamp}.txt** - Execution log with stats summary
3. **failed-jobs-report-{timestamp}.csv** - Jobs with failures in last 30 days

---

## Change Log
- 2026-07-30: Initial data source mapping created
