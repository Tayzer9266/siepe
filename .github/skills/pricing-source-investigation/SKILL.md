# Pricing Source Investigation Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration

## Purpose
Systematic investigation methodology for diagnosing pricing anomalies caused by vendor data source failures, focusing on position mark spikes, flat pricing defaults, and price source gaps. Enhanced with screenshot analysis for price charts and vendor data visualizations.

## When to Use This Skill
- Positions suddenly marked at 100 (flat/par) when they shouldn't be
- Unexpected spikes or drops in position marks across a portfolio
- Client reports pricing inconsistencies between dates
- Mass position mark changes affecting specific instrument types (loans, bonds, etc.)
- Pricing appears incorrect but unclear which vendor source failed

## Investigation Methodology

### Phase 0: Analyze Ticket Attachments and Wiki Procedures

**Step 0.1: Download and Analyze Screenshots**
```powershell
# Get ticket and download all attachments
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

Write-Host "Analyzing $($imageFiles.Count) screenshot(s)..." -ForegroundColor Cyan

# Agent uses view_image to analyze:
# - Price spike charts showing sudden position mark changes
# - Vendor price comparison tables
# - Position mark trend graphs
# - Error messages from pricing systems
# - Data quality reports with highlighted anomalies
```

**Step 0.2: Fetch Wiki Documentation**
```powershell
$wikiPath = "/Vendor-Pricing-Sources"  # Update with actual wiki path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_PricingSources.md" -Encoding UTF8

Write-Host "✓ Pricing source procedures loaded" -ForegroundColor Green
```

### Phase 1: Confirm the Anomaly
**Database:** `Core`

**Step 1.1: Quantify the Position Mark Change**
```sql
SELECT 
    RefDataSetDate,
    COUNT(*) AS TotalPositions,
    SUM(CASE WHEN PositionMark = 100 THEN 1 ELSE 0 END) AS FlatPositions,
    COUNT(DISTINCT InstID) AS UniqueInstruments,
    MIN(PositionMark) AS MinMark,
    MAX(PositionMark) AS MaxMark,
    AVG(PositionMark) AS AvgMark
FROM Core.dbo.vPosition
WHERE Portfolio = '[PORTFOLIO_NAME]'
    AND RefDataSetDate IN ('[DATE_BEFORE]', '[DATE_ISSUE]')
GROUP BY RefDataSetDate
ORDER BY RefDataSetDate
```

**What to look for:**
- Sudden jump in flat (100) positions
- Min/Max range narrowing (indicates defaults)
- Average mark shift

---

### Phase 2: Identify Affected Securities
**Database:** `Core`

**Step 2.1: Find Positions That Changed**
```sql
SELECT TOP 50
    p_issue.InstID,
    i.Name AS InstrumentName,
    it.Name AS InstType,
    CAST(p_before.PositionMark AS DECIMAL(10,3)) AS Mark_Before,
    CAST(p_issue.PositionMark AS DECIMAL(10,3)) AS Mark_Issue,
    CAST(p_issue.PositionMark - ISNULL(p_before.PositionMark, 0) AS DECIMAL(10,3)) AS Change,
    ii.Value AS CUSIP
FROM Core.dbo.vPosition p_issue
LEFT JOIN Core.dbo.vPosition p_before 
    ON p_before.InstID = p_issue.InstID 
    AND p_before.Portfolio = p_issue.Portfolio
    AND p_before.RefDataSetDate = '[DATE_BEFORE]'
INNER JOIN Core.dbo.vInst i ON i.InstID = p_issue.InstID
INNER JOIN Core.dbo.vInstType it ON it.InstTypeID = i.InstTypeID
LEFT JOIN Core.dbo.vInstIdentifierCurrent ii 
    ON ii.InstID = p_issue.InstID 
    AND ii.InstIdentifierType = 'CUSIP'
WHERE p_issue.Portfolio = '[PORTFOLIO_NAME]'
    AND p_issue.RefDataSetDate = '[DATE_ISSUE]'
    AND p_issue.PositionMark = 100  -- Or other anomaly condition
    AND (p_before.PositionMark IS NULL OR p_before.PositionMark <> 100)
ORDER BY p_before.PositionMark
```

**What to look for:**
- Common instrument type (Term Loan, Bond, etc.)
- Similar change magnitude
- Pattern in CUSIPs or instrument names
- Collect 5-10 sample CUSIPs for deeper investigation

---

### Phase 3: Check Vendor Pricing Availability
**Database:** `Reference`

**Step 3.1: Find Pricing Gaps (CRITICAL QUERY)**
```sql
SELECT 
    ii.Value AS CUSIP,
    rds.Name AS PriceSource,
    COUNT(DISTINCT p.PriceDate) AS DaysWithPrices,
    MAX(p.PriceDate) AS LastPriceDate,
    MAX(CASE WHEN p.PriceDate = '[DATE_BEFORE]' THEN CAST(p.Bid AS DECIMAL(10,3)) END) AS Bid_Before,
    MAX(CASE WHEN p.PriceDate = '[DATE_ISSUE]' THEN CAST(p.Bid AS DECIMAL(10,3)) END) AS Bid_Issue
FROM Reference.dbo.vInstIdentifierCurrent ii
LEFT JOIN Reference.dbo.vInstPriceCurrentRaw p 
    ON p.InstID = ii.InstID 
    AND p.PriceDate >= '[START_OF_MONTH]'
    AND p.PriceDate <= '[DATE_ISSUE]'
LEFT JOIN Reference.dbo.vRefDataSource rds ON rds.RefDataSourceID = p.RefDataSourceID
WHERE ii.Value IN ('[CUSIP1]', '[CUSIP2]', '[CUSIP3]', '[CUSIP4]', '[CUSIP5]')
    AND ii.InstIdentifierType = 'CUSIP'
GROUP BY ii.Value, rds.Name
ORDER BY ii.Value, rds.Name
```

**What to look for:**
- **Smoking Gun:** NULL PriceSource rows with DaysWithPrices = 0 (missing pricing)
- One price source has data, another doesn't
- LastPriceDate stopped before issue date
- Bid_Issue is NULL but Bid_Before had value

**Example Result Pattern:**
```
CUSIP      PriceSource                   DaysWithPrices  Bid_Before  Bid_Issue
---------  ---------------------------   --------------  ----------  ---------
11132VAY5  (null)                                     0        NULL       NULL  ❌ PRIMARY FAILED
11132VAY5  Aristotle|LSEG                           14      98.193     98.227  ✅ ALTERNATIVE HAS DATA
```

---

### Phase 4: Identify All Price Sources
**Database:** `Reference`

**Step 4.1: List Relevant Price Sources**
```sql
SELECT 
    RefDataSourceID,
    Name
FROM Reference.dbo.vRefDataSource
WHERE Name LIKE '%[KEYWORD1]%'   -- e.g., 'Markit', 'LSEG', 'ICE', 'loan'
   OR Name LIKE '%[KEYWORD2]%'
   OR Name LIKE '%[CLIENT]%'
ORDER BY Name
```

**What to look for:**
- Primary price source name (e.g., "Siepe-SecurityMaster|Price|MarkIt")
- Alternative sources (e.g., "Aristotle|LSEG")
- Client-specific overrides (e.g., "Garnet CLO 5|FundOverride")

---

### Phase 5: Verify the Failed Source
**Database:** `Reference`

**Step 5.1: Confirm Zero Records from Primary Source**
```sql
SELECT 
    ii.Value AS CUSIP,
    p.PriceDate,
    CAST(p.Bid AS DECIMAL(10,3)) AS Bid,
    CAST(p.Ask AS DECIMAL(10,3)) AS Ask
FROM Reference.dbo.vInstPriceCurrentRaw p
INNER JOIN Reference.dbo.vRefDataSource rds ON rds.RefDataSourceID = p.RefDataSourceID
INNER JOIN Reference.dbo.vInstIdentifierCurrent ii ON ii.InstID = p.InstID
WHERE ii.Value IN ('[CUSIP1]', '[CUSIP2]', '[CUSIP3]')
    AND ii.InstIdentifierType = 'CUSIP'
    AND rds.Name = '[PRIMARY_PRICE_SOURCE_NAME]'
    AND p.PriceDate >= '[DATE_RANGE_START]'
ORDER BY ii.Value, p.PriceDate DESC
```

**Expected Result if Source Failed:** **ZERO rows returned**

---

### Phase 6: Verify Alternative Source Has Data
**Database:** `Reference`

**Step 6.1: Check Alternative Source**
```sql
SELECT 
    p.PriceDate,
    rds.Name AS PriceSource,
    CAST(p.Bid AS DECIMAL(10,3)) AS Bid,
    CAST(p.Ask AS DECIMAL(10,3)) AS Ask
FROM Reference.dbo.vInstPriceCurrentRaw p
INNER JOIN Reference.dbo.vRefDataSource rds ON rds.RefDataSourceID = p.RefDataSourceID
INNER JOIN Reference.dbo.vInstIdentifierCurrent ii ON ii.InstID = p.InstID
WHERE ii.Value = '[SAMPLE_CUSIP]'
    AND ii.InstIdentifierType = 'CUSIP'
    AND rds.Name = '[ALTERNATIVE_PRICE_SOURCE]'
    AND p.PriceDate >= '[DATE_RANGE_START]'
ORDER BY p.PriceDate DESC
```

**What to look for:**
- Continuous pricing through issue date
- Reasonable bid/ask values matching expected market range
- If alternative has data but primary doesn't → **Source failure confirmed**

---

## Root Cause Determination Logic

### Pattern 1: Primary Source Failed, No Fallback
- **Symptoms:** Positions → 100 (flat), primary source has zero records
- **Cause:** Vendor feed failure + no fallback configured
- **Action:** Investigate vendor file delivery, SSIS import logs

### Pattern 2: All Sources Missing Data
- **Symptoms:** Multiple price sources show no data
- **Cause:** Instrument delisting, cusip change, data normalization issue
- **Action:** Check instrument status, identifier mapping

### Pattern 3: Wrong Source Configured
- **Symptoms:** Primary source empty, alternative has data, but not used
- **Cause:** Price weighting configuration issue
- **Action:** Review price source configuration for fund/ledger

### Pattern 4: Stale/Rolled Price
- **Symptoms:** LastPriceDate several days before issue date
- **Cause:** Price rollover not working, vendor stopped providing
- **Action:** Check rollover logic, vendor subscription status

---

## Next Steps After Root Cause Identification

### Immediate Actions
1. **Document Findings:** Create investigation report with queries and evidence
2. **Notify Stakeholders:** Update ticket with root cause and impact
3. **Check Import Logs:** Use `check-ssis-errors` skill to find import failures
4. **Verify File Delivery:** Check SFTP folders for missing vendor files

### Short-term Resolution
5. **If File Missing:** Contact vendor for redelivery
6. **If Import Failed:** Rerun Generic Import Job and normalization
7. **If Unrecoverable:** Apply manual price overrides (use `price-overrides` skill)

### Long-term Prevention
8. **Configure Fallback:** Add secondary price source to fund configuration
9. **Implement Monitoring:** Create alert for pricing record count drops
10. **Document Dependencies:** Map which funds use which price sources

---

## Key Database Objects Reference

### Core Database
- `Core.dbo.vPosition` - Position marks by date/portfolio/instrument
- `Core.dbo.vInst` - Instrument master table
- `Core.dbo.vInstType` - Instrument type definitions
- `Core.dbo.vInstIdentifierCurrent` - CUSIP/ISIN/SEDOL mappings

### Reference Database
- `Reference.dbo.vInstPriceCurrentRaw` - **CRITICAL** - All vendor pricing
- `Reference.dbo.vRefDataSource` - Price source definitions (Markit, LSEG, ICE, etc.)
- `Reference.dbo.vInstIdentifierCurrent` - Instrument identifier lookups

### Feeds Database
- `Feeds.dbo.vGenericImportJob` - Import job definitions
- `Feeds.dbo.vRefDataImport` - Import execution history

---

## Example Investigation: Garnet CLO 5 Flat Position Spike (July 2026)

**Issue:** 50 Term Loans went from 96-99 range → 100.000 flat on 7/21/2026

**Investigation Results:**
```sql
-- Step 3 revealed the smoking gun:
CUSIP      PriceSource                        DaysWithPrices  Bid_7_20  Bid_7_21
---------  --------------------------------   --------------  --------  --------
11132VAY5  (null)                                          0      NULL      NULL  ❌
11132VAY5  Aristotle|LSEG                                 14    98.193    98.227  ✅
69425BAD9  (null)                                          0      NULL      NULL  ❌
W5000CAD9  (null)                                          0      NULL      NULL  ❌
```

**Root Cause:** `Siepe-SecurityMaster|Price|MarkIt` (RefDataSourceID: 1000000123) import failed on 7/21. No pricing records imported for Term Loans. MOS defaulted to 100 (par).

**Resolution:** 
1. Verified Markit LoanXMarks file missing from SecurityMaster
2. Contacted vendor for file redelivery
3. Configured `Aristotle|LSEG` as fallback price source
4. Applied manual overrides for 50 affected CUSIPs

---

## Common Price Sources by Instrument Type

### Loans (Term Loan, Delayed Draw)
- `Siepe-SecurityMaster|Price|MarkIt` (Markit LoanXMarks)
- `Aristotle|LSEG` (LSEG Loan Pricing)
- `Markit` (Legacy)

### Bonds (Corporate, Government)
- `Markit` (Markit Bond Pricing)
- `ICE` (ICE Data Services)
- `LSEG` (LSEG Bond Data)

### Equities
- `ICE` (NYSE/NASDAQ feeds)
- Various exchange-specific sources

### Derivatives
- `Markit` (CDS, Options)
- `ICE` (Futures)

---

## Tips for Efficient Investigation

1. **Always start with Phase 3 (Pricing Availability)** - This is the fastest way to find the gap
2. **Use 5-10 sample CUSIPs** - Don't check all affected securities, representative sample is enough
3. **Check date ranges carefully** - Use ± 5 days to see patterns
4. **Look for NULLs in LEFT JOINs** - These reveal missing data
5. **Compare multiple price sources** - One source having data proves vendor availability
6. **Document RefDataSourceID** - Easier to track than long source names

---

## Related Skills
- `check-ssis-errors` - Diagnose import job failures
- `price-overrides` - Apply manual pricing corrections
- `bulk-price-validation` - Compare prices across multiple sources

---

## Skill Metadata
**Category:** Price Investigation  
**Complexity:** Advanced  
**Typical Duration:** 30-60 minutes  
**Prerequisites:** Access to MOS Prod, understanding of pricing architecture  
**Last Updated:** 2026-07-23  
**Author:** MOS Support Team
