# SSIS Package Troubleshooting

**Category:** ETL Debugging  
**Difficulty:** Intermediate  
**Est. Time:** 10-15 minutes

## Purpose

Investigate SSIS package failures, normalization errors, and ETL job issues by analyzing execution logs, database state, and error messages.

---

## Step 1: Identify the Failed Package

**Ask the user (if not provided):**
- Which SSIS package failed?
- Which tenant/client is affected?
- When did the failure occur?

**Common Packages:**
- `ImportGenericCSV.dtsx` - Generic data imports
- `NormalizeGenericInstrument.dtsx` - Instrument normalization
- `NormalizeGenericPricing.dtsx` - Pricing data normalization
- `PricingDataLoad.dtsx` - MOS pricing loads
- `CashReconciliation.dtsx` - Cash balance reconciliation

---

## Step 2: Check SSIS Execution Status

**Query SSISDB catalog for recent executions:**

```powershell
sqlcmd -S "SSIS-SERVER.mos.siepe.local" -d "SSISDB" -Q "
SELECT TOP 10
    execution_id,
    folder_name,
    project_name,
    package_name,
    status = CASE status
        WHEN 1 THEN 'Created'
        WHEN 2 THEN 'Running'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'Failed'
        WHEN 5 THEN 'Pending'
        WHEN 6 THEN 'Ended Unexpectedly'
        WHEN 7 THEN 'Succeeded'
        WHEN 8 THEN 'Stopping'
        WHEN 9 THEN 'Completed'
    END,
    start_time,
    end_time,
    DATEDIFF(MINUTE, start_time, end_time) AS duration_minutes
FROM catalog.executions
WHERE package_name LIKE '%{PACKAGE_NAME}%'
    OR package_name LIKE '%Generic%'
ORDER BY start_time DESC
"
```

**Expected Output:**
- Execution ID for failed run
- Status (should be 'Failed' or 'Ended Unexpectedly')
- Timestamp of failure
- Duration (may indicate timeout vs error)

**Red Flags:**
- ⚠️ Duration > 60 minutes (possible timeout)
- ❌ Status = Failed (error occurred)
- 🔄 Multiple rapid failures (config issue)

---

## Step 3: Get Detailed Error Messages

**Using execution_id from Step 2, get error details:**

```powershell
sqlcmd -S "SSIS-SERVER.mos.siepe.local" -d "SSISDB" -Q "
SELECT 
    operation_id,
    message_time,
    message_type = CASE message_type
        WHEN 120 THEN 'Error'
        WHEN 110 THEN 'Warning'
        WHEN 70 THEN 'Information'
        WHEN 10 THEN 'Pre-validate'
        WHEN 20 THEN 'Post-validate'
        WHEN 30 THEN 'Pre-execute'
        WHEN 40 THEN 'Post-execute'
        WHEN 60 THEN 'Progress'
        WHEN 50 THEN 'StatusChange'
        WHEN 100 THEN 'QueryCancel'
        WHEN 130 THEN 'TaskFailed'
        WHEN 90 THEN 'Diagnostic'
        WHEN 200 THEN 'Custom'
        WHEN 140 THEN 'DiagnosticEx'
        WHEN 400 THEN 'NonDiagnostic'
        WHEN 80 THEN 'VariableValueChanged'
    END,
    message_source_name,
    message AS error_message,
    package_path
FROM catalog.event_messages
WHERE operation_id = {EXECUTION_ID}
    AND message_type IN (120, 130) -- Errors and TaskFailed
ORDER BY message_time DESC
"
```

**Expected Output:**
- Error code (e.g., 0xC0202009, 0xC020801C)
- Component name where error occurred
- Specific error message
- Package path to failed component

**Common Error Codes:**
- `0xC0202009` - OLEDB error (connection/query issue)
- `0xC020801C` - Lookup component failed
- `0xC0047062` - Data conversion error
- `0xC001602A` - Connection timeout
- `0x80131904` - General .NET exception

---

## Step 4: Check GenericImportJob Status (If Applicable)

**If package is ImportGenericCSV.dtsx:**

```powershell
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Integration" -Q "
SELECT TOP 20
    ImportJobID,
    TenantShortName,
    SourceName,
    FileName,
    ImportType,
    Status,
    StartDate,
    EndDate,
    ErrorMessage,
    RowsImported,
    RowsRejected
FROM GenericImportJob
WHERE TenantShortName LIKE '%{TENANT}%'
    OR SourceName LIKE '%{SOURCE}%'
ORDER BY StartDate DESC
"
```

**Status Values:**
- `Pending` - Queued but not started
- `Processing` - Currently running
- `Completed` - Success
- `Failed` - Error occurred
- `PartialSuccess` - Some rows failed

**Red Flags:**
- ❌ ErrorMessage is not null (check this first)
- ⚠️ RowsRejected > 0 (data quality issue)
- 🔄 Status = Failed repeatedly (config or source issue)

---

## Step 5: Check GenericNormalizationJob Status

**If package is NormalizeGeneric*.dtsx:**

```powershell
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Integration" -Q "
SELECT TOP 20
    NormalizationJobID,
    ImportJobID,
    TenantShortName,
    NormalizationType,
    Status,
    StartDate,
    EndDate,
    ErrorMessage,
    RecordsProcessed,
    RecordsFailed
FROM GenericNormalizationJob
WHERE TenantShortName LIKE '%{TENANT}%'
    AND NormalizationType LIKE '%{TYPE}%' -- Instrument, Pricing, Transaction
ORDER BY StartDate DESC
"
```

**Common Normalization Failures:**
- Missing mapping in `GenericFieldMapping` table
- NULL values in required fields
- Data type mismatch
- Foreign key constraint violation

---

## Step 6: Check SEQ Logs (Real-Time)

**Open SEQ and filter:**
- URL: http://seq.mos.siepe.local:5341
- Filter: `Application = 'SSIS' AND MessageTemplate CONTAINS '{PACKAGE_NAME}'`
- Time: Last 24 hours

**Or query via API:**

```powershell
$seqUrl = "http://seq.mos.siepe.local:5341"
$query = "Application = 'SSIS' AND MessageTemplate CONTAINS '{PACKAGE_NAME}'"
$from = (Get-Date).AddHours(-24).ToString("yyyy-MM-ddTHH:mm:ss")

Invoke-RestMethod -Uri "$seqUrl/api/events?filter=$query&from=$from" -Method GET
```

**Look for:**
- Exception stack traces
- Connection errors
- Data validation errors
- Performance warnings

---

## Step 7: Check SQL Agent Job History (If Scheduled)

**Get recent job run history:**

```powershell
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "msdb" -Q "
SELECT TOP 20
    j.name AS JobName,
    h.step_name AS StepName,
    h.run_date,
    h.run_time,
    h.run_status = CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
    END,
    h.run_duration,
    h.message
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE j.name LIKE '%{JOB_NAME}%'
ORDER BY h.run_date DESC, h.run_time DESC
"
```

**Red Flags:**
- ❌ run_status = 0 (Failed)
- ⏱️ run_duration suddenly different (performance regression)
- 🔄 Retry status (transient errors)

---

## Step 8: Diagnose Root Cause

**Based on error analysis, categorize:**

### Connection/Timeout Errors
- **Symptoms:** 0xC0202009, "Login timeout expired", "Communication link failure"
- **Root Causes:**
  - Database server offline or restarting
  - Network connectivity issues
  - Connection pool exhausted
  - Firewall blocking port
- **Actions:**
  - Verify database server is online
  - Check network connectivity
  - Review connection timeout settings (increase if needed)
  - Check firewall rules

### Data Errors
- **Symptoms:** 0xC020801C, "Lookup failed", "Data conversion error"
- **Root Causes:**
  - Missing reference data in lookup tables
  - NULL values in non-nullable columns
  - Data type mismatch
  - Source data quality issue
- **Actions:**
  - Query lookup tables to verify reference data exists
  - Check source file for unexpected NULLs or formats
  - Review data type mappings
  - Add data validation to source

### Package Configuration Errors
- **Symptoms:** "Variable not found", "Configuration file missing"
- **Root Causes:**
  - Package configuration not deployed
  - Environment variables not set
  - Connection manager not configured
- **Actions:**
  - Verify package configuration in SSISDB
  - Check environment variable values
  - Review connection manager settings

### Performance/Timeout
- **Symptoms:** Long run_duration, "Execution timeout"
- **Root Causes:**
  - Large data volume
  - Missing indexes on lookup tables
  - Blocking/locking on target database
  - Network latency
- **Actions:**
  - Add indexes to lookup tables
  - Check for blocking queries
  - Optimize data flow buffers
  - Consider batch processing

---

## Step 9: Generate HTML Report

**Create structured HTML response:**

```html
<div class="mossy-response">
  
  <div class="response-header">
    <h2>🔧 SSIS Package Error Analysis</h2>
    <div class="metadata">
      <span class="badge badge-danger">Critical</span>
      <span class="timestamp">{TIMESTAMP}</span>
    </div>
  </div>

  <div class="summary-section">
    <h3>🎯 Summary</h3>
    <div class="alert alert-danger">
      <strong>Error Found:</strong> {ERROR_SUMMARY}
    </div>
  </div>

  <div class="content-section">
    <h3>🔍 Error Details</h3>
    
    <table class="data-table">
      <tr>
        <td><strong>Package Name</strong></td>
        <td>{PACKAGE_NAME}</td>
      </tr>
      <tr>
        <td><strong>Execution Date</strong></td>
        <td>{EXECUTION_DATE}</td>
      </tr>
      <tr>
        <td><strong>Error Code</strong></td>
        <td><code>{ERROR_CODE}</code></td>
      </tr>
      <tr>
        <td><strong>Component</strong></td>
        <td>{COMPONENT_NAME}</td>
      </tr>
      <tr>
        <td><strong>Tenant</strong></td>
        <td>{TENANT_NAME}</td>
      </tr>
    </table>

    <div class="code-block">
      <div class="code-header">
        <span class="language-badge">Error Message</span>
        <button class="copy-btn" onclick="copyCode(this)">📋 Copy</button>
      </div>
      <pre><code>{ERROR_MESSAGE}</code></pre>
    </div>

    <details class="collapsible-section">
      <summary><strong>📊 Recent Execution History</strong></summary>
      <div class="collapsible-content">
        <table class="data-table">
          <thead>
            <tr>
              <th>Date</th>
              <th>Status</th>
              <th>Duration</th>
            </tr>
          </thead>
          <tbody>
            {EXECUTION_HISTORY_ROWS}
          </tbody>
        </table>
      </div>
    </details>
  </div>

  <div class="recommendations-section">
    <h3>✅ Recommended Actions</h3>
    <ul class="recommendation-list">
      <li class="recommendation-item high-priority">
        <strong>1. {PRIMARY_ACTION}</strong>
        <span class="priority-badge">Immediate</span>
      </li>
      <li class="recommendation-item high-priority">
        <strong>2. {SECONDARY_ACTION}</strong>
        <span class="priority-badge">Immediate</span>
      </li>
      <li class="recommendation-item medium-priority">
        <strong>3. {PREVENTIVE_ACTION}</strong>
        <span class="priority-badge">Preventive</span>
      </li>
    </ul>
  </div>

  <div class="response-footer">
    <button class="btn btn-danger" onclick="retryJob('{JOB_NAME}')">
      🔄 Retry Job
    </button>
    <button class="btn btn-secondary" onclick="viewSeqLogs('{PACKAGE_NAME}')">
      📋 View SEQ Logs
    </button>
    <button class="btn btn-secondary" onclick="viewFullReport('{REPORT_ID}')">
      📄 Full Report
    </button>
  </div>

</div>
```

---

## Step 10: Return Results

**Provide to user:**
1. ✅ Root cause diagnosis
2. ✅ Error details with context
3. ✅ Execution history analysis
4. ✅ Recommended remediation steps
5. ✅ SQL queries to fix (if applicable)
6. ✅ Preventive measures

**Save investigation to:** `C:\source\PipeWatch\Mossy\investigations\SSIS_{PACKAGE}_{DATE}.md`
