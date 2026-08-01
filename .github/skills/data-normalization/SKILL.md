# Data Normalization Investigation Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration

## Purpose
Systematic investigation of data normalization issues where source data (Solvas, custodians, vendors) fails to transform correctly into MOS normalized structures. Enhanced with screenshot analysis for mapping diagrams and error messages. Diagnoses transformation logic errors, mapping failures, and data quality issues preventing proper normalization.

## When to Use This Skill
- Data not importing or normalizing correctly from source systems
- "Transaction/balance/position missing after import"
- "Normalization view returning NULL or incorrect values"
- "Mapping error" or "transformation failure"
- Source data present but not appearing in MOS normalized views
- Keywords: normalization, mapping, transform, source data, normalize, feed mapping, data conversion

---

## Investigation Methodology

### Phase 0: Analyze Screenshots and Wiki Documentation

**Step 0.1: Screenshot Analysis**
```powershell
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - Mapping diagram screenshots showing source-to-target transformations
# - Error message screenshots from normalization views
# - Data quality reports with NULL values or transformation failures
# - Excel screenshots showing source data vs normalized data comparison
```

**Step 0.2: Fetch Wiki Procedures**
```powershell
$wikiPath = "/Feed-Mapping-Standards"  # Update with actual path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_FeedMapping.md" -Encoding UTF8
```

### Phase 1: Identify Normalization Layer and Data Type

**Objective:** Determine which data normalization pipeline is failing and what type of data is affected.

**Questions to Answer:**
1. **What type of data is failing to normalize?**
   - Transactions (cash movements, trades)
   - Balances (custodian cash balances)
   - Positions (holdings, securities)
   - Prices (vendor pricing data)
   - Reference data (instruments, accounts, mappings)

2. **What is the source system?**
   - Solvas (primary internal system)
   - Custodian (BNY, Citi, Northern Trust, State Street)
   - Vendor (Markit, LSEG, ICE, Sycamore)
   - Manual import (Excel, CSV)

3. **When did normalization fail?**
   - Specific date/time
   - First occurrence date
   - Is it ongoing or one-time?
   - Does it affect all records or specific subset?

4. **How was failure detected?**
   - Missing data in reports
   - Error in normalization view
   - Import log error message
   - User-reported discrepancy

**Initial Context Gathering:**
```sql
-- Check if raw data exists in source table
SELECT TOP 100 *
FROM {SourceSchema}.{RawTable}  -- e.g., Custodian.tCitiTransactionRaw
WHERE ImportDate >= '{FailureDate}'
ORDER BY ImportDate DESC

-- Check if normalized data exists
SELECT TOP 100 *
FROM {SourceSchema}.{NormalizationView}  -- e.g., Custodian.vCitiTransactionNormalization
WHERE NormalizationDate >= '{FailureDate}'
ORDER BY NormalizationDate DESC
```

---

### Phase 2: Transaction Normalization Investigation

**Applicable When:** Transaction data not normalizing correctly

#### Step 2.1: Verify Raw Transaction Data

```sql
-- Examine raw custodian transaction data
SELECT 
    ImportDate,
    TransactionDate,
    AccountNumber,
    TransactionType AS Raw_TransactionType,
    Amount,
    Currency,
    ReferenceNumber,
    Description,
    -- Any other relevant raw fields
    *
FROM Custodian.t{CustodianName}TransactionRaw  -- e.g., tCitiTransactionRaw
WHERE AccountNumber = '{CustodianAccountNumber}'
    AND TransactionDate = '{TargetDate}'
ORDER BY ImportDate DESC, TransactionDate
```

**Raw Data Validation:**
- Is raw transaction record present?
- Are all required fields populated?
- Are field formats correct (dates, amounts, strings)?
- Any NULL values in critical fields?
- Does the data match custodian source file?

#### Step 2.2: Test Normalization View Logic

```sql
-- Execute normalization view for specific transaction
SELECT 
    -- Normalized fields
    TransactionID,
    PortfolioID,
    TransactionDate,
    TransactionType AS Normalized_TransactionType,
    Amount AS Normalized_Amount,
    Currency AS Normalized_Currency,
    ReferenceNumber,
    -- Raw fields for comparison
    raw.TransactionType AS Raw_TransactionType,
    raw.Amount AS Raw_Amount,
    raw.Currency AS Raw_Currency,
    -- Mapping/transformation columns
    ttm.MOSTransactionType,
    ttm.MappingActive,
    pm.PortfolioID AS Mapped_PortfolioID
FROM Custodian.v{CustodianName}TransactionNormalization norm
LEFT JOIN Custodian.t{CustodianName}TransactionRaw raw 
    ON norm.RawTransactionID = raw.TransactionID
LEFT JOIN Reference.dbo.vTransactionTypeMapping ttm 
    ON raw.TransactionType = ttm.CustodianTransactionType
    AND ttm.CustodianName = '{CustodianName}'
LEFT JOIN Core.dbo.vPortfolioMapping pm 
    ON raw.AccountNumber = pm.CustodianAccountNumber
WHERE raw.AccountNumber = '{CustodianAccountNumber}'
    AND raw.TransactionDate = '{TargetDate}'
```

**Common Normalization Failures:**

| Failure Type | Symptom | Likely Cause |
|--------------|---------|--------------|
| **NULL TransactionType** | Normalized type is NULL | Transaction type not in mapping table |
| **NULL PortfolioID** | Portfolio mapping failed | Account number mismatch or missing mapping |
| **NULL Amount** | Amount not converting | Currency conversion error or parsing issue |
| **Duplicate Records** | Same transaction multiple times | JOIN logic creating cartesian product |
| **Missing Records** | Raw exists, normalized doesn't | WHERE filter too restrictive or JOIN dropping rows |

#### Step 2.3: Check Transaction Type Mapping

```sql
-- Verify transaction type mapping exists and is active
SELECT 
    ttm.CustodianTransactionType,
    ttm.MOSTransactionType,
    tt.TransactionTypeName,
    ttm.MappingActive,
    ttm.EffectiveDate,
    ttm.ExpirationDate
FROM Reference.dbo.vTransactionTypeMapping ttm
LEFT JOIN Reference.dbo.vTransactionType tt 
    ON ttm.MOSTransactionType = tt.TransactionType
WHERE ttm.CustodianName = '{CustodianName}'
    AND ttm.CustodianTransactionType = '{RawTransactionType}'
ORDER BY ttm.EffectiveDate DESC
```

**Mapping Issues:**
- Transaction type not mapped (NULL result)
- Mapping inactive or expired
- Mapped to wrong MOS transaction type
- Ambiguous mapping (multiple matches)

**Resolution:**
```sql
-- Add missing transaction type mapping
INSERT INTO Reference.dbo.tTransactionTypeMapping 
    (CustodianName, CustodianTransactionType, MOSTransactionType, MappingActive, EffectiveDate)
VALUES 
    ('{CustodianName}', '{RawTransactionType}', '{MOSTransactionType}', 1, GETDATE())
```

#### Step 2.4: Validate Portfolio/Account Mapping

```sql
-- Check portfolio mapping for custodian account
SELECT 
    pm.PortfolioID,
    p.PortfolioName,
    pm.CustodianName,
    pm.CustodianAccountNumber,
    pm.Active,
    pm.EffectiveDate,
    pm.ExpirationDate
FROM Core.dbo.vPortfolioMapping pm
JOIN Core.dbo.vPortfolio p ON pm.PortfolioID = p.PortfolioID
WHERE pm.CustodianName = '{CustodianName}'
    AND pm.CustodianAccountNumber = '{CustodianAccountNumber}'
ORDER BY pm.EffectiveDate DESC
```

**Portfolio Mapping Problems:**
- Account number not mapped to any portfolio
- Mapping inactive or expired
- Account number format mismatch (leading zeros, spaces)
- Multiple active mappings (ambiguous)

**Resolution:**
```sql
-- Add portfolio mapping
INSERT INTO Core.dbo.tPortfolioMapping 
    (PortfolioID, CustodianName, CustodianAccountNumber, Active, EffectiveDate)
VALUES 
    ({PortfolioID}, '{CustodianName}', '{CustodianAccountNumber}', 1, GETDATE())
```

---

### Phase 3: Balance Normalization Investigation

**Applicable When:** Custodian balance data not normalizing correctly

#### Step 3.1: Verify Raw Balance Data

```sql
-- Check raw custodian balance records
SELECT 
    ImportDate,
    BalanceDate,
    AccountNumber,
    Balance AS Raw_Balance,
    Currency AS Raw_Currency,
    BalanceType,
    *
FROM Custodian.t{CustodianName}BalanceRaw
WHERE AccountNumber = '{CustodianAccountNumber}'
    AND BalanceDate = '{TargetDate}'
ORDER BY ImportDate DESC
```

**Validation:**
- Raw balance record exists?
- Balance value reasonable (not NULL, not zero if unexpected)?
- Currency code valid (USD, EUR, etc.)?
- Any duplicate balance records?

#### Step 3.2: Test Balance Normalization View

```sql
-- Execute balance normalization for account
SELECT 
    -- Normalized fields
    BalanceID,
    PortfolioID,
    BalanceDate,
    CashBalance AS Normalized_Balance,
    Currency AS Normalized_Currency,
    -- Raw comparison
    raw.Balance AS Raw_Balance,
    raw.Currency AS Raw_Currency,
    -- Transformation details
    raw.Balance * fx.ExchangeRate AS Currency_Converted,
    pm.PortfolioID AS Mapped_Portfolio
FROM Custodian.v{CustodianName}BalanceNormalization norm
LEFT JOIN Custodian.t{CustodianName}BalanceRaw raw 
    ON norm.RawBalanceID = raw.BalanceID
LEFT JOIN Reference.dbo.vFXRate fx 
    ON raw.Currency = fx.FromCurrency 
    AND norm.Currency = fx.ToCurrency
    AND raw.BalanceDate = fx.RateDate
LEFT JOIN Core.dbo.vPortfolioMapping pm 
    ON raw.AccountNumber = pm.CustodianAccountNumber
WHERE raw.AccountNumber = '{CustodianAccountNumber}'
    AND raw.BalanceDate = '{TargetDate}'
```

**Common Balance Normalization Failures:**

| Issue | Symptom | Diagnosis |
|-------|---------|-----------|
| **Currency Conversion Missing** | Balance is NULL or wrong | FX rate not available for date/currency pair |
| **Portfolio Mapping Failed** | PortfolioID is NULL | Account number not mapped |
| **Duplicate Balances** | Multiple records for same date | Import deduplication failing or union logic issue |
| **Balance Value Wrong** | Amount doesn't match raw | Calculation error or factor application issue |

#### Step 3.3: Check Currency Conversion

```sql
-- Verify FX rates available
SELECT 
    RateDate,
    FromCurrency,
    ToCurrency,
    ExchangeRate,
    RateSource
FROM Reference.dbo.vFXRate
WHERE RateDate = '{TargetDate}'
    AND (
        (FromCurrency = '{BalanceCurrency}' AND ToCurrency = 'USD')
        OR (FromCurrency = 'USD' AND ToCurrency = '{BalanceCurrency}')
    )
```

**FX Rate Issues:**
- Rate not available for date (weekend, holiday)
- Currency pair not configured
- Rate source missing or stale
- Wrong conversion direction (invert rate)

---

### Phase 4: Position Normalization Investigation

**Applicable When:** Position/holdings data not normalizing from Solvas or custodians

#### Step 4.1: Verify Raw Position Data

```sql
-- Check raw Solvas position data
SELECT 
    ImportDate,
    PositionDate,
    PortfolioID,
    InstrumentID,
    Quantity AS Raw_Quantity,
    CostBasis AS Raw_Cost,
    MarketValue AS Raw_MV,
    Currency,
    *
FROM Solvas.tPositionRaw
WHERE PortfolioID = {PortfolioID}
    AND PositionDate = '{TargetDate}'
    AND InstrumentID = '{InstrumentID}'  -- If investigating specific position
ORDER BY ImportDate DESC
```

#### Step 4.2: Test Position Normalization Logic

```sql
-- Execute position normalization view
SELECT 
    -- Normalized position
    p.PositionID,
    p.PortfolioID,
    p.InstID,
    p.PositionDate,
    p.Quantity AS Normalized_Quantity,
    p.CostBasis AS Normalized_Cost,
    p.MarketValue AS Normalized_MV,
    -- Raw comparison
    raw.Quantity AS Raw_Quantity,
    raw.CostBasis AS Raw_Cost,
    raw.MarketValue AS Raw_MV,
    -- Transformation factors
    inst.Factor,
    raw.Quantity * inst.Factor AS Quantity_After_Factor,
    fx.ExchangeRate,
    raw.MarketValue * fx.ExchangeRate AS MV_After_FX
FROM Core.dbo.vPosition p
LEFT JOIN Solvas.tPositionRaw raw 
    ON p.RawPositionID = raw.PositionID
LEFT JOIN Reference.dbo.vInst inst 
    ON p.InstID = inst.InstID
LEFT JOIN Reference.dbo.vFXRate fx 
    ON raw.Currency = fx.FromCurrency
    AND p.PositionDate = fx.RateDate
WHERE p.PortfolioID = {PortfolioID}
    AND p.PositionDate = '{TargetDate}'
    AND p.InstID = '{InstID}'
```

**Position Normalization Issues:**

| Problem | Indicator | Root Cause |
|---------|-----------|------------|
| **Wrong Quantity** | Quantity differs from raw | Factor not applied or applied incorrectly |
| **Wrong Market Value** | MV calculation incorrect | Currency conversion error or price missing |
| **Duplicate Positions** | Same position multiple times | Aggregation logic issue or raw data duplicates |
| **Missing Positions** | Raw exists, normalized doesn't | Instrument mapping failed or filter too restrictive |
| **NULL Cost Basis** | Cost is NULL | Cost data missing in source or calculation error |

#### Step 4.3: Validate Instrument Factor Application

```sql
-- Check instrument factor configuration
SELECT 
    inst.InstID,
    inst.InstrumentName,
    inst.Factor,
    inst.FactorType,
    inst.AssetType,
    inst.Active
FROM Reference.dbo.vInst inst
WHERE inst.InstID = '{InstID}'
```

**Factor Issues:**
- Factor is NULL (should be 1.0 if no factor applies)
- Factor value incorrect (100 vs. 0.01)
- Factor not applied in normalization view
- Factor changed mid-period

---

### Phase 5: String Parsing and Data Quality Issues

**Common Parsing Failures:**

#### Issue 1: Date Format Mismatch
```sql
-- Test date parsing from raw string field
SELECT 
    DateStringField,
    TRY_CONVERT(DATE, DateStringField, 101) AS US_Format,  -- MM/DD/YYYY
    TRY_CONVERT(DATE, DateStringField, 103) AS UK_Format,  -- DD/MM/YYYY
    TRY_CONVERT(DATE, DateStringField, 112) AS ISO_Format  -- YYYYMMDD
FROM {SourceTable}
WHERE TRY_CONVERT(DATE, DateStringField) IS NULL  -- Identify parsing failures
```

#### Issue 2: Numeric Parsing Errors
```sql
-- Test amount/quantity parsing
SELECT 
    AmountStringField,
    TRY_CONVERT(DECIMAL(18,4), REPLACE(REPLACE(AmountStringField, ',', ''), '$', '')) AS Parsed_Amount,
    CASE 
        WHEN AmountStringField LIKE '%(%' THEN -1  -- Negative in parentheses
        ELSE 1 
    END AS Sign_Multiplier
FROM {SourceTable}
WHERE TRY_CONVERT(DECIMAL(18,4), AmountStringField) IS NULL
```

#### Issue 3: NULL Handling in Joins
```sql
-- Identify NULLs breaking normalization
SELECT 
    'Raw Records' AS DataSet,
    COUNT(*) AS Total_Records,
    SUM(CASE WHEN KeyField IS NULL THEN 1 ELSE 0 END) AS NULL_Keys,
    SUM(CASE WHEN Amount IS NULL THEN 1 ELSE 0 END) AS NULL_Amounts,
    SUM(CASE WHEN TransactionDate IS NULL THEN 1 ELSE 0 END) AS NULL_Dates
FROM {RawTable}
WHERE ImportDate = '{TargetDate}'
```

---

### Phase 6: Normalization View Performance Issues

**Objective:** Identify slow-running or timeout queries in normalization views

#### Step 6.1: Check View Execution Plan

```sql
-- Get estimated execution plan for normalization view
SET SHOWPLAN_XML ON
GO
SELECT * FROM Custodian.v{CustodianName}TransactionNormalization
WHERE TransactionDate = '{TargetDate}'
GO
SET SHOWPLAN_XML OFF
```

**Performance Red Flags:**
- Table scans on large tables (> 1M rows)
- Missing indexes on join columns
- Implicit conversions (VARCHAR to INT)
- Nested loops with high row counts
- Multiple key lookups

#### Step 6.2: Optimize Slow Normalization Views

**Common Optimizations:**

```sql
-- Add index on join column
CREATE NONCLUSTERED INDEX IX_Transaction_AccountDate 
ON Custodian.tCitiTransactionRaw (AccountNumber, TransactionDate)
INCLUDE (TransactionType, Amount, Currency)

-- Add index on mapping table
CREATE NONCLUSTERED INDEX IX_TransactionTypeMapping_Type 
ON Reference.dbo.tTransactionTypeMapping (CustodianName, CustodianTransactionType)
WHERE MappingActive = 1

-- Add filtered index for active mappings only
CREATE NONCLUSTERED INDEX IX_PortfolioMapping_Active 
ON Core.dbo.tPortfolioMapping (CustodianAccountNumber, PortfolioID)
WHERE Active = 1
```

---

### Phase 7: Root Cause Categories and Resolutions

| Root Cause | Indicators | Resolution | Prevention |
|------------|-----------|------------|-----------|
| **Missing Mapping** | NULL in normalized field, mapping query returns 0 rows | Add mapping record | Implement mapping validation on import |
| **Inactive/Expired Mapping** | Mapping exists but Active = 0 or date expired | Update Active flag or extend date | Monitor mapping expiration dates |
| **Data Type Conversion Error** | TRY_CONVERT returns NULL | Fix parsing logic, handle format variations | Validate source data format |
| **NULL in Required Field** | Raw data has NULL in critical column | Contact source system, fix normalization to handle NULL | Add NOT NULL constraint on source |
| **Duplicate Records** | Same record appears multiple times | Fix aggregation or add DISTINCT | Add unique constraint |
| **JOIN Dropping Rows** | Raw count > normalized count | Change INNER JOIN to LEFT JOIN | Review JOIN conditions |
| **Performance Timeout** | View execution > 30 seconds | Add indexes, optimize query | Monitor view execution times |
| **Currency Conversion Missing** | FX rate query returns no rows | Load missing FX rates | Daily FX rate import validation |
| **String Parsing Failure** | Date or amount parse returns NULL | Handle multiple formats, add validation | Standardize source data format |

---

### Phase 8: Generate Investigation Report

**Report Template:**

```markdown
# Data Normalization Investigation Report

## Executive Summary
- Data Type: [Transactions | Balances | Positions | Prices]
- Source System: [Solvas | Custodian | Vendor]
- Portfolio/Account: [Name/Number]
- Target Date: [YYYY-MM-DD]
- Records Affected: [X records]
- Root Cause: [Category]

## Raw Data Verification
- Raw records found: [Yes/No]
- Raw record count: [X]
- Sample raw data: [See attachment]

## Normalization Results
- Normalized records expected: [X]
- Normalized records actual: [X]
- Success rate: [XX%]

## Root Cause Analysis
[Detailed explanation]

### Specific Failure Point
- Normalization Step: [Transaction Type Mapping | Portfolio Mapping | Currency Conversion | etc.]
- Field Affected: [FieldName]
- Expected Value: [Value]
- Actual Value: [NULL | Incorrect Value]

## Remediation Steps

### Immediate Fix (SQL)
```sql
-- [Remediation SQL script]
```

### Long-term Solution
[Process improvement or code fix]

## Validation

### Before Fix
```sql
-- Query showing failure
```

### After Fix
```sql
-- Query showing success
```

## Attachments
- Raw data export
- Normalized data comparison
- Execution plan (if performance issue)
```

---

## Example Investigations

### Example 1: Missing Transaction Type Mapping

**Issue:** Citi wire transfers not appearing in MOS cash rec

**Investigation:**
```sql
-- Found raw transactions
SELECT * FROM Custodian.tCitiTransactionRaw 
WHERE TransactionType = 'WIRE_OUT' AND TransactionDate = '2024-03-15'
-- Result: 10 records

-- Checked normalization
SELECT * FROM Custodian.vCitiTransactionNormalization
WHERE RawTransactionType = 'WIRE_OUT' AND TransactionDate = '2024-03-15'
-- Result: 0 records (expected 10)

-- Checked mapping
SELECT * FROM Reference.dbo.vTransactionTypeMapping
WHERE CustodianName = 'Citi' AND CustodianTransactionType = 'WIRE_OUT'
-- Result: 0 rows (MISSING MAPPING)
```

**Root Cause:** New transaction type `WIRE_OUT` from Citi not mapped to MOS transaction type

**Resolution:**
```sql
INSERT INTO Reference.dbo.tTransactionTypeMapping
VALUES ('Citi', 'WIRE_OUT', 'Wire Transfer', 1, GETDATE(), NULL)
```

**Validation:**
```sql
SELECT * FROM Custodian.vCitiTransactionNormalization
WHERE TransactionDate = '2024-03-15' AND TransactionType = 'Wire Transfer'
-- Result: 10 records ✓
```

---

### Example 2: Portfolio Mapping with Leading Zeros

**Issue:** BNY balances not normalizing for account `00012345`

**Investigation:**
```sql
-- Raw data exists
SELECT AccountNumber, Balance FROM Custodian.tBNYBalanceRaw
WHERE AccountNumber = '00012345'
-- Result: 1 row, Balance = $1,500,000

-- Normalized view fails
SELECT * FROM Custodian.vBNYBalanceNormalization
WHERE RawAccountNumber = '00012345'
-- Result: 0 rows

-- Check portfolio mapping
SELECT * FROM Core.dbo.vPortfolioMapping
WHERE CustodianAccountNumber = '00012345'
-- Result: 0 rows

-- Check without leading zeros
SELECT * FROM Core.dbo.vPortfolioMapping
WHERE CustodianAccountNumber = '12345'
-- Result: 1 row (PortfolioID = 42)
```

**Root Cause:** Account number in raw data has leading zeros (`00012345`), mapping table doesn't (`12345`)

**Resolution:**
```sql
-- Update normalization view to handle leading zeros
ALTER VIEW Custodian.vBNYBalanceNormalization AS
SELECT 
    ...
    pm.PortfolioID
FROM Custodian.tBNYBalanceRaw raw
LEFT JOIN Core.dbo.vPortfolioMapping pm 
    ON LTRIM(raw.AccountNumber, '0') = pm.CustodianAccountNumber  -- Strip leading zeros
...
```

---

### Example 3: Missing FX Rate for Foreign Currency Balance

**Issue:** EUR balance not converting to USD

**Investigation:**
```sql
-- Raw EUR balance exists
SELECT Balance, Currency FROM Custodian.tCitiBalanceRaw
WHERE AccountNumber = '12345' AND BalanceDate = '2024-03-15'
-- Result: Balance = 1000000, Currency = 'EUR'

-- Normalized balance is NULL
SELECT CashBalance FROM Custodian.vCitiBalanceNormalization
WHERE AccountNumber = '12345' AND BalanceDate = '2024-03-15'
-- Result: NULL

-- Check FX rate
SELECT * FROM Reference.dbo.vFXRate
WHERE FromCurrency = 'EUR' AND ToCurrency = 'USD' AND RateDate = '2024-03-15'
-- Result: 0 rows (MISSING FX RATE)
```

**Root Cause:** FX rate not loaded for 2024-03-15 (Friday, import may have failed)

**Resolution:**
```sql
-- Load missing FX rate
INSERT INTO Reference.dbo.tFXRate (RateDate, FromCurrency, ToCurrency, ExchangeRate, RateSource)
VALUES ('2024-03-15', 'EUR', 'USD', 1.0872, 'Bloomberg')

-- Verify normalization now works
SELECT CashBalance FROM Custodian.vCitiBalanceNormalization
WHERE AccountNumber = '12345' AND BalanceDate = '2024-03-15'
-- Result: $1,087,200 (1,000,000 EUR * 1.0872) ✓
```

---

## Skill Metadata

- **Skill Name:** data-normalization
- **Category:** Data Normalization
- **Complexity:** High
- **Execution Time:** 15-45 minutes
- **Prerequisites:** Access to source schemas, normalization views, mapping tables
- **Outputs:** Investigation report, SQL fixes, mapping updates
- **Related Skills:**
  - cash-reconciliation (often requires normalized transaction data)
  - check-ssis-errors (import failures prevent normalization)
  - import-file-investigation (missing source files prevent normalization)
  - pricing-source-investigation (price normalization specific)
