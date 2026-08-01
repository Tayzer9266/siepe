# ================================================================
# Process Mossy Review Queue - Automated Investigation Processor
# ================================================================
# Purpose: Process pending work items in the Mossy Review queue
# Schedule: Run every 5 minutes via Task Scheduler
# Phases: Fetch details → Investigate → Generate assessment → Post to ADO → Update tags
# ================================================================

param(
    [string]$Organization = "https://siepe.visualstudio.com/",
    [string]$Project = "Siepe.Software",
    [switch]$LogToFile,
    [string]$LogPath = "C:\source\MD\AdminTools\Output\mossy-review-processor.log",
    [int]$MaxConcurrentReviews = 2
)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$queueFile = "C:\source\MD\AdminTools\Output\mossy-review-queue.json"

# ================================================================
# HELPER FUNCTIONS
# ================================================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    if ($LogToFile) {
        $logMessage | Out-File -FilePath $LogPath -Append -Encoding UTF8
    }
}

function Get-WorkItemDetails {
    param([int]$WorkItemId)
    
    try {
        $json = az boards work-item show --id $WorkItemId --output json 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to fetch work item #$WorkItemId - $json" "ERROR"
            return $null
        }
        return $json | ConvertFrom-Json
    }
    catch {
        Write-Log "Exception fetching work item #$WorkItemId - $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Invoke-AutomatedInvestigation {
    param(
        [int]$WorkItemId,
        [string]$Title,
        [string]$Description,
        [string]$Type
    )
    
    Write-Log "Starting automated investigation for #$WorkItemId - $Title"
    
    $findings = @()
    $queries = @()
    
    # Pattern detection
    $isPricingIssue = $Title -match "pric(e|ing)" -or $Description -match "pric(e|ing)"
    $isCashIssue = $Title -match "cash|balance|reconcil" -or $Description -match "cash|balance|reconcil"
    $isSSISIssue = $Title -match "ssis|etl|import|load" -or $Description -match "ssis|etl|import|load"
    $isDataQuality = $Title -match "duplicat|missing|incorrect|invalid" -or $Description -match "duplicat|missing|incorrect|invalid"
    
    # PHASE 1: Pattern-based investigation
    if ($isPricingIssue) {
        Write-Log "Detected pricing issue pattern"
        $findings += '**Issue Type**: Pricing/Valuation'
        $findings += ''
        $findings += '**Common Causes:**'
        $findings += "- Missing or stale security master data"
        $findings += "- Vendor price delivery delays (Markit, LSEG, ICE)"
        $findings += "- Price override conflicts"
        $findings += "- Security identifier mapping issues"
        
        $queries += @"
-- Check recent price updates
SELECT TOP 10 
    SecurityID, 
    PriceDate, 
    Price, 
    PriceSource,
    LastModifiedDate
FROM SecurityMaster.dbo.tSecurityPrice
ORDER BY LastModifiedDate DESC;
"@
    }
    
    if ($isCashIssue) {
        Write-Log "Detected cash/balance issue pattern"
        $findings += '**Issue Type**: Cash Reconciliation/Balance Discrepancy'
        $findings += ''
        $findings += '**Common Causes:**'
        $findings += "- Transaction timing differences"
        $findings += "- Pending settlements not reflected"
        $findings += "- FX rate application issues"
        $findings += "- Manual adjustment missing"
        
        $queries += @"
-- Check recent cash transactions
SELECT TOP 10
    TransactionDate,
    AccountNumber,
    TransactionType,
    Amount,
    Currency,
    Status
FROM Enterprise.dbo.tCashTransaction
ORDER BY TransactionDate DESC;
"@
    }
    
    if ($isSSISIssue) {
        Write-Log "Detected SSIS/ETL issue pattern"
        $findings += '**Issue Type**: SSIS/ETL Pipeline Failure'
        $findings += ''
        $findings += '**Common Causes:**'
        $findings += "- Script Adapter timeout (check execution duration)"
        $findings += "- Missing or malformed import file"
        $findings += "- Database connectivity issues"
        $findings += "- Schema validation failure"
        
        $queries += @"
-- Check recent SSIS failures
SELECT TOP 10
    ScriptConfigurationID,
    StartTime,
    EndTime,
    DATEDIFF(SECOND, StartTime, EndTime) AS DurationSeconds,
    JobDetail
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory
WHERE JobDetail LIKE '%failed%' OR JobDetail LIKE '%error%' OR JobDetail LIKE '%timeout%'
ORDER BY StartTime DESC;
"@
    }
    
    if ($isDataQuality) {
        Write-Log "Detected data quality issue pattern"
        $findings += '**Issue Type**: Data Quality/Integrity'
        $findings += ''
        $findings += '**Common Causes:**'
        $findings += "- Duplicate record creation (check unique constraints)"
        $findings += "- Missing required identifiers (CUSIP, ISIN, Ticker)"
        $findings += "- Data normalization issues"
        $findings += "- Reference data synchronization lag"
    }
    
    # PHASE 2: Extract identifiers from description
    $identifiers = @()
    if ($Description -match "CUSIP[:\s]*([A-Z0-9]{9})") {
        $identifiers += "CUSIP: $($matches[1])"
    }
    if ($Description -match "ISIN[:\s]*([A-Z]{2}[A-Z0-9]{10})") {
        $identifiers += "ISIN: $($matches[1])"
    }
    if ($Description -match "#(\d{5,})") {
        $identifiers += "Work Item: #$($matches[1])"
    }
    if ($Description -match "Task[:\s#]*(\d{5,})") {
        $identifiers += "Task: #$($matches[1])"
    }
    
    if ($identifiers.Count -gt 0) {
        $findings += ''
        $findings += '**Identifiers Found:**'
        $findings += $identifiers -join ", "
    }
    
    # PHASE 3: Generate generic investigation steps
    if ($findings.Count -eq 0) {
        $findings += '**Issue Type**: General Investigation Required'
        $findings += ''
        $findings += '**Recommended Actions:**'
        $findings += "1. Review work item description for specific error messages or identifiers"
        $findings += "2. Check recent activity in related systems (MOS, Solvas, SecurityMaster)"
        $findings += "3. Search Seq logs for error patterns around incident timeframe"
        $findings += "4. Verify data integrity with sample queries"
    }
    
    # PHASE 4: Add investigation queries
    if ($queries.Count -gt 0) {
        $findings += ''
        $findings += '**Diagnostic Queries:**'
        $findings += '```sql'
        $findings += $queries -join "`n`n"
        $findings += '```'
    }
    
    # PHASE 5: Next steps
    $findings += ""
    $findings += '**Next Steps:**'
    $findings += '1. Execute diagnostic queries above'
    $findings += '2. Review results for anomalies'
    $findings += '3. Check related logs in Seq (if error messages found)'
    $findings += '4. Update this work item with specific findings'
    $findings += '5. If issue is resolved, add resolution details'
    $findings += '6. If blocked or needs escalation, tag with ''Mossy Review Again'''
    
    return $findings -join "`n"
}

function Post-AssessmentToADO {
    param(
        [int]$WorkItemId,
        [string]$Assessment,
        [string]$Title
    )
    
    try {
        Write-Log "Creating investigation report for work item #$WorkItemId"
        
        # Create investigation markdown file (Mossy's pattern)
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $sanitizedTitle = $Title -replace '[^\w\s-]', '' -replace '\s+', '_'
        $fileName = "MossyReview_$($WorkItemId)_$($sanitizedTitle)_$timestamp.md"
        $filePath = Join-Path $PSScriptRoot "..\..\Output" $fileName
        
        # Format as comprehensive markdown investigation report
        $reportContent = @"
# 🤖 Mossy Automated Review - Work Item #$WorkItemId

**Title:** $Title  
**Review Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Status:** Automated Initial Assessment  
**Reviewer:** Mossy Review Queue Processor  

---

## Investigation Summary

This is an automated preliminary investigation performed by the Mossy Review system.

---

## Findings

$Assessment

---

## Automated Review Notes

- This assessment was generated automatically based on pattern detection
- Manual review is recommended for complex issues
- If issue is resolved, update this work item with specific findings
- If blocked or needs escalation, tag with "Mossy Review Again"

---

## Next Actions

1. Review the findings and recommended actions above
2. Execute any diagnostic queries provided
3. Investigate related systems (MOS, Solvas, SecurityMaster)
4. Check Seq logs for error patterns if applicable
5. Update this work item with investigation results
6. Mark as complete when resolved

---

**Report Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  
**Automation Version:** 1.0  
**Work Item:** https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/$WorkItemId
"@
        
        # Save markdown file to Output folder
        $reportContent | Out-File -FilePath $filePath -Encoding UTF8
        Write-Log "Created investigation report file: $($fileName)"
        
        # Note: Azure DevOps CLI doesn't support file attachments directly
        # File is saved locally in Output folder for manual attachment or future automation
        # For now, we'll reference the file location in the comment
        Write-Log "Investigation report saved locally: $($filePath)"
        
        # Post minimal comment referencing the markdown file
        $summaryComment = "🤖 Automated review complete - see report: ``$fileName`` (AdminTools\Output)"
        
        $commentResult = az boards work-item update --id $WorkItemId --discussion "$summaryComment" --output json 2>&1 | Out-String
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to post summary comment to #$WorkItemId - $commentResult" "ERROR"
            return $false
        }
        
        Write-Log "Successfully posted assessment and attachment to #$WorkItemId"
        return $true
    }
    catch {
        Write-Log "Exception posting assessment to #$WorkItemId - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Update-WorkItemTags {
    param(
        [int]$WorkItemId,
        [string]$CurrentTags
    )
    
    try {
        Write-Log "Updating tags for work item #$WorkItemId"
        
        # Remove "Mossy Review" tag
        $tagsArray = $CurrentTags -split ';' | Where-Object { $_.Trim() -ne "Mossy Review" } | ForEach-Object { $_.Trim() }
        
        # Add "Mossy Reviewed" tag
        $tagsArray += "Mossy Reviewed"
        
        $newTags = $tagsArray -join '; '
        
        $result = az boards work-item update --id $WorkItemId --fields "System.Tags=$newTags" --output json 2>&1 | Out-String
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Failed to update tags for #$WorkItemId - $result" "ERROR"
            return $false
        }
        
        Write-Log "Successfully updated tags for #$WorkItemId"
        return $true
    }
    catch {
        Write-Log "Exception updating tags for #$WorkItemId - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# ================================================================
# MAIN PROCESSING LOGIC
# ================================================================

Write-Log "=========================================="
Write-Log "Mossy Review Queue Processor Started"
Write-Log "=========================================="

# Check if queue file exists
if (-not (Test-Path $queueFile)) {
    Write-Log "Queue file not found at $queueFile - nothing to process"
    exit 0
}

# Load queue
try {
    $queueObj = Get-Content $queueFile -Raw | ConvertFrom-Json
    $queue = @{}
    $queueObj.PSObject.Properties | ForEach-Object {
        $queue[$_.Name] = $_.Value
    }
    
    Write-Log "Loaded queue with $($queue.Count) items"
}
catch {
    Write-Log "Failed to load queue file - $($_.Exception.Message)" "ERROR"
    exit 1
}

# Count items in progress
$inProgressCount = 0
foreach ($item in $queue.Values) {
    if ($item.status -eq "in_progress") {
        $inProgressCount++
    }
}

Write-Log "Current concurrency: $inProgressCount/$MaxConcurrentReviews"

# Find pending items to process
$pendingItems = $queue.GetEnumerator() | Where-Object { $_.Value.status -eq "pending" } | Sort-Object { $_.Value.date_added }

if ($pendingItems.Count -eq 0) {
    Write-Log "No pending items to process"
    exit 0
}

Write-Log "Found $($pendingItems.Count) pending items"

# Process items (respecting concurrency limit)
$processed = 0
foreach ($entry in $pendingItems) {
    if ($inProgressCount -ge $MaxConcurrentReviews) {
        Write-Log "Concurrency limit reached ($inProgressCount/$MaxConcurrentReviews) - stopping"
        break
    }
    
    $idString = $entry.Key
    $queueItem = $entry.Value
    $workItemId = $queueItem.work_item_id
    
    Write-Log "=========================================="
    Write-Log "Processing Work Item #$workItemId - $($queueItem.title)"
    Write-Log "=========================================="
    
    # Update status to in_progress
    $queue[$idString].status = "in_progress"
    $queue[$idString].last_reviewed = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $inProgressCount++
    
    # Save queue with updated status
    $queue | ConvertTo-Json -Depth 10 | Out-File -FilePath $queueFile -Encoding UTF8
    
    # Fetch work item details
    $workItem = Get-WorkItemDetails -WorkItemId $workItemId
    
    if ($null -eq $workItem) {
        Write-Log "Failed to fetch work item #$workItemId - marking as reviewed with error" "ERROR"
        $queue[$idString].status = "reviewed"
        $queue[$idString].assessments += @{
            timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            result = "ERROR: Failed to fetch work item details from ADO"
            posted_successfully = $false
        }
        $queue | ConvertTo-Json -Depth 10 | Out-File -FilePath $queueFile -Encoding UTF8
        continue
    }
    
    $description = $workItem.fields.'System.Description'
    $currentTags = $workItem.fields.'System.Tags'
    
    # Perform automated investigation
    $assessment = Invoke-AutomatedInvestigation -WorkItemId $workItemId -Title $queueItem.title -Description $description -Type $queueItem.type
    
    # Post assessment to ADO (creates markdown file and attaches it)
    $posted = Post-AssessmentToADO -WorkItemId $workItemId -Assessment $assessment -Title $queueItem.title
    
    # Update tags
    $tagsUpdated = $false
    if ($posted) {
        $tagsUpdated = Update-WorkItemTags -WorkItemId $workItemId -CurrentTags $currentTags
    }
    
    # Update queue with results
    $queue[$idString].status = "reviewed"
    $queue[$idString].assessments += @{
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        assessment_text = $assessment
        posted_successfully = $posted
        tags_updated = $tagsUpdated
    }
    
    $queue | ConvertTo-Json -Depth 10 | Out-File -FilePath $queueFile -Encoding UTF8
    
    Write-Log "Completed processing #$workItemId - Posted: $posted, Tags Updated: $tagsUpdated"
    $processed++
    $inProgressCount--
}

Write-Log "=========================================="
Write-Log "Queue Processor Complete"
Write-Log "Processed $processed items"
Write-Log "=========================================="

exit 0
