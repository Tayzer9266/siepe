# Cash Reconciliation Investigation Skill

## Purpose
Systematic investigation of cash reconciliation issues including balance discrepancies, transaction matching problems, Single Fund Refresh (SFR) failures, and approval workflow errors. Diagnoses root causes in the cash rec process and provides actionable remediation steps.

## When to Use This Skill
- User reports "balance discrepancies" or "cash doesn't match"
- Issues with "Cash Rec tool" or "balance reconciliation"
- Problems with "SFR" (Single Fund Refresh) or "balance refresh"
- Transaction matching failures or incorrect matches
- Cash rec approval workflow errors
- Keywords: cash, balance, reconciliation, SFR, cash rec, balance mismatch, transaction matching

---

## Investigation Methodology

### Phase 1: Identify Issue Type and Scope

**Objective:** Determine which cash rec subsystem is affected and gather basic context.

**Questions to Answer:**
1. **What type of issue?**
   - Balance discrepancy (mismatch between custodian and MOS)
   - Transaction matching (auto-match failure or incorrect match)
   - SFR failure (Single Fund Refresh errors)
   - Approval workflow (cannot approve or business rule blocking)

2. **Which portfolio/account?**
   - Portfolio ID and name
   - Custodian account number
   - Company/client

3. **What date?**
   - Reconciliation date (T date)
   - When was issue first observed?
   - Is this a recurring issue or one-time event?

4. **How large is the discrepancy?**
   - Dollar amount of difference
   - Is it material or immaterial?
   - Growing or shrinking over time?

**Initial Data Collection:**
```sql
-- Get portfolio and custodian info
SELECT 
    p.PortfolioID,
    p.PortfolioName,
    p.CompanyID,
    c.CompanyName,
    p.CustodianAccountNumber,
    p.Active,
    p.Currency
FROM Core.dbo.vPortfolio p
JOIN Core.dbo.vCompany c ON p.CompanyID = c.CompanyID
WHERE p.PortfolioID = {PortfolioID} -- Replace with actual ID
```

---

### Phase 2: Balance Discrepancy Investigation

**Applicable When:** Balance mismatch between custodian and MOS

#### Step 2.1: Compare Current Balances

```sql
-- Get MOS balance
SELECT 
    BalanceDate,
    PortfolioID,
    CashBalance AS MOS_Balance,
    Currency,
    BalanceSource
FROM CashRec.vBalance
WHERE PortfolioID = {PortfolioID}
    AND BalanceDate = '{ReconciliationDate}' -- Format: YYYY-MM-DD
ORDER BY BalanceDate DESC

-- Get custodian balance (example: Citi)
-- Note: Adjust table name based on custodian
SELECT 
    BalanceDate,
    AccountNumber,
    Balance AS Custodian_Balance,
    Currency
FROM Custodian.vCitiBalances  -- Change to appropriate custodian view
WHERE AccountNumber = '{CustodianAccountNumber}'
    AND BalanceDate = '{ReconciliationDate}'
```

**Analysis:**
- Calculate difference: `Custodian_Balance - MOS_Balance`
- Note the dollar amount and percentage variance
- Check if currency matches (USD vs. base currency)

#### Step 2.2: Review Transaction Activity

**Objective:** Identify missing or duplicate transactions causing balance mismatch.

```sql
-- Get all transactions for the date range
SELECT 
    t.TransactionDate,
    t.TransactionID,
    t.TransactionType,
    t.Amount,
    t.Currency,
    t.ReferenceNumber,
    t.Description,
    t.MatchStatus,
    t.Source
FROM CashRec.vTransaction t
WHERE t.PortfolioID = {PortfolioID}
    AND t.TransactionDate BETWEEN DATEADD(day, -5, '{ReconciliationDate}') 
        AND '{ReconciliationDate}'
ORDER BY t.TransactionDate, t.TransactionID
```

**Common Patterns:**
- **Missing custodian transaction:** File delivery delayed or transaction excluded from extract
- **Missing MOS transaction:** Trade not booked or settlement date incorrect
- **Duplicate transactions:** Same transaction imported multiple times
- **Timing difference:** T vs. T+1 settlement, weekend/holiday processing

#### Step 2.3: Check File Delivery and Import Status

```sql
-- Check custodian file import history
SELECT 
    ImportDate,
    FileName,
    RecordCount,
    Status,
    ErrorMessage
FROM Reference.dbo.vRefDataImportCurrent
WHERE DataSource LIKE '%{CustodianName}%'  -- e.g., 'Citi', 'BNY', 'Northern Trust'
    AND ImportDate >= DATEADD(day, -7, '{ReconciliationDate}')
ORDER BY ImportDate DESC
```

**Investigation Questions:**
- Was the custodian file delivered on time?
- Did the import complete successfully?
- Any error messages in the import log?
- Is the record count consistent with previous days?

#### Step 2.4: Check Prior Day Balance Carryforward

**Objective:** Verify beginning balance carried forward correctly.

```sql
-- Compare prior day ending balance to current day beginning balance
WITH DailyBalances AS (
    SELECT 
        BalanceDate,
        PortfolioID,
        BeginningBalance,
        EndingBalance,
        LAG(EndingBalance) OVER (PARTITION BY PortfolioID ORDER BY BalanceDate) AS PriorDayEnding
    FROM CashRec.vBalance
    WHERE PortfolioID = {PortfolioID}
        AND BalanceDate >= DATEADD(day, -5, '{ReconciliationDate}')
)
SELECT 
    BalanceDate,
    BeginningBalance,
    PriorDayEnding,
    BeginningBalance - ISNULL(PriorDayEnding, 0) AS CarryforwardDifference
FROM DailyBalances
WHERE BalanceDate = '{ReconciliationDate}'
```

**Common Issues:**
- Prior day balance not carried forward
- Adjustment not applied correctly
- Balance reset due to SFR or manual correction

---

### Phase 3: Transaction Matching Investigation

**Applicable When:** Auto-match failures or incorrect match suggestions

#### Step 3.1: Review Unmatched Transactions

```sql
-- Find unmatched transactions from both sides
SELECT 
    t.Side,  -- 'Custodian' or 'Internal'
    t.TransactionDate,
    t.TransactionID,
    t.TransactionType,
    t.Amount,
    t.ReferenceNumber,
    t.Description,
    t.MatchStatus
FROM CashRec.vTransaction t
WHERE t.PortfolioID = {PortfolioID}
    AND t.MatchStatus = 'Unmatched'
    AND t.TransactionDate >= DATEADD(day, -30, GETDATE())
ORDER BY t.TransactionDate DESC, t.Amount
```

**Matching Analysis:**
- Look for similar amounts on opposite sides (potential matches)
- Check reference numbers for partial matches
- Review transaction dates (might be off by 1 day)
- Check descriptions for identifying information

#### Step 3.2: Check Match Tolerance Settings

```sql
-- Review match group configuration for transaction type
SELECT 
    mg.MatchGroupID,
    mg.MatchGroupName,
    mg.TransactionType,
    mg.ToleranceAmount,
    mg.TolerancePercent,
    mg.MatchLogic,
    mg.Active
FROM CashRec.vMatchGroups mg
WHERE mg.TransactionType IN (
    SELECT DISTINCT TransactionType 
    FROM CashRec.vTransaction 
    WHERE PortfolioID = {PortfolioID} 
        AND MatchStatus = 'Unmatched'
)
```

**Configuration Review:**
- Is tolerance too tight (< $0.01)?
- Is tolerance too loose (> $100)?
- Does match logic cover this transaction pattern?
- Are match rules active?

#### Step 3.3: Analyze Match Suggestions

```sql
-- Review system-generated match suggestions
SELECT 
    ms.SuggestedMatchID,
    ms.CustodianTransactionID,
    ms.InternalTransactionID,
    ms.MatchScore,
    ms.MatchReason,
    ct.Amount AS Custodian_Amount,
    it.Amount AS Internal_Amount,
    ABS(ct.Amount - it.Amount) AS AmountDifference
FROM CashRec.vMatchSuggestions ms
JOIN CashRec.vTransaction ct ON ms.CustodianTransactionID = ct.TransactionID
JOIN CashRec.vTransaction it ON ms.InternalTransactionID = it.TransactionID
WHERE ct.PortfolioID = {PortfolioID}
    AND ct.TransactionDate >= DATEADD(day, -30, GETDATE())
ORDER BY ms.MatchScore DESC
```

**Validation Questions:**
- Does the match score make sense?
- Are amounts within tolerance?
- Do reference numbers align?
- Is the transaction date reasonable?

---

### Phase 4: Single Fund Refresh (SFR) Investigation

**Applicable When:** SFR button failing or producing errors

#### Step 4.1: Check SFR Status and Error Messages

```sql
-- Review recent SFR executions
SELECT 
    sfr.RefreshID,
    sfr.PortfolioID,
    sfr.RefreshDate,
    sfr.Status,
    sfr.ErrorMessage,
    sfr.StartTime,
    sfr.EndTime,
    DATEDIFF(SECOND, sfr.StartTime, sfr.EndTime) AS DurationSeconds
FROM CashRec.vSingleFundRefreshStatus sfr
WHERE sfr.PortfolioID = {PortfolioID}
    AND sfr.RefreshDate >= DATEADD(day, -7, GETDATE())
ORDER BY sfr.RefreshDate DESC
```

**Error Pattern Analysis:**
- **Timeout errors:** Large data set, increase timeout
- **Lock errors:** Concurrent execution, check dependencies
- **Missing data errors:** Source not available, check upstream
- **Dependency errors:** Component order issue, review dependencies

#### Step 4.2: Review Component Dependencies

```sql
-- Check SFR component execution order
SELECT 
    c.ComponentID,
    c.ComponentName,
    c.ExecutionOrder,
    c.DependsOn,
    c.TimeoutSeconds,
    c.Enabled
FROM CashRec.vRefreshComponents c
WHERE c.RefreshType = 'SingleFund'
ORDER BY c.ExecutionOrder
```

**Dependency Validation:**
- Are all required components enabled?
- Is execution order correct?
- Are timeouts appropriate for data volume?
- Are dependency relationships configured correctly?

#### Step 4.3: Check for Lock Conflicts

```sql
-- Identify active locks on cash rec tables
SELECT 
    request_session_id,
    resource_type,
    resource_database_id,
    resource_description,
    request_mode,
    request_status
FROM sys.dm_tran_locks
WHERE resource_database_id = DB_ID('CashRec')
    AND request_status = 'GRANT'
```

**Concurrency Issues:**
- Another SFR running simultaneously
- Long-running query blocking refresh
- Manual intervention in progress

---

### Phase 5: Approval Workflow Investigation

**Applicable When:** Cannot approve cash rec or business rule blocking approval

#### Step 5.1: Check Approval Business Rules

```sql
-- Review approval validation rules
SELECT 
    av.ValidationRuleID,
    av.RuleName,
    av.RuleDescription,
    av.ErrorMessage,
    av.Severity,  -- 'Error' blocks approval, 'Warning' allows override
    av.Enabled
FROM CashRec.vApprovalValidations av
WHERE av.Enabled = 1
ORDER BY av.Severity, av.RuleName
```

**Common Blocking Rules:**
- Stale balance check (balance older than X days)
- Material discrepancy threshold ($X difference)
- Missing required data
- Unmatched transactions above limit
- Balance adjustment not documented

#### Step 5.2: Test Validation Rules Against Current State

```sql
-- Execute approval checks manually
DECLARE @PortfolioID INT = {PortfolioID}
DECLARE @ReconciliationDate DATE = '{ReconciliationDate}'

-- Check 1: Balance staleness
SELECT 
    'Balance Staleness' AS CheckName,
    DATEDIFF(DAY, MAX(BalanceDate), GETDATE()) AS DaysSinceLastBalance,
    CASE 
        WHEN DATEDIFF(DAY, MAX(BalanceDate), GETDATE()) > 3 THEN 'FAIL'
        ELSE 'PASS'
    END AS Result
FROM CashRec.vBalance
WHERE PortfolioID = @PortfolioID

-- Check 2: Material discrepancy
SELECT 
    'Material Discrepancy' AS CheckName,
    ABS(CustodianBalance - MOSBalance) AS DiscrepancyAmount,
    CASE 
        WHEN ABS(CustodianBalance - MOSBalance) > 1000 THEN 'FAIL'
        ELSE 'PASS'
    END AS Result
FROM (
    SELECT 
        SUM(CASE WHEN Source = 'Custodian' THEN Amount ELSE 0 END) AS CustodianBalance,
        SUM(CASE WHEN Source = 'Internal' THEN Amount ELSE 0 END) AS MOSBalance
    FROM CashRec.vTransaction
    WHERE PortfolioID = @PortfolioID
        AND TransactionDate = @ReconciliationDate
) balances

-- Check 3: Unmatched transaction count
SELECT 
    'Unmatched Transactions' AS CheckName,
    COUNT(*) AS UnmatchedCount,
    CASE 
        WHEN COUNT(*) > 10 THEN 'FAIL'
        ELSE 'PASS'
    END AS Result
FROM CashRec.vTransaction
WHERE PortfolioID = @PortfolioID
    AND MatchStatus = 'Unmatched'
    AND TransactionDate >= DATEADD(DAY, -30, @ReconciliationDate)
```

**Resolution Paths:**
- **Stale balance:** Run SFR to refresh
- **Material discrepancy:** Investigate balance difference (Phase 2)
- **Unmatched transactions:** Review and match manually
- **Missing data:** Contact custodian or verify import

#### Step 5.3: Check User Permissions

```sql
-- Verify user has approval rights
SELECT 
    u.UserID,
    u.UserName,
    r.RoleName,
    p.PermissionName,
    p.PermissionType
FROM Core.dbo.vUser u
JOIN Core.dbo.vUserRole ur ON u.UserID = ur.UserID
JOIN Core.dbo.vRole r ON ur.RoleID = r.RoleID
JOIN Core.dbo.vRolePermission rp ON r.RoleID = rp.RoleID
JOIN Core.dbo.vPermission p ON rp.PermissionID = p.PermissionID
WHERE u.UserName = '{UserName}'  -- User attempting approval
    AND p.PermissionType LIKE '%CashRec%Approve%'
```

---

### Phase 6: Root Cause Determination

Based on investigation findings, categorize the root cause:

| Root Cause Category | Common Indicators | Typical Resolution |
|---------------------|-------------------|-------------------|
| **File Delivery Delay** | Missing custodian file, import record count zero | Contact custodian, re-request file |
| **Transaction Timing** | T vs. T+1 differences, weekend/holiday gaps | Adjust reconciliation date, document timing |
| **Match Tolerance** | Many near-matches unmatched, penny differences | Adjust tolerance settings, review match logic |
| **Data Mapping** | Portfolio mismatch, account number wrong | Update portfolio mapping, verify custodian setup |
| **Currency Conversion** | Foreign currency positions, FX rate issues | Verify FX rates, check currency configuration |
| **Normalization Error** | SQL errors in logs, null values | Fix normalization view, handle edge cases |
| **Workflow Configuration** | Business rule blocking approval | Adjust validation rules, request approval override |
| **System Performance** | SFR timeouts, slow queries | Optimize queries, increase timeouts, schedule off-peak |
| **Duplicate Transactions** | Same transaction multiple times | Delete duplicates, fix import deduplication logic |
| **Missing Transactions** | Expected transaction not present | Investigate upstream (trade booking, settlement) |

---

### Phase 7: Generate Report and Recommendations

**Report Structure:**

```markdown
# Cash Reconciliation Investigation Report

## Executive Summary
- Portfolio: [Portfolio Name] (ID: [PortfolioID])
- Reconciliation Date: [YYYY-MM-DD]
- Issue Type: [Balance Discrepancy | Transaction Matching | SFR Failure | Approval Block]
- Discrepancy Amount: $[X,XXX.XX]
- Root Cause: [Category]

## Investigation Findings

### Balance Analysis
- Custodian Balance: $[X,XXX.XX]
- MOS Balance: $[X,XXX.XX]
- Difference: $[XXX.XX] ([X.XX]%)

### Transaction Summary
- Total Transactions (Custodian): [X]
- Total Transactions (MOS): [X]
- Matched: [X]
- Unmatched Custodian: [X]
- Unmatched MOS: [X]

### Root Cause Analysis
[Detailed explanation of root cause]

## Recommendations

### Immediate Actions
1. [Action 1]
2. [Action 2]
3. [Action 3]

### Remediation Steps
[SQL scripts, configuration changes, or manual steps needed]

### Preventive Measures
- [Long-term fix or process improvement]

## Attachments
- Transaction detail export
- Balance comparison spreadsheet
- Error log excerpts
```

**Example SQL for Transaction Export:**
```sql
-- Export unmatched transactions for manual review
SELECT 
    t.Side,
    t.TransactionDate,
    t.TransactionType,
    t.Amount,
    t.Currency,
    t.ReferenceNumber,
    t.Description,
    t.MatchStatus
FROM CashRec.vTransaction t
WHERE t.PortfolioID = {PortfolioID}
    AND t.MatchStatus = 'Unmatched'
    AND t.TransactionDate >= DATEADD(day, -30, GETDATE())
ORDER BY t.TransactionDate, t.Amount
```

---

## Common Resolution Patterns

### Pattern 1: Custodian File Delivery Delay
**Symptom:** Balance missing, no custodian transactions for date  
**Investigation:** Check import logs, verify file delivery  
**Resolution:** Contact custodian, re-import file when received  
**Prevention:** Set up file delivery alerts, monitor daily imports

### Pattern 2: Transaction Timing Difference
**Symptom:** Small balance difference, transactions off by 1 day  
**Investigation:** Compare transaction dates on both sides  
**Resolution:** Adjust match logic to handle T+1, document timing differences  
**Prevention:** Configure match tolerance for date ranges

### Pattern 3: Match Tolerance Too Tight
**Symptom:** Many transactions with penny differences unmatched  
**Investigation:** Review match tolerance settings  
**Resolution:** Increase tolerance to $0.10 or 0.1%  
**Prevention:** Regular review of match performance metrics

### Pattern 4: Duplicate Custodian Import
**Symptom:** Double-counted transactions, balance 2x expected  
**Investigation:** Check import history for duplicate files  
**Resolution:** Delete duplicate records, fix import deduplication  
**Prevention:** Add unique constraint on custodian transaction ID

### Pattern 5: SFR Timeout on Large Portfolio
**Symptom:** SFR fails after 5 minutes, timeout error  
**Investigation:** Review component execution times  
**Resolution:** Increase timeout to 15 minutes, optimize queries  
**Prevention:** Schedule SFR during off-peak hours

### Pattern 6: Stale Balance Blocking Approval
**Symptom:** Cannot approve, "stale balance" error  
**Investigation:** Check last balance refresh date  
**Resolution:** Run SFR to refresh balance, then approve  
**Prevention:** Schedule automatic daily SFR

---

## Technical Reference

### Key Database Objects

**Tables:**
- `CashRec.tBalance` - Cash balances by portfolio and date
- `CashRec.tTransaction` - Transaction details (custodian and internal)
- `CashRec.tMatchGroups` - Auto-match configuration
- `CashRec.tMatchSuggestions` - System-generated match suggestions
- `CashRec.tRefreshStatus` - SFR execution history

**Views:**
- `CashRec.vBalance` - Current and historical balances
- `CashRec.vTransaction` - Normalized transaction view
- `CashRec.vMatchGroups` - Active match configuration
- `CashRec.vSingleFundRefreshStatus` - SFR status and errors
- `CashRec.vApprovalValidations` - Approval business rules

**Stored Procedures:**
- `CashRec.pTransactionChanges` - Compare transactions across dates
- `CashRec.pRefreshBalance` - Manual balance refresh
- `CashRec.pApproveReconciliation` - Approve cash rec
- `CashRec.pMatchTransactions` - Manual transaction matching

### Common Custodian Views

| Custodian | Balance View | Transaction View |
|-----------|--------------|------------------|
| BNY Mellon | `Custodian.vBNYBalances` | `Custodian.vBNYTransactions` |
| Citi | `Custodian.vCitiBalances` | `Custodian.vCitiTransactions` |
| Northern Trust | `Custodian.vNTBalances` | `Custodian.vNTTransactions` |
| State Street | `Custodian.vStateStreetBalances` | `Custodian.vStateStreetTransactions` |

---

## Example Investigations

### Example 1: Balance Discrepancy - Missing Custodian File

**Ticket:** "MissionSquare PLUS Fund balance not feeding in"

**Investigation:**
1. Checked `Reference.dbo.vRefDataImportCurrent` - No Citi file for 2024-03-15
2. Verified FTP delivery logs - File not received from Citi
3. Confirmed prior day file (2024-03-14) imported successfully

**Root Cause:** Custodian file delivery delayed

**Resolution:**
- Contacted Citi custodian operations
- File re-sent and imported successfully
- Balance reconciled after import

### Example 2: Auto-Match Failure - Tolerance Too Tight

**Ticket:** "Transactions not auto-matching despite exact amounts"

**Investigation:**
1. Reviewed `CashRec.vTransaction` - 15 unmatched pairs with $0.00 difference
2. Checked `CashRec.vMatchGroups` - Tolerance set to exact match (0.00)
3. Found reference number differences (leading zeros)

**Root Cause:** Match logic required exact reference number match, tolerance didn't allow rounding

**Resolution:**
- Updated match tolerance to $0.01
- Modified match logic to trim/normalize reference numbers
- Re-ran auto-match process
- All 15 transactions matched

### Example 3: SFR Timeout - Large Data Set

**Ticket:** "Cash rec balance refresh fails for large portfolio"

**Investigation:**
1. Checked `CashRec.vSingleFundRefreshStatus` - Timeout after 5 minutes
2. Reviewed component execution - Slowest: transaction aggregation (4.5 minutes)
3. Analyzed query plan - Missing index on `TransactionDate`

**Root Cause:** Query performance issue, timeout too short for data volume

**Resolution:**
- Added index: `CREATE INDEX IX_Transaction_Date ON CashRec.tTransaction (PortfolioID, TransactionDate)`
- Increased SFR timeout from 5 to 10 minutes
- Execution time reduced to 2.5 minutes
- SFR completing successfully

---

## Skill Metadata

- **Skill Name:** cash-reconciliation
- **Category:** Cash Reconciliation
- **Complexity:** High
- **Execution Time:** 20-60 minutes (depends on issue complexity)
- **Prerequisites:** Access to CashRec schema, custodian views, import logs
- **Outputs:** Investigation report, transaction exports, remediation SQL scripts
- **Related Skills:** 
  - data-normalization (for transaction/balance normalization issues)
  - check-ssis-errors (for import failures)
  - import-file-investigation (for missing custodian files)
