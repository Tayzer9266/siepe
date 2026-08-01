# MOS Support Task Taxonomy
## Back Office SQL Engineers - Research Tasks & Bug Classification

**Purpose:** Categorize common support tasks and bugs to enable skill-based ticket resolution  
**Version:** 1.0  
**Last Updated:** 2026-07-01  
**Scope:** Back Office SQL Engineers backlog analysis

---

## 🤖 Agent Routing Logic

**For MOS Back Office Support Agent:** This section provides quick keyword-to-skill routing with confidence scoring to track taxonomy effectiveness.

### Confidence Scoring System

| Score | Level | Criteria | Action |
|-------|-------|----------|--------|
| 90-100% | High | 3+ exact keyword matches OR 1 exact + clear context | Execute skill immediately |
| 60-89% | Medium | 1-2 exact keywords OR multiple related terms | Execute skill with caution |
| 30-59% | Low | Partial keyword match, requires interpretation | Log to LowConfidenceTickets.md + execute |
| 0-29% | Very Low | No keyword match, unclear category | Log + request manual review |

**⚠️ Tracking:** All tickets with confidence < 70% are logged to `Output/LowConfidenceTickets.md` to identify taxonomy gaps.

### Keyword-to-Skill Mapping

| Keywords (any match) | Category | Skill | Status | Priority |
|---------------------|----------|-------|--------|----------|
| price, pricing, Markit, LSEG, ICE, Sycamore, vendor, enhanced pricing, price source, price weighting | 1 | check-market-price | ✅ Ready | High |
| price exception, bulk price validation, price data review, price mismatch, compare prices, vendor price comparison, Solvas price, SecurityMaster price, position mark | 1A | bulk-price-validation | ✅ Ready | High |
| price override, override price, manual price, custom price, override date, price tagging, tagid 5, market value override, pricing override | 1B | price-overrides | ✅ Ready | High |
| missing identifier, excluded from solvas, identifier not in solvas, missing from portfolio, portfolio exclusion, instrument excluded, entity mapping, loanx missing, cusip missing from solvas, solvas entity issue view, exclude_from_reporting | 1C | missing-identifier-investigation | ✅ Ready | High |
| cash, balance, reconciliation, SFR, cash rec, balance mismatch, cash discrepancy | 2 | check-cash-reconciliation | 🚧 Phase 1 | Critical |
| normalization, mapping, data transform, source data, normalize, feed mapping | 3 | check-data-normalization | 🚧 Phase 1 | Medium |
| SSIS, PowerShell, job failed, package error, ETL, integration services, script error, silent success, zero rows, no records created, package succeeded but, fast execution, DTSER_SUCCESS | 4 | check-ssis-errors | ✅ Ready | High |
| new portfolio, fund setup, account setup, onboarding, portfolio configuration | 5 | setup-portfolio | 📋 Phase 2 | Medium |
| data quality, missing data, incorrect data, validation, data integrity | 6 | check-data-quality | 📋 Phase 2 | Medium |
| slow, performance, timeout, query optimization, hanging, long running | 7 | optimize-performance | 📋 Phase 2 | High |
| feed, import, integration, vendor file, data delivery, file delivery, import error | 8 | check-data-feeds | 📋 Phase 2 | High |
| workflow, approval, stuck, pending approval, approval process | 9 | check-workflow | 📋 Phase 3 | Medium |
| schema change, add column, new table, alter, DDL, database change | 10 | review-schema-change | 📋 Phase 3 | Low |
| process dashboard, operations dashboard, delete report, remove report, dashboard report, editors, cashflow report, decommission report | 11 | remove-process-dashboard-reports | ✅ Ready | Medium |
| outlook, email, inbox, search email, find email, retrieve email, email from, extract email, email confirmation, stakeholder email | 12 | outlook-email-extraction | ✅ Ready | Low |
| process emails, create tasks, email automation, convert email to task, auto-create tickets, email workflow, mos-support inbox | 13 | process-mos-support-emails | ✅ Ready | High |
| planning wiki, create planning, epic planning, roadmap document, project planning, wiki page, overview document, work items hierarchy, phase planning | 14 | create-planning-wiki | ✅ Ready | Low |

### Routing Algorithm

```pseudocode
FUNCTION RouteTicket(ticketID, ticketTitle, ticketDescription):
    keywords = ExtractKeywords(ticketTitle + " " + ticketDescription)
    bestMatch = null
    highestConfidence = 0
    
    FOR EACH category IN taxonomy:
        exactMatches = 0
        partialMatches = 0
        
        // Count keyword matches
        FOR EACH categoryKeyword IN category.keywords:
            IF categoryKeyword EXACT_MATCH IN keywords:
                exactMatches += 1
            ELSE IF categoryKeyword PARTIAL_MATCH IN keywords:
                partialMatches += 1
        
        // Calculate confidence score
        confidence = CalculateConfidence(exactMatches, partialMatches, keywords)
        
        IF confidence > highestConfidence:
            highestConfidence = confidence
            bestMatch = category
    
    // Log low confidence tickets for taxonomy improvement
    IF highestConfidence < 70:
        LogLowConfidenceTicket(ticketID, highestConfidence, bestMatch, keywords)
    
    // Route based on confidence
    IF highestConfidence >= 30:
        IF bestMatch.status == "✅ Ready":
            RETURN ExecuteSkill(bestMatch.skill, ticketData, highestConfidence)
        ELSE:
            RETURN ManualInvestigation(bestMatch, ticketData, highestConfidence)
    ELSE:
        // Very low confidence - manual review required
        RETURN RequestHumanClassification(ticketData, highestConfidence)


FUNCTION CalculateConfidence(exactMatches, partialMatches, contextKeywords):
    baseScore = 0
    
    // Scoring rules
    IF exactMatches >= 3 OR (exactMatches >= 1 AND contextClear):
        baseScore = 90 + MIN(exactMatches * 2, 10)  // 90-100%
    ELSE IF exactMatches >= 1 OR partialMatches >= 3:
        baseScore = 60 + (exactMatches * 10) + (partialMatches * 5)  // 60-89%
    ELSE IF partialMatches >= 1:
        baseScore = 30 + (partialMatches * 10)  // 30-59%
    ELSE:
        baseScore = 10  // 0-29%
    
    RETURN MIN(baseScore, 100)
```

### Priority Escalation Rules

| Ticket Priority | Response Time | Skill Execution | Follow-up |
|----------------|---------------|-----------------|-----------|
| **Critical** (Cash rec, production issues) | < 2 hours | Immediate | Update every 4 hours |
| **High** (Pricing, SSIS, Performance) | < 4 hours | Same day | Update by EOD |
| **Medium** (Data quality, normalization) | < 8 hours | Within 24 hours | Update next day |
| **Low** (Schema changes, enhancements) | < 24 hours | Within 1 week | Update weekly |

---

## Taxonomy Overview

This taxonomy classifies MOS support tasks into **10 primary categories** with detailed subcategories, typical symptoms, required investigation steps, and recommended skills for resolution.

### How to Use This Taxonomy

**For Agents:**
1. Extract keywords from ticket title and description
2. Match keywords to routing table above
3. Execute appropriate skill if status = ✅ Ready
4. Follow manual investigation for 🚧 or 📋 skills

**For Human Analysts:**
1. **Read ticket title and description** → Identify keywords and symptoms
2. **Match to primary category** → Use category definitions and indicators
3. **Select subcategory** → Narrow down specific issue type
4. **Apply appropriate skill** → Use recommended investigation skill
5. **Follow investigation pattern** → Execute standard diagnostic steps

---

## Category Index

| # | Category | Typical Tickets/Year | Avg Priority | Skill Required |
|---|----------|---------------------|--------------|----------------|
| 1 | [Market Pricing Issues](#1-market-pricing-issues) | ~50 | High | check-market-price |
| 1A | [Bulk Price Validation](#1a-bulk-price-validation) | ~30 | High | bulk-price-validation |
| 1B | [Price Overrides](#1b-price-overrides) | ~20 | High | price-overrides |
| 2 | [Cash Reconciliation](#2-cash-reconciliation) | ~120 | Critical | CheckCashReconciliation |
| 3 | [Data Normalization](#3-data-normalization) | ~80 | Medium | CheckDataNormalization |
| 4 | [SSIS/PowerShell Errors](#4-ssispowershell-errors) | ~150 | High | CheckSSISErrors |
| 5 | [Portfolio/Fund Setup](#5-portfoliofund-setup) | ~40 | Medium | SetupPortfolio |
| 6 | [Data Quality Issues](#6-data-quality-issues) | ~60 | Medium | CheckDataQuality |
| 7 | [Performance Issues](#7-performance-issues) | ~30 | High | OptimizePerformance |
| 8 | [Integration/Feed Issues](#8-integrationfeed-issues) | ~70 | High | CheckDataFeeds |
| 9 | [Workflow/Approval](#9-workflowapproval) | ~25 | Medium | CheckWorkflow |
| 10 | [Database Schema Changes](#10-database-schema-changes) | ~200 | Low | ReviewSchemaChange |
| 11 | [Dashboard/Report Management](#11-dashboardreport-management) | ~15 | Medium | RemoveProcessDashboardReports |

**Total Annual Tickets:** ~890

---

## 1. Market Pricing Issues

### Category Definition
Issues related to vendor pricing data, price selection logic, price weighting configuration, or missing/incorrect market prices for instruments.

### Subcategories

#### 1.1 Missing Vendor Prices
**Description:** Instruments have no prices from any vendor source on a specific date

**Common Symptoms:**
- "Markit pricing not available"
- "Price exception report shows missing prices"
- "Enhanced pricing report has gaps"
- "Instrument shows NULL evaluated price"

**Typical Root Causes:**
- Vendor coverage discontinued for instrument
- Instrument matured/called/paid off
- Data feed delivery failure
- New instrument not yet in vendor universe
- Holiday pricing delays

**Investigation Steps:**
1. Verify instrument exists and is active
2. Check all vendor sources for the date (Markit, LSEG, ICE, Sycamore)
3. Review historical price availability (last date with price)
4. Check vendor import logs for errors
5. Verify position still exists in portfolios

**Required Database Queries:**
- `Reference.dbo.vInstPriceCurrentRaw` - Check vendor prices
- `Core.dbo.vPositionRaw` - Verify position exists
- `Reference.dbo.vRefDataImportCurrent` - Check import status

**Recommended Skill:** `CheckMarketPrice.instructions.md`

**Example Tickets:**
- #82115: "FW: Aristotle - Enhanced Pricing Report Daily"
- #74046: "Incorrect Prices (Sycamore)"
- #73505: "Sycamore - MOS Price Exception Report"
- #71075: "Sycamore - MOS Price Exception Report (INTERNAL)"

---

#### 1.2 Price Source Priority/Weighting Issues
**Description:** Wrong vendor price being used due to price weighting configuration

**Common Symptoms:**
- "Why is LSEG price used instead of Markit?"
- "Expected Markit but got ICE pricing"
- "Price doesn't match vendor priority"
- "Configuration review requested"

**Typical Root Causes:**
- Price weighting rules don't cover asset type
- Preferred source has no price (fallback to lower priority)
- Asset type mismatch in configuration
- Company-specific weighting not configured

**Investigation Steps:**
1. Identify company ID and price weighting configuration
2. Check instrument asset type (Bond, Equity, ABS, Loan)
3. Compare available vendor sources with weighting rules
4. Identify which rule matched and why
5. Determine if configuration change needed

**Required Database Queries:**
- `Core.dbo.vPositionPriceWeightingActive` - Price weighting config
- `Core.dbo.vInst` JOIN `Core.dbo.vInstType` - Asset type
- `Reference.dbo.vInstPriceCurrentRaw` - Available prices

**Recommended Skill:** `CheckMarketPrice.instructions.md`

**Resolution Patterns:**
- Add missing asset type filter to weighting rule
- Adjust weight values to change priority
- Add manual price override if needed

---

#### 1.3 Price Import/Feed Errors
**Description:** Vendor price files not importing correctly

**Common Symptoms:**
- "Prices stopped updating"
- "Import log shows errors"
- "Stale prices from yesterday"
- "File delivery failure"

**Typical Root Causes:**
- File format changed
- FTP/SFTP connection issues
- File corruption
- Schema mismatch in SSIS package

**Investigation Steps:**
1. Check vendor import job status
2. Review error logs from import process
3. Verify file was delivered to expected location
4. Check file format matches expected schema
5. Review recent vendor communication about changes

**Required Database Queries:**
- `Reference.dbo.vRefDataImportCurrent` - Import history
- SiepeAdmin monitoring tables for import jobs

**Recommended Skill:** `CheckDataFeeds.instructions.md`

---

#### 1.4 Price Calculation/Display Issues
**Description:** Prices are present but calculated or displayed incorrectly

**Common Symptoms:**
- "Price shows wrong decimal places"
- "Mid calculation incorrect"
- "Bid/Ask spread doesn't match"
- "Factor not applied correctly"

**Typical Root Causes:**
- Rounding logic errors
- Factor application missing
- Currency conversion issues
- Display formatting problems

**Investigation Steps:**
1. Verify raw vendor price vs. displayed price
2. Check price type selection (Bid/Ask/Mid/Price)
3. Review factor application logic
4. Check stored procedure calculations

**Recommended Skill:** `CheckDataQuality.instructions.md`

---

## 1A. Bulk Price Validation

### Category Definition
Large-scale price data validation tasks requiring comparison of prices across multiple securities, portfolios, and data sources. Typically involves Excel attachments with hundreds of price exceptions that need systematic validation.

### Key Characteristics
- **Volume:** 50+ securities requiring validation (vs. single CUSIP investigations)

---

## 1C. Missing Identifier Investigation

### Category Definition
Research and troubleshooting when an identifier (CUSIP, LoanX ID, ISIN) exists in MOS Reference with valid prices but is missing from Solvas portfolios or excluded from client reports. Includes entity mapping validation, portfolio exclusion configuration, and Solvas Entity_Issue_view analysis.

### Common Symptoms
- "LX{ID} is excluded from Sycamore portfolios"
- "CUSIP exists in MOS but not appearing in Solvas"
- "Identifier missing from position extract"
- "Instrument not in deal_facility_market_value table"
- "Entity_Issue_view doesn't show this LoanX ID"
- "Portfolio exclusion - why isn't this instrument included?"

### Typical Root Causes
1. **Reporting Exclusion Flag:** `exclude_from_reporting = 1` in Solvas facility/issue table
2. **Inactive Status:** `active_flag = 0` marking instrument as closed
3. **Entity Mapping Gap:** MOS Portfolio name doesn't map to Solvas deal_name
4. **Import Filter:** Instrument import job filtered out this asset type or identifier
5. **Manual Exclusion:** Client requested specific instruments be excluded from reports
6. **Maturity/Payoff:** `payoff_date` set indicating loan paid off (but position still exists in MOS)
7. **Never Imported:** Identifier never mapped during initial Solvas setup

### Investigation Steps

1. **Verify MOS Reference Status**
   - Check identifier exists in `core.dbo.vposition`
   - Confirm active positions with non-zero quantities
   - Validate position marks and prices are current

2. **Check Solvas Entity_Issue_view**
   - Query `solvas_am.dbo.Entity_Issue_view` for identifier
   - Check facility_id/issue_id mapping
   - Verify entity_id matches expected portfolio

3. **Analyze Exclusion Configuration**
   - Check `solvas_am.dbo.facility.exclude_from_reporting`
   - Check `solvas_am.dbo.issue.exclude_from_reporting`
   - Validate active_flag status
   - Review maturity_date and payoff_date fields

4. **Validate Entity Mapping**
   - Compare MOS Portfolio names with Solvas deal_name patterns
   - Check for entity_id mismatches
   - Identify missing entity-to-portfolio links

5. **Review Import History**
   - Check `Feeds.dbo.vGenericImportHistory` for instrument imports
   - Look for rejected records or validation errors
   - Verify import job configuration and filters

6. **Test Price Upload Process**
   - Execute `core.Report.pSolvasExportPriceEntity` with verbose logging
   - Check if identifier is filtered by @InstrumentSourceIDList parameter
   - Validate price successfully inserted into deal_*_market_value tables

### Resolution Patterns

**Pattern 1: Re-enable Excluded Instrument**
```sql
UPDATE solvas_am.dbo.facility
SET exclude_from_reporting = 0, active_flag = 1
WHERE facility_id = {FacilityID};
```

**Pattern 2: Create Entity Mapping**
- Open Solvas AM application
- Navigate to Entity Management → Add Facility/Issue
- Map identifier to correct entity_id
- Verify in Entity_Issue_view

**Pattern 3: Update Price Export Filter**
```sql
EXEC core.Report.pSolvasExportPriceEntity  
    @CompanyID = '500000004',
    @InstrumentSourceIDList = NULL;  -- Include all instruments
```

**Pattern 4: Manual Price Insert (Temporary)**
```sql
INSERT INTO solvas_am.dbo.deal_facility_market_value 
    (entity_id, facility_id, begin_date, market_value_indent, pricing_type_1)
VALUES ({EntityID}, {FacilityID}, '{Date}', {Price}, 1);
```

### Required Database Queries
- `core.dbo.vposition` - Verify MOS positions
- `solvas_am.dbo.Entity_Issue_view` - Check Solvas mapping
- `solvas_am.dbo.facility` / `solvas_am.dbo.issue` - Check exclusion flags
- `Feeds.dbo.vGenericImportHistory` - Review import logs
- `solvas_am.dbo.deal_facility_market_value` - Validate prices

### Recommended Skill
`check-market-price` (Step 7c: Investigate Missing Identifiers / Portfolio Exclusions)

### Example Tickets
- #85904: "LX293801 excluded from Sycamore portfolios - research why"
- #84125: "CUSIP 12345ABC7 exists in MOS but not in Solvas Entity_Issue_view"
- #83501: "Position extract missing instruments - portfolio exclusion issue"

### Validation After Resolution
```sql
-- Verify identifier now appears in Solvas with prices
SELECT 
    e.deal_name, ev.lx_identifier, dmv.begin_date, dmv.market_value_indent
FROM solvas_am.dbo.Entity_Issue_view ev
JOIN solvas_am.dbo.entity e ON e.entity_id = ev.entity_id
LEFT JOIN solvas_am.dbo.deal_facility_market_value dmv 
    ON dmv.facility_id = ev.facility_id AND dmv.entity_id = ev.entity_id
WHERE ev.lx_identifier = '{LoanXID}'
    AND e.deal_name LIKE '{Pattern}%'
ORDER BY dmv.begin_date DESC;
```

**Expected Result:** Identifier appears with current prices in all expected portfolios

---

## 1A. Bulk Price Validation (Continued)

### Key Characteristics
- **Volume:** 50+ securities requiring validation (vs. single CUSIP investigations)
- **Format:** Excel file with multiple columns to fill (comparison questions)
- **Scope:** Cross-reference checking across MOS, Solvas, SecurityMaster, vendor sources
- **Deliverable:** Completed Excel with validation results + summary report

### Subcategories

#### 1A.1 Client Price Exception Reviews
**Description:** Client provides list of price exceptions requesting validation of vendor pricing vs. their internal marks

**Common Symptoms:**
- "Review list and confirm price data"
- "Fill out the 3 columns on the right"
- Ticket has Excel attachment with price exception list
- Multiple portfolios, same date range
- Questions about position mark vs. bid price

**Typical Root Causes (of price differences):**
- Price timing differences (MOS EOD vs. client snapshot)
- Different price sources within vendor (bid vs. mid vs. ask)
- Stale prices (one side not updated)
- Identifier mapping issues
- Missing vendor coverage for certain securities

**Investigation Steps:**
1. Download Excel attachment from ADO ticket
2. Analyze Excel structure (identify columns, check for Queries sheet)
3. Extract SQL query templates if provided
4. Create PowerShell automation script to:
   - Compare MOS position mark vs. client price
   - Check if vendor bid price exists on MOS
   - Query Solvas for portfolio price data
   - Query SecurityMaster for reference prices
5. Fill validation columns systematically
6. Analyze results for patterns (timing, vendor coverage, data gaps)
7. Generate summary report with findings and recommendations
8. Upload completed Excel + markdown report to ticket

**Required Database Queries:**
- `Core.dbo.vposition` - Position marks
- `Reference.dbo.vinstpricecurrentraw` - Vendor prices on MOS
- `Reference.dbo.tInstPrice` - SecurityMaster prices
- `solvas_am.dbo.deal_facility_market_value` - Solvas loan prices
- `solvas_am.dbo.deal_issue_market_value` - Solvas bond prices

**Validation Logic:**
```
Position Mark Mismatch = |MOSPrice - ClientPrice| > $0.01
Bid Price on MOS = COUNT(vendor prices for date) > 0
Correct Price on SecM = |SecMPrice - ClientPrice| < $0.01
Solvas Price Mismatch = |SolvasPrice - ClientPrice| > $0.01
```

**Recommended Skill:** `bulk-price-validation\SKILL.md`

**Example Tickets:**
- #82309: "Review list and confirm price data for Sycamore" (622 securities, 9 portfolios)

**Common Patterns:**
- **Systematic timing differences:** Small discrepancies ($0.01-$0.50) across many securities → Document, no action if < $0.50
- **Missing vendor coverage:** Securities without bid prices → Verify subscription, request vendor add to feed
- **Solvas data gaps:** Missing price data → Coordinate with Solvas team to load securities
- **Large discrepancies (>$5):** Verify identifier mapping, check corporate actions, manual validation

**Automation Opportunity:** HIGH - PowerShell script can process 500+ rows in 10-15 minutes vs. 4-6 hours manual work

**Resolution Time:**
- Small (<100 securities): 30-60 minutes
- Medium (100-500): 1-2 hours  
- Large (>500): 2-4 hours

---

#### 1A.2 Bulk Price Data Quality Audits
**Description:** Periodic audits of price data quality across multiple portfolios or security types

**Common Symptoms:**
- "Audit MarkIt prices for Q2"
- "Validate all ABS pricing for client"
- "Review prices for matured securities"
- Scheduled quarterly/annual reviews

**Typical Focus Areas:**
- Price availability by asset type
- Vendor coverage gaps
- Stale price detection (not updated in X days)
- Price outliers (statistical analysis)
- Corporate action pricing validation

**Investigation Steps:**
1. Define audit scope (date range, portfolios, asset types)
2. Extract security universe from MOS
3. Generate price availability matrix (security × vendor × date)
4. Identify outliers and gaps
5. Cross-reference with corporate actions
6. Generate quality metrics report

**Required Database Queries:**
- `Reference.dbo.vInstPriceCurrentRaw` - Price history
- `Core.dbo.vInst` + `Core.dbo.vInstType` - Security universe
- `Reference.dbo.vCorporateAction` - Corporate actions
- Aggregate queries for coverage statistics

**Recommended Skill:** `bulk-price-validation\SKILL.md` (adapted for audit scenarios)

**Resolution Time:** 2-8 hours depending on scope

---

#### 1A.3 Price Migration/Conversion Validation
**Description:** Validation after price vendor migration or data conversion projects

**Common Symptoms:**
- "Validate prices after MarkIt → LSEG migration"
- "Confirm all prices loaded after database upgrade"
- "Spot check pricing post-conversion"
- Before/after comparison required

**Typical Validation Checks:**
- Record counts match between old/new system
- Sample price values identical
- No missing securities after migration
- Date ranges complete
- Historical data intact

**Investigation Steps:**
1. Extract pre-migration baseline (control group)
2. Extract post-migration data
3. Compare record counts by security, date, vendor
4. Spot check 50-100 random prices for exact match
5. Identify discrepancies and root cause
6. Document differences and approval for cutover

**Required Artifacts:**
- Pre-migration data extract
- Post-migration data extract  
- Comparison script (PowerShell or SQL)
- Sign-off documentation

**Recommended Skill:** `bulk-price-validation\SKILL.md` + custom comparison logic

**Resolution Time:** 3-6 hours

---

## 1B. Price Overrides

### Category Definition
Manual price override requests for specific securities on specific dates where automated vendor pricing needs to be replaced with custom values. This involves coordinating updates across both MOS and Solvas databases to ensure consistent override pricing.

### Key Characteristics
- **Scope:** Specific CUSIPs/securities with override dates and prices
- **Coordination:** Requires updates in both MOS (tagging) and Solvas (market value)
- **Asset Types:** Bonds (Deal_Issue_Market_Value) and Loans (Deal_Facility_Market_Value)
- **Deliverable:** SQL statements for tagging and price insertion (not executed, for review)

### Subcategories

#### 1B.1 Single Security Price Override
**Description:** Override price for one CUSIP/security across one or more portfolios

**Common Symptoms:**
- "Apply override price for CUSIP 68610BAA2 on 6/30/2026"
- "Manual price needed for [security] effective [date]"
- "Custom pricing for [fund]"
- Ticket includes: CUSIP, override price, override date, Inst ID

**Typical Root Causes (for override request):**
- Vendor price unavailable or unreliable
- Client-specific pricing methodology
- Illiquid security requiring manual valuation
- Corporate action pricing adjustment
- Fair value pricing override

**Investigation Steps:**
1. **Validate Input:** Confirm CUSIP, Inst ID, override price, override date, portfolio names
2. **MOS Database - Get Identifiers:**
   - Query `core.dbo.vinstidentifiercurrent` to get `instidentifierid` and `instid`
   - Verify Inst ID matches
3. **MOS Database - Check Tagging:**
   - Query `core.dbo.vTagMapActive` for TagID = 5
   - Generate tagging statements for portfolios missing tag
4. **Solvas Database - Determine Asset Type:**
   - Query `Deal_Issue_Market_Value` (bonds) or `Deal_Facility_Market_Value` (loans)
   - Identify entity_id, issue_id/facility_id
5. **Solvas Database - Generate Delete Statements:**
   - Create statements to delete existing market values for override date
6. **Solvas Database - Generate Insert Statements:**
   - Create statements to insert override price values

**Required Database Queries:**
```sql
-- Step 1: MOS - Get Instrument IDs
SELECT instidentifierid, instid, * 
FROM core.dbo.vinstidentifiercurrent 
WHERE value = '{CUSIP}'

-- Step 2: MOS - Check Tagging
SELECT portfolioId, * 
FROM core.dbo.vTagMapActive 
WHERE tagid = 5 AND instid = '{instid}'

-- Step 3: Solvas - Bonds
SELECT ev.cusip_number, e.deal_name, d.begin_date, d.end_date
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
WHERE ev.cusip_number IN ('{CUSIP}')
AND d.begin_date >= '{override_date}'

-- Step 3: Solvas - Loans
SELECT ev.LX_identifier, e.deal_name, d.begin_date, d.end_date
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view EV 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
WHERE ev.lx_identifier IN ('{CUSIP}')
AND d.begin_date >= '{override_date}'
```

**Generated Output (DO NOT EXECUTE):**
- **MOS Tagging:** `pTagMapI` stored procedure statements
- **Solvas Delete:** `deal_Issue_market_value_del` or `deal_facility_market_value_del` statements
- **Solvas Insert:** `Deal_issue_market_value_put` or `Deal_Facility_market_value_put` statements

**Recommended Skill:** `price-overrides\SKILL.md`

**Example Tickets:**
- #82685: "Price override for 68610BAA2, 15477CAA3, LX232483 on 6/30/2026"

**Output Format:**
- Markdown file: `PriceOverride_{TicketNumber}_{Date}.md`
- SQL files for each step (tagging, delete, insert)
- Console output with all statements for review

**Critical Safety Rules:**
- ⚠️ **NEVER execute SQL directly** - always output for reviewer approval
- Validate CUSIP exists in MOS before proceeding
- Confirm portfolio names match between input and Solvas
- Document all generated statements with context

**Resolution Time:**
- Single CUSIP: 15-30 minutes
- Multiple CUSIPs (3-5): 30-60 minutes
- Complex multi-portfolio: 1-2 hours

---

#### 1B.2 Bulk Price Override (Multiple Securities)
**Description:** Override prices for multiple securities, typically from Excel file

**Common Symptoms:**
- Excel attachment with columns: CUSIP, Override Price, Override Date, Inst ID, Portfolio Names
- "Apply overrides for attached list"
- Multiple securities requiring same effective date

**Investigation Steps:**
1. Parse Excel input file
2. For each CUSIP, repeat single override workflow
3. Organize output by CUSIP
4. Generate consolidated SQL files

**Automation Opportunity:** HIGH - PowerShell can iterate through Excel rows

**Recommended Skill:** `price-overrides\SKILL.md` (batch mode)

**Resolution Time:** 1-3 hours depending on volume

---

#### 1B.3 Recurring Price Overrides
**Description:** Regular/scheduled price overrides (monthly, quarterly)

**Common Symptoms:**
- "Apply monthly override for fund X"
- "Quarter-end custom pricing"
- Recurring pattern in ticket history

**Investigation Steps:**
1. Identify recurring pattern
2. Document standard override process
3. Consider automation for routine overrides
4. Create scheduled task if appropriate

**Recommended Skill:** `price-overrides\SKILL.md` + automation consideration

**Resolution Time:** Initial setup 2-4 hours, recurring 30 minutes

---

## 2. Cash Reconciliation

### Category Definition
Issues related to cash balance matching, transaction reconciliation, single fund refresh, and cash rec tool workflows.

### Subcategories

#### 2.1 Balance Discrepancies
**Description:** Cash balances don't match between custodian and internal systems

**Common Symptoms:**
- "Prior day balance discrepancies"
- "Balance not feeding in"
- "Cash rec tool shows mismatch"
- "Balance out of balance by $X"

**Typical Root Causes:**
- Custodian file delivery delayed
- Transaction timing differences (T vs. T+1)
- Missing transactions
- Duplicate transactions
- Currency conversion errors
- Weekend/holiday file issues

**Investigation Steps:**
1. Identify portfolio and account with discrepancy
2. Compare custodian balance vs. MOS balance
3. Review transaction history for missing/extra items
4. Check import timing and file delivery logs
5. Verify currency and portfolio mapping
6. Compare prior day balance carryforward

**Required Database Queries:**
- `CashRec.vBalance` - Current balances
- `CashRec.vTransaction` - Transaction details
- Custodian normalization views (e.g., `Custodian.vCitiBalances`)
- `Core.dbo.vRefDataSetActive` - Check data refresh dates

**Recommended Skill:** `CheckCashReconciliation.instructions.md`

**Example Tickets:**
- #70176: "Prior Day Balance Discrepancies in Cash Rec - SQL Updates"
- #69783: "Balance not feeding in for MissionSquare PLUS Fund"
- #72227: "MMF Balances Not Feeding into MOS Portal"

---

#### 2.2 Transaction Matching Issues
**Description:** Transactions not auto-matching or incorrect match suggestions

**Common Symptoms:**
- "Transaction not matching automatically"
- "Incorrect match suggestions"
- "Duplicate match detected"
- "Previously matched transaction re-matching"

**Typical Root Causes:**
- Match tolerance too tight/loose
- Transaction timing differences
- Reference field mismatch
- Multiple similar transactions
- Match logic changes

**Investigation Steps:**
1. Review transaction details from both sides
2. Check match tolerance settings
3. Analyze match logic for transaction type
4. Verify reference fields match
5. Review match history and audit trail

**Required Database Queries:**
- `CashRec.pTransactionChanges` - Transaction comparison
- `CashRec.vMatchGroups` - Match logic
- Transaction normalization views

**Recommended Skill:** `CheckCashReconciliation.instructions.md`

**Example Tickets:**
- #74168: "Review Match groups from 3/31 QE"
- #69410: "Discuss Automatch matching logic for previously match"

---

#### 2.3 Single Fund Refresh (SFR) Issues
**Description:** Single fund refresh process failing or producing incorrect results

**Common Symptoms:**
- "SFR failed"
- "Balance refresh button not working"
- "SFR status shows error"
- "Concurrent import issues"

**Typical Root Causes:**
- Dependency issues between components
- Timeout on large data sets
- Lock conflicts
- Missing data in source system
- Concurrent execution conflicts

**Investigation Steps:**
1. Check SFR status and error messages
2. Review component dependencies
3. Check for lock/timeout issues
4. Verify source data availability
5. Review concurrent execution settings

**Required Database Queries:**
- `SingleFundRefreshStatus` tables
- Job execution logs
- Lock status queries

**Recommended Skill:** `CheckWorkflow.instructions.md`

**Example Tickets:**
- #73280: "Update Cash Rec SFR Refresh to use concurrent Imports"
- #70536: "Testing Cash Rec Balance Button and SFR Button Refresh"

---

#### 2.4 Cash Rec Approval Workflow
**Description:** Issues with approving or managing cash rec records

**Common Symptoms:**
- "Cannot approve cash rec"
- "Approval button not working"
- "Stale balance check blocking approval"
- "Fund management issues"

**Typical Root Causes:**
- Business rule violations
- Missing required data
- Workflow state issues
- Permission problems
- Configuration errors

**Investigation Steps:**
1. Check approval business rules
2. Verify required data present
3. Review workflow state
4. Check user permissions
5. Verify fund configuration

**Required Database Queries:**
- `CashRec` schema tables
- Approval workflow status
- Fund management configuration

**Recommended Skill:** `CheckWorkflow.instructions.md`

**Example Tickets:**
- #74056: "Add ability to approve cash rec if there is a balance adjustment"
- #71392: "Remove Stale Balances Check for Approving Rec"

---

## 3. Data Normalization

### Category Definition
Issues related to data transformation from source systems (Solvas, custodians, vendors) into MOS normalized structures.

### Subcategories

#### 3.1 Transaction Normalization
**Description:** Transaction data not normalizing correctly from source to MOS

**Common Symptoms:**
- "Transaction type not mapping"
- "Transaction missing after import"
- "Duplicate transactions"
- "Transaction reference field incorrect"

**Typical Root Causes:**
- New transaction type in source not mapped
- Normalization logic doesn't handle edge case
- String parsing errors
- Date format issues
- Null handling errors

**Investigation Steps:**
1. Identify source transaction record
2. Review normalization view logic
3. Check transaction type mappings
4. Test normalization logic with sample data
5. Verify all required fields populated

**Required Database Queries:**
- Source transaction tables (e.g., `Custodian.tCitiTransactionRaw`)
- Normalization views (e.g., `Custodian.vCitiTransactionNormalization`)
- `Reference.dbo.vTransactionType` - Transaction type mappings

**Recommended Skill:** `CheckDataNormalization.instructions.md`

**Example Tickets:**
- #74076: "Update Cash Rec Approval logic"
- #69864: "Update Transaction extracts for transaction type"
- #70530: "Update Normalization from TransactionTypes"

---

#### 3.2 Balance Normalization
**Description:** Balance data not normalizing correctly from custodian files

**Common Symptoms:**
- "Balance not loading"
- "Balance value incorrect"
- "Currency not converting"
- "Account mapping issue"

**Typical Root Causes:**
- Portfolio mapping incorrect
- Currency conversion missing
- Account identifier mismatch
- File format changed
- Duplicate custodian portfolios

**Investigation Steps:**
1. Review raw balance data from custodian
2. Check normalization view logic
3. Verify portfolio/account mappings
4. Test currency conversion
5. Check for duplicates

**Required Database Queries:**
- Custodian balance tables
- Balance normalization views
- Portfolio mapping tables

**Recommended Skill:** `CheckDataNormalization.instructions.md`

**Example Tickets:**
- #72815: "Review Balances Normalizations and combine union to outerapply"
- #69952: "Review Balances Normalizations and combine union to outerapply"

---

#### 3.3 Position Normalization
**Description:** Position/holdings data not normalizing correctly from Solvas or custodians

**Common Symptoms:**
- "Position missing"
- "Quantity incorrect"
- "Cost basis wrong"
- "Market value calculation error"

**Typical Root Causes:**
- Factor not applied
- Currency conversion issue
- Quantity aggregation error
- Date mismatch
- Duplicate positions

**Investigation Steps:**
1. Review source position data
2. Check normalization calculations
3. Verify factor application
4. Test quantity/value calculations
5. Check for duplicate records

**Recommended Skill:** `CheckDataNormalization.instructions.md`

**Example Tickets:**
- #70531: "Update Position Normalization for realized gain/loss for Piks"
- #72713: "MOS Position Normalization Fails on T Date"

---

## 4. SSIS/PowerShell Errors

### Category Definition
Errors occurring in SSIS packages or PowerShell scripts that load, transform, or export data.

### Subcategories

#### 4.1 Script Task Failures
**Description:** SSIS script tasks failing during package execution

**Common Symptoms:**
- "Script Task index out of range"
- "Script Task failure across Blank row"
- "Script Task Load Data failure"
- "Column count mismatch"

**Typical Root Causes:**
- File format changed
- Unexpected blank/null rows
- Array index errors
- Data type mismatches
- Missing columns in source

**Investigation Steps:**
1. Review error message and stack trace
2. Check source file format
3. Verify column counts and data types
4. Test with actual file that failed
5. Review recent package changes

**Required Tools:**
- Seq logs for error details
- SSIS package definitions
- Source files for testing
- SQL Server Integration Services

**Recommended Skill:** `CheckSSISErrors.instructions.md`

**Example Tickets:**
- #74228: "[Seq Error Triage] PowerShell - SecMaster SSIS pInstMapI OLE DB dat..."
- #74087: "[Seq Error Triage] PowerShell - SSIS WITH RESULT SETS column count..."
- #74003: "[Seq Error Triage] PowerShell/SSIS - Script Task failures across Bl..."

---

#### 4.2 File Access/Delivery Issues
**Description:** SSIS packages unable to access or process files

**Common Symptoms:**
- "File access failure"
- "File lock"
- "File not found"
- "Blank file detected"

**Typical Root Causes:**
- FTP/SFTP connection issues
- File permissions
- Timing issues (file not ready)
- File locked by another process
- Vendor delivery failure

**Investigation Steps:**
1. Verify file exists in expected location
2. Check file permissions
3. Review FTP/SFTP logs
4. Check file delivery timing
5. Verify network connectivity

**Recommended Skill:** `CheckDataFeeds.instructions.md`

**Example Tickets:**
- #73082: "[Seq Error Triage] PowerShell - Sycamore file access failure"
- #73081: "[Seq Error Triage] PowerShell - CitiTrustee SSIS file access"

---

#### 4.3 SQL Execution Errors
**Description:** SQL errors occurring during SSIS package execution

**Common Symptoms:**
- "SQL syntax error"
- "OLE DB pipeline canceled"
- "InstID lookup failed"
- "LegalEntityID SQL syntax error"

**Typical Root Causes:**
- Invalid SQL syntax
- Missing/misnamed objects
- Data type conversion errors
- Null constraint violations
- Permission issues

**Investigation Steps:**
1. Review exact SQL error message
2. Identify failing query/stored procedure
3. Test query in isolation
4. Check object existence and permissions
5. Review recent schema changes

**Recommended Skill:** `CheckSSISErrors.instructions.md`

**Example Tickets:**
- #74007: "[Seq Error Triage] PowerShell - Diameter SSIS LegalEntityID SQL syn..."
- #70606: "[Seq Error Triage] PowerShell - Diameter SSIS SQL syntax error near..."

---

#### 4.4 Deadlocks and Timeouts
**Description:** SSIS packages encountering deadlocks or timeouts

**Common Symptoms:**
- "Deadlock on Script Task"
- "Command timeout"
- "Query execution timeout"
- "Lock timeout exceeded"

**Typical Root Causes:**
- Concurrent execution conflicts
- Long-running queries
- Missing indexes
- Lock escalation
- Blocking chains

**Investigation Steps:**
1. Check deadlock graph/extended events
2. Identify blocking processes
3. Review concurrent job schedules
4. Analyze query execution plans
5. Check index usage

**Recommended Skill:** `OptimizePerformance.instructions.md`

**Example Tickets:**
- #69298: "[Seq Error Triage] PowerShell - Onex SSIS deadlock on Script Task"

---

#### 4.5 Silent Success Failures ⚠️
**Description:** SSIS packages return SUCCESS status but process ZERO rows despite source data existing

**Common Symptoms:**
- Package returns DTSER_SUCCESS (0)
- Execution time suspiciously fast (< 2 seconds for thousands of expected records)
- Job history shows "Success" but no data changes
- No error messages in logs
- Source data exists but target table unchanged
- Data freshness issues (last CreatedDate is days/weeks old)

**Typical Root Causes:**
- SSIS parameter not mapped to OLE DB Source query WHERE clause
- NULL or empty parameter value filters out all rows
- Date format mismatch (string vs datetime) in parameter comparison
- Source query uses hardcoded value instead of SSIS variable
- Missing row count validation to detect zero-row scenario

**Investigation Steps:**
1. Compare execution time to historical average (too fast = red flag)
2. Query source data to verify records exist for expected date/parameters
3. Query target table to confirm zero records created today
4. Check SSIS package parameter mapping in OLE DB Source Advanced Editor
5. Review PowerShell script parameter passing (e.g., `/set "\package.variables[RefDataSetDate].Value;$RefDataSetDate"`)
6. Open package in Visual Studio to inspect data flow query
7. Add Row Count transformation and validation Script Task

**Required Tools:**
- SSIS package source files (Visual Studio/SSDT access)
- PowerShell script that calls the package
- Source database query access (normalization views/tables)
- Target database query access (destination tables)
- Execution logs with timing information

**Recommended Skill:** `CheckSSISErrors.instructions.md` (see "Silent Success Failures" section)

**Resolution Patterns:**
- **Immediate:** Manual stored procedure insert to unblock users (emergency only)
- **Short-term:** Add PowerShell validation to fail job if row count = 0
- **Permanent:** Fix SSIS package parameter mapping and add row count validation

**Example Tickets:**
- GenericPushInstDebt.dtsx silent failure (2026-07-29): Package succeeded in 1.469 seconds but created 0 of 11,024 expected InstDebt records, causing 13-day data backlog

**Key Learning:** SSIS considers "processing zero rows" as success because no errors occur. Without explicit validation, these failures go undetected until users report missing data.

---

## 5. Portfolio/Fund Setup

### Category Definition
Tasks related to setting up new companies, portfolios, funds, or configuring entity relationships in MOS/CAMOS.

### Subcategories

#### 5.1 New Company Setup
**Description:** Creating a new client company with all required configuration

**Common Symptoms:**
- "Setup new company: [Company Name]"
- "New Solvas Portfolio for Citi Compliance"
- "Client DB setup"

**Typical Root Causes:**
- N/A - This is a standard setup task, not an issue

**Setup Steps:**
1. Create company record in `Employee.tCompany`
2. Create fund records
3. Create portfolio records and mappings
4. Configure price weighting rules
5. Setup cash rec configuration
6. Configure reporting parameters
7. Setup custodian connections/imports
8. Test data flows

**Required Database Tables:**
- `Employee.tCompany`
- `Core.dbo.tFund`
- `Core.dbo.tPortfolio`
- `Core.dbo.tCompanyPortfolioMap`
- `Core.dbo.tPositionPriceWeighting`
- Cash rec configuration tables

**Recommended Skill:** `SetupPortfolio.instructions.md`

**Example Tickets:**
- #71329: "Setup New Company: MidCap Financial Services"
- #72701: "New Solvas Portfolio for Citi Compliance - Shizen Funding Ldt."
- #72833: "Bryant Park Citi Master WH Ltd."

---

#### 5.2 Fund/Portfolio Mapping
**Description:** Mapping portfolios between systems or updating entity relationships

**Common Symptoms:**
- "Update Parent relationship"
- "Portfolio map updates"
- "Fund conversion"
- "Ledger portfolio map"

**Typical Root Causes:**
- Corporate actions (mergers, restructures)
- Name changes
- Fund type changes
- Organizational changes

**Investigation Steps:**
1. Identify source and target portfolios
2. Verify parent/child relationships
3. Check dependent mappings
4. Update portfolio maps
5. Verify data flows after change
6. Update reporting structures

**Recommended Skill:** `SetupPortfolio.instructions.md`

**Example Tickets:**
- #74027: "5) update Parent relationship in CA PEARL POINT CLO, LTD."
- #70535: "Update Ledger Portfolio map to only allow one ledger"

---

#### 5.3 Name Changes/Rebranding
**Description:** Changing names of companies, funds, or portfolios across systems

**Common Symptoms:**
- "Name Change: [Old Name] to [New Name]"
- "DW Name Change"
- "Solvas Name Change"

**Typical Root Causes:**
- Company rebranding
- Legal entity name changes
- Merger/acquisition
- Portfolio reorganization

**Investigation Steps:**
1. Identify all occurrences of old name
2. Update across all systems (Solvas, MOS, CAMOS, DW)
3. Update reporting
4. Update price configurations
5. Verify dependent systems updated

**Recommended Skill:** `SetupPortfolio.instructions.md`

**Example Tickets:**
- #73258: "Name Change: Project Quacker to APD Acquisitions Fund in MOS"
- #73492: "2) MOS DW Name Change: Pearl Point CLO, Ltd MOS to Garnet CLO 6"

---

## 6. Data Quality Issues

### Category Definition
Issues where data is present but incorrect, inconsistent, or doesn't meet quality standards.

### Subcategories

#### 6.1 Missing Identifiers
**Description:** Instruments or entities missing required identifiers (CUSIP, ISIN, Bloomberg, etc.)

**Common Symptoms:**
- "Instruments Missing Identifiers"
- "Incorrect Identifiers and Loans Missing Bloomberg"
- "Bad Identifiers on Assets"

**Typical Root Causes:**
- New instrument not yet in security master
- Identifier mapping missing
- Security master update lag
- Vendor doesn't provide identifier

**Investigation Steps:**
1. Identify instrument and missing identifier types
2. Check security master sources
3. Query vendor feeds
4. Manual research via Bloomberg/Refinitiv
5. Add identifiers manually if needed

**Required Database Queries:**
- `Core.dbo.vInst` - Instrument details
- `Reference.dbo.vInstIdentifierCurrent` - Identifiers
- `Reference.dbo.vInstIdentifierType` - Identifier types

**Recommended Skill:** `CheckDataQuality.instructions.md`

**Example Tickets:**
- #69622: "Instruments Missing Identifiers"
- #70669: "Bad Identifiers on Assets - Bloomberg IDs Not M..."
- #70673: "Incorrect Identifiers and Loans Missing Bloombe..."

---

#### 6.2 Duplicate Records
**Description:** Duplicate data in tables causing calculation or reporting errors

**Common Symptoms:**
- "Duplicate custodian portfolios"
- "Duplicate transactions"
- "Duplicate fund types created"

**Typical Root Causes:**
- Import logic error
- Missing deduplication logic
- Concurrent inserts
- Key collision

**Investigation Steps:**
1. Identify duplicate records and key fields
2. Determine source of duplicates
3. Review insert/update logic
4. Determine which record to keep
5. Remove duplicates safely
6. Add deduplication logic

**Recommended Skill:** `CheckDataQuality.instructions.md`

**Example Tickets:**
- #72293: "Remove Duplicate custodian portfoliotypes"
- #70709: "[Bug Report Triage] MOS - Duplicate Fund Types Created"

---

#### 6.3 Calculation Discrepancies
**Description:** Calculated values (market value, gain/loss, accruals) incorrect

**Common Symptoms:**
- "Traded cost calculation discrepancy"
- "TradedMV incorrect"
- "Realized gains/losses not aligned"
- "ABS Bond TradedQty not reflecting correctly"

**Typical Root Causes:**
- Formula error
- Missing factors
- Currency conversion issue
- Timing differences
- Rounding errors

**Investigation Steps:**
1. Identify calculation and expected result
2. Review calculation logic/stored procedure
3. Test with sample data
4. Verify all input values correct
5. Trace through calculation steps
6. Fix formula or data issue

**Recommended Skill:** `CheckDataQuality.instructions.md`

**Example Tickets:**
- #70727: "[Bug Report Triage] Diameter Traded Cost Calculation Discrepancy"
- #70725: "[Bug Report Triage] Diameter TradedMV Incorrect"
- #73096: "ABS Bond TradedQty not reflecting correctly"

---

#### 6.4 Reference Data Issues
**Description:** Master/reference data (issuers, legal entities, transaction types) incorrect

**Common Symptoms:**
- "Bad Issuer/Instrument Names"
- "Incorrect Legal Entity"
- "Transaction types too specific"

**Typical Root Causes:**
- Data entry errors
- system.object() not replaced
- Mapping errors
- Vendor data quality issues

**Investigation Steps:**
1. Identify incorrect reference data
2. Find source of error
3. Determine correct value
4. Update master data
5. Verify propagation to dependent systems

**Recommended Skill:** `CheckDataQuality.instructions.md`

**Example Tickets:**
- #70723: "[Bug Report Triage] MOS DW - Bad Issuer/Instrument Names"
- #70726: "[Bug Report Triage] MOS - Base Rate Issuers Have Incorrect Legal En..."
- #70694: "[Bug Report Triage] MOS - Solvas Transaction Types Too Specific"

---

## 7. Performance Issues

### Category Definition
Issues related to query performance, timeouts, slow procedures, or system resource problems.

### Subcategories

#### 7.1 Slow Query Issues
**Description:** Specific queries running slowly and causing timeouts or delays

**Common Symptoms:**
- "[Slow Query Triage] proc name - avg XXXms"
- "Query timeout"
- "Report taking too long to load"

**Typical Root Causes:**
- Missing indexes
- Table scans on large tables
- Parameter sniffing
- Outdated statistics
- Inefficient joins
- Large data volumes

**Investigation Steps:**
1. Capture actual execution plan
2. Identify expensive operations (scans, sorts, etc.)
3. Check index usage
4. Review table statistics
5. Analyze joins and filters
6. Test with different parameters
7. Optimize or add indexes

**Required Tools:**
- SQL Server Management Studio execution plans
- `sys.dm_exec_query_stats` - Query statistics
- `sp_BlitzIndex` - Index analysis
- SiepeAdmin performance monitoring tables

**Recommended Skill:** `OptimizePerformance.instructions.md`

**Example Tickets:**
- #72350: "[Slow Query Triage] adhoc:1bf679273aa5 ID-check"
- #72349: "[Slow Query Triage] adhoc:98f7fd08cc42 (SecMaster) - avg 47060ms"
- #72338: "[Slow Query Triage] dbo.pRefDataSetIU (Elmwood) - avg 72302ms"
- #69346: "[Slow Query Triage] solvas_am.pTransactionLoader (MOS) - avg 232509ms"

---

#### 7.2 Deadlock Issues
**Description:** Deadlocks occurring between concurrent processes

**Common Symptoms:**
- "Deadlock detected"
- "Transaction was deadlocked"
- "Deadlock victim"

**Typical Root Causes:**
- Lock order inconsistency
- Long-running transactions
- Missing indexes causing lock escalation
- Concurrent updates to same data

**Investigation Steps:**
1. Capture deadlock graph
2. Identify involved queries/processes
3. Analyze lock order
4. Review transaction isolation levels
5. Check for missing indexes
6. Redesign queries or add indexes

**Recommended Skill:** `OptimizePerformance.instructions.md`

---

#### 7.3 Timeout Issues
**Description:** Processes timing out before completion

**Common Symptoms:**
- "Command timeout"
- "Execution timeout"
- "Long-running query killed"

**Typical Root Causes:**
- Query too expensive
- Resource contention
- Blocking
- Parameter sniffing
- Large data set

**Investigation Steps:**
1. Identify timeout threshold
2. Measure actual execution time
3. Check for blocking
4. Review execution plan
5. Optimize query or increase timeout

**Recommended Skill:** `OptimizePerformance.instructions.md`

---

## 8. Integration/Feed Issues

### Category Definition
Issues with external data feeds, file imports, vendor integrations, and inter-system communications.

### Subcategories

#### 8.1 Vendor File Import Issues
**Description:** Vendor data files not importing correctly

**Common Symptoms:**
- "File delivery failure"
- "Import job failed"
- "Blank file detected"
- "File format changed"

**Typical Root Causes:**
- FTP/SFTP connection problems
- File delivery timing issues
- Format changes by vendor
- Network issues
- Credentials expired

**Investigation Steps:**
1. Check file delivery status
2. Verify FTP/SFTP connection
3. Review import job logs
4. Validate file format
5. Contact vendor if needed
6. Test import with sample file

**Required Tools:**
- FTP/SFTP logs
- Import job logs
- File validation utilities
- Vendor contact information

**Recommended Skill:** `CheckDataFeeds.instructions.md`

**Example Tickets:**
- #69951: "Identify failed Powershell and add BlankFile check"
- #71082: "FactSet - Weekend file with stale data"

---

#### 8.2 Solvas Integration Issues
**Description:** Data not flowing correctly from Solvas to MOS

**Common Symptoms:**
- "Solvas extract failed"
- "Position not feeding from Solvas"
- "Solvas import timeout"
- "Data refresh differences"

**Typical Root Causes:**
- Network connectivity issues
- Solvas database unavailable
- Extract query performance
- Data volume too large
- Schema changes in Solvas

**Investigation Steps:**
1. Test Solvas connectivity
2. Check Solvas database status
3. Review extract queries
4. Test sample data extraction
5. Check for recent Solvas changes

**Recommended Skill:** `CheckDataFeeds.instructions.md`

**Example Tickets:**
- #70724: "[Bug Report Triage] MOS/Solvas Data Refresh - Backdated Transaction..."
- #70672: "[Bug Report Triage] MOS Restructure Creating Data Differences"

---

#### 8.3 Custodian File Processing
**Description:** Custodian files (Citi, Northern Trust, State Street, etc.) not processing correctly

**Common Symptoms:**
- "Citi cash balances failing"
- "State Street holdings file issues"
- "JPM MMFs missing"
- "USBank transaction issues"

**Typical Root Causes:**
- File format changed
- New transaction types
- Timing issues
- Account mapping problems
- Currency conversion issues

**Investigation Steps:**
1. Review raw custodian file
2. Check normalization logic
3. Verify account mappings
4. Test with sample data
5. Contact custodian if format changed

**Recommended Skill:** `CheckDataFeeds.instructions.md`

**Example Tickets:**
- #69617: "Citi Cash Balances for 4/6 failing"
- #70558: "Request for support on State Street holdings file"
- #69407: "JPM MMFs Missing"

---

#### 8.4 Outbound Integration Issues
**Description:** Data not flowing correctly from MOS to downstream systems

**Common Symptoms:**
- "Outbound FTP not working"
- "Extract not generating"
- "Data not pushing to [System]"
- "Generic push failed"

**Typical Root Causes:**
- FTP/SFTP connection issues
- Extract logic error
- Missing data in source
- Format requirements changed

**Investigation Steps:**
1. Check outbound connection
2. Review extract query
3. Verify data availability
4. Test extract with sample
5. Verify destination system expectations

**Recommended Skill:** `CheckDataFeeds.instructions.md`

**Example Tickets:**
- #74078: "Garnet Credit Management Outbound FTP CDO Suite UAT Testing"
- #73215: "Test Outbound USBank-Garnet Transaction"

---

## 9. Workflow/Approval

### Category Definition
Issues related to business workflows, approval processes, locking mechanisms, and state management.

### Subcategories

#### 9.1 Cash Rec Approval Workflow
**Description:** Issues with cash reconciliation approval process

**Common Symptoms:**
- "Cannot approve cash rec"
- "Approval button disabled"
- "Workflow stuck"
- "State transition failed"

**Typical Root Causes:**
- Business rule violations
- Missing required data
- State machine error
- Permission issues
- Locking conflicts

**Investigation Steps:**
1. Check current workflow state
2. Review approval business rules
3. Verify required data present
4. Check user permissions
5. Review audit log for state changes

**Recommended Skill:** `CheckWorkflow.instructions.md`

**Example Tickets:**
- #74056: "Add ability to approve cash rec if there is a balance adjustment"
- #71392: "Remove Stale Balances Check for Approving Rec"

---

#### 9.2 Single Fund Refresh Workflow
**Description:** Issues with single fund refresh process and component management

**Common Symptoms:**
- "SFR workflow stuck"
- "Cannot start refresh"
- "Component dependencies failing"
- "Concurrent execution issues"

**Typical Root Causes:**
- Dependency chain broken
- State inconsistency
- Lock conflicts
- Timeout issues
- Missing prerequisites

**Investigation Steps:**
1. Check SFR status table
2. Review component dependencies
3. Verify prerequisite components complete
4. Check for locks
5. Review execution logs

**Recommended Skill:** `CheckWorkflow.instructions.md`

**Example Tickets:**
- #73109: "Review workflow with support / OPs"
- #70178: "Modify Balance Refresh / SFR Workflow"

---

#### 9.3 Record Locking Issues
**Description:** Issues with pessimistic locking and record state management

**Common Symptoms:**
- "Record locked by another user"
- "Cannot edit locked record"
- "Lock not released"
- "SOX locking issues"

**Typical Root Causes:**
- Stale locks not cleaned up
- User session ended without unlock
- Locking logic error
- Concurrent access conflicts

**Investigation Steps:**
1. Identify locked record
2. Check lock holder
3. Verify if lock is stale
4. Review lock cleanup logic
5. Release lock if appropriate

**Recommended Skill:** `CheckWorkflow.instructions.md`

---

## 10. Database Schema Changes

### Category Definition
Planned database releases including new tables, stored procedures, views, and schema modifications.

### Subcategories

#### 10.1 Stored Procedure Updates
**Description:** Creating or updating stored procedures

**Common Symptoms:**
- "Deploy Stored Procedure to [Environment]"
- "Update [ProcName] for [Feature]"
- "Create [NewProc]"

**Typical Root Causes:**
- N/A - This is a planned change, not an issue

**Development Steps:**
1. Write/update stored procedure code
2. Test in development environment
3. Review with team
4. Create database release work item
5. Deploy to staging
6. Test in staging
7. Deploy to production
8. Verify in production

**Required Artifacts:**
- Stored procedure definition file
- Unit test results
- Code review approval
- Deployment script

**Recommended Skill:** `ReviewSchemaChange.instructions.md`

**Example Tickets:**
- Hundreds of "Database Release" work items
- Pattern: "2025-11-XX-[ObjectName] - [Environment]"

---

#### 10.2 Table Schema Changes
**Description:** Creating new tables or modifying existing table schemas

**Common Symptoms:**
- "Create Cash Rec Schema tables"
- "Add column to [TableName]"
- "Drop deprecated tables"

**Typical Root Causes:**
- N/A - This is a planned change, not an issue

**Development Steps:**
1. Design schema changes
2. Review with DB Schema Committee (DSC)
3. Create migration scripts
4. Test with sample data
5. Create rollback plan
6. Deploy to environments
7. Migrate data if needed
8. Verify data integrity

**Recommended Skill:** `ReviewSchemaChange.instructions.md`

**Example Tickets:**
- #72246: "Create Cash Rec Schema tables and IU / Views"
- #72248: "Drop / Deprecate old tables"

---

#### 10.3 View/Function Updates
**Description:** Creating or updating views and user-defined functions

**Common Symptoms:**
- "Create view [ViewName]"
- "Update function [FunctionName]"
- "Normalization view changes"

**Typical Root Causes:**
- N/A - This is a planned change, not an issue

**Development Steps:**
1. Write/update view or function
2. Test logic with sample data
3. Verify performance
4. Review with team
5. Deploy to environments
6. Verify dependent objects still work

**Recommended Skill:** `ReviewSchemaChange.instructions.md`

---

## 11. Dashboard/Report Management

### Category Definition
Tasks related to managing reports and dashboards in AdminTools, including Process Dashboard (Operations Dashboard) report configuration, removal, and maintenance.

### Key Characteristics
- **Context:** Administrative changes to dashboard configurations
- **Scope:** Individual or bulk report management
- **Risk:** Low to medium (soft deletes, reversible)
- **Frequency:** ~15 tickets/year

### Confidence Scoring for Category 11

**High Confidence (90-100%):**
- Ticket contains: "process dashboard" + ("delete" OR "remove")
- Ticket contains: "operations dashboard" + "report"
- Ticket contains: "editors" + "process dashboard" + specific report name

**Medium Confidence (60-89%):**
- Ticket contains: "dashboard report" + action verb
- Ticket contains: "decommission" + "report"
- Ticket mentions AdminTools + report management

**Low Confidence (30-59%):**
- Generic "report" mention without dashboard context
- Unclear whether it's Process Dashboard or other dashboard type

**Keyword Match Examples:**
- ✅ "Remove Cashflow reports from Process Dashboard" → 95% confidence
- ✅ "Delete dashboard report in AdminTools" → 85% confidence
- ⚠️ "Update report configuration" → 40% confidence (could be SSRS, PowerBI, etc.)
- ❌ "Generate monthly report" → 5% confidence (not dashboard management)

### Subcategories

#### 11.1 Report Removal (Decommissioning)
**Description:** Soft-delete reports from Process Dashboard when they are no longer needed

**Common Symptoms:**
- "Delete [ReportName] from Process Dashboard"
- "Remove Cashflow reports"
- "Clean up old dashboard reports"
- "Decommission [ProcessName] reports"

**Typical Root Causes:**
- Process change (reports no longer relevant)
- Duplicate reports exist
- Report replaced by new version
- Client-specific cleanup requests

**Investigation Steps:**
1. Validate keyword specificity (domain-specific term required)
2. Query database to find matching reports
3. Verify match count ≤ 10 (safety threshold)
4. Review all matching reports for false positives
5. **EXECUTE** soft delete via `pDashboardReportD` stored procedure (agent capability)
6. Verify deletion completed (RefRecStatusID = 0)
7. Document removed reports in investigation report
8. Post results to ADO ticket

**Agent Execution:** Agent will automatically execute the stored procedure after validation checks pass.

**Required Database Queries:**
```sql
-- Find reports by keyword (case-insensitive)
SELECT DashboardReportID, DashboardID, Title, StatusProc, CreatedDate, CreatedUser
FROM [Core].[Process].[tDashboardReport]
WHERE LOWER(Title) LIKE LOWER('%{keyword}%')
  AND RefRecStatusID = 1;

-- Soft-delete report
EXEC [Core].[Process].[pDashboardReportD]
    @DashboardReportID = {reportId},
    @Login = '{username}';
```

**Safety Requirements:**
- ⚠️ Keyword must be domain-specific (e.g., "Cashflow", "Reconciliation")
- ❌ Generic keywords rejected (e.g., "Report", "Daily", "Data")
- ⚠️ Automatic STOP if > 10 reports match
- ✅ All matches reviewed manually before deletion
- ✅ Soft delete only (RefRecStatusID = 0, audit preserved)

**Manual Alternative:**
- Navigate to: https://mos-tools-p.mos.siepe.local/ProcessDashboard#!/
- Path: Editors → Process Dashboard
- Click "Delete Report" button on target report

**Recommended Skill:** `remove-process-dashboard-reports\SKILL.md`

**Example Tickets:**
- #82117: "Remove Cashflow reports from Citi Trustee and MOS Process Dashboard"

**Resolution Time:** 10-30 minutes
- Small (1-3 reports): 10 minutes
- Medium (4-10 reports): 20 minutes
- Requires approval: +10 minutes

---

#### 11.2 Report Configuration Changes
**Description:** Modify existing dashboard report settings, sort order, or properties

**Common Symptoms:**
- "Update report sort order"
- "Change report title"
- "Modify status procedure"
- "Reorder dashboard reports"

**Typical Root Causes:**
- Business process changes
- User experience improvements
- Report consolidation
- Naming convention updates

**Investigation Steps:**
1. Identify report to modify (ID or title)
2. Review current configuration
3. Apply requested changes via UI or stored procedure
4. Verify changes saved
5. Test report display in dashboard

**Required Database Access:**
- `[Core].[Process].[tDashboardReport]` - Report configuration
- `[Core].[Process].[pProcessesIU]` - Bulk update stored procedure

**Manual Method:**
- Navigate to AdminTools Process Dashboard editor
- Locate report in process
- Edit properties via UI
- Save changes

**Recommended Skill:** `remove-process-dashboard-reports\SKILL.md` (adapted for updates)

**Resolution Time:** 5-15 minutes

---

#### 11.3 New Report Creation
**Description:** Add new reports to Process Dashboard

**Common Symptoms:**
- "Add new report to dashboard"
- "Create [ReportName] in Process Dashboard"
- "Set up dashboard for new process"

**Typical Root Causes:**
- N/A - This is a planned change

**Development Steps:**
1. Define report title and description
2. Identify or create status stored procedure
3. Add report via AdminTools UI (Editors → Process Dashboard)
4. Configure actions if needed
5. Set sort order
6. Test report functionality
7. Verify in dashboard view

**Required Database Procedures:**
- `[Core].[Process].[pSubscriptionProcessReportI]` - Insert new report
- `[Core].[Process].[pProcessesIU]` - Bulk process update

**Resolution Time:** 15-30 minutes

---

## Field Definitions for Skill Mapping

### Core Fields

| Field Name | Description | Example Values |
|------------|-------------|----------------|
| **Title** | Brief description of issue | "Markit pricing not available", "Balance discrepancy" |
| **Category** | Primary category from taxonomy | "Market Pricing Issues", "Cash Reconciliation" |
| **Subcategory** | Specific issue type | "Missing Vendor Prices", "Balance Discrepancies" |
| **Priority** | Business priority | Critical, High, Medium, Low |
| **Urgency** | Time sensitivity | 1-High, 2-Medium, 3-Low |
| **Skill Required** | Recommended investigation skill | CheckMarketPrice, CheckCashReconciliation |
| **Database** | Primary database involved | Core, Reference, Feeds, CashRec, Solvas_AM |
| **System Component** | Affected system area | Pricing, Cash Rec, Positions, Transactions |

---

### Symptom Keywords

Use these keywords to quickly categorize tickets:

#### Market Pricing
- Price, pricing, markit, LSEG, ICE, sycamore, vendor, evaluated price, price exception, price weighting, missing price, wrong price

#### Cash Reconciliation
- Balance, cash rec, reconciliation, discrepancy, match, transaction, custodian, single fund refresh, SFR, approval

#### Data Normalization
- Normalization, transform, mapping, transaction type, custodian data, balance normalization, position normalization

#### SSIS/PowerShell
- SSIS, PowerShell, script task, package, import, file access, deadlock, timeout, OLE DB, pipeline

#### Portfolio Setup
- New company, setup, fund conversion, portfolio map, parent relationship, name change, configuration

#### Data Quality
- Missing identifier, duplicate, calculation error, incorrect, data quality, bad data, Bloomberg, CUSIP, ISIN

#### Performance
- Slow query, timeout, deadlock, performance, blocking, lock, execution plan

#### Integration/Feeds
- Import, file, feed, vendor, FTP, SFTP, delivery, extract, Solvas integration, custodian file

#### Workflow
- Approval, workflow, lock, state, SOX, single fund refresh status, component

#### Schema Changes
- Database release, stored procedure, table, view, function, schema, deployment

#### Dashboard/Report Management
- Process dashboard, operations dashboard, delete report, remove report, dashboard report, decommission report, editors, AdminTools configuration, report removal, cashflow report

---

## Skill Assignment Matrix

| Category | Primary Skill | Secondary Skills | Investigation Priority |
|----------|--------------|------------------|----------------------|
| Market Pricing Issues | CheckMarketPrice | CheckDataFeeds, CheckDataQuality | High |
| Cash Reconciliation | CheckCashReconciliation | CheckWorkflow, CheckDataNormalization | Critical |
| Data Normalization | CheckDataNormalization | CheckDataFeeds, CheckDataQuality | Medium |
| SSIS/PowerShell Errors | CheckSSISErrors | CheckDataFeeds, OptimizePerformance | High |
| Portfolio/Fund Setup | SetupPortfolio | CheckDataNormalization | Medium |
| Data Quality Issues | CheckDataQuality | CheckDataNormalization, CheckDataFeeds | Medium |
| Performance Issues | OptimizePerformance | CheckSSISErrors | High |
| Integration/Feed Issues | CheckDataFeeds | CheckSSISErrors, CheckDataNormalization | High |
| Workflow/Approval | CheckWorkflow | CheckCashReconciliation | Medium |
| Database Schema Changes | ReviewSchemaChange | N/A | Low |
| Dashboard/Report Management | RemoveProcessDashboardReports | N/A | Medium |

---

## Decision Tree for Skill Selection

```
START: New ticket arrives
│
├─ Contains "price", "pricing", "markit", "LSEG"?
│  └─ YES → CheckMarketPrice.instructions.md
│
├─ Contains "balance", "cash rec", "reconciliation"?
│  └─ YES → CheckCashReconciliation.instructions.md
│
├─ Contains "SSIS", "PowerShell", "script task", "package"?
│  └─ YES → CheckSSISErrors.instructions.md
│
├─ Contains "slow query", "timeout", "deadlock", "performance"?
│  └─ YES → OptimizePerformance.instructions.md
│
├─ Contains "normalization", "transform", "mapping"?
│  └─ YES → CheckDataNormalization.instructions.md
│
├─ Contains "import", "file", "feed", "FTP", "vendor"?
│  └─ YES → CheckDataFeeds.instructions.md
│
├─ Contains "new company", "setup", "fund conversion"?
│  └─ YES → SetupPortfolio.instructions.md
│
├─ Contains "approval", "workflow", "lock", "SOX"?
│  └─ YES → CheckWorkflow.instructions.md
│
├─ Contains "missing identifier", "duplicate", "calculation error"?
│  └─ YES → CheckDataQuality.instructions.md
│
├─ Contains "process dashboard", "operations dashboard", "delete report", "remove report"?
│  └─ YES → remove-process-dashboard-reports\SKILL.md
│
└─ WorkItemType = "Database Release"?
   └─ YES → ReviewSchemaChange.instructions.md
```

---

## Usage Examples

### Example 1: Market Pricing Ticket

**Ticket #82115:** "FW: Aristotle - Enhanced Pricing Report Daily - 2026/07/01"  
**Description:** Client is asking for confirmation on whether Markit Pricing was not available for that day

**Classification:**
- **Category:** Market Pricing Issues
- **Subcategory:** Missing Vendor Prices
- **Skill:** CheckMarketPrice.instructions.md
- **Priority:** High
- **Database:** Core, Reference

**Investigation Steps:**
1. Extract company name: Aristotle → CompanyID 500000006
2. Extract date: 2026-07-01 → PriorDate 2026-06-30
3. Extract identifier from attached report: CUSIP 83408EAA1
4. Execute CheckMarketPrice skill 5-step process
5. Generate analysis report
6. Provide client response

---

### Example 2: Cash Reconciliation Ticket

**Ticket #70176:** "Prior Day Balance Discrepancies in Cash Rec - SQL Updates"

**Classification:**
- **Category:** Cash Reconciliation
- **Subcategory:** Balance Discrepancies
- **Skill:** CheckCashReconciliation.instructions.md
- **Priority:** Critical
- **Database:** CashRec, Core

**Investigation Steps:**
1. Identify portfolio and account
2. Compare custodian vs. MOS balances
3. Review transaction history
4. Check import timing
5. Analyze discrepancy source
6. Provide resolution

---

### Example 3: Performance Ticket

**Ticket #72338:** "[Slow Query Triage] dbo.pRefDataSetIU (Elmwood) - avg 72302ms"

**Classification:**
- **Category:** Performance Issues
- **Subcategory:** Slow Query Issues
- **Skill:** OptimizePerformance.instructions.md
- **Priority:** High
- **Database:** Core, Reference

**Investigation Steps:**
1. Capture execution plan
2. Identify expensive operations
3. Analyze index usage
4. Review statistics
5. Optimize query or add indexes
6. Test performance improvement

---

### Example 4: Dashboard/Report Management Ticket

**Ticket #82117:** "Remove Cashflow reports from Citi Trustee and MOS Process Dashboard"  
**Description:** For manual process in admin tools under Citi trustee and MOS go to the Editors>>Process Dashboard and delete reports with the keyword "Cashflow" report

**Classification:**
- **Category:** Dashboard/Report Management
- **Subcategory:** Report Removal (Decommissioning)
- **Skill:** remove-process-dashboard-reports\SKILL.md
- **Confidence:** 95% (High - "process dashboard" + "delete" + domain-specific keyword "Cashflow")
- **Priority:** Medium
- **Database:** Core (Process schema)

**Confidence Scoring Breakdown:**
- ✅ Contains "Process Dashboard": +30%
- ✅ Contains "Editors": +10%
- ✅ Contains "delete reports": +30%
- ✅ Domain-specific keyword "Cashflow": +25%
- **Total:** 95% confidence (High)

**Investigation Steps:**
1. Validate keyword "Cashflow" (domain-specific ✅, not generic like "Report")
2. Query Citi Trustee database for matching reports
3. Query MOS database for matching reports
4. Verify match count < 10 (safety threshold)
5. Review all reports for false positives
6. Execute soft delete via stored procedure
7. Verify deletion (RefRecStatusID = 0)
8. Generate investigation report
9. Post results to ADO ticket

**Resolution:**
- Citi Trustee: 3 reports soft-deleted (executed by agent)
- MOS: 2 reports soft-deleted (executed by agent)
- Total: 5 reports removed via stored procedure
- Audit trail preserved
- Resolution time: 15 minutes (fully automated)

---

## Appendix A: Available Skills

### ✅ Production Skills (Ready to Use)

#### CheckMarketPrice.instructions.md
**Status:** ✅ **PRODUCTION READY**  
**Location:** `C:\source\MD\AdminTools\Skills\CheckMarketPrice.instructions.md`  
**Category:** Market Pricing Issues (Category 1)  
**Version:** 1.0  
**Created:** 2026-07-01

**Covers:**
- Missing vendor prices investigation
- Price source priority/weighting analysis
- Vendor coverage gaps
- Price selection logic diagnosis
- Root cause identification for pricing discrepancies

**Key Features:**
- 5-step systematic investigation process
- Automated SQL query generation
- Markdown report output
- ADO ticket comment formatting
- Database: MOS Production (mos-sql-p.mos.siepe.local,52155)

**Inputs Required:**
- Company name or ID
- Price date (investigates T-1)
- Instrument identifier (CUSIP/ISIN/LoanX ID)

**Output:**
- Detailed markdown analysis report: `CheckMarketPrice-{CUSIP}-{Date}.md`
- Root cause analysis with resolution recommendations
- Formatted ADO comment ready to paste

**Example Tickets Resolved:**
- #82115: "FW: Aristotle - Enhanced Pricing Report Daily - 2026/07/01"
- Successfully diagnosed Markit coverage gap, LSEG fallback usage

**Usage:**
```
When ticket mentions: price, pricing, markit, LSEG, ICE, vendor, 
evaluated price, price exception, price weighting, missing price
→ Apply CheckMarketPrice skill
```

---

#### CheckSSISErrors.instructions.md
**Status:** ✅ **PRODUCTION READY**  
**Location:** `.github/skills/check-ssis-errors/SKILL.md`  
**Category:** SSIS/PowerShell Errors (Category 4)  
**Version:** 1.0  
**Created:** 2026-07-01

**Covers:**
- SSIS pipeline error diagnosis
- Script Task exceptions (IndexOutOfRange, null reference)
- Lookup component failures (0xC004701A)
- OLE DB errors (0x80004005, 0xC0202009)
- Schema mismatch detection
- Pre-execute phase failures

**Key Features:**
- Error code pattern matching
- Component-level troubleshooting
- Root cause identification
- Resolution recommendations
- Historical error tracking

**Inputs Required:**
- Error message or error code
- Package name
- Execution timestamp
- Environment (MOS, CitiTrustee, etc.)

**Output:**
- Error analysis with root cause
- Step-by-step resolution guide
- Prevention recommendations

**Example Tickets Resolved:**
- #72342: CitiTrustee SSIS Script Task index out of range
- #73644: MOS SSIS LegalEntityIdentifierType pipeline error
- #70811: Ledger Balance SSIS InstID lookup failure

**Usage:**
```
When ticket mentions: SSIS, PowerShell, script task, package error, 
pipeline, ETL, integration services, lookup failure
→ Apply CheckSSISErrors skill
```

---

#### RemoveProcessDashboardReports\SKILL.md
**Status:** ✅ **PRODUCTION READY**  
**Location:** `.github/skills/remove-process-dashboard-reports/SKILL.md`  
**Category:** Dashboard/Report Management (Category 11)  
**Version:** 1.0  
**Created:** 2026-07-06

**Covers:**
- Soft-delete reports from Process Dashboard
- Keyword-based report identification with validation
- Batch report removal
- Safety threshold enforcement (≤10 reports)
- Domain-specific keyword validation

**Key Features:**
- ⚠️ Domain-specific keyword validation (rejects generic terms)
- ⚠️ Safety threshold (auto-stops if >10 matches)
- ✅ Pre-deletion review checklist
- ✅ Soft delete only (RefRecStatusID = 0, reversible)
- ✅ Audit trail preservation
- SQL and manual UI methods documented

**Safety Rules:**
- ✅ Accepts domain-specific keywords: "Cashflow", "Reconciliation", "Attribution"
- ❌ Rejects generic keywords: "Report", "Daily", "Data", "Summary"
- ⚠️ Stops if keyword matches > 10 reports
- ✅ All matches reviewed manually before deletion

**Inputs Required:**
- Database/environment (MOS, CitiTrustee, etc.)
- Domain-specific keyword or exact report title
- Approval from ticket requester

**Output:**
- Investigation report with keyword validation
- List of reports soft-deleted (IDs and titles)
- Verification queries showing RefRecStatusID = 0
- ADO-ready comment

**Confidence Scoring:**
- **High (90-100%):** "process dashboard" + "delete" + domain keyword
- **Medium (60-89%):** "dashboard report" + action verb
- **Low (30-59%):** Generic "report" mention without context

**Example Tickets Resolved:**
- #82117: "Remove Cashflow reports from Citi Trustee and MOS Process Dashboard"
  - Confidence: 95% (High)
  - 5 reports soft-deleted (3 CitiTrustee, 2 MOS)
  - Resolution time: 15 minutes

**Database:**
- `[Core].[Process].[tDashboardReport]` - Report configuration
- `[Core].[Process].[pDashboardReportD]` - Soft delete stored procedure

**Manual Method:**
- AdminTools: https://mos-tools-p.mos.siepe.local/ProcessDashboard#!/
- Path: Editors → Process Dashboard → Delete Report button

**Usage:**
```
When ticket mentions: process dashboard, operations dashboard, 
delete report, remove report, decommission report
→ Apply RemoveProcessDashboardReports skill
Confidence scoring: Check for domain-specific keywords
```

---

## Appendix B: Skill Development Roadmap

### Phase 1: Core Investigation Skills (Current)
- [x] **CheckMarketPrice.instructions.md** ← **✅ COMPLETE (2026-07-01)**
- [x] **CheckSSISErrors.instructions.md** ← **✅ COMPLETE (2026-07-01)**
- [x] **RemoveProcessDashboardReports\SKILL.md** ← **✅ COMPLETE (2026-07-06)**
- [ ] CheckCashReconciliation.instructions.md ← **NEXT PRIORITY**
- [ ] CheckDataNormalization.instructions.md

### Phase 2: Specialized Skills
- [ ] OptimizePerformance.instructions.md
- [ ] CheckDataFeeds.instructions.md
- [ ] CheckDataQuality.instructions.md

### Phase 3: Configuration Skills
- [ ] SetupPortfolio.instructions.md
- [ ] CheckWorkflow.instructions.md
- [ ] ReviewSchemaChange.instructions.md

---

## Appendix B: Common Database Objects

### Core Database
- `Employee.vCompany` - Company master
- `Core.dbo.vInst` - Instrument master
- `Core.dbo.vPositionRaw` - Position data
- `Core.dbo.vPositionPriceWeightingActive` - Price weighting config
- `Core.dbo.vRefDataSetActive` - Data refresh tracking

### Reference Database
- `Reference.dbo.vInstPriceCurrentRaw` - Vendor prices
- `Reference.dbo.vInstIdentifierCurrent` - Instrument identifiers
- `Reference.dbo.vRefDataSourceRaw` - Data sources
- `Reference.dbo.vRefDataImportCurrent` - Import logs

### CashRec Database
- `CashRec.vBalance` - Cash balances
- `CashRec.vTransaction` - Cash transactions
- `CashRec.vMatchGroups` - Match logic

### Custodian Views
- `Custodian.vCitiBalances` - Citi balance normalization
- `Custodian.vCitiTransactionNormalization` - Citi transaction normalization
- Similar patterns for NT, StateStreet, USBank, JPM

---

## Appendix C: Contact Information

### Support Escalation
- **MOS Support Team:** MOS-Support@siepe.com
- **DBA Team:** DBA@siepe.com
- **Ops Team:** Operations@siepe.com

### Vendor Contacts
- **Markit/IHS Markit:** pricing-support@ihsmarkit.com
- **LSEG/Refinitiv:** support@lseg.com
- **ICE Data Services:** support@ice.com
- **Sycamore:** support@sycamoregrp.com

---

**Document Version:** 1.1  
**Last Updated:** 2026-07-06  
**Maintained By:** Back Office SQL Engineers Team  
**Next Review:** 2026-10-01

**Change Log:**
- v1.1 (2026-07-06): Added Category 11 (Dashboard/Report Management) with confidence scoring
- v1.0 (2026-07-01): Initial taxonomy creation
