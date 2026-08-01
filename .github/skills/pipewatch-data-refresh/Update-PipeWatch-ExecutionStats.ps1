<#
.SYNOPSIS
    PipeWatch Script Adapter Backfill - 30-Day Execution History with Failure Tracking

.DESCRIPTION
    Queries Enterprise.ScriptAdapter.tScriptConfigurationHistory for execution statistics
    and updates job-names-list-enriched.json with 30-day metrics including failure tracking.

.PARAMETER LookbackDays
    Number of days to look back for execution history (default: 30)

.PARAMETER OutputPath
    Path to job-names-list-enriched.json file
    Default: C:\source\PipeWatch\public\docs\job-names-list-enriched.json

.PARAMETER LogPath
    Path to save execution log
    Default: C:\source\MD\AdminTools\Output\backfill-log-{timestamp}.txt

.EXAMPLE
    .\Update-PipeWatch-ExecutionStats.ps1
    # Standard 30-day backfill

.EXAMPLE
    .\Update-PipeWatch-ExecutionStats.ps1 -LookbackDays 60
    # 60-day lookback period

.NOTES
    Author: Mossy (MOS Support Agent)
    Date: 2026-07-30
    Database: Enterprise (mos-sql-p.mos.siepe.local,52155)
    Focus: Script Adapter jobs only (skip Email/Report subscriptions)
#>

param(
    [int]$LookbackDays = 30,
    [string]$OutputPath = "C:\source\PipeWatch\public\docs\job-names-list-enriched.json",
    [string]$LogPath = "C:\source\MD\AdminTools\Output\backfill-log-$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
)

$ErrorActionPreference = "Stop"
$StartTime = Get-Date

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogPath -Value $logMessage
}

# ============================================================================
# DATABASE CONFIGURATION
# ============================================================================

$ServerInstance = "mos-sql-p.mos.siepe.local,52155"
$Database = "Enterprise"

Write-Log "========================================" "INFO"
Write-Log "PipeWatch Execution Stats Backfill" "INFO"
Write-Log "========================================" "INFO"
Write-Log "Lookback Period: $LookbackDays days" "INFO"
Write-Log "Output File: $OutputPath" "INFO"
Write-Log "Log File: $LogPath" "INFO"

# ============================================================================
# STEP 1: Query Script Adapter Execution History
# ============================================================================

Write-Log "STEP 1: Querying Script Adapter execution history..." "INFO"

$executionStatsQuery = @"
-- Aggregate 30-day execution stats with failure tracking
WITH ExecutionStats AS (
    SELECT 
        h.ScriptConfigurationID as tool_id,
        COUNT(*) as total_executions,
        MIN(DATEDIFF(second, h.StartTime, ISNULL(h.EndTime, GETDATE()))) as min_duration_seconds,
        MAX(DATEDIFF(second, h.StartTime, ISNULL(h.EndTime, GETDATE()))) as max_duration_seconds,
        AVG(DATEDIFF(second, h.StartTime, ISNULL(h.EndTime, GETDATE()))) as avg_duration_seconds,
        MAX(h.StartTime) as last_execution_start,
        MAX(h.EndTime) as last_execution_end
    FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory h
    WHERE h.StartTime >= DATEADD(day, -$LookbackDays, GETDATE())
      AND h.EndTime IS NOT NULL  -- Exclude currently running jobs
    GROUP BY h.ScriptConfigurationID
),
FailureStats AS (
    SELECT 
        ScriptConfigurationID as tool_id,
        MAX(StartTime) as last_failed_time,
        COUNT(*) as total_failures,
        MAX(JobDetail) as last_error_message
    FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
    WHERE StartTime >= DATEADD(day, -$LookbackDays, GETDATE())
      AND (
          JobDetail LIKE '%failed%' 
          OR JobDetail LIKE '%error%' 
          OR JobDetail LIKE '%exception%'
          OR JobDetail LIKE '%timeout%'
      )
    GROUP BY ScriptConfigurationID
),
LastExecution AS (
    SELECT 
        ScriptConfigurationID as tool_id,
        DATEDIFF(second, StartTime, ISNULL(EndTime, GETDATE())) as last_duration_seconds
    FROM (
        SELECT 
            ScriptConfigurationID,
            StartTime,
            EndTime,
            ROW_NUMBER() OVER (PARTITION BY ScriptConfigurationID ORDER BY StartTime DESC) as rn
        FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
        WHERE StartTime >= DATEADD(day, -$LookbackDays, GETDATE())
          AND EndTime IS NOT NULL
    ) ranked
    WHERE rn = 1
)
SELECT 
    e.tool_id,
    e.total_executions as total_executions_30d,
    e.min_duration_seconds,
    e.max_duration_seconds,
    e.avg_duration_seconds,
    le.last_duration_seconds,
    CONVERT(VARCHAR(23), e.last_execution_start, 121) as last_execution_start,
    CONVERT(VARCHAR(23), e.last_execution_end, 121) as last_execution_end,
    CONVERT(VARCHAR(23), f.last_failed_time, 121) as last_failed_time,
    DATEDIFF(day, f.last_failed_time, GETDATE()) as days_since_failure,
    ISNULL(f.total_failures, 0) as total_failures_30d,
    CAST(ROUND((ISNULL(f.total_failures, 0) * 100.0 / e.total_executions), 2) AS DECIMAL(5,2)) as failure_rate,
    f.last_error_message
FROM ExecutionStats e
LEFT JOIN FailureStats f ON f.tool_id = e.tool_id
LEFT JOIN LastExecution le ON le.tool_id = e.tool_id
ORDER BY e.tool_id
"@

try {
    $executionStats = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $executionStatsQuery -QueryTimeout 120
    Write-Log "Retrieved execution stats for $($executionStats.Count) Script Adapter jobs" "INFO"
} catch {
    Write-Log "ERROR querying database: $_" "ERROR"
    throw
}

# ============================================================================
# STEP 2: Load Existing JSON
# ============================================================================

Write-Log "STEP 2: Loading existing JSON file..." "INFO"

if (-not (Test-Path $OutputPath)) {
    Write-Log "ERROR: JSON file not found at $OutputPath" "ERROR"
    throw "JSON file not found"
}

try {
    $jsonContent = Get-Content $OutputPath -Raw | ConvertFrom-Json
    Write-Log "Loaded JSON with $($jsonContent.total_jobs) total jobs in $($jsonContent.total_categories) categories" "INFO"
} catch {
    Write-Log "ERROR loading JSON: $_" "ERROR"
    throw
}

# ============================================================================
# STEP 3: Create Lookup Hash Table for Fast Updates
# ============================================================================

Write-Log "STEP 3: Creating execution stats lookup hash table..." "INFO"

$statsLookup = @{}
foreach ($row in $executionStats) {
    $statsLookup[$row.tool_id] = @{
        total_executions_30d = $row.total_executions_30d
        min_duration_seconds = $row.min_duration_seconds
        max_duration_seconds = $row.max_duration_seconds
        avg_duration_seconds = $row.avg_duration_seconds
        last_duration_seconds = if ($row.last_duration_seconds) { $row.last_duration_seconds } else { $null }
        last_execution_start = $row.last_execution_start
        last_execution_end = $row.last_execution_end
        last_failed_time = if ($row.last_failed_time -eq "") { $null } else { $row.last_failed_time }
        days_since_failure = if ($row.days_since_failure) { $row.days_since_failure } else { $null }
        total_failures_30d = $row.total_failures_30d
        failure_rate = [double]$row.failure_rate
        last_error_message = if ($row.last_error_message -eq "") { $null } else { $row.last_error_message }
        duration_range = "$($row.min_duration_seconds)-$($row.max_duration_seconds) sec"
    }
}

Write-Log "Created lookup hash table with $($statsLookup.Count) entries" "INFO"

# ============================================================================
# STEP 4: Update JSON with Execution Stats
# ============================================================================

Write-Log "STEP 4: Updating JSON jobs with execution stats..." "INFO"

$updatedCount = 0
$skippedCount = 0
$failedJobsCount = 0

foreach ($category in $jsonContent.categories) {
    foreach ($job in $category.jobs) {
        # Only process jobs with script_path (Script Adapters)
        if ($job.script_path) {
            $toolId = $job.tool_id
            
            if ($statsLookup.ContainsKey($toolId)) {
                $stats = $statsLookup[$toolId]
                
                # Add or update execution_stats property
                $job | Add-Member -NotePropertyName "execution_stats" -NotePropertyValue $stats -Force
                
                # Update computed fields for backwards compatibility
                if ($stats.last_duration_seconds -ne $null) {
                    $job | Add-Member -NotePropertyName "last_run_duration" -NotePropertyValue "$($stats.last_duration_seconds) sec" -Force
                }
                if ($stats.avg_duration_seconds -ne $null) {
                    $job | Add-Member -NotePropertyName "typical_duration" -NotePropertyValue "$($stats.avg_duration_seconds) sec" -Force
                }
                $job | Add-Member -NotePropertyName "duration_range" -NotePropertyValue $stats.duration_range -Force
                
                $updatedCount++
                
                # Track failed jobs
                if ($stats.last_failed_time) {
                    $failedJobsCount++
                }
            } else {
                $skippedCount++
            }
        }
        
        # Recursively process children (nested Script Adapters)
        if ($job.children) {
            foreach ($child in $job.children) {
                if ($child.script_path) {
                    $childToolId = $child.tool_id
                    
                    if ($statsLookup.ContainsKey($childToolId)) {
                        $stats = $statsLookup[$childToolId]
                        $child | Add-Member -NotePropertyName "execution_stats" -NotePropertyValue $stats -Force
                        
                        if ($stats.last_duration_seconds -ne $null) {
                            $child | Add-Member -NotePropertyName "last_run_duration" -NotePropertyValue "$($stats.last_duration_seconds) sec" -Force
                        }
                        if ($stats.avg_duration_seconds -ne $null) {
                            $child | Add-Member -NotePropertyName "typical_duration" -NotePropertyValue "$($stats.avg_duration_seconds) sec" -Force
                        }
                        $child | Add-Member -NotePropertyName "duration_range" -NotePropertyValue $stats.duration_range -Force
                        
                        $updatedCount++
                        
                        if ($stats.last_failed_time) {
                            $failedJobsCount++
                        }
                    } else {
                        $skippedCount++
                    }
                }
            }
        }
    }
}

Write-Log "Updated $updatedCount jobs with execution stats" "INFO"
Write-Log "Skipped $skippedCount jobs (no execution history found)" "WARN"
Write-Log "Found $failedJobsCount jobs with failures in last $LookbackDays days" "WARN"

# ============================================================================
# STEP 5: Save Updated JSON
# ============================================================================

Write-Log "STEP 5: Saving updated JSON file..." "INFO"

try {
    # Backup original
    $backupPath = $OutputPath -replace '\.json$', "_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    Copy-Item $OutputPath $backupPath
    Write-Log "Created backup at $backupPath" "INFO"
    
    # Save updated JSON
    $jsonContent | ConvertTo-Json -Depth 20 | Out-File $OutputPath -Encoding UTF8
    Write-Log "Saved updated JSON to $OutputPath" "INFO"
} catch {
    Write-Log "ERROR saving JSON: $_" "ERROR"
    throw
}

# ============================================================================
# STEP 6: Generate Failed Jobs Report
# ============================================================================

Write-Log "STEP 6: Generating failed jobs report..." "INFO"

$failedJobsReport = @()
foreach ($category in $jsonContent.categories) {
    foreach ($job in $category.jobs) {
        if ($job.execution_stats -and $job.execution_stats.last_failed_time) {
            $failedJobsReport += [PSCustomObject]@{
                tool_id = $job.tool_id
                job_description = $job.job_description
                script_path = $job.script_path
                last_failed_time = $job.execution_stats.last_failed_time
                days_since_failure = $job.execution_stats.days_since_failure
                total_failures_30d = $job.execution_stats.total_failures_30d
                failure_rate = "$($job.execution_stats.failure_rate)%"
                last_error_message = $job.execution_stats.last_error_message
            }
        }
        
        # Check children
        if ($job.children) {
            foreach ($child in $job.children) {
                if ($child.execution_stats -and $child.execution_stats.last_failed_time) {
                    $failedJobsReport += [PSCustomObject]@{
                        tool_id = $child.tool_id
                        job_description = $child.job_description
                        script_path = $child.script_path
                        last_failed_time = $child.execution_stats.last_failed_time
                        days_since_failure = $child.execution_stats.days_since_failure
                        total_failures_30d = $child.execution_stats.total_failures_30d
                        failure_rate = "$($child.execution_stats.failure_rate)%"
                        last_error_message = $child.execution_stats.last_error_message
                    }
                }
            }
        }
    }
}

if ($failedJobsReport.Count -gt 0) {
    $reportPath = "C:\source\MD\AdminTools\Output\failed-jobs-report-$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $failedJobsReport | Sort-Object days_since_failure | Export-Csv $reportPath -NoTypeInformation
    Write-Log "Saved failed jobs report to $reportPath" "INFO"
    
    # Display top 10 recent failures
    Write-Log "" "INFO"
    Write-Log "=== TOP 10 RECENT FAILURES ===" "WARN"
    $failedJobsReport | Sort-Object days_since_failure | Select-Object -First 10 | ForEach-Object {
        Write-Log "  [$($_.days_since_failure)d ago] $($_.job_description) - $($_.total_failures_30d) failures ($($_.failure_rate))" "WARN"
    }
} else {
    Write-Log "No failed jobs found in last $LookbackDays days" "INFO"
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Log "" "INFO"
Write-Log "========================================" "INFO"
Write-Log "Backfill Complete!" "INFO"
Write-Log "========================================" "INFO"
Write-Log "Total Execution Time: $($Duration.TotalSeconds) seconds" "INFO"
Write-Log "Jobs Updated: $updatedCount" "INFO"
Write-Log "Jobs Skipped: $skippedCount" "INFO"
Write-Log "Jobs with Failures: $failedJobsCount" "INFO"
Write-Log "Output File: $OutputPath" "INFO"
Write-Log "Log File: $LogPath" "INFO"

Write-Host "`n✓ PipeWatch backfill completed successfully!" -ForegroundColor Green
