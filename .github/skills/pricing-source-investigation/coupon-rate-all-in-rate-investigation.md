---
skill_name: coupon-rate-all-in-rate-investigation
title: Current Coupon vs All-In Rate Investigation
description: Investigate and explain discrepancies between Current Coupon and All-In Rate for floating rate loans. This is typically expected behavior, not a data issue.
version: 1.0
applies_to: floating_rate_loans, clo_positions, loan_instruments
last_updated: 2026-07-24
related_tasks:
  - TASK 85092: Current Coupon vs All-In Rate investigation
  - Bug 84955: Current Coupon isn't the same as the all in rate
apply_to:
  - pattern: "**/*"
    when_user_mentions:
      - "coupon rate not matching"
      - "all in rate different"
      - "current coupon discrepancy"
      - "rate variance"
      - "driven by same index"
---

# Current Coupon vs All-In Rate Investigation

## Purpose

Investigate and explain why **Current Coupon** differs from **All-In Rate** for floating rate loans. This is **expected behavior** in most cases and reflects different calculation purposes in the system.

---

## When to Use This Skill

### ✅ Use this skill when:
- Team reports "Current Coupon isn't the same as All-In Rate"
- Collateral Detail Reconciliation shows rate discrepancies
- Questions about floating rate loan calculations
- Investigating rate variance of ±2 to ±10 basis points
- Need to explain SOFR-based loan rate mechanics

### ❌ Do NOT use this skill when:
- Fixed-rate instruments (CouponRate should match)
- Large discrepancies (>50 bps) - likely data issue
- Pricing errors from vendor feeds
- Missing prices or NULL rates

---

## Understanding the Two Rates

### All-In Rate (Contract Level)

**Purpose:** Forward-looking contract rate for next payment period

**Calculation:**
```
All-In Rate = Base Rate (SOFR) + Fixed Spread
Example: 3.689% + 1.75% = 5.439%
```

**Characteristics:**
- ✅ Standardized across all positions holding the same instrument
- ✅ Calculated at contract level (tInstContractCashFlow)
- ✅ Same for all funds holding the security
- ✅ Used for future payment projections

**Source Tables:**
- `core.dbo.vInstContractCashFlowActive`
- `core.dbo.tInstContractCashFlow`

---

### Current Coupon (Position Level)

**Purpose:** Position-specific accrual rate reflecting actual accrued interest

**Calculation:**
```
Current Coupon = Position-specific accrual based on:
- Purchase date
- Settlement timing
- Accrual method (Actual/360, Actual/365, etc.)
- Fund-specific accrual period
```

**Characteristics:**
- ✅ Varies by fund/position
- ✅ Reflects actual accrued interest for each position
- ✅ Position-level calculation (vCollateralDetail)
- ✅ May differ ±2 to ±10 bps from All-In Rate (normal)

**Source Tables:**
- `Lumen.dbo.vCollateralDetail`
- `Lumen.dbo.vPosition`

---

## Expected Variance

| Variance | Status | Action |
|----------|--------|--------|
| 0-5 bps | ✅ Normal | No action required |
| 5-10 bps | ⚠️ Normal (higher) | Review if persistent |
| 10-50 bps | ⚠️ Investigate | Check accrual settings |
| 50+ bps | ❌ Data Issue | Investigate immediately |

---

## Investigation Workflow

### Step 1: Identify the Security

Get the LoanXID or security identifier from the inquiry:
- LoanXID (e.g., LX235201)
- CUSIP/ISIN
- Security description

### Step 2: Run Contract-Level Query

```sql
SELECT 
    t.*,
    ii.loanxid,
    ii.SecurityDesc
FROM core.dbo.vInstContractCashFlowActive t
JOIN core.dbo.vinstbyidentifier ii ON ii.instid = t.instid 
WHERE ii.loanxid = 'LX235201'  -- Replace with actual LoanXID
ORDER BY t.allinrate DESC
```

**What to look for:**
- AllInRate value
- SOFR base rate + spread components
- Historical rate trends
- Consistency across periods

### Step 3: Run Position-Level Query

```sql
SELECT 
    PortfolioCode,
    SecurityId,
    AsOfDate,
    CurrentCoupon,
    MarketValue,
    AccruedInterest
FROM Lumen.dbo.vCollateralDetail
WHERE SecurityId = 'LX235201'  -- Replace with actual ID
    AND AsOfDate >= DATEADD(day, -7, GETDATE())
ORDER BY AsOfDate DESC, PortfolioCode
```

**What to look for:**
- CurrentCoupon values by portfolio
- Variance from AllInRate
- Consistency across portfolios

### Step 4: Calculate Variance

```
Variance (bps) = (CurrentCoupon - AllInRate) × 10,000
Example: (5.415% - 5.394%) × 10,000 = 21.3 bps
```

### Step 5: Determine if Action Required

| Variance | Conclusion | Response |
|----------|-----------|----------|
| 0-10 bps | Expected behavior | Explain to team - no action |
| 10-30 bps | Normal variance | Document and monitor |
| 30-50 bps | Review accrual settings | Investigate further |
| 50+ bps | Data issue | Create ticket for correction |

---

## Standard Response Template

When team asks about rate discrepancies, use this template:

---

**Subject:** Current Coupon vs All-In Rate - Expected Behavior

Hi Team,

I investigated this issue and found that **the difference between Current Coupon and All-In Rate is expected behavior** for floating rate loans.

**Why they're different:**

- **All-In Rate (X.XXX%)** = Contract-level rate (SOFR base + spread) calculated for the **next payment period**
  - Standardized across all positions
  - Same for all funds holding this security

- **Current Coupon (X.XXX%)** = **Position-specific accrual rate**
  - Varies by fund based on purchase date, accrual method, and settlement timing
  - Reflects actual accrued interest for each individual position

**Variance Analysis:**
- Date 1: +X.X bps ✓ Normal
- Date 2: +X.X bps ✓ Normal

**Normal variance:** ±2 to ±10 basis points between the two rates is **expected and correct**.

Both rates ARE driven by the same SOFR index and spread, but they serve different purposes in the system. The All-In Rate is forward-looking (next period), while Current Coupon is position-specific accrual.

**No action required** - this is working as designed.

Full investigation details are in **TASK XXXXX**: [Link to ticket]

Let me know if you need any clarification!

---

---

## SQL Queries Reference

### Query 1: Full Contract Cash Flow History

```sql
SELECT 
    t.InstContractCashFlowID,
    t.InstID,
    t.StartDate,
    t.EndDate,
    t.PaymentDate,
    t.AllInRate,
    t.BaseRate,
    t.Spread,
    t.PrincipalAmount,
    ii.loanxid,
    ii.SecurityDesc
FROM core.dbo.vInstContractCashFlowActive t
JOIN core.dbo.vinstbyidentifier ii ON ii.instid = t.instid 
WHERE ii.loanxid = 'LX235201'
ORDER BY t.StartDate DESC
```

### Query 2: Position-Level Current Coupon

```sql
SELECT 
    cd.PortfolioCode,
    cd.SecurityId,
    cd.AsOfDate,
    cd.CurrentCoupon,
    cd.MarketValue,
    cd.Quantity,
    cd.AccruedInterest,
    p.PortfolioName
FROM Lumen.dbo.vCollateralDetail cd
LEFT JOIN Core.dbo.tPortfolio p ON p.PortfolioCode = cd.PortfolioCode
WHERE cd.SecurityId = 'LX235201'
    AND cd.AsOfDate >= DATEADD(day, -30, GETDATE())
ORDER BY cd.AsOfDate DESC, cd.PortfolioCode
```

### Query 3: Rate Components Breakdown

```sql
SELECT 
    t.InstContractCashFlowID,
    t.StartDate,
    t.EndDate,
    t.BaseRate AS 'SOFR_Rate',
    t.Spread AS 'Fixed_Spread',
    t.AllInRate AS 'All_In_Rate',
    (t.AllInRate - t.Spread) AS 'Calculated_Base_Rate',
    CASE 
        WHEN ABS((t.AllInRate - t.Spread) - t.BaseRate) < 0.0001 THEN 'Match'
        ELSE 'Mismatch'
    END AS 'Validation'
FROM core.dbo.vInstContractCashFlowActive t
JOIN core.dbo.vinstbyidentifier ii ON ii.instid = t.instid 
WHERE ii.loanxid = 'LX235201'
ORDER BY t.StartDate DESC
```

---

## Common Scenarios

### Scenario 1: Team Reports "Rates Don't Match"

**Typical Message:**
> "The current coupon isn't the same as the all in rate. Which is strange because they should be driven by the same index and spread."

**Response Approach:**
1. Run both contract and position queries
2. Calculate variance in basis points
3. Confirm variance is within normal range (0-10 bps)
4. Explain expected behavior using template above
5. Reference TASK 85092 for detailed documentation

---

### Scenario 2: Large Variance (>50 bps)

**Investigation Steps:**
1. Verify correct security identifier
2. Check for data load issues
3. Review accrual method settings in tPortfolio
4. Compare with historical values
5. Check for manual overrides in pricing
6. Create ticket if data issue confirmed

---

### Scenario 3: Collateral Detail Reconciliation Report

**Common Pattern:**
- All-In Rate: Same value for multiple dates
- Current Coupon: Varies slightly by date/portfolio

**Explanation:**
- All-In Rate updates monthly (payment period)
- Current Coupon updates daily (accrual)
- Daily variance in accrual causes small differences

---

## Key Concepts

### SOFR (Secured Overnight Financing Rate)
- Replaces LIBOR as benchmark rate
- Published daily by Federal Reserve
- Used as base rate for floating rate loans
- Typically 1-month, 3-month, or 6-month term SOFR

### Spread
- Fixed percentage added to base rate
- Set at loan origination
- Does not change over life of loan
- Example: 1.75%, 2.00%, 2.50%

### Accrual Methods
- **Actual/360:** Used for most loans
- **Actual/365:** Less common
- **30/360:** Corporate bonds
- Different methods = different daily accrual rates

---

## Related Documentation

- **TASK 85092:** Primary investigation ticket
- **Bug 84955:** Original report of discrepancy
- [Investigation Reports](../../Output/)
  - RateInvestigation_545_InstID500010497_20260724.md
  - RateInvestigation_LX235201_InstID500010497_20260724.md
  - SupplementaryAnalysis_LX235201_vInstContractCashFlowActive_20260724.md

---

## Notes

- **Historical Context:** This behavior has existed since SOFR replaced LIBOR
- **System Design:** Intentional separation of contract vs position calculations
- **Reporting:** Both values are correct for their respective purposes
- **No Fix Needed:** This is not a bug - it's a feature

---

## Example Investigation - LX235201

**Security:** 1011778 BC ULC Senior Secured First @ Term SOFR 1.75% 09/20/2030

**Dates Investigated:**
- July 17, 2026
- July 20, 2026

**Findings:**

| Metric | July 17 | July 20 |
|--------|---------|---------|
| All-In Rate | 5.394% | 5.394% |
| Current Coupon (Garnet CLO 6) | 5.415% | 5.449% |
| Variance | +2.13 bps | +5.47 bps |
| Status | ✅ Normal | ✅ Normal |

**Rate Components:**
- SOFR Base Rate: 3.689%
- Fixed Spread: 1.75%
- All-In Rate: 5.439% (3.689% + 1.75%)

**Conclusion:** Expected behavior - no action required.

**Historical Trend (24 months):**
- Peak: 7.09% (July 2024)
- Current: 5.39% (July 2026)
- Decline: -169 bps (reflects Federal Reserve rate cuts)
- Spread: 1.75% consistent throughout

---

## Quick Reference Card

```
EXPECTED BEHAVIOR CHECKLIST:
☑ Variance < 10 bps? → Normal, no action
☑ Both rates use same SOFR + spread? → Correct
☑ All-In Rate consistent across portfolios? → Expected
☑ Current Coupon varies by portfolio? → Expected
☑ Spread matches loan terms (e.g., 1.75%)? → Correct

ACTION REQUIRED CHECKLIST:
☐ Variance > 50 bps? → Investigate
☐ All-In Rate calculation error? → Fix
☐ Missing SOFR base rate? → Load data
☐ Spread incorrect? → Correct contract
☐ Accrual method wrong? → Update portfolio settings
```

---

## Contact

For questions about this investigation pattern:
- **Primary:** Tay Nguyen (MOS Support)
- **Ticket Reference:** TASK 85092
- **Documentation:** AdminTools/.github/skills/pricing-source-investigation/
