# ================================================================
# Continuous Mossy Review Monitor - Loop Script
# ================================================================
# Purpose: Continuously monitor ADO for "Mossy Review" work items
# Method: Runs in an infinite loop, checking every 2 minutes
# Usage: Run in a persistent PowerShell window or as a background job
# ================================================================

param(
    [int]$IntervalMinutes = 2,
    [string]$Organization = "https://siepe.visualstudio.com/",
    [string]$Project = "Siepe.Software",
    [string]$LogPath = "C:\source\MD\AdminTools\.github\skills\ado-mossy-review\mossy-review-monitor.log",
    [switch]$NotifyOnNewItems,
    [switch]$Verbose
)

$stateFile = "C:\source\MD\AdminTools\.github\skills\ado-mossy-review\mossy-review-state.json"
$intervalSeconds = $IntervalMinutes * 60

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MOSSY REVIEW CONTINUOUS MONITOR" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "Check Interval: $IntervalMinutes minute(s)" -ForegroundColor White
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

$checkCount = 0

# Load previous state if exists
$previousState = @{}
if (Test-Path $stateFile) {
    $previousState = Get-Content $stateFile -Raw | ConvertFrom-Json -AsHashtable
}

# Main monitoring loop
while ($true) {
    $checkCount++
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    if ($Verbose) {
        Write-Host "[$timestamp] Check #$checkCount - Querying ADO..." -ForegroundColor Gray
    }
    
    $wiql = @"
SELECT 
    [System.Id], 
    [System.Title], 
    [System.WorkItemType], 
    [System.State], 
    [System.IterationPath], 
    [System.Tags],
    [System.AssignedTo]
FROM WorkItems 
WHERE [System.Tags] CONTAINS 'Mossy Review' 
    AND [System.WorkItemType] IN ('Task', 'Bug') 
    AND [System.State] <> 'Closed' 
    AND [System.State] <> 'Removed' 
ORDER BY [System.CreatedDate] DESC
"@
    
    try {
        # Execute query
        $result = az boards query --wiql $wiql --output json 2>&1 | Out-String
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[$timestamp] ERROR: Failed to query ADO" -ForegroundColor Red
            "[$timestamp] ERROR: $result" | Out-File -FilePath $LogPath -Append -Encoding UTF8
            Start-Sleep -Seconds $intervalSeconds
            continue
        }
        
        $workItems = $result | ConvertFrom-Json
        
        # Build current state
        $currentState = @{}
        foreach ($item in $workItems) {
            $currentState[$item.'System.Id'] = @{
                Title = $item.'System.Title'
                State = $item.'System.State'
                Type = $item.'System.WorkItemType'
                Sprint = $item.'System.IterationPath'
            }
        }
        
        # Detect new items
        $newItems = @()
        $stateChanged = @()
        
        foreach ($id in $currentState.Keys) {
            if (-not $previousState.ContainsKey($id)) {
                $newItems += $id
            } elseif ($previousState[$id].State -ne $currentState[$id].State) {
                $stateChanged += $id
            }
        }
        
        # Detect closed/removed items
        $removedItems = @()
        foreach ($id in $previousState.Keys) {
            if (-not $currentState.ContainsKey($id)) {
                $removedItems += $id
            }
        }
        
        # Output summary
        $summary = "[$timestamp] Active items: $($workItems.Count)"
        
        if ($newItems.Count -gt 0 -or $stateChanged.Count -gt 0 -or $removedItems.Count -gt 0) {
            Write-Host "`n========================================" -ForegroundColor Yellow
            Write-Host $summary -ForegroundColor White
            Write-Host "========================================" -ForegroundColor Yellow
            
            # New items
            if ($newItems.Count -gt 0) {
                Write-Host "`n🔔 NEW ITEMS ($($newItems.Count)):" -ForegroundColor Green
                foreach ($id in $newItems) {
                    $item = $workItems | Where-Object { $_.'System.Id' -eq $id }
                    $sprint = if ($item.'System.IterationPath') { $item.'System.IterationPath'.Split('\')[-1] } else { "No Sprint" }
                    Write-Host "  $($item.'System.WorkItemType') #$id - $($item.'System.Title')" -ForegroundColor Green
                    Write-Host "    Sprint: $sprint | State: $($item.'System.State')" -ForegroundColor Gray
                    Write-Host "    URL: $Organization$Project/_workitems/edit/$id" -ForegroundColor Cyan
                }
                
                # Log to file
                $logEntry = "`n[$timestamp] NEW ITEMS:`n"
                foreach ($id in $newItems) {
                    $item = $workItems | Where-Object { $_.'System.Id' -eq $id }
                    $logEntry += "  $($item.'System.WorkItemType') #$id - $($item.'System.Title')`n"
                }
                $logEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8
            }
            
            # State changes
            if ($stateChanged.Count -gt 0) {
                Write-Host "`n🔄 STATE CHANGES ($($stateChanged.Count)):" -ForegroundColor Yellow
                foreach ($id in $stateChanged) {
                    $item = $workItems | Where-Object { $_.'System.Id' -eq $id }
                    Write-Host "  $($item.'System.WorkItemType') #$id - $($item.'System.Title')" -ForegroundColor Yellow
                    Write-Host "    $($previousState[$id].State) → $($item.'System.State')" -ForegroundColor Gray
                }
            }
            
            # Removed items
            if ($removedItems.Count -gt 0) {
                Write-Host "`n✅ COMPLETED/CLOSED ($($removedItems.Count)):" -ForegroundColor Magenta
                foreach ($id in $removedItems) {
                    Write-Host "  $($previousState[$id].Type) #$id - $($previousState[$id].Title)" -ForegroundColor Magenta
                }
            }
            
            Write-Host "========================================`n" -ForegroundColor Yellow
        } else {
            # No changes
            if ($Verbose) {
                Write-Host $summary -ForegroundColor Gray
            } else {
                # Just show a dot to indicate it's running
                Write-Host "." -NoNewline -ForegroundColor Gray
            }
        }
        
        # Save current state
        $currentState | ConvertTo-Json -Depth 10 | Out-File -FilePath $stateFile -Encoding UTF8
        $previousState = $currentState
        
    } catch {
        Write-Host "[$timestamp] EXCEPTION: $($_.Exception.Message)" -ForegroundColor Red
        "[$timestamp] EXCEPTION: $($_.Exception.Message)" | Out-File -FilePath $LogPath -Append -Encoding UTF8
    }
    
    # Wait for next check
    Start-Sleep -Seconds $intervalSeconds
}
