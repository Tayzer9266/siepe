---
name: bulk-price-validation
version: 2.1
description: Investigation and validation procedure for bulk price exception reviews comparing vendor prices across multiple data sources (MOS, Solvas, SecurityMaster). Creates query result tabs for user VLOOKUP instead of direct cell filling. Enhanced with AI vision screenshot analysis and wiki procedure integration.
confidence_threshold: 0.75
applyTo: ["**/*"]
keywords:
  - price exception
  - bulk price validation
  - price data review
  - price mismatch
  - compare prices
  - vendor price comparison
  - Solvas price
  - SecurityMaster price
  - MarkIt price
  - position mark
  - bid price
---

# Bulk Price Validation Skill

## Version 2.1 Update (2026-07-28)

**NEW ENHANCEMENTS:**
- ✅ **AI Vision Screenshot Analysis** - Automatically analyzes Excel screenshots, error images, and visual evidence from ticket attachments
- ✅ **Wiki Integration** - Fetches standard operating procedures from Azure DevOps wiki for consistent investigation approach
- ✅ **Enhanced Reports** - Investigation reports now include screenshot analysis and wiki procedure compliance
- ✅ **Multi-Attachment Support** - Downloads and analyzes all ticket attachments (Excel + images)

## Version 2.0 Update

**IMPORTANT CHANGE:** This skill now creates **separate query result tabs** instead of filling validation columns directly. This approach is:
- ✅ **Faster** - One bulk query per database instead of hundreds of row-by-row queries (2-5 min vs 30+ min)
- ✅ **More reliable** - No Excel COM timeout or file locking issues
- ✅ **User-controlled** - Users complete VLOOKUP formulas at their own pace
- ✅ **Easier to debug** - Raw query data visible in dedicated tabs

**User action required:** After the agent creates query result tabs, users must apply VLOOKUP formulas to complete validation. Formula templates are provided.

## Purpose

This skill handles **bulk price exception review tasks** where multiple securities need price validation across different data sources. It automates the comparison of prices between:
- MOS Position Marks
- Vendor prices (MarkIt, ICE, etc.)
- Solvas portfolio prices
- SecurityMaster reference prices

## When to Use This Skill

### ✅ Use this skill when:
- Ticket contains an Excel attachment with multiple securities to review
- Task requires filling out comparison columns (e.g., "Position Mark Mismatch?", "Bid Price on MOS?", "Solvas Price Mismatch?")
- Investigating price discrepancies across multiple portfolios
- Client requests validation of vendor pricing data
- Ticket references "price exception", "price data review", or "confirm price data"
- Multiple instruments need the same set of validation checks

### ❌ Do NOT use this skill when:
- Investigating a **single CUSIP** with missing vendor pricing → Use `check-market-price` skill instead
- Ticket is about price weighting configuration
- Ticket is about asset type classification issues
- Task requires manual judgment or client communication

---

## Requirements Validation

**CRITICAL:** Before proceeding with investigation, validate that all required information is available in the ticket. If the skill confidence is adequate but requirements are missing, the agent MUST post missing requirements to the ticket discussion.

### Required Information Checklist

| Requirement | Location | Example | Status Check |
|-------------|----------|---------|-------------|
| **Ticket ID** | ADO URL/ID | 82309 | Required |
| **Excel Attachment** | Ticket attachments | price_exceptions_7-2.xlsx | Required |
| **Date Range** | Excel data or ticket description | 2026-06-03 to 2026-06-30 | Required |
| **Portfolio Names** | Excel "Portfolio" column | SY Cash Flow Fund II | Required |
| **Primary Identifiers** | Excel "Primary Identifier" column | LX189433, 03756ABS5 | Required |
| **Columns to Fill** | Excel headers or ticket instructions | Position Mark Mismatch?, Solvas Price Mismatch? | Required |

### Validation Script

```powershell
# Step 1: Fetch ticket details
$ticketId = <TICKET_ID>
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json

# Step 2: Check for attachments
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$excelAttachment = $attachments | Where-Object { $_.url -like "*.xlsx" -or $_.url -like "*.xls" }

# Step 3: Build missing requirements list
$missingReqs = @()

if (-not $excelAttachment) {
    $missingReqs += "- **Excel Attachment**: No Excel file (.xlsx/.xls) attached to ticket. Please attach the price exception file with securities to validate."
}

if ($ticket.fields.'System.Description' -notmatch 'date|portfolio|price') {
    $missingReqs += "- **Investigation Context**: Ticket description does not specify date range, portfolio names, or which price comparisons are needed. Please provide:\n  - Reference data date or date range\n  - Portfolio names (if specific to certain portfolios)\n  - Which columns need validation (e.g., Position Mark Mismatch, Solvas Price Mismatch, Bid Price on MOS)"
}

# Step 4: If requirements missing, post to discussion
if ($missingReqs.Count -gt 0) {
    $comment = @"
### ⚠️ Missing Requirements for Bulk Price Validation

This ticket was identified for bulk price validation, but the following required information is missing:

$($missingReqs -join "`n`n")

**Next Steps:**
1. Please provide the missing information above
2. Ensure the Excel file contains these columns:
   - RefDataSetDate or PriceDate
   - Portfolio
   - Primary Identifier (CUSIP/ISIN/LX ID)
   - InstID or Instrument
   - (MOS) PositionMark
   - (Sycamore) Bid or (Client) Bid
   - Any empty columns to fill (Position Mark Mismatch?, Solvas Price Mismatch?, etc.)

**Skill Status:** Investigation paused until requirements are complete.
"@

    # Post comment to ticket
    az boards work-item update --id $ticketId `
        --org "https://siepe.visualstudio.com/" `
        --discussion "$comment"
    
    Write-Host "❌ Requirements validation failed. Posted missing requirements to ticket #$ticketId discussion."
    exit 1
}

Write-Host "✅ All requirements present. Proceeding with investigation..."
```

### When to Skip Investigation

**STOP and post requirements** if:
- ✋ No Excel attachment found
- ✋ Excel file exists but has < 5 columns (likely wrong file)
- ✋ No "Primary Identifier" or "CUSIP" or "InstID" column found
- ✋ Ticket description provides no context (no date, portfolio, or objective mentioned)

**Proceed with investigation** if:
- ✅ Excel file attached with 8+ columns
- ✅ File contains identifier columns (Primary Identifier, CUSIP, ISIN, LX ID, or InstID)
- ✅ File contains price columns (Position Mark, Bid, vendor prices)
- ✅ Some empty columns exist (indicating validation is needed)

---

## Investigation Workflow

**⚡ PERFORMANCE TIP:** For 100+ rows, use bulk query optimization:
1. Read all Excel data into memory first (close Excel immediately)
2. Run ONE bulk query per database with all identifiers in IN clause
3. Store results in hashtable for fast lookups
4. Fill all columns from cached data
5. Write results back to Excel in one operation

This approach reduces execution time from 60+ minutes to 5-10 minutes and prevents Excel file corruption from keeping COM objects open too long.

### Step 1: Fetch Ticket Details and Download All Attachments (Excel + Images)

```powershell
# Get ticket information
$ticketId = <TICKET_ID>
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json

# Extract attachments
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }

# Download all attachments (Excel + images)
$token = (az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
$headers = @{ Authorization = "Bearer $token" }

$downloadedFiles = @{
    Excel = @()
    Images = @()
    Other = @()
}

foreach ($attachment in $attachments) {
    $attachmentUrl = $attachment.url
    $fileName = $attachmentUrl -replace '.*/([^/]+)$', '$1'
    $localPath = "C:\source\MD\AdminTools\Output\Attachments\$fileName"
    
    # Ensure directory exists
    $attachmentDir = Split-Path $localPath -Parent
    if (-not (Test-Path $attachmentDir)) {
        New-Item -ItemType Directory -Path $attachmentDir -Force | Out-Null
    }
    
    # Download attachment
    Invoke-RestMethod -Uri $attachmentUrl -Headers $headers -OutFile $localPath
    
    # Categorize by type
    if ($fileName -match '\.(xlsx|xls)$') {
        $downloadedFiles.Excel += $localPath
        Write-Host "✓ Downloaded Excel: $fileName" -ForegroundColor Green
    } elseif ($fileName -match '\.(png|jpg|jpeg|gif|webp|bmp)$') {
        $downloadedFiles.Images += $localPath
        Write-Host "✓ Downloaded Image: $fileName" -ForegroundColor Cyan
    } else {
        $downloadedFiles.Other += $localPath
        Write-Host "✓ Downloaded File: $fileName" -ForegroundColor Gray
    }
}

Write-Host "`nAttachment Summary:" -ForegroundColor Yellow
Write-Host "  Excel files: $($downloadedFiles.Excel.Count)" -ForegroundColor White
Write-Host "  Images: $($downloadedFiles.Images.Count)" -ForegroundColor White
Write-Host "  Other files: $($downloadedFiles.Other.Count)" -ForegroundColor White
```

**Extract from ticket JSON:**
- `fields.'System.Title'` - Ticket title
- `fields.'System.Description'` - Task description with instructions
- `relations` array where `rel = "AttachedFile"` - All attachment URLs (Excel, images, PDFs)

### Step 1A: Analyze Screenshot Attachments with AI Vision

**Before opening Excel, analyze any screenshot attachments to extract context:**

```powershell
# Analyze all image attachments
$screenshotAnalysis = @()

foreach ($imagePath in $downloadedFiles.Images) {
    Write-Host "`nAnalyzing screenshot: $(Split-Path $imagePath -Leaf)" -ForegroundColor Cyan
    
    # Use view_image tool (AI vision analysis)
    # Note: This would be called by the agent, not PowerShell
    # Agent pseudo-code:
    # $analysis = await viewImage($imagePath)
    
    # For PowerShell script, log image for agent analysis
    $screenshotAnalysis += @{
        FileName = Split-Path $imagePath -Leaf
        Path = $imagePath
        AnalysisNeeded = $true
        ExpectedContent = "Excel data, price comparisons, error messages, or validation results"
    }
}

# Agent will analyze images and extract:
# - Excel cell values visible in screenshots
# - Price comparison data
# - Highlighted cells or errors
# - Column headers and data ranges
# - Formula errors (#N/A, #VALUE!, #REF!)
# - Error messages or validation failures
```

**Screenshot Analysis Output (Generated by Agent):**

```markdown
## Screenshot Analysis

### Image 1: price_comparison_screenshot.png
**Type:** Excel Price Comparison  
**Visible Data:**
- Column F (Primary Identifier): 03756ABS5, 488930AL2, LX189433
- Column G (MOS PositionMark): 98.500, 97.250, 98.125
- Column H (Sycamore Bid): 98.450, 97.200, 93.500
- Column J (Position Mark Mismatch): Empty (needs filling)

**Highlighted Cells:** Row 4 highlighted in yellow (LX189433 shows large difference)

**Issue Identified:** Row 4 has significant price discrepancy (98.125 vs 93.500 = 4.625 difference)

### Image 2: solvas_query_error.png
**Type:** SQL Error Screenshot  
**Error Message:** "Invalid object name 'solvas_am.dbo.deal_facility_market_value'"  
**Database:** solvas_am  
**Context:** User attempting to run Solvas price query manually

**Issue Identified:** User may have connectivity issues to Solvas database or incorrect permissions
```

### Step 2: Analyze Excel Structure

**⚠️ CRITICAL:** Always kill all Excel processes BEFORE opening Excel files to prevent file locking and COM object conflicts:

```powershell
# Kill all Excel processes first
Get-Process -Name EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Now open Excel
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$workbook = $excel.Workbooks.Open("<EXCEL_PATH>")

# Check all sheets
for($i = 1; $i -le $workbook.Sheets.Count; $i++) {
    $sheetName = $workbook.Sheets.Item($i).Name
    Write-Host "Sheet $i: $sheetName"
}

# Common sheets:
# - "List" - Main data with securities to validate
# - "Queries" - SQL templates for investigation
```

**Typical column structure:**
1. `RefDataSetDate` - Reference data date
2. `PriceDate` - Price date
3. `Portfolio` - Portfolio name
4. `InstID` - Instrument ID (MOS internal)
5. `Instrument` - Full instrument description
6. `Primary Identifier` - CUSIP or LX identifier
7. `(MOS) PositionMark` - Price from MOS position
8. `(Sycamore) Bid` or `(Client) Bid` - Client's reported price
9. `Name` - Vendor name (e.g., "MarkIt Loan Pricing")
10. **`Position Mark Mismatch?`** - *To fill: Does MOS Position Mark differ from Sycamore Bid?*
11. **`Solvas Price Mismatch?`** - *To fill: Does Solvas price differ from Sycamore Bid?*
12. **`Bid Price on MOS?`** - *To fill: Does vendor bid price match Sycamore Bid? (Yes = matches, No = doesn't match or missing)*
13. **`Is Correct Price on SecM?`** - *To fill: Same as Column 12 - redundant check*

**CRITICAL Column Meanings:**
- **Column 10**: Position Mark vs Sycamore → "Yes" means mismatch exists
- **Column 11**: Solvas vs Sycamore → "Yes" means mismatch exists  
- **Column 12**: Vendor Bid vs Sycamore → **"Yes" means MATCH (prices agree), "No" means mismatch or missing**
- **Column 13**: Same as Column 12 (duplicate validation)

**CRITICAL:** All price comparisons are against **Sycamore Bid** (Column 8), NOT Position Mark (Column 7)

### Step 2A: Fetch Wiki Documentation for Standard Operating Procedures

**Before running queries, fetch the standard wiki procedure for price exception investigations:**

```powershell
# Fetch Price Exception wiki page
$wikiPath = "/2281/Price-Exception-Not-Matching-MarkIT-ICE-or-ICE-OR-NULL-Marks"
$wikiOutputPath = "C:\source\MD\AdminTools\Output\Wiki_PriceException_Procedures.md"

Write-Host "`nFetching wiki documentation..." -ForegroundColor Cyan

az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path $wikiPath `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | Out-File $wikiOutputPath -Encoding UTF8

if (Test-Path $wikiOutputPath) {
    Write-Host "✓ Wiki procedures downloaded: Wiki_PriceException_Procedures.md" -ForegroundColor Green
    
    # Read wiki content for investigation guidance
    $wikiContent = Get-Content $wikiOutputPath -Raw
    Write-Host "`nWiki Procedure Summary:" -ForegroundColor Yellow
    Write-Host "  Following standard operating procedure from Siepe Wiki" -ForegroundColor White
    Write-Host "  Reference: Price Exception - Not Matching MarkIT ICE or ICE OR NULL Marks" -ForegroundColor White
} else {
    Write-Host "⚠ Wiki page not found - proceeding with standard investigation" -ForegroundColor Yellow
}
```

**Wiki Integration Benefits:**
- Ensures consistent investigation approach across all price exception tickets
- Documents which standard procedures were followed
- Provides reference for manual steps that may be required
- Links investigation back to official documentation

### Step 3: Extract SQL Query Templates

Read the "Queries" sheet for provided SQL templates. Common queries include:

#### Query 1: Check Core Position Mark on Active Position (MOS Database)
```sql
-- Database: Core
SELECT DISTINCT PositionMark, p.refdatasetdate, p.EffFromDate, p.Tradedqty, p.Portfolio, ii.value 
FROM core.dbo.vposition p 
JOIN core.dbo.vinstidentifiercurrent ii ON ii.instid = p.instid
WHERE p.refdatasetdate >= '<START_DATE>'
AND p.Portfolio LIKE '%<PORTFOLIO_PATTERN>%'
AND ii.value = '<IDENTIFIER>'
ORDER BY p.refdatasetdate DESC
```
**Note:** Query all dates >= start date to cache results and avoid repeated queries

#### Query 2: Check Bid Price on MOS (Reference Database)
```sql
-- Database: Reference
SELECT TOP 100 BID, p.PriceDate, r.name as VendorName
FROM Reference.dbo.vinstpricecurrentraw p 
JOIN Reference.dbo.vRefDataSource r ON r.RefDataSourceID = p.RefDataSourceID
JOIN Reference.dbo.vInstIdentifierCurrent ii ON ii.instid = p.instid 
WHERE ii.value = '<IDENTIFIER>'
AND r.name NOT IN ('solvas portfolio')
AND p.PriceDate >= '<START_DATE>'
ORDER BY p.PriceDate ASC
```
**Note:** Query all dates >= start date to cache results. This returns vendor prices from MarkIt, ICE, etc.

#### Query 3: Check Solvas Price (Solvas Database)

**⚠️ CRITICAL - SYCAMORE PORTFOLIO SPECIFICS:**
- **ALL Sycamore securities are LOANS**, even if identifiers look like CUSIPs (e.g., 03756ABS5, 488930AL2)
- **ALWAYS use the loan query** (`deal_facility_market_value`) for Sycamore portfolios
- **DO NOT** use the bond query (`deal_issue_market_value`) for Sycamore - it will return no results

```sql
-- Database: solvas_am
-- Server: SOLVAS-SQL-D.mos.siepe.local,52156
-- For ALL Sycamore identifiers (including CUSIP-format ones)
SELECT d.pricing_type_1, e.deal_name, d.begin_date
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
  AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ('<IDENTIFIER_LIST>')  -- Works for both LX and CUSIP format
AND e.deal_name LIKE 'sy%'  -- Sycamore portfolios
AND d.begin_date >= '<START_DATE>'  -- Use >= not = to get earliest available
ORDER BY d.begin_date ASC
```

**CRITICAL Price Calculation Rules:**
1. Table column: `pricing_type_1` (NOT `unit_market_value` - that column doesn't exist in deal_facility_market_value)
2. Formula: **Price = pricing_type_1 × 100**
3. Always use the **first (earliest) date** >= the target date using ROW_NUMBER()
4. Example: If `pricing_type_1 = 0.97667`, then Price = 97.667

**Verification Example (LX189433 on 2026-06-03):**
```sql
-- Query returns: pricing_type_1 = 0.98125
-- Calculation: 0.98125 × 100 = 98.125
-- Sycamore Bid: 93.5
-- Difference: |98.125 - 93.5| = 4.625
-- Result: "Yes - Diff: 4.625" (genuine mismatch - Solvas has different price)
```

This confirms the validation is working correctly - Solvas data exists and shows a real price discrepancy between the portfolio system and what the client is reporting.

**Optimized Bulk Query (Use this for 100+ identifiers):**
```sql
-- Get first available price for each identifier
WITH RankedPrices AS (
    SELECT ev.lx_identifier, d.pricing_type_1, d.begin_date,
           ROW_NUMBER() OVER (PARTITION BY ev.lx_identifier ORDER BY d.begin_date ASC) as rn
    FROM solvas_am.dbo.deal_facility_market_value d
    JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
    JOIN solvas_am.dbo.Entity_Issue_view EV ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
        AND ev.entity_id = e.entity_id
    WHERE ev.lx_identifier IN ('LX189433', 'LX211038', '03756ABS5', '488930AL2')
    AND e.deal_name LIKE 'sy%'
    AND d.begin_date >= '2026-06-03'
)
SELECT lx_identifier, pricing_type_1
FROM RankedPrices
WHERE rn = 1
```

**Note:** For "Is Correct Price on SecM?" column, use the **same vendor price query (#2)** to check if the vendor bid matches Sycamore Bid. Do NOT use a separate tInstPrice query - use the filtered vinstpricecurrentraw results.

### Step 4: Create Column-by-Column Validation Script

**CRITICAL OPTIMIZATION:** Process **one column at a time** instead of caching all data in memory. This is faster because:
- Each column queries a different database
- You can fill and save immediately after each column completes
- Reduces memory usage and allows parallel database work
- Easier to debug and resume if interrupted

```powershell
# Fill-PriceExceptionColumns-ColumnByColumn.ps1
param(
    [string]$ExcelPath = "C:\source\MD\AdminTools\Output\<FILENAME>.xlsx",
    [string]$Server = "mos-sql-p.mos.siepe.local,52155",
    [int]$StartRow = 2,
    [int]$EndRow = <LAST_ROW>
)

# COLUMN-BY-COLUMN STRATEGY:
# Process columns in this order (each connects to different database):
#   1. Column 10: Position Mark Mismatch (simple calculation, no query)
#   2. Column 12: Bid Price on MOS (Reference database)
#   3. Column 13: Is Correct Price on SecM (uses same Reference query results)
#   4. Column 11: Solvas Price Mismatch (Solvas database via Reference)
#
# Benefits:
# - Can run in parallel if you split into 3 scripts (col 10, col 12-13, col 11)
# - Save progress after each column completes
# - Easier to troubleshoot which database/column has issues
```

**Key Logic:**

**Position Mark Mismatch:**
```powershell
# Compare MOS Position Mark (Column 7) to Sycamore Bid (Column 8)
$mosPriceNum = [decimal]$mosPrice
$sycamoreBidNum = [decimal]$sycamoreBid
$diff = [Math]::Abs($mosPriceNum - $sycamoreBidNum)
$posMarkMismatch = if($diff -gt 0.01) { "Yes" } else { "No" }
```

**Bid Price on MOS:**
```powershell
# Check if vendor bid price MATCHES Sycamore Bid (within 0.01 tolerance)
# Column 12 asks: "Bid Price on MOS?" meaning "Does MOS have the CORRECT bid?"
$cacheKey = "$identifier|$sqlDate"
if($vendorPriceCache.ContainsKey($cacheKey)) {
    $vendorBid = $vendorPriceCache[$cacheKey]
    $vendorBidNum = [decimal]$vendorBid
    $sycamoreBidNum = [decimal]$sycamoreBid
    $bidDiff = [Math]::Abs($vendorBidNum - $sycamoreBidNum)
    
    if($bidDiff -lt 0.01) {
        $bidPriceOnMOS = "Yes"  # Vendor price MATCHES Sycamore bid
    } else {
        $bidPriceOnMOS = "No"   # Vendor price EXISTS but DOESN'T MATCH
    }
} else {
    $bidPriceOnMOS = "No"  # No vendor data
}
```

**Correct Price on SecM (Duplicate of Column 12):**
```powershell
# Use the SAME vendor price from cached results to compare to Sycamore Bid
$cacheKey = "$identifier|$sqlDate"
if($vendorPriceCache.ContainsKey($cacheKey)) {
    $vendorBid = $vendorPriceCache[$cacheKey]
    $vendorBidNum = [decimal]$vendorBid
    $sycamoreBidNum = [decimal]$sycamoreBid
    $bidDiff = [Math]::Abs($vendorBidNum - $sycamoreBidNum)
    
    if($bidDiff -lt 0.01) {
        $correctPriceSecM = "Yes"
    } else {
        $correctPriceSecM = "No - Diff: $bidDiff"
    }
} else {
    $correctPriceSecM = "N/A"
}
```

**Solvas Price Mismatch:**
```powershell
# Check Solvas price from cached results and compare to Sycamore Bid
$cacheKey = "$identifier|$sqlDate"
if($solvasPriceCache.ContainsKey($cacheKey)) {
    $solvasPrice = $solvasPriceCache[$cacheKey]
    
    # CRITICAL: For loans, if pricing_type_1 exists, use pricing_type_1 * 100
    $solvasPriceNum = [decimal]$solvasPrice
    $sycamoreBidNum = [decimal]$sycamoreBid
    
    $solvasDiff = [Math]::Abs($solvasPriceNum - $sycamoreBidNum)
    $solvasMismatch = if($solvasDiff -lt 0.01) { "No" } else { "Yes - Diff: $solvasDiff" }
} else {
    $solvasMismatch = "No Solvas Data"
}
```

**Understanding "Solvas Price Mismatch" Results:**

The Column 11 results tell you whether Solvas portfolio prices match what the client (Sycamore) is reporting:

- **"No"** = Prices match (within 0.01) - Solvas and Sycamore agree
- **"Yes - Diff: X.XXX"** = **GENUINE MISMATCH** - Solvas has a different price than Sycamore's reported bid
  - This is the **expected result** for price exceptions - it confirms the discrepancy exists in Solvas too
  - Example: Solvas shows 98.125, Sycamore reports 93.5 → Diff: 4.625
  - This indicates the client may be using a different vendor or pricing methodology
- **"No Solvas Data"** = Security not found in Solvas or no price for that date

**IMPORTANT:** "Yes - Diff" does NOT mean an error - it means Solvas data exists but confirms the price discrepancy. This is useful information showing that:
1. The security exists in both systems
2. The price difference is real, not a data entry error
3. Investigation is needed to understand why Solvas and client have different prices

**Column 12 vs Column 13 - Important Distinction:**

- **Column 12 "Bid Price on MOS?"** = Does vendor bid price MATCH Sycamore bid?
  - "Yes" = Vendor price exists AND matches Sycamore (prices agree within 0.01)
  - "No" = Vendor price exists but doesn't match, OR no vendor data
- **Column 13 "Is Correct Price on SecM?"** = Same as Column 12 (redundant validation)
  - "Yes" = Vendor price matches Sycamore bid
  - "No - Diff: X.XXX" = Vendor price exists but doesn't match (shows difference)
  - "N/A" = No vendor data available

**Typical Results Pattern:**
- Column 10 (Position Mark): High % of "Yes" (many mismatches expected)
- Column 11 (Solvas): High % of "Yes - Diff" (confirms discrepancies exist in portfolio system)
- **Column 12 (Vendor Bid on MOS): HIGH % of "No"** (vendor prices don't match what client reports)
- **Column 13 (Correct Vendor Price): HIGH % of "No"** (same as Column 12)

This pattern confirms that the client is reporting prices that differ from both MOS position marks, Solvas portfolio prices, AND vendor reference prices.

### Step 5: Create Query Result Tabs for VLOOKUP

**NEW APPROACH:** Instead of filling cells row-by-row (which is slow and prone to Excel COM errors), create separate tabs with complete query results. The user can then use VLOOKUP formulas to match data by identifier.

**Benefits:**
- ✅ Much faster - one bulk query per database instead of hundreds of individual queries
- ✅ No Excel file locking issues - write results all at once
- ✅ User maintains control - can see raw query data and customize formulas
- ✅ Easier to debug - query results visible in dedicated tabs
- ✅ No COM object timeout issues from long-running processes

#### Phase 1: Read All Identifiers from Excel

```powershell
# Kill Excel processes first
Get-Process -Name EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Open Excel and read identifiers
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $true  # Show progress to user
$excel.DisplayAlerts = $false

$excelPath = ".\Output\<FILENAME>.xlsx"
$workbook = $excel.Workbooks.Open((Resolve-Path $excelPath).Path)
$mainSheet = $workbook.Worksheets.Item(1)  # Usually "List" sheet

# Read all identifiers and dates
$rows = $mainSheet.UsedRange.Rows.Count
$identifiers = @()
$minDate = $null

for ($r = 2; $r -le $rows; $r++) {
    $id = $mainSheet.Cells.Item($r, 6).Value2  # Column 6: Primary Identifier
    $dateStr = $mainSheet.Cells.Item($r, 2).Value2  # Column 2: PriceDate
    
    if ($id) { 
        $identifiers += "'$id'" 
        
        # Track minimum date for query optimization
        $date = [DateTime]::Parse($dateStr)
        if (-not $minDate -or $date -lt $minDate) {
            $minDate = $date
        }
    }
}

$idList = $identifiers -join ","
$startDate = $minDate.ToString("yyyy-MM-dd")

Write-Host "Found $($identifiers.Count) identifiers, min date: $startDate" -ForegroundColor Green
```

#### Phase 2: Run Bulk Database Queries

```powershell
# Import SQL module
Import-Module SqlServer -ErrorAction SilentlyContinue
if (-not (Get-Module SqlServer)) {
    Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser
    Import-Module SqlServer
}

# Query 1: MOS Position Marks and Vendor Prices
Write-Host "Querying MOS for position marks and vendor prices..." -ForegroundColor Cyan

$mosQuery = @"
SELECT 
    i.value as identifier,
    ISNULL(pm.position_mark, 0) as position_mark,
    ISNULL(ip.price, 0) as vendor_bid,
    r.name as vendor_name,
    ip.PriceDate,
    ISNULL(pw.price_weighting_percentage, 100) as price_weighting
FROM Reference.vInstIdentifierCurrent i
LEFT JOIN Core.vPositionMark pm ON i.inst_id = pm.inst_id
LEFT JOIN Reference.vInstPriceCurrentRaw ip ON i.inst_id = ip.inst_id 
    AND ip.data_source_name IN ('MarkIt', 'ICE')
    AND ip.data_set_name = 'Bid'
LEFT JOIN Reference.vRefDataSource r ON r.RefDataSourceID = ip.RefDataSourceID
LEFT JOIN Core.vPositionPriceWeightingActive pw ON i.inst_id = pw.inst_id
WHERE i.value IN ($idList)
    AND (ip.PriceDate >= '$startDate' OR ip.PriceDate IS NULL)
ORDER BY i.value, ip.PriceDate
"@

$mosResults = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" `
    -Database "Reference" `
    -Query $mosQuery `
    -TrustServerCertificate `
    -ErrorAction Stop

Write-Host "  Got $($mosResults.Count) MOS results" -ForegroundColor Green

# Query 2: Solvas Prices
Write-Host "Querying Solvas for loan prices..." -ForegroundColor Cyan

$solvasQuery = @"
SELECT 
    ev.lx_identifier as identifier,
    d.pricing_type_1 * 100 as solvas_price,
    d.begin_date as price_date,
    e.deal_name as portfolio
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ($idList)
    AND e.deal_name LIKE 'sy%'
    AND d.begin_date >= '$startDate'
ORDER BY ev.lx_identifier, d.begin_date
"@

$solvasResults = Invoke-Sqlcmd -ServerInstance "SOLVAS-SQL-D.mos.siepe.local,52156" `
    -Database "solvas_am" `
    -Query $solvasQuery `
    -TrustServerCertificate `
    -ErrorAction Stop

Write-Host "  Got $($solvasResults.Count) Solvas results" -ForegroundColor Green
```

#### Phase 3: Create Query Result Tabs

```powershell
Write-Host "Creating query result tabs in Excel..." -ForegroundColor Yellow

# Delete existing query tabs if present
$workbook.Worksheets | Where-Object {
    $_.Name -eq "MOS Query Results" -or $_.Name -eq "Solvas Query Results"
} | ForEach-Object { $_.Delete() }

# Create MOS Results Tab
$mosTab = $workbook.Worksheets.Add()
$mosTab.Name = "MOS Query Results"

# Headers
$mosTab.Cells.Item(1, 1).Value2 = "Identifier"
$mosTab.Cells.Item(1, 2).Value2 = "Position Mark"
$mosTab.Cells.Item(1, 3).Value2 = "Vendor Bid"
$mosTab.Cells.Item(1, 4).Value2 = "Vendor Name"
$mosTab.Cells.Item(1, 5).Value2 = "Price Date"
$mosTab.Cells.Item(1, 6).Value2 = "Price Weighting %"

# Format headers
$mosTab.Range("A1:F1").Interior.Color = 15773696  # Blue
$mosTab.Range("A1:F1").Font.Bold = $true

# Write data
$row = 2
foreach ($r in $mosResults) {
    $mosTab.Cells.Item($row, 1).Value2 = $r.identifier
    $mosTab.Cells.Item($row, 2).Value2 = if ($r.position_mark) { [decimal]$r.position_mark } else { "N/A" }
    $mosTab.Cells.Item($row, 3).Value2 = if ($r.vendor_bid) { [decimal]$r.vendor_bid } else { "N/A" }
    $mosTab.Cells.Item($row, 4).Value2 = if ($r.vendor_name) { $r.vendor_name } else { "N/A" }
    $mosTab.Cells.Item($row, 5).Value2 = if ($r.PriceDate) { $r.PriceDate.ToString("yyyy-MM-dd") } else { "N/A" }
    $mosTab.Cells.Item($row, 6).Value2 = if ($r.price_weighting) { $r.price_weighting } else { 100 }
    $row++
}

$mosTab.UsedRange.Columns.AutoFit() | Out-Null
Write-Host "  Created MOS Query Results tab with $($mosResults.Count) rows" -ForegroundColor Green

# Create Solvas Results Tab
$solvasTab = $workbook.Worksheets.Add()
$solvasTab.Name = "Solvas Query Results"

# Headers
$solvasTab.Cells.Item(1, 1).Value2 = "Identifier"
$solvasTab.Cells.Item(1, 2).Value2 = "Solvas Price"
$solvasTab.Cells.Item(1, 3).Value2 = "Price Date"
$solvasTab.Cells.Item(1, 4).Value2 = "Portfolio"

# Format headers
$solvasTab.Range("A1:D1").Interior.Color = 15773696  # Blue
$solvasTab.Range("A1:D1").Font.Bold = $true

# Write data
$row = 2
foreach ($r in $solvasResults) {
    $solvasTab.Cells.Item($row, 1).Value2 = $r.identifier
    $solvasTab.Cells.Item($row, 2).Value2 = if ($r.solvas_price) { [decimal]$r.solvas_price } else { "N/A" }
    $solvasTab.Cells.Item($row, 3).Value2 = if ($r.price_date) { $r.price_date.ToString("yyyy-MM-dd") } else { "N/A" }
    $solvasTab.Cells.Item($row, 4).Value2 = if ($r.portfolio) { $r.portfolio } else { "N/A" }
    $row++
}

$solvasTab.UsedRange.Columns.AutoFit() | Out-Null
Write-Host "  Created Solvas Query Results tab with $($solvasResults.Count) rows" -ForegroundColor Green

# Save workbook
Write-Host "Saving workbook..." -ForegroundColor Yellow
$workbook.Save()

Write-Host "✅ Query result tabs created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "USER ACTION REQUIRED:" -ForegroundColor Cyan
Write-Host "Use VLOOKUP formulas in the main sheet to match data from the query result tabs." -ForegroundColor Yellow
Write-Host ""
Write-Host "Example VLOOKUP formulas:" -ForegroundColor White
Write-Host "  Position Mark Mismatch: =IF(ABS(G2-H2)>0.01,\"Yes\",\"No\")" -ForegroundColor Gray
Write-Host "  Vendor Bid: =VLOOKUP(F2,'MOS Query Results'!A:C,3,FALSE)" -ForegroundColor Gray
Write-Host "  Solvas Price: =VLOOKUP(F2,'Solvas Query Results'!A:B,2,FALSE)" -ForegroundColor Gray
```

**Time estimate:** 2-5 minutes total (vs. 26-37 minutes with row-by-row approach)

#### Phase 4: Add VLOOKUP Helper Tab (Optional)

Create a helper sheet with pre-built VLOOKUP formulas that the user can copy:

```powershell
$helperTab = $workbook.Worksheets.Add()
$helperTab.Name = "VLOOKUP Formulas"

$helperTab.Cells.Item(1, 1).Value2 = "Column"
$helperTab.Cells.Item(1, 2).Value2 = "Formula"
$helperTab.Cells.Item(1, 3).Value2 = "Description"

$helperTab.Cells.Item(2, 1).Value2 = "Position Mark Mismatch (Col 10)"
$helperTab.Cells.Item(2, 2).Value2 = "=IF(ABS(G2-H2)>0.01,""Yes"",""No"")"
$helperTab.Cells.Item(2, 3).Value2 = "Compare Position Mark to Sycamore Bid"

$helperTab.Cells.Item(3, 1).Value2 = "Vendor Bid (Col 12)"
$helperTab.Cells.Item(3, 2).Value2 = "=IFERROR(VLOOKUP(F2,'MOS Query Results'!A:C,3,FALSE),""No Data"")"
$helperTab.Cells.Item(3, 3).Value2 = "Lookup vendor bid price from MOS"

$helperTab.Cells.Item(4, 1).Value2 = "Solvas Price Mismatch (Col 11)"
$helperTab.Cells.Item(4, 2).Value2 = "=IFERROR(IF(ABS(VLOOKUP(F2,'Solvas Query Results'!A:B,2,FALSE)-H2)>0.01,""Yes - Diff: "" & ROUND(ABS(VLOOKUP(F2,'Solvas Query Results'!A:B,2,FALSE)-H2),3),""No""),""No Solvas Data"")"
$helperTab.Cells.Item(4, 3).Value2 = "Compare Solvas price to Sycamore Bid"

$helperTab.UsedRange.Columns.AutoFit() | Out-Null
```

**Total execution time:** 2-5 minutes for all queries + tab creation

### Step 6: User Completes VLOOKUP Matching

**After creating query result tabs, instruct the user:**

```markdown
## User Action Required

The database query results have been exported to two new tabs in your Excel file:

1. **MOS Query Results** - Contains position marks, vendor bid prices, and price weightings for all identifiers
2. **Solvas Query Results** - Contains Solvas portfolio prices for all identifiers

### How to Complete the Validation

Use VLOOKUP formulas to match data from the query tabs to your main data sheet:

**Column 10: Position Mark Mismatch**
```excel
=IF(ABS(G2-H2)>0.01,"Yes","No")
```
Compares Position Mark (column G) to Sycamore Bid (column H)

**Column 12: Bid Price on MOS**
```excel
=IFERROR(IF(ABS(VLOOKUP(F2,'MOS Query Results'!A:C,3,FALSE)-H2)<0.01,"Yes","No"),"No")
```
Checks if vendor bid from MOS matches Sycamore Bid

**Column 11: Solvas Price Mismatch**
```excel
=IFERROR(IF(ABS(VLOOKUP(F2,'Solvas Query Results'!A:B,2,FALSE)-H2)>0.01,"Yes - Diff: " & ROUND(ABS(VLOOKUP(F2,'Solvas Query Results'!A:B,2,FALSE)-H2),3),"No"),"No Solvas Data")
```
Compares Solvas price to Sycamore Bid

Copy these formulas down for all rows to complete the validation.
```

### Step 7: Analyze Query Results

After user completes VLOOKUPs, analyze patterns in the query result tabs:

```powershell
# Analyze MOS Query Results tab
$mosTab = $workbook.Worksheets.Item("MOS Query Results")
$mosRows = $mosTab.UsedRange.Rows.Count

$vendorPricesFound = 0
$vendorPricesMissing = 0

for ($r = 2; $r -le $mosRows; $r++) {
    $vendorBid = $mosTab.Cells.Item($r, 3).Value2
    if ($vendorBid -and $vendorBid -ne "N/A") {
        $vendorPricesFound++
    } else {
        $vendorPricesMissing++
    }
}

Write-Host "MOS Analysis:" -ForegroundColor Cyan
Write-Host "  Total identifiers: $($mosRows - 1)" -ForegroundColor White
Write-Host "  Vendor prices found: $vendorPricesFound" -ForegroundColor Green
Write-Host "  Vendor prices missing: $vendorPricesMissing" -ForegroundColor Yellow

# Analyze Solvas Query Results tab
$solvasTab = $workbook.Worksheets.Item("Solvas Query Results")
$solvasRows = $solvasTab.UsedRange.Rows.Count

Write-Host "Solvas Analysis:" -ForegroundColor Cyan
Write-Host "  Total Solvas prices: $($solvasRows - 1)" -ForegroundColor White
```

### Step 8: Generate Enhanced Investigation Report with Screenshot Analysis

Create markdown report: `AdminTools/Output/BulkPriceValidation_<TICKET_ID>_<TIMESTAMP>.md`

```markdown
# Bulk Price Validation Report
**Ticket:** #<TICKET_ID>  
**Client:** <CLIENT_NAME>  
**Date:** <CURRENT_DATE>  
**Analyst:** MOS Support Agent

---

## Screenshot Analysis

**Attachments Analyzed:** <IMAGE_COUNT> images

### Image 1: price_comparison_screenshot.png
**Type:** Excel Price Comparison  
**Visible Data:**
- Identifiers: 03756ABS5, 488930AL2, LX189433
- MOS Prices: 98.500, 97.250, 98.125
- Sycamore Bids: 98.450, 97.200, 93.500
- Validation Columns: Empty (investigation needed)

**Key Observations:**
- Row 4 (LX189433) shows significant discrepancy: MOS 98.125 vs Sycamore 93.500 = 4.625 difference
- Rows 2-3 show minor differences (<0.10) likely acceptable timing variances
- Screenshot confirms validation columns need to be filled

### Image 2: solvas_error_screenshot.png
**Type:** SQL Error
**Error:** "Invalid object name 'solvas_am.dbo.deal_facility_market_value'"
**Context:** User attempted manual Solvas query

**Issue:** Database connectivity or permissions problem - investigation will verify Solvas access

---

## Wiki Reference

**Standard Operating Procedure:** [Price Exception - Not Matching MarkIT ICE or ICE OR NULL Marks](https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/2281/Price-Exception-Not-Matching-MarkIT-ICE-or-ICE-OR-NULL-Marks)

**Procedure Steps from Wiki:**
1. ✅ Check vendor subscription status
2. ✅ Verify identifier mapping
3. ✅ Review price weighting configuration
4. ✅ Validate price source hierarchy
5. ✅ Run bulk validation queries
6. ⏳ User completes VLOOKUP formulas

**Investigation Status:** Following steps 1-5 as documented in wiki

---

## Summary

Created query result tabs for **<TOTAL>** securities across **<PORTFOLIO_COUNT>** portfolios for date range **<START_DATE>** to **<END_DATE>**.

### Query Execution Results

- **MOS Query Results Tab:** Created with <MOS_COUNT> rows
  - Position marks: Available for <PM_COUNT> securities
  - Vendor prices: Available for <VENDOR_COUNT> securities
  - Price weightings: Configured for <WEIGHTING_COUNT> securities

- **Solvas Query Results Tab:** Created with <SOLVAS_COUNT> rows
  - Solvas prices: Available for <SOLVAS_COUNT> securities
  - Missing Solvas data: <MISSING_COUNT> securities

### Data Coverage Summary

| Data Source | Securities Found | Coverage % |
|-------------|-----------------|------------|
| Position Marks | <PM_COUNT> | <PM_PCT>% |
| Vendor Prices | <VENDOR_COUNT> | <VENDOR_PCT>% |
| Solvas Prices | <SOLVAS_COUNT> | <SOLVAS_PCT>% |

## User Action Required

**IMPORTANT:** Validation columns have NOT been filled automatically. User must complete VLOOKUP formulas to match query data to the main sheet.

### VLOOKUP Formula Guide

Copy these formulas to the corresponding columns in your main data sheet:

**Column 10: Position Mark Mismatch**
```
=IF(ABS(G2-H2)>0.01,"Yes","No")
```

**Column 12: Bid Price on MOS**
```
=IFERROR(IF(ABS(VLOOKUP(F2,'MOS Query Results'!A:C,3,FALSE)-H2)<0.01,"Yes","No"),"No")
```

**Column 11: Solvas Price Mismatch**
```
=IFERROR(IF(ABS(VLOOKUP(F2,'Solvas Query Results'!A:B,2,FALSE)-H2)>0.01,"Yes - Diff: " & ROUND(ABS(VLOOKUP(F2,'Solvas Query Results'!A:B,2,FALSE)-H2),3),"No"),"No Solvas Data")
```

  - Includes screenshot analysis
  - References wiki procedures
  - Documents standard compliance

- **Wiki Documentation:** `Wiki_PriceException_Procedures.md`
  - Standard operating procedure reference
  - Downloaded from Siepe Wiki

- **Screenshot Analysis:** Embedded in investigation report
  - Excel data extraction
  - Error message identification
  - Visual evidence documentation
## Data Quality Observations

### Vendor Price Availability

**Identifiers with vendor pricing:** <COUNT>  
**Identifiers without vendor pricing:** <COUNT>

Identifiers without vendor prices may require:
- Manual vendor lookup
- SecurityMaster integration check
- Vendor subscription verification

### Solvas Integration Status

**Data available:** <COUNT> securities  
**No Solvas data:** <COUNT> securities

Missing Solvas data may indicate:
- Securities not yet loaded to Solvas
- Identifier mapping issues between MOS and Solvas
- Portfolio not configured in Solvas system

## Investigation Workflow

1. ✅ **Query Execution:** Completed - MOS and Solvas query result tabs created
2. ⏳ **VLOOKUP Completion:** User action required - apply formulas to validation columns
3. ⏳ **Pattern Analysis:** After VLOOKUPs complete, analyze mismatch patterns
4. ⏳ **Client Communication:** Report findings and request clarification on pricing methodology

## Next Steps

1. User applies VLOOKUP formulas to complete validation columns
2. Agent analyzes completed results to identify patterns
3. Generate final summary with mismatch categories and recommendations
4. Communicate findings to client with specific examples

## Files Generated

- **Updated Excel File:** `<FILENAME>.xlsx`
  - New tab: "MOS Query Results" (<MOS_COUNT> rows)
  - New tab: "Solvas Query Results" (<SOLVAS_COUNT> rows)
  - Optional: "VLOOKUP Formulas" helper tab
  
- **Investigation Report:** `BulkPriceValidation_<TICKET_ID>_<TIMESTAMP>.md`

## Recommendations

1. **Investigate large price differences** (>$2.00 difference between MOS and vendor)
2. **Review identifiers without vendor pricing** - Check if securities are properly mapped
3. **Validate Solvas data gaps** - Coordiquery result tabs created)
- Raw SQL results: `<QUERY_RESULTS>.csv` (if applicable)
- Screenshot images: `<IMAGE_FILES>` (analyzed and documented above)
- Wiki procedures: `Wiki_PriceException_Procedures.md`

---

## Screenshot Evidence

**Original screenshots from ticket preserved as evidence:**

1. `price_comparison_screenshot.png` - Excel validation workbook showing discrepancies
2. `solvas_error_screenshot.png` - Database error encountered by user

**Analysis Summary:**
- Screenshot 1 confirms LX189433 has significant price mismatch (4.625 difference)
- Screenshot 2 indicates Solvas database access issue - verified connectivity during investigation
- Visual evidence supports investigation findings

---

## Investigation Compliance

✅ **Wiki Procedure Followed:** Price Exception - Not Matching MarkIT ICE  
✅ **Screenshots Analyzed:** 2 images processed with AI vision  
✅ **Database Queries Executed:** MOS and Solvas bulk queries completed  
✅ **Quality Gates Passed:** All validation data collected  
✅ **User Action Required:** VLOOKUP formulas provided for completion
ches found

## Next Steps

- [ ] Upload completed Excel file to ADO ticket
- [ ] Coordinate with <TEAM> on identified issues
- [ ] Schedule follow-up for unresolved price exceptions
- [ ] Document any required configuration changes

## Attachments

- Updated Excel file: `<FILENAME>.xlsx` (all columns filled)
- Raw SQL results: `<QUERY_RESULTS>.csv` (if applicable)
```

### Step 8: Update ADO Ticket

#### 8A: Post Discussion Comments

```powershell
$ticketId = <TICKET_ID>
$org = "https://siepe.visualstudio.com/"

# Post brief comment referencing the attached report and Excel
az boards work-item update --id $ticketId --org $org --discussion "🔍 Price validation complete - query tabs and detailed report attached"
```

#### 8B: Append to Description Field

```powershell
.\append-to-description.ps1 -ticketId <TICKET_ID> -reportPath "<REPORT_MD_PATH>"
```

#### 8C: Attach Updated Excel File with Query Tabs

```powershell
# Upload Excel file with query result tabs
$token = (az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
$headers = @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/octet-stream" }
$fileBytes = [System.IO.File]::ReadAllBytes("<EXCEL_PATH>")

$uploadUrl = "https://siepe.visualstudio.com/4717395b-e9a6-4e06-82b2-b7608c52f3f7/_apis/wit/attachments?fileName=<FILENAME>_QueryResults.xlsx&api-version=7.0"
$uploadResponse = Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headers -Body $fileBytes

# Link attachment to work item
$attachmentUrl = $uploadResponse.url
$patchUrl = "https://siepe.visualstudio.com/4717395b-e9a6-4e06-82b2-b7608c52f3f7/_apis/wit/workitems/<TICKET_ID>?api-version=7.0"
$patchBody = "[{`"op`":`"add`",`"path`":`"/relations/-`",`"value`":{`"rel`":`"AttachedFile`",`"url`":`"$attachmentUrl`",`"attributes`":{`"comment`":`"Query result tabs created - User must complete VLOOKUP formulas`"}}}]"

Invoke-RestMethod -Uri $patchUrl -Method Patch -Headers @{ "Authorization" = "Bearer $token"; "Content-Type" = "application/json-patch+json" } -Body $patchBody
```

#### 8D: Attach Markdown Report

```powershell
.\attach-to-ado.ps1 -ticketId <TICKET_ID> -filePath "<REPORT_MD_PATH>"
```

---

## Common Patterns and Issues

### Pattern 1: Systematic Price Differences (Timing)

**Symptoms:**
- Small differences ($0.01-$0.50) across many securities
- Same vendor (e.g., all MarkIt prices)
- Consistent pattern (MOS always higher/lower)

**Root Cause:** 
- Price timing differences (MOS rolled price vs. client EOD price)
- Different price sources within same vendor (bid vs. mid vs. ask)

**Resolution:**
- Document timing differences in report
- No action needed if < $0.50 difference
- Coordinate price snapshot timing with client

### Pattern 2: Missing Vendor Prices

**Symptoms:**
- "Bid Price on MOS?" = No
- Position mark exists but no vendor price

**Root Cause:**
- Security not subscribed in MarkIt/vendor feed
- Identifier mapping issue (wrong LX or CUSIP)
- New security not yet in vendor database

**Resolution:**
1. Check identifier is correct and active
2. Verify security is in MarkIt subscription
3. Request vendor add security to feed if needed
4. Use fallback pricing methodology per client agreement

### Pattern 3: Solvas Data Gaps

**Symptoms:**
- "Solvas Price Mismatch?" = No Solvas Data
- Multiple securities for same client missing

**Root Cause:**
- Securities not loaded to Solvas yet
- Portfolio not configured in Solvas system
- Identifier mapping between MOS and Solvas

**Resolution:**
1. Check `Entity_Issue_view` for identifier mappings
2. Coordinate with Solvas data team to load missing securities
3. Update entity/deal mappings if needed

### Pattern 4: Large Price Discrepancies (>$5.00)

**Symptoms:**
- Position Mark Mismatch = Yes
- Large difference between MOS and SecurityMaster

**Root Cause:**
- Stale price (price not updated)
- Wrong security mapped (identifier linked to wrong bond/loan)
- Corporate action not reflected (prepayment, default, etc.)

**Resolution:**
1. Verify identifier mapping is correct
2. Check for recent corporate actions
3. Manually validate price with vendor
4. Update price in MOS or request vendor correction

---

## Database References

### MOS Production Server
- **Server:** `mos-sql-p.mos.siepe.local,52155`
- **Databases Used:**
  - **Core** - Position marks and holdings
  - **Reference** - Vendor prices, SecurityMaster prices, Solvas data
- **Authentication:** Windows Integrated Security

### Database-Specific Queries

**Core Database** (`-d "Core"`)
- Position marks: `core.dbo.vposition`
- Instrument identifiers: `core.dbo.vinstidentifiercurrent`

**Reference Database** (`-d "Reference"`)
- Vendor prices: `Reference.dbo.vinstpricecurrentraw` + `Reference.dbo.vRefDataSource`
- SecurityMaster prices: `Reference.dbo.tInstPrice` + `Reference.dbo.vinstidentifier`
- Solvas loan prices: `solvas_am.dbo.deal_facility_market_value` (accessible via Reference connection)
- Solvas bond prices: `solvas_am.dbo.deal_issue_market_value` (accessible via Reference connection)
- Entity mappings: `solvas_am.dbo.Entity_Issue_view`

**IMPORTANT:** When querying Solvas tables, connect to Reference database (`-d "Reference"`), then use fully-qualified names like `solvas_am.dbo.deal_facility_market_value`

---

## Generate and Attach Investigation Report

After completing the validation analysis, generate a comprehensive markdown report and attach it to the ADO ticket for review.

### Step 1: Generate Markdown Report

Create a markdown file summarizing the validation results:

**File naming:** `BulkPriceValidation_{TicketNumber}_{Date}.md`

**Template:**
```markdown
# Bulk Price Validation Report - TASK #{TicketNumber}

**Generated:** {CurrentDateTime}  
**Client/Portfolio:** {ClientName}  
**Total Securities:** {Count}  
**Analyst:** {Username}

---

## Summary

This report validates pricing data for {Count} securities across {PortfolioCount} portfolios.

**Validation Columns Completed:**
- ✅ Column 7: Position Marks (MOS)
- ✅ Column 8: Vendor Price Available
- ✅ Column 9: Active Price Weighting Config
- ✅ Column 10: SecurityMaster Price
- ✅ Column 11: Solvas Price Mismatch
- ✅ Columns 12-13: Price Source Configuration

---

## Key Findings

### Missing Vendor Prices
**Count:** {MissingVendorCount}  
**Action Needed:** {Recommendation - e.g., "No action - expected for illiquid securities"}

### Price Mismatches (Solvas vs. Vendor)
**Count:** {MismatchCount}  
**Details:**
| Identifier | Vendor Price | Solvas Price | Difference |
|------------|--------------|--------------|------------|
| {CUSIP1} | {Price1} | {SolvasPrice1} | {Diff1} |
| ... |

**Action Needed:** {Recommendation - e.g., "Apply price overrides" or "Investigate vendor feed"}

### Missing Price Weighting Config
**Count:** {MissingConfigCount}  
**Action Needed:** Configure price weighting rules for affected portfolios/instruments

### Asset Type Misclassifications
**Count:** {MisclassCount}  
**Details:**
| Identifier | Current Type | Expected Type | Issue |
|------------|--------------|---------------|-------|
| {CUSIP1} | {Type1} | {ExpectedType1} | {Description} |

**Action Needed:** Update instrument asset type classification

---

## Validation Results by Category

### 1. Vendor Price Coverage
- **Total Securities:** {Total}
- **With Vendor Price:** {WithPrice} ({Percentage}%)
- **Missing Vendor Price:** {MissingPrice} ({Percentage}%)

### 2. Price Weighting Configuration
- **Configured:** {ConfiguredCount} ({Percentage}%)
- **Missing Config:** {MissingCount} ({Percentage}%)

### 3. Solvas Price Alignment
- **Matching:** {MatchCount} ({Percentage}%)
- **Mismatched:** {MismatchCount} ({Percentage}%)
- **No Solvas Data:** {NoDataCount} ({Percentage}%)

### 4. SecurityMaster Availability
- **Available:** {SMAvailable} ({Percentage}%)
- **Not in SM:** {NotInSM} ({Percentage}%)

---

## Recommended Actions

### High Priority
1. {Action 1 - e.g., "Apply price overrides for 15 mismatched securities"}
2. {Action 2 - e.g., "Configure price weighting for 3 portfolios"}

### Medium Priority
1. {Action 3}
2. {Action 4}

### Low Priority / Monitoring
1. {Action 5}

---

## SQL Queries for Follow-Up

### Apply Price Overrides
{Include generated SQL if applicable, or reference to price-overrides skill}

### Configure Price Weighting
{Include INSERT statements if applicable}

### Update Asset Type
{Include UPDATE statements if applicable}

---

## Attachments

- **Completed Excel File:** {FileName}
- **PowerShell Script:** `Fill-PriceExceptionColumns.ps1`
- **SQL Results:** (if applicable)

---

## Report Metadata

**Ticket:** TASK #{TicketNumber}  
**Generated By:** {AgentName}  
**Timestamp:** {ISO8601DateTime}  
**Excel Rows Processed:** {RowCount}  
**Total Queries Executed:** {QueryCount}

---

**End of Report**
```

### Step 2: Save Markdown File

```powershell
# Define file path
$ticketId = {TicketNumber}
$date = Get-Date -Format "yyyyMMdd"
$fileName = "BulkPriceValidation_$ticketId_$date.md"
$outputPath = "C:\source\MD\AdminTools\Output\$fileName"

# Write markdown content to file
$markdownContent | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ Validation report generated: $fileName"
```

### Step 3: Attach to ADO Ticket

```powershell
# Upload markdown report as attachment
az boards work-item relation add `
    --id $ticketId `
    --relation-type AttachedFile `
    --target-id (az boards attachment upload --file-path $outputPath --output tsv) `
    --org "https://siepe.visualstudio.com/" `
    --output json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Report attached to TASK #$ticketId"
}

# Also attach the completed Excel file
$excelPath = "C:\source\MD\AdminTools\Output\{ExcelFileName}.xlsx"
az boards work-item relation add `
    --id $ticketId `
    --relation-type AttachedFile `
    --target-id (az boards attachment upload --file-path $excelPath --output tsv) `
    --org "https://siepe.visualstudio.com/" `
    --output json
```

### Step 4: Post Summary Comment

```powershell
# Post brief comment referencing the detailed markdown report
$comment = "🔍 Bulk price validation complete - see attached report for findings and recommendations"

az boards work-item update --id $ticketId `
    --org "https://siepe.visualstudio.com/" `
    --discussion "$comment"

Write-Host "✅ Brief summary posted to TASK #$ticketId"
```

---

## Related Skills

- **check-market-price** - For single CUSIP missing vendor pricing investigations
- **price-weighting-config** - For configuring vendor price selection rules
- **asset-type-classification** - For fixing incorrect asset type assignments

---

## Skill Metadata

**Taxonomy Category:** Data Validation / Price Exception Review

**Estimated Time:**
- Small dataset (<100 securities): 30-60 minutes
- Medium dataset (100-500 securities): 1-2 hours
- Large dataset (>500 securities): 2-4 hours

**Prerequisites:**
- Access to MOS Production database
- Azure CLI configured with Siepe organization
- PowerShell with Excel COM automation
- Understanding of price weighting concepts

**Output Artifacts:**
1. PowerShell validation script (`Fill-PriceExceptionColumns.ps1`)
2. Completed Excel file with all validation columns filled
3. Markdown investigation report
4. ADO ticket updated with findings and recommendations

---

## Version History

**v1.0 (2026-07-02)**
- Initial skill creation
- Documented workflow for Ticket #82309 (Sycamore price data review)
- 622 securities validated across 9 portfolios
- Automated column filling via PowerShell script
- SQL query templates for MOS, Solvas, SecurityMaster

## Version 2.0 Summary

### Key Changes from Version 1.4

**OLD APPROACH (v1.4):**
- ? Row-by-row or column-by-column database queries
- ? Direct Excel cell filling via COM automation
- ? Execution time: 26-37 minutes for 600+ rows
- ? Prone to Excel file locking and timeout issues
- ? Difficult to debug when queries fail

**NEW APPROACH (v2.0):**
- ? **Single bulk query per database** (one for MOS, one for Solvas)
- ? **Create dedicated query result tabs** instead of filling cells
- ? **User completes VLOOKUP formulas** at their own pace
- ? **Execution time: 2-5 minutes** (10x faster)
- ? **No Excel COM timeout issues** - all data written at once
- ? **Easier to debug** - raw query data visible in dedicated tabs
- ? **Always kill Excel processes first** to prevent file conflicts

### Critical Best Practices (v2.0)

1. **Always kill Excel before opening:**
   ```powershell
   Get-Process -Name EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force
   Start-Sleep -Seconds 2
   ```

2. **Create query result tabs, not filled cells:**
   - "MOS Query Results" tab with all MOS data
   - "Solvas Query Results" tab with all Solvas data
   - "VLOOKUP Formulas" helper tab (optional)

3. **Provide VLOOKUP templates for user:**
   - Position Mark Mismatch: Direct calculation formula
   - Vendor Bid match: VLOOKUP to MOS Query Results
   - Solvas Price match: VLOOKUP to Solvas Query Results

4. **User completes validation:**
   - Agent creates query tabs and provides formulas
   - User applies VLOOKUPs to complete validation columns
   - User reviews results and identifies patterns

### When to Use This Skill

? **Use this skill for:**
- Bulk price validation tasks with 10+ securities
- Excel attachments requiring multiple validation columns
- Price comparison across MOS, Solvas, and vendor sources
- Tasks where database queries can answer the validation questions

? **Do NOT use for:**
- Single security investigations (use check-market-price skill)
- Tasks requiring manual judgment or client communication
- Cases where validation logic is unclear or custom per row
