# Price Overrides Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration  
**Reference:** https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/6226/MOS-Ops-Price-Overrides

## Description
Process price overrides for securities (bonds and loans) in MOS and Solvas databases. Enhanced with Excel screenshot analysis to extract override data from images and wiki procedure integration for compliance. This involves tagging instruments in MOS, deleting existing market values in Solvas, and inserting new override prices.

## When to Use This Skill
- User mentions "price override" or "override price"
- Task/ticket involves applying custom pricing to specific CUSIPs
- User provides CUSIP, override price, override date, and Inst ID
- Reference to TASK 82685 or Solvas price override procedures

## Input Method Decision Guide

**Use Direct Field Input when:**
- ✅ Processing 1-3 securities
- ✅ Quick ad-hoc override request
- ✅ Simple ticket with clear data
- ✅ Faster for small changes

**Use Excel Attachment when:**
- ✅ Processing 4+ securities
- ✅ Bulk override operations
- ✅ Complex data with many portfolios
- ✅ Operations team provided structured file

---

## Input Requirements

### Phase 0: Analyze Attachments and Fetch Procedures

**Step 0.1: Screenshot Analysis**
```powershell
# Download ticket attachments
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes Excel screenshots to extract:
# - CUSIP/LX identifiers from visible cells
# - Override prices in price columns
# - Override dates
# - Portfolio/deal names
# - Inst IDs if visible
```

**Step 0.2: Fetch Wiki Procedure**
```powershell
$wikiPath = "/6226/MOS-Ops-Price-Overrides"
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_PriceOverrides.md" -Encoding UTF8
```

### Two Input Methods Supported:

#### Method 1: Direct Field Input (For 1-3 Securities)
User provides required fields directly in the ticket description or as structured text:

**Required Fields:**
- **CUSIP ID** (or LX identifier for loans) - e.g., "68610BAA2", "LX232483"
- **Override Price** - e.g., "30.4375", "66.00"
- **Override Date** - e.g., "2026-06-30", "6/30/2026"
- **Inst ID** (from MOS database) - e.g., "500016222"
- **Portfolio/Deal Names** - e.g., "Pacific Select Fund - Core Income Portfolio"

**Example Ticket Description Format:**
```
Price override request:
CUSIP: 68610BAA2
Override Price: 30.4375
Override Date: 2026-06-30
Inst ID: 500016222
Portfolios: Pacific Select Fund - Core Income Portfolio, Pacific Life Insurance Company: IMD Bank Loans Portfolio

CUSIP: 15477CAA3
Override Price: 65.0000
Override Date: 2026-06-30
Inst ID: 500010629
Portfolios: Aristotle Funds Series Trust - Aristotle Core Income Fund
```

**OR Table Format:**
```
| CUSIP     | Override Price | Inst ID   | Override Date | Portfolio/Deal Name                                    |
|-----------|----------------|-----------|---------------|-------------------------------------------------------|
| 68610BAA2 | 30.4375        | 500016222 | 2026-06-30    | Pacific Select Fund - Core Income Portfolio           |
| 15477CAA3 | 65.0000        | 500010629 | 2026-06-30    | Aristotle Funds Series Trust - Aristotle Core Income Fund |
| LX232483  | 66.0000        | 500009880 | 2026-06-30    | Trestles CLO V, Ltd MOS                               |
```

#### Method 2: Excel Attachment (For Bulk/4+ Securities)
User attaches Excel file with the following columns:

**Required Excel Columns:**
- CUSIP (or LX Identifier)
- Override Price
- Inst ID
- Override Date
- Portfolio/Deal Name

**Example Excel Format:**
```
CUSIP       Override Price     Inst ID        Portfolio/Deal Name
68610BAA2   30.4375           500016222      Pacific Select Fund - Core Income Portfolio
15477CAA3   65.0000           500010629      Aristotle Funds Series Trust - Aristotle Core Income Fund
LX232483    66.0000           500009880      Trestles CLO V, Ltd MOS
```

#### Method 3: Automated CSV Import (For Large-Scale Bulk Overrides)

For large-scale overrides, you can use the automated email import process instead of manual SQL execution:

**Process:**
1. Create CSV file named: `MOSOpsPriceOverrides_yyyyMMdd.csv`
2. Send email to: **MOSData@Siepe.com**
3. Email subject: **"MOS Ops Price Overrides yyyyMMdd"**
4. Attach the CSV file
5. File will automatically ingest via:
   - **Generic Import Job ID:** 2350
   - **Generic Normalization Job IDs:** 164
   - **Normalization Views:**
     - `Feeds.MOS.vMOSOpsPriceOverridesInstRefNormalization`
     - `Feeds.MOS.vMOSOpsPriceOverridesInstPricingRefNormalization`

**Post-Import:**
- Send follow-up email requesting MOS Support to:
  - Confirm prices in Solvas
  - Kick off data refresh for the specified dates

**When to Use This Method:**
- ✅ 10+ securities with same override date
- ✅ Regular monthly/quarterly override batches
- ✅ Operations team prefers file-based workflow
- ✅ Automated tracking via import job logs

**RefDataSource Configuration:**
Check import configuration:
```sql
SELECT * 
FROM reference.dbo.vInstArbitrationRefDataSourceConfigRaw  
WHERE RefDataSourceID = 1000000168
```

---

## Requirements Validation

**CRITICAL:** Before proceeding with investigation, validate that all required information is available. If confidence is adequate but requirements are missing, the agent MUST post missing requirements to the ticket discussion.

### Validation Logic

```powershell
# Step 1: Fetch ticket details
$ticketId = <TICKET_ID>
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json

$description = $ticket.fields.'System.Description'
$title = $ticket.fields.'System.Title'

# Step 2: Check for Excel attachment
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$excelAttachment = $attachments | Where-Object { $_.url -like "*.xlsx" -or $_.url -like "*.xls" }

# Step 3: Check for required fields in description
$hasDirectInput = (
    $description -match 'CUSIP|LX\d+' -and
    $description -match 'Override\s+Price|Price.*\d+\.\d+' -and
    $description -match 'Override\s+Date|Date.*\d{4}-\d{2}-\d{2}' -and
    $description -match 'Inst\s*ID|InstID.*\d+' -and
    $description -match 'Portfolio|Deal\s+Name'
)

# Step 4: Build missing requirements list
$missingReqs = @()

if (-not $excelAttachment -and -not $hasDirectInput) {
    $missingReqs += @"
- **Input Method**: No Excel attachment found AND required fields not in ticket description. Please provide EITHER:
  
  **Option A - Direct Input (for 1-3 securities):**
  Include these fields in ticket description:
  - CUSIP ID (or LX identifier)
  - Override Price
  - Override Date
  - Inst ID
  - Portfolio/Deal Names
  
  **Option B - Excel Attachment (for bulk/4+ securities):**
  Attach Excel file with columns: CUSIP, Override Price, Inst ID, Override Date, Portfolio/Deal Name
"@
}

# Validate specific fields if using direct input
if ($hasDirectInput) {
    if ($description -notmatch '\d{4}-\d{2}-\d{2}|(\d{1,2}/\d{1,2}/\d{4})') {
        $missingReqs += "- **Override Date**: Date format unclear. Please use YYYY-MM-DD (e.g., 2026-06-30)"
    }
    if ($description -notmatch 'Inst\s*ID.*\d{9}') {
        $missingReqs += "- **Inst ID**: MOS Inst ID not found or invalid format. Should be 9-digit number (e.g., 500016222)"
    }
}

# Step 5: If requirements missing, post to discussion
if ($missingReqs.Count -gt 0) {
    $comment = @"
### ⚠️ Missing Requirements for Price Override

This ticket was identified for price override processing, but the following required information is missing:

$($missingReqs -join "`n`n")

**Example Direct Input Format:**
\`\`\`
CUSIP: 68610BAA2
Override Price: 30.4375
Override Date: 2026-06-30
Inst ID: 500016222
Portfolios: Pacific Select Fund - Core Income Portfolio
\`\`\`

**Next Steps:**
1. Provide missing information using either direct input OR Excel attachment
2. For bulk operations (4+ securities), Excel attachment is recommended
3. For small operations (1-3 securities), direct input in description is faster

**Skill Status:** Investigation paused until requirements are complete.
"@

    az boards work-item update --id $ticketId `
        --org "https://siepe.visualstudio.com/" `
        --discussion "$comment"
    
    Write-Host "❌ Requirements validation failed. Posted missing requirements to ticket #$ticketId discussion."
    exit 1
}

Write-Host "✅ All requirements present. Proceeding with investigation..."
Write-Host "Input method: $(if ($excelAttachment) { 'Excel Attachment' } else { 'Direct Field Input' })"
```

### When to Skip Investigation

**STOP and post requirements** if:
- 🛑 No Excel attachment AND no structured field input in description
- 🛑 Missing required fields (CUSIP, Price, Date, Inst ID, Portfolio)
- 🛑 Inst ID format invalid (not 9 digits)
- 🛑 Date format ambiguous or unparseable

**Proceed with investigation** if:
- ✅ Excel file attached with all required columns, OR
- ✅ Ticket description contains all required fields in clear format
- ✅ All values are parseable and valid

---

---

## Workflow Steps

### Step 0: Parse Input Data

Depending on the input method, extract the required data:

#### Option A: Parse Excel Attachment
```powershell
# Download Excel file
$token = (az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv)
$headers = @{ Authorization = "Bearer $token" }
Invoke-RestMethod -Uri $excelAttachment.url -Headers $headers -OutFile "C:\temp\overrides.xlsx"

# Parse Excel
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$workbook = $excel.Workbooks.Open("C:\temp\overrides.xlsx")
$sheet = $workbook.Sheets.Item(1)

# Extract data rows
$overrides = @()
for ($row = 2; $row -le $sheet.UsedRange.Rows.Count; $row++) {
    $overrides += @{
        CUSIP = $sheet.Cells.Item($row, 1).Text
        OverridePrice = $sheet.Cells.Item($row, 2).Text
        InstID = $sheet.Cells.Item($row, 3).Text
        OverrideDate = $sheet.Cells.Item($row, 4).Text
        Portfolios = $sheet.Cells.Item($row, 5).Text
    }
}

$workbook.Close()
$excel.Quit()
```

#### Option B: Parse Direct Field Input
```powershell
$description = $ticket.fields.'System.Description'

# Parse structured text format
$overrides = @()
$currentOverride = @{}

# Split by lines and parse key-value pairs
$lines = $description -split "`n"
foreach ($line in $lines) {
    if ($line -match '^\s*CUSIP\s*[:=]\s*([A-Z0-9]+)') {
        if ($currentOverride.Count -gt 0) {
            $overrides += $currentOverride
            $currentOverride = @{}
        }
        $currentOverride['CUSIP'] = $matches[1]
    }
    elseif ($line -match '^\s*Override\s+Price\s*[:=]\s*([\d.]+)') {
        $currentOverride['OverridePrice'] = $matches[1]
    }
    elseif ($line -match '^\s*Override\s+Date\s*[:=]\s*(\d{4}-\d{2}-\d{2})') {
        $currentOverride['OverrideDate'] = $matches[1]
    }
    elseif ($line -match '^\s*Inst\s*ID\s*[:=]\s*(\d+)') {
        $currentOverride['InstID'] = $matches[1]
    }
    elseif ($line -match '^\s*Portfolio[s]?\s*[:=]\s*(.+)') {
        $currentOverride['Portfolios'] = $matches[1].Trim()
    }
}

# Add last override
if ($currentOverride.Count -gt 0) {
    $overrides += $currentOverride
}

# Alternative: Parse table format
if ($overrides.Count -eq 0 -and $description -match '\|.*CUSIP.*\|') {
    # Extract table rows
    $tableLines = $lines | Where-Object { $_ -match '^\s*\|' -and $_ -notmatch '^\s*\|[-\s|]+\|' }
    foreach ($tableLine in $tableLines | Select-Object -Skip 1) {
        $cells = $tableLine -split '\|' | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }
        if ($cells.Count -ge 5) {
            $overrides += @{
                CUSIP = $cells[0]
                OverridePrice = $cells[1]
                InstID = $cells[2]
                OverrideDate = $cells[3]
                Portfolios = $cells[4]
            }
        }
    }
}

Write-Host "Parsed $($overrides.Count) override(s) from ticket description"
```

---

### Step 1: Get Instrument Identifiers from MOS
Query MOS database to get `instidentifierid` and `instid` for each CUSIP.

**Query Template:**
```sql
SELECT instidentifierid, instid, * 
FROM core.dbo.vinstidentifiercurrent 
WHERE value = '{CUSIP}'
```

**Example:**
```sql
SELECT instidentifierid, instid, * 
FROM core.dbo.vinstidentifiercurrent 
WHERE value = '68610BAA2'
```

**Action:** Record the `instid` for each CUSIP (should match the Inst ID provided in input).

---

### Step 2: Check if Tagging Already Exists
For each `instid`, check if portfolios are already tagged with tagid = 5.

**Query Template:**
```sql
SELECT portfolioId, * 
FROM core.dbo.vTagMapActive 
WHERE tagid = 5 AND instid = '{instid}'
```

**Example:**
```sql
SELECT portfolioId, * 
FROM core.dbo.vTagMapActive 
WHERE tagid = 5 AND instid = '500016222'
```

**Action:** 
- If results exist for all portfolios → skip Step 3
- If some/all portfolios are missing tagid = 5 → proceed to Step 3

---

### Step 3: Generate Tagging Statements (If Needed)
For each `portfolioId` that does NOT have tagid = 5, generate the tagging procedure statement.

**Procedure Template:**
```sql
EXEC core.dbo.pTagMapI 
    @Tagid = 5,
    @InstID = '{instid}',
    @PortfolioID = '{portfolioId}',
    @EffFromDate = '{override_date}'
```

**Example:**
```sql
EXEC core.dbo.pTagMapI 
    @Tagid = 5,
    @InstID = '500009880',
    @PortfolioID = '500000100',
    @EffFromDate = '2026-06-30'
```

**Action:** 
- Generate EXEC statements for all portfolios missing the tag
- Display statements for manual review
- **DO NOT EXECUTE** - reviewer will decide whether to run them

---

### Step 3.5: Identify Security Type (Bond, Loan, or Equity)

**CRITICAL:** Before querying Solvas, determine which type of security you're working with. This determines which tables, stored procedures, and workflows to use.

**🔍 How to Identify Security Type:**

#### Method 1: Check Identifiers from MOS or Ticket

| Security Type | Has CUSIP? | Has LX_identifier? | Has Bloomberg ID? | Example Identifier |
|---------------|------------|--------------------|--------------------|-------------------|
| **Bond** | ✅ Yes | ❌ No | May have | 15477CAA3, 68610BAA2 |
| **Loan** | ❌ No | ✅ Yes | May have | LX232483, LX204108 |
| **Equity (Fund Unit)** | ❌ No | ❌ No | ✅ Usually | BBG00FMFT6M9 |

**Query to Check Identifiers:**
```sql
-- Query MOS to see what identifiers exist
SELECT instidentifierid, instid, value, InstIdentifierTypeID
FROM core.dbo.vinstidentifiercurrent
WHERE instid = {INST_ID}
```

**Identifier Type IDs:**
- `InstIdentifierTypeID = 500000001` → CUSIP (Bond)
- `InstIdentifierTypeID = 500000006` → Bloomberg (Could be any type, check for CUSIP/LX)
- Look for LX prefix in value → Loan

#### Method 2: Check Solvas Entity_Issue_view

```sql
SELECT 
    issue_id, 
    facility_id,
    cusip_number, 
    lx_identifier, 
    issue_name
FROM Solvas_AM.dbo.Entity_Issue_view
WHERE issue_name LIKE '%{SECURITY_NAME}%'
```

**Decision Logic:**
- If `cusip_number IS NOT NULL` → **Bond** (use Steps 4a, 5a, 6a)
- If `lx_identifier IS NOT NULL` → **Loan** (use Steps 4b, 5b, 6b)
- If `cusip_number IS NULL` AND `lx_identifier IS NULL` → **Equity** (use Steps 4c, 5c, 6d)

#### Workflow Mapping by Security Type

| Security Type | Step 4 Query | Step 5 DELETE | Step 6 INSERT | Table |
|---------------|-------------|---------------|---------------|-------|
| **Bond** | Query with cusip_number | deal_Issue_market_value_del | Deal_issue_market_value_put | Deal_Issue_Market_Value |
| **Loan** | Query with lx_identifier | deal_facility_market_value_del | Deal_Facility_market_value_put | deal_facility_market_value |
| **Equity** | Query with issue_id | deal_equity_market_value_del | deal_equity_market_value_put | deal_equity_market_value |

**Action:**
- Identify security type from identifiers
- Note the type in your investigation report
- Follow the appropriate workflow path (Bond/Loan/Equity) in subsequent steps
- If unclear, check both Bond and Loan queries - one will return results

---

### Step 4: Query Solvas for Entity and Issue Mappings

**⚠️ CRITICAL CONCEPT:** Before you can generate DELETE and INSERT statements for Solvas, you MUST have the `entity_id` and `issue_id`/`facility_id` values. These values:
- Are **NOT** typically provided in the ticket
- Must be **queried from the Solvas database**
- Must be **stored** for use in Steps 5 and 6
- Will **NOT be available after DELETE statements are executed** in Step 5

**This step has two parts:**
1. Map portfolio/deal names → entity_id
2. Map CUSIP/LX identifier → issue_id or facility_id

---

#### Step 4a: Query for Entity IDs (Portfolio/Deal Name → entity_id)

If the ticket provides portfolio/deal names but NOT entity_id values, query Solvas to get them:

**Query Template:**
```sql
-- Get entity_id for all portfolios mentioned in the ticket
SELECT 
    entity_id,
    deal_name
FROM Solvas_AM.dbo.entity
WHERE deal_name IN ({portfolio_list})
ORDER BY deal_name
```

**Example:**
```sql
SELECT 
    entity_id,
    deal_name
FROM Solvas_AM.dbo.entity
WHERE deal_name IN (
    'AAD1',
    'AAD2', 
    'CLOMEN',
    'COAST3'
)
ORDER BY deal_name
```

**Example Results:**
```
entity_id   deal_name
---------   ---------
234         AAD1
235         AAD2
257         CLOMEN
419         COAST3
```

**Action:** 
- Store the entity_id values with their corresponding portfolio names
- You will need these for both DELETE (Step 5) and INSERT (Step 6) statements

**Alternative Lookup Methods:**

If portfolio/deal names are not provided, use these queries:

```sql
-- Search for InstID by instrument name
SELECT ID as instid, Name  
FROM Client.ivInstCurrent 
WHERE Name LIKE '%Kleopatra%'

-- Search for Portfolio ID by name
SELECT id as portfolioid 
FROM Client.ivPortfolioCurrent 
WHERE Name LIKE '%Trestles%'

-- Get Entity ID from Solvas by deal name pattern
SELECT entity_id, deal_name 
FROM Solvas_AM.dbo.entity 
WHERE deal_name LIKE '%Trestles CLO%'
```

**Check Historical Changes (for troubleshooting):**

If you need to see what changed previously:

```sql
-- Check historical price changes via log table
SELECT *
FROM solvas_am.dbo.deal_issue_market_value_log d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV  
  ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
  AND ev.entity_id = e.entity_id
WHERE e.deal_name IN ('Aristotle Funds Series Trust - Aristotle High Yield Bond Fund')
  AND ev.cusip_number IN ('LX232483')
  AND begin_date >= '2026-07-13 00:00:00'
ORDER BY begin_date DESC
```

---

#### Step 4b: Query for Issue/Facility IDs (CUSIP/LX → issue_id or facility_id)

Query Solvas to determine:
1. Whether each CUSIP is a **bond** (issue_id) or **loan** (facility_id)
2. The issue_id or facility_id value for each CUSIP/LX identifier

**For Bonds (CUSIPs):**
```sql
-- Get issue_id for bonds by CUSIP
SELECT DISTINCT
    ev.cusip_number,
    ev.issue_id,
    ev.issue_name
FROM Solvas_AM.dbo.Entity_Issue_view ev
WHERE ev.cusip_number IN ({cusip_list})
    AND ev.issue_id IS NOT NULL
ORDER BY ev.cusip_number
```

**Example:**
```sql
SELECT DISTINCT
    ev.cusip_number,
    ev.issue_id,
    ev.issue_name
FROM Solvas_AM.dbo.Entity_Issue_view ev
WHERE ev.cusip_number IN (
    '00206RBM0',
    '02005NBH8',
    '12532TAA5',
    '14575AAA2',
    '21870QAB8'
)
    AND ev.issue_id IS NOT NULL
ORDER BY ev.cusip_number
```

**Example Results:**
```
cusip_number  issue_id  issue_name
------------  --------  -----------------------------------------
00206RBM0     63421     AT&T INC 4.3% 02/15/2030
02005NBH8     63422     Ally Financial Inc 5.75% 11/20/2025
12532TAA5     63423     Caesars Entertainment Inc 4.625% 10/15/2029
14575AAA2     63424     CarMax Auto Owner Trust 2023-4
21870QAB8     63425     Cowen CLO 2019-1 Ltd
```

**For Loans (LX Identifiers):**
```sql
-- Get facility_id for loans by LX identifier
SELECT DISTINCT
    ev.lx_identifier,
    ev.facility_id,
    ev.issue_name
FROM Solvas_AM.dbo.Entity_Issue_view ev
WHERE ev.lx_identifier IN ({lx_list})
    AND ev.facility_id IS NOT NULL
ORDER BY ev.lx_identifier
```

**Example:**
```sql
SELECT DISTINCT
    ev.lx_identifier,
    ev.facility_id,
    ev.issue_name
FROM Solvas_AM.dbo.Entity_Issue_view ev
WHERE ev.lx_identifier = 'LX232483'
    AND ev.facility_id IS NOT NULL
```

**Example Results:**
```
lx_identifier  facility_id  issue_name
-------------  -----------  --------------------------
LX232483       62875        Trestles Preference Share
```

**For Equities (Fund Units with no CUSIP/LX):**
```sql
-- Get issue_id (equity_id) for equities by issue name or issue_id
SELECT DISTINCT
    ev.issue_id,
    ev.issue_name,
    ev.lx_identifier,
    ev.cusip_number
FROM Solvas_AM.dbo.Entity_Issue_view ev
WHERE ev.issue_name LIKE '%{SECURITY_NAME}%'
    OR ev.issue_id = {ISSUE_ID}
ORDER BY ev.issue_name
```

**Example:**
```sql
SELECT DISTINCT
    ev.issue_id,
    ev.issue_name,
    ev.lx_identifier,
    ev.cusip_number
FROM Solvas_AM.dbo.Entity_Issue_view ev
WHERE ev.issue_name LIKE '%Kleopatra%'
    OR ev.issue_id = 57558
```

**Example Results:**
```
issue_id  issue_name                  lx_identifier  cusip_number
--------  --------------------------  -------------  ------------
57558     Kleopatra Finco S.a r.l.    NULL           NULL
```

**Verification:**
- If `lx_identifier IS NULL` AND `cusip_number IS NULL` → Confirmed equity
- Use `issue_id` as the `equity_id` parameter in stored procedures
- For equities, the `issue_id` field maps to the `equity_id` column in `deal_equity_market_value` table

**Action:** 
- Store the issue_id (for bonds), facility_id (for loans), or issue_id as equity_id (for equities) with each security identifier
- These values are shared across all portfolios for the same security
- You will need these for both DELETE (Step 5) and INSERT (Step 6) statements

---

#### Step 4c: Combine Mappings and Verify Against Existing Market Values

Now that you have entity_id and issue_id/facility_id values, verify they exist in the market value tables and identify which records need to be deleted:

**For Bonds:**
**Query Template:**
```sql
SELECT 
    d.entity_id,
    d.issue_id,
    ev.cusip_number, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value_indent
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE ev.cusip_number IN ('{CUSIP}')
    AND d.begin_date >= '{override_date}'
ORDER BY ev.cusip_number, e.deal_name
```

**Example:**
```sql
SELECT 
    d.entity_id,
    d.issue_id,
    ev.cusip_number, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value_indent
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE ev.cusip_number IN ('00206RBM0', '02005NBH8')
    AND d.begin_date >= '2026-06-30'
ORDER BY ev.cusip_number, e.deal_name
```

**Example Results:**
```
entity_id  issue_id  cusip_number  deal_name         begin_date  end_date  market_value_indent
---------  --------  ------------  ----------------  ----------  --------  -------------------
234        63421     00206RBM0     AAD1              2026-06-30  NULL      44.48
235        63421     00206RBM0     AAD2              2026-06-30  NULL      44.48
257        63421     00206RBM0     CLOMEN            2026-06-30  NULL      44.48
234        63422     02005NBH8     AAD1              2026-06-30  NULL      51.25
235        63422     02005NBH8     AAD2              2026-06-30  NULL      51.25
```

**For Loans:**
**Query Template:**
```sql
SELECT 
    d.entity_id,
    d.facility_id,
    ev.LX_identifier, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.pricing_type_1
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ('{LX_IDENTIFIER}')
    AND d.begin_date >= '{override_date}'
ORDER BY ev.LX_identifier, e.deal_name
```

**Example:**
```sql
SELECT 
    d.entity_id,
    d.facility_id,
    ev.LX_identifier, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.pricing_type_1
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier = 'LX232483'
    AND d.begin_date >= '2026-06-30'
ORDER BY ev.LX_identifier, e.deal_name
```

**Example Results:**
```
entity_id  facility_id  LX_identifier  deal_name      begin_date  end_date  pricing_type_1
---------  -----------  -------------  -------------  ----------  --------  --------------
257        62875        LX232483       CLOMEN         2026-06-30  NULL      115.05
419        62875        LX232483       COAST3         2026-06-30  NULL      115.05
```

**For Equities (Fund Units):**
**Query Template:**
```sql
SELECT 
    d.entity_id,
    d.equity_id,
    ev.issue_name, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value
FROM Solvas_AM.dbo.deal_equity_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON ev.issue_id = d.equity_id 
    AND ev.entity_id = e.entity_id
WHERE ev.issue_id = {ISSUE_ID}
    AND e.deal_name IN ({portfolio_list})
    AND d.begin_date >= '{override_date}'
ORDER BY ev.issue_name, e.deal_name, d.begin_date
```

**Example:**
```sql
SELECT 
    d.entity_id,
    d.equity_id,
    ev.issue_name, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value
FROM Solvas_AM.dbo.deal_equity_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON ev.issue_id = d.equity_id 
    AND ev.entity_id = e.entity_id
WHERE ev.issue_id = 57558  -- Kleopatra Finco S.a r.l.
    AND e.deal_name IN (
        'Trestles CLO 2017-1, Ltd MOS',
        'Trestles CLO II, Ltd MOS',
        'Trestles CLO III, Ltd MOS'
    )
    AND d.begin_date >= '2026-06-30'
ORDER BY ev.issue_name, e.deal_name, d.begin_date
```

**Example Results:**
```
entity_id  equity_id  issue_name                begin_date  end_date  market_value
---------  ---------  ------------------------  ----------  --------  ------------
295        233        Kleopatra Finco S.a r.l.  2026-06-30  NULL      1.15
298        233        Kleopatra Finco S.a r.l.  2026-06-30  NULL      1.15
299        233        Kleopatra Finco S.a r.l.  2026-06-30  NULL      1.15
295        233        Kleopatra Finco S.a r.l.  2026-07-01  NULL      1.15
298        233        Kleopatra Finco S.a r.l.  2026-07-01  NULL      1.15
```

**Note for Equities:** Results show **one row per entity per day** (not just one row per entity like bonds/loans), which is why DELETE workflow requires deleting every day from override date to current date.

**Action:** 
- **CRITICAL:** Store these complete result sets! You need:
  - entity_id (one per portfolio)
  - issue_id, facility_id, or equity_id (same for all portfolios with the same security)
  - begin_date (the dates that will be deleted)
  - Current prices (for validation)
- These exact records will be DELETED in Step 5
- You will use the entity_id and issue_id/facility_id/equity_id values to reconstruct INSERT statements in Step 6
- If Bond query returns results → it's a bond, proceed with bond workflow (Steps 5a, 6a)
- If Loan query returns results → it's a loan, proceed with loan workflow (Steps 5b, 6b)
- If Equity query returns results → it's an equity, proceed with equity workflow (Steps 5c, 6d)

---

#### Step 4d: Summary of Mappings

After completing Steps 4a-4c, you should have collected:

**Portfolio Mappings (from Step 4a):**
```
Portfolio/Deal Name → entity_id
AAD1                → 234
AAD2                → 235
CLOMEN              → 257
COAST3              → 419
```

**Security Mappings (from Step 4b):**
```
CUSIP/LX/Identifier → issue_id/facility_id/equity_id  → Type
00206RBM0           → 63421 (issue_id)                → Bond
02005NBH8           → 63422 (issue_id)                → Bond
LX232483            → 62875 (facility_id)             → Loan
Kleopatra (57558)   → 57558 (equity_id/issue_id)     → Equity (Fund Unit)
```

**Combined Data (from Step 4c):**
For each security + portfolio combination, you now have:
- entity_id (which portfolio)
- issue_id, facility_id, or equity_id (which security)
- begin_date (which date to delete)
- Current market_value_indent, pricing_type_1, or market_value (for validation)

**STORE ALL OF THIS DATA** - you will use it in Steps 5 and 6.

**Visual Example:**

For CUSIP 00206RBM0 (issue_id 63421):
```
entity_id: 234, issue_id: 63421, deal_name: AAD1, begin_date: 2026-06-30, current_price: 44.48
entity_id: 235, issue_id: 63421, deal_name: AAD2, begin_date: 2026-06-30, current_price: 44.48
entity_id: 257, issue_id: 63421, deal_name: CLOMEN, begin_date: 2026-06-30, current_price: 44.48
```

For LX identifier LX232483 (facility_id 62875):
```
entity_id: 257, facility_id: 62875, deal_name: CLOMEN, begin_date: 2026-06-30, current_price: 115.05
entity_id: 419, facility_id: 62875, deal_name: COAST3, begin_date: 2026-06-30, current_price: 115.05
```

For Kleopatra fund units (equity_id 233):
```
entity_id: 295, equity_id: 233, deal_name: Trestles CLO 2017-1, begin_date: 2026-06-30, current_price: 1.15
entity_id: 295, equity_id: 233, deal_name: Trestles CLO 2017-1, begin_date: 2026-07-01, current_price: 1.15
entity_id: 298, equity_id: 233, deal_name: Trestles CLO II, begin_date: 2026-06-30, current_price: 1.15
entity_id: 298, equity_id: 233, deal_name: Trestles CLO II, begin_date: 2026-07-01, current_price: 1.15
(Note: Equities have one row per entity per day, unlike bonds/loans which have one row per entity total)
```

**You will use these exact values to:**
- Generate DELETE statements in Step 5 (using entity_id, issue_id/facility_id/equity_id, begin_date)
- Generate INSERT statements in Step 6 (using entity_id, issue_id/facility_id/equity_id, override_date, override_price)

**Quick Entity ID Verification Query:**

Before proceeding to DELETE/INSERT, verify you have the correct entity IDs:

```sql
-- Verify price override mappings by entity_id list
SELECT 
    e.deal_name,
    i.CUSIP_number,
    i.issue_name,
    dmv.begin_date,
    dmv.market_value_indent
FROM Solvas_AM.dbo.deal_issue_market_value dmv
JOIN Solvas_AM.dbo.entity e ON dmv.entity_id = e.entity_id
JOIN Solvas_AM.dbo.issue i ON dmv.issue_id = i.issue_id
WHERE dmv.entity_id IN (234, 235, 257, 419)  -- Replace with your entity IDs
    AND dmv.begin_date = '2026-06-30'
ORDER BY e.deal_name, i.CUSIP_number
```

**Expected Results:** Should show one row per entity with correct deal names and current prices.

---

### Step 5: Generate Delete Statements
Generate SQL to delete existing market values for the override date range.

#### Step 5a: Bonds - Delete Existing Market Values

**Query Template:**
```sql
SELECT 
    CONCAT(
        'EXEC Solvas_am.dbo.deal_Issue_market_value_del',
        ' @user_id = ''', '{username}', '''',
        ', @entity_id = ', d.entity_id,
        ', @issue_id = ', d.issue_id,
        ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.cusip_number, 
    e.deal_name, 
    d.begin_date, 
    d.end_date
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE ev.cusip_number IN ('{CUSIP}')
    AND e.deal_name IN ({portfolio_list})
    AND d.begin_date >= '{override_date}'
```

**Example:**
```sql
SELECT 
    CONCAT(
        'EXEC Solvas_am.dbo.deal_Issue_market_value_del',
        ' @user_id = ''tcnguyen''',
        ', @entity_id = ', d.entity_id,
        ', @issue_id = ', d.issue_id,
        ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.cusip_number, 
    e.deal_name, 
    d.begin_date, 
    d.end_date
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE ev.cusip_number IN ('15477CAA3')
    AND e.deal_name IN (
        'APC Asset Development II, LP',
        'Aristotle Funds Series Trust - Aristotle Core Income Fund',
        'Pacific Select Fund - Core Income Portfolio'
    )
    AND d.begin_date >= '2026-06-30'
```

#### Step 5b: Loans - Delete Existing Market Values

**Query Template:**
```sql
SELECT 
    CONCAT(
        'EXEC Solvas_am.dbo.deal_facility_market_value_del',
        ' @user_id = ''', '{username}', '''',
        ', @entity_id = ', d.entity_id,
        ', @facility_id = ', d.facility_id,
        ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.LX_identifier, 
    e.deal_name, 
    d.begin_date, 
    d.end_date
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ('{CUSIP}')
    AND e.deal_name IN ({portfolio_list})
    AND d.begin_date >= '{override_date}'
```

**Example:**
```sql
SELECT 
    CONCAT(
        'EXEC Solvas_am.dbo.deal_facility_market_value_del',
        ' @user_id = ''tcnguyen''',
        ', @entity_id = ', d.entity_id,
        ', @facility_id = ', d.facility_id,
        ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.LX_identifier, 
    e.deal_name, 
    d.begin_date, 
    d.end_date
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ('LX232483')
    AND e.deal_name IN (
        'MissionSquare PLUS Fund, a stable value fund of VantageTrust III Master Collective Investment Fund (Loan)',
        'Trestles CLO V, Ltd MOS'
    )
    AND d.begin_date >= '2026-06-30'
```

**Action:** 
- Display the generated DELETE statements
- **DO NOT EXECUTE** - output for manual review

---

#### Step 5c: Equities (Fund Units) - Delete Existing Market Values

**🔍 How to Identify Equities:**
- Security has NO CUSIP identifier
- Security has NO LX_identifier  
- Usually has Bloomberg ID (e.g., BBG00FMFT6M9)
- Security type is "Fund Units" or "Equity"
- Found in `Entity_Issue_view` with `lx_identifier = NULL` and no `cusip_number`

**⚠️ CRITICAL DIFFERENCE for Equities:**
Unlike bonds and loans, equities require deleting records for **EVERY DAY** from the **start date to CURRENT DATE**, not just from the override date forward.

**Why This is Different:**
- Bonds/Loans: Delete only from override date forward (override date → future)
- **Equities: Delete from override date → TODAY** (inclusive)
- This ensures the entire historical range is cleared before applying the override

**Query Template for Equities:**
```sql
SELECT 
    d.entity_id,
    d.equity_id,
    ev.issue_name, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value
FROM Solvas_AM.dbo.deal_equity_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON ev.issue_id = d.equity_id 
    AND ev.entity_id = e.entity_id
WHERE ev.issue_id = {ISSUE_ID}
    AND e.deal_name IN ({portfolio_list})
    AND d.begin_date >= '{override_date}'
ORDER BY ev.issue_name, e.deal_name, d.begin_date
```

**Example:**
```sql
SELECT 
    d.entity_id,
    d.equity_id,
    ev.issue_name, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value
FROM Solvas_AM.dbo.deal_equity_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON ev.issue_id = d.equity_id 
    AND ev.entity_id = e.entity_id
WHERE ev.issue_id = 57558  -- Kleopatra Finco S.a r.l.
    AND e.deal_name IN (
        'Trestles CLO 2017-1, Ltd MOS',
        'Trestles CLO II, Ltd MOS',
        'Trestles CLO III, Ltd MOS'
    )
    AND d.begin_date >= '2026-06-30'
ORDER BY ev.issue_name, e.deal_name, d.begin_date
```

**Generating DELETE Statements for Equities:**

Unlike bonds/loans which generate one DELETE per existing record, equities require generating DELETE statements for **every calendar day** from override date to today:

```powershell
# Parameters from ticket
$overrideDate = Get-Date "2026-06-30"
$currentDate = Get-Date
$entityIds = @(295, 298, 299, 300, 301, 302, 303, 304)  # From Step 4
$equityId = 57558  # issue_id from Step 4b
$username = $env:USERNAME

# Generate DELETE statement for each day, for each entity
$deleteStatements = @()
for ($date = $overrideDate; $date -le $currentDate; $date = $date.AddDays(1)) {
    $dateStr = $date.ToString("MMMM dd yyyy") + " 12:00AM"
    foreach ($entityId in $entityIds) {
        $deleteStatements += "exec Solvas_am.dbo.deal_equity_market_value_del @user_id = '$username', @equity_id = $equityId, @entity_id = $entityId, @begin_date = '$dateStr'"
    }
}

Write-Host "Total DELETE statements: $($deleteStatements.Count)"
Write-Host "Date range: $($overrideDate.ToString('yyyy-MM-dd')) to $($currentDate.ToString('yyyy-MM-dd'))"
Write-Host "Days: $(($currentDate - $overrideDate).Days + 1)"
Write-Host "Entities: $($entityIds.Count)"
$deleteStatements | Out-String
```

**Example Output:**
```sql
exec Solvas_am.dbo.deal_equity_market_value_del @user_id = 'tcnguyen', @equity_id = 233, @entity_id = 295, @begin_date = 'June 30 2026 12:00AM'
exec Solvas_am.dbo.deal_equity_market_value_del @user_id = 'tcnguyen', @equity_id = 233, @entity_id = 298, @begin_date = 'June 30 2026 12:00AM'
exec Solvas_am.dbo.deal_equity_market_value_del @user_id = 'tcnguyen', @equity_id = 233, @entity_id = 299, @begin_date = 'June 30 2026 12:00AM'
...
exec Solvas_am.dbo.deal_equity_market_value_del @user_id = 'tcnguyen', @equity_id = 233, @entity_id = 295, @begin_date = 'July 21 2026 12:00AM'
exec Solvas_am.dbo.deal_equity_market_value_del @user_id = 'tcnguyen', @equity_id = 233, @entity_id = 298, @begin_date = 'July 21 2026 12:00AM'
exec Solvas_am.dbo.deal_equity_market_value_del @user_id = 'tcnguyen', @equity_id = 233, @entity_id = 299, @begin_date = 'July 21 2026 12:00AM'
```

**Calculation:**
- If override date = 2026-06-30 and current date = 2026-07-21
- Date range = 22 days (June 30 through July 21 inclusive)
- Entities = 8 portfolios
- **Total DELETE statements = 22 days × 8 entities = 176 statements**

**Action:** 
- Display the generated DELETE statements
- Include count summary (days × entities = total)
- **DO NOT EXECUTE** - output for manual review
- Save to file for Operations team

**Key Differences Summary:**

| Aspect | Bonds/Loans | Equities (Fund Units) |
|--------|-------------|----------------------|
| Identifier | CUSIP or LX_identifier | issue_id (no CUSIP/LX) |
| Table | Deal_Issue_Market_Value or deal_facility_market_value | deal_equity_market_value |
| Stored Procedure | deal_Issue_market_value_del or deal_facility_market_value_del | deal_equity_market_value_del |
| Parameter Name | @issue_id or @facility_id | @equity_id |
| DELETE Range | Override date → future records | Override date → TODAY (every day) |
| DELETE Count | One per existing record | Days × Entities |
| Price Field | market_value_indent or pricing_type_1 | market_value |

---

### Step 6: Generate Insert Statements

**🚨 CRITICAL:** After DELETE statements are executed in Step 5, the records won't exist anymore. Therefore, we must **construct** the INSERT statements using the entity_id and issue_id/facility_id values we collected from **Step 4**, NOT by querying the tables again.

**Why This Matters:**
- Step 5 DELETE statements remove records from the database
- Once deleted, you CANNOT query for entity_id and issue_id values anymore
- You MUST use the data you stored in Step 4c
- If you try to query after deletion, you will get ZERO results and cannot generate INSERT statements

**What You Need from Step 4:**
- `entity_id` - one per portfolio (from Step 4a and 4c)
- `issue_id` or `facility_id` - shared across all portfolios for same CUSIP/LX (from Step 4b and 4c)
- These values DO NOT CHANGE - they are permanent IDs in Solvas
- You apply the override price and override date from the ticket (NOT from the database)

**Construction Logic:**
1. Use the **same entity_id and issue_id/facility_id values** from Step 4 results
2. Apply the **override price from the ticket** (NOT from database)
3. Apply the **override date from the ticket** (NOT begin_date from database)
4. Generate one EXEC statement per entity_id

**Key Parameters:**
- `@user_id` = Current username (e.g., 'tcnguyen')
- `@row_version` = NULL (always)
- `@entity_id` = From Step 4 query results
- `@Issue_ID` or `@facility_id` = From Step 4 query results  
- `@begin_date` = Override date from ticket
- `@end_date` = NULL (always)
- `@market_value_indent` (bonds) or `@pricing_type_1` (loans) = Override price from ticket

#### Step 6a: Bonds - Construct INSERT Statements from Step 4 Data

**Using Step 4 query results, construct INSERT statements:**

```powershell
# From Step 4 Bond query, store the results
$step4BondResults = @(
    @{ entity_id = 233; issue_id = 42326; deal_name = "APC Asset Development II, LP" },
    @{ entity_id = 243; issue_id = 42326; deal_name = "Aristotle Core Income Fund" },
    @{ entity_id = 244; issue_id = 42326; deal_name = "Pacific Select Fund" },
    @{ entity_id = 251; issue_id = 42326; deal_name = "Another Portfolio" },
    @{ entity_id = 252; issue_id = 42326; deal_name = "Yet Another Portfolio" },
    @{ entity_id = 260; issue_id = 42326; deal_name = "Portfolio Six" },
    @{ entity_id = 268; issue_id = 42326; deal_name = "Portfolio Seven" }
)

# Construct INSERT statements
$username = $env:USERNAME
$overrideDate = '2026-06-30'
$overridePrice = 65.0000

foreach ($row in $step4BondResults) {
    $stmt = @"
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = '$username', @row_version = NULL, @entity_id = $($row.entity_id), @Issue_ID = $($row.issue_id), @begin_date = '$overrideDate', @end_date = NULL, @market_value_indent = $overridePrice
"@
    Write-Output $stmt
}
```

**Expected Output (one statement per entity_id from Step 4):**
```sql
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 233, @Issue_ID = 42326, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 65.0000
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 243, @Issue_ID = 42326, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 65.0000
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 244, @Issue_ID = 42326, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 65.0000
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 251, @Issue_ID = 42326, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 65.0000
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 252, @Issue_ID = 42326, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 65.0000
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 260, @Issue_ID = 42326, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 65.0000
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 268, @Issue_ID = 42326, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 65.0000
```

#### Step 6b: Loans - Construct INSERT Statements from Step 4 Data

**Using Step 4 Loan query results, construct INSERT statements:**

```powershell
# From Step 4 Loan query, store the results
$step4LoanResults = @(
    @{ entity_id = 284; facility_id = 42326; deal_name = "Trestles CLO V, Ltd MOS" },
    @{ entity_id = 285; facility_id = 42326; deal_name = "MissionSquare PLUS Fund" },
    @{ entity_id = 286; facility_id = 42326; deal_name = "Another Loan Portfolio" }
)

# Construct INSERT statements
$username = $env:USERNAME
$overrideDate = '2026-06-30'
$overridePrice = 66.0000

foreach ($row in $step4LoanResults) {
    $stmt = @"
EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] @user_id = '$username', @row_version = NULL, @entity_id = $($row.entity_id), @facility_id = $($row.facility_id), @begin_date = '$overrideDate', @end_date = NULL, @pricing_type_1 = $overridePrice
"@
    Write-Output $stmt
}
```

**Expected Output (one statement per entity_id from Step 4):**
```sql
EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 284, @facility_id = 42326, @begin_date = '2026-06-30', @end_date = NULL, @pricing_type_1 = 66.0000
EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 285, @facility_id = 42326, @begin_date = '2026-06-30', @end_date = NULL, @pricing_type_1 = 66.0000
EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 286, @facility_id = 42326, @begin_date = '2026-06-30', @end_date = NULL, @pricing_type_1 = 66.0000
```

**Action:**
- Construct one INSERT statement per entity_id from Step 4 results
- Use override price and override date from ticket (NOT from database)
- Display all generated INSERT statements for manual review
- **DO NOT EXECUTE** - output for manual review only

---

#### Step 6c: Practical Example - Complete Workflow from Step 4 to Step 6

This example demonstrates the complete flow from querying Solvas to generating INSERT statements.

**Scenario:** Apply price override for CUSIP 00206RBM0 to portfolios AAD1 and AAD2 on 2026-06-30 at price $44.48

**Step 4a Results - Portfolio Mapping:**
```sql
-- Query executed
SELECT entity_id, deal_name FROM Solvas_AM.dbo.entity 
WHERE deal_name IN ('AAD1', 'AAD2')

-- Results stored
entity_id: 234, deal_name: AAD1
entity_id: 235, deal_name: AAD2
```

**Step 4b Results - Security Mapping:**
```sql
-- Query executed
SELECT DISTINCT cusip_number, issue_id FROM Solvas_AM.dbo.Entity_Issue_view 
WHERE cusip_number = '00206RBM0' AND issue_id IS NOT NULL

-- Results stored
cusip_number: 00206RBM0, issue_id: 63421
```

**Step 4c Results - Combined Verification:**
```sql
-- Query executed (from Step 4c)
SELECT d.entity_id, d.issue_id, ev.cusip_number, e.deal_name, d.begin_date, d.market_value_indent
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id AND ev.entity_id = e.entity_id
WHERE ev.cusip_number = '00206RBM0' AND d.begin_date >= '2026-06-30'

-- Results stored
entity_id: 234, issue_id: 63421, deal_name: AAD1, begin_date: 2026-06-30, current_price: 44.48
entity_id: 235, issue_id: 63421, deal_name: AAD2, begin_date: 2026-06-30, current_price: 44.48
```

**Step 5 - DELETE Statements Generated:**
```sql
-- These will be executed to remove existing records
EXEC Solvas_am.dbo.deal_Issue_market_value_del @user_id = 'tcnguyen', @entity_id = 234, @issue_id = 63421, @begin_date = '2026-06-30'
EXEC Solvas_am.dbo.deal_Issue_market_value_del @user_id = 'tcnguyen', @entity_id = 235, @issue_id = 63421, @begin_date = '2026-06-30'
```

**Step 6 - INSERT Statements Generated (Using Step 4 Data):**
```sql
-- Using entity_id and issue_id from Step 4c results
-- Using override price $44.48 and override date 2026-06-30 from ticket
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 234, @Issue_ID = 63421, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 44.48
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 235, @Issue_ID = 63421, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 44.48
```

**Key Takeaways:**
1. ✅ Queried Solvas in Step 4 to get entity_id (234, 235) and issue_id (63421)
2. ✅ Stored these values BEFORE generating DELETE statements
3. ✅ Generated DELETE statements in Step 5 using stored values
4. ✅ Generated INSERT statements in Step 6 using the SAME stored values from Step 4
5. ✅ Did NOT re-query Solvas between Step 5 and Step 6 (records are deleted!)
6. ✅ Applied override price from ticket ($44.48), NOT from database

**What Would Go Wrong Without Step 4 Data:**
- ❌ After Step 5 DELETE, querying `Deal_Issue_Market_Value` would return 0 rows
- ❌ You would not know entity_id = 234 belongs to AAD1
- ❌ You would not know entity_id = 235 belongs to AAD2  
- ❌ You would not know issue_id = 63421 for CUSIP 00206RBM0
- ❌ You could NOT generate INSERT statements without this information
- ❌ The override workflow would FAIL

**Therefore:** ALWAYS query and store entity_id and issue_id/facility_id values in Step 4 BEFORE generating any DELETE or INSERT statements.

---

#### Step 6d: Equities (Fund Units) - Construct INSERT Statements from Step 4 Data

**Using Step 4 Equity query results, construct INSERT statements:**

```powershell
# From Step 4 Equity query, store the results
$step4EquityResults = @(
    @{ entity_id = 295; equity_id = 233; deal_name = "Trestles CLO 2017-1, Ltd MOS" },
    @{ entity_id = 298; equity_id = 233; deal_name = "Trestles CLO II, Ltd MOS" },
    @{ entity_id = 299; equity_id = 233; deal_name = "Trestles CLO III, Ltd MOS" },
    @{ entity_id = 300; equity_id = 233; deal_name = "Trestles CLO IV, Ltd MOS" },
    @{ entity_id = 301; equity_id = 233; deal_name = "Trestles CLO V, Ltd MOS" },
    @{ entity_id = 302; equity_id = 233; deal_name = "Trestles CLO VI, Ltd MOS" },
    @{ entity_id = 303; equity_id = 233; deal_name = "Trestles CLO VII, Ltd MOS" },
    @{ entity_id = 304; equity_id = 233; deal_name = "Trestles CLO VIII, Ltd MOS" }
)

# Construct INSERT statements
$username = $env:USERNAME
$overrideDate = '2026-06-30'
$overridePrice = 2.075

foreach ($row in $step4EquityResults) {
    $stmt = @"
EXEC Solvas_am.[dbo].[deal_equity_market_value_put] @user_id = '$username', @row_version = NULL, @entity_id = $($row.entity_id), @equity_id = $($row.equity_id), @begin_date = '$overrideDate', @end_date = NULL, @market_value = $overridePrice
"@
    Write-Output $stmt
}
```

**Expected Output (one statement per entity_id from Step 4):**
```sql
EXEC Solvas_am.[dbo].[deal_equity_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 295, @equity_id = 233, @begin_date = '2026-06-30', @end_date = NULL, @market_value = 2.075
EXEC Solvas_am.[dbo].[deal_equity_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 298, @equity_id = 233, @begin_date = '2026-06-30', @end_date = NULL, @market_value = 2.075
EXEC Solvas_am.[dbo].[deal_equity_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 299, @equity_id = 233, @begin_date = '2026-06-30', @end_date = NULL, @market_value = 2.075
EXEC Solvas_am.[dbo].[deal_equity_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 300, @equity_id = 233, @begin_date = '2026-06-30', @end_date = NULL, @market_value = 2.075
EXEC Solvas_am.[dbo].[deal_equity_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 301, @equity_id = 233, @begin_date = '2026-06-30', @end_date = NULL, @market_value = 2.075
EXEC Solvas_am.[dbo].[deal_equity_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 302, @equity_id = 233, @begin_date = '2026-06-30', @end_date = NULL, @market_value = 2.075
EXEC Solvas_am.[dbo].[deal_equity_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 303, @equity_id = 233, @begin_date = '2026-06-30', @end_date = NULL, @market_value = 2.075
EXEC Solvas_am.[dbo].[deal_equity_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 304, @equity_id = 233, @begin_date = '2026-06-30', @end_date = NULL, @market_value = 2.075
```

**Key Parameters for Equities:**
- `@user_id` = Current username
- `@row_version` = NULL (always)
- `@entity_id` = From Step 4 query results (one per portfolio)
- `@equity_id` = From Step 4 query results (issue_id, same for all portfolios)
- `@begin_date` = Override date from ticket (e.g., '2026-06-30')
- `@end_date` = NULL (always)
- `@market_value` = Override price from ticket (e.g., 2.075)

**Action:**
- Construct one INSERT statement per entity_id from Step 4 results
- Use override price and override date from ticket (NOT from database)
- Display all generated INSERT statements for manual review
- **DO NOT EXECUTE** - output for manual review only

---

---

### Step 7: Generate Comprehensive Markdown Report and Attach to Ticket

**CRITICAL:** This is the primary deliverable. Generate a complete markdown file containing all SQL statements organized by security and attach it to the ADO ticket for the support user to review and execute.

#### Step 7a: Generate Markdown Report

Create a comprehensive markdown file with the following structure:

**File naming:** `PriceOverride_{TicketNumber}_{OverrideDate}.md`

**Example:** `PriceOverride_82685_20260630.md`

**Markdown Template:**
```markdown
# Price Override Report - TASK #{TicketNumber}

**Generated:** {CurrentDateTime}  
**Override Date:** {OverrideDate}  
**Processed By:** {Username}  
**Total Securities:** {Count}

---

## Summary

This report contains SQL statements to apply price overrides for the following securities:

| CUSIP/LX ID | Type | Override Price | Inst ID | Portfolio Count |
|-------------|------|----------------|---------|-----------------|
| {CUSIP1} | Bond/Loan | {Price1} | {InstID1} | {Count1} |
| {CUSIP2} | Bond/Loan | {Price2} | {InstID2} | {Count2} |
| ... |

---

## ⚠️ IMPORTANT INSTRUCTIONS

**DO NOT execute these statements without review!**

**Execution Order:**
1. **Step 3 (if needed):** Execute tagging statements in MOS Production database
2. **Wait:** Verify tags applied successfully
3. **Step 5:** Execute DELETE statements in Solvas database
4. **Step 6:** Execute INSERT statements in Solvas database
5. **Verify:** Check override prices applied correctly in Solvas

**Database Connections:**
- **MOS Production:** `mos-sql-p.mos.siepe.local,52155` (Database: Core)
- **Solvas:** `SOLVAS-SQL-D.mos.siepe.local,52156` (Database: Solvas_AM)

---

## CUSIP: {CUSIP1}

**Security Type:** {Bond/Loan}  
**Inst ID:** {InstID}  
**Override Price:** {OverridePrice}  
**Override Date:** {OverrideDate}  
**Portfolios Affected:** {PortfolioCount}

### MOS Details
```
Inst Identifier ID: {instidentifierid}
Inst ID: {instid}
Identifier Type: {InstIdentifierTypeID}
```

### Step 3: MOS Tagging Statements (If Needed)

**Note:** Only execute if portfolios are missing tagid=5.

```sql
-- Portfolio: {Portfolio Name 1}
EXEC core.dbo.pTagMapI @Tagid = 5, @InstID = '{instid}', @PortfolioID = '{portfolioId1}', @EffFromDate = '{override_date}'

-- Portfolio: {Portfolio Name 2}
EXEC core.dbo.pTagMapI @Tagid = 5, @InstID = '{instid}', @PortfolioID = '{portfolioId2}', @EffFromDate = '{override_date}'
```

### Step 5: DELETE Statements

**Target:** Remove existing market values from {override_date} onwards

**Portfolios:**
- {Portfolio1}
- {Portfolio2}
- {Portfolio3}

```sql
-- Execute these DELETE statements in Solvas database
EXEC Solvas_am.dbo.deal_{Issue/facility}_market_value_del @user_id = '{username}', @entity_id = {entity_id1}, @{issue/facility}_id = {id1}, @begin_date = '{begin_date1}'
EXEC Solvas_am.dbo.deal_{Issue/facility}_market_value_del @user_id = '{username}', @entity_id = {entity_id2}, @{issue/facility}_id = {id2}, @begin_date = '{begin_date2}'
-- ... (one per portfolio)
```

### Step 6: INSERT Statements

**Action:** Apply override price {OverridePrice} for date {OverrideDate}

```sql
-- Execute these INSERT statements in Solvas database
EXEC Solvas_am.[dbo].[Deal_{issue/Facility}_market_value_put] @user_id = '{username}', @row_version = NULL, @entity_id = {entity_id1}, @{Issue_ID/facility_id} = {id1}, @begin_date = '{override_date}', @end_date = NULL, @{market_value_indent/pricing_type_1} = {OverridePrice}
EXEC Solvas_am.[dbo].[Deal_{issue/Facility}_market_value_put] @user_id = '{username}', @row_version = NULL, @entity_id = {entity_id2}, @{Issue_ID/facility_id} = {id2}, @begin_date = '{override_date}', @end_date = NULL, @{market_value_indent/pricing_type_1} = {OverridePrice}
-- ... (one per entity_id from Step 4)
```

**Summary for {CUSIP1}:**
- Total Tagging Statements: {count or "N/A - Already tagged"}
- Total DELETE Statements: {count}
- Total INSERT Statements: {count}

---

## CUSIP: {CUSIP2}
... (repeat structure for each security)

---

## Validation Queries

After executing the statements, run these queries to verify the overrides were applied:

### For Bonds:
```sql
-- Verification query to confirm override prices were applied
SELECT d.*
FROM solvas_am.dbo.deal_issue_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE e.deal_name LIKE '%'
    AND ev.cusip_number IN ('{CUSIP1}', '{CUSIP2}', '{CUSIP3}')
    AND d.begin_date >= '{override_date}'
ORDER BY d.begin_date DESC, ev.cusip_number;

-- Optional filters (uncomment if needed):
-- AND d.created_by = '{username}'
-- AND d.last_update_date >= '{override_date}'
```

**What to verify:**
- ✅ `begin_date` matches override date
- ✅ `market_value_indent` matches override prices
- ✅ `entity_id` matches expected portfolios
- ✅ `created_by` or `last_updated_by` shows correct user
- ✅ No unexpected future dates exist

### For Loans:
```sql
-- Verification query for facility/loan overrides
SELECT d.*
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE e.deal_name LIKE '%'
    AND ev.lx_identifier IN ('{LX_ID1}', '{LX_ID2}')
    AND d.begin_date >= '{override_date}'
ORDER BY d.begin_date DESC, ev.lx_identifier;

-- Optional filters (uncomment if needed):
-- AND d.created_by = '{username}'
-- AND d.last_update_date >= '{override_date}'
```

**What to verify:**
- ✅ `begin_date` matches override date
- ✅ `pricing_type_1` matches override prices
- ✅ `entity_id` matches expected portfolios
- ✅ `created_by` or `last_updated_by` shows correct user
- ✅ No unexpected future dates exist

### Extended Verification: Position Marks and SecMaster

After confirming Solvas prices, verify the override propagated to MOS Core and Reference databases:

#### Check Position Marks on MOS Core:
```sql
-- Verify position marks reflect override prices
SELECT DISTINCT 
  PositionMark, 
  p.refdatasetdate, 
  p.EffFromDate, 
  p.Tradedqty, 
  p.Portfolio, 
  ii.value AS CUSIP_LX
FROM core.dbo.vposition p 
JOIN core.dbo.vinstidentifiercurrent ii ON ii.instid = p.instid
WHERE p.refdatasetdate >= '{override_date}'
  AND p.Portfolio LIKE '%{Portfolio_Name_Pattern}%'
  AND ii.value IN ('{CUSIP1}', '{CUSIP2}', '{LX_ID1}')
ORDER BY p.refdatasetdate DESC, p.Portfolio
```

**What to verify:**
- ✅ `PositionMark` reflects override price (may lag by 1 day)
- ✅ `refdatasetdate` matches or follows override date
- ✅ Positions exist for expected portfolios

#### Check SecMaster Reference Prices:
```sql
-- Get InstID from identifier
SELECT instid 
FROM Reference.dbo.vinstidentifier 
WHERE Value = '{CUSIP_or_LX}' 
  AND RefDataSource LIKE '%MarkIT LoanXMarks%'  -- For loans
  -- or RefDataSource LIKE '%Market%'          -- For bonds

-- Check SecMaster price records
SELECT * 
FROM Reference.dbo.tInstPrice 
WHERE instid = {InstID_from_above}
  AND PriceDate >= '{override_date}'
ORDER BY PriceDate DESC
```

**What to verify:**
- ✅ Override price appears in `tInstPrice` for the date
- ✅ Subsequent dates show expected pricing (override or market)
- ✅ RefDataSource matches expected provider

---

## Appendix: Affected Portfolios

### {CUSIP1} - {Count} Portfolios
| Entity ID | Issue/Facility ID | Portfolio/Deal Name |
|-----------|-------------------|---------------------|
| {id1} | {fid1} | {name1} |
| {id2} | {fid2} | {name2} |
| ... |

### {CUSIP2} - {Count} Portfolios
... (repeat for each security)

---

## Report Metadata

**Ticket:** TASK #{TicketNumber}  
**Generated By:** {AgentName}  
**Timestamp:** {ISO8601DateTime}  
**Input Method:** {Direct Input / Excel Attachment}  
**Total SQL Statements:** {TotalCount}

---

**End of Report**
```

#### Step 7b: Save Markdown File

```powershell
# Define file path
$ticketId = {TicketNumber}
$overrideDate = "{OverrideDate}" -replace "-", ""  # Format: 20260630
$fileName = "PriceOverride_$ticketId_$overrideDate.md"
$outputPath = "C:\source\MD\AdminTools\Output\$fileName"

# Write markdown content to file
$markdownContent | Out-File -FilePath $outputPath -Encoding UTF8

Write-Host "✅ Markdown report generated: $fileName"
```

#### Step 7c: Attach File to ADO Ticket

```powershell
# Upload file as attachment to ADO ticket
$uploadUrl = az boards work-item relation add `
    --id $ticketId `
    --relation-type AttachedFile `
    --target-id (az boards attachment upload --file-path $outputPath --output tsv) `
    --org "https://siepe.visualstudio.com/" `
    --output json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Markdown report attached to TASK #$ticketId"
} else {
    Write-Host "❌ Failed to attach report to ticket"
}
```

#### Step 7d: Post Summary Comment to Ticket

After attaching the markdown file, post a summary comment to the ticket discussion:

```powershell
# Post brief comment referencing the detailed markdown report and SQL files
$comment = "🔧 Price override SQL generated - see attached report for investigation and execution instructions"

az boards work-item update --id $ticketId `
    --org "https://siepe.visualstudio.com/" `
    --discussion "$comment"

Write-Host "✅ Brief summary posted to TASK #$ticketId"
```

---

## Output Format

The skill generates the following outputs:

### 1. **Markdown File (Primary Deliverable)** ⭐
Create a comprehensive markdown file with:
- Complete report with all SQL statements organized by CUSIP
- Clear execution instructions and ordering
- Validation queries
- Portfolio/entity mapping tables
- **Attached to the ADO ticket for easy access**

**File naming:** `PriceOverride_{TicketNumber}_{OverrideDate}.md`

**Example:** `PriceOverride_82685_20260630.md`

### 2. **Separate SQL Files (ALWAYS GENERATE)** 🎯

**CRITICAL:** Always generate standalone SQL files for each statement type to make execution easier for the user.

**Required SQL Files:**

#### a) MOS Tagging Statements (Step 3) - ALWAYS GENERATE
**File:** `pTagMapI_Statements_{TicketNumber}.sql`

**Purpose:** Apply TagID 5 (price-exclusion) tags in MOS Core database

**Content:**
- Header with ticket number, override date, client name
- One section per portfolio/fund
- Comments showing CUSIP, override price, and security count
- pTagMapI EXEC statements with GO separator

**Example:**
```sql
-- ============================================================================
-- PRICE EXCLUSION TAG STATEMENTS - TICKET #84106
-- Generated: 2026-07-15
-- Purpose: Apply TagID 5 (price-exclusion) for approved override prices
-- Override Date: 2026-06-30
-- ============================================================================

-- AAD1 - APC Asset Development I, LP (PortfolioID: 500000090)
-- 1. CUSIP 89531GAC9 → $51.23
EXEC dbo.pTagMapI @tagid = 5, @instid = 500016570, @portfolioid = 500000090, @efffromdate = '2026-06-30', @user = 'MOS Support Agent - Ticket 84106';
GO
```

**Database:** MOS Production (mos-sql-p.mos.siepe.local,52155)  
**Schema:** Core.dbo

---

#### b) Solvas DELETE Statements (Step 5) - ALWAYS GENERATE
**File:** `Solvas_PriceOverride_DELETE_{TicketNumber}.sql`

**Purpose:** Remove existing market values from Solvas before applying overrides

**Content:**
- Header with ticket number and override date
- One section per CUSIP/LX identifier
- Comments showing portfolio names and dates
- deal_Issue_market_value_del or deal_facility_market_value_del EXEC statements

**Example:**
```sql
-- ============================================================================
-- SOLVAS PRICE OVERRIDE DELETE STATEMENTS - TICKET #84106
-- Generated: 2026-07-15
-- Purpose: Delete existing market values before applying overrides
-- Override Date: 2026-06-30
-- ============================================================================

-- CUSIP 00206RBM0 - AAD1
EXEC Solvas_am.dbo.deal_Issue_market_value_del @user_id = 'tcnguyen', @entity_id = 234, @issue_id = 63421, @begin_date = '2026-06-30'
```

**Database:** Solvas (SOLVAS-SQL-D.mos.siepe.local,52156)  
**Schema:** Solvas_AM.dbo

---

#### c) Solvas INSERT Statements (Step 6) - ALWAYS GENERATE
**File:** `Solvas_PriceOverride_INSERT_{TicketNumber}.sql`

**Purpose:** Apply override prices in Solvas database

**Content:**
- Header with ticket number, override date, and override prices
- One section per CUSIP/LX identifier
- Comments showing portfolio names and override prices
- Deal_issue_market_value_put or Deal_Facility_market_value_put EXEC statements

**Example:**
```sql
-- ============================================================================
-- SOLVAS PRICE OVERRIDE INSERT STATEMENTS - TICKET #84106
-- Generated: 2026-07-15
-- Purpose: Apply override prices in Solvas
-- Override Date: 2026-06-30
-- ============================================================================

-- CUSIP 00206RBM0 → Override Price: $44.48
-- AAD1 (entity_id: 234)
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 234, @Issue_ID = 63421, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 44.48
```

**Database:** Solvas (SOLVAS-SQL-D.mos.siepe.local,52156)  
**Schema:** Solvas_AM.dbo

---

### 3. Console Output
Display key summary information in the conversation:
- Count of securities processed
- Count of SQL statements generated (by type)
- File paths for all generated SQL files
- Link to attached markdown file
- Next steps for the user

**Example Console Output:**
```
✅ Price Override Investigation Complete - Ticket #84106

Files Generated:
  📄 PriceOverride_84106_20260630.md (comprehensive report)
  📝 pTagMapI_Statements_84106.sql (12 MOS tagging statements)
  📝 Solvas_PriceOverride_DELETE_84106.sql (12 DELETE statements)
  📝 Solvas_PriceOverride_INSERT_84106.sql (12 INSERT statements)

SQL Summary:
  - MOS Tagging (Step 3): 12 statements
  - Solvas DELETE (Step 5): 12 statements
  - Solvas INSERT (Step 6): 12 statements
  - Total: 36 SQL statements

Execution Order:
  1. pTagMapI_Statements_84106.sql → MOS Production
  2. Solvas_PriceOverride_DELETE_84106.sql → Solvas
  3. Solvas_PriceOverride_INSERT_84106.sql → Solvas

All files saved to: C:\source\MD\AdminTools\Output\
```

---

## Important Notes

### Required Deliverables
**CRITICAL:** Every price override investigation must generate ALL of the following files:

1. **Comprehensive Markdown Report** - `PriceOverride_{TicketNumber}_{OverrideDate}.md`
   - Contains all SQL statements, instructions, and validation queries
   - Primary reference document for the user
   - Must be attached to ADO ticket

2. **MOS Tagging SQL** - `pTagMapI_Statements_{TicketNumber}.sql`
   - ALWAYS generate, even if only 1 security
   - Contains pTagMapI EXEC statements for TagID 5
   - Executed first in MOS Production database

3. **Solvas DELETE SQL** - `Solvas_PriceOverride_DELETE_{TicketNumber}.sql`
   - ALWAYS generate
   - Contains market value deletion statements
   - Executed second in Solvas database

4. **Solvas INSERT SQL** - `Solvas_PriceOverride_INSERT_{TicketNumber}.sql`
   - ALWAYS generate
   - Contains override price insertion statements
   - Executed last in Solvas database

**Why Separate SQL Files Matter:**
- Users can execute files directly without copying from markdown
- Reduces copy-paste errors
- Makes batch execution easier
- Clear separation of MOS vs Solvas operations
- Explicit execution order (file 1 → file 2 → file 3)

### Primary Deliverable
**CRITICAL:** The markdown report file attached to the ADO ticket is the primary deliverable. This ensures the support user has a complete, organized reference document with all SQL statements and instructions. All four files should be saved to `C:\source\MD\AdminTools\Output\` and attached to the ticket.

### Do Not Execute
**CRITICAL:** This skill should ONLY generate SQL statements, never execute them. All statements must be reviewed and manually executed by the user.

### Date Format
Both formats are acceptable:
- `'2026-06-30'`
- `'June 30 2026 12:00AM'`

### Portfolio Name List
The portfolio/deal names should come from the Excel file provided by operations. Build the `IN (...)` clause using the portfolio names associated with each CUSIP.

### Username
Use the current username for `@user_id` parameter (typically obtained from environment or user context).

### Validation
Before generating statements, verify:
- CUSIP exists in MOS (Step 1 returns results)
- Inst ID matches between input and MOS query
- Portfolio names match between Excel and Solvas database

---

## Reference

**ADO Wiki:** https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/6226/MOS-Ops-Price-Overrides

**Related Task:** TASK 82685

---

## Example Workflows

### Example 1: Direct Field Input (Single CUSIP)

**Ticket Description Input:**
```
Price override request:
CUSIP: LX232483
Override Price: 66.0000
Override Date: 2026-06-30
Inst ID: 500009880
Portfolios: Trestles CLO V, Ltd MOS
```

**Skill Processing:**
1. ✅ Parse direct input from ticket description
2. Query MOS to confirm instid = 500009880
3. Check tagging status for portfolios
4. Query Solvas for entity_id and facility_id mappings
5. Determine it's a loan (LX identifier)
6. Generate tagging statements (pTagMapI)
7. Generate DELETE statements for existing market values
8. Generate INSERT statements with override price 66.0000
9. Create comprehensive markdown report
10. Create separate SQL files (pTagMapI, DELETE, INSERT)
11. Attach all files to TASK #82685
12. Post summary comment to ticket discussion

**Output:** 
- `PriceOverride_82685_20260630.md` - Comprehensive report
- `pTagMapI_Statements_82685.sql` - MOS tagging statements
- `Solvas_PriceOverride_DELETE_82685.sql` - DELETE statements  
- `Solvas_PriceOverride_INSERT_82685.sql` - INSERT statements
- All files attached to ticket

---

### Example 2: Direct Field Input (Multiple CUSIPs - Table Format)

**Ticket Description Input:**
```
| CUSIP     | Override Price | Inst ID   | Override Date | Portfolio/Deal Name                                    |
|-----------|----------------|-----------|---------------|-------------------------------------------------------|
| 68610BAA2 | 30.4375        | 500016222 | 2026-06-30    | Pacific Select Fund - Core Income Portfolio           |
| 15477CAA3 | 65.0000        | 500010629 | 2026-06-30    | Aristotle Funds Series Trust - Aristotle Core Income Fund |
| LX232483  | 66.0000        | 500009880 | 2026-06-30    | Trestles CLO V, Ltd MOS                               |
```

**Skill Processing:**
1. ✅ Parse table format from ticket description
2. Process each CUSIP individually (3 CUSIPs)
3. Query Solvas for entity_id and issue_id/facility_id mappings
4. Generate statements organized by CUSIP
5. Combine all outputs into markdown report and separate SQL files
6. Attach all files to ticket
7. Post summary comment with execution order

**Output:** 
- `PriceOverride_82685_20260630.md` - Report with 3 CUSIP sections
- `pTagMapI_Statements_82685.sql` - MOS tagging for all 3 securities
- `Solvas_PriceOverride_DELETE_82685.sql` - DELETE for all 3 securities
- `Solvas_PriceOverride_INSERT_82685.sql` - INSERT for all 3 securities
- All files attached to ticket

---

### Example 3: Excel Attachment (Bulk - 10+ CUSIPs)

**Excel File Structure:**
| CUSIP     | Override Price | Inst ID   | Override Date | Portfolio/Deal Name                |
|-----------|----------------|-----------|---------------|------------------------------------|
| 68610BAA2 | 30.4375        | 500016222 | 2026-06-30    | Pacific Select Fund                |
| 15477CAA3 | 65.0000        | 500010629 | 2026-06-30    | Aristotle Core Income Fund         |
| 48903LAA1 | 72.5000        | 500012345 | 2026-06-30    | Core Income Portfolio              |
| ... (8 more rows) ...

**Skill Processing:**
1. ✅ Download and parse Excel attachment
2. Loop through all rows (10+ CUSIPs)
3. Query Solvas for all entity_id and issue_id/facility_id mappings
4. Process each CUSIP with batch queries where possible
5. Generate comprehensive markdown report and separate SQL files
6. Attach all files to ticket
7. Post summary comment with statement counts

**Output:** 
- `PriceOverride_82685_20260630.md` - Report with 10+ CUSIP sections
- `pTagMapI_Statements_82685.sql` - MOS tagging for all securities
- `Solvas_PriceOverride_DELETE_82685.sql` - DELETE for all securities
- `Solvas_PriceOverride_INSERT_82685.sql` - INSERT for all securities
- All files attached to ticket
- Summary shows total statement counts per type

---

## Error Handling

If any step fails, document the error and provide guidance:
- CUSIP not found in MOS → verify CUSIP format and Inst ID
- No results in Solvas → verify portfolio names and override date
- Multiple begin_dates found → list all and ask user which to override
