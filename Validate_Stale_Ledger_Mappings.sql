-- =============================================
-- Query to identify STALE mappings between Reference and Core ledgers
-- Created: 2026-07-20
-- Purpose: Find mappings where Reference DataSourceKey no longer matches 
--          either Core Description OR Core MMF Account ValueString
-- =============================================

SELECT 
    map.CORELedgerID,
    map.RefLedgerID,
    map.RefDataSource,
    rl.DataSourceKey AS Ref_DataSourceKey,
    cl.Description AS Core_Description,
    lv.ValueString AS Core_MMF_Account,
    -- Show what's mismatched
    CASE 
        WHEN rl.DataSourceKey IS NULL THEN 'Reference DataSourceKey is NULL'
        WHEN cl.Description IS NULL AND lv.ValueString IS NULL THEN 'Core has no Description or MMF Account'
        ELSE 'DataSourceKey matches neither Description nor MMF Account'
    END AS MismatchReason
FROM Reference.dbo.vLedgerLedgerMapCurrent map
    INNER JOIN Reference.dbo.vLedger rl 
        ON rl.LedgerID = map.RefLedgerID
    INNER JOIN Core.dbo.vLedger cl 
        ON cl.LedgerID = map.CORELedgerID
    LEFT JOIN (
        SELECT lvc.LedgerID, lvc.ValueString
        FROM Core.dbo.vLedgerValueCurrent lvc
        INNER JOIN Core.dbo.vLedgerValueType lvt 
            ON lvt.LedgerValueTypeID = lvc.LedgerValueTypeID
        WHERE lvt.Name = 'MMF Account'
    ) lv ON lv.LedgerID = cl.LedgerID
WHERE 
    -- Exclude Solvas Portfolio
    map.RefDataSource NOT IN ('Solvas Portfolio')
    -- DataSourceKey doesn't match Description
    AND ISNULL(rl.DataSourceKey, '') <> ISNULL(cl.Description, '')
    -- AND DataSourceKey doesn't match MMF Account ValueString
    AND ISNULL(rl.DataSourceKey, '') <> ISNULL(lv.ValueString, '')
ORDER BY map.RefDataSource, map.CORELedgerID;
