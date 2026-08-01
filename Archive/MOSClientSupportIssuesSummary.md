# MOS - Client Support Issues Summary

**Source:** [Siepe Wiki - MOS Overview](https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/1006/MOS)  
**Date Extracted:** 2026-06-30  
**Total Support Topics:** 33 documented pages

---

## Overview

The MOS (Management Operating System) client support documentation covers operational issues across multiple areas including trade booking, pricing, cash reconciliation, position reconciliation, and data integrations with Solvas and third-party systems.

---

## Key Problem Areas

### 1. Daily Trade Booking Issues

**Common Problems:**

#### 1.1 Process Flow Trade Bookings with No Results
- **Issue:** Trade bookings that failed due to Solvas timeout
- **Resolution:** Trades need to be re-run in process flow
- **Monitoring:** Email alerts sent when this occurs

#### 1.2 Critical Data Integrity - Unmapped Portfolios
- **Issue:** Portfolios that are unmapped and don't have an entityID
- **Root Cause:** Portfolio missing in CAMOS system
- **Resolution Steps:**
  1. Map portfolio in CAMOS
  2. Find proper entityID
  3. Run SQL allocation procedure to allocate the trade in Solvas

**SQL Fix:**
```sql
-- Identify unallocated trades
select ft.trade_code,
CONCAT('EXEC Solvas_am.dbo.Facility_Entity_Trade_allocation_put
    @user_id = ''SIEPE\CLOUEY''
    ,@operation_confirmed = 1
    ,@silent_mode = 1
    ,@lot_allocation_method = ''PROR''
    ,@ftrade_id = ''', ft.ftrade_id,'''
    ,@commitment_amount = ''',ft.original_trade_amount,'''
    ,@funded_amount = ''',ft.original_funded_amount,'''
    ,@trade_allocation_type = ''',TRIM(ft.trade_type),'''
    ,@target_settle_date = ''',TRY_CONVERT(DATE,ft.expected_settle_date),'''
    ,@entity_id = ') as SQL
from Solvas_AM.dbo.Facility_Trade ft
LEFT JOIN Solvas_AM.dbo.Facility_Trade_Allocation FTA ON FTA.ftrade_id = ft.ftrade_id
where FTA.entity_id is null
AND (ft.trade_status NOT IN ('CANC') OR ft.trade_status is null)
AND ft.created_by = 'IPOS_GENERATE'
```

#### 1.3 TRD_Facility_Not_Found
- **Issue:** Facility not found during trade booking
- **Possible Causes:**
  - InstType mapping issue
  - Facility doesn't exist in system
- **Resolution:**
  1. Get fundid from `core.ProcessFlow.vClientDetails`
  2. Run trade loader: `exec core.ProcessFlow.pSolvasTradeLoader @FundID = {id}, @Date = '{date}'`
  3. Map InstType in `Reference.dbo.vInstTypeInstTypeMapCurrent`
  4. Contact Asset Admin to create facility if needed

---

### 2. Pricing Issues

**Problem:** Price Exception - Not Matching MarkIT ICE or ICE OR NULL Marks

#### 2.1 Verification Process

**Step 1: Check MOS Core Position Marks**
```sql
-- Check core position mark on active position
select distinct PositionMark, p.refdatasetdate, p.EffFromDate, 
    p.Tradedqty, p.Portfolio, ii.value 
from core.dbo.vposition p 
join core.dbo.vinstidentifiercurrent ii on ii.instid = p.instid
where p.refdatasetdate = '{date}'
and p.Portfolio like '%sy%'
and ii.value = '{identifier}'
order by 2 desc
```

**Step 2: Check Vendor Data**
- Verify pricing data from:
  - **Markit** (for loans)
  - **ICE** (for bonds)
  - **Sycamore** (for Sycamore bonds - sourced from ICE but pulled separately)

```sql
-- Check vendor pricing data
select top 100* 
from Reference.dbo.vinstpricecurrentraw p 
join Reference.dbo.vRefDataSource r on r.RefDataSourceID = p.RefDataSourceID
join Reference.dbo.vInstIdentifierCurrent ii on ii.InstID = p.InstID
where ii.value = '{identifier}'
and p.PriceDate >= '{date}'
order by p.PriceDate desc
```

**Common Scenarios:**
- Dataset date in range for refresh → No action needed, inform email chain
- Position mark doesn't match → Investigate vendor data
- Missing vendor data → Check data source refresh status

---

### 3. Cash Reconciliation Issues

#### 3.1 Setup Requirements

**New Fund Setup:**
```sql
select case when t.FundID is null then 'Does not Exist in CashRec' 
    else CONCAT('Exists in Cashrec since',t.CreatedDate) END 'Exists in cash rec?',
CONCAT('exec CashRec.pCashRecFundI @fundid =', f.FundID) as 'Script to include fund in cashrec',
f.FundID, f.FundName, t.* 
from core.dbo.vfund f 
left join [CashRec].vcashrecfundraw t on t.FundID = f.FundID
where FundName like '%{fundname}%'
```

**New Data Source Setup:**
```sql
exec core.CashRec.pDataSourceI
@RefDataSourceID = '{id}',
@DisplayName = '{name}',
@DataSourceTypeID = 2,
@IsCore = 0,
@IsMMF = 0
```

#### 3.2 Automated Maintenance Jobs

| RS Job ID | Name | Schedule | Purpose |
|-----------|------|----------|---------|
| 500001530 | Settled no Cash Applied Insert into Unmatched | 4:30am, 9:30am daily | Handles backdated transactions (-90 to -2 days) |
| 500001671 | New Trustee Ledgers to Be Mapped | Hourly 8am-11am | Maps trustee ledger to Solvas ledger |
| 500001984 | Unmapped Ledger Portfolio - Trustee Transactions | Per Citi transaction pull | Maps ledger to portfolio for normalization |
| 500002183 | Trustee Transaction - Unmapped Unknown Portfolio | Per Citi transaction pull | Creates portfolio using Solvas mapping |
| 500001683 | Remove Transactions in Matched Group from Unmatched | 9:30am, 11:30am | Cleanup matched transactions |
| 500001727 | Remove Cash Applied in Solvas from Unmatched | 9:30am, 11:30am | Remove cash applied transactions |
| 500001734 | Remove Inactive Transactions From Unmatched | 3pm daily | Cleanup inactive transactions |

#### 3.3 Common Mapping Issues

**Trustee Ledger Mapping:**
```sql
-- Check unmapped ledgers (debug mode)
EXEC Report.pTrusteeLedgersMapping 
    @Debug = 1, 
    @RefDataSourceIDs = '1000000002,1000000059,1000000107,...'
```

**Ledger Portfolio Mapping:**
```sql
-- Check unmapped portfolio ledgers
EXEC Core.Report.pCreatedReferenceLedgerPortfolioMaps 
    @MMF = 0, 
    @Debug = 1, 
    @RefDataSourceIDs = '1000000059,1000000107,...'
```

**Unknown Portfolio Creation:**
```sql
-- Create portfolios for unmapped trustee data
EXEC Report.pCreateRefTransactionPortfolios 
    @MMF = 0, 
    @Debug = 1, 
    @UnknownPortfolioName = 'Unknown', 
    @RefDataSourceIDs = '1000000059,1000000107,...'
```

---

### 4. Position Reconciliation

**Topics Covered:**
- Position recon process documentation
- Integration with Solvas data
- Reconciliation with custodian positions
- Exception handling and resolution

---

### 5. Data Integration Issues

**Key Integration Points:**
- **Solvas** → MOS data synchronization
- **Security Master** → Asset and pricing data
- **Custodians** (Citi, Northern Trust, US Bank) → Position and cash data
- **Aristotle** → EOD pricing, positions, and trades
- **Sycamore** → Bond pricing and positions
- **Diameter** → US Bank integration

---

## Additional Support Documentation

The wiki includes 33 total support pages covering:

1. Adding Reports to Portal
2. Aristotle EOD Pricing, Positions, and Trades
3. Assets management
4. Cash Rec Portal
5. Cashflow and Cash Rec Set Up
6. ClearPar Invoice processing
7. Collateral Attribute Rec
8. Compliance Test Summary Exports
9. File Upload procedures
10. Issue TradeCode Update
11. Kicking Off Position Refresh from Emails
12. MOS - Trade Reconciliation Report
13. pCashFlowReport: Creating new Ledger Mappings for new Portfolios
14. MOS Ops Price Overrides
15. New Fund Set Up Process (Datawarehouse)
16. New Fund Set Up Process (Solvas)
17. New User Dashboard Setup
18. Onboarding Portal Permissioning - Cash Rec
19. Process Flow - Trade Workflow
20. Process Flow Linkage Between MOS and Sec M
21. Quick Guide to Solvas|MOS and MOS|Client Refreshes
22. Sending Adhoc Position and Cashflow Extracts
23. Snapshots - Sycamore
24. Solvas Extract Timings
25. Solvas Extracts
26. Trade Capture MOS
27. USBank Diameter
28. USBank Sycamore

---

## Problem Categories Summary

| Category | Issue Count | Severity |
|----------|-------------|----------|
| Trade Booking | 3+ recurring | High |
| Pricing | 2+ recurring | High |
| Cash Reconciliation | 7+ mapping issues | Medium |
| Position Reconciliation | Multiple | Medium |
| Data Integration | Multiple | Medium-High |
| Setup/Configuration | Multiple | Low-Medium |

---

## Root Cause Patterns

1. **Mapping Issues** (Most Common)
   - Unmapped portfolios in CAMOS
   - Unmapped InstTypes
   - Unmapped trustee ledgers
   - Unmapped data sources

2. **Data Synchronization**
   - Solvas timeout failures
   - Vendor data refresh delays
   - Custodian data timing issues

3. **System Integration**
   - Missing facility definitions
   - Missing entityIDs
   - Unknown portfolios in trustee data

4. **Manual Intervention Required**
   - Price overrides
   - Backdated transaction handling
   - Ad-hoc extract requests

---

## Recommended Actions

1. **Proactive Monitoring**
   - Monitor daily email alerts for trade booking failures
   - Review automated job execution logs
   - Track unmapped entity reports

2. **Process Improvements**
   - Automate more mapping processes
   - Improve error notifications
   - Create self-service tools for common fixes

3. **Documentation**
   - Keep SQL scripts updated
   - Document new integration patterns
   - Maintain mapping reference tables

4. **Training**
   - Train support team on common resolution patterns
   - Document escalation procedures
   - Create runbooks for frequent issues

---

## Contact Points

- **Asset Admin:** For facility creation requests
- **MOS Operations:** Price overrides and manual adjustments
- **Data Team:** Vendor data and integration issues
- **Development Team:** System bugs and enhancement requests
