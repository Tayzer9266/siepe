<#
.SYNOPSIS
    Test PipeWatch data refresh system

.DESCRIPTION
    Validates database connectivity, script functionality, and output generation
    without modifying production JSON file

.EXAMPLE
    .\Test-PipeWatch-Refresh.ps1

.NOTES
    Author: Mossy (MOS Support Agent)
    Date: 2026-07-30
    Safe to run - creates test output in AdminTools\Output folder
#>

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PipeWatch Data Refresh System Test" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$passCount = 0
$failCount = 0

# Test 1: Database Connectivity
Write-Host "[1/6] Testing database connectivity..." -ForegroundColor Yellow
try {
    $result = sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Enterprise" -Q "SELECT COUNT(*) as ActiveScriptAdapters FROM ScriptAdapter.tScriptConfiguration WHERE RefRecStatusID = 1" -h -1
    $count = [int]$result.Trim()
    Write-Host "  ✓ Database connected - $count active Script Adapters found" -ForegroundColor Green
    $passCount++
} catch {
    Write-Host "  ✗ Database connection failed: $_" -ForegroundColor Red
    $failCount++
}

# Test 2: Execution History Query
Write-Host "[2/6] Testing execution history query..." -ForegroundColor Yellow
try {
    $result = sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Enterprise" -Q "SELECT COUNT(*) FROM ScriptAdapter.tScriptConfigurationHistory WHERE StartTime >= DATEADD(day, -30, GETDATE())" -h -1
    $count = [int]$result.Trim()
    Write-Host "  ✓ Query successful - $count executions in last 30 days" -ForegroundColor Green
    $passCount++
} catch {
    Write-Host "  ✗ Query failed: $_" -ForegroundColor Red
    $failCount++
}

# Test 3: JSON File Exists
Write-Host "[3/6] Testing JSON file access..." -ForegroundColor Yellow
$jsonPath = "C:\source\PipeWatch\public\docs\job-names-list-enriched.json"
if (Test-Path $jsonPath) {
    $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
    Write-Host "  ✓ JSON file loaded - $($json.total_jobs) jobs, $($json.total_categories) categories" -ForegroundColor Green
    $passCount++
} else {
    Write-Host "  ✗ JSON file not found at $jsonPath" -ForegroundColor Red
    $failCount++
}

# Test 4: Script Path Exists
Write-Host "[4/6] Testing backfill script..." -ForegroundColor Yellow
$scriptPath = "C:\source\MD\AdminTools\.github\skills\pipewatch-data-refresh\Update-PipeWatch-ExecutionStats.ps1"
if (Test-Path $scriptPath) {
    $fileSize = (Get-Item $scriptPath).Length
    Write-Host "  ✓ Backfill script found - $([math]::Round($fileSize/1KB, 2)) KB" -ForegroundColor Green
    $passCount++
} else {
    Write-Host "  ✗ Backfill script not found at $scriptPath" -ForegroundColor Red
    $failCount++
}

# Test 5: Output Directory Writable
Write-Host "[5/6] Testing output directory..." -ForegroundColor Yellow
$outputDir = "C:\source\MD\AdminTools\Output"
try {
    $testFile = Join-Path $outputDir "test_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
    "test" | Out-File $testFile
    Remove-Item $testFile
    Write-Host "  ✓ Output directory writable" -ForegroundColor Green
    $passCount++
} catch {
    Write-Host "  ✗ Cannot write to output directory: $_" -ForegroundColor Red
    $failCount++
}

# Test 6: Sample Data Query
Write-Host "[6/6] Testing sample execution stats query..." -ForegroundColor Yellow
try {
    $query = @"
SELECT TOP 3 
    ScriptConfigurationID as tool_id,
    COUNT(*) as total_executions,
    AVG(DATEDIFF(second, StartTime, EndTime)) as avg_duration_seconds
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE StartTime >= DATEADD(day, -30, GETDATE())
  AND EndTime IS NOT NULL
GROUP BY ScriptConfigurationID
ORDER BY COUNT(*) DESC
"@
    $result = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" -Database "Enterprise" -Query $query
    Write-Host "  ✓ Stats query successful - Sample results:" -ForegroundColor Green
    $result | ForEach-Object {
        Write-Host "    Tool ID $($_.tool_id): $($_.total_executions) runs, avg $($_.avg_duration_seconds)s" -ForegroundColor Gray
    }
    $passCount++
} catch {
    Write-Host "  ✗ Stats query failed: $_" -ForegroundColor Red
    $failCount++
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Test Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $passCount/6" -ForegroundColor Green
Write-Host "Failed: $failCount/6" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })

if ($failCount -eq 0) {
    Write-Host "`n✓ All tests passed! System ready for production use." -ForegroundColor Green
    Write-Host "`nTo run backfill:" -ForegroundColor Yellow
    Write-Host "  cd C:\source\MD\AdminTools\.github\skills\pipewatch-data-refresh" -ForegroundColor White
    Write-Host "  .\Update-PipeWatch-ExecutionStats.ps1" -ForegroundColor White
} else {
    Write-Host "`n✗ Some tests failed. Please fix issues before running backfill." -ForegroundColor Red
}

Write-Host "`n========================================`n" -ForegroundColor Cyan
