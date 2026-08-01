# Data Quality Investigation Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration

## Purpose
Investigate and resolve data quality issues including missing identifiers, duplicate records, calculation discrepancies, and reference data errors. Enhanced with screenshot analysis for data quality reports and validation errors. Ensures data integrity and accuracy across MOS systems.

## When to Use This Skill
- Missing or incorrect identifiers (CUSIP, ISIN, Bloomberg)
- Duplicate records in tables
- Calculation errors (market value, cost basis, gain/loss)
- Bad reference data (issuers, legal entities, transaction types)
- Keywords: data quality, missing data, duplicate, incorrect data, validation, calculation error

---

## Investigation Methodology

### Phase 0: Analyze Data Quality Screenshots and Wiki

**Step 0.1: Screenshot Analysis**
```powershell
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - Table snapshots showing data errors (NULLs, duplicates)
# - Excel validation reports with highlighted issues
# - Error screenshots from data quality checks
# - Missing identifier reports
```

**Step 0.2: Fetch Wiki Documentation**
```powershell
$wikiPath = "/Data-Quality-Standards"  # Update with actual path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_DataQuality.md" -Encoding UTF8
```

### Phase 1: Identify Data Quality Issue Type

**Issue Types:**
1. **Missing Identifiers:** Instruments lack CUSIP, ISIN, Bloomberg IDs
2. **Duplicate Records:** Same data appears multiple times
3. **Calculation Discrepancies:** Computed values incorrect
4. **Reference Data Errors:** Master data (issuers, entities) wrong

---

### Phase 2: Missing Identifiers Investigation

#### Step 2.1: Identify Missing Identifiers

```sql
-- Find instruments missing key identifiers
SELECT 
    inst.InstID,
    inst.InstrumentName,
    inst.AssetType,
    CASE WHEN cusip.IdentifierValue IS NULL THEN 'Missing' ELSE cusip.IdentifierValue END AS CUSIP,
    CASE WHEN isin.IdentifierValue IS NULL THEN 'Missing' ELSE isin.IdentifierValue END AS ISIN,
    CASE WHEN bb.IdentifierValue IS NULL THEN 'Missing' ELSE bb.IdentifierValue END AS BloombergID,
    CASE WHEN sedol.IdentifierValue IS NULL THEN 'Missing' ELSE sedol.IdentifierValue END AS SEDOL
FROM Reference.dbo.vInst inst
LEFT JOIN Reference.dbo.vInstIdentifierCurrent cusip 
    ON inst.InstID = cusip.InstID AND cusip.IdentifierType = 'CUSIP'
LEFT JOIN Reference.dbo.vInstIdentifierCurrent isin 
    ON inst.InstID = isin.InstID AND isin.IdentifierType = 'ISIN'
LEFT JOIN Reference.dbo.vInstIdentifierCurrent bb 
    ON inst.InstID = bb.InstID AND bb.IdentifierType = 'Bloomberg'
LEFT JOIN Reference.dbo.vInstIdentifierCurrent sedol 
    ON inst.InstID = sedol.InstID AND sedol.IdentifierType = 'SEDOL'
WHERE inst.Active = 1
    AND (cusip.IdentifierValue IS NULL OR isin.IdentifierValue IS NULL OR bb.IdentifierValue IS NULL)
ORDER BY inst.InstrumentName
```

#### Step 2.2: Research Missing Identifiers

**Sources for Identifier Lookup:**
1. **Bloomberg Terminal:** Look up by instrument name
2. **Vendor Feeds:** Check Markit, LSEG, ICE feeds
3. **Security Master:** Query SecurityMaster database
4. **Manual Research:** Google, issuer website, FINRA, SEC EDGAR

#### Step 2.3: Add Missing Identifiers

```sql
-- Insert missing identifier
INSERT INTO Reference.dbo.tInstIdentifier (
    InstID, IdentifierType, IdentifierValue, Source, EffectiveDate, Active
)
VALUES (
    {InstID},
    'CUSIP',  -- or 'ISIN', 'Bloomberg', 'SEDOL'
    '{IdentifierValue}',
    'Manual Entry',
    GETDATE(),
    1
)
```

---

### Phase 3: Duplicate Records Investigation

#### Step 3.1: Find Duplicate Records

```sql
-- Find duplicate transactions (by date, portfolio, amount)
SELECT 
    TransactionDate,
    PortfolioID,
    Amount,
    TransactionType,
    COUNT(*) AS DuplicateCount,
    STRING_AGG(CAST(TransactionID AS VARCHAR), ',') AS TransactionIDs
FROM CashRec.tTransaction
GROUP BY TransactionDate, PortfolioID, Amount, TransactionType
HAVING COUNT(*) > 1
ORDER BY DuplicateCount DESC

-- Find duplicate custodian portfolios
SELECT 
    CustodianAccountNumber,
    COUNT(*) AS DuplicateCount,
    STRING_AGG(CAST(PortfolioID AS VARCHAR), ',') AS PortfolioIDs
FROM Core.dbo.tPortfolioMapping
WHERE Active = 1
GROUP BY CustodianAccountNumber
HAVING COUNT(*) > 1
```

#### Step 3.2: Determine Which Record to Keep

**Decision Criteria:**
1. **Most recent:** Keep record with latest InsertDate
2. **Most complete:** Keep record with most populated fields
3. **Referenced:** Keep record with FK references in other tables
4. **User specified:** Ask user which to retain

#### Step 3.3: Remove Duplicates Safely

```sql
-- Delete duplicates, keep earliest TransactionID
WITH DuplicateCTE AS (
    SELECT 
        TransactionID,
        ROW_NUMBER() OVER (
            PARTITION BY TransactionDate, PortfolioID, Amount, TransactionType 
            ORDER BY TransactionID ASC
        ) AS RowNum
    FROM CashRec.tTransaction
)
DELETE FROM CashRec.tTransaction
WHERE TransactionID IN (
    SELECT TransactionID FROM DuplicateCTE WHERE RowNum > 1
)
```

**Prevent Future Duplicates:**
```sql
-- Add unique constraint
ALTER TABLE CashRec.tTransaction
ADD CONSTRAINT UQ_Transaction_Unique
UNIQUE (TransactionDate, PortfolioID, Amount, TransactionType, ReferenceNumber)
```

---

### Phase 4: Calculation Discrepancy Investigation

#### Step 4.1: Identify Calculation Error

```sql
-- Compare calculated vs. expected values
SELECT 
    pos.PositionID,
    pos.InstID,
    inst.InstrumentName,
    pos.Quantity,
    pos.CostBasis AS Stored_Cost,
    pos.Quantity * pos.UnitCost AS Calculated_Cost,
    pos.CostBasis - (pos.Quantity * pos.UnitCost) AS Cost_Difference,
    pos.MarketValue AS Stored_MV,
    pos.Quantity * price.Price * inst.Factor AS Calculated_MV,
    pos.MarketValue - (pos.Quantity * price.Price * inst.Factor) AS MV_Difference
FROM Core.dbo.vPosition pos
JOIN Reference.dbo.vInst inst ON pos.InstID = inst.InstID
LEFT JOIN Feeds.dbo.vMarketPrice price 
    ON pos.InstID = price.InstID AND pos.PositionDate = price.PriceDate
WHERE ABS(pos.CostBasis - (pos.Quantity * pos.UnitCost)) > 0.01  -- Cost mismatch
    OR ABS(pos.MarketValue - (pos.Quantity * price.Price * ISNULL(inst.Factor, 1))) > 0.01  -- MV mismatch
```

#### Step 4.2: Trace Calculation Logic

**Check calculation procedure:**
```sql
-- Review procedure source code
EXEC sp_helptext 'Core.pPositionCalculate'

-- Test with sample data
DECLARE @Quantity DECIMAL(18,4) = 1000000
DECLARE @Price DECIMAL(18,6) = 98.5
DECLARE @Factor DECIMAL(18,6) = 0.01

SELECT 
    @Quantity AS Quantity,
    @Price AS Price,
    @Factor AS Factor,
    @Quantity * @Price AS Without_Factor,
    @Quantity * @Price * @Factor AS With_Factor,
    @Quantity * @Price * ISNULL(@Factor, 1) AS Null_Safe_Factor
```

#### Step 4.3: Common Calculation Errors

| Error Type | Cause | Fix |
|------------|-------|-----|
| **Factor not applied** | Missing join or NULL factor | Add factor join, use `ISNULL(Factor, 1)` |
| **Currency conversion missing** | No FX rate | Load FX rates, add FX join |
| **Rounding error** | Precision mismatch | Use consistent DECIMAL precision |
| **NULL handling** | NULL * value = NULL | Use `ISNULL()` or `COALESCE()` |
| **Sign error** | Should be negative | Check sign_change or debit/credit logic |

#### Step 4.4: Fix Calculation

**Option 1: Fix procedure logic**
```sql
ALTER PROCEDURE Core.pPositionCalculate
AS
BEGIN
    UPDATE p
    SET 
        p.MarketValue = p.Quantity * mp.Price * ISNULL(inst.Factor, 1) * ISNULL(fx.ExchangeRate, 1),
        p.LastUpdated = GETDATE()
    FROM Core.tPosition p
    JOIN Reference.dbo.vInst inst ON p.InstID = inst.InstID
    LEFT JOIN Feeds.dbo.vMarketPrice mp ON p.InstID = mp.InstID AND p.PositionDate = mp.PriceDate
    LEFT JOIN Reference.dbo.vFXRate fx ON p.Currency = fx.FromCurrency AND p.PositionDate = fx.RateDate
END
```

**Option 2: Recalculate affected records**
```sql
-- Recalculate and update
UPDATE p
SET 
    p.MarketValue = p.Quantity * mp.Price * ISNULL(inst.Factor, 1),
    p.CostBasis = p.Quantity * p.UnitCost
FROM Core.tPosition p
JOIN Reference.dbo.vInst inst ON p.InstID = inst.InstID
LEFT JOIN Feeds.dbo.vMarketPrice mp ON p.InstID = mp.InstID AND p.PositionDate = mp.PriceDate
WHERE p.PositionDate = '{AffectedDate}'
    AND ABS(p.MarketValue - (p.Quantity * mp.Price * ISNULL(inst.Factor, 1))) > 0.01
```

---

### Phase 5: Reference Data Errors Investigation

#### Step 5.1: Identify Bad Reference Data

```sql
-- Find bad issuer/instrument names (system.object() not replaced)
SELECT 
    InstID,
    InstrumentName,
    IssuerName,
    LegalEntityName
FROM Reference.dbo.vInst
WHERE InstrumentName LIKE '%system.object%'
    OR IssuerName LIKE '%system.object%'
    OR LegalEntityName LIKE '%system.object%'

-- Find incorrect legal entities (wrong parent)
SELECT 
    le.LegalEntityID,
    le.LegalEntityName,
    le.ParentLegalEntityID,
    parent.LegalEntityName AS ParentName,
    le.LegalEntityType
FROM Reference.dbo.vLegalEntity le
LEFT JOIN Reference.dbo.vLegalEntity parent ON le.ParentLegalEntityID = parent.LegalEntityID
WHERE le.LegalEntityType = 'Issuer'
    AND le.ParentLegalEntityID != {ExpectedParentID}
```

#### Step 5.2: Correct Reference Data

```sql
-- Update instrument name
UPDATE Reference.dbo.tInst
SET 
    InstrumentName = '{CorrectName}',
    IssuerName = '{CorrectIssuer}',
    LastUpdated = GETDATE(),
    UpdatedBy = '{UserName}'
WHERE InstID = {InstID}

-- Update legal entity parent
UPDATE Reference.dbo.tLegalEntity
SET 
    ParentLegalEntityID = {CorrectParentID},
    LastUpdated = GETDATE()
WHERE LegalEntityID = {LegalEntityID}

-- Fix transaction type granularity (too specific)
UPDATE Custodian.tTransactionTypeMapping
SET 
    MOSTransactionType = 'Wire Transfer',  -- More generic
    LastUpdated = GETDATE()
WHERE CustodianTransactionType IN ('WIRE_DOMESTIC', 'WIRE_INTERNATIONAL', 'WIRE_RETURN')
    AND CustodianName = 'Solvas'
```

---

### Phase 6: Data Validation and Quality Checks

#### Implement Data Quality Rules

```sql
-- Create data quality check procedure
CREATE PROCEDURE DataQuality.pRunQualityChecks
AS
BEGIN
    -- Check 1: Missing required identifiers
    INSERT INTO DataQuality.tQualityIssues (IssueType, Description, Severity, RecordCount)
    SELECT 
        'MissingIdentifier' AS IssueType,
        'Instruments missing CUSIP' AS Description,
        'Medium' AS Severity,
        COUNT(*) AS RecordCount
    FROM Reference.dbo.vInst inst
    WHERE inst.Active = 1
        AND NOT EXISTS (
            SELECT 1 FROM Reference.dbo.vInstIdentifierCurrent id 
            WHERE id.InstID = inst.InstID AND id.IdentifierType = 'CUSIP'
        )
    
    -- Check 2: Duplicate records
    INSERT INTO DataQuality.tQualityIssues (IssueType, Description, Severity, RecordCount)
    SELECT 
        'Duplicate' AS IssueType,
        'Duplicate transactions detected' AS Description,
        'High' AS Severity,
        SUM(DupCount - 1) AS RecordCount
    FROM (
        SELECT COUNT(*) AS DupCount
        FROM CashRec.tTransaction
        GROUP BY TransactionDate, PortfolioID, Amount, TransactionType
        HAVING COUNT(*) > 1
    ) dups
    
    -- Check 3: Calculation discrepancies
    INSERT INTO DataQuality.tQualityIssues (IssueType, Description, Severity, RecordCount)
    SELECT 
        'CalculationError' AS IssueType,
        'Market value calculation mismatch' AS Description,
        'High' AS Severity,
        COUNT(*) AS RecordCount
    FROM Core.dbo.vPosition pos
    JOIN Reference.dbo.vInst inst ON pos.InstID = inst.InstID
    JOIN Feeds.dbo.vMarketPrice price ON pos.InstID = price.InstID AND pos.PositionDate = price.PriceDate
    WHERE ABS(pos.MarketValue - (pos.Quantity * price.Price * ISNULL(inst.Factor, 1))) > 1.00
    
    -- Check 4: Reference data issues
    INSERT INTO DataQuality.tQualityIssues (IssueType, Description, Severity, RecordCount)
    SELECT 
        'BadReferenceData' AS IssueType,
        'Instrument names contain system.object()' AS Description,
        'Medium' AS Severity,
        COUNT(*) AS RecordCount
    FROM Reference.dbo.vInst
    WHERE InstrumentName LIKE '%system.object%'
END
```

---

## Example Investigations

### Example 1: Missing Bloomberg IDs for Loans

**Issue:** Bulk of loans missing Bloomberg identifiers

**Investigation:**
```sql
SELECT COUNT(*) FROM Reference.dbo.vInst inst
WHERE inst.AssetType = 'Loan'
    AND NOT EXISTS (SELECT 1 FROM Reference.dbo.vInstIdentifierCurrent id WHERE id.InstID = inst.InstID AND id.IdentifierType = 'Bloomberg')
-- Result: 452 loans missing Bloomberg IDs
```

**Resolution:** Researched in Bloomberg terminal, added identifiers in bulk via Excel import

### Example 2: Duplicate Custodian Portfolios

**Issue:** Same custodian account mapped to multiple portfolios

**Investigation:**
```sql
SELECT CustodianAccountNumber, STRING_AGG(CAST(PortfolioID AS VARCHAR), ',')
FROM Core.dbo.tPortfolioMapping
WHERE Active = 1 AND CustodianName = 'BNY'
GROUP BY CustodianAccountNumber
HAVING COUNT(*) > 1
-- Found: Account 12345 mapped to portfolios 42 and 58
```

**Root Cause:** Portfolio split, old mapping not deactivated

**Resolution:**
```sql
UPDATE Core.dbo.tPortfolioMapping
SET Active = 0, ExpirationDate = '2024-01-15'
WHERE PortfolioID = 42 AND CustodianAccountNumber = '12345'
```

### Example 3: Traded Cost Calculation Wrong

**Issue:** TradedCost not matching quantity × price

**Investigation:**
```sql
SELECT Quantity, Price, TradedCost, Quantity * Price AS ExpectedCost
FROM Core.dbo.vTrade
WHERE ABS(TradedCost - (Quantity * Price)) > 1.00
-- Found: Factor not applied
```

**Root Cause:** Calculation missing instrument factor

**Fix:**
```sql
ALTER VIEW Core.dbo.vTrade AS
SELECT 
    t.TradeID,
    t.Quantity * t.Price * ISNULL(inst.Factor, 1) AS TradedCost  -- Added factor
FROM Core.tTrade t
JOIN Reference.dbo.vInst inst ON t.InstID = inst.InstID
```

---

## Skill Metadata

- **Skill Name:** data-quality
- **Category:** Data Quality Issues
- **Complexity:** Medium
- **Execution Time:** 20-60 minutes
- **Prerequisites:** Access to Reference, Core, Feeds schemas
- **Outputs:** Corrected data, quality issue reports, SQL fixes
- **Related Skills:**
  - data-normalization (normalization produces bad data)
  - cash-reconciliation (balance/transaction quality)
  - pricing-source-investigation (price data quality)
