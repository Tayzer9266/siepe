# Portfolio and Fund Setup Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration

## Purpose
Configure new companies, funds, and portfolios in MOS including database setup, custodian connections, price weighting, cash reconciliation, and name change procedures. Enhanced with screenshot analysis for configuration dialogs and setup wizards.

## When to Use This Skill
- New company onboarding
- New fund or portfolio creation
- Portfolio name changes or rebranding
- Fund restructuring or merging
- Custodian account mapping
- Keywords: new company, new fund, new portfolio, setup, onboarding, name change, portfolio configuration

---

## Investigation Methodology

### Phase 0: Analyze Configuration Screenshots and Wiki

**Step 0.1: Screenshot Analysis**
```powershell
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - Configuration dialog screenshots showing setup wizard steps
# - Portfolio settings screenshots with enabled/disabled features
# - Custodian connection screenshots with account mappings
# - Error screenshots from setup validation
```

**Step 0.2: Fetch Wiki Onboarding Checklist**
```powershell
$wikiPath = "/Portfolio-Onboarding-Checklist"  # Update with actual path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_PortfolioOnboarding.md" -Encoding UTF8
```

### Phase 1: New Company Setup

#### Step 1.1: Gather Company Information

**Required Information:**
- Company legal name
- Company short name (code)
- Parent entity (if subsidiary)
- Accounting currency
- Fiscal year end
- Contact person
- Active date

#### Step 1.2: Create Company Record

```sql
-- Insert new company
INSERT INTO Employee.dbo.tCompany (
    CompanyName,
    CompanyCode,
    ParentCompanyID,
    Currency,
    FiscalYearEnd,
    ContactPerson,
    Active,
    EffectiveDate,
    InsertDate,
    InsertedBy
)
VALUES (
    '{CompanyLegalName}',
    '{CompanyCode}',  -- e.g., 'ELMWOOD'
    {ParentCompanyID},  -- NULL if standalone
    'USD',
    '12-31',  -- MM-DD format
    '{ContactName}',
    1,
    '{EffectiveDate}',
    GETDATE(),
    '{UserName}'
)

SELECT SCOPE_IDENTITY() AS NewCompanyID
```

#### Step 1.3: Configure Company Settings

```sql
-- Set default portfolio settings for company
INSERT INTO Core.dbo.tCompanySettings (
    CompanyID,
    SettingName,
    SettingValue
)
VALUES
    ({CompanyID}, 'DefaultPriceSource', 'Markit'),
    ({CompanyID}, 'CashRecEnabled', '1'),
    ({CompanyID}, 'PriceWeightingMethod', 'FIFO'),
    ({CompanyID}, 'FXRateSource', 'Bloomberg')
```

---

### Phase 2: New Fund Setup

#### Step 2.1: Gather Fund Information

**Required Information:**
- Fund name
- Fund code
- Company ID (parent company)
- Fund type (Hedge Fund, Mutual Fund, PE, etc.)
- Master/Feeder structure
- Accounting method (US GAAP, IFRS)
- Base currency

#### Step 2.2: Create Fund Record

```sql
-- Insert new fund
INSERT INTO Core.dbo.tFund (
    FundName,
    FundCode,
    CompanyID,
    FundType,
    MasterFundID,  -- NULL if master or standalone
    AccountingStandard,
    BaseCurrency,
    Active,
    InceptionDate,
    InsertDate,
    InsertedBy
)
VALUES (
    '{FundName}',
    '{FundCode}',
    {CompanyID},
    '{FundType}',
    {MasterFundID},
    'US GAAP',
    'USD',
    1,
    '{InceptionDate}',
    GETDATE(),
    '{UserName}'
)

SELECT SCOPE_IDENTITY() AS NewFundID
```

---

### Phase 3: New Portfolio Setup

#### Step 3.1: Gather Portfolio Information

**Required Information:**
- Portfolio name
- Portfolio code
- Fund ID (parent fund)
- Portfolio type (Trading, Custody, Financing)
- Custodian name
- Custodian account number(s)
- Price weighting method (FIFO, WAC, SpecificID)
- Cash rec enabled? (Yes/No)

#### Step 3.2: Create Portfolio Record

```sql
-- Insert new portfolio
INSERT INTO Core.dbo.tPortfolio (
    PortfolioName,
    PortfolioCode,
    FundID,
    PortfolioType,
    PriceWeightingMethod,
    BaseCurrency,
    Active,
    InceptionDate,
    InsertDate,
    InsertedBy
)
VALUES (
    '{PortfolioName}',
    '{PortfolioCode}',
    {FundID},
    'Trading',  -- or 'Custody', 'Financing'
    'FIFO',  -- or 'WAC', 'SpecificID'
    'USD',
    1,
    '{InceptionDate}',
    GETDATE(),
    '{UserName}'
)

SELECT SCOPE_IDENTITY() AS NewPortfolioID
```

#### Step 3.3: Map Custodian Accounts

```sql
-- Map custodian account(s) to portfolio
INSERT INTO Core.dbo.tPortfolioMapping (
    PortfolioID,
    CustodianName,
    CustodianAccountNumber,
    CustodianAccountName,
    AccountType,
    Active,
    EffectiveDate,
    InsertDate,
    InsertedBy
)
VALUES
    ({PortfolioID}, 'BNY Mellon', '{AccountNumber1}', '{AccountName1}', 'Trading', 1, '{EffectiveDate}', GETDATE(), '{UserName}'),
    ({PortfolioID}, 'State Street', '{AccountNumber2}', '{AccountName2}', 'Custody', 1, '{EffectiveDate}', GETDATE(), '{UserName}')
```

#### Step 3.4: Configure Price Weighting

```sql
-- Set up FIFO/WAC price weighting tracking
INSERT INTO Core.dbo.tPriceWeightingConfig (
    PortfolioID,
    WeightingMethod,
    SplitByTaxLot,
    Active,
    EffectiveDate
)
VALUES (
    {PortfolioID},
    'FIFO',  -- First In First Out
    1,  -- Track tax lots separately
    1,
    '{EffectiveDate}'
)

-- Initialize price weighting table for existing positions (if needed)
INSERT INTO Core.dbo.tPriceWeighting (PortfolioID, InstID, PositionDate, WeightedCost, Quantity)
SELECT 
    {PortfolioID} AS PortfolioID,
    p.InstID,
    p.PositionDate,
    p.CostBasis AS WeightedCost,
    p.Quantity
FROM Core.dbo.vPosition p
WHERE p.PortfolioID = {PortfolioID}
    AND p.PositionDate >= '{InceptionDate}'
```

#### Step 3.5: Enable Cash Reconciliation

```sql
-- Enable cash rec for portfolio
INSERT INTO CashRec.dbo.tPortfolioConfig (
    PortfolioID,
    CashRecEnabled,
    AutoReconcile,
    ReconciliationFrequency,
    Active,
    EffectiveDate
)
VALUES (
    {PortfolioID},
    1,  -- Enabled
    0,  -- Manual reconciliation
    'Daily',
    1,
    '{EffectiveDate}'
)

-- Create initial cash balance
INSERT INTO CashRec.dbo.tBalance (
    PortfolioID,
    BalanceDate,
    Currency,
    OpeningBalance,
    ClosingBalance,
    InsertDate,
    InsertedBy
)
VALUES (
    {PortfolioID},
    '{InceptionDate}',
    'USD',
    0.00,
    0.00,
    GETDATE(),
    '{UserName}'
)
```

---

### Phase 4: Custodian Feed Configuration

#### Step 4.1: Set Up Custodian Import

```sql
-- Configure custodian data import for portfolio
INSERT INTO Custodian.dbo.tImportConfig (
    CustodianName,
    PortfolioID,
    FeedType,  -- 'Position', 'Transaction', 'CashBalance'
    FilePath,
    FileFormat,  -- 'CSV', 'Excel', 'Fixed'
    ImportFrequency,
    Active,
    EffectiveDate
)
VALUES
    ('BNY Mellon', {PortfolioID}, 'Position', '\\fileserver\custodian\bny\positions\*.csv', 'CSV', 'Daily', 1, '{EffectiveDate}'),
    ('BNY Mellon', {PortfolioID}, 'Transaction', '\\fileserver\custodian\bny\transactions\*.csv', 'CSV', 'Daily', 1, '{EffectiveDate}'),
    ('BNY Mellon', {PortfolioID}, 'CashBalance', '\\fileserver\custodian\bny\cash\*.csv', 'CSV', 'Daily', 1, '{EffectiveDate}')
```

#### Step 4.2: Map Custodian Fields

```sql
-- Configure field mappings for custodian import
INSERT INTO Custodian.dbo.tFieldMapping (
    CustodianName,
    FeedType,
    SourceField,
    DestinationField,
    DataType,
    Transformation
)
VALUES
    ('BNY Mellon', 'Position', 'Acct_Num', 'AccountNumber', 'VARCHAR(50)', NULL),
    ('BNY Mellon', 'Position', 'CUSIP', 'CUSIP', 'VARCHAR(9)', NULL),
    ('BNY Mellon', 'Position', 'Sec_Name', 'InstrumentName', 'VARCHAR(255)', 'TRIM'),
    ('BNY Mellon', 'Position', 'Shares', 'Quantity', 'DECIMAL(18,4)', 'CAST'),
    ('BNY Mellon', 'Position', 'Market_Val', 'MarketValue', 'DECIMAL(18,2)', 'CAST')
```

---

### Phase 5: Portfolio Name Change / Rebranding

#### Step 5.1: Identify All Systems Affected

**Systems to Update:**
- MOS Core database (portfolio, fund, company names)
- CAMOS (client reporting)
- Data Warehouse (historical reporting)
- Solvas (custodian system)
- User documentation

#### Step 5.2: Update MOS Portfolio Name

```sql
-- Update portfolio name
UPDATE Core.dbo.tPortfolio
SET 
    PortfolioName = '{NewPortfolioName}',
    PortfolioCode = '{NewPortfolioCode}',
    LastUpdated = GETDATE(),
    UpdatedBy = '{UserName}'
WHERE PortfolioID = {PortfolioID}

-- Log name change for audit
INSERT INTO Core.dbo.tPortfolioNameHistory (
    PortfolioID,
    OldName,
    NewName,
    ChangeDate,
    ChangedBy,
    Reason
)
VALUES (
    {PortfolioID},
    '{OldPortfolioName}',
    '{NewPortfolioName}',
    GETDATE(),
    '{UserName}',
    '{ChangeReason}'
)
```

#### Step 5.3: Update Fund Name

```sql
-- Update fund name
UPDATE Core.dbo.tFund
SET 
    FundName = '{NewFundName}',
    FundCode = '{NewFundCode}',
    LastUpdated = GETDATE(),
    UpdatedBy = '{UserName}'
WHERE FundID = {FundID}
```

#### Step 5.4: Update Company Name

```sql
-- Update company name
UPDATE Employee.dbo.tCompany
SET 
    CompanyName = '{NewCompanyName}',
    CompanyCode = '{NewCompanyCode}',
    LastUpdated = GETDATE(),
    UpdatedBy = '{UserName}'
WHERE CompanyID = {CompanyID}
```

#### Step 5.5: Propagate Changes to Other Systems

**CAMOS Update:**
```sql
-- Update CAMOS client reporting
UPDATE CAMOS.dbo.tClient
SET 
    ClientName = '{NewCompanyName}',
    LastUpdated = GETDATE()
WHERE ClientID = (SELECT ClientID FROM CAMOS.dbo.tClientMapping WHERE CompanyID = {CompanyID})
```

**Data Warehouse Update:**
```sql
-- Update DW dimensions (slowly changing dimension Type 2)
-- Close old record
UPDATE DW.dbo.dimPortfolio
SET 
    EffectiveEndDate = GETDATE(),
    IsCurrent = 0
WHERE PortfolioID = {PortfolioID} AND IsCurrent = 1

-- Insert new record with new name
INSERT INTO DW.dbo.dimPortfolio (
    PortfolioID,
    PortfolioName,
    PortfolioCode,
    FundName,
    CompanyName,
    EffectiveStartDate,
    EffectiveEndDate,
    IsCurrent
)
VALUES (
    {PortfolioID},
    '{NewPortfolioName}',
    '{NewPortfolioCode}',
    '{NewFundName}',
    '{NewCompanyName}',
    GETDATE(),
    '9999-12-31',
    1
)
```

**Solvas Update:**
- Coordinate with custodian to update account names
- Typically requires custodian ticket/request
- Verify in next day's custodian file

---

### Phase 6: Validation and Testing

#### Step 6.1: Verify Database Setup

```sql
-- Verify company setup
SELECT * FROM Employee.dbo.tCompany WHERE CompanyID = {CompanyID}

-- Verify fund setup
SELECT * FROM Core.dbo.tFund WHERE FundID = {FundID}

-- Verify portfolio setup
SELECT * FROM Core.dbo.tPortfolio WHERE PortfolioID = {PortfolioID}

-- Verify custodian mappings
SELECT * FROM Core.dbo.tPortfolioMapping WHERE PortfolioID = {PortfolioID} AND Active = 1

-- Verify cash rec config
SELECT * FROM CashRec.dbo.tPortfolioConfig WHERE PortfolioID = {PortfolioID}

-- Verify price weighting config
SELECT * FROM Core.dbo.tPriceWeightingConfig WHERE PortfolioID = {PortfolioID}
```

#### Step 6.2: Test Data Import

```sql
-- Run custodian import manually for new portfolio
EXEC Custodian.pImportPositions @PortfolioID = {PortfolioID}, @ImportDate = '{TestDate}'

-- Verify imported data
SELECT TOP 100 * FROM Custodian.vPositionImport WHERE PortfolioID = {PortfolioID} ORDER BY ImportDate DESC
```

#### Step 6.3: Test Price Weighting

```sql
-- Calculate FIFO/WAC for new portfolio
EXEC Core.pCalculatePriceWeighting @PortfolioID = {PortfolioID}, @CalculationDate = '{TestDate}'

-- Verify price weighting
SELECT * FROM Core.dbo.vPriceWeighting WHERE PortfolioID = {PortfolioID} AND PositionDate = '{TestDate}'
```

---

## Example Setups

### Example 1: New Company - Elmwood Partners

**Scenario:** Onboard new private equity firm Elmwood Partners

**Steps:**
1. Created company record (CompanyID 42)
2. Set default settings (Markit pricing, USD currency)
3. Created master fund "Elmwood Fund I LP" (FundID 128)
4. Created two portfolios:
   - "Elmwood Trading" (PortfolioID 256) - BNY custodian
   - "Elmwood Custody" (PortfolioID 257) - State Street custodian
5. Configured cash rec for both portfolios
6. Set up FIFO price weighting for trading portfolio
7. Configured daily BNY/State Street position imports
8. Tested import with sample file - successful

### Example 2: Portfolio Name Change - Rebranding

**Scenario:** Marathon Fund rebranded to Titan Capital

**Old Name:** Marathon Growth Fund LP
**New Name:** Titan Capital Growth Fund LP

**Steps:**
1. Updated company name: Employee.tCompany (Marathon → Titan Capital)
2. Updated fund name: Core.tFund (Marathon Growth Fund LP → Titan Capital Growth Fund LP)
3. Updated 3 portfolio names in Core.tPortfolio
4. Updated CAMOS client name for reporting
5. Added Type 2 SCD records in DW.dimPortfolio
6. Coordinated custodian name change with BNY Mellon
7. Verified next day custodian file showed new name
8. Updated documentation and user guides

### Example 3: Fund Restructuring - Master/Feeder

**Scenario:** Convert standalone fund to master/feeder structure

**Old Structure:**
- Acme Fund LP (standalone)

**New Structure:**
- Acme Master Fund LP (master)
  - Acme Domestic Feeder LP (US investors)
  - Acme Offshore Feeder LP (non-US investors)

**Steps:**
1. Created master fund record (FundID 200) with NULL MasterFundID
2. Created two feeder fund records:
   - Domestic Feeder (FundID 201) with MasterFundID = 200
   - Offshore Feeder (FundID 202) with MasterFundID = 200
3. Migrated existing portfolio (PortfolioID 100) to master fund
4. Created new portfolios for each feeder
5. Set up cash rec for feeders (allocate from master)
6. Configured position consolidation view (feeders + master)
7. Tested with sample data - allocations correct

---

## Common Issues and Resolutions

| Issue | Cause | Resolution |
|-------|-------|------------|
| **Custodian import fails** | Missing field mapping | Add field mapping in Custodian.tFieldMapping |
| **Price weighting errors** | No config record | Insert record in Core.tPriceWeightingConfig |
| **Cash rec disabled** | Missing config | Insert record in CashRec.tPortfolioConfig |
| **Duplicate portfolio code** | Code already exists | Use unique portfolio code |
| **Name change not in reports** | DW not updated | Add Type 2 SCD record in DW.dimPortfolio |
| **Custodian file wrong account** | Account mapping wrong | Update Core.tPortfolioMapping |

---

## Skill Metadata

- **Skill Name:** portfolio-setup
- **Category:** Portfolio/Fund Setup
- **Complexity:** Medium
- **Execution Time:** 30-90 minutes
- **Prerequisites:** Access to Core, Employee, Custodian, CashRec schemas, company information
- **Outputs:** New company/fund/portfolio records, custodian mappings, configuration settings
- **Related Skills:**
  - cash-reconciliation (cash rec setup validation)
  - data-normalization (custodian feed setup)
  - pricing-source-investigation (price source configuration)
