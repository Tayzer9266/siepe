# Log File Timing Analysis Script
# Analyzes Middle Office load scripts log files and extracts timing information

param(
    [string]$LogFolderPath = "C:\source\MD\AdminTools\Archive\Client Refresh Log"
)

# Script folders to analyze
$scripts = @{
    "AgentBank" = "MiddleOfficeAgentBankLoad"
    "Amortization" = "MiddleOfficeAmortizationLoad"
    "ContractCashFlow" = "MiddleOfficeContractCashFlowDebtLoad"
    "Factor" = "MiddleOfficeFactorLoad"
    "InstDefault" = "MiddleOfficeInstDefaultLoad"
    "Instrument" = "MiddleOfficeInstrumentLoad"
    "LiabilityCapstack" = "MiddleOfficeLiabilityCapstackLoad"
    "PositionLoad" = "MiddleOfficePositionLoad"
    "TradeLoad" = "MiddleOfficeTradeLoad"
}

# Output file
$outputFile = "$LogFolderPath\Timing_Analysis_Summary.md"

# Create summary report
$report = @"
# Middle Office Data Load - Timing Analysis Summary
**Analysis Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Data Source:** Log files from past 7 days

---

"@

foreach ($folder in $scripts.Keys) {
    $scriptName = $scripts[$folder]
    $logFolder = Join-Path $LogFolderPath $folder
    
    Write-Host "Analyzing $scriptName..." -ForegroundColor Cyan
    
    if (-not (Test-Path $logFolder)) {
        Write-Host "  Folder not found: $logFolder" -ForegroundColor Yellow
        continue
    }
    
    # Get most recent 7 log files
    $logFiles = Get-ChildItem -Path $logFolder -Filter "*.txt" | 
                Sort-Object LastWriteTime -Descending | 
                Select-Object -First 7
    
    if ($logFiles.Count -eq 0) {
        Write-Host "  No log files found" -ForegroundColor Yellow
        continue
    }
    
    $report += "## $scriptName`n`n"
    $report += "**Log Files Analyzed:** $($logFiles.Count) (most recent)`n`n"
    
    # Analyze each log file
    $timings = @()
    
    foreach ($logFile in $logFiles) {
        try {
            # Extract date from filename
            if ($logFile.Name -match '(\d{8}T\d{6})') {
                $runDate = $matches[1]
                $runDateTime = [DateTime]::ParseExact($runDate, 'yyyyMMddTHHmmss', $null)
                
                # Get file info
                $fileSize = $logFile.Length
                $lastModified = $logFile.LastWriteTime
                
                # Calculate approximate duration (file creation to last modified)
                $duration = ($lastModified - $runDateTime).TotalMinutes
                
                $timings += [PSCustomObject]@{
                    Date = $runDateTime.ToString('yyyy-MM-dd')
                    StartTime = $runDateTime.ToString('HH:mm:ss')
                    Duration = [math]::Round($duration, 2)
                    FileSizeKB = [math]::Round($fileSize / 1KB, 2)
                }
            }
        } catch {
            Write-Host "  Error processing $($logFile.Name): $_" -ForegroundColor Red
        }
    }
    
    if ($timings.Count -gt 0) {
        # Calculate statistics
        $avgDuration = ($timings | Measure-Object -Property Duration -Average).Average
        $minDuration = ($timings | Measure-Object -Property Duration -Minimum).Minimum
        $maxDuration = ($timings | Measure-Object -Property Duration -Maximum).Maximum
        
        $report += "### Recent Run Statistics`n`n"
        $report += "| Metric | Value |`n"
        $report += "|--------|-------|`n"
        $report += "| Average Duration | $([math]::Round($avgDuration, 2)) minutes |`n"
        $report += "| Min Duration | $([math]::Round($minDuration, 2)) minutes |`n"
        $report += "| Max Duration | $([math]::Round($maxDuration, 2)) minutes |`n"
        $report += "| Typical Run Time | $(($timings[0]).StartTime) |`n`n"
        
        $report += "### Recent Run Details`n`n"
        $report += "| Date | Start Time | Duration (min) | Log Size (KB) |`n"
        $report += "|------|------------|----------------|---------------|`n"
        
        foreach ($timing in $timings | Sort-Object Date -Descending) {
            $report += "| $($timing.Date) | $($timing.StartTime) | $($timing.Duration) | $($timing.FileSizeKB) |`n"
        }
        
        $report += "`n"
    }
    
    $report += "---`n`n"
}

# Save report
$report | Out-File -FilePath $outputFile -Encoding UTF8 -Force

Write-Host "`nAnalysis complete!" -ForegroundColor Green
Write-Host "Report saved to: $outputFile" -ForegroundColor Green

# Display report
Get-Content $outputFile
