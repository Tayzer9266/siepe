# Log Analysis and Investigation

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration  
**Category:** Monitoring & Debugging  
**Difficulty:** Beginner-Intermediate  
**Est. Time:** 5-10 minutes

## Purpose

Search and analyze logs from SEQ, file system, and database sources to troubleshoot ETL issues, SSIS failures, and application errors. Enhanced with log screenshot analysis to extract error messages, stack traces, and timestamps from log images.

---

## Step 0: Analyze Log Screenshots and Wiki

**Step 0.1: Screenshot Analysis**
```powershell
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - Seq log screenshots showing error messages, timestamps
# - Log file screenshots with stack traces
# - Error level indicators (ERROR, WARN, INFO)
# - Exception types and error codes
```

**Step 0.2: Fetch Wiki Documentation**
```powershell
$wikiPath = "/Log-Analysis-Procedures"  # Update with actual path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_LogAnalysis.md" -Encoding UTF8
```

## Step 1: Identify Log Source and Search Criteria

**Ask the user (if not provided):**
- What are you looking for? (errors, warnings, specific job, tenant)
- Time range? (last hour, today, specific date)
- Which log source? (SEQ, file logs, database logs)

**Available Log Sources:**
1. **SEQ** (Primary) - Real-time aggregated logs
2. **File System** - Application and ETL file logs
3. **Database** - SSIS execution logs, job history

---

## Step 2: Search SEQ Logs (Primary Source)

### Option A: SEQ Web UI

**Open SEQ in browser:**
```powershell
Start-Process "http://seq.mos.siepe.local:5341"
```

**Manual filter examples:**
- `Level = 'Error' AND @Timestamp >= Now() - 1h`
- `Application = 'SSIS' AND MessageTemplate CONTAINS 'failed'`
- `TenantShortName = 'Aristotle' AND Level IN ['Error', 'Warning']`
- `SourceContext = 'PricingDataLoad'`

### Option B: SEQ API Query (Programmatic)

**Search for errors in last 24 hours:**

```powershell
$seqUrl = "http://seq.mos.siepe.local:5341"
$from = (Get-Date).AddHours(-24).ToString("yyyy-MM-ddTHH:mm:ss")
$filter = "Level = 'Error'"

$response = Invoke-RestMethod -Uri "$seqUrl/api/events?filter=$filter&from=$from&count=100" -Method GET

$response.Events | ForEach-Object {
    [PSCustomObject]@{
        Timestamp = $_.Timestamp
        Level = $_.Level
        Message = $_.MessageTemplate
        Application = $_.Properties.Application
        Exception = $_.Exception
    }
} | Format-Table -AutoSize
```

**Search for specific job:**

```powershell
$jobName = "MiddleOfficeTradeLoad"
$filter = "MessageTemplate CONTAINS '$jobName' OR SourceContext CONTAINS '$jobName'"
$from = (Get-Date).AddDays(-7).ToString("yyyy-MM-ddTHH:mm:ss")

$response = Invoke-RestMethod -Uri "$seqUrl/api/events?filter=$filter&from=$from&count=50" -Method GET

$response.Events | Select-Object @{N='Time';E={$_.Timestamp}}, @{N='Level';E={$_.Level}}, @{N='Message';E={$_.MessageTemplate}} | Format-Table -Wrap
```

**Search for tenant-specific errors:**

```powershell
$tenant = "Aristotle"
$filter = "TenantShortName = '$tenant' AND Level IN ['Error', 'Warning']"
$from = (Get-Date).AddDays(-1).ToString("yyyy-MM-ddTHH:mm:ss")

Invoke-RestMethod -Uri "$seqUrl/api/events?filter=$filter&from=$from" -Method GET | ConvertTo-Json -Depth 5
```

**Expected Output:**
- Timestamp of each log event
- Log level (Error, Warning, Info)
- Message template
- Structured properties (Tenant, Application, Job)
- Exception details (if error)

---

## Step 3: Search File System Logs

**Log file location:**
```
\\998s02.mos.siepe.local\Siepe\Data\Logs\
```

### Search Logs for Pattern

```powershell
$logPath = "\\998s02.mos.siepe.local\Siepe\Data\Logs\"
$searchPattern = "error|exception|failed"
$daysBack = 3

# Get recent log files
$logFiles = Get-ChildItem -Path $logPath -Recurse -Filter "*.log" | 
    Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-$daysBack) }

# Search for pattern
$results = @()
foreach ($file in $logFiles) {
    $matches = Select-String -Path $file.FullName -Pattern $searchPattern -Context 2,2
    foreach ($match in $matches) {
        $results += [PSCustomObject]@{
            File = $file.Name
            LineNumber = $match.LineNumber
            Line = $match.Line
            Context = $match.Context.PostContext -join "`n"
        }
    }
}

$results | Format-Table -AutoSize -Wrap
```

### Get Latest Logs for Specific Job

```powershell
$jobName = "PricingDataLoad"
$logPath = "\\998s02.mos.siepe.local\Siepe\Data\Logs\$jobName\"

Get-ChildItem -Path $logPath -Filter "*.log" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 5 | 
    ForEach-Object {
        Write-Host "`n=== $($_.Name) ===" -ForegroundColor Cyan
        Get-Content $_.FullName -Tail 50
    }
```

---

## Step 4: Query Database Logs

### SSIS Event Logs (Integration Database)

**Get SSIS import events for tenant:**

```powershell
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Integration" -Q "
SELECT TOP 100
    EventDate,
    EventType,
    TenantShortName,
    PackageName,
    EventSource,
    EventMessage,
    ExecutionID
FROM SSISImportEventLog
WHERE TenantShortName = '{TENANT}'
    AND EventDate >= DATEADD(DAY, -7, GETDATE())
    AND EventType IN ('Error', 'Warning')
ORDER BY EventDate DESC
"
```

### SSISDB Catalog Logs

**Get all SSIS execution messages:**

```powershell
sqlcmd -S "SSIS-SERVER.mos.siepe.local" -d "SSISDB" -Q "
SELECT TOP 200
    em.message_time,
    em.message_type = CASE em.message_type
        WHEN 120 THEN 'Error'
        WHEN 110 THEN 'Warning'
        WHEN 70 THEN 'Information'
    END,
    e.package_name,
    em.message_source_name,
    em.message,
    em.package_path
FROM catalog.event_messages em
INNER JOIN catalog.executions e ON em.operation_id = e.execution_id
WHERE em.message_time >= DATEADD(HOUR, -24, GETDATE())
    AND em.message_type IN (110, 120) -- Warning, Error
ORDER BY em.message_time DESC
"
```

### SQL Agent Job History

**Get failed job runs:**

```powershell
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "msdb" -Q "
SELECT TOP 50
    j.name AS JobName,
    h.step_name,
    h.run_date,
    h.run_time,
    h.run_status = CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
    END,
    h.message
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE h.run_status = 0 -- Failed
    AND h.run_date >= CONVERT(INT, CONVERT(VARCHAR, DATEADD(DAY, -7, GETDATE()), 112))
ORDER BY h.run_date DESC, h.run_time DESC
"
```

---

## Step 5: Analyze Log Patterns

### Identify Common Issues

**Group errors by type:**

```powershell
$seqUrl = "http://seq.mos.siepe.local:5341"
$from = (Get-Date).AddHours(-24).ToString("yyyy-MM-ddTHH:mm:ss")
$filter = "Level = 'Error'"

$events = (Invoke-RestMethod -Uri "$seqUrl/api/events?filter=$filter&from=$from&count=1000" -Method GET).Events

# Group by message template
$grouped = $events | Group-Object -Property MessageTemplate | 
    Sort-Object Count -Descending | 
    Select-Object Count, Name

$grouped | Format-Table -AutoSize
```

**Timeline analysis:**

```powershell
# Group errors by hour
$events | Group-Object { (Get-Date $_.Timestamp).Hour } | 
    Sort-Object Name | 
    Select-Object @{N='Hour';E={$_.Name}}, @{N='ErrorCount';E={$_.Count}} |
    Format-Table
```

### Correlation Analysis

**Check if errors correlate with job execution:**

```powershell
# Get job execution times
$jobTimes = sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "msdb" -h -1 -W -Q "
SELECT 
    CAST(CAST(run_date AS VARCHAR) + ' ' + 
         STUFF(STUFF(RIGHT('000000' + CAST(run_time AS VARCHAR), 6), 3, 0, ':'), 6, 0, ':') AS DATETIME) AS execution_time
FROM msdb.dbo.sysjobhistory
WHERE run_date >= CONVERT(INT, CONVERT(VARCHAR, GETDATE(), 112))
"

# Get error times from SEQ
$filter = "Level = 'Error'"
$from = (Get-Date).Date.ToString("yyyy-MM-ddTHH:mm:ss")
$errorTimes = (Invoke-RestMethod -Uri "$seqUrl/api/events?filter=$filter&from=$from" -Method GET).Events.Timestamp

# Find errors within 5 minutes of job execution
# (Analysis logic here)
```

---

## Step 6: Generate HTML Report

**Create structured HTML response:**

```html
<div class="mossy-response">
  
  <div class="response-header">
    <h2>📋 Log Analysis Results</h2>
    <div class="metadata">
      <span class="badge badge-info">Logs</span>
      <span class="timestamp">{TIMESTAMP}</span>
    </div>
  </div>

  <div class="summary-section">
    <h3>🎯 Summary</h3>
    <div class="status-grid">
      <div class="status-card status-error">
        <div class="card-title">❌ Errors Found</div>
        <div class="card-value">{ERROR_COUNT}</div>
        <div class="card-detail">Last 24 hours</div>
      </div>
      <div class="status-card status-warning">
        <div class="card-title">⚠️ Warnings</div>
        <div class="card-value">{WARNING_COUNT}</div>
        <div class="card-detail">Attention needed</div>
      </div>
      <div class="status-card status-info">
        <div class="card-title">📊 Log Sources</div>
        <div class="card-value">{SOURCE_COUNT}</div>
        <div class="card-detail">Checked</div>
      </div>
    </div>
  </div>

  <div class="content-section">
    <h3>🔍 Error Details</h3>
    
    <table class="data-table">
      <thead>
        <tr>
          <th>Time</th>
          <th>Source</th>
          <th>Level</th>
          <th>Message</th>
        </tr>
      </thead>
      <tbody>
        {LOG_ENTRIES_ROWS}
      </tbody>
    </table>

    <details class="collapsible-section">
      <summary><strong>📊 Error Distribution by Hour</strong></summary>
      <div class="collapsible-content">
        <table class="data-table">
          <thead>
            <tr>
              <th>Hour</th>
              <th>Error Count</th>
              <th>Pattern</th>
            </tr>
          </thead>
          <tbody>
            {HOURLY_DISTRIBUTION_ROWS}
          </tbody>
        </table>
      </div>
    </details>

    <details class="collapsible-section">
      <summary><strong>🔬 Top Error Types</strong></summary>
      <div class="collapsible-content">
        <table class="data-table">
          <thead>
            <tr>
              <th>Count</th>
              <th>Error Type</th>
              <th>Impact</th>
            </tr>
          </thead>
          <tbody>
            {ERROR_TYPE_ROWS}
          </tbody>
        </table>
      </div>
    </details>
  </div>

  <div class="recommendations-section">
    <h3>✅ Findings & Recommendations</h3>
    <ul class="recommendation-list">
      <li class="recommendation-item {PRIORITY}">
        <strong>{FINDING_1}</strong>
        <span class="priority-badge">{PRIORITY_LEVEL}</span>
      </li>
    </ul>
  </div>

  <div class="response-footer">
    <button class="btn btn-primary" onclick="openSeq()">
      🔍 Open SEQ
    </button>
    <button class="btn btn-secondary" onclick="exportLogs('{REPORT_ID}')">
      💾 Export Logs
    </button>
    <button class="btn btn-secondary" onclick="viewFullReport('{REPORT_ID}')">
      📄 Full Report
    </button>
  </div>

</div>
```

---

## Step 7: Return Results

**Provide to user:**
1. ✅ Total error/warning count
2. ✅ Top error types and patterns
3. ✅ Timeline of events
4. ✅ Correlation with job executions
5. ✅ Specific error messages with context
6. ✅ Recommendations for investigation

**Save investigation to:** `C:\source\PipeWatch\Mossy\investigations\LogAnalysis_{DATE}.md`

---

## Common Log Patterns to Look For

### Connection Issues
- `"Login timeout expired"`
- `"A network-related or instance-specific error"`
- `"Communication link failure"`

### Data Issues
- `"Conversion failed"`
- `"NULL value cannot be inserted"`
- `"Violation of PRIMARY KEY constraint"`

### SSIS Package Issues
- `"DTS_E_OLEDBERROR"`
- `"Lookup component failed"`
- `"Package execution failed"`

### Performance Issues
- `"Query timeout"`
- `"Execution time exceeded"`
- `"Memory allocation failure"`

### Configuration Issues
- `"Variable not found"`
- `"Configuration file not found"`
- `"Invalid connection string"`
