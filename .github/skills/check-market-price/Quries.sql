-- ================================================================
-- Market Price Investigation Queries
-- Database: MOS Production (mos-sql-p.mos.siepe.local,52155)
-- Reference: C:\source\MD\AdminTools\.github\skills\check-market-price\SKILL.md
---Wiki:
    https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/2281/Price-Exception-Not-Matching-MarkIT-ICE-or-ICE-OR-NULL-Marks
-- ================================================================

-- ================================================================
-- SECTION 1: CHECK POSITION MARKS (CORE DATABASE)
-- ================================================================
-- Purpose: Verify marked prices on active positions
-- Use Case: Confirm if prices were applied to positions after correction

-- Check position mark on active position
SELECT DISTINCT 
    p.refdatasetdate,
	p.Portfolio, 
    PositionMark, 
	ii.value AS Identifier,
    p.Tradedqty, 
    p.EffFromDate
FROM core.dbo.vposition p 
JOIN core.dbo.vinstidentifiercurrent ii ON ii.instid = p.instid
WHERE p.refdatasetdate = '2026-07-22 00:00:00.000'  -- Replace with target date
    AND p.Portfolio LIKE '%sy%'                      -- Replace with portfolio pattern
    AND ii.value = 'LX293810'                       -- Replace with CUSIP/ISIN/LoanX ID
ORDER BY   p.refdatasetdate, ii.value, p.Portfolio;

SELECT DISTINCT 
    cpm.CompanyID,
    c.Name AS CompanyName,
    p.refdatasetdate,
    p.Portfolio, 
    PositionMark, 
    ii.value AS Identifier,
    p.Tradedqty, 
    p.EffFromDate
FROM core.dbo.vposition p 
JOIN core.dbo.vinstidentifiercurrent ii ON ii.instid = p.instid
LEFT JOIN core.dbo.tCompanyPortfolioMap cpm ON cpm.PortfolioID = p.PortfolioID 
    AND cpm.EffFromDate <= p.refdatasetdate 
    AND cpm.EffThruDate > p.refdatasetdate
LEFT JOIN core.Employee.tCompany c ON c.CompanyID = cpm.CompanyID
WHERE p.refdatasetdate = '2026-07-28 00:00:00.000'  -- Replace with target date
   -- AND p.Portfolio LIKE '%Ari%'                      -- Replace with portfolio pattern
    AND ii.value = 'LX293801'   and cpm.CompanyID = '500000006'       --- aristotle                 -- Replace with CUSIP/ISIN/LoanX ID
ORDER BY cpm.CompanyID, p.refdatasetdate, ii.value, p.Portfolio 

-- ================================================================
-- SECTION 2: CHECK VENDOR PRICES (REFERENCE DATABASE)
-- ================================================================
-- Purpose: Check if vendor sources (ICE, LSEG, Markit) have prices
-- Use Case: Investigate why a specific vendor price was/wasn't used
--
-- Vendor Source Mapping:
--   - LSEG = LSEG Siepe_Multiasset_Pricing
--   - Markit = Siepe-SecurityMaster|Price|MarkIt
--   - ICE = Aristotle|ICE
--
-- If NO DATA found:
--   1. Check the files we sent (verify CUSIP was submitted for pricing)
--   2. Check the files we received (verify vendor provided pricing)
--   3. Review vendor data feed jobs for errors

-- Check vendor prices on MOS Reference database
SELECT TOP 100 
    p.PriceDate,
    r.Name AS RefDataSource, 
    p.Price, 
    p.Bid, 
    p.Ask,
    ii.value AS Identifier
FROM Reference.dbo.vinstpricecurrentraw p 
JOIN Reference.dbo.vRefDataSource r ON r.RefDataSourceID = p.RefDataSourceID
JOIN Reference.dbo.vInstIdentifierCurrent ii ON ii.instid = p.instid 
WHERE ii.value = '34966BAN6'                        -- Replace with CUSIP/ISIN/LoanX ID
    AND r.name NOT IN ('solvas portfolio')          -- Exclude Solvas prices
   -- and r.name = 'Siepe-SecurityMaster|Price|MarkIt'
    -- AND p.PriceDate >= '2026-7-24 00:00:00.000'            -- Optional: Filter to specific date
ORDER BY p.PriceDate DESC;



-- ================================================================
-- SECTION 3: CHECK SOLVAS PRICES (BACK OFFICE DATABASE)
-- ================================================================
-- Purpose: Validate prices stored in Solvas_AM database
-- Use Case: Compare front office (MOS) prices with back office (Solvas) prices

-- ----------------------------------------
-- 3a. Check Loan Prices (deal_facility_market_value)
-- ----------------------------------------
SELECT 
    e.deal_name AS Portfolio, 
    ev.lx_identifier,
    d.begin_date, 
    d.end_date,

    d.pricing_type_1
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ('LX293801')             -- Replace with LoanX ID
    AND e.deal_name LIKE 'sy%'                      -- Replace with portfolio pattern
    AND d.begin_date >= '7/22/2026'       -- Replace with start date
ORDER BY d.begin_date DESC;

SELECT 
    e.deal_name AS Portfolio, 
    ev.lx_identifier,
    d.begin_date, 
    d.end_date,
    d.pricing_type_1
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ('LX293801')             -- Replace with LoanX ID
    AND e.deal_name in ('Aristotle Funds Series Trust - Aristotle Floating Rate Income Fund',
'Aristotle Funds Series Trust - Aristotle High Yield Bond Fund',
'Indiana University Health, Inc.',
'MissionSquare PLUS Fund, a stable value fund of VantageTrust III Master Collective Investment Fund (Loan)',
'Pacific Asset Management Bank Loan Fund L.P.',
'Pacific Life Insurance Company: IMD Bank Loans Portfolio',
'Pacific Select Fund - Floating Rate Income Portfolio',
'Pacific Select Fund - High Yield Bond Portfolio',
'Trestles CLO 12, Ltd MOS',
'Trestles CLO 13, Ltd MOS',
'Trestles CLO 2017-1, Ltd MOS',
'Trestles CLO II, Ltd MOS',
'Trestles CLO III, Ltd MOS',
'Trestles CLO IV, Ltd MOS',
'Trestles CLO IX, Ltd MOS',
'Trestles CLO V, Ltd MOS',
'Trestles CLO VI, Ltd MOS',
'Trestles CLO VII, Ltd MOS',
'Trestles CLO VIII, Ltd MOS',
'Trestles CLO X, Ltd MOS',
'Trestles CLO XI, Ltd MOS',
'Trestles Funding Solutions, Ltd MOS',
'Trestles Funding Solutions, Ltd MOS',
'Water and Power Employees Health Benefits Fund',
'Water and Power Employees Retirement Plan')                    -- Replace with portfolio pattern
    AND d.begin_date >= '7/22/2026'       -- Replace with start date
ORDER BY d.begin_date DESC;

-- ----------------------------------------
-- 3b. Check Bond Prices - Search by CUSIP (deal_issue_market_value)
-- ----------------------------------------

SELECT 
    e.deal_name AS Portfolio,
    ev.cusip_number,
    ev.issue_name,
    d.begin_date, 
    d.end_date,
    d.market_value_indent
 
FROM solvas_am.dbo.deal_issue_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev 
    ON COALESCE(ev.facility_id, ev.Issue_id) = d.issue_id 
    AND ev.entity_id = e.entity_id
WHERE ev.cusip_number  IN ('{cusip}')                  -- Replace with CUSIP (e.g., '04045F162')
    AND d.begin_date >= '2026-07-22'                -- Replace with start date
ORDER BY d.begin_date DESC;

select*
from solvas_am.dbo.deal_issue_market_value d
join solvas_am.dbo.entity e on e.entity_id = d.entity_id
join solvas_am.dbo.Entity_Issue_view EV  on coalesce(ev.facility_id, ev.Issue_id) = d.issue_id and ev.entity_id = e.entity_id
where e.deal_name like 'Sy%'
--and d.issue_id = 11139
and ev.cusip_number  in ('34966BAN6')
and begin_date >= '2026-07-22' 
order  by begin_date desc 



-- ----------------------------------------
-- 3c. Check Bond Prices - Search by Entity ID (Bulk Validation)
-- ----------------------------------------
SELECT TOP 100
    e.deal_name AS Portfolio,
    i.CUSIP_number,
    i.issue_name,
    dmv.begin_date,
    dmv.market_value_indent
FROM Solvas_AM.dbo.deal_issue_market_value dmv
JOIN Solvas_AM.dbo.entity e ON dmv.entity_id = e.entity_id
JOIN Solvas_AM.dbo.issue i ON dmv.issue_id = i.issue_id
WHERE dmv.entity_id IN (234, 235, 257, 419)         -- Replace with entity_id list
    AND dmv.begin_date = '2026-06-30'               -- Replace with target date
ORDER BY e.deal_name, i.CUSIP_number;


-- ================================================================
-- SECTION 4: CHECK SECURITY MASTER PRICES (REFERENCE DATABASE)
-- ================================================================
-- Purpose: Validate prices in Security Master database (raw vendor data)
-- Use Case: Verify raw vendor prices before price weighting is applied

-- Step 1: Find Instrument in Security Master
SELECT * 
FROM Reference.dbo.vinstidentifier 
WHERE Value = 'LX189433'                            -- Replace with LoanX ID or CUSIP
    AND RefDataSource LIKE '%MarkIT LoanXMarks%';   -- Or other vendor pattern

-- Step 2: Check Price in Security Master (Use InstID from Step 1)
SELECT * 
FROM Reference.dbo.tInstPrice 
WHERE instid = 1000537671                           -- Replace with InstID from Step 1
    AND PriceDate = '2026-06-03'                    -- Replace with target date
ORDER BY PriceDate DESC;


--- Combined Check price on Sec-M
SELECT * 
FROM Reference.dbo.tInstPrice 
WHERE instid = (SELECT instID 
FROM Reference.dbo.vinstidentifier 
WHERE Value = '34966BAN6'                            -- Replace with LoanX ID or CUSIP
    AND RefDataSource LIKE '%MarkIT LoanXMarks%')                           -- Replace with InstID from Step 1
    AND PriceDate = '2026-06-03'                    -- Replace with target date
ORDER BY PriceDate DESC;

 
 
-- ================================================================
-- POST-RESOLUTION WORKFLOWS
-- ================================================================
--- Next Steps to Reconcile Prices:
---1. If the correct price is on SecM but not on MOS Reference, send the updated prices from SecM to MOS.
---2. If the correct price is on MOS Reference but not on Solvas, send updated price from MOS to Solvas.
---3. Once all prices in Solvas are correct, kick off refreshes so that the Position Mark on MOS matches the Bid Price from Sycamore on the Report.
---4. Send Position Extracts to Sycamore once all is complete.


-- ================================================================
-- SECTION 5a: If the correct price is on SecM but not on MOS Reference
-- ================================================================

-- Purpose: Procedures to run after correcting price mismatches
 
-- SecM Prod 30 --- don't run unless bond
-- Mos SA 1291
-- Purpose: Export bid prices to Security Master for validation
-- Report Subscriptions:
-  RS 700002320: Bid price export (pPriceExport)
-  RS 500002177: Pick up file from mos-tools-p.mos.siepe.local

-- ----------------------------------------
 
-- Execute bid price export for date range
-- Note: Run for each day individually, then verify reference prices updated
EXEC Core.Report.pPriceExport 
    @PriceSourceIDList = '1000000001,1000000004,1000000016',  -- ICE, LSEG, Markit
    @InstrumentSourceIDList = NULL,                           -- Leave NULL if InstID unknown
    @StartDate = '2026-07-01',
    @EndDate = '2026-07-03',
    @dateRange = 1;

-- Note: Leave @InstrumentSourceIDList NULL if you don't know it 
-- (InstID from MOS != InstID from SecM)
-- Purpose: Find SFTP folder locations for file pickups

 

-- ================================================================
-- 5b. Solvas Price Export (pSolvasExportPriceEntity) Position Extract for Client Reporting (pPositionExtract)
-- Purpose: Export MOS prices to Solvas for back office processing and Vender Reconciliation
-- Must run in the correct company admin portal environment (e.g., Sycamore, Aristotle, etc.)

-- Default EXEC core.Report.pSolvasExportPriceEntity  @CompanyID = '500000004', @FallBackToMostRecentTradePrice = 1
-- Sycamore Admin Tools  / search: MOS Position  2 SA:3
-- Subscription ID 500002483
-- RS: 500001246   price loader  for all days
/*
Company                     CompanyID   RS_ID       SA_ID   
------------------------    ----------  ----------  --------
Diameter                    500000002   500002484   1555 
Sycamore                    500000004   500002483   1556
Abry Partners II, LLC       500000005   500002485   1557
Aristotle Pacific Capital   500000006   500002283   1558
Garnet Credit Management    500000007   (manual)    1559 */
-- ================================================================
 
 --- examples:
EXEC core.Report.pSolvasExportPriceEntity  
    @CompanyID = '500000006',              -- Aristotle
    @FallBackToMostRecentTradePrice = 1, 
    @PriceDate = '2026-7-22',    --- this is for the 22nd going foward
    @identifier = 'LX293801'
 

EXEC core.Report.pSolvasExportPriceEntity  
    @CompanyID = '500000004',              -- 500000004 = Sycamore
    @FallBackToMostRecentTradePrice = 1, 
    @PriceDate = '2026-7-22',    --- this is for the 22nd going foward
    @identifier = 'LX293801'

EXEC core.Report.pSolvasExportPriceEntity  
    @CompanyID = '500000004,500000002,500000005,500000006,500000007',
    @FallBackToMostRecentTradePrice = 1,
    @PriceDate = '2026-06-16',      --- single day refresh for all companies
    @SingleDate = 1;

--check vendor prices to see if they are good afterards
 
-- ================================================================
-- 6. Dataset Refresh to sync up Mark Prices with Vendor Prices
-- Check prices to see they are good afterwards
-- Dataset postion refresh needs to bd done to sync mark position: 
-- ================================================================

-- Fund Data Governance (Dataset Refresh): https://mos-portal-p.mos.siepe.local/fund-data-governance/dataset-refresh
-- Job Management: https://portal.mos.siepe.local/jobManagement
-- SFTP Folders:
-- Solvas SecMaster LoanXMarks: \\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\Solvas\SecMaster\LoanXMarks\Incoming
-- Siepe-SecurityMaster Index: \\mos.siepe.local\shared\CLIENTS\998\MOS\PROD\Siepe-SecurityMaster\Index
-- Pick-up script: C:\Siepe\Data\Scripts\PROD\SecMaster_Index.ps1
-- Check Mark Prices if it updated

-- ================================================================
-- 7. Position Extract for Client Reporting (pPositionExtract)
-- positionon after the solvas  and mark prices are matched  postion exgtract to solvas
-- RS 500002376 on MOS to RUN Adhoc Position and Position Cashflow Extracts to Client Evs
-- ================================================================
--- examples

EXEC report.pPositionExtract  
    @RefDataSetDateStart = '7/22/2026',
    @RefDataSetDateEnd = '7/30/2026',
    @CompanyID = '500000004',                       -- 500000004 = Sycamore
    @ExcludePortfolioID = '#[PortfolioExclusion]',
    @IsPositionCashFlow = '#[IsPositionCashflow]';

-- Example: Generate position extract for date range
EXEC report.pPositionExtract  
    @RefDataSetDateStart = '7/22/2026',
    @RefDataSetDateEnd = '7/30/2026',
    @CompanyID = '500000006',                       -- 500000004 = Aristotle
    @ExcludePortfolioID = '#[PortfolioExclusion]',
    @IsPositionCashFlow = '#[IsPositionCashflow]';

 
 --- Check CHECK SOLVAS PRICES to ensure priced updated

 
