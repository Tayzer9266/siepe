USE Core
-- Aristotle
-- ============================================================
-- FactSet Integrity: Missing Prices Tab
-- Reproduces the result set from chk1_missing() in
-- factset_integrity.py for a given report date.
--
-- Flags positions where:
--   "Missing Price"    -- PositionMark IS NULL
--   "Stale Price Date" -- PositionMark exists but the raw price
--                         date is older than the report date
--                         (Siepe-MOS-only rollover instruments)
--
-- Output is ordered to match the report: Missing Price first,
-- then Stale Price Date, each group sorted by Ending MV desc.
-- ============================================================

DECLARE @RefDataSetDate DATE      = NULL        -- NULL = most recent business day
DECLARE @Login          VARCHAR(50) = NULL        -- NULL = current Windows login
DECLARE @CompanyID      INT       = 2            -- Aristotle Capital Management (Aristotle-Prod)

IF @Login IS NULL
    SET @Login = SUSER_SNAME()

IF @RefDataSetDate IS NULL
    SET @RefDataSetDate = dbo.fDateFloorS(dbo.fOffsetDate(GETDATE(), 'W', 0), 'DD')

-- ── Step 1: Aristotle portfolio list ─────────────────────────────────────────

DROP TABLE IF EXISTS #CompanyPortfolios
CREATE TABLE #CompanyPortfolios (CompanyID INT, PortfolioID INT)
INSERT INTO #CompanyPortfolios
SELECT CompanyID, PortfolioID
FROM   dbo.vCompanyPortfolioMapCurrent
WHERE  CompanyID = @CompanyID

-- ── Step 2: Positions (mirrors pFactSetTBR.sql #Positions block) ─────────────

DROP TABLE IF EXISTS #Positions
SELECT
    P.PositionID
    ,PFM.FundID
    ,PFM.Fund
    ,P.InstID
    ,IT.WSOAssetType
    ,SUM(P.TradedQty)                                               AS TradedQty
    ,SUM(P.OutstandingTradedRC)                                     AS OutstandingTradedRC
    ,SUM(P.PositionMark * CASE WHEN IT.WSOAssetType = 'Equity'
                                THEN P.TradedQty
                                ELSE P.OutstandingTradedRC END)
        / NULLIF(SUM(CASE WHEN IT.WSOAssetType = 'Equity'
                          THEN P.TradedQty
                          ELSE P.OutstandingTradedRC END), 0)       AS PositionMark
    ,SUM(P.TradedMV)                                                AS TradedMV
    ,SUM(P.TradedRCMV)                                              AS TradedRCMV
INTO #Positions
FROM       dbo.fPositionByLogin(@Login)     P
JOIN       #CompanyPortfolios               CP  ON CP.PortfolioID = P.PortfolioID
JOIN       dbo.vPortfolioFundMapCurrent     PFM ON PFM.PortfolioID = P.PortfolioID
JOIN       dbo.vInstRaw                     IR  ON IR.InstID = P.InstID
JOIN       dbo.vInstTypeRaw                 IT  ON IT.InstTypeID = IR.InstTypeID
WHERE  P.RefDataSetDate = @RefDataSetDate
GROUP BY
    P.PositionID
    ,PFM.FundID
    ,PFM.Fund
    ,P.InstID
    ,IT.WSOAssetType

-- ── Step 3: Raw price sources per instrument ─────────────────────────────────
-- Aggregates all sources from vInstPriceCurrentRaw on the report date.
-- Format matches the Python: "Source: price (bid=X | ask=Y | mid=Z)"
-- Instruments with ONLY a Siepe MOS row are potential rollovers (stale).

DROP TABLE IF EXISTS #RawSources
SELECT
    instid
    ,STRING_AGG(
        CONCAT(
            InstPriceSource, ': ',
            CONVERT(NVARCHAR(20), CONVERT(DECIMAL(18,4), Price)),
            CASE WHEN Bid IS NOT NULL AND Ask IS NOT NULL
                 THEN CONCAT(
                        ' (bid=', CONVERT(NVARCHAR(20), CONVERT(DECIMAL(18,4), Bid)),
                        ' | ask=', CONVERT(NVARCHAR(20), CONVERT(DECIMAL(18,4), Ask)),
                        ' | mid=', CONVERT(NVARCHAR(20), CONVERT(DECIMAL(18,4), (Bid + Ask) / 2.0)),
                        ')')
                 ELSE '' END
        ), ' || '
     ) WITHIN GROUP (ORDER BY InstPriceSource)                      AS AvailableRawSources
    -- Flag as Siepe-MOS-only rollover when no independent vendor feed exists
    ,CASE WHEN COUNT(*) = COUNT(CASE WHEN InstPriceSource = 'Siepe MOS' THEN 1 END)
          THEN 1 ELSE 0 END                                         AS IsSiepeOnly
    ,MAX(CASE WHEN InstPriceSource = 'Siepe MOS' THEN PriceDate END) AS SiepePriceDate
INTO #RawSources
FROM   dbo.vInstPriceCurrentRaw
WHERE  PriceDate = @RefDataSetDate
GROUP BY instid

-- ── Step 4: Final result — Missing or Stale Prices ───────────────────────────

SELECT
    -- Issue type: matches the Python's "Missing Price" / "Stale Price Date" labels
    CASE
        WHEN P.PositionMark IS NULL THEN 'Missing Price'
        ELSE 'Stale Price Date'
    END                                                             AS Issue

    ,F.FundName                                                     AS [Portfolio Name]

    -- Symbol derivation: identical to pFactSetTBR.sql
    ,TRY_CONVERT(NVARCHAR(30),
        COALESCE(
            CASE WHEN II.[Bloomberg ID] LIKE 'BBG%'
                 THEN COALESCE(II.CUSIP, II.ISIN, II.LoanXID)
                 ELSE II.[Bloomberg ID] END,
            II.CUSIP,
            II.ISIN,
            CASE WHEN II.[Bloomberg Unique ID] LIKE 'COBL%'
                 THEN SUBSTRING(II.[Bloomberg Unique ID], 3, 100) END,
            II.LoanXID
        )
    )                                                               AS Symbol

    ,I.[Name]                                                       AS [Security Name]

    ,CASE IT.WSOAssetType
         WHEN 'Loan' THEN 'Facility'
         WHEN 'ABS'  THEN 'Security'
         WHEN 'Bond' THEN 'Security'
         ELSE IT.WSOAssetType
     END                                                            AS [Asset Class]

    ,CASE WHEN I.Issuer = 'US Treasury N/B'
          THEN 'US Treasury or Agency'
          ELSE I.InstType
     END                                                            AS [Asset Type]

    ,II.CUSIP                                                       AS CUSIP
    ,II.LoanXID                                                     AS [LX ID]

    ,CASE WHEN PP.InstID IS NOT NULL THEN 'Y' END                   AS [Priv. Plcmt]

    ,TRY_CONVERT(DECIMAL(28,4),
        CASE WHEN P.WSOAssetType = 'Equity'
             THEN P.TradedQty
             ELSE P.OutstandingTradedRC END
     )                                                              AS Quantity

    -- Price: NULL for missing; existing value for stale
    ,CASE WHEN P.PositionMark IS NULL
          THEN NULL
          ELSE TRY_CONVERT(DECIMAL(28,8), P.PositionMark * ISNULL(IT.PriceFactor, 1))
     END                                                            AS Price

    ,FORMAT(@RefDataSetDate, 'MM/dd/yyyy')                          AS [Price Date]
    ,FORMAT(@RefDataSetDate, 'MM/dd/yyyy')                          AS [File Date]

    ,TRY_CONVERT(DECIMAL(28,4), ISNULL(P.TradedRCMV, P.TradedMV))  AS [Ending MV ($)]

    -- Days Stale: how old is the Siepe MOS price for rollover instruments?
    -- Populated when the raw source is Siepe MOS only and its PriceDate predates
    -- the report date — mirrors the Python's rollover_ctx / Days Stale column.
    ,CASE
         WHEN RS.IsSiepeOnly = 1 AND RS.SiepePriceDate < @RefDataSetDate
         THEN CONVERT(NVARCHAR(20), DATEDIFF(DAY, RS.SiepePriceDate, @RefDataSetDate))
         ELSE NULL
     END                                                            AS [Days Stale]

    ,COALESCE(RS.AvailableRawSources, '(no raw data found)')        AS [Available Raw Sources]

FROM       #Positions                   P
JOIN       dbo.vFund                    F   ON F.FundID    = P.FundID
JOIN       dbo.vInst                    I   ON I.InstID    = P.InstID
JOIN       dbo.vInstType                IT  ON IT.InstTypeID = I.InstTypeID
LEFT JOIN  dbo.vInstByIdentifier        II  ON II.InstID   = I.InstID
LEFT JOIN  dbo.vInstPrivatePlacementRaw PP  ON PP.RefRecStatusID = 1
                                           AND PP.EffThruDate = '9999-01-01'
                                           AND PP.InstID = I.InstID
LEFT JOIN  #RawSources                  RS  ON RS.instid   = P.InstID

WHERE
    -- Missing Price: PositionMark IS NULL
    -- Stale Price Date: Siepe-MOS-only rollover where the raw price date < report date
    (
        P.PositionMark IS NULL
        OR (RS.IsSiepeOnly = 1 AND RS.SiepePriceDate < @RefDataSetDate)
    )
    -- Mirrors filter_df(): exclude zero/tiny quantities and CASH positions
    AND CASE WHEN P.WSOAssetType = 'Equity' THEN P.TradedQty ELSE P.OutstandingTradedRC END >= 0.1
    AND CASE P.WSOAssetType
            WHEN 'Loan' THEN 'Facility'
            WHEN 'ABS'  THEN 'Security'
            WHEN 'Bond' THEN 'Security'
            ELSE P.WSOAssetType
        END <> 'CASH'

ORDER BY
    -- Missing Price sorts before Stale Price Date (alphabetical ascending)
    CASE WHEN P.PositionMark IS NULL THEN 0 ELSE 1 END
    ,ISNULL(P.TradedRCMV, P.TradedMV) DESC

DROP TABLE IF EXISTS #CompanyPortfolios
DROP TABLE IF EXISTS #Positions
DROP TABLE IF EXISTS #RawSources
