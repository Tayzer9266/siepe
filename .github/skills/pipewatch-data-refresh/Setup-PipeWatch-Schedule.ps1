<#
.SYNOPSIS
    Setup Windows Task Scheduler for PipeWatch weekly data refresh

.DESCRIPTION
    Creates a scheduled task to run PipeWatch backfill every Monday at 6:00 AM

.PARAMETER UserName
    Domain\Username for task execution (default: current user)

.EXAMPLE
    .\Setup-PipeWatch-Schedule.ps1
    # Uses current user credentials

.EXAMPLE
    .\Setup-PipeWatch-Schedule.ps1 -UserName "DOMAIN\serviceaccount"
    # Uses specific service account

.NOTES
    Author: Mossy (MOS Support Agent)
    Date: 2026-07-30
#>

param(
    [string]$UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
)

$ErrorActionPreference = "Stop"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PipeWatch Weekly Data Refresh Scheduler" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Task details
$taskName = "PipeWatch Weekly Data Refresh"
$scriptPath = "C:\source\MD\AdminTools\.github\skills\pipewatch-data-refresh\Update-PipeWatch-ExecutionStats.ps1"
$description = "Weekly backfill of PipeWatch Script Adapter execution statistics with failure tracking"

# Verify script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: Script not found at $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "Script Path: $scriptPath" -ForegroundColor White
Write-Host "User Account: $UserName" -ForegroundColor White
Write-Host "Schedule: Every Monday at 6:00 AM`n" -ForegroundColor White

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "WARNING: Task '$taskName' already exists" -ForegroundColor Yellow
    $response = Read-Host "Do you want to replace it? (Y/N)"
    
    if ($response -eq 'Y') {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "✓ Removed existing task" -ForegroundColor Green
    } else {
        Write-Host "Cancelled - Task not modified" -ForegroundColor Yellow
        exit 0
    }
}

# Create scheduled task components
Write-Host "Creating scheduled task..." -ForegroundColor Cyan

$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Monday `
    -At 6:00AM

$principal = New-ScheduledTaskPrincipal `
    -UserId $UserName `
    -LogonType S4U `
    -RunLevel Limited

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1)

# Register the task
try {
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description $description `
        -Force | Out-Null
    
    Write-Host "`n✓ Scheduled task created successfully!" -ForegroundColor Green
    
    # Display task details
    $task = Get-ScheduledTask -TaskName $taskName
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($task.TaskName)" -ForegroundColor White
    Write-Host "  State: $($task.State)" -ForegroundColor White
    Write-Host "  Next Run: $(Get-ScheduledTask -TaskName $taskName | Get-ScheduledTaskInfo | Select-Object -ExpandProperty NextRunTime)" -ForegroundColor White
    
    Write-Host "`nTo test the task immediately:" -ForegroundColor Yellow
    Write-Host "  Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
    
    Write-Host "`nTo view task history:" -ForegroundColor Yellow
    Write-Host "  Get-ScheduledTask -TaskName '$taskName' | Get-ScheduledTaskInfo" -ForegroundColor White
    
} catch {
    Write-Host "`nERROR: Failed to create scheduled task" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
