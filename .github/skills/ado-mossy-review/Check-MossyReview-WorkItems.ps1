# ================================================================
# Check Mossy Review Work Items - Monitoring Script
# ================================================================
# Purpose: Query Azure DevOps for active work items tagged with "Mossy Review"
# Schedule: Run every 2 minutes via Task Scheduler
# Output: Console output + optional log file
# ================================================================

param(
    [string]$Organization = "https://siepe.visualstudio.com/",
    [string]$Project = "Siepe.Software",
    [switch]$LogToFile,
    [string]$LogPath = "C:\source\MD\AdminTools\Output\mossy-review-monitor.log",
    [switch]$OnlyShowChanges  # Only output when new items appear
)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Query ADO for Mossy Review work items (single line for az CLI compatibility)
$wiql = "SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State], [System.IterationPath], [System.Tags], [System.AssignedTo], [System.CreatedDate] FROM WorkItems WHERE [System.Tags] CONTAINS 'Mossy Review' AND [System.WorkItemType] IN ('Task', 'Bug') AND [System.State] <> 'Closed' AND [System.State] <> 'Removed' ORDER BY [System.CreatedDate] DESC"

try {
    # Execute query
    $result = az boards query --wiql $wiql --output json 2>&1 | Out-String
    
    if ($LASTEXITCODE -ne 0) {
        $errorMsg = "[$timestamp] ERROR: Failed to query ADO - $result"
        Write-Host $errorMsg -ForegroundColor Red
        if ($LogToFile) {
            $errorMsg | Out-File -FilePath $LogPath -Append -Encoding UTF8
        }
        exit 1
    }
    
    $workItems = @($result | ConvertFrom-Json)  # JSON is directly an array, force array wrapper
    
    # Check if we have work items
    if ($null -eq $workItems -or $workItems.Count -eq 0) {
        if (-not $OnlyShowChanges) {
            $msg = "[$timestamp] No active work items with 'Mossy Review' tag"
            Write-Host $msg -ForegroundColor Green
            if ($LogToFile) {
                $msg | Out-File -FilePath $LogPath -Append -Encoding UTF8
            }
        }
        exit 0
    }
    
    # Current sprint detection
    $today = Get-Date
    
    # Build output
    $output = @()
    $output += ""
    $output += "=========================================="
    $output += "MOSSY REVIEW WORK ITEMS - $timestamp"
    $output += "=========================================="
    $output += "Found $($workItems.Count) active work item(s):"
    $output += ""
    
    foreach ($item in $workItems) {
        $fields = $item.fields
        $id = $fields.'System.Id'
        $title = $fields.'System.Title'
        $type = $fields.'System.WorkItemType'
        $state = $fields.'System.State'
        $iteration = $fields.'System.IterationPath'
        $tags = $fields.'System.Tags'
        $assignedTo = $fields.'System.AssignedTo'
        $created = $fields.'System.CreatedDate'
        
        # Extract sprint from iteration path
        $sprint = if ($iteration) { $iteration.Split('\')[-1] } else { "No Sprint" }
        
        # Determine if current sprint (basic check - sprint contains current date range)
        $isCurrentSprint = $false
        if ($iteration -and $iteration.Length -ge 5 -and $iteration -match '\d{2}\.\d{2}[ab]') {
            # Format like "07.26b" - check if month matches
            try {
                $sprintMonth = [int]$iteration.Substring($iteration.Length - 5, 2)
                if ($sprintMonth -eq $today.Month) {
                    $isCurrentSprint = $true
                }
            } catch {
                # Ignore parsing errors for non-standard sprint names
            }
        }
        
        $sprintIndicator = if ($isCurrentSprint) { " [CURRENT SPRINT]" } else { "" }
        
        $output += "$type #$id - $title"
        $output += "  State: $state"
        $output += "  Sprint: $sprint$sprintIndicator"
        $output += "  Tags: $tags"
        if ($assignedTo) {
            $output += "  Assigned: $assignedTo"
        }
        $output += "  URL: $Organization$Project/_workitems/edit/$id"
        $output += ""
    }
    
    $output += "=========================================="
    
    # Output to console
    $output | ForEach-Object { Write-Host $_ }
    
    # Log to file if requested
    if ($LogToFile) {
        $output | Out-File -FilePath $LogPath -Append -Encoding UTF8
    }
    
    # ================================================================
    # QUEUE MANAGEMENT WITH CONCURRENCY CONTROL
    # ================================================================
    
    $stateFile = "C:\source\MD\AdminTools\Output\mossy-review-state.json"
    $queueFile = "C:\source\MD\AdminTools\Output\mossy-review-queue.json"
    $maxConcurrentReviews = 2  # Maximum items Mossy can review simultaneously
    
    $previousState = @{}
    $queue = @{}
    
    if (Test-Path $stateFile) {
        $previousStateObj = Get-Content $stateFile -Raw | ConvertFrom-Json
        # Convert PSCustomObject to Hashtable for easier manipulation
        $previousStateObj.PSObject.Properties | ForEach-Object {
            $previousState[$_.Name] = $_.Value
        }
    }
    
    if (Test-Path $queueFile) {
        $queueObj = Get-Content $queueFile -Raw | ConvertFrom-Json
        # Convert PSCustomObject to Hashtable for easier manipulation
        $queueObj.PSObject.Properties | ForEach-Object {
            $queue[$_.Name] = $_.Value
        }
    }
    
    # Build current state
    $currentState = @{}
    foreach ($item in $workItems) {
        $fields = $item.fields
        $idString = $fields.'System.Id'.ToString()  # Ensure string key for JSON serialization
        $currentState[$idString] = @{
            Title = $fields.'System.Title'
            State = $fields.'System.State'
            Type = $fields.'System.WorkItemType'
            Sprint = if ($fields.'System.IterationPath') { $fields.'System.IterationPath'.Split('\')[-1] } else { "No Sprint" }
        }
    }
    
    # Save current state
    $currentState | ConvertTo-Json -Depth 10 | Out-File -FilePath $stateFile -Encoding UTF8
    
    # Count items currently in progress (concurrency check)
    $inProgressCount = 0
    foreach ($queueItem in $queue.Values) {
        if ($queueItem.status -eq "in_progress") {
            $inProgressCount++
        }
    }
    
    # Detect new items and changes
    $newItems = @()
    $reinvestigateItems = @()
    $queueUpdated = $false
    
    foreach ($idString in $currentState.Keys) {
        $id = [int]$idString  # Convert string key back to int for comparisons
        $item = $workItems | Where-Object { $_.fields.'System.Id' -eq $id }
        $fields = $item.fields
        $tags = $fields.'System.Tags'
        $hasMossyReview = $tags -like "*Mossy Review*"
        $hasMossyReviewAgain = $tags -like "*Mossy Review Again*"
        
        # Check if item is in queue
        $inQueue = $queue.ContainsKey($idString)
        
        if ($hasMossyReviewAgain -and $inQueue) {
            # Reinvestigation requested
            $queue[$idString].status = "pending"
            $currentCount = if ($queue[$idString].review_count) { $queue[$idString].review_count } else { 0 }
            $queue[$idString].review_count = $currentCount + 1
            $queue[$idString].last_updated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            $reinvestigateItems += $id
            $queueUpdated = $true
            
            $reinvestigateMsg = "[REINVESTIGATION] Work item #$id added to queue again (review count: $($queue[$idString].review_count))"
            Write-Host $reinvestigateMsg -ForegroundColor Magenta
            if ($LogToFile) {
                $reinvestigateMsg | Out-File -FilePath $LogPath -Append -Encoding UTF8
            }
        }
        elseif (-not $previousState.ContainsKey($idString) -and -not $inQueue) {
            # New item detected
            if ($inProgressCount -lt $maxConcurrentReviews) {
                # Add to queue with "pending" status
                $queue[$idString] = @{
                    work_item_id = $id
                    title = $fields.'System.Title'
                    type = $fields.'System.WorkItemType'
                    status = "pending"
                    date_added = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    sprint = if ($fields.'System.IterationPath') { $fields.'System.IterationPath'.Split('\')[-1] } else { "No Sprint" }
                    review_count = 1
                    last_reviewed = $null
                    user_context = ""
                    assessments = @()
                }
                $newItems += $id
                $queueUpdated = $true
                
                $queueMsg = "[QUEUE_ADD] Work item #$id added to queue (In Progress: $inProgressCount/$maxConcurrentReviews)"
                Write-Host $queueMsg -ForegroundColor Green
                if ($LogToFile) {
                    $queueMsg | Out-File -FilePath $LogPath -Append -Encoding UTF8
                }
            }
            else {
                # Queue full - skip for now
                $skipMsg = "[QUEUE_FULL] Work item #$id detected but queue is full (In Progress: $inProgressCount/$maxConcurrentReviews). Will retry on next check."
                Write-Host $skipMsg -ForegroundColor Yellow
                if ($LogToFile) {
                    $skipMsg | Out-File -FilePath $LogPath -Append -Encoding UTF8
                }
            }
        }
        elseif ($inQueue -and $queue[$idString].status -eq "reviewed") {
            # Already reviewed - skip
            $skipMsg = "[QUEUE_SKIP] Work item #$id already reviewed. Use 'Mossy Review Again' tag to reinvestigate."
            Write-Host $skipMsg -ForegroundColor Gray
            if ($LogToFile) {
                $skipMsg | Out-File -FilePath $LogPath -Append -Encoding UTF8
            }
        }
    }
    
    # Save updated queue
    if ($queueUpdated) {
        $queue | ConvertTo-Json -Depth 10 | Out-File -FilePath $queueFile -Encoding UTF8
    }
    
    # Alert for new items
    if ($newItems.Count -gt 0) {
        $alertMsg = ""
        $alertMsg += "=========================================="
        $alertMsg += "🔔 NEW MOSSY REVIEW ITEMS DETECTED!"
        $alertMsg += "=========================================="
        $alertMsg += "Concurrency Status: $inProgressCount/$maxConcurrentReviews in progress"
        $alertMsg += ""
        foreach ($id in $newItems) {
            $item = $workItems | Where-Object { $_.'System.Id' -eq $id }
            $alertMsg += "$($item.'System.WorkItemType') #$id - $($item.'System.Title')"
            $alertMsg += "  URL: $Organization$Project/_workitems/edit/$id"
        }
        $alertMsg += "=========================================="
        
        Write-Host $alertMsg -ForegroundColor Yellow
        
        if ($LogToFile) {
            $alertMsg | Out-File -FilePath $LogPath -Append -Encoding UTF8
        }
    }
    
    # Summary of queue status
    $queueSummaryMsg = "Queue Status: $($queue.Count) total items | $inProgressCount in progress | $($queue.Values | Where-Object { $_.status -eq 'pending' } | Measure-Object | Select-Object -ExpandProperty Count) pending | $($queue.Values | Where-Object { $_.status -eq 'reviewed' } | Measure-Object | Select-Object -ExpandProperty Count) reviewed"
    Write-Host $queueSummaryMsg -ForegroundColor Cyan
    if ($LogToFile) {
        $queueSummaryMsg | Out-File -FilePath $LogPath -Append -Encoding UTF8
    }
    
} catch {
    $errorMsg = "[$timestamp] EXCEPTION: $($_.Exception.Message)"
    Write-Host $errorMsg -ForegroundColor Red
    if ($LogToFile) {
        $errorMsg | Out-File -FilePath $LogPath -Append -Encoding UTF8
    }
    exit 1
}
