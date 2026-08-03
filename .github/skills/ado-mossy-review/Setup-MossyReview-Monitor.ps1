# ================================================================
# Setup Mossy Review Work Items Monitor - Task Scheduler
# ================================================================
# Purpose: Create a scheduled task that checks ADO every 2 minutes
# Run this script ONCE to set up the monitoring
# ================================================================

param(
    [string]$TaskName = "Mossy Review ADO Monitor",
    [string]$UserName = $env:USERNAME,
    [switch]$EnableLogging
)

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Mossy Review Monitor Setup" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Script path
$scriptPath = Join-Path $PSScriptRoot "Check-MossyReview-WorkItems.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: Script not found at $scriptPath" -ForegroundColor Red
    exit 1
}

# Build arguments
$arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
if ($EnableLogging) {
    $arguments += " -LogToFile"
}

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Task Name: $TaskName"
Write-Host "  Script: $scriptPath"
Write-Host "  Run As: $UserName"
Write-Host "  Interval: Every 2 minutes"
Write-Host "  Logging: $EnableLogging"
Write-Host ""

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "Task '$TaskName' already exists." -ForegroundColor Yellow
    $response = Read-Host "Do you want to replace it? (Y/N)"
    if ($response -ne 'Y' -and $response -ne 'y') {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create scheduled task action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument $arguments

# Create trigger - every 2 minutes, indefinitely
# Note: Task Scheduler doesn't support intervals < 1 minute directly
# We'll use a repeating daily trigger with a 2-minute repetition interval
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 2) `
    -RepetitionDuration (New-TimeSpan -Days 9999)

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 1) `
    -Priority 7

# Create principal (run as current user)
$principal = New-ScheduledTaskPrincipal `
    -UserId $UserName `
    -LogonType S4U `
    -RunLevel Limited

# Register the task
try {
    Write-Host "Creating scheduled task..." -ForegroundColor Yellow
    
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Monitors Azure DevOps for work items tagged with 'Mossy Review' every 2 minutes" `
        -ErrorAction Stop | Out-Null
    
    Write-Host "`n[OK] Task created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  - Runs every 2 minutes"
    Write-Host "  - Starts immediately"
    Write-Host "  - Runs even on battery power"
    Write-Host "  - Ignores new instances if already running"
    Write-Host "  - 1-minute timeout per execution"
    Write-Host ""
    
    Write-Host "Management Commands:" -ForegroundColor Cyan
    Write-Host "  # View task" -ForegroundColor White
    Write-Host "  Get-ScheduledTask -TaskName '$TaskName' | Format-List" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Start task immediately (test)" -ForegroundColor White
    Write-Host "  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Disable task" -ForegroundColor White
    Write-Host "  Disable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Enable task" -ForegroundColor White
    Write-Host "  Enable-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  # Remove task" -ForegroundColor White
    Write-Host "  Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false" -ForegroundColor Gray
    Write-Host ""
    
    # Ask to run test
    $testNow = Read-Host "Do you want to run a test now? (Y/N)"
    if ($testNow -eq 'Y' -or $testNow -eq 'y') {
        Write-Host "`nRunning test..." -ForegroundColor Yellow
        Start-ScheduledTask -TaskName $TaskName
        Start-Sleep -Seconds 2
        
        Write-Host "`n[OK] Test execution started. Check console output or log file." -ForegroundColor Green
        
        if ($EnableLogging) {
            $logPath = "C:\source\MD\AdminTools\.github\skills\ado-mossy-review\mossy-review-monitor.log"
            Write-Host "  Log: $logPath" -ForegroundColor Gray
        }
    }
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Setup Complete!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Cyan
    
} catch {
    Write-Host "`n[ERROR] Failed to create scheduled task:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
