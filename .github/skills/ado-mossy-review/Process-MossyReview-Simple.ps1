<#
.SYNOPSIS
Simple Mossy Review Processor - Uses Azure CLI (works perfectly!)

.DESCRIPTION
Simplified version without box-drawing characters that break encoding
#>

param(
    [int]$MaxTickets = 5,
    [switch]$DryRun
)

# Import Claude API module
Import-Module (Join-Path $PSScriptRoot "Invoke-ClaudeAPI.psm1") -Force

# Configuration
$ADO_ORG = "siepe"
$ADO_PROJECT = "Siepe.Software"
$TAG_TO_PROCESS = "Mossy Review"
$TAG_COMPLETE = "Mossy Review - Complete"
$OUTPUT_DIR = "C:\MossyOutput"

# Get API key
$APIKey = if ($env:ANTHROPIC_API_KEY) { $env:ANTHROPIC_API_KEY } else { throw "ANTHROPIC_API_KEY not set" }

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "MOSSY AUTOMATED REVIEW PROCESSOR" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan
Write-Host "Config: $ADO_ORG / $ADO_PROJECT" -ForegroundColor Gray
Write-Host "Tag: $TAG_TO_PROCESS" -ForegroundColor Gray
Write-Host "Max: $MaxTickets tickets`n" -ForegroundColor Gray

# STEP 1: Query for tickets
Write-Host "[1/3] Querying for tickets..." -ForegroundColor Yellow

$query = "SELECT [System.Id], [System.Title], [System.Tags] FROM workitems WHERE [System.TeamProject] = '$ADO_PROJECT' AND [System.Tags] CONTAINS '$TAG_TO_PROCESS' AND [System.State] <> 'Closed'"

try {
    $tickets = az boards query --wiql $query --org https://$ADO_ORG.visualstudio.com --output json | ConvertFrom-Json
    
    if ($tickets.Count -eq 0) {
        Write-Host "No tickets found. Exiting." -ForegroundColor Green
        exit 0
    }
    
    Write-Host "Found $($tickets.Count) tickets" -ForegroundColor Green
    $tickets | ForEach-Object { Write-Host "  - #$($_.id): $($_.fields.'System.Title')" -ForegroundColor White }
    
} catch {
    Write-Error "Query failed: $_"
    exit 1
}

# STEP 2: Process each ticket
$processCount = [Math]::Min($MaxTickets, $tickets.Count)
Write-Host "`n[2/3] Processing $processCount ticket(s)..." -ForegroundColor Yellow

for ($i = 0; $i -lt $processCount; $i++) {
    $ticket = $tickets[$i]
    $ticketId = $ticket.id
    
    Write-Host "`n--- Ticket #$ticketId ---" -ForegroundColor Magenta
    
    # Build investigation prompt
    $title = $ticket.fields.'System.Title'
    $description = $ticket.fields.'System.Description' -replace '<[^>]+>', '' # Strip HTML
    
    $prompt = @"
You are Mossy, an expert database and pricing systems investigator.

TICKET: #$ticketId
TITLE: $title
DESCRIPTION: $description

Analyze this ticket and provide a brief investigation report with:
1. Summary of the issue
2. Likely causes
3. Recommended next steps

Keep it concise (max 500 words).
"@
    
    # Call Claude
    Write-Host "Analyzing with Claude..." -ForegroundColor Cyan
    
    try {
        $report = Invoke-ClaudeAPI -Prompt $prompt -MaxTokens 2000 -APIKey $APIKey
        
        Write-Host "Generated $($report.Length) character report" -ForegroundColor Green
        
        if ($DryRun) {
            Write-Host "`nDRY RUN - Would post:" -ForegroundColor Yellow
            Write-Host $report -ForegroundColor Gray
        } else {
            # Post comment to ADO
            Write-Host "Posting to ADO..." -ForegroundColor Cyan
            az boards work-item update --id $ticketId --discussion $report --org https://$ADO_ORG.visualstudio.com | Out-Null
            
            # Update tags
            $currentTags = $ticket.fields.'System.Tags'
            $newTags = $currentTags -replace [regex]::Escape($TAG_TO_PROCESS), $TAG_COMPLETE
            
            az boards work-item update --id $ticketId --fields "System.Tags=$newTags" --org https://$ADO_ORG.visualstudio.com | Out-Null
            
            Write-Host "Done! Tag updated to: $TAG_COMPLETE" -ForegroundColor Green
        }
        
    } catch {
        $errorMsg = $_.Exception.Message
        Write-Error "Failed to process ticket #${ticketId}: $errorMsg"
    }
}

Write-Host "`n[3/3] Complete!" -ForegroundColor Green
Write-Host "Processed $processCount tickets" -ForegroundColor White
