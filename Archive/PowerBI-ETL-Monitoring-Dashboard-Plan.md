# Power BI ETL Monitoring Dashboard - Implementation Plan

**Created:** 2026-07-06  
**Purpose:** Consolidated monitoring of all ETL processes across Siepe databases for preventative measures

---

## Overview

This plan outlines the architecture for a Power BI dashboard that monitors distributed ETL event logs across Core, Feeds, and Reference databases. The solution uses a materialized summary table approach for performance while maintaining the benefits of the distributed source architecture.

---

## Architecture: Materialized Summary + Real-Time Views

### Design Principles
- **Centralized reporting layer** without forcing a unified physical log
- **Fast Power BI performance** through pre-aggregated summary table
- **Real-time capability** through DirectQuery views when needed
- **Preventative monitoring** via trend analysis and anomaly detection

---

## Database Server Reference

### MOS Production Server
**Server:** `mos-sql-p.mos.siepe.local,52155`  
**Authentication:** Windows Integrated Security (SSO)

**Available Databases:**
- `Core` - Main operational database (jobs, positions, trades, cash rec, mappings)
- `Feeds` - ETL source data staging (SSIS logs, vendor imports)
- `Reference` - Reference data (securities, issuers, legal entities)
- `Enterprise` - Enterprise-wide data
- `Portal` - Portal/UI configuration
- `SiepeAdmin` - System administration

### Solvas Development Server
**Server:** `SOLVAS-SQL-D.mos.siepe.local,52156`  
**Authentication:** Windows Integrated Security (SSO)

**Available Databases:**
- `Solvas_AM` - Solvas Asset Manager integration (separate server)
- `Feeds` - Solvas-specific feed data
- `Digitize_Staging` - Document digitization staging

**Note:** Solvas Asset Loader process results may be tracked in `Solvas_AM` database on the development server, NOT in the main MOS production Feeds database.

---

## Step 1: Create Consolidated Summary Table

### Core Database Summary Table

```sql
-- Core Database
CREATE TABLE [dbo].[tETLMonitoringSummary] (
    [ETLMonitoringSummaryID] INT IDENTITY(1,1) NOT NULL,
    [LogSource] VARCHAR(50) NOT NULL,           -- 'Core.SvcJobs', 'Feeds.SSIS', etc.
    [ProcessName] VARCHAR(200) NOT NULL,        -- Job name, package name, loader name
    [ProcessType] VARCHAR(100) NOT NULL,        -- 'Job', 'SSIS', 'Loader', 'Import'
    [EventDate] DATETIME NOT NULL,
    [Status] VARCHAR(20) NOT NULL,              -- 'Success', 'Failed', 'Warning', 'Running'
    [DurationSeconds] INT NULL,
    [RecordsProcessed] INT NULL,
    [RecordsFailed] INT NULL,
    [ErrorCount] INT NULL,
    [ErrorMessage] VARCHAR(1000) NULL,          -- Brief summary
    [SourceEventID] INT NULL,                   -- Link back to source table
    [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE(),
    [RefRecStatusID] INT NOT NULL DEFAULT 1,
    
    CONSTRAINT [PK_dbo_tETLMonitoringSummary] PRIMARY KEY CLUSTERED 
    ([ETLMonitoringSummaryID] ASC) WITH (FILLFACTOR = 90) ON [FGDATA01],
    
    -- Optimized for Power BI queries
    INDEX [IX_tETLMonitoringSummary_EventDate_Status] NONCLUSTERED 
    ([EventDate] DESC, [Status]) INCLUDE ([ProcessName], [DurationSeconds]) ON [FGDATA01]
) ON [FGDATA01]
```

### Extended Properties

```sql
EXEC dbo.pExtendedPropertyIU @schema = 'dbo', @table = 'tETLMonitoringSummary', 
    @description = 'Consolidated ETL monitoring summary for Power BI reporting and preventative monitoring'
GO
EXEC dbo.pExtendedPropertyIU @schema = 'dbo', @table = 'tETLMonitoringSummary', 
    @Column = 'LogSource', @description = 'Source system identifier (e.g., Core.SvcJobs, Feeds.SSIS)'
GO
EXEC dbo.pExtendedPropertyIU @schema = 'dbo', @table = 'tETLMonitoringSummary', 
    @Column = 'ProcessName', @description = 'Human-readable process name'
GO
EXEC dbo.pExtendedPropertyIU @schema = 'dbo', @table = 'tETLMonitoringSummary', 
    @Column = 'ProcessType', @description = 'Process category: Job, SSIS, Loader, Import'
GO
EXEC dbo.pExtendedPropertyIU @schema = 'dbo', @table = 'tETLMonitoringSummary', 
    @Column = 'Status', @description = 'Execution status: Success, Failed, Warning, Running'
GO
EXEC dbo.pExtendedPropertyIU @schema = 'dbo', @table = 'tETLMonitoringSummary', 
    @Column = 'SourceEventID', @description = 'Foreign key to source event log table for drill-through'
GO
```

---

## Step 2: Create Consolidation Views

### View for Job Execution Events (Core Database)

**Note:** `SvcJobs.tJobAudit` is the newer job framework. If not yet deployed, use `IRA.tProcessResult` (see alternative below).

```sql
-- OPTION 1: SvcJobs Framework (Newer - use if available)
CREATE VIEW [dbo].[vETLMonitoring_Jobs] AS
SELECT 
    'Core.SvcJobs' AS LogSource,
    CONCAT(jt.JobTypeName, ' - ', ja.DeduplicationKey) AS ProcessName,
    'Job' AS ProcessType,
    ja.ActionDate AS EventDate,
    CASE 
        WHEN ja.Action = 'Completed' THEN 'Success'
        WHEN ja.Action = 'Failed' THEN 'Failed'
        WHEN ja.Action = 'Started' THEN 'Running'
        ELSE 'Warning'
    END AS Status,
    NULL AS DurationSeconds,  -- Calculate from Started/Completed pairs if needed
    NULL AS RecordsProcessed,
    NULL AS RecordsFailed,
    NULL AS ErrorCount,
    ja.ActionDetail AS ErrorMessage,
    ja.JobAuditID AS SourceEventID
FROM [SvcJobs].[tJobAudit] ja
INNER JOIN [SvcJobs].[tJobType] jt ON ja.JobTypeID = jt.JobTypeID
WHERE ja.RefRecStatusID = 1
GO

-- OPTION 2: IRA Framework (Older - use if SvcJobs not available)
CREATE VIEW [dbo].[vETLMonitoring_IRAProcess] AS
SELECT 
    'Core.IRA' AS LogSource,
    COALESCE(
        pf.OverrideName, 
        'Process-' + CAST(pr.ProcessJournalID AS VARCHAR(20)) + 
        CASE WHEN pr.Link IS NOT NULL THEN ' - ' + pr.Link ELSE '' END
    ) AS ProcessName,
    'IRAProcess' AS ProcessType,
    pr.CreatedDate AS EventDate,
    CASE 
        WHEN ps.Name IN ('Complete', 'Completed', 'Success', 'Successful') THEN 'Success'
        WHEN ps.Name IN ('Error', 'Failed', 'Failure') THEN 'Failed'
        WHEN ps.IsRunningStatus = 1 THEN 'Running'
        ELSE 'Warning'
    END AS Status,
    NULL AS DurationSeconds,
    NULL AS RecordsProcessed,
    NULL AS RecordsFailed,
    NULL AS ErrorCount,
    pr.MessageBody AS ErrorMessage,
    pr.ProcessJournalID AS SourceEventID
FROM [IRA].[tProcessResult] pr
LEFT JOIN [IRA].[tProcessStatus] ps ON pr.Status = ps.ProcessStatusID
LEFT JOIN [IRA].[tProcessFlow] pf ON pr.ProcessQueueID = pf.ProcessFlowID
WHERE pr.RefRecStatusID = 1
GO
```

### View for SSIS Executions (Feeds Database)

```sql
CREATE VIEW [dbo].[vETLMonitoring_SSIS] AS
SELECT 
    'Feeds.SSIS' AS LogSource,
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
    ssis.DeleteCount AS RecordsFailed,  -- DeleteCount may represent failed/rejected records
    CASE WHEN ssis.EventCode <> 0 THEN 1 ELSE 0 END AS ErrorCount,
    ssis.EventDescription AS ErrorMessage,
    ssis.EventID AS SourceEventID
FROM [Feeds].[dbo].[tSSISImportEventLog] ssis
WHERE ssis.RefDataSetID IS NOT NULL
GO
```

### View for Asset/Trade Loaders (Solvas_AM Database)

**✅ VERIFIED:** Asset loader process tracking found in `Process_Log` table

**Server:** `SOLVAS-SQL-D.mos.siepe.local,52156`  
**Database:** `Solvas_AM`  
**Schema:** `dbo`  
**Table:** `Process_Log`

**Investigation Notes (2026-07-06):**
- ✅ Found: `[dbo].[Process_Log]` tracks ASSET_LOADER, TRADE_LOADER, and other Solvas processes
- Process Status Codes: `BEG` (Begin), `LOAD` (Loading), `VALD` (Validated), `OK` (Success), `ERR` (Error)
- Filter by `processed_by = 'ASSET_LOADER'` for asset loading events
- Filter by `processed_by = 'TRADE_LOADER'` for trade loading events

**Table Columns:**
- `process_id` (int) - Primary key
- `tool_id` (int) - Reference to tool/process type
- `file_name` (varchar 1000) - Source file name if applicable
- `start_time` (datetime) - Process start timestamp
- `end_time` (datetime) - Process end timestamp  
- `process_status` (char 4) - Status: BEG, LOAD, VALD, OK, ERR
- `error_message` (varchar 500) - Error summary
- `error_body` (varchar 4000) - Detailed error information
- `total_records_count` (int) - Records processed
- `processed_by` (varchar 50) - Process identifier (ASSET_LOADER, TRADE_LOADER, etc.)

**ETL Monitoring View:**
```sql
-- Use linked server or separate connection to SOLVAS-SQL-D
CREATE VIEW [dbo].[vETLMonitoring_SolvasLoaders] AS
SELECT 
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
FROM [SOLVAS-SQL-D_LinkedServer].[Solvas_AM].[dbo].[Process_Log]
WHERE processed_by IN ('ASSET_LOADER', 'TRADE_LOADER')
    AND start_time >= DATEADD(DAY, -7, GETDATE())  -- Last 7 days
GO
```

**Note:** Requires linked server to SOLVAS-SQL-D or separate ETL process to copy data to Core database for unified reporting.

### Union View for All ETL Events

```sql
CREATE VIEW [dbo].[vETLMonitoring_All] AS
-- Choose ONE of the job frameworks (SvcJobs OR IRA)
SELECT * FROM [dbo].[vETLMonitoring_Jobs]  -- Use if SvcJobs exists
-- OR
-- SELECT * FROM [dbo].[vETLMonitoring_IRAProcess]  -- Use if only IRA exists
UNION ALL
SELECT * FROM [dbo].[vETLMonitoring_SSIS]
UNION ALL
SELECT * FROM [dbo].[vETLMonitoring_Loaders]
-- Add more sources as needed
GO
```

---

## Step 3: Populate Summary Table (Scheduled Job)

### Refresh Stored Procedure

```sql
CREATE PROCEDURE [dbo].[pETLMonitoringSummaryRefresh]
    @DaysBack INT = 1  -- Only refresh recent data
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION
        
        -- Delete recent data that will be refreshed
        DELETE FROM [dbo].[tETLMonitoringSummary]
        WHERE EventDate >= DATEADD(DAY, -@DaysBack, GETDATE())
        
        -- Insert consolidated data
        INSERT INTO [dbo].[tETLMonitoringSummary]
            (LogSource, ProcessName, ProcessType, EventDate, Status, 
             DurationSeconds, RecordsProcessed, RecordsFailed, ErrorCount, ErrorMessage, SourceEventID)
        SELECT 
            LogSource, ProcessName, ProcessType, EventDate, Status,
            DurationSeconds, RecordsProcessed, RecordsFailed, ErrorCount, ErrorMessage, SourceEventID
        FROM [dbo].[vETLMonitoring_All]
        WHERE EventDate >= DATEADD(DAY, -@DaysBack, GETDATE())
        
        -- Update statistics for query optimization
        UPDATE STATISTICS [dbo].[tETLMonitoringSummary]
        
        COMMIT TRANSACTION
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION
            
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY()
        DECLARE @ErrorState INT = ERROR_STATE()
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
    END CATCH
END
GO
```

### SQL Server Agent Job (Schedule)

```sql
-- Create SQL Agent Job to run every 15 minutes
USE [msdb]
GO

EXEC msdb.dbo.sp_add_job
    @job_name = N'ETL Monitoring Summary Refresh',
    @enabled = 1,
    @description = N'Refreshes tETLMonitoringSummary for Power BI dashboard'
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = N'ETL Monitoring Summary Refresh',
    @step_name = N'Refresh Summary',
    @subsystem = N'TSQL',
    @command = N'EXEC [dbo].[pETLMonitoringSummaryRefresh] @DaysBack = 1',
    @database_name = N'Core'
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = N'Every 15 Minutes',
    @freq_type = 4,  -- Daily
    @freq_interval = 1,
    @freq_subday_type = 4,  -- Minutes
    @freq_subday_interval = 15
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = N'ETL Monitoring Summary Refresh',
    @schedule_name = N'Every 15 Minutes'
GO
```

---

## Step 4: Key Metrics View for Preventative Monitoring

### Metrics and Anomaly Detection View

```sql
CREATE VIEW [dbo].[vETLMonitoring_Metrics] AS
SELECT 
    ProcessName,
    ProcessType,
    CAST(EventDate AS DATE) AS EventDay,
    
    -- Success Rate Metrics
    COUNT(*) AS TotalRuns,
    SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS SuccessCount,
    SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS FailureCount,
    CAST(SUM(CASE WHEN Status = 'Success' THEN 1.0 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100 AS DECIMAL(5,2)) AS SuccessRate,
    
    -- Performance Trends
    AVG(DurationSeconds) AS AvgDurationSeconds,
    MAX(DurationSeconds) AS MaxDurationSeconds,
    MIN(DurationSeconds) AS MinDurationSeconds,
    STDEV(DurationSeconds) AS StdDevDuration,
    
    -- Volume Trends
    SUM(RecordsProcessed) AS TotalRecordsProcessed,
    AVG(RecordsProcessed) AS AvgRecordsProcessed,
    SUM(RecordsFailed) AS TotalRecordsFailed,
    SUM(ErrorCount) AS TotalErrorCount,
    
    -- Anomaly Detection Flags (simple baseline)
    CASE 
        WHEN AVG(DurationSeconds) > (
            SELECT AVG(DurationSeconds) * 1.5 
            FROM [dbo].[tETLMonitoringSummary] s2
            WHERE s2.ProcessName = s1.ProcessName 
            AND s2.EventDate >= DATEADD(DAY, -30, GETDATE())
            AND s2.Status = 'Success'
        ) THEN 1 ELSE 0 
    END AS IsDurationAnomaly,
    
    CASE 
        WHEN CAST(SUM(CASE WHEN Status = 'Success' THEN 1.0 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100 AS DECIMAL(5,2)) < 85 
        THEN 1 ELSE 0 
    END AS IsLowSuccessRate
    
FROM [dbo].[tETLMonitoringSummary] s1
WHERE EventDate >= DATEADD(DAY, -90, GETDATE())
GROUP BY ProcessName, ProcessType, CAST(EventDate AS DATE)
GO
```

---

## Power BI Implementation

### Data Model Configuration

#### Connection Mode Strategy

**1. Import Mode (Primary - Scheduled Refresh)**
- **Source:** `tETLMonitoringSummary` table
- **Refresh Schedule:** Every 15-30 minutes
- **Advantages:** 
  - Fast query performance
  - Complex DAX calculations
  - Historical trend analysis
- **Use For:** Main dashboard pages

**2. DirectQuery Mode (Real-Time)**
- **Source:** `vETLMonitoring_All` view
- **Refresh:** Live/on-demand
- **Advantages:**
  - Real-time current status
  - No data latency
- **Use For:** Real-time monitoring page, drill-through details

**3. Composite Model (Hybrid)**
- Import summary for speed
- DirectQuery for drill-through to source tables
- Best of both worlds

### Data Model Tables

```
Tables to Import:
- tETLMonitoringSummary (Fact table)
- DimDate (Date dimension)
- DimProcessType (Process type lookup)
- DimStatus (Status lookup)

DirectQuery Tables (Optional):
- vETLMonitoring_All (Real-time view)
- SvcJobs.tJobAudit (Drill-through)
- dbo.tSSISImportEventLog (Drill-through)
```

### Relationships

```
tETLMonitoringSummary[EventDate] -> DimDate[Date]
tETLMonitoringSummary[ProcessType] -> DimProcessType[ProcessType]
tETLMonitoringSummary[Status] -> DimStatus[Status]
```

---

## Dashboard Pages

### Page 1: Executive Summary

**Purpose:** High-level overview of ETL health

**Visuals:**
1. **KPI Cards (Top Row)**
   - Total Processes Today
   - Success Rate Today (%)
   - Failed Processes Today
   - Avg Duration (Minutes)

2. **Success Rate Trend (Line Chart)**
   - X-axis: Date
   - Y-axis: Success Rate %
   - Legend: Process Type
   - Time range: Last 30 days

3. **Top 5 Failing Processes (Bar Chart)**
   - X-axis: Failure Count
   - Y-axis: Process Name
   - Filter: Last 7 days

4. **Duration by Process Type (Column Chart)**
   - X-axis: Process Type
   - Y-axis: Avg Duration (seconds)
   - Data labels: Show values

5. **Daily Execution Volume (Stacked Column)**
   - X-axis: Date
   - Y-axis: Count of Executions
   - Legend: Status (Success/Failed/Warning)

---

### Page 2: Preventative Alerts

**Purpose:** Early warning system for potential issues

**DAX Measures:**

```dax
// Duration Anomaly Detection
IsSlowRun = 
VAR CurrentDuration = AVERAGE(tETLMonitoringSummary[DurationSeconds])
VAR HistoricalAvg = 
    CALCULATE(
        AVERAGE(tETLMonitoringSummary[DurationSeconds]),
        DATESINPERIOD(
            tETLMonitoringSummary[EventDate], 
            MAX(tETLMonitoringSummary[EventDate]), 
            -30, 
            DAY
        ),
        tETLMonitoringSummary[Status] = "Success"
    )
VAR Threshold = HistoricalAvg * 1.5
RETURN 
    IF(
        CurrentDuration > Threshold, 
        "⚠️ Slow (" & FORMAT(CurrentDuration - HistoricalAvg, "#,##0") & "s over avg)", 
        "✓ Normal"
    )

// Failure Rate Trend
FailureRateTrend = 
VAR Last7Days = 
    CALCULATE(
        DIVIDE(
            COUNTROWS(FILTER(tETLMonitoringSummary, tETLMonitoringSummary[Status] = "Failed")),
            COUNTROWS(tETLMonitoringSummary)
        ),
        DATESINPERIOD(tETLMonitoringSummary[EventDate], TODAY(), -7, DAY)
    )
VAR Previous7Days = 
    CALCULATE(
        DIVIDE(
            COUNTROWS(FILTER(tETLMonitoringSummary, tETLMonitoringSummary[Status] = "Failed")),
            COUNTROWS(tETLMonitoringSummary)
        ),
        DATESINPERIOD(tETLMonitoringSummary[EventDate], TODAY()-7, -7, DAY)
    )
RETURN 
    IF(
        Last7Days > Previous7Days * 1.2, 
        "⚠️ Increasing (" & FORMAT((Last7Days - Previous7Days) * 100, "0.0%") & ")",
        "✓ Stable"
    )

// Missing Job Detection
ExpectedButMissing = 
VAR Today = TODAY()
VAR LastRun = MAX(tETLMonitoringSummary[EventDate])
VAR DaysSinceRun = DATEDIFF(LastRun, Today, DAY)
RETURN
    IF(
        DaysSinceRun > 1,
        "⛔ Last run " & DaysSinceRun & " days ago",
        "✓ Running"
    )

// Volume Anomaly
RecordVolumeAnomaly = 
VAR CurrentVolume = SUM(tETLMonitoringSummary[RecordsProcessed])
VAR HistoricalAvg = 
    CALCULATE(
        AVERAGE(tETLMonitoringSummary[RecordsProcessed]),
        DATESINPERIOD(tETLMonitoringSummary[EventDate], MAX(tETLMonitoringSummary[EventDate]), -30, DAY)
    )
VAR UpperBound = HistoricalAvg * 1.5
VAR LowerBound = HistoricalAvg * 0.5
RETURN
    SWITCH(
        TRUE(),
        CurrentVolume > UpperBound, "⚠️ High Volume",
        CurrentVolume < LowerBound, "⚠️ Low Volume",
        "✓ Normal"
    )
```

**Visuals:**
1. **Alert Matrix Table**
   - Columns: Process Name, Last Run, Status, Duration Alert, Failure Rate Alert, Volume Alert
   - Conditional Formatting: Red for alerts, Green for normal
   - Filter: Show only items with alerts

2. **Duration Anomaly Chart (Scatter)**
   - X-axis: Historical Avg Duration
   - Y-axis: Current Duration
   - Size: Deviation percentage
   - Color: Red if anomaly, Green if normal

3. **Missing Jobs Table**
   - Process Name, Expected Frequency, Last Run Date, Days Since Run
   - Filter: Only show jobs not run in expected timeframe

4. **Failure Rate Trend (Line + Column Combo)**
   - Primary axis (Line): Failure rate %
   - Secondary axis (Column): Total failures
   - Time range: Last 30 days

---

### Page 3: Process Drill-Down

**Purpose:** Detailed analysis of individual processes

**Filters:**
- Process Name (Slicer)
- Date Range (Date slicer)
- Process Type (Slicer)
- Status (Multi-select)

**Visuals:**
1. **Process Execution Timeline (Gantt/Bar)**
   - Shows individual runs over time
   - Color by Status
   - Tooltip: Duration, Records Processed, Error Message

2. **Success vs. Failure Distribution (Donut)**
   - Values: Count by Status
   - Data labels: Percentage

3. **Duration Box Plot**
   - Shows distribution of execution times
   - Identifies outliers
   - By date

4. **Error Details Table**
   - Columns: Event Date, Status, Duration, Records, Error Message
   - Filter: Failed/Warning only
   - Drill-through to source system

5. **Performance Trend (Line Chart)**
   - X-axis: Date
   - Y-axis: Duration (seconds)
   - Reference line: Average
   - Reference band: +/- 1 std dev

---

### Page 4: Capacity Planning

**Purpose:** Predict future resource needs

**Visuals:**
1. **Record Volume Trend (Area Chart)**
   - X-axis: Date
   - Y-axis: Total Records Processed
   - Forecast: Next 30 days (Power BI analytics)

2. **Processing Time vs. Volume (Scatter)**
   - X-axis: Records Processed
   - Y-axis: Duration (seconds)
   - Trend line: Linear regression
   - Color: Process Type

3. **Peak Hour Analysis (Heatmap)**
   - Rows: Hour of Day
   - Columns: Day of Week
   - Values: Count of Executions
   - Color scale: Low to High

4. **Resource Utilization Forecast (Column + Line)**
   - X-axis: Date
   - Columns: Total Duration (hours)
   - Line: Projected capacity limit
   - Show where capacity may be exceeded

---

## Alert Threshold Configuration

### Critical Alerts (Red - Immediate Action)

```
🔴 CRITICAL:
- Process failed 3+ times in last hour
- Success rate < 85% for the day
- Duration > 3x historical average
- Zero executions when expected (scheduled job missing)
- Error count spike (>5x normal)
```

### Warning Alerts (Yellow - Investigation Needed)

```
🟡 WARNING:
- Duration > 1.5x historical average
- Success rate 85-95%
- Error count increasing week-over-week
- Record count ±30% from average
- Execution time trending upward (3+ days)
```

### Notification Setup

**Power BI Data-Driven Alerts:**
1. Go to dashboard tile
2. Click "..." → "Manage alerts"
3. Set threshold (e.g., Success Rate < 90%)
4. Configure recipients
5. Set frequency (hourly/daily)

**Power Automate Integration:**
```
Trigger: Power BI data-driven alert
Condition: Check alert type
Actions:
  - Send email to team
  - Post to Teams channel
  - Create ServiceNow ticket (Critical only)
  - Log to monitoring database
```

---

## Maintenance & Governance

### Data Retention Policy

```sql
-- Archive old data (monthly job)
CREATE PROCEDURE [dbo].[pETLMonitoringSummaryArchive]
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create archive table if not exists
    IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = 'tETLMonitoringSummary_Archive')
    BEGIN
        SELECT TOP 0 * 
        INTO [dbo].[tETLMonitoringSummary_Archive]
        FROM [dbo].[tETLMonitoringSummary]
    END
    
    -- Move data older than 90 days to archive
    INSERT INTO [dbo].[tETLMonitoringSummary_Archive]
    SELECT * 
    FROM [dbo].[tETLMonitoringSummary]
    WHERE EventDate < DATEADD(DAY, -90, GETDATE())
    
    -- Delete archived data from main table
    DELETE FROM [dbo].[tETLMonitoringSummary]
    WHERE EventDate < DATEADD(DAY, -90, GETDATE())
    
    -- Update statistics
    UPDATE STATISTICS [dbo].[tETLMonitoringSummary]
    UPDATE STATISTICS [dbo].[tETLMonitoringSummary_Archive]
END
GO
```

### Table Partitioning (Optional - for large volumes)

```sql
-- Partition by month for better performance
CREATE PARTITION FUNCTION PF_ETLMonitoring_Monthly (DATETIME)
AS RANGE RIGHT FOR VALUES (
    '2026-01-01', '2026-02-01', '2026-03-01', 
    '2026-04-01', '2026-05-01', '2026-06-01',
    '2026-07-01', '2026-08-01', '2026-09-01',
    '2026-10-01', '2026-11-01', '2026-12-01'
);

CREATE PARTITION SCHEME PS_ETLMonitoring_Monthly
AS PARTITION PF_ETLMonitoring_Monthly
ALL TO ([FGDATA01]);
```

### Adding New ETL Sources

**Process to add new event source:**

1. Create source-specific view following naming convention:
   ```sql
   CREATE VIEW [dbo].[vETLMonitoring_<SourceName>] AS
   -- Map to standard schema
   ```

2. Add to union view:
   ```sql
   ALTER VIEW [dbo].[vETLMonitoring_All] AS
   -- ... existing unions ...
   UNION ALL
   SELECT * FROM [dbo].[vETLMonitoring_<SourceName>]
   ```

3. Test refresh procedure
4. Update Power BI documentation
5. Add new process types to slicers if needed

---

## Performance Optimization

### Indexing Strategy

```sql
-- Additional indexes based on common Power BI queries
CREATE NONCLUSTERED INDEX [IX_tETLMonitoringSummary_ProcessName_EventDate]
ON [dbo].[tETLMonitoringSummary] ([ProcessName], [EventDate] DESC)
INCLUDE ([Status], [DurationSeconds], [RecordsProcessed])
ON [FGDATA01]

CREATE NONCLUSTERED INDEX [IX_tETLMonitoringSummary_Status_EventDate]
ON [dbo].[tETLMonitoringSummary] ([Status], [EventDate] DESC)
INCLUDE ([ProcessName], [ProcessType])
ON [FGDATA01]
```

### Query Optimization

```sql
-- Columnstore index for analytical queries (if volume is high)
CREATE NONCLUSTERED COLUMNSTORE INDEX [NCCI_tETLMonitoringSummary]
ON [dbo].[tETLMonitoringSummary] 
(EventDate, ProcessName, ProcessType, Status, DurationSeconds, RecordsProcessed)
ON [FGDATA01]
```

---

## Success Criteria

### Metrics to Track

✅ **Technical Success:**
- Dashboard loads in < 3 seconds
- Data refresh completes in < 5 minutes
- Query performance < 2 seconds for all visuals
- 99% refresh success rate

✅ **Business Success:**
- Reduced mean time to detect (MTTD) issues by 50%
- Proactive issue identification before user impact
- 90%+ user satisfaction with dashboard
- Documented prevention of 3+ major incidents per quarter

---

## Rollout Plan

### Phase 1: Foundation (Week 1-2)
- [ ] Create summary table and views
- [ ] Implement refresh stored procedure
- [ ] Set up SQL Agent job
- [ ] Validate data accuracy

### Phase 2: Power BI Development (Week 3-4)
- [ ] Build Executive Summary page
- [ ] Create Preventative Alerts page
- [ ] Implement Process Drill-Down
- [ ] Add Capacity Planning

### Phase 3: Alerting & Automation (Week 5)
- [ ] Configure Power BI alerts
- [ ] Set up Power Automate flows
- [ ] Test notification delivery
- [ ] Document alert response procedures

### Phase 4: Training & Handoff (Week 6)
- [ ] Train dashboard users
- [ ] Document maintenance procedures
- [ ] Establish SLA for dashboard availability
- [ ] Go-live!

---

## Support & Documentation

### Key Contacts
- **Dashboard Owner:** [Name]
- **DBA Support:** [Team]
- **Power BI Admin:** [Name]

### Links
- **Dashboard URL:** [Power BI Workspace URL]
- **Documentation:** [Confluence/SharePoint Link]
- **Runbook:** [Alert Response Procedures]
- **Source Code:** [Git Repository]

---

## Appendix: ETL Source Tables Reference

### Core Database

**Job Execution Frameworks (choose based on what's deployed):**
- `SvcJobs.tJobAudit` - **Newer** job execution audit log (if available)
  - Fields: JobAuditID, JobID, JobTypeID, DeduplicationKey, Action, ActionDetail, ActionDate
- `IRA.tProcessResult` - **Older** process execution results (fallback)
  - Fields: ProcessJournalID, RefDatasetID, CorrelationID, Status, MessageCount, MessageBody, CreatedDate, ProcessQueueID, Link, FileType
- `IRA.tProcessStatus` - Process status lookup
  - Fields: ProcessStatusID, Label, Icon, Name, IsRunningStatus
- `IRA.tProcessFlow` - Process flow definitions
  - Fields: ProcessFlowID, ProcessGroupID, ProcessStepID, OverrideName, OverrideDescription, StatusProcedureID

**Import Logs:**
- `Employee.tImportLog` - Employee import events
- `Employee.tImportHistory` - Employee import history
- `Web.tCalendarImportLog` - Calendar import events

### Feeds Database
  - Fields: EventID, EventType, PackageName, TaskName, EventCode, EventDescription, PackageDuration, ContainerDuration, InsertCount, UpdateCount, DeleteCount, UserName, Host, EventDate, RefDataSetID, FileName, GUID
- `dbo.tSSISImportEventLog` - SSIS package execution log
- `dbo.tSSISPowerShellVariableLog` - PowerShell ETL logging
- `solvas_am.tAssetLoaderSolvasProcessResults` - Asset loader results
- `solvas_am.tTradeLoaderSolvasProcessResults` - Trade loader results
- `solvas_am.tAssetLoaderStagException` - Asset loader errors
- `solvas_am.tTradeLoaderStagException` - Trade loader errors
- `SecurityMaster.tClientRequestLogging` - Security master request log
- `custodian.tYostEventHistory` - Custodian event tracking

---

**Document Version:** 1.0  
**Last Updated:** 2026-07-06  
**Next Review:** 2026-10-06
