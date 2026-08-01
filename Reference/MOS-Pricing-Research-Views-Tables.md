# MOS Pricing Research - Essential Views and Tables

## Overview

This document catalogs the essential database views and tables used for investigating pricing discrepancies, price source issues, and market data quality in the MOS (Middle Office System).

**Last Updated:** 2026-07-23  
**Environment:** MOS Production (mos-sql-p.mos.siepe.local,52155) / Development (mos-sql-d.mos.siepe.local,52155)

---

## Key Concepts & Glossary

### What is an Instrument?
An **instrument** (also called a "security") is any tradable financial asset that holds value. In MOS, instruments are stored in the Reference database and represent the master record for each security across all portfolios.

**Examples:**
- **Equity Common** - Common stock (e.g., Apple Inc. shares, CUSIP: 037833100)
- **Corporate Bond** - Corporate debt instrument (e.g., Apple 3.45% 2029, ISIN: US037833DL16)
- **Government Bond** - Treasury or sovereign debt (e.g., US Treasury 10Y)
- **Mutual Fund** - Pooled investment vehicle
- **Option** - Derivative contract for right to buy/sell
- **Forward** - Over-the-counter derivative agreement

**Instrument Identifiers:**
Each instrument can have multiple identifiers used by different systems:
- **CUSIP** - 9-character identifier (used in North America)
- **ISIN** - 12-character international identifier
- **SEDOL** - 7-character identifier (UK/Europe)
- **Ticker** - Stock exchange symbol (e.g., "AAPL")
- **BBGlobalID** - Bloomberg unique identifier
- **FIGI** - Financial Instrument Global Identifier (ISO standard)

### What is a Portfolio?
A **portfolio** is a collection of investment positions held by a specific fund, account, or client. Each portfolio is tracked separately in MOS and has its own set of positions, valuations, and performance metrics.

**Examples:**
- ABC Growth Fund (equity-focused fund)
- XYZ Bond Fund (fixed income portfolio)  
- Client Segregated Account (individual client holdings)
- Pension Fund Plan A (retirement portfolio)

**Portfolio Hierarchy:**
```
Company (e.g., "Siepe Capital")
└── Fund (e.g., "Growth Fund")
    └── Portfolio (e.g., "Growth Fund - Main Account")
```

### What is a Position?
A **position** represents the quantity and value of a specific instrument held in a portfolio on a specific date. Positions track:
- **Quantity** - How many shares/units are owned
- **Mark (Price)** - Current market price per unit
- **Market Value** - Total value (Quantity × Mark)
- **Cost Basis** - Original purchase price

**Position Example:**
```
Portfolio: ABC Growth Fund
Instrument: Apple Inc. (CUSIP: 037833100)
Date: 2026-07-23
Quantity: 1,000 shares
Mark: $175.50 per share
Market Value: $175,500
Cost Basis: $150.00 per share (purchased earlier)
```

### What is a Mark (Position Mark)?
A **mark** is the price assigned to an instrument for valuation purposes. Marks come from various sources:
- **Market Prices** - Real-time or end-of-day prices from exchanges or vendors (Markit, LSEG, ICE)
- **Cost Pricing** - Using original purchase price when no market price is available
- **Manual Overrides** - Operations team manually sets price for illiquid/private securities
- **Model Prices** - Calculated using pricing models for derivatives or structured products

**Pricing Hierarchy:** MOS uses a waterfall approach - if Markit price unavailable, fall back to LSEG, then ICE, then manual override, then cost.

### What is a RefDataSet?
A **RefDataSet** (Reference Data Set) is a snapshot of all position data for a specific business date. Each night, MOS creates a new RefDataSet capturing:
- All portfolio positions as of that date
- Market valuations
- Cash balances
- Corporate actions applied
- Performance calculations

**Think of it as:** A complete photograph of all portfolios at the close of business on a specific day.

### What is RefRecStatusID?
**RefRecStatusID** (Reference Record Status ID) tracks whether a database record is active or inactive:
- `1` = **Active** - Current, valid record
- `2` = **Inactive** - Deleted or superseded record (soft delete)
- `9` = **Historical** - Archived for historical reference only

**Why this matters:** Always filter `WHERE RefRecStatusID = 1` to get only active records. MOS uses "soft deletes" - records are never physically removed, just marked inactive.

### Asset Classes and Instrument Types

**Asset Classes** (high-level groupings):
- **Equity** - Ownership stakes (stocks, shares)
- **Fixed Income** - Debt instruments (bonds, notes)
- **Cash** - Cash equivalents and money market
- **Derivative** - Contracts derived from underlying assets (options, futures, swaps)
- **Alternative** - Non-traditional investments (private equity, hedge funds, real estate)

**Instrument Types** (specific classifications):
- Equity Common, Equity Preferred, Equity Rights
- Corporate Bond, Government Bond, Municipal Bond
- Call Option, Put Option, Future, Forward, Swap
- Mutual Fund, ETF, REIT
- Private Equity, Hedge Fund

### Data Relationships and Flow

#### Entity Relationship Diagram (Conceptual)
```
┌─────────────────┐
│   RefDataSet    │ ← Daily snapshot (one per business day)
│  (Date: 7/23)   │
└────────┬────────┘
         │
         │ contains many
         ↓
┌─────────────────┐      ┌──────────────┐
│    Position     │─────→│   Portfolio  │ (which fund/account)
│  (InstID: 123)  │      │ (ABC Growth) │
│  (Mark: 175.50) │      └──────────────┘
│  (Qty: 1000)    │
└────────┬────────┘
         │
         │ references
         ↓
┌─────────────────┐      ┌───────────────────┐
│   Instrument    │─────→│ InstIdentifier    │ (CUSIP, ISIN, etc.)
│  (Apple Inc.)   │      │ CUSIP: 037833100  │
│  Type: Equity   │      │ ISIN: US0378...   │
└────────┬────────┘      └───────────────────┘
         │
         │ has pricing from
         ↓
┌─────────────────┐
│   InstPrice     │
│ Source: Markit  │
│ Date: 7/23      │
│ Price: 175.50   │
└─────────────────┘
```

#### How Position Pricing Works (Step-by-Step)

**1. Instrument Master Created**
```sql
Reference.dbo.vInst
InstID: 12345
Description: "Apple Inc."
InstType: "Equity Common"
```

**2. Identifiers Added**
```sql
Reference.dbo.vInstIdentifierCurrent
InstID: 12345, Type: "CUSIP", Value: "037833100"
InstID: 12345, Type: "ISIN", Value: "US0378331005"
InstID: 12345, Type: "Ticker", Value: "AAPL"
```

**3. Price Feeds Loaded (Daily)**
```sql
Core.dbo.vInstPriceCurrentRaw
InstID: 12345
PriceDate: 2026-07-23
InstPriceSource: "Markit Closed"
Price: 175.50
```

**4. Portfolio Holds Position**
```sql
Core.dbo.vPortfolio
PortfolioID: 5001
Name: "ABC Growth Fund"
```

**5. Position Created/Updated**
```sql
Core.dbo.vPositionRaw
PositionID: 789456
RefDataSetDate: 2026-07-23
PortfolioID: 5001 (ABC Growth Fund)
InstID: 12345 (Apple Inc.)
SettledQty: 1000 shares
PositionMark: 175.50 (from Markit price)
SettledMV: 175,500 (1000 × 175.50)
CostBasisSettled: 150.00 (what we paid originally)
UnrealizedGainLoss: 25,500 (175,500 - 150,000)
```

#### Price Selection Logic (Waterfall)

MOS uses a **pricing hierarchy** (waterfall) to select the best price for each position:

```
1. Manual Override (highest priority)
   ↓ (if none, fall back to)
2. Primary Vendor (Markit Closed)
   ↓ (if missing, fall back to)
3. Secondary Vendor (LSEG Pricing)
   ↓ (if missing, fall back to)
4. Tertiary Vendor (ICE Price)
   ↓ (if missing, fall back to)
5. Cost Basis (fallback for illiquid securities)
```

**Configured in:** `Core.dbo.tPositionPriceWeighting`

**Why this matters for pricing research:**
- If you see different prices across portfolios for the same instrument, they may be using different price sources
- Positions "priced at cost" means no market price was available in any vendor feed
- Price source changes indicate vendor data issues or configuration changes

---

## How to Find InstID

The `InstID` is the primary key for instruments in MOS. You'll need it for most pricing research queries. Here are the common ways to find it:

### 1. By Identifier (CUSIP, ISIN, Ticker) - Most Common Method

**By CUSIP (most reliable for US securities):**
```sql
SELECT InstID, InstIdentifierType, Value
FROM Reference.dbo.vInstIdentifierCurrent
WHERE InstIdentifierType = 'CUSIP'
    AND Value = '037833100'  -- Apple's CUSIP
```

**By ISIN (most reliable for international securities):**
```sql
SELECT InstID, InstIdentifierType, Value
FROM Reference.dbo.vInstIdentifierCurrent
WHERE InstIdentifierType = 'ISIN'
    AND Value = 'US0378331005'  -- Apple's ISIN
```

**By Ticker (less reliable - can have duplicates across exchanges):**
```sql
SELECT 
    ii.InstID, 
    ii.Value AS Ticker,
    i.Description,
    i.InstType
FROM Reference.dbo.vInstIdentifierCurrent ii
INNER JOIN Reference.dbo.vInst i ON ii.InstID = i.InstID
WHERE ii.InstIdentifierType = 'Ticker'
    AND ii.Value = 'AAPL'
    AND i.RefRecStatusID = 1  -- Active only
```

### 2. By Instrument Name - Search/Browse

**Exact match:**
```sql
SELECT InstID, Description, InstType, AssetClass
FROM Reference.dbo.vInst
WHERE Description = 'Apple Inc.'
    AND RefRecStatusID = 1  -- Active instruments only
```

**Partial match (fuzzy search):**
```sql
SELECT InstID, Description, InstType, AssetClass
FROM Reference.dbo.vInst
WHERE Description LIKE '%Apple%'
    AND RefRecStatusID = 1
ORDER BY Description
```

**Bond search (with maturity):**
```sql
SELECT 
    InstID, 
    Description, 
    InstType,
    MaturityDate
FROM Reference.dbo.vInst
WHERE Description LIKE '%Apple%'
    AND InstType LIKE '%Bond%'
    AND RefRecStatusID = 1
ORDER BY MaturityDate
```

### 3. From Position Data - If You Know the Portfolio

**Get all instruments in a specific portfolio:**
```sql
SELECT DISTINCT 
    p.InstID,
    i.Description,
    i.InstType,
    id.Value AS CUSIP
FROM Core.dbo.vPositionRaw p
INNER JOIN Reference.dbo.vInst i ON p.InstID = i.InstID
LEFT JOIN Reference.dbo.vInstIdentifierCurrent id 
    ON p.InstID = id.InstID 
    AND id.InstIdentifierType = 'CUSIP'
WHERE p.PortfolioID = 5001
    AND p.RefDataSetDate = '2026-07-23'
    AND p.SettledQty <> 0  -- Only positions with holdings
ORDER BY i.Description
```

**Get all instruments with pricing issues:**
```sql
SELECT DISTINCT 
    p.InstID,
    i.Description,
    p.PositionMark,
    p.PositionMarkSource
FROM Core.dbo.vPositionRaw p
INNER JOIN Reference.dbo.vInst i ON p.InstID = i.InstID
WHERE p.RefDataSetDate = '2026-07-23'
    AND (p.PositionMark IS NULL OR p.PositionMarkSource LIKE '%Cost%')
ORDER BY i.Description
```

### 4. Bulk Lookup - Multiple Identifiers at Once

**Lookup multiple CUSIPs:**
```sql
SELECT 
    i.InstID,
    i.Description,
    i.InstType,
    id.InstIdentifierType,
    id.Value
FROM Reference.dbo.vInst i
INNER JOIN Reference.dbo.vInstIdentifierCurrent id ON i.InstID = id.InstID
WHERE id.Value IN ('037833100', '459200101', '594918104')
    AND id.InstIdentifierType = 'CUSIP'
```

**Lookup with all identifiers (comprehensive view):**
```sql
SELECT 
    i.InstID,
    i.Description,
    i.InstType,
    i.AssetClass,
    MAX(CASE WHEN id.InstIdentifierType = 'CUSIP' THEN id.Value END) AS CUSIP,
    MAX(CASE WHEN id.InstIdentifierType = 'ISIN' THEN id.Value END) AS ISIN,
    MAX(CASE WHEN id.InstIdentifierType = 'Ticker' THEN id.Value END) AS Ticker,
    MAX(CASE WHEN id.InstIdentifierType = 'SEDOL' THEN id.Value END) AS SEDOL
FROM Reference.dbo.vInst i
LEFT JOIN Reference.dbo.vInstIdentifierCurrent id ON i.InstID = id.InstID
WHERE i.Description LIKE '%Apple%'
    AND i.RefRecStatusID = 1
GROUP BY i.InstID, i.Description, i.InstType, i.AssetClass
```

### Best Practices for InstID Lookup

✅ **Recommended:**
- Use CUSIP for US securities (most reliable)
- Use ISIN for international securities
- Always filter by `RefRecStatusID = 1` to get active instruments only
- Use INNER JOIN when you need instrument details with identifiers

❌ **Avoid:**
- Relying solely on Ticker (can be ambiguous - same ticker on different exchanges)
- Searching by description without wildcards (spelling variations exist)
- Using InstID values hardcoded in queries (they can change across environments)

**Common Identifier Types in MOS:**
- `CUSIP` - 9 characters (US/Canada)
- `ISIN` - 12 characters (international standard)
- `SEDOL` - 7 characters (UK/Europe)
- `Ticker` - Variable length (exchange symbol)
- `BBGlobalID` - Bloomberg unique ID
- `FIGI` - ISO 24165 standard

---

## Reading Query Results - Practical Examples

### Example 1: Understanding a Position Row

**Query Result:**
```
RefDataSetDate: 2026-07-23
PortfolioID: 5001
PortfolioName: ABC Growth Fund
InstID: 12345
CUSIP: 037833100
Description: Apple Inc.
SettledQty: 1000
PositionMark: 175.50
SettledMV: 175500.00
CostBasisSettled: 150.00
CostAmountSettled: 150000.00
```

**What this means:**
- **Date:** As of close of business on July 23, 2026
- **Portfolio:** The "ABC Growth Fund" portfolio
- **Instrument:** Holds 1,000 shares of Apple Inc. stock
- **Current Value:** Each share is marked at $175.50 = $175,500 total value
- **Original Cost:** Originally purchased at $150/share = $150,000 total cost
- **Unrealized Profit:** $175,500 - $150,000 = $25,500 gain (not yet sold)

### Example 2: Identifying Pricing Inconsistency

**Query Result:**
```
RefDataSetDate: 2026-07-23
InstID: 67890
CUSIP: 123456789
Description: XYZ Corp Bond 5% 2030
PortfolioCount: 3
MinPrice: 98.50
MaxPrice: 99.25
PriceVariance: 0.75
PortfolioDetails: Fund A (98.50), Fund B (99.25), Fund C (98.50)
```

**What this means:**
- **Issue:** Three portfolios hold the same bond but with different prices
- **Price Range:** From $98.50 to $99.25 (75 cents difference)
- **Investigation Needed:** 
  - Why does Fund B have a higher price?
  - Check price sources: Fund B may be using a different pricing vendor
  - Could be stale price (Fund B using yesterday's close)
  - Could be manual override in Fund B

**Next Steps:**
```sql
-- Check price sources for each portfolio
SELECT 
    p.PortfolioID,
    port.Name,
    p.PositionMark,
    ip.InstPriceSource,
    ip.PriceDate
FROM Core.dbo.vPositionRaw p
INNER JOIN Core.dbo.vPortfolio port ON p.PortfolioID = port.PortfolioID
LEFT JOIN Core.dbo.vInstPriceCurrentRaw ip 
    ON p.InstID = ip.InstID 
    AND p.RefDataSetDate = ip.PriceDate
WHERE p.InstID = 67890
    AND p.RefDataSetDate = '2026-07-23'
```

### Example 3: Day-Over-Day Price Change

**Query Result:**
```
PortfolioID: 5001
PortfolioName: ABC Growth Fund
InstID: 45678
CUSIP: 987654321
Description: DEF Technology Inc
PriorDate: 2026-07-22
PriorPrice: 250.00
CurrentDate: 2026-07-23
CurrentPrice: 265.00
PriceChange: 15.00
PercentChange: 6.00
```

**What this means:**
- **Security:** DEF Technology Inc stock
- **Yesterday:** Priced at $250.00
- **Today:** Priced at $265.00
- **Change:** +$15.00 per share (+6.0%)
- **Analysis:** 6% increase in one day is significant
  - Could be legitimate (earnings beat, acquisition news)
  - Could be pricing error (wrong source, stale data)
  - Verify against external sources (Bloomberg, Yahoo Finance)

### Example 4: Position Priced at Cost

**Query Result:**
```
RefDataSetDate: 2026-07-23
PortfolioID: 5002
PortfolioName: Private Equity Fund
InstID: 99999
CUSIP: (none)
Description: ABC Private Company Series A Preferred
PositionMark: 10.00
CostBasis: 10.00
Quantity: 100000
MarketValue: 1000000.00
PriceSource: No Market Price
IsPricedAtCost: 1
```

**What this means:**
- **Security:** Private company stock (not publicly traded)
- **Pricing:** Using cost basis ($10/share) because no market price exists
- **Risk:** If company value has changed, this valuation may be inaccurate
- **Action Needed:**
  - Private securities should have periodic valuations (quarterly/annually)
  - If valuation was done, update with manual price override
  - Flag for portfolio manager to provide updated fair value

### Example 5: Missing Price

**Query Result:**
```
RefDataSetDate: 2026-07-23
PortfolioID: 5003
PortfolioName: Bond Fund
InstID: 55555
CUSIP: 456789123
Description: GHI Corp 3.75% 2028
Quantity: 500000
PositionMark: NULL
MarketValue: NULL
PriceSource: (none)
DaysStale: 3
```

**What this means:**
- **Problem:** No price available for this bond
- **Impact:** Cannot value the position (shows NULL market value)
- **Investigation:**
  - Check if vendor (Markit, LSEG) is providing this price
  - CUSIP may be wrong or changed (reorg, merger)
  - Bond may be called or matured
  - Vendor may have delisted this security
  
**Resolution:**
```sql
-- Check if price exists in vendor feed
SELECT TOP 5 
    PriceDate,
    InstPriceSource,
    Price
FROM Core.dbo.vInstPriceCurrentRaw
WHERE InstID = 55555
ORDER BY PriceDate DESC

-- If no prices found, check instrument identifiers
SELECT 
    InstIdentifierType,
    Value
FROM Reference.dbo.vInstIdentifierCurrent
WHERE InstID = 55555
```

---

## Troubleshooting Common Pricing Issues

### Issue: "Position shows in one portfolio but not another"
**Cause:** Portfolios may settle trades on different schedules (T+1 vs T+2)  
**Check:** Compare `SettledQty` vs `TradedQty` - position may show in TradedQty but not SettledQty  
**Query:**
```sql
SELECT 
    PortfolioID,
    InstID,
    SettledQty,
    TradedQty,
    SettledQty - TradedQty AS Pending
FROM Core.dbo.vPositionRaw
WHERE InstID = @InstID
    AND RefDataSetDate = @Date
    AND (SettledQty <> 0 OR TradedQty <> 0)
```

### Issue: "Price changed dramatically overnight"
**Cause:** Corporate action (stock split, reverse split, dividend)  
**Check:** Look for corporate actions in Reference.tCorporateAction  
**Example:** 2-for-1 split means quantity doubles, price halves (value unchanged)

### Issue: "Same CUSIP shows different InstIDs"
**Cause:** Instrument merger, acquisition, or identifier reassignment  
**Check:** Historical identifier records may show the change  
**Action:** Update positions to use new InstID

### Issue: "Bond price over 100"
**Cause:** Bond trading above par (premium bond)  
**Interpretation:** Normal for bonds when market rates drop below coupon rate  
**Example:** 5% coupon bond when market rates are 3% → trades at ~105-110

### Issue: "Negative market value"
**Cause:** Short position (sold shares you don't own)  
**Interpretation:** SettledQty will be negative  
**Example:** SettledQty=-100, Mark=50 → SettledMV=-5000 (you owe shares)

---

## Core Database (Core.dbo)

### Position and Mark Data

#### Core.dbo.vPositionRaw
**Purpose:** Raw position data including marks, quantities, and market values for all portfolios and dates  
**Use Cases:**
- Identifying pricing inconsistencies across portfolios
- Finding positions priced at cost vs market
- Comparing day-over-day price changes
- Analyzing position marks and valuations

**All Columns with Semantic Descriptions:**

| Column Name | Data Type | Semantic Meaning |
|-------------|-----------|------------------|
| `PositionID` | INT | Unique identifier for this position record |
| `RefDataSetID` | INT | Links to vRefDataSetActiveRaw - identifies which daily snapshot this position belongs to |
| `RefDataSetDate` | DATE | Business date of this position (computed from RefDataSetID) |
| `PortfolioID` | INT | Which portfolio holds this position |
| `InstID` | INT | Which instrument (security) this position represents |
| **Quantity Fields** | | |
| `SettledQty` | DECIMAL | **Settled Quantity** - Shares/units owned after all trades have settled (T+2 for stocks) |
| `TradedQty` | DECIMAL | **Traded Quantity** - Shares/units including unsettled trades (shows pending trades) |
| `PendingQty` | DECIMAL | **Pending Quantity** - Difference between Traded and Settled (trades in flight) |
| **Mark/Price Fields** | | |
| `PositionMark` | DECIMAL | **Mark Price** - Price per unit used for valuation (from price vendor or override) |
| `PriceFactor` | DECIMAL | **Price Factor** - Multiplier for bonds quoted as percentage (e.g., 98.5 means 98.5% of par) |
| `FXRate` | DECIMAL | **Foreign Exchange Rate** - Conversion rate to reporting currency if position is in foreign currency |
| **Market Value Fields** | | |
| `SettledMV` | DECIMAL | **Settled Market Value** - Total value of settled position (SettledQty × PositionMark) |
| `TradedMV` | DECIMAL | **Traded Market Value** - Total value including unsettled trades (TradedQty × PositionMark) |
| `SettledRCMV` | DECIMAL | **Settled Reporting Currency MV** - Settled MV converted to reporting currency (USD) |
| `TradedRCMV` | DECIMAL | **Traded Reporting Currency MV** - Traded MV converted to reporting currency (USD) |
| **Cost Basis Fields** | | |
| `CostBasisSettled` | DECIMAL | **Settled Cost Basis** - Average cost per unit for settled shares (what you paid) |
| `CostBasisTraded` | DECIMAL | **Traded Cost Basis** - Average cost per unit including pending trades |
| `CostAmountSettled` | DECIMAL | **Settled Cost Amount** - Total cost of settled position (SettledQty × CostBasisSettled) |
| `CostAmountTraded` | DECIMAL | **Traded Cost Amount** - Total cost including pending trades |
| `CostAmountSettledRC` | DECIMAL | **Settled Cost in Reporting Currency** - Cost amount converted to USD |
| `CostAmountTradedRC` | DECIMAL | **Traded Cost in Reporting Currency** - Cost amount converted to USD |
| **Gain/Loss Fields** | | |
| `UnrealizedGainLoss` | DECIMAL | **Unrealized Gain/Loss** - Profit/loss on position not yet sold (MV - Cost) |
| `RealizedGainLoss` | DECIMAL | **Realized Gain/Loss** - Profit/loss from sales completed today |
| **Metadata Fields** | | |
| `RefDataSourceID` | INT | Source system that provided this position data (Custodian, Internal, etc.) |
| `DataSourceKey` | NVARCHAR | External system's unique key for this position |
| `RefRecStatusID` | INT | Record status: 1=Active, 2=Inactive/Deleted |
| `CreatedDate` | DATETIME | When this position record was created in MOS |
| `CreatedUser` | NVARCHAR | User/system that created this record |
| `ModifiedDate` | DATETIME | When this record was last updated |
| `ModifiedUser` | NVARCHAR | User/system that last modified this record |

**Standard Query Pattern:**
```sql
SELECT 
    p.RefDataSetDate,
    p.PortfolioID,
    p.InstID,
    p.PositionMark,
    p.SettledQty,
    p.SettledMV
FROM Core.dbo.vPositionRaw p
INNER JOIN Core.dbo.vRefDataSetActiveRaw rds 
    ON p.RefDataSetID = rds.RefDataSetID
WHERE p.RefDataSetDate = @AsOfDate
    AND p.SettledQty <> 0
```

---

#### Core.dbo.vRefDataSetActiveRaw
**Purpose:** Active reference data sets for position snapshots  
**Use Cases:**
- Mapping RefDataSetID to RefDataSetDate
- Finding the most recent position date
- Filtering for active data sets only

**Key Columns:**
- `RefDataSetID` - Unique identifier
- `RefDataSetDate` - Date of the data set
- `RefRecStatusID` - Status (1 = Active)

**Standard Query Pattern:**
```sql
-- Get most recent date
SELECT MAX(RefDataSetDate) 
FROM Core.dbo.vRefDataSetActiveRaw

-- Join with positions
FROM Core.dbo.vPositionRaw p
INNER JOIN Core.dbo.vRefDataSetActiveRaw rds 
    ON p.RefDataSetID = rds.RefDataSetID
```

---

#### Core.dbo.vPortfolio
**Purpose:** Portfolio master data  
**Use Cases:**
- Getting portfolio names and descriptions
- Filtering by portfolio type
- Portfolio-level aggregations

**All Columns with Semantic Descriptions:**

| Column Name | Data Type | Semantic Meaning |
|-------------|-----------|------------------|
| `PortfolioID` | INT | Unique identifier for this portfolio |
| `Name` | NVARCHAR | **Portfolio Name** - Display name (e.g., "ABC Growth Fund - Main") |
| `Description` | NVARCHAR | **Portfolio Description** - Longer description or purpose of portfolio |
| `PortfolioType` | NVARCHAR | **Portfolio Type Name** - Classification (e.g., "Equity Fund", "Bond Fund", "Segregated Account") |
| `PortfolioTypeID` | INT | Portfolio type reference ID |
| `BaseCurrencyID` | INT | **Base Currency** - Primary reporting currency for this portfolio (usually USD) |
| `CustodianID` | INT | **Custodian** - Which custodian bank holds the assets (e.g., State Street, BNY Mellon) |
| `AnalystID` | INT | **Portfolio Manager/Analyst** - Person responsible for managing this portfolio |
| `OpenDate` | DATE | **Portfolio Open Date** - When portfolio was established |
| `CloseDate` | DATE | **Portfolio Close Date** - When portfolio was closed (NULL if still active) |
| `IncludeInAUM` | BIT | **Include in Assets Under Management** - Whether to count in firm's total AUM (1=Yes, 0=No) |
| `WireAccountNumber` | NVARCHAR | Bank wire account number for cash movements |
| `RefDataSource` | NVARCHAR | Source system that maintains this portfolio master record |
| `RefDataSourceID` | INT | Source system reference ID |
| `DataSourceKey` | NVARCHAR | External system's unique key for this portfolio |
| `RefRecStatusID` | INT | Record status: 1=Active, 2=Inactive/Closed |
| `CreatedDate` | DATETIME | When this portfolio was created in MOS |
| `CreatedUser` | NVARCHAR | User who created this portfolio record |

**Standard Query Pattern:**
```sql
SELECT 
    port.PortfolioID,
    port.Name AS PortfolioName,
    port.PortfolioType
FROM Core.dbo.vPortfolio port
WHERE port.RefRecStatusID = 1
```

---

### Price and Source Data

#### Core.dbo.vInstPriceCurrentRaw
**Purpose:** Current instrument prices with price sources  
**Use Cases:**
- Identifying price sources (Markit, LSEG, ICE, Manual overrides)
- Finding missing or stale prices
- Price source change tracking

**All Columns with Semantic Descriptions:**

| Column Name | Data Type | Semantic Meaning |
|-------------|-----------|------------------|
| `InstPriceID` | INT | Unique identifier for this price record |
| `InstID` | INT | Which instrument this price applies to |
| `Price` | DECIMAL | **Market Price** - Price per unit in the denomination currency |
| `PriceDate` | DATE | **Price Date** - Business date this price is for (not when it was loaded) |
| `InstPriceSource` | NVARCHAR | **Price Source Name** - Where this price came from (see common sources below) |
| `InstPriceSourceID` | INT | Price source reference ID |
| `PriceRefDataSourceID` | INT | Reference data source that provided this price |
| `Ask` | DECIMAL | **Ask Price** - Price at which market will sell to you (higher) |
| `Bid` | DECIMAL | **Bid Price** - Price at which market will buy from you (lower) |
| `RefCurrencyID` | INT | **Price Currency** - Currency the price is quoted in |
| `Depth` | INT | **Price Depth** - For Time & Sales data, quantity available at this price |
| `EffFromDate` | DATETIME | **Effective From** - When this price became effective (includes time) |
| `EffThruDate` | DATETIME | **Effective Through** - When this price was superseded (9999-12-31 if current) |
| `RefDataSourceID` | INT | Source system that loaded this price |
| `DataSourceKey` | NVARCHAR | External system's unique key for this price |
| `RefRecStatusID` | INT | Record status: 1=Active, 2=Inactive/Superseded |
| `CreatedDate` | DATETIME | When this price record was created in MOS |
| `CreatedUser` | NVARCHAR | User/system that created this price (often "SSIS" for automated feeds) |

**Standard Query Pattern:**
```sql
SELECT 
    ip.InstID,
    ip.Price,
    ip.PriceDate,
    ip.InstPriceSource,
    ip.RefCurrencyID
FROM Core.dbo.vInstPriceCurrentRaw ip
WHERE ip.PriceDate = @AsOfDate
    AND ip.RefRecStatusID = 1
```

**Common Price Sources:**
- `Markit Closed` - Markit end-of-day pricing
- `LSEG Pricing` - London Stock Exchange Group pricing
- `ICE Price` - ICE Data Services
- `MOS Ops Price Override [Client]` - Manual price overrides
- `Solvas Global Pricing` - Solvas pricing feed
- `GarnetPricing` - Garnet pricing source

---

#### Core.dbo.tPositionPriceWeighting
**Purpose:** Price weighting configurations for portfolios  
**Use Cases:**
- Understanding how prices are selected for positions
- Debugging price source selection logic

**Key Columns:**
- `PositionPriceWeightingID` - Unique identifier
- `PortfolioID` - Portfolio this applies to
- `InstPriceSourceID` - Price source priority
- `Weighting` - Priority/weight value

---

## Reference Database (Reference.dbo)

### Instrument Master Data

#### Reference.dbo.vInst
**Purpose:** Instrument master reference data  
**Use Cases:**
- Getting instrument descriptions and classifications
- Filtering by asset type (equity, fixed income, derivative)
- Instrument attribute lookups

**All Columns with Semantic Descriptions:**

| Column Name | Data Type | Semantic Meaning |
|-------------|-----------|------------------|
| `InstID` | INT | Unique identifier for this instrument across all systems |
| `Description` | NVARCHAR | **Instrument Name** - Full security name (e.g., "Apple Inc.", "US Treasury 2.5% 2029") |
| `InstType` | NVARCHAR | **Instrument Type** - Specific classification (e.g., "Equity Common", "Corporate Bond", "Call Option") |
| `InstTypeID` | INT | Instrument type reference ID |
| `InstSubType` | NVARCHAR | **Instrument Sub-Type** - Additional classification detail |
| `AssetClass` | NVARCHAR | **Asset Class** - High-level grouping (e.g., "Equity", "Fixed Income", "Derivative", "Cash") |
| `IssuerID` | INT | **Issuer** - Company/government that issued this security |
| `IssuerName` | NVARCHAR | **Issuer Name** - Name of issuing entity (e.g., "Apple Inc.", "US Treasury") |
| `CountryOfRisk` | NVARCHAR | **Country of Risk** - Primary country exposure (e.g., "United States", "Germany") |
| `CountryOfRiskID` | INT | Country reference ID |
| `CurrencyID` | INT | **Denomination Currency** - Currency the instrument is denominated in |
| `MaturityDate` | DATE | **Maturity Date** - When bond/debt instrument matures (NULL for equities) |
| `CouponRate` | DECIMAL | **Coupon Rate** - Interest rate for bonds (e.g., 3.5 means 3.5% annual) |
| `ParValue` | DECIMAL | **Par Value** - Face value of bond (usually 100 or 1000) |
| `IssueDate` | DATE | **Issue Date** - When instrument was originally issued |
| `ExchangeCode` | NVARCHAR | **Exchange** - Where instrument trades (e.g., "NYSE", "NASDAQ", "LSE") |
| `Sector` | NVARCHAR | **Sector** - Industry sector (e.g., "Technology", "Healthcare", "Financials") |
| `IndustryGroup` | NVARCHAR | **Industry Group** - More specific industry classification |
| `RefDataSource` | NVARCHAR | Source system for instrument master data |
| `RefDataSourceID` | INT | Source system reference ID |
| `DataSourceKey` | NVARCHAR | External system's unique key |
| `RefRecStatusID` | INT | Record status: 1=Active, 2=Inactive/Delisted |
| `CreatedDate` | DATETIME | When this instrument was added to MOS |
| `CreatedUser` | NVARCHAR | User who created this record |

**Standard Query Pattern:**
```sql
SELECT 
    i.InstID,
    i.Description,
    i.InstType,
    i.AssetClass
FROM Reference.dbo.vInst i
WHERE i.RefRecStatusID = 1
```

---

#### Reference.dbo.vInstIdentifierCurrent
**Purpose:** Current instrument identifiers (CUSIP, ISIN, SEDOL, Ticker, etc.)  
**Use Cases:**
- Looking up instruments by CUSIP/ISIN
- Getting all identifiers for an instrument
- Cross-referencing with external systems

**Key Columns:**
- `InstID` - Instrument identifier
- `InstIdentifierID` - Unique identifier record ID
- `InstIdentifierType` - Type (e.g., "CUSIP", "ISIN", "SEDOL", "Ticker")
- `InstIdentifierTypeID` - Type reference
- `Value` - The actual identifier value
- `RefRecStatusID` - Active status (1 = Active)

**Standard Query Pattern:**
```sql
SELECT 
    i.InstID,
    cusip.Value AS CUSIP,
    isin.Value AS ISIN,
    ticker.Value AS Ticker
FROM Reference.dbo.vInst i
LEFT JOIN Reference.dbo.vInstIdentifierCurrent cusip 
    ON i.InstID = cusip.InstID 
    AND cusip.InstIdentifierType = 'CUSIP'
LEFT JOIN Reference.dbo.vInstIdentifierCurrent isin 
    ON i.InstID = isin.InstID 
    AND isin.InstIdentifierType = 'ISIN'
LEFT JOIN Reference.dbo.vInstIdentifierCurrent ticker 
    ON i.InstID = ticker.InstID 
    AND ticker.InstIdentifierType = 'Ticker'
```

**Common Identifier Types:**
- `CUSIP` - 9-character US security identifier
- `ISIN` - 12-character international identifier
- `SEDOL` - 7-character UK identifier
- `Ticker` - Exchange ticker symbol
- `BBGlobalID` - Bloomberg Global ID
- `FIGI` - Financial Instrument Global Identifier

---

## Dashboard Database (Dashboard.dbo)

### Dashboard Stored Procedures

#### Dashboard.pIntegrityMissingPrices
**Purpose:** Identifies positions with missing or stale prices  
**Use Cases:**
- Finding positions that need pricing
- Monitoring price coverage
- Operations Dashboard widget

**Key Parameters:**
- `@RefDataSetDate` - Date to check
- `@GetColumnList` - Return column metadata for dashboard

---

#### Dashboard.pIntegrityPriceSourceChanges
**Purpose:** Tracks price source changes over time  
**Use Cases:**
- Monitoring when price sources change
- Identifying pricing method shifts
- Price source stability analysis

---

#### Dashboard.pPricingInconsistenciesAcrossPortfolios
**Purpose:** Identifies instruments with different prices across portfolios on same date  
**Use Cases:**
- Finding pricing inconsistencies
- Quality control for pricing
- Portfolio reconciliation

**Key Parameters:**
- `@AsOfDate` - Date to check
- `@MinVarianceThreshold` - Minimum price difference to report
- `@GetColumnList` - Return column metadata

---

#### Dashboard.pIntegrityDayOverDayPriceChanges
**Purpose:** Identifies significant day-over-day price movements  
**Use Cases:**
- Finding unusual price changes
- Price validation
- Market event detection

**Key Parameters:**
- `@PortfolioID` - Portfolio filter
- `@StartDate`, `@EndDate` - Date range
- `@ChangeThreshold` - Minimum % change to report
- `@GetColumnList` - Return column metadata

---

#### Dashboard.pIntegrityAssetsPricedAtCost
**Purpose:** Identifies positions priced at cost vs market  
**Use Cases:**
- Finding positions lacking market prices
- Cost vs market analysis
- Price coverage gaps

**Key Parameters:**
- `@RefDataSetDate` - Date to check
- `@PortfolioID` - Portfolio filter
- `@GetColumnList` - Return column metadata

---

## Common Pricing Research Queries

### 1. Find Instruments with Multiple Prices on Same Date
```sql
SELECT 
    p.RefDataSetDate,
    p.InstID,
    i.Description,
    COUNT(DISTINCT p.PortfolioID) AS PortfolioCount,
    MIN(p.PositionMark) AS MinPrice,
    MAX(p.PositionMark) AS MaxPrice,
    MAX(p.PositionMark) - MIN(p.PositionMark) AS PriceVariance
FROM Core.dbo.vPositionRaw p
INNER JOIN Core.dbo.vRefDataSetActiveRaw rds 
    ON p.RefDataSetID = rds.RefDataSetID
INNER JOIN Reference.dbo.vInst i 
    ON p.InstID = i.InstID
WHERE p.RefDataSetDate = '2026-07-23'
    AND p.PositionMark IS NOT NULL
    AND p.PositionMark <> 0
GROUP BY p.RefDataSetDate, p.InstID, i.Description
HAVING COUNT(DISTINCT p.PortfolioID) > 1
    AND (MAX(p.PositionMark) - MIN(p.PositionMark)) >= 0.01
ORDER BY PriceVariance DESC
```

### 2. Get Price Sources for an Instrument
```sql
SELECT 
    ip.InstID,
    i.Description,
    ip.PriceDate,
    ip.Price,
    ip.InstPriceSource,
    ip.EffFromDate,
    ip.EffThruDate
FROM Core.dbo.vInstPriceCurrentRaw ip
INNER JOIN Reference.dbo.vInst i 
    ON ip.InstID = i.InstID
WHERE ip.InstID = @InstID
    AND ip.PriceDate BETWEEN @StartDate AND @EndDate
ORDER BY ip.PriceDate DESC, ip.EffFromDate DESC
```

### 3. Find Positions Missing Market Prices (Priced at Cost)
```sql
SELECT 
    p.RefDataSetDate,
    p.PortfolioID,
    port.Name AS PortfolioName,
    p.InstID,
    i.Description,
    p.PositionMark,
    p.CostBasisSettled,
    p.SettledQty
FROM Core.dbo.vPositionRaw p
INNER JOIN Core.dbo.vRefDataSetActiveRaw rds 
    ON p.RefDataSetID = rds.RefDataSetID
INNER JOIN Core.dbo.vPortfolio port 
    ON p.PortfolioID = port.PortfolioID
INNER JOIN Reference.dbo.vInst i 
    ON p.InstID = i.InstID
WHERE p.RefDataSetDate = '2026-07-23'
    AND p.SettledQty <> 0
    AND ABS(p.PositionMark - p.CostBasisSettled) < 0.01  -- Mark equals cost
    AND p.CostBasisSettled <> 0
ORDER BY port.Name, i.Description
```

### 4. Day-Over-Day Price Changes
```sql
WITH CurrentPrices AS (
    SELECT 
        p.PortfolioID,
        p.InstID,
        p.RefDataSetDate AS CurrentDate,
        p.PositionMark AS CurrentPrice
    FROM Core.dbo.vPositionRaw p
    INNER JOIN Core.dbo.vRefDataSetActiveRaw rds 
        ON p.RefDataSetID = rds.RefDataSetID
    WHERE p.RefDataSetDate = '2026-07-23'
        AND p.PositionMark > 0
),
PriorPrices AS (
    SELECT 
        p.PortfolioID,
        p.InstID,
        p.RefDataSetDate AS PriorDate,
        p.PositionMark AS PriorPrice
    FROM Core.dbo.vPositionRaw p
    INNER JOIN Core.dbo.vRefDataSetActiveRaw rds 
        ON p.RefDataSetID = rds.RefDataSetID
    WHERE p.RefDataSetDate = '2026-07-22'
        AND p.PositionMark > 0
)
SELECT 
    curr.PortfolioID,
    curr.InstID,
    i.Description,
    prior.PriorDate,
    prior.PriorPrice,
    curr.CurrentDate,
    curr.CurrentPrice,
    curr.CurrentPrice - prior.PriorPrice AS PriceChange,
    CASE 
        WHEN prior.PriorPrice > 0 
        THEN ((curr.CurrentPrice - prior.PriorPrice) / prior.PriorPrice) * 100
        ELSE 0
    END AS PercentChange
FROM CurrentPrices curr
INNER JOIN PriorPrices prior 
    ON curr.PortfolioID = prior.PortfolioID
    AND curr.InstID = prior.InstID
INNER JOIN Reference.dbo.vInst i 
    ON curr.InstID = i.InstID
WHERE ABS(((curr.CurrentPrice - prior.PriorPrice) / prior.PriorPrice) * 100) >= 1.0  -- 1% threshold
ORDER BY ABS((curr.CurrentPrice - prior.PriorPrice) / prior.PriorPrice) DESC
```

---

## Best Practices

### Always Filter by Active Records
```sql
WHERE RefRecStatusID = 1
```

### Use vRefDataSetActiveRaw for Date Filtering
```sql
INNER JOIN Core.dbo.vRefDataSetActiveRaw rds 
    ON p.RefDataSetID = rds.RefDataSetID
WHERE rds.RefDataSetDate = @AsOfDate
```

### Query Views, Not Tables
- Always use views (v prefix) for SELECT queries
- Only access tables (t prefix) for INSERT/UPDATE/DELETE
- Exception: UPDATE...FROM can query views in FROM clause

### Schema Prefix Requirements
- Procedures in Dashboard/Report schema MUST prefix Core and Reference objects
- Procedures in Core (dbo) schema can optionally omit dbo. prefix for Core objects

---

## Related Documentation

- [MOSSystemConnectionsReference.md](../MOSSystemConnectionsReference.md) - Database connection strings
- [Siepe Database Standards](../.github/skills/siepe-database-standards/SKILL.md) - SQL coding standards
- [Bulk Price Validation](../.github/skills/bulk-price-validation/SKILL.md) - Price exception research workflow

---

## Frequently Used Filters

### Get Most Recent Position Date
```sql
SELECT MAX(RefDataSetDate) FROM Core.dbo.vRefDataSetActiveRaw
```

### Filter by Portfolio
```sql
WHERE p.PortfolioID = @PortfolioID
-- OR
WHERE port.Name = 'Portfolio Name'
```

### Filter by Instrument Type
```sql
WHERE i.InstType = 'Equity Common'
-- OR
WHERE i.AssetClass = 'Fixed Income'
```

### Filter by Price Source
```sql
WHERE ip.InstPriceSource = 'Markit Closed'
-- OR
WHERE ip.InstPriceSource LIKE 'MOS Ops Price Override%'
```

### Exclude Zero Positions
```sql
WHERE p.SettledQty <> 0
AND p.PositionMark IS NOT NULL
AND p.PositionMark <> 0
```

---

## Contact

For pricing discrepancy investigation support, contact MOS Operations team or submit ADO ticket under Siepe.Software project.
