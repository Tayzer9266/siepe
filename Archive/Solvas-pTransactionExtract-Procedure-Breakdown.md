# Solvas Transaction Extract Procedure - Step-by-Step Breakdown

**Stored Procedure:** `[Feeds].[solvas_am].[pTransactionExtract]`  
**Database:** Solvas (Feeds)  
**Purpose:** Extract transaction data from Solvas_AM for specified date range and fund/group  
**Date Documented:** 2026-07-07

---

## Overview

This procedure extracts transaction data by monitoring the event log (`ECI_Event_Log`) and reconstructing transaction states across multiple transaction types:
- **Facility Transactions** (Loans)
- **Issue Transactions** (Bonds/Securities)
- **Entity Transactions** (Deal-level)
- **Cash Transactions**
- **Account Transfers**

The procedure handles ADD, UPDATE, and DELETE events and manages the lifecycle of pending vs settled trades.

---

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `@StartDate` | DATETIME | Start of extraction window | Last processed date from RefDataSetActive |
| `@EndDate` | DATETIME | End of extraction window | GETDATE() |
| `@GroupName` | VARCHAR(100) | Entity group (e.g., 'Collateraladmin', 'MOS') | Required |
| `@Fund` | INT | Specific fund ID (NULL for all funds in group) | NULL |

---

## Execution Flow

### **Phase 1: Initialization & Setup**

#### Step 1.1: Calculate Effective Date Range
```sql
-- If @StartDate not provided, use last processed date from RefDataSetActive
-- Label format: 'TransactionExtract_{GroupName}'
-- Falls back to 1990-01-01 if no previous run exists
```

**Logic:**
- Looks up `Feeds.dbo.vRefDataSetActive` for last `EffFromDate`
- Uses label `TransactionExtract_{GroupName}` and type `Transactions`
- If NULL: defaults to `'1990-01-01'`

#### Step 1.2: Create Temporary Tables
Creates 7 temp tables:

1. **#AllTransaction** - Raw event log entries
2. **#Transaction** - Processed transaction events
3. **#Result** - Final transaction data
4. **#facility** - Facility/loan asset details
5. **#bond** - Bond/security asset details
6. **#equity** - Equity asset details
7. **#ProceedsType** - Proceeds type mapping (Principal/Interest)
8. **#TransType** - Transaction type account mapping

---

### **Phase 2: Event Log Extraction**

#### Step 2.1: Extract All Events from ECI_Event_Log
**Source:** `Solvas_AM.dbo.ECI_Event_Log`

**Filters Applied:**
- ✅ `event_date BETWEEN @StartDate_In AND @EndDate_In`
- ❌ `Created_By NOT IN ('PriceLoader', 'SIEPE\Octopus')` - Exclude automated processes
- ❌ Exclude account transfer cash: `(DEAL, ACCT, ATRCASH)`
- ❌ Exclude entity transaction cash (except DELETE or cash rec): `(DEAL, ENTTRANS, ATRCASH)`

**Columns Captured:**
- EventId, GlobalObjectId, GlobalObjectCode
- BizObjectId, BizObjectCode
- EntityId, EntityObjectId, EntityObjectCode
- EventDate, ActionCode, LogMasterId, TransactionDate

**Result:** Populates `#AllTransaction`

---

#### Step 2.2: Process DELETE Events
**Logic:** For DELETE events, find the most recent event BEFORE deletion

```sql
-- Find MAX(Event_Id) where:
--   - Same global/biz/entity object IDs
--   - action_code != 'DELETE' (the state before deletion)
--   - table_name IN ('Issue_Transaction', 'Facility_Transaction', 
--                    'Cash_Transaction', 'Entity_Transaction')
```

**Special Handling:**
- `Facility_Trans_Fee_Payment_Details` → Treated as `Facility_Transaction`
- ActionCode set to `'DELETE'`
- TransactionType is NULL (will be populated later)

**Result:** Inserts into `#Transaction`

---

#### Step 2.3: Process ADD/UPDATE Events
**Logic:** Directly copy ADD and UPDATE events

**Filters:**
- `ActionCode IN ('ADD', 'UPDATE')`
- `EntityId IN (fEntityList(@GroupName, @Fund))`

**Result:** Inserts into `#Transaction`

---

#### Step 2.4: Update Transaction Types
**Purpose:** Populate missing TransactionType for Issue and Facility transactions

**Issue Transactions:**
```sql
-- Join #Transaction with Issue_Transaction_log
-- Where IssueTransId appears in BOTH Cash_Transaction AND Issue_Transaction
-- (Indicates a cash-related issue transaction)
```

**Facility Transactions:**
```sql
-- Join #Transaction with Facility_Transaction_log
-- Where IssueTransId appears in BOTH Cash_Transaction AND Facility_Transaction
-- (Indicates a cash-related facility transaction)
```

**Result:** Updates `TransactionType` in `#Transaction`

---

### **Phase 3: Proceeds Type & Account Mapping**

#### Step 3.1: Extract Proceeds Type Mapping
**Source:** `Solvas_AM.dbo.Transaction_Account_Proceeds_view`

**Logic:**
- Groups transactions to identify P+I combinations
- If transaction has BOTH 'P' (Principal) and 'I' (Interest) proceeds on same account → 'PI'
- Otherwise uses original proceeds_type

**Result:** Populates `#ProceedsType`

---

#### Step 3.2: Extract Transaction Type to Account Mapping
**Source:** `Solvas_AM.dbo.Account_Trans_Type_Map`

**Purpose:** Maps transaction types to accounts and currencies

**Filters:**
- `active_account = 1`
- `entity_id IN (fEntityList(@GroupName, @Fund))`

**Result:** Populates `#TransType`

---

### **Phase 4: Extract Transaction Details**

#### Step 4.1: Extract Facility Transactions (Loans)
**Tables Joined:**
- `#Transaction` (driver)
- `Facility_Transaction_log` (historical state)
- `Facility_Transaction` (current state)
- `Facility_Trade_Transaction` (trade linkage)
- `vFacilitySecurityTransactionPar` (par value)
- `Facility_Trade` (trade details)
- `Entity`, `Facility`, `Issuer` (reference data)
- `Account_Transaction_expanded_view` (account details)
- `Account`, `Account_Trans_Type_Map` (account mapping)
- `Facility_Trade_Allocation_view` (trade allocation)
- `#ProceedsType`, `#TransType` (proceeds/type mapping)

**Key Calculations:**
- `OriginalTradeNetAmount = original_trade_amount × (funded_percentage + original_trade_price - 1) × trade_type_sign × initial_position_flag`
- `TotalProceedsAmount = PrincipalProceedsAmount + InterestProceedsAmount`
- `ActionCode = 'UPDATE'` if facility transaction is ADD with trade_id and settle_date (settled pending trade)

**Special Handling:**
- TransactionCategory = 'Facility'
- TransactionCategoryCode = 'L'
- ProceedsType determined by: #ProceedsType → #TransType → Calculated from amounts

**Result:** Inserts into `#Result` with ExtractSource = 'Iterative - Facility'

---

#### Step 4.2: Extract Issue Transactions (Bonds/Securities)
**Similar to Facility Transactions but for:**
- `Issue_Transaction_log` / `Issue_Transaction`
- `Issue` table instead of Facility
- Uses `issue_trans_id` as TradeId when not explicitly linked to trade

**Key Differences:**
- TransactionCategory = 'Issue'
- TransactionCategoryCode = 'I'
- No OriginalTradeNetAmount calculation
- TradeId defaults to issue_trans_id if no explicit trade_id

**Result:** Inserts into `#Result` with ExtractSource = 'Iterative - Issue'

---

#### Step 4.3: Extract Entity Transactions
**Purpose:** Deal-level transactions not tied to specific instruments

**Tables Joined:**
- `Entity_Transaction_log`
- `Account_Transaction_expanded_view`
- `Account_Cash_Transaction_expanded_view` (for cash totals)
- Entity, Issuer, Account tables

**Key Fields:**
- TransactionCategory = 'Entity'
- TransactionCategoryCode = 'E'
- InstName = Transaction description or trans type description
- No IssueId or FacilityId
- CashAmount = Total proceeds from cash view
- SettleDate = TransactionDate
- TradeDate = TransactionDate

**Result:** Inserts into `#Result` with ExtractSource = 'Iterative - Entity'

---

#### Step 4.4: Extract Cash Transactions
**Purpose:** Link cash receipts to transactions

**Tables Joined:**
- `Cash_Transaction_log` (driver)
- `Account_Cash_Transaction_expanded_view`
- `Account_Transaction_expanded_view`
- Issue/Facility transaction logs (to get original transaction)
- Issue/Facility tables (current state)
- Trade tables (facility/issue trades)

**Key Logic:**
- Joins cash to both facility AND issue transactions
- Determines if cash relates to entity transaction via GlobalObjectId = EntityId
- Uses transfer type view for account transfer descriptions

**Special Fields:**
- `Received = 1` (indicates cash actually received)
- `ProceedsType` determined by: #ProceedsType → trans_type_cat → Calculated
- Links to parent transaction via CTL.issue_trans_id or CTL.facility_trans_id

**Result:** Inserts into `#Result` with ExtractSource = 'Iterative - Cash'

---

#### Step 4.5: Extract Account Transfers
**Source:** `Account_Transaction_expanded_view` + `Account_Transfer_view`

**Filters:**
- `trans_category = 'T'`
- `create_date BETWEEN @StartDate_In AND @EndDate_In`
- `active_account = 1`

**Key Fields:**
- TransactionCategory = 'Transfer'
- TransactionCategoryCode = 'T'
- ActionCode = 'ADD' (always, as extracted by date)
- Received = 0
- No IssueId, FacilityId, IssuerId, or Country

**Result:** Inserts into `#Result` with ExtractSource = 'Iterative - Transfer'

---

#### Step 4.6: Extract Entity Cash & Account Transfer Cash
**Source:** `vCash_Transaction_Log` (excludes items already in #AllTransaction)

**Purpose:** Capture cash transactions created directly in cash tables, not via event log

**Filters:**
- `event_date BETWEEN @StartDate_In AND @EndDate_In`
- `EntityObjectId NOT IN #AllTransaction` (avoid duplicates)

**Key Fields:**
- Received = 1
- ActionCode from log (ADD/UPDATE/DELETE)
- Uses transfer type view for descriptions

**Result:** Inserts into `#Result` with ExtractSource = 'Iterative - Cash ET'

---

### **Phase 5: Handle Pending vs Settled Trades**

#### Step 5.1: Settle Facility Trades (Delete Pending)
**Purpose:** When a pending trade settles, mark the pending version as DELETED

**Logic:**
```sql
-- Find transactions in #Result where:
--   1. SettleDate IS NOT NULL (now settled)
--   2. TransactionCategory = 'Facility'
--   3. TradeId IS NOT NULL
--   4. ActionCode != 'DELETE'
-- Then find matching pending trades where:
--   - Same ftrade_id and facility_id
--   - settle_date IS NULL (still pending)
```

**Two Inserts:**
1. **With AccountTransId** (active account transaction record exists)
2. **Without AccountTransId** (NULL - for pending trades already in data warehouse)

**Result:** Inserts DELETE records with ExtractSource = 'Iterative - Delete Pending'

---

#### Step 5.2: Unsettle Facility Trades (Reactivate Pending)
**Purpose:** If a settled trade becomes unsettled, recreate the pending version

**Logic:**
```sql
-- Find transactions in #Result where:
--   1. ActionCode = 'DELETE' (was marked for deletion)
--   2. TransactionCategory = 'Facility'
--   3. TradeId IS NOT NULL
-- Then find matching facility transactions where:
--   - Same ftrade_id and facility_id
--   - settle_date IS NULL (now pending again)
```

**Result:** Inserts UPDATE records with ExtractSource = 'Iterative - Reactivate Pending'

---

#### Step 5.3: Settle Issue Trades (Deactivate Pending)
**Similar to Step 5.1 but for Issue transactions**

**Logic:**
```sql
-- Find settled issue transactions in #Result
-- Match with unsettled issue transactions in Issue_Transaction_Log
-- Insert DELETE records (AccountTransId = NULL)
```

**Result:** Inserts DELETE records with ExtractSource = 'Iterative - Deactivate Pending'

---

### **Phase 6: Extract Asset Details**

#### Step 6.1: Extract Facility Asset Details
**Source:** `Solvas_AM.dbo.Facility`

**Joins:**
- `Issuer` (issuer name/country)
- `cdosys_Lookup_Code_view` (security level description)
- `tf_Global_Loan_view` (floating rate index type)
- `Facility_Spread_History_view` (interest rate spread)

**Columns Extracted:**
- Asset identifiers: ISIN, LIN, LX_Identifier, Bloomberg, Facility Number, CUSIP
- Asset type: Always 'Loan'
- Seniority: From security_level lookup
- Lien Type: FRST → 'First', SCND → 'Second'
- Floating Spread Type: From coupon index type
- Floating Spread: From spread history as of @EndDate
- Maturity Date

**Filters:**
- Only facilities that exist in #Result

**Result:** Populates `#facility`

---

#### Step 6.2: Extract Bond Asset Details
**Source:** `Solvas_AM.dbo.Issue`

**Columns Extracted:**
- Asset identifiers: CUSIP, ISIN
- Asset Type: 'Bond', 'FBS', or 'Equity' (based on issue_type)
- Sub Type: From security_type lookup
- Is Fixed: 'Yes' if coupon_type = 'F'
- Fixed Rate: Only if fixed coupon
- Floating Spread: Only for RFR variable rate bonds
- Maturity Date

**Filters:**
- Only issues that exist in #Result
- Excludes issue_type 'L' (Loan) and 'E' (Equity)

**Result:** Populates `#bond`

---

#### Step 6.3: Extract Equity Asset Details
**Source:** `Solvas_AM.dbo.Equity`

**Columns Extracted:**
- Asset identifiers: CUSIP, ISIN
- Asset name: equity_name

**Filters:**
- Only equities that exist in #Result

**Result:** Populates `#equity`

---

### **Phase 7: Final Result Assembly**

#### Step 7.1: Join Asset Details
**Joins #Result with:**
- `#facility` (LEFT JOIN on FacilityId)
- `#bond` (LEFT JOIN on IssueId)
- `#equity` (LEFT JOIN on IssueId)

**Coalesced Fields:**
- CUSIP, ISIN, LoanX from facility/bond/equity
- Asset details prefixed with `TransEx_Asset_`

---

#### Step 7.2: Calculate Derived Columns

**LedgerType:**
```sql
CASE
  WHEN PrincipalProceedsAmount != 0 AND InterestProceedsAmount = 0 THEN 'Principal'
  WHEN InterestProceedsAmount != 0 AND PrincipalProceedsAmount = 0 THEN 'Interest'
  WHEN BOTH != 0 THEN 'Principal & Interest'
  ELSE 'Unknown'
END
```

**SortOrder:**
```sql
ROW_NUMBER() OVER (
  PARTITION BY TransId, CashTransactionId, EntityId, AccountId, CONVERT(DATE, EventDate)
  ORDER BY ActionCodeId, EventDate
)
```

**ProceedsTypeDescription:**
- 'P' → 'Principal'
- 'I' → 'Interest'
- 'PI' → 'Principal & Interest'
- 'M' → 'Miscellaneous'
- 'U' → 'Unknown'

---

#### Step 7.3: Apply Final Filters
**Exclude:**
- Transactions with `ActionCode IN ('ADD','UPDATE') AND AccountTransId IS NULL`
  - These are incomplete transactions without account mapping

---

#### Step 7.4: Return Results
**Sorted By:**
1. TransId
2. SortOrder

**Total Columns Returned:** 63 columns including:
- Transaction identifiers
- Entity/Deal information
- Account details
- Transaction amounts (Cash, Principal, Interest)
- Trade details
- Asset details (15 asset-specific columns)
- Dates (Transaction, Event, Trade, Settle)
- Status codes and descriptions

---

## Key Design Patterns

### 1. **Event Sourcing**
- Uses event log (ECI_Event_Log) as source of truth
- Reconstructs transaction state from ADD/UPDATE/DELETE events
- Handles historical state via _log tables

### 2. **Incremental Extraction**
- Uses RefDataSetActive to track last extraction
- Only processes events in date range
- Supports both full and incremental loads

### 3. **Pending vs Settled Trade Management**
- Maintains separate records for pending trades
- Deletes pending when settled
- Reactivates pending if unsettled

### 4. **Multi-Source Transaction Types**
- Facility (Loans)
- Issue (Bonds/Securities)
- Entity (Deal-level)
- Cash (Receipts/Payments)
- Transfer (Account movements)

### 5. **Complex Join Strategy**
- LEFT JOINs preserve all transactions
- COALESCE handles data from multiple sources
- Conditional logic based on transaction type

---

## Common Transaction Scenarios

### Scenario 1: New Facility Trade
1. Event log captures ADD for Facility_Transaction
2. Step 4.1 extracts facility details
3. If no settle_date → Pending trade
4. Step 6.1 adds facility asset details
5. Result: One record, ActionCode = ADD, SettleDate = NULL

### Scenario 2: Facility Trade Settles
1. Event log captures UPDATE with settle_date
2. Step 4.1 extracts settled transaction
3. Step 4.4 may extract related cash transaction
4. Step 5.1 issues DELETE for previous pending version
5. Result: Two records (UPDATE for settled, DELETE for pending)

### Scenario 3: Cash Receipt
1. Event log captures ADD for Cash_Transaction
2. Step 4.4 extracts cash details
3. Links to parent Issue/Facility transaction
4. Step 3.1 determines proceeds type (P/I/PI)
5. Result: One record, Received = 1

### Scenario 4: Account Transfer
1. Account_Transfer_view captures transfer
2. Step 4.5 extracts by create_date
3. Uses transfer type view for description
4. Result: One record, TransactionCategory = 'Transfer'

### Scenario 5: Transaction Deleted
1. Event log captures DELETE
2. Step 2.2 finds last state before deletion
3. Extracts with ActionCode = 'DELETE'
4. Result: One record with DELETE action

---

## Performance Considerations

1. **Temp Tables**
   - Uses NOLOCK hints extensively
   - Indexes not explicitly created (SQL Server auto-temps)

2. **Date Range Filtering**
   - Applied early in #AllTransaction population
   - Reduces data volume for subsequent joins

3. **Entity List Function**
   - `fEntityList(2, @GroupName, @Fund)` called multiple times
   - Could be materialized into temp table for large datasets

4. **Complex Joins**
   - Multiple LEFT JOINs in Steps 4.1-4.4
   - May benefit from intermediate temp tables for large volumes

5. **DISTINCT Usage**
   - DISTINCT used in final SELECT
   - May indicate duplicate row issues that could be addressed earlier

---

## Error Handling

**None explicitly implemented**

Recommendations:
- Add TRY/CATCH blocks
- Log errors to audit table
- Return error codes
- Validate @GroupName and @Fund exist

---

## Testing Scenarios

### Test 1: Small Date Range
```sql
EXEC solvas_am.pTransactionExtract 
    @StartDate = '2026-07-01', 
    @EndDate = '2026-07-02', 
    @GroupName = 'Collateraladmin', 
    @Fund = NULL
```

### Test 2: Specific Fund
```sql
EXEC solvas_am.pTransactionExtract 
    @StartDate = '2026-01-16 09:00:37.063', 
    @EndDate = '2026-01-16 09:40:37.063', 
    @GroupName = 'MOS', 
    @Fund = 312
```

### Test 3: Full Incremental Load
```sql
-- Uses last EffFromDate from RefDataSetActive
EXEC solvas_am.pTransactionExtract 
    @StartDate = NULL, 
    @EndDate = NULL, 
    @GroupName = 'MOS', 
    @Fund = NULL
```

---

## Dependencies

### Tables Referenced
- `Solvas_AM.dbo.ECI_Event_Log` ⭐ Core
- `Solvas_AM.dbo.cdosys_Log_Master`
- `Solvas_AM.dbo.Facility_Transaction_log`
- `Solvas_AM.dbo.Facility_Transaction`
- `Solvas_AM.dbo.Issue_Transaction_log`
- `Solvas_AM.dbo.Issue_Transaction`
- `Solvas_AM.dbo.Entity_Transaction_log`
- `Solvas_AM.dbo.Cash_Transaction_log`
- `Solvas_AM.dbo.Account_Transaction_expanded_view` ⭐ Core
- `Solvas_AM.dbo.Account_Cash_Transaction_expanded_view`
- `Feeds.solvas_am.vCash_Transaction_Log` ⭐ Core
- `Solvas_AM.dbo.Transaction_Account_Proceeds_view`
- `Solvas_AM.dbo.Account_Trans_Type_Map`
- `Solvas_AM.dbo.Facility`, `Issue`, `Equity` (Master data)
- `Solvas_AM.dbo.Entity`, `Issuer`, `Account` (Reference data)
- `Feeds.dbo.vRefDataSetActive` (Tracking)

### Functions Used
- `feeds.solvas_am.fEntityList(2, @GroupName, @Fund)` ⭐ Critical
- `Solvas_AM.dbo.CodeDesc()` (Lookup descriptions)
- `Solvas_AM.dbo.TransTypeDesc()` (Transaction type descriptions)
- `Solvas_AM.dbo.IssueGlobalOutstandingAmountAsofDate()`
- `Solvas_AM.dbo.IssueInterestRateAsofDate()`
- `Solvas_AM.dbo.IssueInterestRateSpreadAsofDate()`
- `Solvas_AM.dbo.IssueIndexTypeAsofDate()`
- `Solvas_AM.dbo.ConfigValue()`

### Views Used
- `Solvas_AM.dbo.Facility_Trade_Transaction`
- `Solvas_AM.dbo.Facility_Trade_Allocation_view`
- `Solvas_AM.dbo.Account_Transfer_view`
- `solvas_am.vFacilitySecurityTransactionPar`
- `solvas_am.vTransferTypeView`
- `Solvas_AM.dbo.Cash_Transaction_view`
- `Solvas_AM.dbo.tf_Global_Loan_view()`

---

## Monitoring & Troubleshooting

### Check Last Run
```sql
SELECT * 
FROM Feeds.dbo.vRefDataSetActive 
WHERE Label LIKE 'TransactionExtract_%'
  AND RefDataSetType = 'Transactions'
ORDER BY EffFromDate DESC
```

### Verify Entity List
```sql
SELECT * FROM feeds.solvas_am.fEntityList(2, 'Collateraladmin', NULL)
SELECT * FROM feeds.solvas_am.fEntityList(2, 'MOS', 312)
```

### Check Event Volume
```sql
SELECT 
    CONVERT(DATE, event_date) AS EventDate,
    global_object_code,
    entity_object_code,
    action_code,
    COUNT(*) AS EventCount
FROM Solvas_AM.dbo.ECI_Event_Log
WHERE event_date >= '2026-07-01'
  AND event_date < '2026-07-02'
  AND Created_By NOT IN ('PriceLoader', 'SIEPE\Octopus')
GROUP BY 
    CONVERT(DATE, event_date),
    global_object_code,
    entity_object_code,
    action_code
ORDER BY EventDate, global_object_code, action_code
```

### Missing Transactions
Common causes:
1. **Entity not in fEntityList** - Check @GroupName and @Fund parameters
2. **Created by excluded user** - Check Created_By field
3. **Date range issue** - Verify event_date vs trans_date
4. **Excluded by filters** - Check specific exclusion rules in Step 2.1

---

## Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-07-07 | 1.0 | Initial documentation | MOS Support Agent |

