# ================================================================
# Quick Mossy Review Check - Simple Version
# ================================================================

param(
    [string]$Organization = "https://siepe.visualstudio.com/",
    [string]$Project = "Siepe.Software"
)

Write-Host "`nChecking for Mossy Review work items...`n" -ForegroundColor Cyan

# Query for Mossy Review items
$wiql = "SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State], [System.Tags] FROM WorkItems WHERE [System.Tags] CONTAINS 'Mossy Review' AND [System.State] <> 'Closed' AND [System.State] <> 'Removed' ORDER BY [System.CreatedDate] DESC"

try {
    $result = az boards query --wiql $wiql --output json 2>&1 | Out-String
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to query ADO" -ForegroundColor Red
        Write-Host $result
        exit 1
    }
    
    $workItems = @($result | ConvertFrom-Json)
    
    if ($null -eq $workItems -or $workItems.Count -eq 0) {
        Write-Host "No active work items with 'Mossy Review' tag" -ForegroundColor Green
        exit 0
    }
    
    # Display results
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "MOSSY REVIEW QUEUE" -ForegroundColor Yellow
    Write-Host "Found $($workItems.Count) active work item(s)" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($item in $workItems) {
        $id = $item.fields.'System.Id'
        $title = $item.fields.'System.Title'
        $type = $item.fields.'System.WorkItemType'
        $state = $item.fields.'System.State'
        $url = "$Organization$Project/_workitems/edit/$id"
        
        Write-Host "  $type #$id" -ForegroundColor Yellow
        Write-Host "  Title: $title" -ForegroundColor White
        Write-Host "  State: $state" -ForegroundColor Gray
        Write-Host "  URL: $url" -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
} catch {
    Write-Host "ERROR: $_" -ForegroundColor Red
    exit 1
}
