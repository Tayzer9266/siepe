# Performance Optimization Investigation Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration

## Purpose
Systematic investigation and resolution of SQL Server performance issues including slow queries, timeouts, deadlocks, and resource contention. Enhanced with execution plan diagram analysis and performance graph screenshot interpretation. Provides query optimization strategies, index recommendations, and performance tuning guidance.

## When to Use This Skill
- Slow query triage alerts or tickets
- Query timeouts or command timeouts
- Deadlock errors
- Long-running procedures
- Report performance degradation
- Keywords: slow, performance, timeout, deadlock, hanging, long running, optimization

---

## Investigation Methodology

### Phase 0: Analyze Performance Screenshots and Wiki

**Step 0.1: Screenshot Analysis**
```powershell
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - Execution plan diagrams showing operators, costs, scans vs seeks
# - Performance graphs showing CPU, memory, I/O trends
# - Timeout error screenshots with execution times
# - Deadlock graphs showing transaction conflicts
# - Slow query reports with wait statistics
```

**Step 0.2: Fetch Wiki Best Practices**
```powershell
$wikiPath = "/Performance-Optimization-Best-Practices"  # Update with actual path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_Performance.md" -Encoding UTF8
```

### Phase 1: Identify Performance Issue Type

**Questions:**
1. **What type of performance issue?**
   - Slow query (specific query running slowly)
   - Timeout (query exceeds timeout threshold)
   - Deadlock (concurrent transaction conflict)
   - Resource contention (blocking, waits)

2. **Which object is affected?**
   - Stored procedure name
   - View name
   - Ad-hoc query pattern
   - Report/dashboard

3. **When does it occur?**
   - Specific time of day
   - During specific operations
   - Random/intermittent
   - After recent change

4. **What is the performance impact?**
   - Execution time (milliseconds)
   - Timeout threshold
   - User impact (# affected users)
   - Business criticality

---

### Phase 2: Slow Query Investigation

#### Step 2.1: Capture Execution Plan

```sql
-- Enable actual execution plan
SET STATISTICS IO ON
SET STATISTICS TIME ON
GO

-- Execute problem query
EXEC [ProcedureName] @Param1 = 'Value1', @Param2 = 'Value2'
GO

SET STATISTICS IO OFF
SET STATISTICS TIME OFF
```

**Or capture via DMV:**
```sql
-- Find cached plan for procedure
SELECT 
    cp.plan_handle,
    st.text AS QueryText,
    qp.query_plan,
    qs.execution_count,
    qs.total_elapsed_time / 1000 AS TotalElapsedMS,
    qs.total_elapsed_time / qs.execution_count / 1000 AS AvgElapsedMS,
    qs.total_logical_reads,
    qs.total_logical_reads / qs.execution_count AS AvgLogicalReads,
    qs.last_execution_time
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE st.text LIKE '%[ProcedureName]%'
ORDER BY qs.total_elapsed_time DESC
```

#### Step 2.2: Analyze Execution Plan

**Look for these red flags:**

| Indicator | Problem | Solution |
|-----------|---------|----------|
| **Table Scan** (100K+ rows) | No useful index | Add covering index |
| **Key Lookup** (high cost) | Missing included columns | Add columns to index |
| **Index Scan** (high cost) | Non-selective index | Add better index or update stats |
| **Sort** operator | ORDER BY not using index | Add index on sort columns |
| **Hash Match** (large tables) | Missing index on join | Add index on join columns |
| **Implicit Conversion** warning | Data type mismatch | Fix parameter/column types |
| **Parameter Sniffing** (varied plans) | Non-optimal plan cached | Use OPTIMIZE FOR or RECOMPILE |
| **Parallelism** (CXPACKET waits) | Query too parallel | Adjust MAXDOP or threshold |

#### Step 2.3: Check Index Usage

```sql
-- Find missing indexes for specific table
SELECT 
    migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS ImprovementMeasure,
    'CREATE INDEX [IX_' + OBJECT_NAME(mid.object_id) + '_' 
        + REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns, ''), ', ', '_'), '[', ''), ']', '') 
        + CASE WHEN mid.inequality_columns IS NOT NULL THEN '_' + REPLACE(REPLACE(REPLACE(mid.inequality_columns, ', ', '_'), '[', ''), ']', '') ELSE '' END
        + '] ON ' + mid.statement 
        + ' (' + ISNULL(mid.equality_columns, '') 
        + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END
        + ISNULL(mid.inequality_columns, '') + ')'
        + ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS CreateIndexStatement,
    migs.user_seeks,
    migs.user_scans,
    migs.avg_user_impact
FROM sys.dm_db_missing_index_groups mig
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE mid.database_id = DB_ID()
    AND OBJECT_NAME(mid.object_id) = '{TableName}'
ORDER BY ImprovementMeasure DESC
```

#### Step 2.4: Check Statistics Freshness

```sql
-- Check when statistics were last updated
SELECT 
    OBJECT_NAME(s.object_id) AS TableName,
    s.name AS StatName,
    s.stats_id,
    sp.last_updated,
    sp.rows,
    sp.rows_sampled,
    sp.modification_counter,
    CAST(sp.modification_counter AS FLOAT) / sp.rows * 100 AS PercentModified
FROM sys.stats s
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
WHERE OBJECT_NAME(s.object_id) = '{TableName}'
ORDER BY sp.last_updated
```

**Update stale statistics:**
```sql
UPDATE STATISTICS {TableName} WITH FULLSCAN
```

#### Step 2.5: Common Optimizations

**Add Covering Index:**
```sql
CREATE NONCLUSTERED INDEX IX_TableName_FilterCols
ON {TableName} (FilterColumn1, FilterColumn2)
INCLUDE (SelectColumn1, SelectColumn2, SelectColumn3)
```

**Handle Parameter Sniffing:**
```sql
-- Option 1: OPTIMIZE FOR hint
EXEC pProcedureName @Param1 = 'Value' OPTION (OPTIMIZE FOR (@Param1 = 'TypicalValue'))

-- Option 2: RECOMPILE (for highly variable plans)
ALTER PROCEDURE pProcedureName
WITH RECOMPILE
AS
...

-- Option 3: Local variable copy
CREATE PROCEDURE pProcedureName @Param1 VARCHAR(50)
AS
BEGIN
    DECLARE @LocalParam1 VARCHAR(50) = @Param1  -- Breaks parameter sniffing
    SELECT ... WHERE Column = @LocalParam1
END
```

---

### Phase 3: Timeout Investigation

#### Step 3.1: Measure Actual Execution Time

```sql
-- Measure procedure execution time
DECLARE @StartTime DATETIME2 = SYSDATETIME()

EXEC pProcedureName @Param1 = 'Value'

SELECT DATEDIFF(MILLISECOND, @StartTime, SYSDATETIME()) AS ElapsedMS
```

#### Step 3.2: Check for Blocking

```sql
-- Find active blocking chains
SELECT 
    blocking.session_id AS BlockingSessionID,
    blocked.session_id AS BlockedSessionID,
    blocking_sql.text AS BlockingQuery,
    blocked_sql.text AS BlockedQuery,
    blocked.wait_type,
    blocked.wait_time,
    blocked.last_wait_type
FROM sys.dm_exec_requests blocked
LEFT JOIN sys.dm_exec_requests blocking 
    ON blocked.blocking_session_id = blocking.session_id
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_sql
OUTER APPLY sys.dm_exec_sql_text(blocking.sql_handle) blocking_sql
WHERE blocked.blocking_session_id > 0
```

#### Step 3.3: Resolution Strategies

| Timeout Cause | Solution |
|---------------|----------|
| Query too expensive | Optimize query (see Phase 2) |
| Blocking | Identify and kill blocker, reduce transaction scope |
| Resource contention | Schedule during off-peak, increase resources |
| Large result set | Add pagination, return fewer rows |
| Appropriate timeout | Increase timeout threshold (last resort) |

---

### Phase 4: Deadlock Investigation

#### Step 4.1: Capture Deadlock Graph

```sql
-- Enable deadlock trace flag (capture to error log)
DBCC TRACEON(1222, -1)  -- Detailed deadlock info

-- Or use Extended Events
CREATE EVENT SESSION CaptureDeadlocks ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file(SET filename=N'C:\Temp\Deadlocks.xel')
GO

ALTER EVENT SESSION CaptureDeadlocks ON SERVER STATE = START
GO
```

#### Step 4.2: Analyze Deadlock Victim

**Typical deadlock pattern:**
- Session A locks Table1, needs Table2
- Session B locks Table2, needs Table1
- Deadlock detected, one session chosen as victim

**Deadlock graph shows:**
- Resource types (KEY, PAGE, TABLE)
- Lock modes (X, S, U, IX, IS)
- Queries involved
- Victim selection

#### Step 4.3: Resolve Deadlocks

**Strategy 1: Consistent Lock Order**
```sql
-- BAD: Different lock order causes deadlocks
-- Session A:
UPDATE Table1 WHERE ID = 1
UPDATE Table2 WHERE ID = 1

-- Session B:
UPDATE Table2 WHERE ID = 2  -- Locks Table2 first
UPDATE Table1 WHERE ID = 2  -- Then needs Table1 (deadlock!)

-- GOOD: Same lock order
-- Both sessions:
UPDATE Table1 WHERE ID = @ID
UPDATE Table2 WHERE ID = @ID  -- Always Table1 then Table2
```

**Strategy 2: Reduce Transaction Scope**
```sql
-- BAD: Long transaction
BEGIN TRANSACTION
    SELECT ... (slow query)
    UPDATE ...
    SELECT ... (another slow query)
    UPDATE ...
COMMIT

-- GOOD: Minimal transaction
SELECT ... (outside transaction)
BEGIN TRANSACTION
    UPDATE ...  -- Only updates in transaction
    UPDATE ...
COMMIT
SELECT ... (outside transaction)
```

**Strategy 3: Add Indexes to Reduce Locks**
```sql
-- Fewer rows locked = fewer conflicts
CREATE INDEX IX_Table_FilterColumn ON Table (FilterColumn)
```

**Strategy 4: Use SNAPSHOT Isolation**
```sql
-- Enable snapshot isolation (reads don't block writes)
ALTER DATABASE MOS SET ALLOW_SNAPSHOT_ISOLATION ON
ALTER DATABASE MOS SET READ_COMMITTED_SNAPSHOT ON
```

---

### Phase 5: Resource Contention Analysis

#### Step 5.1: Check Wait Statistics

```sql
-- Top wait types
SELECT 
    wait_type,
    wait_time_ms / 1000.0 AS WaitTimeSec,
    waiting_tasks_count,
    wait_time_ms / waiting_tasks_count AS AvgWaitMS
FROM sys.dm_os_wait_stats
WHERE wait_type NOT IN (
    'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 
    'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 
    'WAITFOR', 'LOGMGR_QUEUE', 'CHECKPOINT_QUEUE', 'REQUEST_FOR_DEADLOCK_SEARCH'
)
ORDER BY wait_time_ms DESC
```

**Common wait types:**
- `CXPACKET`: Parallelism coordination
- `PAGEIOLATCH_*`: Disk I/O
- `LCK_M_*`: Lock waits (blocking)
- `WRITELOG`: Transaction log writes
- `SOS_SCHEDULER_YIELD`: CPU pressure

#### Step 5.2: Check CPU and Memory Pressure

```sql
-- Current CPU usage
SELECT 
    scheduler_id,
    cpu_id,
    status,
    current_tasks_count,
    runnable_tasks_count,
    pending_disk_io_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255

-- Memory usage
SELECT 
    physical_memory_in_use_kb / 1024 AS PhysicalMemoryUsedMB,
    total_physical_memory_kb / 1024 AS TotalPhysicalMemoryMB,
    available_physical_memory_kb / 1024 AS AvailablePhysicalMemoryMB,
    system_high_memory_signal_state,
    system_low_memory_signal_state
FROM sys.dm_os_sys_memory
```

---

### Phase 6: Procedure-Specific Optimizations

#### Common MOS Procedure Patterns

**Pattern 1: Temp Table vs. CTE vs. Table Variable**
```sql
-- SLOW: CTE with multiple references (re-executed each time)
WITH LargeCTE AS (SELECT ... complex query ...)
SELECT * FROM LargeCTE a JOIN LargeCTE b ...

-- FAST: Temp table (materialized once)
SELECT ... INTO #LargeTemp FROM ... complex query ...
CREATE INDEX IX_Temp ON #LargeTemp (KeyColumn)
SELECT * FROM #LargeTemp a JOIN #LargeTemp b ...
```

**Pattern 2: NOLOCK Hints for Reports**
```sql
-- Add NOLOCK for read-only reports (avoid blocking)
SELECT * FROM Core.dbo.vPosition WITH (NOLOCK)
WHERE PositionDate = @Date
```

**Pattern 3: EXISTS vs. IN vs. JOIN**
```sql
-- SLOW: IN with subquery
WHERE PortfolioID IN (SELECT PortfolioID FROM ...)

-- FAST: EXISTS (stops at first match)
WHERE EXISTS (SELECT 1 FROM ... WHERE ...)

-- FAST: JOIN with DISTINCT (if returning columns from subquery)
SELECT DISTINCT ... FROM Table1 t1 JOIN (...) t2 ON ...
```

---

### Phase 7: Monitoring and Alerting

#### Set Up Performance Monitoring

**Query Store:**
```sql
-- Enable Query Store
ALTER DATABASE MOS SET QUERY_STORE = ON
ALTER DATABASE MOS SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1000
)

-- Find regressed queries
SELECT 
    q.query_id,
    qt.query_sql_text,
    rs_recent.avg_duration / 1000 AS Recent_AvgDurationMS,
    rs_old.avg_duration / 1000 AS Old_AvgDurationMS,
    (rs_recent.avg_duration - rs_old.avg_duration) / 1000 AS RegressionMS
FROM sys.query_store_query q
JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_plan p ON q.query_id = p.query_id
JOIN sys.query_store_runtime_stats rs_recent ON p.plan_id = rs_recent.plan_id
JOIN sys.query_store_runtime_stats rs_old ON p.plan_id = rs_old.plan_id
WHERE rs_recent.last_execution_time > DATEADD(day, -1, GETDATE())
    AND rs_old.last_execution_time < DATEADD(day, -7, GETDATE())
    AND rs_recent.avg_duration > rs_old.avg_duration * 1.5  -- 50% slower
ORDER BY RegressionMS DESC
```

**SiepeAdmin Slow Query Triage:**
```sql
-- Log slow queries to monitoring table
INSERT INTO SiepeAdmin.dbo.tSlowQueryLog (
    DatabaseName, ProcedureName, AvgDurationMS, ExecutionCount, LogDate
)
SELECT 
    DB_NAME() AS DatabaseName,
    OBJECT_NAME(s.object_id) AS ProcedureName,
    s.total_elapsed_time / s.execution_count / 1000 AS AvgDurationMS,
    s.execution_count,
    GETDATE() AS LogDate
FROM sys.dm_exec_procedure_stats s
WHERE s.total_elapsed_time / s.execution_count > 10000000  -- > 10 seconds avg
```

---

## Example Investigations

### Example 1: Slow Procedure - Missing Index

**Ticket:** "[Slow Query Triage] dbo.pRefDataSetIU (Elmwood) - avg 72302ms"

**Investigation:**
```sql
-- Captured execution plan
SET STATISTICS IO ON
EXEC Core.dbo.pRefDataSetIU @CompanyID = 10

-- Found: Table Scan on tRefDataSet (500K rows)
-- Cost: 85% of query

-- Checked missing indexes
SELECT * FROM sys.dm_db_missing_index_details
WHERE OBJECT_NAME(object_id) = 'tRefDataSet'
-- Suggestion: Index on (CompanyID, RefDataSetDate)
```

**Resolution:**
```sql
CREATE NONCLUSTERED INDEX IX_RefDataSet_CompanyDate
ON Core.dbo.tRefDataSet (CompanyID, RefDataSetDate)
INCLUDE (RefDataSetID, Active, BusinessDate)

-- Execution time: 72s → 2s (97% improvement)
```

### Example 2: Deadlock - Lock Order Issue

**Ticket:** "Deadlock between cash rec approval and balance update"

**Deadlock Graph Analysis:**
- Session A: Updates CashRec.tBalance, then CashRec.tTransaction
- Session B: Updates CashRec.tTransaction, then CashRec.tBalance
- Deadlock when A locks Balance, B locks Transaction

**Resolution:**
```sql
-- Standardize lock order: Always Balance → Transaction
ALTER PROCEDURE CashRec.pApproveReconciliation
AS
BEGIN TRANSACTION
    -- Lock Balance first
    UPDATE CashRec.tBalance WITH (UPDLOCK) ...
    -- Then Transaction
    UPDATE CashRec.tTransaction ...
COMMIT
```

### Example 3: Timeout - Parameter Sniffing

**Ticket:** "Position report times out for large portfolios"

**Investigation:**
```sql
-- Works fast for small portfolio (10K positions)
EXEC Report.pPositionReport @PortfolioID = 42
-- Execution: 5 seconds

-- Times out for large portfolio (500K positions)
EXEC Report.pPositionReport @PortfolioID = 99
-- Execution: 120+ seconds, timeout

-- Found: Plan optimized for small portfolio, scans index for large
```

**Resolution:**
```sql
ALTER PROCEDURE Report.pPositionReport @PortfolioID INT
AS
BEGIN
    -- Force recompile for each execution
    OPTION (RECOMPILE)
    
    -- Or optimize for typical large portfolio
    OPTION (OPTIMIZE FOR (@PortfolioID = 99))
END
```

---

## Skill Metadata

- **Skill Name:** performance-optimization
- **Category:** Performance Issues
- **Complexity:** High
- **Execution Time:** 30-90 minutes
- **Prerequisites:** SSMS, execution plan analysis, index knowledge
- **Outputs:** Optimized queries, index recommendations, execution plan analysis
- **Related Skills:**
  - check-ssis-errors (SSIS performance issues)
  - data-normalization (slow normalization views)
  - cash-reconciliation (SFR timeouts)
