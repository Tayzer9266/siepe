-- ================================================================
-- Price Override Workflow Queries
-- Database: MOS Production (mos-sql-p.mos.siepe.local,52155) & Solvas_AM
-- Reference: C:\source\MD\AdminTools\.github\skills\price-overrides\SKILL.md
-- ================================================================

-- ================================================================
-- OVERVIEW: PRICE OVERRIDE METHODS
-- ================================================================
/*
Three Methods for Price Overrides:

Method 1: Manual Solvas Stored Procedure Execution (This file)
    - Direct execution of deal_*_market_value_del and deal_*_market_value_put
    - For ad-hoc overrides, retroactive backfills, and complex multi-portfolio scenarios
    - Requires manual identification of entity_id, issue_id/facility_id, and portfolio combinations

Method 2: MOS Operations Portal (GUI)
    - Portal: https://mos-portal-p.mos.siepe.local/
    - For simple one-time or temporary overrides
    - User-friendly interface for operations team
    - Limited to forward-dated overrides

Method 3: Automated CSV Import via Email (Recommended for Bulk)
    - Send email to: MOSData@Siepe.com
    - Email Subject: "MOS Ops Price Overrides yyyyMMdd" (e.g., "MOS Ops Price Overrides 20260630")
    - File Attachment: "MOSOpsPriceOverrides_yyyyMMdd.csv"
    - Generic Import Job ID: 2350
    - Generic Normalization Job IDs: 164
        - Feeds.MOS.vMOSOpsPriceOverridesInstRefNormalization
        - Feeds.MOS.vMOSOpsPriceOverridesInstPricingRefNormalization
    - Auto-ingested and processed
    - Request refresh via email to MOS Support after confirmation

Vendor Price Mapping Configuration:
    SELECT * 
    FROM reference.dbo.vInstArbitrationRefDataSourceConfigRaw  
    WHERE RefDataSourceID = 1000000168;

Documentation:
    https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/6226/MOS-Ops-Price-Overrides
*/


-- ================================================================
-- EXAMPLE DATA (For Reference)
-- ================================================================
/*
Override Date: 6/30/2026

CUSIP/LX ID | Override Price | InstID     | Notes
----------- | -------------- | ---------- | -----
68610BAA2   | 30.4375        | 500016222  | 
15477CAA3   | 65.0000        | 500010629  | Still updating
LX232483    | 66.0000        | 500009880  | 
*/


-- ================================================================
-- STEP 1: IDENTIFY INSTRUMENT AND PORTFOLIO INFORMATION
-- ================================================================
-- Purpose: Lookup InstID, InstIdentifierID, and Portfolio IDs by CUSIP/LoanX ID
-- Use Case: Start of every price override workflow

-- ----------------------------------------
-- 1a. Get Inst IDs by CUSIP/ISIN/LoanX ID
-- ----------------------------------------
SELECT 
    instidentifierid, 
    instid, 
    value AS Identifier,
    InstIdentifierType
FROM core.dbo.vinstidentifiercurrent 
WHERE value = '68610BAA2';                          -- Replace with CUSIP/ISIN/LoanX ID

-- Search by InstID (if already known)
SELECT 
    instidentifierid, 
    instid, 
    value AS Identifier,
    InstIdentifierType
FROM core.dbo.vinstidentifiercurrent 
WHERE instid = '500020862';                         -- Replace with InstID


-- ----------------------------------------
-- 1b. Search by Deal/Security Name (If CUSIP Unknown)
-- ----------------------------------------
-- Find InstID by security name
SELECT 
    ID AS instid, 
    Name AS SecurityName
FROM Client.ivInstCurrent 
WHERE Name LIKE '%Kleopatra%'                       -- Replace with security name pattern
ORDER BY Name;


-- ----------------------------------------
-- 1c. Search Portfolios by Name
-- ----------------------------------------
SELECT 
    id AS portfolioid,
    Name AS PortfolioName
FROM Client.ivPortfolioCurrent 
WHERE Name LIKE '%Trestles%'                        -- Replace with portfolio pattern
ORDER BY Name;


-- ----------------------------------------
-- 1d. Get Entity ID from Solvas by Deal Name
-- ----------------------------------------
SELECT 
    entity_id, 
    deal_name,
    deal_status
FROM Solvas_AM.dbo.entity 
WHERE deal_name LIKE '%Trestles CLO%'               -- Replace with deal name pattern
ORDER BY deal_name;


-- ----------------------------------------
-- 1e. Get CUSIP Numbers by Deal Name (Multiple Portfolios)
-- ----------------------------------------
SELECT 
    ev.cusip_number,
    ev.lx_identifier,
    ev.issue_name,
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value_indent
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE e.deal_name IN (
    'Aristotle Funds Series Trust - Aristotle Floating Rate Income Fund',
    'Aristotle Funds Series Trust - Aristotle High Yield Bond Fund',
    'Goldman Sachs Trust II: Goldman Sachs Multi-Manager Non-Core Fixed Income Fund',
    'Indiana University Health, Inc.',
    'MissionSquare PLUS Fund, a stable value fund of VantageTrust III Master Collective Investment Fund (Loan)',
    'Pacific Asset Management Bank Loan Fund L.P.',
    'Pacific Life Insurance Company: PL APC Credit Opportunities Portfolio',
    'Pacific Select Fund - Floating Rate Income Portfolio',
    'Pacific Select Fund - High Yield Bond Portfolio',
    'Water and Power Employees Health Benefits Fund',
    'Water and Power Employees Retirement Plan'
)
AND d.begin_date >= '2026-06-30'                    -- Replace with target date
ORDER BY e.deal_name, ev.cusip_number, d.begin_date;


-- ----------------------------------------
-- 1f. Check Historical Overrides (Log Table)
-- ----------------------------------------
SELECT 
    ev.cusip_number,
    ev.lx_identifier,
    e.deal_name,
    d.begin_date,
    d.end_date,
    d.market_value_indent,
    d.created_by,
    d.last_update_date
FROM solvas_am.dbo.deal_issue_market_value_log d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE e.deal_name IN (
    'Aristotle Funds Series Trust - Aristotle High Yield Bond Fund'
)
AND ev.cusip_number IN ('LX232483')                 -- Replace with CUSIP
AND d.begin_date >= '2026-07-13 00:00:00'           -- Replace with start date
ORDER BY d.begin_date DESC;


-- ================================================================
-- STEP 2: CHECK AND APPLY TAG MAPPING (EXCLUDE FROM VENDOR PRICING)
-- ================================================================
-- Purpose: Tag instruments to exclude from automated vendor pricing
-- Tag ID 5: "Exclude from Vendor Pricing" (prevents automated price updates)

-- ----------------------------------------
-- 2a. Check if Tag Mapping Already Exists
-- ----------------------------------------
SELECT 
    portfolioId,
    instid,
    tagid,
    EffFromDate,
    EffThruDate
FROM core.dbo.vTagMapActive 
WHERE tagid = 5                                     -- Tag 5 = Exclude from Vendor Pricing
    AND instid = '500016222';                       -- Replace with InstID

-- ✅ If data exists for the portfolio: Skip Step 2b (already tagged)
-- ❌ If no data exists: Proceed to Step 2b to create tag mapping


-- ----------------------------------------
-- 2b. Create Tag Mapping (If Missing)
-- ----------------------------------------
-- Execute for EACH PortfolioID that needs exclusion from vendor pricing

-- Example: Tag single portfolio
EXEC core.dbo.pTagMapI 
    @Tagid = 5,                                     -- Tag 5 = Exclude from Vendor Pricing
    @InstID = '500010629',                          -- Replace with InstID from Step 1
    @PortfolioID = '500000099',                     -- Replace with PortfolioID
    @EffFromDate = 'June 30 2026 12:00AM';          -- Replace with override date

-- Example: Tag multiple portfolios (run separately for each)
EXEC core.dbo.pTagMapI 
    @Tagid = 5, 
    @InstID = '500010629', 
    @PortfolioID = '500000143', 
    @EffFromDate = '2026-06-30';

-- Note: Run one EXEC per portfolio. Repeat for all affected portfolios.


-- ================================================================
-- STEP 3: DETERMINE SECURITY TYPE (BOND, LOAN, OR EQUITY)
-- ================================================================
-- Purpose: Identify if the CUSIP is a Bond, Loan, or Equity to use correct stored procedure

-- ----------------------------------------
-- 3a. Check if Bond (deal_issue_market_value)
-- ----------------------------------------
-- If this query returns results, it's a BOND
SELECT 
    ev.cusip_number,
    ev.issue_name,
    d.issue_id,
    e.entity_id,
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value_indent
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE ev.cusip_number IN ('15477CAA3')              -- Replace with CUSIP
    AND d.begin_date >= '2026-06-30'                -- Replace with override date
ORDER BY e.deal_name, d.begin_date;

-- Alternative: Search by deal name for bonds
SELECT 
    ev.cusip_number,
    ev.issue_name,
    d.issue_id,
    e.entity_id,
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value_indent
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE e.deal_name LIKE 'Kleopatra Finco%'           -- Replace with deal pattern
    AND d.begin_date >= '2026-06-30'
ORDER BY e.deal_name, d.begin_date;


-- ----------------------------------------
-- 3b. Check if Loan (deal_facility_market_value)
-- ----------------------------------------
-- If this query returns results, it's a LOAN
SELECT 
    ev.LX_identifier,
    ev.issue_name,
    d.facility_id,
    e.entity_id,
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.pricing_type_1
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ('LX232483')              -- Replace with LoanX ID
    AND d.begin_date >= '2026-06-30'                -- Replace with override date
ORDER BY e.deal_name, d.begin_date;

-- Alternative: Search by deal name for loans
SELECT 
    ev.LX_identifier,
    ev.issue_name,
    d.facility_id,
    e.entity_id,
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.pricing_type_1
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE e.deal_name IN (
    'APC Asset Development II, LP',
    'Aristotle Funds Series Trust - Aristotle Core Income Fund',
    'Aristotle Funds Series Trust - Aristotle Floating Rate Income Fund',
    'Trestles CLO V, Ltd MOS',
    'Trestles CLO VI, Ltd MOS',
    'Trestles CLO VII, Ltd MOS',
    'Trestles CLO VIII, Ltd MOS',
    'Trestles CLO X, Ltd MOS',
    'Water and Power Employees Health Benefits Fund',
    'Water and Power Employees Retirement Plan'
)
AND d.begin_date >= '2026-06-30'
ORDER BY e.deal_name, d.begin_date;


-- ----------------------------------------
-- 3c. Check if Equity (deal_equity_market_value)
-- ----------------------------------------
-- If this query returns results, it's an EQUITY
SELECT TOP 100 
    d.entity_id, 
    d.equity_id,
    ev.issue_name,
    e.deal_name,
    d.begin_date,
    d.end_date,
    d.market_value
FROM solvas_am.dbo.deal_equity_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.equity_id 
    AND ev.entity_id = e.entity_id
WHERE e.deal_name IN (
    'Trestles CLO 2017-1, Ltd MOS',
    'Trestles CLO II, Ltd MOS',
    'Trestles CLO III, Ltd MOS',
    'Trestles CLO IV, Ltd MOS',
    'Trestles CLO V, Ltd MOS',
    'Trestles CLO VI, Ltd MOS',
    'Trestles CLO VII, Ltd MOS',
    'Trestles CLO VIII, Ltd MOS'
)
-- AND e.entity_id = 295                            -- Optional: Filter by specific entity
AND d.begin_date >= '2026-06-30 00:00:00'
ORDER BY d.equity_id, d.begin_date DESC;


-- ================================================================
-- STEP 4: GENERATE DELETE STATEMENTS (REMOVE EXISTING PRICES)
-- ================================================================
-- Purpose: Generate DELETE statements to remove existing prices before applying override
-- Note: Review generated statements before execution

-- ----------------------------------------
-- 4a. Bonds - Generate DELETE Statements by CUSIP
-- ----------------------------------------
SELECT 
    CONCAT('EXEC Solvas_am.dbo.deal_Issue_market_value_del',
        ' @user_id = ''tcnguyen''',                 -- Replace with your username
        ', @entity_id = ', d.entity_id,
        ', @issue_id = ', d.issue_id,
        ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.cusip_number, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value_indent
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE e.deal_name LIKE 'Kleopatra Finco%'           -- Replace with deal pattern
    AND d.begin_date >= '2026-06-30'                -- Replace with override date
ORDER BY e.deal_name, ev.cusip_number, d.begin_date;


-- ----------------------------------------
-- 4b. Bonds - Generate DELETE Statements by Issue ID
-- ----------------------------------------
SELECT 
    CONCAT('EXEC Solvas_am.dbo.deal_Issue_market_value_del',
        ' @user_id = ''tcnguyen''',                 -- Replace with your username
        ', @entity_id = ', d.entity_id,
        ', @issue_id = ', d.issue_id,
        ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.cusip_number, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value_indent
FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE d.issue_id = 62875                            -- Replace with issue_id
    AND d.begin_date >= '2026-06-30'
ORDER BY e.deal_name, ev.cusip_number, d.begin_date;


-- ----------------------------------------
-- 4c. Loans - Generate DELETE Statements by LoanX ID
-- ----------------------------------------
SELECT 
    CONCAT('EXEC Solvas_am.dbo.deal_facility_market_value_del',
        ' @user_id = ''tcnguyen''',                 -- Replace with your username
        ', @entity_id = ', d.entity_id,
        ', @facility_id = ', d.facility_id,
        ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.LX_identifier,
    ev.issue_name, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.pricing_type_1
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ('500016570')             -- Replace with LoanX ID
    AND e.deal_name IN (
        'APC Asset Development II, LP',
        'Aristotle Funds Series Trust - Aristotle Core Income Fund',
        'Aristotle Funds Series Trust - Aristotle Floating Rate Income Fund',
        'Trestles CLO VIII, Ltd MOS',
        'Trestles CLO X, Ltd MOS',
        'Water and Power Employees Health Benefits Fund',
        'Water and Power Employees Retirement Plan'
    )
    AND d.begin_date > '2026-06-30'                 -- Replace with override date
ORDER BY e.deal_name, d.begin_date;


-- ----------------------------------------
-- 4d. Loans - Generate DELETE Statements by Facility ID
-- ----------------------------------------
SELECT 
    CONCAT('EXEC Solvas_am.dbo.deal_facility_market_value_del',
        ' @user_id = ''tcnguyen''',                 -- Replace with your username
        ', @entity_id = ', d.entity_id,
        ', @facility_id = ', d.facility_id,
        ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.issue_name, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.pricing_type_1
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.facility_id = 62875                        -- Replace with facility_id
    AND e.deal_name IN (
        'Menard, Inc.',
        'COAST3 - Aristotle Pacific CLO Adviser III, LLC'
    )
    AND d.begin_date >= '2026-06-30'
ORDER BY e.deal_name, d.begin_date;


-- ----------------------------------------
-- 4e. Equities - Generate DELETE Statements by Deal Name
-- ----------------------------------------
-- Note: Equities require deleting EVERY DAY from override date to CURRENT DATE
SELECT 
    CONCAT('EXEC Solvas_am.dbo.deal_equity_market_value_del',
        ' @user_id = ''tcnguyen''',                 -- Replace with your username
        ', @equity_id = 233',                        -- Replace with equity_id (issue_id)
        ', @entity_id = ', d.entity_id,
        ', @begin_date = ''June 30 2026 12:00AM'''   -- Replace with override date
    ) AS execute_statement,
    d.deal_name,
    d.entity_id
FROM Solvas_AM.dbo.entity d
WHERE deal_name IN (
    'Trestles CLO 2017-1, Ltd MOS',
    'Trestles CLO II, Ltd MOS',
    'Trestles CLO III, Ltd MOS',
    'Trestles CLO IV, Ltd MOS',
    'Trestles CLO V, Ltd MOS',
    'Trestles CLO VI, Ltd MOS',
    'Trestles CLO VII, Ltd MOS',
    'Trestles CLO VIII, Ltd MOS'
)
ORDER BY d.deal_name;

-- Example: Manual DELETE for single equity
EXEC Solvas_am.dbo.deal_equity_market_value_del 
    @user_id = 'tcnguyen', 
    @equity_id = 233, 
    @entity_id = 295, 
    @begin_date = 'June 30 2026 12:00AM';

-- Example: Manual DELETE for bond
EXEC Solvas_am.dbo.deal_Issue_market_value_del  
    @user_id = 'tcnguyen',
    @entity_id = 244,
    @issue_id = 42326,
    @begin_date = 'Jun 30 2026 12:00AM';


-- ================================================================
-- STEP 5: GENERATE INSERT STATEMENTS (APPLY NEW OVERRIDE PRICES)
-- ================================================================
-- Purpose: Generate INSERT statements to apply new override prices
-- Note: Review generated statements before execution

-- ----------------------------------------
-- 5a. Loans - Generate INSERT Statements
-- ----------------------------------------
-- Manual execution template for loans
EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] 
    @user_id = 'tcnguyen',                          -- Replace with your username
    @row_version = NULL,
    @entity_id = 235,                               -- Replace with entity_id from Step 3
    @facility_id = 26478,                           -- Replace with facility_id from Step 3
    @begin_date = '2026-06-30',                     -- Replace with override date
    @end_date = NULL,
    @pricing_type_1 = 66.0000;                      -- Replace with override price

-- Example: Multiple portfolios (execute separately for each)
EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] 
    @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 241, @facility_id = 26478, @begin_date = '2026-06-30', @end_date = NULL, @pricing_type_1 = 66.0000;

EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] 
    @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 243, @facility_id = 26478, @begin_date = '2026-06-30', @end_date = NULL, @pricing_type_1 = 66.0000;


-- ----------------------------------------
-- 5b. Bonds - Generate INSERT Statements
-- ----------------------------------------
-- Generate INSERT statements by deal name and CUSIP
SELECT 
    CONCAT('EXEC Solvas_am.[dbo].[Deal_issue_market_value_put]',
        ' @user_id = ''tcnguyen''',                 -- Replace with your username
        ', @row_version = NULL',
        ', @entity_id = ', d.entity_id,
        ', @Issue_ID = 42175',                       -- Replace with issue_id from Step 3
        ', @begin_date = ''2026-06-30''',            -- Replace with override date
        ', @end_date = NULL',
        ', @market_value_indent = 65.0000'           -- Replace with override price
    ) AS exec_statement,
    ev.LX_identifier,
    ev.cusip_number, 
    e.deal_name, 
    d.begin_date, 
    d.end_date
FROM solvas_am.dbo.deal_issue_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE e.deal_name IN (
    'Aristotle Funds Series Trust - Aristotle Floating Rate Income Fund',
    'Aristotle Funds Series Trust - Aristotle High Yield Bond Fund',
    'Goldman Sachs Trust II: Goldman Sachs Multi-Manager Non-Core Fixed Income Fund',
    'Indiana University Health, Inc.',
    'MissionSquare PLUS Fund, a stable value fund of VantageTrust III Master Collective Investment Fund (Loan)',
    'Pacific Asset Management Bank Loan Fund L.P.',
    'Pacific Life Insurance Company: PL APC Credit Opportunities Portfolio',
    'Pacific Select Fund - Floating Rate Income Portfolio',
    'Pacific Select Fund - High Yield Bond Portfolio',
    'Water and Power Employees Health Benefits Fund',
    'Water and Power Employees Retirement Plan'
)
AND ev.cusip_number IN ('LX232483')                 -- Replace with CUSIP
AND d.begin_date >= '2026-06-30 00:00:00'
ORDER BY d.begin_date DESC;

-- Manual execution template for bonds
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] 
    @user_id = 'tcnguyen',                          -- Replace with your username
    @row_version = NULL,
    @entity_id = 244,                               -- Replace with entity_id from Step 3
    @Issue_ID = 42326,                              -- Replace with issue_id from Step 3
    @begin_date = '2026-06-30',                     -- Replace with override date
    @end_date = NULL,
    @market_value_indent = 65.0000;                 -- Replace with override price

-- Example: Multiple portfolios (execute separately for each)
EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] 
    @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 268, @Issue_ID = 42326, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 65.0000;

EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] 
    @user_id = 'tcnguyen', @row_version = NULL, @entity_id = 272, @Issue_ID = 42326, @begin_date = '2026-06-30', @end_date = NULL, @market_value_indent = 65.0000;


-- ================================================================
-- STEP 6: VERIFICATION QUERIES (CONFIRM CHANGES)
-- ================================================================
-- Purpose: Verify that price overrides were successfully applied
-- Use Case: Post-execution validation

-- ----------------------------------------
-- 6a. Verify Bond Overrides by Issue ID and CUSIP
-- ----------------------------------------
SELECT 
    d.*,
    ev.cusip_number,
    e.deal_name
FROM solvas_am.dbo.deal_issue_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE d.issue_id = 57558                            -- Replace with issue_id
    AND ev.cusip_number IN ('15477CAA3')            -- Replace with CUSIP
    AND d.last_update_date >= '2026-07-15'          -- Replace with date of change
    AND d.begin_date >= '2026-06-01 00:00:00'
    -- AND d.created_by = 'tcnguyen'                -- Optional: Filter by user
ORDER BY d.begin_date DESC;


-- ----------------------------------------
-- 6b. Verify Loan Overrides by Facility ID
-- ----------------------------------------
SELECT 
    d.*,
    ev.lx_identifier,
    e.deal_name
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE d.facility_id = 26478                         -- Replace with facility_id
    AND d.last_update_date >= '2026-07-15'          -- Replace with date of change
    AND d.begin_date >= '2026-06-01 00:00:00'
ORDER BY d.begin_date DESC;


-- ----------------------------------------
-- 6c. Verify Equity Overrides
-- ----------------------------------------
SELECT 
    d.*,
    ev.issue_name,
    e.deal_name
FROM solvas_am.dbo.deal_equity_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.equity_id 
    AND ev.entity_id = e.entity_id
WHERE d.equity_id = 233                             -- Replace with equity_id
    AND d.last_update_date >= '2026-07-15'          -- Replace with date of change
    AND d.begin_date >= '2026-06-01 00:00:00'
ORDER BY d.begin_date DESC;


-- ================================================================
-- REFERENCE INFORMATION
-- ================================================================
/*
Stored Procedures Summary:

Security Type | DELETE Procedure                      | INSERT Procedure                     | Key Parameters
------------- | ------------------------------------- | ------------------------------------ | --------------------------------
Bond          | deal_Issue_market_value_del           | Deal_issue_market_value_put          | @issue_id, @market_value_indent
Loan          | deal_facility_market_value_del        | Deal_Facility_market_value_put       | @facility_id, @pricing_type_1
Equity        | deal_equity_market_value_del          | deal_equity_market_value_put         | @equity_id, @market_value

Common Parameters:
- @user_id: Your Siepe username (e.g., 'tcnguyen')
- @entity_id: Portfolio entity ID from Solvas
- @begin_date: Override effective date (format: 'YYYY-MM-DD' or 'Month DD YYYY HH:MMAM/PM')
- @end_date: NULL for open-ended overrides
- @row_version: NULL (not used in manual overrides)

Database: Solvas_AM (Solvas Asset Management back office database)
Server: mos-sql-p.mos.siepe.local,52155

Related Documentation:
- SKILL.md: C:\source\MD\AdminTools\.github\skills\price-overrides\SKILL.md
- Wiki: https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/6226/MOS-Ops-Price-Overrides

Important Notes:
1. Always DELETE existing records before INSERT to avoid duplicates
2. Equities require deleting EVERY DAY from override date to current date
3. Tag mapping (Step 2) prevents vendor pricing from overwriting manual overrides
4. Verify changes (Step 6) before notifying clients
5. Request dataset refresh from MOS Support after confirming changes
*/

    --- Delete by issue_id

        SELECT CONCAT('EXEC Solvas_am.dbo.deal_Issue_market_value_del'
    , ' @user_id = ''tcnguyen'''
    , ', @entity_id = ', d.entity_id
    , ', @issue_id = ', d.issue_id
    , ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.cusip_number, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.market_value_indent
    FROM Solvas_AM.dbo.Deal_Issue_Market_Value d
    JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
    JOIN solvas_am.dbo.Entity_Issue_view EV 
        ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
        AND ev.entity_id = e.entity_id
    WHERE  d.issue_id = 62875
    AND d.begin_date >= '2026-06-30'
    ORDER BY e.deal_name, ev.cusip_number, d.begin_date;

    --- Delete by facility_id
    SELECT CONCAT('EXEC Solvas_am.dbo.deal_facility_market_value_del'
    , ' @user_id = ''tcnguyen'''
    , ', @entity_id = ', d.entity_id
    , ', @facility_id = ', d.facility_id
    , ', @begin_date = ''', d.begin_date, ''''
    ) AS execute_statement,
    ev.issue_name, 
    e.deal_name, 
    d.begin_date, 
    d.end_date,
    d.pricing_type_1
    FROM solvas_am.dbo.deal_facility_market_value d
    JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
    JOIN solvas_am.dbo.Entity_Issue_view EV 
        ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
        AND ev.entity_id = e.entity_id
    WHERE  ev.facility_id = 62875
    AND 
    e.deal_name IN (
        'Menard, Inc.',
        'COAST3 - Aristotle Pacific CLO Adviser III, LLC'
    )
    AND d.begin_date >= '2026-06-30'
    ORDER BY e.deal_name, d.begin_date;
 
 


Loans:

select concat('exec Solvas_am.dbo.deal_facility_market_value_del '
, ' @user_id = dyun'
, ' ,@entity_id =', d.entity_id
, ' ,@facility_id = ', d.facility_id
, ' ,@begin_date = ','''',begin_date ,''''
--@operation_confirmed
--@silent_mode
), ev.LX_identifier, e.deal_name, d.begin_date, d.end_date
from solvas_am.dbo.deal_facility_market_value d
join solvas_am.dbo.entity e on e.entity_id = d.entity_id
join solvas_am.dbo.Entity_Issue_view EV  on coalesce(ev.facility_id, ev.Issue_id) = d.facility_id and ev.entity_id = e.entity_id
where ev.lx_identifier  in ('500016570')
and e.deal_name IN (
'APC Asset Development II, LP',
'Aristotle Funds Series Trust - Aristotle Core Income Fund',
'Aristotle Funds Series Trust - Aristotle Floating Rate Income Fund',
'Trestles CLO VIII, Ltd MOS',
'Trestles CLO X, Ltd MOS',
'Water and Power Employees Health Benefits Fund',
'Water and Power Employees Retirement Plan'
)
and d.begin_date > '2026-06-30'
 

    ---- Delete by Deal Name

select concat('exec Solvas_am.dbo.deal_equity_market_value_del '
, ' @user_id = tcnguyen'
, ' @equity_id = 233'
, ' ,@entity_id =', d.entity_id
, ' ,@begin_date = ', '''June 30 2026 12:00AM'''
--, ' ,@begin_date = ','''',begin_date ,''''
--@operation_confirmed
--@silent_mode,
)
FROM Solvas_AM.dbo.entity d
WHERE deal_name IN (
'Trestles CLO 2017-1, Ltd MOS',
'Trestles CLO II, Ltd MOS',
'Trestles CLO III, Ltd MOS',
'Trestles CLO IV, Ltd MOS',
'Trestles CLO V, Ltd MOS',
'Trestles CLO VI, Ltd MOS',
'Trestles CLO VII, Ltd MOS',
'Trestles CLO VIII, Ltd MOS'
)


-- check by deal name
select top 100  d.entity_id, d.equity_id,  * 
from solvas_am.dbo.deal_equity_market_value d
join solvas_am.dbo.entity e on e.entity_id = d.entity_id
join solvas_am.dbo.Entity_Issue_view EV  on coalesce(ev.facility_id, ev.Issue_id) = d.equity_id and ev.entity_id = e.entity_id
where  e.deal_name IN (
'Trestles CLO 2017-1, Ltd MOS',
'Trestles CLO II, Ltd MOS',
'Trestles CLO III, Ltd MOS',
'Trestles CLO IV, Ltd MOS',
'Trestles CLO V, Ltd MOS',
'Trestles CLO VI, Ltd MOS',
'Trestles CLO VII, Ltd MOS',
'Trestles CLO VIII, Ltd MOS')
 and e.entity_id = 295
 and d.begin_date >= '2026-06-30 00:00:00'
order by d.equity_id, begin_date desc



exec Solvas_am.dbo.deal_equity_market_value_del @user_id = 'tcnguyen', @equity_id = 233, @entity_id = 295, @begin_date = 'June 30 2026 12:00AM'

exec Solvas_am.dbo.deal_Issue_market_value_del  @user_id = 'tcnguyen' ,@entity_id =244 ,@issue_id = 42326 ,@begin_date = 'Jun 30 2026 12:00AM'


 6. Run the @market_value_indent/@pricing_type_1 is found on the ticket, and the end date
 the @begin_date is found in the beging_date, 
 and the @user_id is the current user name, also use the same parameters as the last step but run bond or loan query base on the cusip type.   Then print out the execute statement for review.
 issue_id is the issue_id, entity_id is the excel solvas_id column or just the solvas_id

Loans:

 EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] @user_id  = '{userid}' ,@row_version = NULL ,@entity_id = 243  ,@facility_id = {issuer_id} ,@begin_date = {override price date} ,@end_date = NULL ,@pricing_type_1 = {Overrid Price}

e.g.
 EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] @user_id  = 'tcnguyen' ,@row_version = NULL ,@entity_id = 235  ,@facility_id = 26478 ,@begin_date = '2026-06-30' ,@end_date = NULL ,@pricing_type_1 = 66.0000  
 EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] @user_id  = 'tcnguyen' ,@row_version = NULL ,@entity_id = 241  ,@facility_id = 26478 ,@begin_date = '2026-06-30' ,@end_date = NULL ,@pricing_type_1 = 66.0000 
 EXEC Solvas_am.[dbo].[Deal_Facility_market_value_put] @user_id  = 'tcnguyen' ,@row_version = NULL ,@entity_id = 243  ,@facility_id = 26478 ,@begin_date = '2026-06-30' ,@end_date = NULL ,@pricing_type_1 = 66.0000 


 Bonds:

 select	
    CONCAT(
        'EXEC Solvas_am.[dbo].[Deal_issue_market_value_put]',
        ' @user_id = ''tcnguyen''',
        ', @row_version = NULL',
        ', @entity_id = ', d.entity_id,
        ', @Issue_ID = 42175',
        ', @begin_date = ''2026-06-30''',
        ', @end_date = NULL',
        ', @market_value_indent = 65.0000'
    ) AS exec_statement
	, ev.LX_identifier, e.deal_name, d.begin_date, d.end_date
from solvas_am.dbo.deal_issue_market_value d
join solvas_am.dbo.entity e on e.entity_id = d.entity_id
join solvas_am.dbo.Entity_Issue_view EV  on coalesce(ev.facility_id, ev.Issue_id) = d.issue_id and ev.entity_id = e.entity_id
and e.deal_name IN (
'Aristotle Funds Series Trust - Aristotle Floating Rate Income Fund'
,'Aristotle Funds Series Trust - Aristotle High Yield Bond Fund'
,'Goldman Sachs Trust II: Goldman Sachs Multi-Manager Non-Core Fixed Income Fund'
,'Indiana University Health, Inc.'
,'MissionSquare PLUS Fund, a stable value fund of VantageTrust III Master Collective Investment Fund (Loan)'
,'Pacific Asset Management Bank Loan Fund L.P.'
,'Pacific Life Insurance Company: PL APC Credit Opportunities Portfolio'
,'Pacific Select Fund - Floating Rate Income Portfolio'
,'Pacific Select Fund - High Yield Bond Portfolio'
,'Water and Power Employees Health Benefits Fund'
,'Water and Power Employees Retirement Plan'
)
and ev.cusip_number  in ('LX232483')
and begin_date >= '2026-06-30 00:00:00'
order  by begin_date desc;



 EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id  = '{userid}' ,@row_version = NULL ,@entity_id = 243  ,@Issue_ID = {issuer_id} ,@begin_date = {override price date} ,@end_date = NULL ,@market_value_indent = {Overrid Price}

 e.g.
 EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id  = 'tcnguyen' ,@row_version = NULL ,@entity_id = 244  ,@Issue_ID = 42326 ,@begin_date = '2026-06-30' ,@end_date = NULL ,@market_value_indent = 65.0000 
 EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id  = 'tcnguyen' ,@row_version = NULL ,@entity_id = 268  ,@Issue_ID = 42326 ,@begin_date = '2026-06-30' ,@end_date = NULL ,@market_value_indent = 65.0000 
 EXEC Solvas_am.[dbo].[Deal_issue_market_value_put] @user_id  = 'tcnguyen' ,@row_version = NULL ,@entity_id = 272  ,@Issue_ID = 42326 ,@begin_date = '2026-06-30' ,@end_date = NULL ,@market_value_indent = 65.0000 
 



--- Check to ensure changes took place on Solvas
--  Check Solvas
--- Check to see if updated by issue_id and cusip --loans
	select d.*
	from solvas_am.dbo.deal_issue_market_value d
	join solvas_am.dbo.entity e on e.entity_id = d.entity_id
	join solvas_am.dbo.Entity_Issue_view EV  on coalesce(ev.facility_id, ev.Issue_id) = d.issue_id and ev.entity_id = e.entity_id
	where e.deal_name like '%'
	---and d.created_by = 'tcnguyen'
	and d.issue_id = 57558
	and ev.cusip_number  in ('15477CAA3')
	and d.last_update_date >= '2026-07-15'
	and begin_date >= '2026-06-01 00:00:00'
	and begin_date = '2026-06-15 00:00:00.000'
	order  by begin_date desc 
 
--bond s
	select*
	from solvas_am.dbo.deal_issue_market_value d
	join solvas_am.dbo.entity e on e.entity_id = d.entity_id
	join solvas_am.dbo.Entity_Issue_view EV  on coalesce(ev.facility_id, ev.Issue_id) = d.issue_id and ev.entity_id = e.entity_id
	where e.deal_name like 'Sy%'
	--and d.issue_id = 11139
	and ev.cusip_number  in ('08179MAN9')
	and begin_date  ='2026-06-19 00:00:00.000'
	order  by begin_date desc 


--- Check to see if updated by issue_id
    select*
    from solvas_am.dbo.deal_issue_market_value d
    join solvas_am.dbo.entity e on e.entity_id = d.entity_id
    join solvas_am.dbo.Entity_Issue_view EV  on coalesce(ev.facility_id, ev.Issue_id) = d.issue_id and ev.entity_id = e.entity_id
    where e.deal_name like '%'
    --and d.issue_id = 11139
    and d.issue_id = 62875
    and begin_date >= '2026-06-30 00:00:00'
    order  by begin_date desc

--- Check by entity ID

    SELECT 
        e.deal_name,
        i.CUSIP_number,
        i.issue_name,
        dmv.begin_date,
        dmv.market_value_indent
    FROM Solvas_AM.dbo.deal_issue_market_value dmv
    JOIN Solvas_AM.dbo.entity e ON dmv.entity_id = e.entity_id
    JOIN Solvas_AM.dbo.issue i ON dmv.issue_id = i.issue_id
    WHERE dmv.entity_id IN (234, 235, 257, 419)
        AND dmv.begin_date = '2026-06-30'
    ORDER BY e.deal_name, i.CUSIP_number;

-----  Confirm Price override worked by entity and portfolio


select top 100 * 
	from solvas_am.dbo.deal_equity_market_value d
	join solvas_am.dbo.entity e on e.entity_id = d.entity_id
	join solvas_am.dbo.Entity_Issue_view EV  on coalesce(ev.facility_id, ev.Issue_id) = d.equity_id and ev.entity_id = e.entity_id
	where  e.deal_name IN (
	'Trestles CLO 2017-1, Ltd MOS',
	'Trestles CLO II, Ltd MOS',
	'Trestles CLO III, Ltd MOS',
	'Trestles CLO IV, Ltd MOS',
	'Trestles CLO V, Ltd MOS',
	'Trestles CLO VI, Ltd MOS',
	'Trestles CLO VII, Ltd MOS',
	'Trestles CLO VIII, Ltd MOS')
	 and e.entity_id = 295
	 and d.begin_date >= '2026-06-30 00:00:00'
	order by equity_id, begin_date desc
 

--- Check price on Secmaster and get instid
SELECT instid FROM Reference.dbo.vinstidentifier 
where Value='LX269902' 
AND RefDataSource like '%MarkIT LoanXMarks%'


---Check position mark on mos
--check core position mark on active position 
select distinct PositionMark, p.refdatasetdate, p.EffFromDate, p.Tradedqty , p.Portfolio, ii.value 
from core.dbo.vposition p 
join core.dbo.vinstidentifiercurrent ii on ii.instid = p.instid -- and ii.InstIdentifierType = 'LoanXID'
where  p.refdatasetdate ='2026-6-16 00:00:00.000'
and p.Portfolio like '%sy%'
and ii.value = 'LX245155'
order by 2 desc

--Use Inst ID Here
SELECT * FROM Reference.dbo.tInstPrice 
where instid= (SELECT instid FROM Reference.dbo.vinstidentifier 
where Value='LX209837' AND RefDataSource like '%MarkIT LoanXMarks%') 
and  
PriceDate = '2026-06-16 00:00:00.000'
order by PriceDate