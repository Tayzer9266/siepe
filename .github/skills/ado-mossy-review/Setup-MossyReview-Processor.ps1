# ================================================================
# Setup Mossy Review Processor - Scheduled Task
# ================================================================
# Purpose: One-time setup for automated queue processing
# Creates: Scheduled task "Mossy Review Queue Processor"
# Schedule: Every 5 minutes, indefinitely
# ================================================================

param(
    [string]$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
)

# Require administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[ERROR] This script requires administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Mossy Review Processor - Task Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$taskName = "Mossy Review Queue Processor"
$scriptPath = Join-Path $PSScriptRoot "Process-MossyReview-Queue.ps1"
$workingDir = $PSScriptRoot

# Verify script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERROR] Processor script not found at: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "Task Name:       $taskName" -ForegroundColor White
Write-Host "Script Path:     $scriptPath" -ForegroundColor White
Write-Host "Working Dir:     $workingDir" -ForegroundColor White
Write-Host "Run As User:     $UserName" -ForegroundColor White
Write-Host "Schedule:        Every 5 minutes, indefinitely" -ForegroundColor White
Write-Host ""

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "[WARNING] Scheduled task '$taskName' already exists." -ForegroundColor Yellow
    $response = Read-Host "Do you want to recreate it? (y/n)"
    
    if ($response -ne 'y') {
        Write-Host "Setup cancelled." -ForegroundColor Yellow
        exit 0
    }
    
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "[OK] Existing task removed" -ForegroundColor Green
}

# Create action
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" `
    -WorkingDirectory $workingDir

# Create trigger (every 5 minutes, indefinitely)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

# Create principal (run as user with highest privileges)
$principal = New-ScheduledTaskPrincipal -UserId $UserName -LogonType Interactive -RunLevel Highest

# Register task
try {
    Write-Host "Creating scheduled task..." -ForegroundColor Cyan
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "Automated processor for Mossy Review queue - investigates pending work items and posts assessments to ADO" `
        -ErrorAction Stop | Out-Null
    
    Write-Host "[OK] Scheduled task created successfully!" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The Mossy Review Queue Processor is now scheduled to run every 5 minutes." -ForegroundColor White
Write-Host ""
Write-Host "Management Commands:" -ForegroundColor Cyan
Write-Host "  View Task:    Get-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
Write-Host "  Task Info:    Get-ScheduledTaskInfo -TaskName '$taskName'" -ForegroundColor White
Write-Host "  Run Now:      Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
Write-Host "  Enable:       Enable-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
Write-Host "  Disable:      Disable-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
Write-Host "  Remove:       Unregister-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
Write-Host ""
Write-Host "Control Scripts (easier to use):" -ForegroundColor Cyan
Write-Host "  Start:        .\Start-MossyReview-Processor.bat" -ForegroundColor White
Write-Host "  Stop:         .\Stop-MossyReview-Processor.bat" -ForegroundColor White
Write-Host ""
Write-Host "[OK] Queue processor is ENABLED and will run automatically" -ForegroundColor Green
Write-Host ""
