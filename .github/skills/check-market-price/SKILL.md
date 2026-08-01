---(e.g. Task 82115)
skill_name: check-market-price 
title: Market Price Analysis & Vendor Source Investigation
description: Diagnose market price discrepancies by analyzing vendor data sources, price weighting configuration, and executed pricing procedures for client portfolios. Enhanced with AI vision screenshot analysis and wiki procedure integration. Connects to MOS production database to research pricing issues and generates formatted analysis for ADO ticket updates.
version: 1.5
database: mos-prod
output_format: markdown
last_updated: 2026-07-26
changelog: "v1.5 - Added screenshot analysis, wiki integration, enhanced investigation reports with visual evidence; v1.4 - Added Step 6-10: Extended workflows including position mark validation, Solvas price checks, Security Master queries, post-resolution procedures (dataset refresh, bid price validation), SFTP folder locations, and reference links; v1.3 - Added Step 0: Finding Instrument Identifiers using Enhanced Pricing Report when CUSIP/ISIN not provided in ticket, with strategies for checking first CUSIP or multiple CUSIPs by asset type; v1.2 - Added Scenario 4: Incorrect Asset Type Classification; v1.1 - Updated queries to match actual MOS production database schema"
apply_to:
  - pattern: "**/*"
    when_user_mentions:
      - "market price"
      - "pricing discrepancy"
      - "wrong price"
      - "markit"
      - "LSEG"
      - "ICE"
      - "price source"
      - "vendor pricing"
      - "enhanced pricing report"
      - "price weighting"
---

# Market Price Analysis Skill

**⚠️ Schema Note:** Queries updated 2026-07-01 to reflect actual MOS production database structure. If queries fail, check for environment-specific table/column name variations.

## Purpose
Investigate and diagnose market price discrepancies by analyzing:
- Available vendor price sources (Markit, LSEG/Refinitiv, ICE)
- Price weighting configuration and priority rules
- Instrument asset type classification
- Executed pricing procedures and actual prices used
- Root cause identification and resolution recommendations

## When to Use This Skill
- Client questions about pricing differences between reports
- Investigation of why a specific vendor price was/wasn't used
- Price source configuration analysis
- Troubleshooting "wrong price" support tickets
- Enhanced Pricing Report daily review follow-ups
- Tickets mentioning pricing issues without specific CUSIP/ISIN (use Step 0 first)

---

## Required Inputs

Extract the following from the ADO ticket:

1. **Company Name** (e.g., "Aristotle Pacific Capital", "Brotherhood Mutual")
   - Found in: Ticket title, description, or client name
   
2. **Price Date** (e.g., "2026-06-30")
   - Found in: Ticket title, description, or report date
   - **Always research the day BEFORE the reported date** (PriorDate = Date - 1 day)
   
3. **Instrument Identifier** (CUSIP, ISIN, or LoanX ID)
   - Found in: Ticket description, attached Excel files (e.g., EnhancedPriceHistoryReport.xlsx)
   - Examples: "008911BD0", "US008911BD04", "LX189433"
   - **If missing:** See "Step 0: Finding Instrument Identifiers" below

---

## Requirements Validation

**CRITICAL:** Before proceeding with investigation, validate that all required information is available in the ticket. If the skill confidence is adequate but requirements are missing, the agent MUST post missing requirements to the ticket discussion.

### Required Information Checklist

| Requirement | Location | Example | Status Check |
|-------------|----------|---------|--------------|
| **Company/Client Name** | Ticket title or description | Aristotle Pacific Capital | Required |
| **Price Date** | Ticket description or report | 2026-06-30 | Required |
| **Instrument Identifier** | Ticket description or attachment | 008911BD0, LX189433 | Conditional* |
| **Issue Description** | Ticket description | Wrong vendor used, price mismatch | Required |

*If no identifier provided, agent can use Enhanced Pricing Report (Step 0) to retrieve all instruments for the client.

### Validation Script

```powershell
# Step 1: Fetch ticket details
$ticketId = <TICKET_ID>
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json

$description = $ticket.fields.'System.Description'
$title = $ticket.fields.'System.Title'

# Step 2: Check for required information
$missingReqs = @()

# Check for company/client name
if ($title -notmatch '([A-Z][a-z]+\s){1,4}(Capital|Fund|Mutual|Investment|Trust|Management)' -and 
    $description -notmatch '(company|client|fund|portfolio):\s*\w+') {
    $missingReqs += "- **Company/Client Name**: Which client is affected? (e.g., Aristotle Pacific Capital, Brotherhood Mutual, Citi Trustee)"
}

# Check for price date
if ($description -notmatch '\d{4}-\d{2}-\d{2}' -and $description -notmatch '(date|dated|as of):\s*\w+') {
    $missingReqs += "- **Price Date**: What date is the pricing issue for? (format: YYYY-MM-DD, e.g., 2026-06-30)"
}

# Check for issue description
if ($description -notmatch '(price|pricing|vendor|markit|LSEG|ICE|wrong|mismatch|discrepancy)') {
    $missingReqs += "- **Issue Description**: What is the pricing problem? (e.g., wrong vendor used, price not found, price mismatch between reports)"
}

# Identifier is optional if we can use Enhanced Pricing Report
$hasIdentifier = $description -match '([A-Z0-9]{8,12}|LX\d+)' -or 
                 $description -match '(CUSIP|ISIN|LoanX|identifier):\s*[A-Z0-9]+'

if (-not $hasIdentifier) {
    Write-Host "ℹ️ No specific instrument identifier found. Will use Enhanced Pricing Report to retrieve all client instruments."
}

# Step 3: If requirements missing, post to discussion
if ($missingReqs.Count -gt 0) {
    $comment = @"
### ⚠️ Missing Requirements for Market Price Investigation

This ticket was identified for market price analysis, but the following required information is missing:

$($missingReqs -join "`n`n")

**Optional but Helpful Information:**
- Specific CUSIP, ISIN, or LoanX ID (if available)
- Expected vendor source (e.g., "should use Markit")
- Report name where issue was observed (e.g., Enhanced Pricing Report)
- Screenshot or attachment showing the price discrepancy

**Investigation Capabilities:**
- If no specific instrument identifier is provided, agent can retrieve all instruments for the client on the specified date
- Agent will analyze vendor sources, price weighting configuration, and executed pricing procedures
- Agent will identify root cause and provide resolution recommendations

**Next Steps:**
Please provide the missing required information above so the investigation can proceed.

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

# Step 1A: Download and Analyze Screenshot Attachments

$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

Write-Host "\nAnalyzing $($imageFiles.Count) screenshot(s)..." -ForegroundColor Cyan

# Agent will use view_image tool to analyze screenshots and extract:
# - Price comparison data visible in Excel/reports
# - Vendor price values shown in screenshots
# - Error messages or UI dialogs
# - Highlighted cells or discrepancies
# - Date stamps and identifiers visible in images

# Step 1B: Fetch Wiki Documentation

$wikiPath = "/2281/Price-Exception-Not-Matching-MarkIT-ICE-or-ICE-OR-NULL-Marks"
$wikiOutput = "C:\source\MD\AdminTools\Output\Wiki_PriceException.md"

Write-Host "Fetching wiki procedure documentation..." -ForegroundColor Cyan

az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path $wikiPath `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | Out-File $wikiOutput -Encoding UTF8

if (Test-Path $wikiOutput) {
    Write-Host "✓ Wiki procedures loaded for investigation compliance" -ForegroundColor Green
}
```

### When to Skip Investigation

**STOP and post requirements** if:
- 🛑 No company/client name identifiable
- 🛑 No price date mentioned
- 🛑 Issue description is vague (e.g., "check prices" with no context)
- 🛑 Ticket is about configuration changes (not investigation)

**Proceed with investigation** if:
- ✅ Company/client name clearly identified
- ✅ Price date specified (exact date or date range)
- ✅ Issue description mentions pricing problem
- ✅ Either identifier provided OR agent can use Enhanced Pricing Report to retrieve instruments

---

## Step 0: Finding Instrument Identifiers (When Not Provided)

**Use Case:** Ticket mentions pricing issues but doesn't specify CUSIP/ISIN/LoanX ID

**Solution:** Use the Enhanced Pricing Report to retrieve all instruments for the client on the relevant date.

### Query to Execute

**Procedure:** `Report.pEnhancedPricingReport`  
**Database:** Core  
**Purpose:** Generate complete position pricing report with all identifiers

**PowerShell Command:**
```powershell
# Run Enhanced Pricing Report for specific date (T-1)
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" `
  -Q "EXEC Report.pEnhancedPricingReport @RefDataSetDate = '{PriorDate}', @FundID = NULL" `
  -o "C:\temp\EnhancedPricingReport_{Date}.csv" -W -s ","
```

**Parameters:**
- `@RefDataSetDate` = **One day before** the reported issue date (T-1)
- `@FundID` = NULL (returns all funds) or specific comma-separated fund IDs
- `@Login` = Defaults to current Windows user (automatic permissions)
- `@OutputType` = 'Report' (default, full report with all fields)

**Alternative: SQL Query**
```sql
-- Execute directly in SSMS or sqlcmd
EXEC Report.pEnhancedPricingReport 
    @RefDataSetDate = '2026-06-30',  -- T-1 date
    @FundID = NULL,                   -- All funds
    @OutputType = 'Report';
```

### Report Output Fields

The report returns comprehensive position data including:
- **Fund Name** / **Portfolio Name**
- **Issuer Name** / **Asset Name** / **Asset Type**
- **CUSIP** / **LoanXID** / **ISIN** / **LIN** / **Bloomberg ID** ← Identifiers
- **Par Amount** (Settled/Traded)
- **Market Value** (Settled/Traded)
- **Mark Price** / **Bid** / **Ask** / **Mid**
- **Mark Price Source** (vendor used)
- **Mark Price Depth**
- **MarkDate** / **EndDate**
- **Moody's** / **S&P** / **Fitch** ratings

### Investigation Strategy

#### Option A: Check First Returned Instrument (Quick Analysis)

**When to Use:** 
- Ticket mentions general pricing discrepancies without specifics
- Quick validation needed
- Single asset type in portfolio

**Approach:**
1. Run Enhanced Pricing Report for T-1 date
2. **Check the FIRST CUSIP that appears** in the result set
3. Use this CUSIP for Steps 1-5 of the pricing analysis
4. If this resolves the issue, document and close
5. If not, proceed to Option B

**Example:**
```powershell
# Get first CUSIP from report
$result = sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" `
  -Q "EXEC Report.pEnhancedPricingReport @RefDataSetDate = '2026-06-30'" -W -h -1 -s ","
$firstCUSIP = ($result | Select-Object -Skip 1 | Select-Object -First 1).Split(',')[14]  # CUSIP column
Write-Host "Analyzing first CUSIP: $firstCUSIP"
```

#### Option B: Check Multiple Instruments by Asset Type (Thorough Analysis)

**When to Use:**
- First CUSIP analysis doesn't reveal root cause
- Portfolio has mixed asset types (Bonds, Loans, ABS, Equity)
- Ticket suggests asset type-specific pricing rules might be involved
- Need comprehensive validation across instrument types

**Approach:**
1. Run Enhanced Pricing Report for T-1 date
2. **Identify unique Asset Types** in the result set
3. **Select one CUSIP per unique Asset Type**
4. Run pricing analysis (Steps 1-5) for each selected CUSIP
5. Compare results to identify asset type-specific patterns

**SQL Query to Find Representative CUSIPs:**
```sql
-- Get one CUSIP per Asset Type from Enhanced Pricing Report
WITH PricingData AS (
    SELECT 
        [Inst|Asset Type] AS AssetType,
        [Inst|CUSIP] AS CUSIP,
        [Inst|Asset Name] AS AssetName,
        [Prices|Mark Price Source] AS PriceSource,
        ROW_NUMBER() OVER (PARTITION BY [Inst|Asset Type] ORDER BY [Inst|Asset Name]) AS RowNum
    FROM OPENQUERY([mos-sql-p], 
        'EXEC Core.Report.pEnhancedPricingReport @RefDataSetDate = ''2026-06-30''')
)
SELECT AssetType, CUSIP, AssetName, PriceSource
FROM PricingData
WHERE RowNum = 1  -- First instrument per asset type
ORDER BY AssetType;
```

**Manual Filter Alternative:**
```powershell
# Export to CSV and manually identify representative CUSIPs
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" `
  -Q "EXEC Report.pEnhancedPricingReport @RefDataSetDate = '2026-06-30'" `
  -o "EnhancedPricing.csv" -W -s ","

# Then filter in Excel:
# 1. Sort by Asset Type column
# 2. Pick first CUSIP for each unique Asset Type (Bond, Loan, ABS, Equity)
# 3. Note the Mark Price Source for each
```

**Example Analysis Output:**
| Asset Type | CUSIP | Asset Name | Mark Price Source | Analysis Status |
|------------|-------|------------|-------------------|-----------------|
| Bond | 008911BD0 | ABC Corp Bond | Aristotle\|LSEG | ✅ Correct source (weight 750) |
| Loan | 54321XYZ1 | DEF Term Loan | Siepe-SecurityMaster\|Price\|MarkIt | ✅ Correct source (weight 750) |
| ABS | 98765ABC7 | GHI Auto ABS | Siepe-SecurityMaster\|Price\|MarkIt | ✅ Correct source (weight 750) |
| Equity | 11111EQT9 | JKL Common Stock | Aristotle\|ICE | ⚠️ Should be LSEG (weight 750), ICE used (weight 800) |

**Pattern Identification:**
- If **all asset types** show same issue → Likely global price weighting misconfiguration
- If **one asset type** has issue → Asset type-specific rule missing or incorrect
- If **random CUSIPs** affected → Instrument-level data quality issue

### When to Use Each Approach

| Scenario | Recommended Approach | Rationale |
|----------|---------------------|-----------|
| "Enhanced Pricing Report shows wrong prices" | Option B (Multiple) | Need to validate across all asset types |
| "CUSIP not specified, quick check needed" | Option A (First) | Fast validation, single data point |
| "Pricing issue started yesterday" | Option A (First) | Quick comparison vs prior day |
| "Some instruments priced wrong, not all" | Option B (Multiple) | Pattern detection across types |
| "New vendor source added" | Option B (Multiple) | Verify configuration for all types |

### Proceed to Next Steps

Once you have identified CUSIP(s) to investigate:
- **Single CUSIP (Option A):** Continue to Step 1 with selected identifier
- **Multiple CUSIPs (Option B):** Repeat Steps 1-5 for each CUSIP, then aggregate findings

---

## Database Connection

**Server:** `mos-sql-p.mos.siepe.local,52155`  
**Database:** `Core` (with joins to `Reference`)  
**Authentication:** Windows Integrated Security  

**PowerShell Connection Example:**
```powershell
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" -Q "[SQL QUERY]"
```

---

## Investigation Steps

### Step 1: Identify Company ID

**Purpose:** Convert company name to CompanyID for configuration lookups

**Query:**
```sql
SELECT CompanyID, Name 
FROM Employee.vCompany 
WHERE Name LIKE '%{CompanyName}%'
ORDER BY Name;
```

**Parameters:**
- `{CompanyName}` = Partial company name from ticket (e.g., "Aristotle")

**Expected Output:**
| CompanyID | Name |
|-----------|------|
| 500000006 | Aristotle Pacific Capital |

**Action:** Record the `CompanyID` for use in subsequent queries.

**Tip:** If multiple companies match, select the one mentioned in the ticket context or ask for clarification.

---

### Step 2: Check Available Vendor Prices

**Purpose:** Identify which vendor price sources have data for this instrument on the price date

**Simplified Query (Recommended - Based on Production Use):**
```sql
SELECT TOP 20
    p.PriceDate, 
    r.Name AS RefDataSource, 
    p.Price, 
    p.Bid, 
    p.Ask,
    p.CreatedDate
FROM Reference.dbo.vinstpricecurrentraw p 
JOIN Reference.dbo.vRefDataSource r ON r.RefDataSourceID = p.RefDataSourceID
JOIN Reference.dbo.vInstIdentifierCurrent ii ON ii.instid = p.instid 
WHERE ii.value = '{Identifier}'
  AND r.name NOT IN ('solvas portfolio') 
ORDER BY pricedate DESC;
```

**Parameters:**
- `{Identifier}` = CUSIP/ISIN/LoanX ID from ticket
- Results ordered by date descending (most recent first)

**Expected Output:**
| PriceDate | RefDataSource | Price | Bid | Ask | CreatedDate |
|-----------|---------------|-------|-----|-----|-------------|
| 2026-07-01 | Aristotle\|LSEG | 99.9297000 | 99.8672000 | 99.9922000 | 2026-07-01 06:15:23 |
| 2026-06-30 | Aristotle\|LSEG | 99.9574181 | 99.8949181 | 100.0199181 | 2026-06-30 06:15:12 |
| 2026-06-30 | Siepe-SecurityMaster\|Price\|MarkIt | 100.2087100 | 100.1898000 | 100.2277000 | 2026-06-30 07:22:45 |

**Analysis Points:**
- ✅ **Multiple sources available** = Price weighting determines which is used
- ⚠️ **Single source only** = No alternatives if this source is down
- ❌ **No sources available** = Vendor data feed issue or instrument not covered
- 🔄 **PriceRollover- prefix** = Stale price carried forward (non-business day or feed issue)

**Alternative: Filter by Specific Date**
```sql
-- If you want only a specific date
SELECT 
    p.PriceDate, 
    r.Name AS RefDataSource, 
    p.Price, 
    p.Bid, 
    p.Ask
FROM Reference.dbo.vinstpricecurrentraw p 
JOIN Reference.dbo.vRefDataSource r ON r.RefDataSourceID = p.RefDataSourceID
JOIN Reference.dbo.vInstIdentifierCurrent ii ON ii.instid = p.instid 
WHERE ii.value = '{Identifier}'
  AND p.PriceDate = '{PriorDate}'
  AND r.name NOT IN ('solvas portfolio') 
ORDER BY r.Name;
```

---

### Step 3: Review Price Weighting Configuration

**Purpose:** Understand which vendor sources have priority for this company

**Query:**
```sql
SELECT 
    DS.Name AS RefDataSource,
    PW.Weight,
    PW.Level1CriteriaType,
    PW.Level1CriteriaID,
    PW.Level2CriteriaType,
    PW.Level2CriteriaValue,
    PW.PriceType,
    PW.EffFromDate,
    PW.EffThruDate
FROM Core.dbo.vPositionPriceWeightingActive PW
JOIN Reference.dbo.vRefDataSourceRaw DS ON DS.RefDataSourceID = PW.ReferenceRefDataSourceID
WHERE PW.CompanyID = {CompanyID}
  AND PW.EffFromDate <= '{PriorDate}'
  AND PW.EffThruDate > '{PriorDate}'
ORDER BY PW.Weight ASC, PW.Level2CriteriaType, PW.Level2CriteriaValue;
```

**Parameters:**
- `{CompanyID}` = From Step 1
- `{PriorDate}` = Price date minus 1 day

**Expected Output:**
| RefDataSource | Weight | Level2CriteriaType | Level2CriteriaValue | PriceType |
|---------------|--------|--------------------|---------------------|-----------|
| MOS Ops Price Override | 500 | None | None | Price |
| Aristotle\|ICE | 750 | WSOAssetType | Bond | Price |
| Aristotle\|ICE | 750 | WSOAssetType | Equity | Price |
| Siepe-SecurityMaster\|Price\|MarkIt | 750 | WSOAssetType | ABS | Price |
| Siepe-SecurityMaster\|Price\|MarkIt | 750 | WSOAssetType | Loan | Price |
| Aristotle\|LSEG | 800 | None | None | Price |

**Key Points:**
- **Lower Weight = Higher Priority** (e.g., 500 > 750 > 800)
- **Level2CriteriaValue** filters by asset type (Bond, Equity, ABS, Loan, etc.)
- **"None"** = Applies to all instruments (catch-all rule)

---

### Step 4: Determine Instrument Asset Type

**Purpose:** Identify which price weighting rules apply based on asset classification

**Option A: Pattern Match from Instrument Name (Recommended - Fastest)**

Based on instrument name from Step 2, identify asset type:
- **"CONSUMER LOAN", "LOAN", "CLO", "TERM LOAN"** → Asset Type: **Loan**
- **"ABS", "AUTO", "CREDIT CARD", "STUDENT LOAN"** → Asset Type: **ABS**
- **"BOND", "CORP", "NOTE", "DEBENTURE"** → Asset Type: **Bond**
- **"EQUITY", "COMMON", "PREFERRED"** → Asset Type: **Equity**

**Option B: Query Price Weighting Rules (If name unclear)**

```sql
-- Check which weighting rules have Level2CriteriaValue filters
SELECT 
    DS.Name AS RefDataSource,
    PW.Weight,
    PW.Level2CriteriaValue AS AssetTypeFilter
FROM Core.dbo.vPositionPriceWeightingActive PW
JOIN Reference.dbo.vRefDataSourceRaw DS ON DS.RefDataSourceID = PW.ReferenceRefDataSourceID
WHERE PW.CompanyID = {CompanyID}
  AND PW.Level2CriteriaType = 'WSOAssetType'
  AND PW.Level2CriteriaValue IS NOT NULL
  AND PW.EffFromDate <= '{PriorDate}'
  AND PW.EffThruDate > '{PriorDate}'
ORDER BY PW.Weight ASC;
```

Then match instrument characteristics to available filters.

**Option C: Direct Instrument Query (May Fail on Some Systems)**

```sql
-- WARNING: Table/column names may vary by environment
SELECT TOP 1
    I.Name AS InstName,
    I.InstID
FROM Reference.dbo.vInst I
JOIN Reference.dbo.vInstIdentifierCurrent II ON II.InstID = I.InstID
WHERE II.Value = '{Identifier}';
```

Then infer asset type from instrument name patterns.

**Action:** 
1. Identify asset type using Option A (name pattern matching)
2. Compare against `Level2CriteriaValue` filters from Step 3
3. Determine which price weighting rules apply to this instrument

---

### Step 5: Execute Price Export Procedure

**Purpose:** Run the actual pricing procedure to see what price was selected

**PowerShell Command (Recommended):**
```powershell
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" `
  -Q "EXEC Core.Report.pSolvasExportPriceEntity @CompanyID = {CompanyID}, @PriceDate = '{PriorDate}';" `
  -W -h -1 -s "," | findstr /i "{Identifier}"
```

**Parameters:**
- `{CompanyID}` = From Step 1
- `{PriorDate}` = Price date (NOT minus 1 day for this procedure)
- `{Identifier}` = CUSIP/ISIN to filter results

**Expected Output:**
```
ARISTOTLE_FUNDS_TRUST_ARISTOTLE_ULTRA_SHORT_OME_FUND,83408EAA1,CUSIP,06/30/2026,06/30/2026,99.9574181030000000,99.8949181030000000,99.957418103,100.0199181030000000
```

**Key Fields (comma-separated):**
1. Portfolio/Entity Code
2. Identifier (CUSIP/ISIN)
3. Identifier Type
4. Price Date
5. Evaluation Date
6. **Price** (main evaluated price)
7. Bid
8. Mid
9. Ask

**Alternative: Direct SQL Execution**
```sql
-- Note: Procedure parameters may vary by environment
-- Common parameters: @CompanyID, @PriceDate
-- Check procedure definition if this fails
EXEC Core.Report.pSolvasExportPriceEntity  
    @CompanyID = {CompanyID},
    @PriceDate = '{PriorDate}';
```

**Verification Steps:**
1. Compare price in output with vendor prices from Step 2
2. Identify which vendor source was used (match price value)
3. Confirm this matches expected priority from Step 3
4. Check if price is consistent across all portfolios

---

## Root Cause Analysis

### Common Scenarios

#### Scenario 1: Price from Unexpected Source

**Symptoms:** 
- Client expected Markit price but LSEG price was used
- Multiple vendor sources available but "wrong" one selected

**Root Cause Analysis:**
1. Compare available sources (Step 2) with price weighting rules (Step 3)
2. Check if preferred source has matching `Level2CriteriaValue` for asset type (Step 4)
3. Identify which rule matched based on:
   - Lowest weight
   - Asset type filter match
   - "None" catch-all rules

**Example Finding:**
```
❌ ISSUE IDENTIFIED:
- Instrument: Bond (WSOAssetType = "Bond")
- Available Prices:
  • Aristotle|ICE: NO PRICE AVAILABLE
  • Aristotle|LSEG: 100.26095 (weight 800, None filter)
  • Markit: 100.20871 (weight 750, ABS/Loan filter only)
  
- Markit rule (weight 750) only applies to ABS and Loan asset types
- Bond instruments fall through to Aristotle|LSEG (weight 800)
```

**Resolution:**
```sql
-- Add price weighting rule for Markit on Bond instruments
INSERT INTO Core.dbo.tPositionPriceWeighting (
    ReferenceRefDataSourceID,
    Level1CriteriaType,
    Level1CriteriaID,
    Weight,
    CompanyID,
    Level2CriteriaType,
    Level2CriteriaValue,
    PriceType,
    EffFromDate,
    EffThruDate,
    RefRecStatusID
)
SELECT 
    1000000123, -- Siepe-SecurityMaster|Price|MarkIt
    'None',
    99999999,
    750,
    {CompanyID},
    'WSOAssetType',
    'Bond',
    'Price',
    '1900-01-01',
    '9999-01-01',
    1;
```

---

#### Scenario 2: No Price Available

**Symptoms:**
- Instrument shows NULL or missing price in reports

**Root Cause Analysis:**
1. Check if ANY vendor sources have prices (Step 2)
2. If no sources: Vendor data feed issue or instrument not covered
3. If sources exist but not selected: Price weighting configuration issue

**Possible Causes:**
- Vendor data feed delayed or failed
- Instrument not in vendor's coverage universe
- CUSIP/ISIN mapping incorrect
- Price weighting excludes all available sources

---

#### Scenario 3: Stale Price (Rollover)

**Symptoms:**
- Price appears unchanged from previous day
- Source shows "PriceRollover-*" prefix

**Root Cause Analysis:**
1. Check `RefDataSource` field in Step 2 results
2. Sources with "PriceRollover-" prefix indicate rolled-over prices

**Explanation:**
- System keeps most recent price until new price arrives
- Normal for weekends, holidays, or illiquid securities
- Abnormal if vendor typically provides daily prices

---

#### Scenario 4: Incorrect Asset Type Classification

**Symptoms:**
- Wrong vendor price source was used despite "correct" price weighting configuration
- Price differs significantly from expected vendor source
- Asset type-specific price weighting rules not being applied

**Root Cause Analysis:**
1. Verify the instrument's actual asset type classification (Step 4)
2. Compare with what asset type the instrument **should** be classified as
3. Check if price weighting rules exist for the correct asset type (Step 3)
4. Identify if the wrong asset type caused a different price weighting rule to be applied

**Example Finding:**
```
❌ ISSUE IDENTIFIED:
- Instrument: "ABC CONSUMER LOAN 2026"
- Current Asset Type: "ABS" ❌ (INCORRECT)
- Should Be: "Loan" ✓
- Price Weighting Rules:
  • Markit (weight 750, Loan filter) - NOT APPLIED due to wrong asset type
  • LSEG (weight 800, None filter) - APPLIED (fallback rule)
  
Result: LSEG price used instead of preferred Markit price for Loans
```

**Why This Happens:**
- Asset type misclassification in the Reference database
- Instrument name patterns don't match standard classifications
- Manual overrides or data migration issues
- New instrument types not properly categorized

**Resolution:**
1. **Verify correct asset type** based on instrument characteristics:
   - Loan: Consumer loans, term loans, revolvers, CLOs
   - ABS: Asset-backed securities, auto receivables, credit cards
   - Bond: Corporate bonds, notes, debentures
   - Equity: Common stock, preferred shares

2. **Update instrument classification** in Reference database (if incorrect):
```sql
-- Example: Update instrument asset type
-- NOTE: Verify table/column names for your environment
-- Contact Reference Data team for production changes
UPDATE Reference.dbo.tInst
SET WSOAssetType = 'Loan'  -- Correct asset type
WHERE InstID = {InstID};
```

3. **Verify price weighting rules exist** for the corrected asset type
4. **Re-run pricing** for affected dates to apply correct prices

**⚠️ Important:**
- **Always verify the asset type first** when investigating pricing discrepancies
- Incorrect asset type is a **common root cause** of unexpected vendor price selection
- Asset type changes may affect historical pricing - coordinate with client before corrections

---

## Extended Validation & Resolution Workflows

### Step 6: Check Position Mark on Core (Active Positions)

**Purpose:** Verify the actual marked price on active positions in the Core database

**Query:**
```sql
-- Check position marks for specific security across portfolios
SELECT DISTINCT 
    PositionMark, 
    p.refdatasetdate, 
    p.EffFromDate, 
    p.Tradedqty, 
    p.Portfolio, 
    ii.value 
FROM Core.dbo.vposition p 
JOIN Core.dbo.vinstidentifiercurrent ii ON ii.instid = p.instid
WHERE p.refdatasetdate = '{PriorDate}'
  AND p.Portfolio LIKE '%{PortfolioPattern}%'
  AND ii.value = '{Identifier}'
ORDER BY p.refdatasetdate DESC;
```

**Parameters:**
- `{PriorDate}` = Price date (e.g., '2026-06-04')
- `{PortfolioPattern}` = Portfolio name filter (e.g., 'sy' for Sycamore portfolios)
- `{Identifier}` = CUSIP/ISIN/LoanX ID

**Use Case:**
- Verify if the price was successfully applied to positions
- Check price consistency across multiple portfolios
- Validate historical position pricing after corrections

**Expected Output:**
| PositionMark | refdatasetdate | EffFromDate | Tradedqty | Portfolio | value |
|--------------|----------------|-------------|-----------|-----------|-------|
| 100.2087100 | 2026-06-04 | 2025-03-15 | 1000000 | Sycamore CLO I | 04045F162 |
| 100.2087100 | 2026-06-04 | 2025-03-15 | 500000 | Sycamore CLO II | 04045F162 |

---

### Step 7: Check Solvas Prices (Direct Database Queries)

**Purpose:** Validate prices stored in the Solvas_AM database for loans and bonds

#### 7a. Check Loan Prices (deal_facility_market_value)

**Query:**
```sql
-- Check loan pricing in Solvas
SELECT 
    e.deal_name, 
    d.* 
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ('{Identifier}')
  AND e.deal_name LIKE '{DealPattern}%'
  AND begin_date >= '{StartDate}'
ORDER BY begin_date DESC;
```

**Parameters:**
- `{Identifier}` = LoanX ID (e.g., 'LX189433', '04045F162')
- `{DealPattern}` = Portfolio/entity pattern (e.g., 'sy' for Sycamore)
- `{StartDate}` = Earliest date to check (e.g., '2025-04-01')

**Expected Output:**
| deal_name | entity_id | facility_id | begin_date | end_date | market_value_indent | pricing_type_1 |
|-----------|-----------|-------------|------------|----------|---------------------|----------------|
| Sycamore CLO I MOS | 295 | 11234 | 2026-06-30 | NULL | 100.20871 | 1 |

#### 7b. Check Bond Prices (deal_issue_market_value)

**Query by CUSIP:**
```sql
-- Check bond pricing in Solvas by CUSIP
SELECT 
    e.deal_name,
    d.*
FROM solvas_am.dbo.deal_issue_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE ev.cusip_number IN ('{CUSIP}')
  AND e.deal_name LIKE '{DealPattern}%'
  AND begin_date >= '{StartDate}'
ORDER BY begin_date DESC;
```

**Query by Entity ID (for bulk validation):**
```sql
-- Check bond pricing by entity_id for multiple portfolios
SELECT TOP 100
    e.deal_name,
    i.CUSIP_number,
    i.issue_name,
    dmv.begin_date,
    dmv.market_value_indent
FROM Solvas_AM.dbo.deal_issue_market_value dmv
JOIN Solvas_AM.dbo.entity e ON dmv.entity_id = e.entity_id
JOIN Solvas_AM.dbo.issue i ON dmv.issue_id = i.issue_id
WHERE dmv.entity_id IN ({EntityIDList})  -- e.g., 234, 235, 257, 419
  AND dmv.begin_date = '{PriceDate}'
ORDER BY e.deal_name, i.CUSIP_number;
```

**Use Case:**
- Validate prices pushed to Solvas after pSolvasExportPriceEntity execution
- Compare Solvas prices with MOS Reference prices
- Identify discrepancies between front office (MOS) and back office (Solvas)

---

### Step 7c: Investigate Missing Identifiers / Portfolio Exclusions

**Purpose:** Research why an identifier (CUSIP, LoanX ID) is missing from Solvas portfolios or excluded from specific client entities

**Common Scenario:**
> "Identifier LX293801 exists in MOS Reference with valid prices but doesn't appear in Solvas deal_facility_market_value or deal_issue_market_value tables for Sycamore portfolios"

#### Investigation Workflow

##### Step 7c.1: Verify Identifier Exists in MOS Reference

**Query:**
```sql
-- Check if identifier exists and has positions in MOS
SELECT DISTINCT
    p.Portfolio,
    p.refdatasetdate,
    ii.value AS Identifier,
    ii.IDType,
    p.Tradedqty,
    p.EffFromDate,
    p.PositionMark,
    i.AssetType
FROM core.dbo.vposition p
JOIN core.dbo.vinstidentifiercurrent ii ON ii.instid = p.instid
JOIN core.dbo.vInst i ON i.InstID = p.InstID
WHERE ii.value = '{Identifier}'  -- e.g., 'LX293801'
    AND p.Portfolio LIKE '%{PortfolioPattern}%'  -- e.g., '%sy%' for Sycamore
    AND p.refdatasetdate >= DATEADD(day, -30, GETDATE())
ORDER BY p.refdatasetdate DESC, p.Portfolio;
```

**Expected Output:**
| Portfolio | refdatasetdate | Identifier | IDType | Tradedqty | AssetType |
|-----------|----------------|------------|--------|-----------|------------|
| Sycamore CLO I | 2026-07-22 | LX293801 | LoanX | 1000000 | Loan |
| Sycamore CLO II | 2026-07-22 | LX293801 | LoanX | 500000 | Loan |

**Interpretation:**
- ✅ Identifier exists in MOS with active positions
- ✅ Has valid position marks and quantities
- ❓ **But missing from Solvas** → Proceed to next steps

##### Step 7c.2: Check Solvas Entity_Issue_view for Identifier

**Query:**
```sql
-- Check if identifier exists in Solvas Entity_Issue_view
SELECT 
    e.deal_name,
    e.entity_id,
    ev.lx_identifier,
    ev.cusip_number,
    ev.facility_id,
    ev.issue_id,
    ev.issue_name,
    ev.asset_type
FROM solvas_am.dbo.Entity_Issue_view ev
JOIN solvas_am.dbo.entity e ON e.entity_id = ev.entity_id
WHERE (ev.lx_identifier = '{LoanXID}'  -- e.g., 'LX293801'
       OR ev.cusip_number = '{CUSIP}')  -- e.g., '12345ABC7'
    AND e.deal_name LIKE '{DealPattern}%'  -- e.g., 'sy%'
ORDER BY e.deal_name;
```

**Possible Results:**

**Scenario A: Identifier Found in Solvas**
| deal_name | entity_id | lx_identifier | facility_id | issue_name |
|-----------|-----------|---------------|-------------|------------|
| Sycamore CLO I MOS | 295 | LX293801 | 11234 | ABC Corp Term Loan |

→ Identifier exists but may be excluded from price uploads (check Step 7c.3)

**Scenario B: Identifier NOT Found in Solvas**
| deal_name | entity_id | lx_identifier | facility_id | issue_name |
|-----------|-----------|---------------|-------------|------------|
| *(no results)* | - | - | - | - |

→ Identifier never mapped to Solvas entity (see Step 7c.4 for causes)

##### Step 7c.3: Check Solvas Portfolio Exclusion Configuration

**Query:**
```sql
-- Check if facility/issue has portfolio-specific exclusions
-- For Loans:
SELECT 
    e.deal_name,
    e.entity_id,
    f.facility_id,
    f.facility_name,
    f.exclude_from_reporting,
    f.active_flag,
    f.maturity_date,
    f.payoff_date
FROM solvas_am.dbo.facility f
JOIN solvas_am.dbo.entity e ON e.entity_id = f.entity_id
WHERE f.facility_id = {FacilityID}  -- From Step 7c.2
    AND e.deal_name LIKE '{DealPattern}%';

-- For Bonds:
SELECT 
    e.deal_name,
    e.entity_id,
    i.issue_id,
    i.issue_name,
    i.exclude_from_reporting,
    i.active_flag,
    i.maturity_date,
    i.payoff_date
FROM solvas_am.dbo.issue i
JOIN solvas_am.dbo.entity e ON e.entity_id = i.entity_id
WHERE i.issue_id = {IssueID}  -- From Step 7c.2
    AND e.deal_name LIKE '{DealPattern}%';
```

**Key Fields to Check:**
- `exclude_from_reporting` = 1 → Instrument excluded from reports/price uploads
- `active_flag` = 0 → Instrument marked inactive
- `maturity_date` / `payoff_date` → Check if past date (instrument paid off)

**Common Exclusion Reasons:**
1. **Reporting Exclusion:** `exclude_from_reporting = 1`
   - Instrument deliberately excluded from client reports
   - Often used for zero-balance positions or internal tracking

2. **Inactive Status:** `active_flag = 0`
   - Position sold/closed but not yet deleted
   - Historical data retained for audit purposes

3. **Maturity/Payoff:** `payoff_date IS NOT NULL`
   - Loan paid off or bond matured
   - No longer requires pricing

##### Step 7c.4: Check Entity-to-Portfolio Mapping

**Query:**
```sql
-- Verify entity mapping between MOS Portfolio and Solvas deal_name
SELECT 
    p.Portfolio AS MOS_Portfolio,
    e.deal_name AS Solvas_Deal,
    e.entity_id AS Solvas_EntityID,
    COUNT(DISTINCT ii.value) AS Instruments_Mapped
FROM core.dbo.vposition p
JOIN core.dbo.vinstidentifiercurrent ii ON ii.instid = p.instid
CROSS APPLY (
    SELECT e.deal_name, e.entity_id
    FROM solvas_am.dbo.entity e
    WHERE e.deal_name LIKE '%' + REPLACE(p.Portfolio, ' ', '%') + '%'
) e
WHERE p.Portfolio LIKE '%{PortfolioPattern}%'  -- e.g., '%Sycamore%'
    AND p.refdatasetdate = '{PriceDate}'
GROUP BY p.Portfolio, e.deal_name, e.entity_id
ORDER BY p.Portfolio, e.deal_name;
```

**Expected Output:**
| MOS_Portfolio | Solvas_Deal | Solvas_EntityID | Instruments_Mapped |
|---------------|-------------|-----------------|--------------------|
| Sycamore CLO I | Sycamore CLO I MOS | 295 | 127 |
| Sycamore CLO II | Sycamore CLO II MOS | 296 | 94 |

**Common Mapping Issues:**
1. **No entity match:** MOS Portfolio name doesn't match Solvas deal_name pattern
2. **Multiple entities:** MOS Portfolio maps to multiple Solvas entities (need manual selection)
3. **Entity name change:** Deal renamed in Solvas but MOS Portfolio name unchanged

##### Step 7c.5: Check Instrument Import History

**Query:**
```sql
-- Check if identifier was ever imported into Solvas
SELECT TOP 100
    gih.ImportDateTime,
    gih.ImportStatus,
    gih.RecordsProcessed,
    gih.RecordsRejected,
    gih.ErrorMessage,
    gij.Name AS ImportJobName,
    gij.SourceFolder,
    gij.FileName
FROM Feeds.dbo.vGenericImportHistory gih
JOIN Feeds.dbo.vGenericImportJob gij ON gij.GenericImportJobID = gih.GenericImportJobID
WHERE gij.Name LIKE '%Solvas%Instrument%'
    OR gij.Name LIKE '%Entity%Issue%'
ORDER BY gih.ImportDateTime DESC;
```

**Check Import Logs:**
- Look for rejected records on date identifier should have been added
- Review error messages for validation failures
- Check if import job succeeded but zero records created

##### Step 7c.6: Root Cause Identification

**Decision Tree:**

```
Is identifier in MOS Reference?
├─ NO → Identifier never created in MOS (instrument setup issue)
│   └─ Resolution: Add instrument to MOS Reference first
│
└─ YES → Does identifier exist in Solvas Entity_Issue_view?
    ├─ NO → Mapping never created
    │   ├─ Check: Was instrument imported? (Step 7c.5)
    │   │   ├─ NO → Import failed or never attempted
    │   │   │   └─ Resolution: Re-run instrument import job
    │   │   └─ YES → Import succeeded but identifier not mapped
    │   │       └─ Resolution: Manual mapping required in Solvas
    │   │
    │   └─ Check: Entity mapping correct? (Step 7c.4)
    │       ├─ NO → Portfolio name mismatch
    │       │   └─ Resolution: Update entity mapping configuration
    │       └─ YES → Identifier excluded by import filter
    │           └─ Resolution: Update import job filters
    │
    └─ YES → Is identifier excluded from reporting?
        ├─ YES → Check exclusion flags (Step 7c.3)
        │   ├─ exclude_from_reporting = 1
        │   │   └─ Resolution: Set exclude_from_reporting = 0 if needed
        │   ├─ active_flag = 0
        │   │   └─ Resolution: Set active_flag = 1 if position still exists
        │   └─ maturity_date/payoff_date set
        │       └─ Resolution: Clear payoff_date if loan not actually paid off
        │
        └─ NO → Check price upload configuration
            └─ pSolvasExportPriceEntity may be filtering this instrument
                └─ Resolution: Update @InstrumentSourceIDList parameter
```

#### Common Resolution Steps

##### Resolution 1: Enable Excluded Instrument

**For Loans:**
```sql
-- Re-enable facility for reporting
UPDATE solvas_am.dbo.facility
SET exclude_from_reporting = 0,
    active_flag = 1
WHERE facility_id = {FacilityID};
```

**For Bonds:**
```sql
-- Re-enable issue for reporting
UPDATE solvas_am.dbo.issue
SET exclude_from_reporting = 0,
    active_flag = 1
WHERE issue_id = {IssueID};
```

##### Resolution 2: Create Missing Entity Mapping

**Steps:**
1. Open Solvas AM application
2. Navigate to Entity Management → [Portfolio Name]
3. Select "Instruments" tab
4. Click "Add Facility" or "Add Issue"
5. Search for identifier (CUSIP/LoanX ID)
6. Map to correct entity_id
7. Save and verify in Entity_Issue_view

##### Resolution 3: Update Price Export Filter

**Modify pSolvasExportPriceEntity call:**
```sql
-- Include specific instrument source IDs if filtering was too restrictive
EXEC core.Report.pSolvasExportPriceEntity  
    @CompanyID = '500000004',
    @PriceDate = '{PriceDate}',
    @SingleDate = 1,
    @InstrumentSourceIDList = NULL,  -- Set to NULL to include all instruments
    @FallBackToMostRecentTradePrice = 1;
```

##### Resolution 4: Manual Price Upload (Temporary)

**If immediate fix needed before mapping corrected:**

**For Loans:**
```sql
-- Manually insert price record in Solvas
INSERT INTO solvas_am.dbo.deal_facility_market_value 
    (entity_id, facility_id, begin_date, market_value_indent, pricing_type_1)
VALUES 
    ({EntityID}, {FacilityID}, '{PriceDate}', {Price}, 1);
```

**For Bonds:**
```sql
-- Manually insert price record in Solvas
INSERT INTO solvas_am.dbo.deal_issue_market_value 
    (entity_id, issue_id, begin_date, market_value_indent, pricing_type_1)
VALUES 
    ({EntityID}, {IssueID}, '{PriceDate}', {Price}, 1);
```

⚠️ **Warning:** Manual inserts bypass validation and audit logging. Use only as temporary workaround.

#### Validation After Resolution

**Query to Verify Fix:**
```sql
-- Check identifier now appears in Solvas with prices
SELECT 
    e.deal_name,
    ev.lx_identifier,
    ev.cusip_number,
    dmv.begin_date,
    dmv.market_value_indent AS Price
FROM solvas_am.dbo.Entity_Issue_view ev
JOIN solvas_am.dbo.entity e ON e.entity_id = ev.entity_id
LEFT JOIN solvas_am.dbo.deal_facility_market_value dmv 
    ON dmv.facility_id = ev.facility_id 
    AND dmv.entity_id = ev.entity_id
    AND dmv.begin_date = '{PriceDate}'
WHERE ev.lx_identifier = '{LoanXID}'
    AND e.deal_name LIKE '{DealPattern}%'
ORDER BY dmv.begin_date DESC;
```

**Expected Output After Fix:**
| deal_name | lx_identifier | begin_date | Price |
|-----------|---------------|------------|-------|
| Sycamore CLO I MOS | LX293801 | 2026-07-22 | 98.25 |
| Sycamore CLO II MOS | LX293801 | 2026-07-22 | 98.25 |

✅ Identifier now appears in Solvas with valid prices

#### Documentation for ADO Ticket

**Template for Missing Identifier Investigation:**

```markdown
## Missing Identifier Investigation - {Identifier}

**Ticket:** #{TicketID}  
**Identifier:** {LoanXID or CUSIP}  
**Portfolio:** {PortfolioName}  
**Date:** {PriceDate}

### Investigation Summary

**MOS Reference Status:**
- ✅ Identifier exists in MOS with active positions
- Portfolio: {MOS Portfolio Names}
- Position Quantities: {Quantities}
- Asset Type: {Bond/Loan/ABS}

**Solvas Status:**
- ❌ Identifier NOT found in Entity_Issue_view for {Solvas Deal Name}
- OR
- ⚠️ Identifier found but excluded: `exclude_from_reporting = 1`

### Root Cause

{Select appropriate cause from Step 7c.6 decision tree}

**Examples:**
- Facility marked as `exclude_from_reporting = 1` in Solvas
- Entity mapping between MOS Portfolio "{MOS Name}" and Solvas Deal "{Solvas Name}" incomplete
- Instrument import job filtered out this asset type
- Manual exclusion requested by client (verify with stakeholder)

### Resolution Applied

{Describe resolution from Step 7c.6}

**SQL Commands Executed:**
```sql
{Paste actual UPDATE or INSERT statements used}
```

**Validation Query:**
```sql
{Paste verification query from "Validation After Resolution"}
```

### Verification

- ✅ Identifier now appears in Solvas Entity_Issue_view
- ✅ Prices successfully uploaded via pSolvasExportPriceEntity
- ✅ Position extracts include this identifier
- ✅ Client reports updated

### Next Steps

1. Monitor price uploads for next {N} days to ensure consistency
2. Verify position extracts delivered to client include this instrument
3. Update documentation if this was systematic issue affecting multiple identifiers
```

---

### Step 8: Check Security Master Prices (SecM Direct Query)

**Purpose:** Validate prices in the Security Master database (Reference.dbo tables)

#### 8a. Find Instrument in Security Master

**Query:**
```sql
-- Lookup instrument identifier in Security Master
SELECT * 
FROM Reference.dbo.vinstidentifier 
WHERE Value = '{Identifier}'
  AND RefDataSource LIKE '%MarkIT LoanXMarks%';
```

**Parameters:**
- `{Identifier}` = LoanX ID or CUSIP

#### 8b. Check Price in Security Master

**Query:**
```sql
-- Use InstID from previous query
SELECT * 
FROM Reference.dbo.tInstPrice 
WHERE instid = {InstID}
  AND PriceDate = '{PriceDate}'
ORDER BY PriceDate;
```

**Parameters:**
- `{InstID}` = From Step 8a query result
- `{PriceDate}` = Target price date

**Use Case:**
- Verify raw vendor prices before price weighting is applied
- Check if Security Master received prices from MarkIT/LSEG/ICE vendors
- Diagnose vendor feed issues vs. price weighting issues

**Example:**
```sql
-- Find LoanX identifier in SecM
SELECT * FROM Reference.dbo.vinstidentifier 
WHERE Value='LX189433' 
AND RefDataSource like '%MarkIT LoanXMarks%'
-- Returns: InstID = 1000537671

-- Check price for that instrument
SELECT * FROM Reference.dbo.tInstPrice 
WHERE instid = 1000537671
AND PriceDate = '2026-06-03'
ORDER BY PriceDate
-- Returns: Price = 100.2087100, Bid = 100.1898000, Ask = 100.2277000
```

---

### Step 9: Post-Resolution Workflows

After correcting price mismatches, follow these procedures to refresh data and deliver reports:

#### 9a. Fund Dataset Refresh (Refresh Position Prices)

**Portal:** [Fund Data Governance - Dataset Refresh](https://mos-portal-p.mos.siepe.local/fund-data-governance/dataset-refresh)

**Purpose:** Refresh fund positions and prices after correcting vendor data or price overrides

**Steps:**
1. Navigate to Fund Data Governance portal
2. Select "Dataset Refresh"
3. Enter `RefDataSetDate` = Affected price date
4. Select target portfolios (or all portfolios for the company)
5. Click "Refresh Fund Data on Positions"
6. Monitor refresh completion

**⚠️ Important:** 
- Create multiple Report Subscription (RS) jobs to split large refreshes
- Large files may skip records; breaking into smaller batches prevents data loss

#### 9b. Job Management Portal

**Portal:** [Job Management](https://portal.mos.siepe.local/jobManagement)

**Purpose:** Monitor job status, check SSIS execution, and verify RS/SA jobs

**Use Cases:**
- Verify dataset refresh completion
- Check if price export jobs succeeded
- Monitor SFTP file transfer jobs
- Diagnose job failures or timeout issues

#### 9c. Position Extract for Client Reporting (pPositionExtract)

**Purpose:** Generate position extract files for client delivery (e.g., Sycamore)

**Report Subscription Tool:** [MOS Tools - Report Subscriptions](https://mos-tools-p.mos.siepe.local/#!/)

**Procedure:**
```sql
-- Search for "position" RS jobs in date range
-- Example: 6/15-6/19 and then 7/1-7/3

EXEC report.pPositionExtract  
    @RefDataSetDateStart = '6/15/2026',
    @RefDataSetDateEnd = '6/19/2026',
    @CompanyID = '500000004',  -- Sycamore
    @ExcludePortfolioID = '#[PortfolioExclusion]',
    @IsPositionCashFlow = #[IsPositionCashflow];

EXEC report.pPositionExtract  
    @RefDataSetDateStart = '7/1/2026',
    @RefDataSetDateEnd = '7/2/2026',
    @CompanyID = '500000004',
    @ExcludePortfolioID = '#[PortfolioExclusion]',
    @IsPositionCashFlow = #[IsPositionCashflow];
```

**Parameters:**
- `@RefDataSetDateStart` / `@RefDataSetDateEnd` = Date range for extraction
- `@CompanyID` = Target company (see Company ID reference below)
- `@ExcludePortfolioID` = Portfolios to exclude (optional)
- `@IsPositionCashFlow` = Include cashflow data (0 or 1)

**Script Adapter Delivery:**

After generating position extract, deliver to client via Script Adapter:

**Portal:** [Sycamore Tools - Script Adapter](https://sycamore-tools-p.stp.aws/ScriptAdapter#!/)

**Configuration:**
- Search: "Mos Position"
- Script Adapter ID: 3
- Delivers position extract files to client SFTP

---

### Step 10: Bid Price Validation Workflow

**Purpose:** Validate bid prices pushed from MOS to Solvas and Security Master

#### 10a. Company ID Reference

**Query:**
```sql
-- Get company details
SELECT 
    CompanyID,
    CompanyName,
    CompanyShortName,
    RefRecStatusID
FROM Core.dbo.vCompanyCurrent
WHERE CompanyID = '{CompanyID}';
```

**Company Reports Reference (RS and SA IDs):**

| Company | CompanyID | RS_ID | SA_ID |
|---------|-----------|-------|-------|
| Diameter | 500000002 | 500002484 | 1555 |
| Sycamore | 500000004 | 500002483 | 1556 |
| Abry Partners II, LLC | 500000005 | 500002485 | 1557 |
| Aristotle Pacific Capital | 500000006 | (manual) | 1558 |
| Garnet Credit Management | 500000007 | (manual) | 1559 |

**Use Case:**
- Lookup Report Subscription (RS) ID for automated reporting
- Find Script Adapter (SA) ID for file delivery
- Verify company configuration in Core database

#### 10b. Execute Price Export to Solvas (pSolvasExportPriceEntity)

**Purpose:** Export MOS prices to Solvas for back office processing

**Procedure (All Companies):**
```sql
-- Execute for all client companies, single date
EXEC core.Report.pSolvasExportPriceEntity  
    @CompanyID = '500000004,500000002,500000005,500000006,500000007',
    @FallBackToMostRecentTradePrice = 1, 
    @PriceDate = '{PriceDate}', 
    @SingleDate = 1;
```

**Procedure (Single Company):**
```sql
-- Execute for specific company (e.g., Sycamore)
EXEC core.Report.pSolvasExportPriceEntity  
    @CompanyID = '500000004',
    @FallBackToMostRecentTradePrice = 1, 
    @PriceDate = '2026-06-16', 
    @SingleDate = 1;
```

**Parameters:**
- `@CompanyID` = Single or comma-separated list of company IDs
- `@PriceDate` = Target price date
- `@FallBackToMostRecentTradePrice` = Use last available price if current date missing (1 = yes)
- `@SingleDate` = Export single date only (1) vs. date range (0)

**Action:** 
- Load price file into SFTP folder (see Step 10d)
- Fire off Script Adapter job to import into Solvas

#### 10c. Execute Bid Price Export (pPriceExport)

**Purpose:** Export bid prices to Security Master for validation

**Report Subscription ID:** `700002320`

**Procedure:**
```sql
-- Export bid prices for date range
-- Run for each day individually (change date per row)
-- Wait 15-20 minutes, then check reference prices
EXEC Core.Report.pPriceExport 
    @PriceSourceIDList = '1000000001,1000000004,1000000016', 
    @InstrumentSourceIDList = NULL,  -- Leave NULL if InstID not known
    @StartDate = '2026-07-01', 
    @EndDate = '2026-07-03', 
    @dateRange = 1;
```

**Parameters:**
- `@PriceSourceIDList` = Comma-separated price source IDs (ICE, LSEG, Markit)
  - 1000000001 = ICE
  - 1000000004 = LSEG  
  - 1000000016 = Markit (MarkIT LoanXMarks)
- `@InstrumentSourceIDList` = NULL (if you don't know it; InstID from MOS ≠ SecM)
- `@StartDate` / `@EndDate` = Date range for export
- `@dateRange` = 1 (export each day in range)

**Workflow:**
1. Execute pPriceExport RS job 700002320
2. RS generates price export file
3. RS 500002177 picks up file from mos-tools-p.mos.siepe.local
4. Manually run Script Adapter job ID 1291 on MOS

**Validation Query:**
```sql
-- After 15-20 minutes, verify prices loaded
-- Compare position marks with bid prices
SELECT DISTINCT 
    PositionMark, 
    p.refdatasetdate, 
    p.Portfolio, 
    ii.value 
FROM core.dbo.vposition p 
JOIN core.dbo.vinstidentifiercurrent ii ON ii.instid = p.instid
WHERE p.refdatasetdate = '2026-06-15'
  AND p.Portfolio LIKE '%sy%'
  AND ii.value = 'LX245155'
ORDER BY p.refdatasetdate DESC;

-- Check corresponding bid prices
SELECT TOP 100 * 
FROM Reference.dbo.vinstpricecurrentraw p 
JOIN Reference.dbo.vRefDataSource r ON r.RefDataSourceID = p.RefDataSourceID
JOIN Reference.dbo.vInstIdentifierCurrent ii ON ii.instid = p.instid 
WHERE ii.value = 'LX245155'
  AND r.name NOT IN ('solvas portfolio') 
  AND p.PriceDate = '2026-06-15';
```

**Expected Result:**
- Position mark should match bid price from vendor source
- Example: LX245155 → PositionMark = 1.00227, Bid = 1.00227 ✅

#### 10d. SFTP Folder Locations and File Pickup

**Solvas Price Import SFTP Folder:**
```
\\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\Solvas\SecMaster\LoanXMarks\Incoming
```

**Security Master Index SFTP Folder:**
```
\\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\Siepe-SecurityMaster\Index
```

**Pick-up Script Location:**
```
C:\Siepe\Data\Scripts\PROD\SecMaster_Index.ps1
```

**Remote Server:**
- RS Server: mos-tools-p.mos.siepe.local
- Remote Execution: 998s02.mos.siepe.local

**Script Adapter Jobs:**
- SA ID 30: Runs SecM Price Script Adapter
- SA ID 1291: Manually triggered for bid price import

**Query to Find Pickup Location:**
```sql
-- Check Generic Import Job configuration for pickup folder
SELECT 
    SourceFolder, 
    FileName, 
    FileExtension, 
    ArchiveLocation,
    *
FROM Feeds.dbo.vGenericImportJob 
WHERE GenericImportJobID = 2136
  AND RefRecStatusID = 1;
```

**Expected Output:**
| SourceFolder | FileName | FileExtension | ArchiveLocation |
|--------------|----------|---------------|-----------------|
| \\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\Siepe-SecurityMaster\Index | SecMaster_* | .csv | \\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\Siepe-SecurityMaster\Index\Archive |

---

## Reference Links & Documentation

### Internal Wiki
- **Price Exception Documentation:** [Wiki - Price Exception Not Matching MarkIT/ICE/LSEG or NULL Marks](https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/2281/Price-Exception-Not-Matching-MarkIT-ICE-or-ICE-OR-NULL-Marks)

### Related Tasks
- TASK 83664 - Price export workflow and bid price validation
- TASK 84763 - Security Master portal configuration changes
- TASK 82115 - Market price discrepancy investigation example

### Portal Locations
- **Security Master Portal:** securitymastertools.siepe.local (Remove 000app01.siepe.local)
- **Fund Data Governance:** https://mos-portal-p.mos.siepe.local/fund-data-governance/dataset-refresh
- **Job Management:** https://portal.mos.siepe.local/jobManagement
- **MOS Tools (RS):** https://mos-tools-p.mos.siepe.local/#!/
- **Sycamore Tools (SA):** https://sycamore-tools-p.stp.aws/ScriptAdapter#!/

---

## Output Format

Generate a markdown file with the following structure:

**Filename:** `CheckMarketPrice-{Identifier}-{Date}.md`  
**Example:** `CheckMarketPrice-008911BD0-2026-06-30.md`

**Template:**

```markdown
# Market Price Analysis Report

**Work Item:** #{WorkItemID}  
**Date:** {CurrentDate}  
**Analyst:** {YourName}  

---

## Summary

**Company:** {CompanyName} (ID: {CompanyID})  
**Instrument:** {Identifier} ({InstName})  
**Price Date:** {PriorDate}  
**Asset Type:** {WSOAssetType}  

**Issue:** {Brief description from ticket}  
**Status:** ✅ Resolved | ⚠️ Configuration Needed | ❌ Vendor Issue  

---

## Investigation Results

### 1. Company Identification
- **CompanyID:** {CompanyID}
- **Company Name:** {CompanyName}

### 2. Available Vendor Prices

| RefDataSource | Price | Bid | Ask | MidCalc | PriceSource |
|---------------|-------|-----|-----|---------|-------------|
| {Data from Step 2} |

**Analysis:**
- ✅ {X} vendor sources available
- ⚠️ Key findings...

### 3. Price Weighting Configuration

| Priority | RefDataSource | Weight | Asset Type Filter |
|----------|---------------|--------|-------------------|
| {Data from Step 3, ranked by weight} |

**Analysis:**
- Highest priority source: {Source} (weight {Weight})
- Applies to: {Asset types or "All"}

### 4. Instrument Classification

| Property | Value |
|----------|-------|
| InstID | {InstID} |
| Instrument Name | {InstName} |
| Instrument Type | {InstType} |
| WSO Asset Type | {WSOAssetType} |

### 5. Executed Price

| Field | Value |
|-------|-------|
| Evaluated Price | {EvaluatedPrice} |
| Source | {DeterminedSource} |
| Ask | {Ask} |
| Bid | {Bid} |

---

## Root Cause

{Detailed explanation of why specific price was selected}

**Example:**
```
The instrument is classified as a Bond (WSOAssetType = "Bond").

Price Weighting Analysis:
1. Aristotle|ICE (weight 750, Bond filter) - NO PRICE AVAILABLE ❌
2. Siepe-SecurityMaster|Price|MarkIt (weight 750, ABS/Loan filter) - DOES NOT MATCH ❌
3. Aristotle|LSEG (weight 800, No filter) - MATCHED & AVAILABLE ✅

Result: Aristotle|LSEG price (100.26095) was selected because:
- Higher priority sources (ICE) had no data
- Markit rule only applies to ABS and Loan instruments
- LSEG is the next available source with matching criteria
```

---

## Recommendations

### Immediate Actions
- [ ] {Action item 1}
- [ ] {Action item 2}

### Configuration Changes Needed
{Include SQL INSERT/UPDATE if needed}

### Follow-Up Required
- {Follow-up task 1}
- {Follow-up task 2}

---

## SQL Queries Used

<details>
<summary>Click to expand queries</summary>

### Query 1: Company Lookup
```sql
{Actual query executed}
```

### Query 2: Vendor Prices
```sql
{Actual query executed}
```

### Query 3: Price Weighting
```sql
{Actual query executed}
```

### Query 4: Instrument Type
```sql
{Actual query executed}
```

### Query 5: Price Export Procedure
```sql
{Actual query executed}
```

</details>

---

## ADO Ticket Update

**Copy the following comment to paste into ADO:**

```
---

**Market Price Analysis Complete**

**Summary:** {One-sentence summary}

**Root Cause:** {Brief explanation}

**Resolution:** {Recommended action}

**Details:** See attached analysis report: CheckMarketPrice-{Identifier}-{Date}.md

**Next Steps:**
1. {Action 1}
2. {Action 2}

{If configuration change needed, include SQL snippet}

---
```

---

## Attach Report to ADO Ticket

After generating the markdown report, attach it to the ADO ticket so the support user can review the complete analysis.

### Step 1: Save the Markdown File

```powershell
# Define file path
$identifier = "{CUSIP_or_ISIN}"  # e.g., "83408EAA1"
$date = Get-Date -Format "yyyyMMdd"
$fileName = "CheckMarketPrice_${identifier}_${date}.md"
$outputPath = "C:\source\MD\AdminTools\Output\$fileName"

# Write markdown content to file
$markdownContent | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ Markdown report generated: $fileName"
```

### Step 2: Attach to ADO Ticket

```powershell
# Upload file as attachment to ADO ticket
$ticketId = {WorkItemID}  # e.g., 82685

az boards work-item relation add `
    --id $ticketId `
    --relation-type AttachedFile `
    --target-id (az boards attachment upload --file-path $outputPath --output tsv) `
    --org "https://siepe.visualstudio.com/" `
    --output json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Report attached to TASK #$ticketId"
} else {
    Write-Host "❌ Failed to attach report to ticket"
}
```

### Step 3: Post Summary Comment

```powershell
# Post brief comment referencing the detailed markdown report
$comment = "💰 Price investigation complete - see attached report for root cause and resolution SQL"

az boards work-item update --id $ticketId `
    --org "https://siepe.visualstudio.com/" `
    --discussion "$comment"

Write-Host "✅ Brief summary posted to TASK #$ticketId"
```

---

## Appendix: Reference Information

### Common RefDataSource Names
- `Aristotle|LSEG` - Refinitiv (formerly LSEG) pricing via Aristotle feed
- `Aristotle|ICE` - ICE pricing via Aristotle feed
- `Siepe-SecurityMaster|Price|MarkIt` - Markit pricing
- `PriceRollover-*` - Rolled-over price from previous day
- `MOS Ops Price Override` - Manual price overrides

### Common WSOAssetType Values
- `Bond` - Corporate bonds, government bonds
- `Loan` - Term loans, revolvers
- `Equity` - Stocks, equity securities
- `ABS` - Asset-backed securities

### Price Weighting Levels
- **Level1CriteriaType**: Portfolio grouping (PortfolioID, FundID, FundTypeID, None)
- **Level2CriteriaType**: Instrument classification (InstID, InstTypeID, WSOAssetType, None)
- **Weight**: Priority ranking (lower = higher priority)

---

*This report was generated using the Market Price Analysis Skill v1.0*
```

---

## Important Notes

1. **If ticket lacks CUSIP/ISIN** - Start with Step 0 to extract identifiers from Enhanced Pricing Report
2. **Always use PriorDate** (date minus 1 day) - pricing typically loads next business day
3. **Check for PriceRollover sources** - indicates stale prices
4. **Match asset types carefully** - configuration rules are case-sensitive
5. **Lower weight = higher priority** - counterintuitive but critical
6. **"None" filters are catch-alls** - apply when no specific asset type match exists
7. **Multiple asset types = multiple analyses** - Use Step 0 Option B for comprehensive validation

---

## Future Enhancements

**Phase 2 (ADO Integration):**
- Automatic ADO ticket updates via Azure CLI
- Attachment of analysis report directly to work item
- Automated work item status updates

**Command Preview:**
```powershell
# Future: Auto-update ADO ticket
az boards work-item update `
    --id {WorkItemID} `
    --discussion "{analysis_summary}" `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software"
```

---

## Contact & Support

**For questions about this skill:**
- MOS Support Team
- Database: MOS Production (mos-sql-p.mos.siepe.local,52155)
- Wiki: https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/1006/MOS

**Skill Version:** 1.0  
**Last Updated:** 2026-07-01  
**Maintained By:** MOS Support Team
