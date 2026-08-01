# Solvas Transaction Extract History Procedure - Step-by-Step Breakdown

**Stored Procedure:** `[Feeds].[solvas_am].[pTransactionExtractHistory]`  
**Database:** Solvas (Feeds)  
**Purpose:** Extract historical transaction snapshots from Solvas current state (not event log based)  
**Date Documented:** 2026-07-07

---

## Overview

This procedure extracts **current state** transaction data from Solvas_AM using "Raw" views. Unlike `pTransactionExtract` which uses event logs, this procedure queries the current transaction tables directly to build a historical snapshot.

**Key Differences from pTransactionExtract:**
- ✅ Uses `vXXXRaw` views (current state) instead of event logs
- ✅ No date range filtering - uses `@TransID` for specific transaction extraction
- ✅ Simpler execution model - 3 UNION queries instead of event-based logic
- ✅ Handles "virtual" facility transactions (exist only in facility table, not account_transaction)
- ✅ Always returns ActionCode 'ADD' or 'DELETE' (based on settle status)

**Use Cases:**
- Ad-hoc transaction lookups by TransID
- Historical state extraction for specific funds/groups
- Backfill or reconciliation scenarios
- Investigating specific transaction issues

---

## Parameters

| Parameter | Type | Description | Default | Required |
|-----------|------|-------------|---------|----------|
| `@GroupName` | VARCHAR(100) | Entity group name (e.g., 'MOS', 'collateraladmin') | None | ✅ Yes |
| `@Fund` | INT | Specific fund ID within group | NULL | ❌ No (NULL = all funds in group) |
| `@TransID` | VARCHAR(8000) | Comma-separated transaction IDs | NULL | ❌ No (NULL = all transactions) |

**Example Executions:**
```sql
-- All transactions for MOS fund 131
EXEC Solvas_AM.pTransactionExtractHistory 'MOS', 131

-- All transactions for collateraladmin (all funds)
EXEC Solvas_AM.pTransactionExtractHistory 'collateraladmin', NULL

-- Specific transactions for collateraladmin
EXEC Solvas_AM.pTransactionExtractHistory 'collateraladmin', NULL, '1723,1724,1725'
```

---

## Execution Flow

### **Phase 1: Initialization & Validation**

#### Step 1.1: Parse Transaction IDs
**Purpose:** Convert comma-separated @TransID into temp table

```sql
CREATE TABLE #TransIDs (TransID INT)

-- Split comma-separated string using custom function
-- Example: '1723,1724,1725' → 3 rows (1723, 1724, 1725)
```

**Function Used:** `dbo.fnCOMSplitTableT(@TransID, ',')`
- Splits string by delimiter
- Returns table with [row] column
- GROUP BY eliminates duplicates

**Result:** `#TransIDs` populated if @TransID provided, empty otherwise

---

#### Step 1.2: Build Entity List
**Purpose:** Get all EntityIDs for specified group/fund

```sql
CREATE TABLE #EntityIDs (EntityID INT PRIMARY KEY)

-- Calls function to get entities
INSERT INTO #EntityIDs
SELECT DISTINCT EntityID
FROM feeds.solvas_am.fEntityList(2, @GroupName, @Fund)
```

**Function:** `fEntityList(2, @GroupName, @Fund)`
- Parameter 1: 2 (likely a type indicator)
- Returns list of entity IDs matching criteria

---

#### Step 1.3: Validate Entities Exist
**Purpose:** Fail fast if no entities found

```sql
IF NOT EXISTS (SELECT 1 FROM #EntityIDs)
BEGIN
    THROW 50001, 'No EntityIDs found for the provided GroupName/Fund.', 1;
END
```

**Error Handling:**
- Throws SQL exception with code 50001
- Prevents execution with invalid group/fund combinations
- Better than returning empty result set

---

### **Phase 2: Build Reference Data**

#### Step 2.1: Extract Proceeds Type Mapping
**Source:** `Solvas_AM.dbo.Transaction_Account_Proceeds_view`

**Purpose:** Determine if transaction has Principal (P), Interest (I), or both (PI)

**Logic:**
```sql
-- If transaction has BOTH P and I proceeds on same account → 'PI'
-- Otherwise use original proceeds_type from view
```

**Columns:**
- entity_id, trans_category, trans_id, trans_date
- account_id, payment_status_override
- proceeds_type (calculated)
- trans_amount

**Filters:**
- `entity_id IN #EntityIDs`
- `@TransID IS NULL OR trans_id IN #TransIDs`

**Result:** Populates `#ProceedsType`

---

#### Step 2.2: Extract Transaction Type to Account Mapping
**Source:** `Solvas_AM.dbo.Account_Trans_Type_Map`

**Purpose:** Map transaction types to accounts for each entity

**Columns:**
- entity_id, trans_type, account_id
- trans_currency, proceeds_type

**Filters:**
- `active_account = 1`
- `entity_id IN #EntityIDs`

**Result:** Populates `#TransType`

---

#### Step 2.3: Create Result Table
**Purpose:** Define structure for final output

**Table:** `#Result`

**Columns (63 total):**
- **Transaction IDs:** AccountTransId, TransId, CashTransactionId
- **Instrument:** IssuerId, IssuerName, IssuerCountry, IssueId, FacilityId, CUSIP, ISIN, LoanX, InstName
- **Account:** AccountId, AccountName, AccountType
- **Entity:** EntityId, DealName
- **Transaction Details:** Category, Type, Description, Notes, Dates
- **Amounts:** Cash, Principal, Interest, Total
- **Trade Info:** TradeId, TradeDate, SettleDate, Price, Par
- **Status:** ActionCode, Received, LedgerType, ProceedsType
- **Metadata:** CreateDate, EventDate, SortOrder, ExtractSource

---

#### Step 2.4: Create Asset Detail Tables
**Purpose:** Store facility, bond, and equity asset attributes

**Tables Created:**
1. `#facility` - 15 columns (loan/facility details)
2. `#bond` - 13 columns (bond/security details)
3. `#equity` - 5 columns (equity details)

---

### **Phase 3: Extract Transactions (3 UNION Queries)**

#### Query 1: Account Transactions (Main Query)
**Purpose:** Extract all transactions linked to accounts

**Source:** `Solvas_am.vAccount_Transaction_expanded_viewRaw`

**Key Joins:**
- `vAccountRaw` (account details) - INNER JOIN
- `vEntityRaw` (deal/entity) - INNER JOIN
- `vIssuerRaw` (issuer) - LEFT JOIN
- `vIssueRaw` (bond/security) - LEFT JOIN
- `vFacilityRaw` (loan/facility) - LEFT JOIN
- `vIssue_TransactionRaw` (issue transaction details) - LEFT JOIN
- `vEquity_TransactionRaw` (equity transaction) - LEFT JOIN
- `vEquity_TradeRaw` (equity trade) - LEFT JOIN
- `vFacility_TransactionRaw` (facility transaction) - LEFT JOIN
- `vFacility_TradeRaw` (facility trade) - LEFT JOIN
- `Facility_Trade_Transaction` (facility trade link) - LEFT JOIN
- `vAccount_Cash_Transaction_expanded_viewRaw` (cash details) - LEFT JOIN (subquery)
- `vFacilitySecurityTransactionPar` (par values) - LEFT JOIN
- `vTransferTypeView` (transfer type descriptions) - LEFT JOIN
- `#ProceedsType` (proceeds mapping) - LEFT JOIN
- `#TransType` (type mapping) - LEFT JOIN

**AccountTransId Calculation:**
```sql
CAST(itv.account_trans_id as VARCHAR(MAX))
```
- Direct from account_transaction table
- Indicates transaction has account linkage

**AccountTransactionStatus:**
- Always 'ACTIVE' (current state view)

**TransactionCategory Mapping:**
```sql
CASE trans_category
    WHEN 'I' THEN 'Issue'
    WHEN 'L' THEN 'Facility'
    WHEN 'E' THEN 'Entity'
    WHEN 'T' THEN 'Transfer'
    WHEN 'Q' THEN 'Equity'
END
```

**TransactionDate Logic:**
```sql
CASE 
    WHEN ftd.ftrade_id IS NOT NULL THEN ftd.trade_date  -- Use trade date if linked to facility trade
    ELSE itv.trans_date  -- Otherwise use transaction date
END
```

**ActionCode Logic:**
```sql
CASE 
    WHEN ftd.settle_date IS NOT NULL AND itv.settle_date IS NULL THEN 'DELETE'
    -- Trade is settled but transaction shows unsettled → Pending trade deleted
    ELSE 'ADD'
END
```

**ActionCodeId:**
- 1 = ADD
- 3 = DELETE

**Proceeds Type Priority:**
1. `#ProceedsType` (pre-calculated from proceeds view)
2. `#TransType` (from account type mapping)
3. Calculated from principal/interest amounts
4. 'U' (Unknown) as fallback

**Filters:**
- `E.entity_id IN #EntityIDs`
- `@TransID IS NULL OR itv.trans_id IN #TransIDs`

**Result:** Inserts into `#Result` with ExtractSource = 'ExtractHistory'

---

#### Query 2: Virtual Facility Transactions
**Purpose:** Extract facility transactions NOT linked to any account

**Source:** `Solvas_am.vFacility_TransactionRaw`

**What are "Virtual" Transactions?**
- Exist in Facility_Transaction table
- Do NOT exist in Account_Transaction table
- Examples: PIK, exchange, pending trades not yet allocated

**Key Filter:**
```sql
NOT EXISTS (
    SELECT 1
    FROM Solvas_am.vAccount_Transaction_expanded_viewRaw atv
    WHERE atv.trans_id = ftr.facility_trans_id
    AND atv.trans_category = 'L'
)
```
This ensures we only get facility transactions NOT captured in Query 1

**Additional Filter:**
```sql
((fstp.commitment_amount <> 0) OR (ftr.ftrade_id IS NOT NULL))
```
Only include if:
- Has non-zero commitment amount, OR
- Is linked to a trade

**AccountTransId Calculation:**
```sql
CASE 
    WHEN ftr.ftrade_id IS NOT NULL THEN Concat(ftr.facility_trans_id, ftr.ftrade_id)  -- Pending trade
    ELSE CAST(ftr.facility_trans_id as varchar(max)) + 'L'  -- PIK/exchange
END
```
- Pending trades: Concatenated ID
- Other: TransID + 'L' suffix

**AccountId Logic:**
```sql
COALESCE(aft.account_id, pt.account_id, ftr.entity_id, 0)
```
Priority:
1. Account from trade allocation (aft - subquery)
2. Account from trans type mapping (pt)
3. Entity ID as fallback
4. 0 if none found

**InstName Logic:**
```sql
COALESCE(
    f.facility_name,
    CASE WHEN ftd.ftrade_id IS NOT NULL 
        THEN FacilityTradeTransDesc(trade_type, TransTypeDesc(trans_type, position_type))
        ELSE TransTypeDesc(trans_type, position_type)
    END
)
```
- Facility name if available
- Otherwise descriptive text based on trade/transaction type

**Key Joins:**
- `vFacility_TradeRaw` (trade details) - LEFT JOIN
- Subquery for account allocation (finds account from other transactions with same trade_id)
- `vEntityRaw` (required - INNER JOIN)
- `vFacilitySecurityTransactionPar` (par values) - LEFT JOIN
- `vFacilityRaw` (facility master) - LEFT JOIN
- `vIssuerRaw` (issuer) - LEFT JOIN
- `#ProceedsType`, `#TransType`, `vTransferTypeView` - LEFT JOINs

**Special Handling:**
- IssueId always NULL (facility transactions)
- TransactionCategoryCode always 'L'
- TransactionCategory always 'Facility'
- Cash amounts always NULL (not linked to account)
- Received always 0

**Result:** Inserts into `#Result` with ExtractSource = 'ExtractHistory'

---

#### Query 3: Cash Transactions
**Purpose:** Extract cash receipts/payments linked to transactions

**Source:** `Solvas_am.vAccount_Transaction_expanded_viewRaw` + `vAccount_Cash_Transaction_expanded_viewRaw`

**Key Join:**
```sql
JOIN vAccount_Cash_Transaction_expanded_viewRaw ac 
    ON ac.Trans_id = itv.Trans_id 
    AND ac.account_id = itv.Account_id 
    AND ac.Trans_type = itv.Trans_type
```
This links cash entries to their parent transactions

**Additional Join:**
```sql
JOIN solvas_am.dbo.account_transaction at 
    ON ac.Account_Trans_ID = at.Account_Trans_ID
```
Gets cash_trans_id from base table

**Key Differences from Query 1:**
- `TransactionCategory = 'Cash'` (always)
- `TransactionCategoryCode = COALESCE(ac.trans_category, itv.trans_category, 'U')`
- `CashTransactionId = at.cash_trans_id` (populated)
- `CashAmount = AC.total_proceeds` (populated)
- `PostDate = AC.cash_date` (cash posting date)
- `Received = 1` (indicates cash actually received)
- `ActionCode = 'ADD'` (always)
- `ActionCodeId = 1` (always)

**TransactionDate:**
- Uses `itv.trans_date` (parent transaction date, not cash date)

**SettleDate:**
```sql
ISNULL(itv.settle_date, ftd.settle_date)
```
- Transaction settle date or trade settle date

**LedgerType:**
- Based on cash record's principal/interest amounts (ac.princ_proceeds_amt, ac.int_proceeds_amt)
- Not from parent transaction (itv)

**Proceeds Type Priority:**
1. Calculated from cash amounts (ac)
2. `#ProceedsType` mapping
3. 'U' (Unknown)

**Filters:**
- `E.entity_id IN #EntityIDs`
- `@TransID IS NULL OR itv.trans_id IN #TransIDs`

**Result:** Inserts into `#Result` with ExtractSource = 'ExtractHistory'

---

### **Phase 4: Extract Asset Details**

#### Step 4.1: Extract Facility Asset Details
**Source:** `Solvas_AM.dbo.Facility`

**As-Of Date:** `GETDATE()` (current date)

**Columns Extracted:**
- **Identifiers:** ISIN, LIN, LX_Identifier, Bloomberg ID, Facility Number, CUSIP
- **Asset Type:** Always 'Loan'
- **Seniority:** From `cdosys_Lookup_Code_view` (security_level lookup)
- **Lien Type:** 
  - 'FRST' → 'First'
  - 'SCND' → 'Second'
- **Floating Rate Details:**
  - Index Type: From `tf_Global_Loan_view` (TSFR, SONA, L, or RFR types)
  - Spread: From `Facility_Spread_History_view` as of today
- **Maturity Date**

**OUTER APPLY Logic:**

**First OUTER APPLY - Index Type:**
```sql
SELECT TOP 1 glv.index_type, glv.currency_code
FROM tf_Global_Loan_view() glv
WHERE glv.facility_id = f.facility_id
    AND IssueGlobalOutstandingAmountAsofDate(glv.loan_id, @as_of_date) > 0.00
    AND (glv.index_type IN ('TSFR', 'SONA', 'L') OR glv.index_type IN (...RFR types...))
ORDER BY 
    CASE WHEN glv.facility_currency = glv.loan_currency THEN 1 ELSE 2 END ASC,
    IssueGlobalOutstandingAmountAsofDate(glv.loan_id, @as_of_date) DESC,
    glv.loan_id
```
- Gets index type for loans with outstanding balance
- Prioritizes facility currency matches
- Orders by outstanding amount (largest first)

**Second OUTER APPLY - Spread:**
```sql
SELECT TOP 1 fshv.interest_rate_spread
FROM Facility_Spread_History_view fshv
LEFT JOIN Facility_Global_Transaction fgt ON ...
WHERE fshv.facility_id = f.facility_id
    AND fshv.index_type = cv.index_type
    AND fshv.index_currency = cv.currency_code
    AND fshv.change_date <= @as_of_date
ORDER BY fshv.change_date DESC, fgt.trans_date DESC
```
- Gets most recent spread change before as-of date
- Matches index type and currency from first OUTER APPLY

**Filter:**
```sql
WHERE EXISTS (SELECT 1 FROM #Result r WHERE r.FacilityId = f.facility_id)
```
- Only extracts for facilities in result set

**Result:** Populates `#facility`

---

#### Step 4.2: Extract Bond Asset Details
**Source:** `Solvas_AM.dbo.Issue`

**Columns Extracted:**
- **Identifiers:** CUSIP, ISIN
- **Asset Type:** 
  - 'S' → 'Bond'
  - 'A' → 'FBS' (Fixed income backed security)
  - 'E' → 'Equity'
- **Sub Type:** From security_type lookup
- **Coupon Details:**
  - Is Fixed: 'Yes' if coupon_type = 'F', else 'No'
  - Fixed Rate: Interest rate as of today (if fixed)
  - Floating Spread: Interest rate spread (if variable RFR type)
- **Maturity Date**

**Floating Spread Logic:**
```sql
CASE 
    WHEN (coupon_type = 'V')  -- Variable rate
        AND EXISTS (
            -- Check if index type is RFR-based (TSFR, SONA, L, or RFR types)
            SELECT cit.coupon_index_type
            FROM cdobiz_Coupon_Index cit
            WHERE cit.coupon_index = IssueIndexTypeAsofDate(issue_id, GETDATE())
                AND cit.coupon_index_type IN (...)
        )
    THEN IssueInterestRateSpreadAsofDate(issue_id, @as_of_date)
END
```
- Only populates for variable rate bonds
- Only for RFR-based index types
- Gets spread as of today

**Filters:**
- `EXISTS (SELECT 1 FROM #Result r WHERE r.IssueId = ie.issue_id)`
- `issue_type NOT IN ('L', 'E')` - Excludes loans and equities

**Result:** Populates `#bond`

---

#### Step 4.3: Extract Equity Asset Details
**Source:** `Solvas_AM.dbo.Equity`

**Columns Extracted:**
- Issuer name
- Asset name (equity_name)
- CUSIP, ISIN
- Asset ID (equity_id)

**Filter:**
```sql
WHERE EXISTS (SELECT 1 FROM #Result r WHERE r.IssueId = ie.equity_id)
```

**Result:** Populates `#equity`

---

### **Phase 5: Final Result Assembly**

#### Step 5.1: Join Asset Details
**Purpose:** Add asset-specific columns to result set

**Joins:**
```sql
FROM #Result R
LEFT JOIN #facility fc ON fc.facility_id = R.FacilityId
LEFT JOIN #bond b ON b.asset_id = R.IssueId
LEFT JOIN #equity e ON e.asset_id = R.IssueId
```

**Coalesced Columns:**
- **CUSIP:** `COALESCE(fc.CUSIP, b.CUSIP, e.CUSIP)`
- **ISIN:** `COALESCE(fc.ISIN, b.ISIN, e.ISIN)`
- **LoanX:** `fc.LX_Identifier`
- **Asset Name:** `COALESCE(fc.asset_name, b.asset_name, e.asset_name)`
- **Floating Spread:** `COALESCE(fc.Asset_FloatingSpread, b.Asset_FloatingSpread)`
- **Maturity Date:** `COALESCE(fc.Asset_MaturityDate, b.Asset_MaturityDate)`
- **Asset Type:** `COALESCE(fc.Asset_AssetTypeID_CodeName, b.Asset_AssetTypeID_CodeName)`

**Facility-Only Columns:**
- Seniority, Lien Type, LIN, Bloomberg ID, Facility Number

**Bond-Only Columns:**
- Sub Type, Is Fixed, Fixed Rate

---

#### Step 5.2: Return Final Result Set
**Total Columns:** 63 + 15 asset detail columns = 78 columns

**No Sorting:** Results returned in insertion order

**No Filters:** All rows from #Result returned

---

## Key Design Patterns

### 1. **Current State Extraction**
- Uses "Raw" views (current state tables)
- No event log processing
- Simpler than event-based extraction
- Represents "snapshot" at execution time

### 2. **Three Transaction Categories**
1. **Account Transactions** (Query 1) - Majority of transactions
2. **Virtual Facility Transactions** (Query 2) - Special facility-only records
3. **Cash Transactions** (Query 3) - Payment/receipt records

### 3. **UNION Strategy**
- Three separate queries combined with UNION
- Each query handles different transaction type
- Avoids complex conditional logic in single query

### 4. **Optional TransID Filtering**
- `@TransID IS NULL` → All transactions for group/fund
- `@TransID provided` → Only specified transactions
- Comma-separated list parsed into temp table

### 5. **Proceeds Type Hierarchy**
1. Pre-calculated from proceeds view (#ProceedsType)
2. Account type mapping (#TransType)
3. Calculated from amounts
4. Default to 'U' (Unknown)

### 6. **Virtual Transaction Handling**
- Facility transactions can exist without account linkage
- Query 2 specifically targets these "virtual" records
- Uses NOT EXISTS to exclude duplicates

---

## Comparison: pTransactionExtract vs pTransactionExtractHistory

| Aspect | pTransactionExtract | pTransactionExtractHistory |
|--------|---------------------|----------------------------|
| **Data Source** | Event log (ECI_Event_Log) | Current state (Raw views) |
| **Time Range** | Date-based (@StartDate, @EndDate) | TransID-based or all |
| **Event Types** | ADD, UPDATE, DELETE (from log) | ADD, DELETE (calculated) |
| **Incremental** | Yes (tracks last run) | No (snapshot) |
| **Performance** | Slower (event reconstruction) | Faster (direct queries) |
| **Historical Accuracy** | Event-based (what happened) | State-based (current state) |
| **Complexity** | High (7 phases, event processing) | Medium (3 UNIONs, simpler logic) |
| **Use Case** | Incremental ETL, data warehouse | Ad-hoc queries, backfills |
| **Pending Trades** | Managed via settle/unsettle logic | Identified by settle_date mismatch |

---

## Common Usage Scenarios

### Scenario 1: Full Fund Extraction
```sql
-- Get all transactions for MOS fund 131
EXEC Solvas_AM.pTransactionExtractHistory 'MOS', 131
```

**Result:** 
- All account transactions (Query 1)
- All virtual facility transactions (Query 2)
- All cash transactions (Query 3)
- For fund 131 in MOS group

---

### Scenario 2: Group-Wide Extraction
```sql
-- Get all transactions for entire collateraladmin group
EXEC Solvas_AM.pTransactionExtractHistory 'collateraladmin', NULL
```

**Result:**
- All transactions across all funds in group
- Larger result set
- May be slower

---

### Scenario 3: Specific Transaction Lookup
```sql
-- Investigate specific transactions
EXEC Solvas_AM.pTransactionExtractHistory 'collateraladmin', NULL, '1723,1724,1725'
```

**Result:**
- Only transactions 1723, 1724, 1725
- Much faster than full extraction
- Useful for troubleshooting specific issues

**Note:** Cash transactions (Query 3) linked to parent transactions also returned

---

### Scenario 4: Pending Trade Identification
**Look for records where:**
- `ActionCode = 'DELETE'`
- `ActionCodeId = 3`

**Meaning:**
- Trade is settled (ftd.settle_date IS NOT NULL)
- Transaction shows unsettled (itv.settle_date IS NULL)
- Indicates pending trade should be removed

---

### Scenario 5: Cash Receipt Verification
**Filter results where:**
- `Received = 1`
- `CashTransactionId IS NOT NULL`
- `TransactionCategory = 'Cash'`

**Meaning:**
- Cash was actually received/paid
- Has link to parent transaction
- Can reconcile cash vs. expected proceeds

---

## Performance Considerations

### 1. **Entity List Function**
```sql
feeds.solvas_am.fEntityList(2, @GroupName, @Fund)
```
- Called once and materialized into #EntityIDs
- Primary key on EntityID improves join performance
- More efficient than calling function multiple times

### 2. **TransID Parsing**
```sql
dbo.fnCOMSplitTableT(@TransID, ',')
```
- Converts string to table once
- Enables JOIN instead of IN with string parsing
- More efficient than dynamic SQL

### 3. **NOLOCK Hints**
- Used on `Facility_Trade_Transaction` table
- Read uncommitted isolation level
- Faster but may see uncommitted data

### 4. **Raw Views**
- Pre-filtered views with common joins
- Better than joining base tables directly
- May have additional indexes

### 5. **NOT EXISTS vs LEFT JOIN**
```sql
NOT EXISTS (SELECT 1 FROM ... WHERE ...)
```
- More efficient than LEFT JOIN with NULL check
- Stops searching after first match
- Used to exclude virtual transactions

### 6. **OUTER APPLY**
- Used for correlated subqueries
- Returns TOP 1 result per facility
- More efficient than subquery in SELECT

---

## Error Handling

### Explicit Error
```sql
IF NOT EXISTS (SELECT 1 FROM #EntityIDs)
BEGIN
    THROW 50001, 'No EntityIDs found for the provided GroupName/Fund.', 1;
END
```

**When Triggered:**
- Invalid @GroupName
- Invalid @Fund
- Group/Fund combination doesn't exist

**Recommendation:** Add additional validation:
- Check @TransID format (all numeric)
- Validate transaction IDs exist
- Log execution details for auditing

---

## Testing Scenarios

### Test 1: Single Fund, All Transactions
```sql
EXEC Solvas_AM.pTransactionExtractHistory 'MOS', 131
```

**Expected:**
- Returns all transactions for fund 131
- Includes virtual facility transactions
- Includes cash transactions
- Should match count in views

---

### Test 2: Multiple Specific Transactions
```sql
EXEC Solvas_AM.pTransactionExtractHistory 'collateraladmin', 144, '1723,1724,1725'
```

**Expected:**
- Returns exactly 3 parent transactions
- Plus any linked cash transactions
- Plus any virtual facility transactions (if applicable)

---

### Test 3: Invalid Group Name
```sql
EXEC Solvas_AM.pTransactionExtractHistory 'INVALID_GROUP', NULL
```

**Expected:**
- Error: "No EntityIDs found for the provided GroupName/Fund."
- No result set returned

---

### Test 4: Verify Virtual Transactions
```sql
-- Run procedure
EXEC Solvas_AM.pTransactionExtractHistory 'MOS', 131

-- Check for virtual facility transactions
SELECT * FROM <result>
WHERE TransactionCategoryCode = 'L'
  AND AccountTransId LIKE '%L'  -- Ends with 'L'
```

**Expected:**
- AccountTransId format: '{TransID}L'
- AccountId might be 0 or EntityId
- No cash amounts
- Only facility-related fields populated

---

### Test 5: Cash Transaction Reconciliation
```sql
-- Run procedure
EXEC Solvas_AM.pTransactionExtractHistory 'MOS', 131

-- Compare cash vs. parent transactions
SELECT 
    TransId,
    COUNT(DISTINCT CASE WHEN Received = 0 THEN 1 END) AS ParentTransCount,
    COUNT(DISTINCT CASE WHEN Received = 1 THEN 1 END) AS CashTransCount,
    SUM(CASE WHEN Received = 0 THEN TotalProceedsAmount ELSE 0 END) AS ExpectedProceeds,
    SUM(CASE WHEN Received = 1 THEN CashAmount ELSE 0 END) AS ActualCash
FROM <result>
GROUP BY TransId
HAVING SUM(CASE WHEN Received = 1 THEN CashAmount ELSE 0 END) <> 
       SUM(CASE WHEN Received = 0 THEN TotalProceedsAmount ELSE 0 END)
```

**Expected:**
- Identifies transactions with cash discrepancies
- Partial payments have ActualCash < ExpectedProceeds
- Overpayments have ActualCash > ExpectedProceeds

---

## Dependencies

### Tables Referenced (Base)
- `Solvas_AM.dbo.Transaction_Account_Proceeds_view`
- `Solvas_AM.dbo.Account_Trans_Type_Map`
- `Solvas_AM.dbo.Account`
- `Solvas_AM.dbo.account_transaction`
- `Solvas_AM.dbo.Facility`
- `Solvas_AM.dbo.Issue`
- `Solvas_AM.dbo.Equity`
- `Solvas_AM.dbo.Issuer`
- `Solvas_AM.dbo.cdosys_Lookup_Code_view`
- `Solvas_AM.dbo.Facility_Trade_Transaction`
- `Solvas_AM.dbo.Facility_Spread_History_view`
- `Solvas_AM.dbo.Facility_Global_Transaction`
- `Solvas_AM.dbo.cdobiz_Coupon_Index`
- `Solvas_AM.dbo.Cash_Transaction_view`

### Views Used (Raw Views)
- `Solvas_am.vAccount_Transaction_expanded_viewRaw` ⭐ Core
- `Solvas_am.vAccountRaw`
- `Solvas_am.vEntityRaw`
- `Solvas_am.vIssuerRaw`
- `Solvas_am.vIssueRaw`
- `Solvas_am.vFacilityRaw`
- `Solvas_am.vIssue_TransactionRaw`
- `Solvas_am.vEquity_TransactionRaw`
- `Solvas_am.vEquity_TradeRaw`
- `Solvas_am.vFacility_TransactionRaw` ⭐ Core
- `Solvas_am.vFacility_TradeRaw`
- `Solvas_am.vAccount_Cash_Transaction_expanded_viewRaw` ⭐ Core
- `Solvas_am.vFacilitySecurityTransactionPar`
- `Solvas_am.vTransferTypeView`
- `Solvas_AM.dbo.cdobiz_RFR_Index_Type_view`

### Functions Used
- `feeds.solvas_am.fEntityList(2, @GroupName, @Fund)` ⭐ Critical
- `dbo.fnCOMSplitTableT(@TransID, ',')` ⭐ Critical
- `Solvas_AM.dbo.CodeDesc()` (Lookup descriptions)
- `Solvas_am.dbo.FacilityTradeTransDesc()` (Trade descriptions)
- `Solvas_AM.dbo.TransTypeDesc()` (Transaction type descriptions)
- `Solvas_AM.dbo.IssueGlobalOutstandingAmountAsofDate()`
- `Solvas_AM.dbo.IssueInterestRateAsofDate()`
- `Solvas_AM.dbo.IssueInterestRateSpreadAsofDate()`
- `Solvas_AM.dbo.IssueIndexTypeAsofDate()`
- `Solvas_AM.dbo.tf_Global_Loan_view()`

### Table-Valued Functions
- `tf_Global_Loan_view()` - Returns global loan details

---

## Monitoring & Troubleshooting

### Check Entity List
```sql
SELECT * FROM feeds.solvas_am.fEntityList(2, 'MOS', 131)
SELECT * FROM feeds.solvas_am.fEntityList(2, 'collateraladmin', NULL)
```

**Expected:**
- Returns list of EntityIDs
- If empty, group/fund combination invalid

---

### Verify TransID Format
```sql
-- Parse TransID string
SELECT [row] AS TransID  
FROM dbo.fnCOMSplitTableT('1723,1724,1725', ',')
```

**Expected:**
- Returns 3 rows: 1723, 1724, 1725
- All numeric values
- No leading/trailing spaces

---

### Check Transaction Counts by Category
```sql
-- Run procedure into temp table
SELECT * INTO #ProcResult
FROM (...result of procedure...)

-- Analyze by category
SELECT 
    TransactionCategory,
    TransactionCategoryCode,
    COUNT(*) AS TransCount,
    COUNT(DISTINCT TransId) AS UniqueTransIds,
    SUM(CASE WHEN Received = 1 THEN 1 ELSE 0 END) AS CashTransCount,
    COUNT(DISTINCT AccountId) AS UniqueAccounts
FROM #ProcResult
GROUP BY TransactionCategory, TransactionCategoryCode
ORDER BY TransCount DESC
```

---

### Find Virtual Facility Transactions
```sql
SELECT 
    AccountTransId,
    TransId,
    FacilityId,
    InstName,
    AccountId,
    AccountName,
    Price,
    Par,
    ExtractSource
FROM #ProcResult
WHERE TransactionCategoryCode = 'L'
  AND (AccountTransId LIKE '%L' OR AccountId = 0)
ORDER BY TransId
```

**Interpretation:**
- AccountTransId ending in 'L' = Virtual transaction
- AccountId = 0 = No account mapping found
- AccountId = EntityId = Fell back to entity

---

### Verify Asset Detail Coverage
```sql
SELECT 
    TransactionCategory,
    COUNT(*) AS Total,
    COUNT(Cusip) AS WithCusip,
    COUNT(Isin) AS WithIsin,
    COUNT(LoanX) AS WithLoanX,
    COUNT(TransEx_Asset_AssetTypeID_CodeName) AS WithAssetType
FROM #ProcResult
GROUP BY TransactionCategory
```

**Expected:**
- Facility: High LoanX coverage
- Issue: High CUSIP/ISIN coverage
- Entity: Low asset detail coverage (not instrument-based)
- Cash: Inherited from parent transaction

---

### Compare with pTransactionExtract
```sql
-- Run both procedures for same parameters
-- History (current state)
EXEC Solvas_AM.pTransactionExtractHistory 'MOS', 131
-- Results into #History

-- Extract (event-based) for recent period
EXEC Solvas_AM.pTransactionExtract 
    @StartDate = '2026-07-01', 
    @EndDate = '2026-07-07', 
    @GroupName = 'MOS', 
    @Fund = 131
-- Results into #Extract

-- Compare counts
SELECT 'History' AS Source, COUNT(*) AS RowCount FROM #History
UNION ALL
SELECT 'Extract' AS Source, COUNT(*) AS RowCount FROM #Extract

-- Find differences
SELECT h.TransId, h.ActionCode, e.ActionCode
FROM #History h
FULL OUTER JOIN #Extract e ON h.TransId = e.TransId AND h.AccountTransId = e.AccountTransId
WHERE h.TransId IS NULL OR e.TransId IS NULL
```

---

## Missing Transactions Troubleshooting

### Issue 1: Expected Transaction Not Returned
**Possible Causes:**
1. Transaction not in entity list
2. TransID filter excludes it
3. Transaction filtered by Query 2 NOT EXISTS clause
4. Account not active

**Check:**
```sql
-- Verify entity membership
SELECT * FROM feeds.solvas_am.fEntityList(2, @GroupName, @Fund)
WHERE EntityID = (SELECT entity_id FROM account WHERE account_id = ...)

-- Check account status
SELECT * FROM Solvas_am.vAccountRaw WHERE account_id = ...

-- Check if transaction in account_transaction view
SELECT * FROM Solvas_am.vAccount_Transaction_expanded_viewRaw WHERE trans_id = ...

-- Check if virtual facility transaction
SELECT * FROM Solvas_am.vFacility_TransactionRaw WHERE facility_trans_id = ...
```

---

### Issue 2: Duplicate Transactions
**Possible Causes:**
1. Same TransID in multiple queries
2. Cash transaction + parent transaction

**Expected Behavior:**
- Parent transaction (Received = 0)
- Cash transaction (Received = 1)
- Both should have same TransId
- Different AccountTransId

**Verify:**
```sql
SELECT TransId, AccountTransId, Received, TransactionCategory, CashTransactionId
FROM #ProcResult
WHERE TransId = ...
ORDER BY Received
```

---

### Issue 3: Missing Cash Transactions
**Possible Causes:**
1. No entry in account_transaction.cash_trans_id
2. Cash not linked properly

**Check:**
```sql
-- Check cash linkage
SELECT at.*, ct.*
FROM solvas_am.dbo.account_transaction at
LEFT JOIN solvas_am.dbo.cash_transaction ct ON at.cash_trans_id = ct.cash_trans_id
WHERE at.trans_id = ...
```

---

### Issue 4: Virtual Facility Transactions Missing
**Possible Causes:**
1. Has account_transaction record (excluded by NOT EXISTS)
2. Zero commitment and no trade_id

**Check:**
```sql
-- Check if in account_transaction
SELECT * FROM Solvas_am.vAccount_Transaction_expanded_viewRaw 
WHERE trans_id = ... AND trans_category = 'L'

-- Check commitment and trade
SELECT 
    ftr.facility_trans_id,
    ftr.ftrade_id,
    fstp.commitment_amount,
    CASE 
        WHEN fstp.commitment_amount <> 0 OR ftr.ftrade_id IS NOT NULL THEN 'INCLUDE'
        ELSE 'EXCLUDE'
    END AS IncludeStatus
FROM Solvas_am.vFacility_TransactionRaw ftr
LEFT JOIN solvas_am.vFacilitySecurityTransactionPar fstp 
    ON fstp.fissue_trans_id = ftr.facility_trans_id 
    AND ftr.facility_id = fstp.fissue_id
WHERE ftr.facility_trans_id = ...
```

---

## Limitations

1. **No Historical State**
   - Shows current state only
   - Cannot recreate past states
   - Deleted transactions not captured

2. **No Date Filtering**
   - Cannot filter by date range
   - Returns all transactions for entity/fund
   - Must filter results after execution

3. **No Incremental Tracking**
   - No last-run tracking
   - Always full extraction
   - Not suitable for incremental ETL

4. **Performance at Scale**
   - Full group extraction may be slow
   - No pagination
   - No parallel processing

5. **Limited Action Codes**
   - Only ADD or DELETE
   - No UPDATE events
   - Cannot track modification history

---

## Recommendations

### For Production Use

1. **Add Execution Logging**
```sql
-- Log start
INSERT INTO ProcedureExecutionLog (ProcName, StartTime, Parameters)
VALUES ('pTransactionExtractHistory', GETDATE(), @GroupName + '|' + CAST(@Fund AS VARCHAR))

-- Log end
UPDATE ProcedureExecutionLog
SET EndTime = GETDATE(), RowCount = @@ROWCOUNT
WHERE LogId = @LogId
```

2. **Add Result Pagination**
```sql
-- Add parameters
@PageNumber INT = 1,
@PageSize INT = 1000

-- Apply pagination
ORDER BY TransId, AccountTransId
OFFSET (@PageNumber - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY
```

3. **Index Temp Tables**
```sql
CREATE INDEX IX_EntityIDs ON #EntityIDs(EntityID)
CREATE INDEX IX_TransIDs ON #TransIDs(TransID)
CREATE INDEX IX_ProceedsType ON #ProceedsType(trans_id, account_id, entity_id)
```

4. **Validate Input Parameters**
```sql
-- Check GroupName format
IF @GroupName IS NULL OR LTRIM(RTRIM(@GroupName)) = ''
    THROW 50002, '@GroupName cannot be empty', 1

-- Check Fund value
IF @Fund < 0
    THROW 50003, '@Fund must be positive or NULL', 1

-- Check TransID format
IF @TransID IS NOT NULL AND @TransID NOT LIKE '[0-9,]%'
    THROW 50004, '@TransID must contain only numbers and commas', 1
```

5. **Add Performance Monitoring**
```sql
-- Track query execution time
DECLARE @Query1Start DATETIME = GETDATE()
INSERT INTO #Result (...Query 1...)
DECLARE @Query1Duration INT = DATEDIFF(MILLISECOND, @Query1Start, GETDATE())

-- Similar for Query 2, Query 3, Asset extraction
```

---

## Use Cases by Scenario

### Use Case 1: Ad-Hoc Transaction Investigation
**When:** Support team needs to investigate specific transactions

**Execution:**
```sql
EXEC Solvas_AM.pTransactionExtractHistory 'MOS', NULL, '12345,12346,12347'
```

**Advantage:** 
- Fast (specific TransIDs)
- Current state
- All related data (cash, asset details)

---

### Use Case 2: Fund-Level Reconciliation
**When:** Need to reconcile all transactions for a fund

**Execution:**
```sql
EXEC Solvas_AM.pTransactionExtractHistory 'collateraladmin', 144
```

**Advantage:**
- Complete fund snapshot
- Includes virtual transactions
- Cash vs. expected proceeds comparison

---

### Use Case 3: Data Warehouse Backfill
**When:** Need to backfill historical data after issue

**Execution:**
```sql
-- Load all transactions
EXEC Solvas_AM.pTransactionExtractHistory 'MOS', 131
-- Merge into data warehouse
```

**Advantage:**
- Full current state
- Simpler than event reconstruction
- Includes all transaction types

**Limitation:**
- Cannot recreate intermediate states
- Only current values

---

### Use Case 4: Virtual Transaction Analysis
**When:** Need to understand transactions not in account_transaction

**Execution:**
```sql
EXEC Solvas_AM.pTransactionExtractHistory 'MOS', 131
-- Filter for AccountTransId LIKE '%L'
```

**Advantage:**
- Query 2 specifically targets these
- Shows PIK, exchange, pending trades
- Includes fallback account mapping

---

## Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-07-07 | 1.0 | Initial documentation | MOS Support Agent |

---

## Related Procedures

- **pTransactionExtract** - Event-based incremental extraction
- **pTransactionExtractSingle** - Single transaction extraction (likely exists)
- **vAccount_Transaction_expanded_viewRaw** - Core view for account transactions
- **vCash_Transaction_Log** - Cash transaction log (used in pTransactionExtract)

