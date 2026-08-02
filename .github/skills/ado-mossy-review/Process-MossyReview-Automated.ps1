# ============================================
# Process-MossyReview-Automated.ps1
# PROOF OF CONCEPT: Automated Mossy Review Processing with Claude API
# ============================================
# 
# PURPOSE: Demonstrates 24/7 automated ADO ticket investigation using Claude API
# 
# RUNS: In Azure Automation (computer can be OFF)
# 
# WORKFLOW:
#   1. Query ADO for tickets tagged "Mossy Review"
#   2. For each ticket, call Claude API to analyze and generate investigation plan
#   3. Execute SQL queries suggested by Claude
#   4. Generate markdown investigation report
#   5. Post report to ADO as comment
#   6. Remove "Mossy Review" tag and add "Mossy Review - Complete"
# 
# SETUP:
#   - Store API key in Azure Key Vault or environment variable
#   - Schedule as Azure Automation runbook (daily/hourly)
#   - No human interaction needed!
# 
# ============================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$APIKey = $env:ANTHROPIC_API_KEY,

    [Parameter(Mandatory=$false)]
    [int]$MaxTicketsToProcess = 5,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun  # Don't post to ADO, just generate reports
)

# Import Claude API helper
$modulePath = Join-Path $PSScriptRoot "Invoke-ClaudeAPI.psm1"
Import-Module $modulePath -Force

# FIX: Azure CLI Unicode encoding bug (prevents ∞ symbol crash)
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

# ============================================
# CONFIGURATION
# ============================================

$ADO_ORG = "siepe"  # Organization name (for siepe.visualstudio.com or dev.azure.com/siepe)
$ADO_PROJECT = "Siepe.Software"
$TAG_TO_PROCESS = "Mossy Review"
$TAG_COMPLETE = "Mossy Review - Complete"

# MOS Production Database
$SQL_SERVER = "mos-sql-p.mos.siepe.local,52155"
$SQL_DATABASES = @("Reference", "Core", "Enterprise", "Solvas_am", "feeds")

# Output directory for investigation reports
$OUTPUT_DIR = "C:\source\MD\AdminTools\Output\AutomatedInvestigations"
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}

# ============================================
# STEP 1: QUERY ADO FOR MOSSY REVIEW TICKETS
# ============================================

function Get-MossyReviewTickets {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 1: Querying ADO for Mossy Review tickets" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $query = @"
SELECT
    [System.Id],
    [System.WorkItemType],
    [System.Title],
    [System.State],
    [System.Tags],
    [System.Description],
    [Microsoft.VSTS.TCM.ReproSteps]
FROM workitems
WHERE
    [System.TeamProject] = '$ADO_PROJECT'
    AND [System.Tags] CONTAINS '$TAG_TO_PROCESS'
    AND [System.State] <> 'Closed'
    AND [System.State] <> 'Removed'
ORDER BY [System.ChangedDate] DESC
"@

    try {
        # Get PAT token and create auth headers (BYPASS Azure CLI Unicode bug!)
        $pat = $env:AZURE_DEVOPS_PAT
        if (-not $pat) {
            throw "AZURE_DEVOPS_PAT environment variable not set"
        }
        
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
            "Content-Type" = "application/json"
        }

        $wiql = @{
            query = $query
        } | ConvertTo-Json

        # Use visualstudio.com endpoint (dev.azure.com doesn't work with PAT Basic Auth)
        $uri = "https://$ADO_ORG.visualstudio.com/$ADO_PROJECT/_apis/wit/wiql?api-version=7.0"
        
        # Use Invoke-RestMethod instead of Azure CLI to avoid Unicode encoding bugs
        $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $wiql

        if ($response.workItems.Count -eq 0) {
            Write-Host "✓ No tickets found with tag '$TAG_TO_PROCESS'" -ForegroundColor Green
            return @()
        }

        Write-Host "Found $($response.workItems.Count) tickets with tag '$TAG_TO_PROCESS'" -ForegroundColor Yellow

        # Get full work item details
        $tickets = @()
        foreach ($item in $response.workItems) {
            $ticketUri = "https://$ADO_ORG.visualstudio.com/$ADO_PROJECT/_apis/wit/workitems/$($item.id)?api-version=7.0"
            $ticket = Invoke-RestMethod -Uri $ticketUri -Method Get -Headers $headers
            $tickets += $ticket
            
            Write-Host "  - #$($ticket.id): $($ticket.fields.'System.Title')" -ForegroundColor White
        }

        return $tickets
    }
    catch {
        Write-Error "Failed to query ADO: $($_.Exception.Message)"
        throw
    }
}

# ============================================
# STEP 2: ANALYZE TICKET WITH CLAUDE API
# ============================================

function Invoke-TicketAnalysis {
    param(
        [Parameter(Mandatory=$true)]
        $Ticket,
        
        [Parameter(Mandatory=$true)]
        [string]$APIKey
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 2: Analyzing Ticket #$($Ticket.id) with Claude API" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $ticketId = $Ticket.id
    $ticketType = $Ticket.fields.'System.WorkItemType'
    $title = $Ticket.fields.'System.Title'
    $description = $Ticket.fields.'System.Description' -replace '<[^>]+>', ''  # Strip HTML
    $reproSteps = $Ticket.fields.'Microsoft.VSTS.TCM.ReproSteps' -replace '<[^>]+>', ''  # Strip HTML

    # Build comprehensive prompt for Claude
    $prompt = @"
I need you to investigate this MOS back office support ticket and provide a detailed analysis.

**Ticket Information:**
- **ID:** #$ticketId
- **Type:** $ticketType
- **Title:** $title

**Description:**
$description

**Reproduction Steps / Details:**
$reproSteps

---

**Your Task:**

1. **Classify the Issue Type** (choose one):
   - Price Reconciliation / Vendor Price Issue
   - Cash Reconciliation / Balance Discrepancy
   - SSIS / ETL Job Failure
   - Data Quality / Missing Records
   - Performance / Slow Query
   - Portfolio Setup / Instrument Mapping
   - Other (specify)

2. **Identify Key Information Needed:**
   - What specific data points are mentioned? (PKID, HCID, dates, amounts, fund names, etc.)
   - What databases are likely involved? (Reference, Core, Enterprise, Solvas_am, feeds)

3. **Generate Investigation SQL Queries:**
   - Provide 3-5 SQL queries to investigate this issue
   - Use appropriate databases (Reference, Core, Enterprise, Solvas_am, feeds)
   - Include queries to check current state, history, related records
   - Format as executable SQL (no placeholder values - use actual values from ticket)

4. **Expected Findings:**
   - What should the queries reveal?
   - What would indicate the issue is confirmed?
   - What would indicate the issue is resolved or not present?

5. **Recommended Resolution Steps:**
   - What actions should be taken based on investigation results?
   - Any procedures to run? (e.g., pInstMapI, pInstMapD)
   - Any manual fixes needed?

**Important:**
- Extract actual values from the ticket description (PKIDs, HCIDs, dates, amounts)
- Make queries copy-paste ready (no placeholders like <PKID>)
- Use proper SQL Server syntax
- Focus on MOS production database schema

**Respond with:**
1. Issue classification
2. Key data points identified
3. SQL queries (formatted as code blocks)
4. Expected findings
5. Resolution steps
"@

    Write-Host "Sending prompt to Claude API..." -ForegroundColor Yellow
    Write-Host "Prompt length: $($prompt.Length) characters" -ForegroundColor Gray

    try {
        $analysis = Invoke-ClaudeAPI -Prompt $prompt -APIKey $APIKey -MaxTokens 4096

        Write-Host "`n✓ Claude analysis received: $($analysis.Length) characters" -ForegroundColor Green

        return $analysis
    }
    catch {
        Write-Error "Claude API call failed: $($_.Exception.Message)"
        throw
    }
}

# ============================================
# STEP 3: EXECUTE SQL QUERIES FROM ANALYSIS
# ============================================

function Invoke-InvestigationQueries {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Analysis
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 3: Executing SQL Queries from Analysis" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    # Extract SQL queries from analysis (look for code blocks)
    $sqlPattern = '```sql\s*\n(.*?)\n```'
    $matches = [regex]::Matches($Analysis, $sqlPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

    if ($matches.Count -eq 0) {
        Write-Host "⚠ No SQL queries found in analysis" -ForegroundColor Yellow
        return @()
    }

    Write-Host "Found $($matches.Count) SQL queries to execute`n" -ForegroundColor Yellow

    $results = @()
    $queryNum = 1

    foreach ($match in $matches) {
        $query = $match.Groups[1].Value.Trim()

        Write-Host "--- Query $queryNum ---" -ForegroundColor Cyan
        Write-Host $query -ForegroundColor Gray
        Write-Host ""

        # Detect database from query (look for schema prefix)
        $database = "Reference"  # Default
        if ($query -match 'Core\.') { $database = "Core" }
        elseif ($query -match 'Enterprise\.') { $database = "Enterprise" }
        elseif ($query -match 'Solvas_am\.') { $database = "Solvas_am" }
        elseif ($query -match 'feeds\.') { $database = "feeds" }

        try {
            # Execute query and capture results
            $tempFile = [System.IO.Path]::GetTempFileName()
            
            $sqlcmdCommand = "sqlcmd -S `"$SQL_SERVER`" -d `"$database`" -Q `"$query`" -o `"$tempFile`" -W -s `",`""
            
            Write-Host "Executing on database: $database" -ForegroundColor Yellow
            Invoke-Expression $sqlcmdCommand | Out-Null

            $queryResult = Get-Content $tempFile -Raw

            $results += @{
                QueryNumber = $queryNum
                Database = $database
                Query = $query
                Result = $queryResult
            }

            Write-Host "✓ Query executed successfully" -ForegroundColor Green
            Write-Host "Result preview:" -ForegroundColor Gray
            Write-Host ($queryResult | Select-Object -First 500) -ForegroundColor DarkGray
            Write-Host ""

            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Host "✗ Query failed: $($_.Exception.Message)" -ForegroundColor Red
            
            $results += @{
                QueryNumber = $queryNum
                Database = $database
                Query = $query
                Result = "ERROR: $($_.Exception.Message)"
            }
        }

        $queryNum++
    }

    return $results
}

# ============================================
# STEP 4: GENERATE INVESTIGATION REPORT
# ============================================

function New-InvestigationReport {
    param(
        [Parameter(Mandatory=$true)]
        $Ticket,
        
        [Parameter(Mandatory=$true)]
        [string]$Analysis,
        
        [Parameter(Mandatory=$true)]
        [array]$QueryResults
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 4: Generating Investigation Report" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $ticketId = $Ticket.id
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $report = @"
# Automated Investigation Report - Ticket #$ticketId

**Generated:** $timestamp  
**Investigator:** Mossy (Automated Agent)  
**Ticket:** #$ticketId - $($Ticket.fields.'System.Title')

---

## Claude Analysis

$Analysis

---

## SQL Query Results

"@

    foreach ($result in $QueryResults) {
        $report += @"

### Query $($result.QueryNumber) (Database: $($result.Database))

``````sql
$($result.Query)
``````

**Result:**

``````
$($result.Result)
``````

---

"@
    }

    $report += @"

## Next Steps

- Review query results above
- Verify issue is confirmed or resolved
- Take recommended resolution steps from Claude analysis
- Update ticket status accordingly

---

**Investigation completed by automated Mossy agent using Claude API**
"@

    # Save report to file
    $reportFile = Join-Path $OUTPUT_DIR "Investigation_${ticketId}_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    $report | Out-File -FilePath $reportFile -Encoding UTF8

    Write-Host "✓ Investigation report saved to:" -ForegroundColor Green
    Write-Host "  $reportFile" -ForegroundColor White

    return @{
        FilePath = $reportFile
        Content = $report
    }
}

# ============================================
# STEP 5: POST REPORT TO ADO
# ============================================

function Add-InvestigationToADO {
    param(
        [Parameter(Mandatory=$true)]
        $Ticket,
        
        [Parameter(Mandatory=$true)]
        [string]$ReportContent,
        
        [Parameter(Mandatory=$false)]
        [switch]$DryRun
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "STEP 5: Posting Report to ADO Ticket" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan

    $ticketId = $Ticket.id

    if ($DryRun) {
        Write-Host "⚠ DRY RUN MODE: Would post this comment to #$ticketId" -ForegroundColor Yellow
        Write-Host $ReportContent -ForegroundColor Gray
        return
    }

    try {
        # Get PAT token and create auth headers (BYPASS Azure CLI Unicode bug!)
        $pat = $env:AZURE_DEVOPS_PAT
        if (-not $pat) {
            throw "AZURE_DEVOPS_PAT environment variable not set"
        }
        
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
        $headers = @{
            Authorization = "Basic $base64AuthInfo"
        }
        
        # Add comment to work item
        $commentBody = @{
            text = $ReportContent
        } | ConvertTo-Json

        $commentUri = "https://$ADO_ORG.visualstudio.com/$ADO_PROJECT/_apis/wit/workItems/$ticketId/comments?api-version=7.0"
        
        # Use Invoke-RestMethod instead of Azure CLI to avoid Unicode encoding bugs
        $headers["Content-Type"] = "application/json"
        Invoke-RestMethod -Uri $commentUri -Method Post -Headers $headers -Body $commentBody | Out-Null

        Write-Host "✓ Posted investigation report to ticket #$ticketId" -ForegroundColor Green

        # Update tags: remove "Mossy Review", add "Mossy Review - Complete"
        $currentTags = $Ticket.fields.'System.Tags'
        $newTags = $currentTags -replace [regex]::Escape($TAG_TO_PROCESS), $TAG_COMPLETE

        $updateBody = @(
            @{
                op = "replace"
                path = "/fields/System.Tags"
                value = $newTags
            }
        ) | ConvertTo-Json

        $updateUri = "https://$ADO_ORG.visualstudio.com/$ADO_PROJECT/_apis/wit/workitems/$ticketId?api-version=7.0"
        
        # Use Invoke-RestMethod with JSON Patch content type
        $headers["Content-Type"] = "application/json-patch+json"
        Invoke-RestMethod -Uri $updateUri -Method Patch -Headers $headers -Body $updateBody | Out-Null

        Write-Host "✓ Updated tags: '$TAG_TO_PROCESS' → '$TAG_COMPLETE'" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to post to ADO: $($_.Exception.Message)"
        throw
    }
}

# ============================================
# MAIN EXECUTION
# ============================================

function Main {
    Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     MOSSY AUTOMATED INVESTIGATION AGENT (Proof of Concept)    ║
║                                                                ║
║     Powered by Claude API - Runs 24/7 in Azure Automation     ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  ADO Organization: $ADO_ORG" -ForegroundColor White
    Write-Host "  ADO Project: $ADO_PROJECT" -ForegroundColor White
    Write-Host "  Tag to Process: $TAG_TO_PROCESS" -ForegroundColor White
    Write-Host "  Max Tickets: $MaxTicketsToProcess" -ForegroundColor White
    Write-Host "  SQL Server: $SQL_SERVER" -ForegroundColor White
    Write-Host "  Output Directory: $OUTPUT_DIR" -ForegroundColor White
    Write-Host "  Dry Run: $DryRun" -ForegroundColor White
    Write-Host ""

    # Check API key
    if (-not $APIKey) {
        Write-Error "API key not provided. Set ANTHROPIC_API_KEY environment variable or pass -APIKey parameter."
        exit 1
    }
    Write-Host "✓ API key configured" -ForegroundColor Green

    # STEP 1: Get tickets
    $tickets = Get-MossyReviewTickets

    if ($tickets.Count -eq 0) {
        Write-Host "`n✓ No tickets to process. Exiting." -ForegroundColor Green
        return
    }

    # Limit number of tickets to process
    $ticketsToProcess = $tickets | Select-Object -First $MaxTicketsToProcess

    Write-Host "`nProcessing $($ticketsToProcess.Count) ticket(s)..." -ForegroundColor Yellow

    $processedCount = 0
    $successCount = 0
    $failureCount = 0

    foreach ($ticket in $ticketsToProcess) {
        $processedCount++

        Write-Host "`n" -NoNewline
        Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
        Write-Host "  Processing Ticket $processedCount of $($ticketsToProcess.Count): #$($ticket.id)" -ForegroundColor Magenta
        Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Magenta

        try {
            # STEP 2: Analyze with Claude
            $analysis = Invoke-TicketAnalysis -Ticket $ticket -APIKey $APIKey

            # STEP 3: Execute SQL queries
            $queryResults = Invoke-InvestigationQueries -Analysis $analysis

            # STEP 4: Generate report
            $report = New-InvestigationReport -Ticket $ticket -Analysis $analysis -QueryResults $queryResults

            # STEP 5: Post to ADO
            Add-InvestigationToADO -Ticket $ticket -ReportContent $report.Content -DryRun:$DryRun

            $successCount++
            Write-Host "`n✓ Ticket #$($ticket.id) processed successfully!" -ForegroundColor Green
        }
        catch {
            $failureCount++
            Write-Host "`n✗ Ticket #$($ticket.id) failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Summary
    Write-Host "`n" -NoNewline
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  EXECUTION SUMMARY" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Total Tickets Processed: $processedCount" -ForegroundColor White
    Write-Host "  Successful: $successCount" -ForegroundColor Green
    Write-Host "  Failed: $failureCount" -ForegroundColor Red
    Write-Host "  Reports Generated: $OUTPUT_DIR" -ForegroundColor White
    Write-Host ""

    if ($DryRun) {
        Write-Host "⚠ DRY RUN MODE: No changes were made to ADO tickets" -ForegroundColor Yellow
    }
    else {
        Write-Host "✓ All successful tickets updated in ADO" -ForegroundColor Green
    }

    Write-Host "`n✓ Automated investigation complete!" -ForegroundColor Green
}

# Run main function
Main
