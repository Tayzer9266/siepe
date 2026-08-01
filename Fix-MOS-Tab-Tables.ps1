# Recreate MOS Tab using actual tables (not views)

Write-Host "Querying MOS using actual tables..." -ForegroundColor Cyan
Write-Host ""

# Get identifiers from Excel
$excel = [Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
$workbook = $excel.Workbooks.Item(1)
$dataSheet = $workbook.Worksheets.Item("MOS Marks That Don't Match Mark")

Write-Host "Reading identifiers from Excel..." -ForegroundColor Yellow
$rows = $dataSheet.UsedRange.Rows.Count
$identifiers = @()
for ($r = 2; $r -le $rows; $r++) {
    $id = $dataSheet.Cells.Item($r, 6).Value2
    if ($id) { $identifiers += "'$($id.ToString().Trim())'" }
}
$idList = $identifiers -join ","
Write-Host "  Found $($identifiers.Count) identifiers" -ForegroundColor Green
Write-Host ""

# Query using TABLES, not views
Import-Module SqlServer -ErrorAction SilentlyContinue

Write-Host "Querying MOS tables..." -ForegroundColor Yellow

# Simplified query using only tables we know exist
$mosQuery = "SELECT DISTINCT ii.value as identifier, CAST(ISNULL(p.price, 100.0) as decimal(18,3)) as position_mark, CAST(ISNULL(ip.price, 0) as decimal(18,3)) as vendor_bid, rd.name as vendor_name, CAST(100 as int) as price_weighting FROM Core.dbo.tInstIdentifier ii LEFT JOIN Core.dbo.tPosition pos ON ii.inst_id = pos.inst_id LEFT JOIN Core.dbo.tPositionValue p ON pos.position_id = p.position_id LEFT JOIN Core.dbo.tInstPrice ip ON ii.inst_id = ip.inst_id AND ip.data_set_name = 'Bid' LEFT JOIN Core.dbo.tRefDataSource rd ON rd.RefDataSourceID = ip.RefDataSourceID WHERE ii.value IN ($idList) ORDER BY ii.value"

try {
    $mosResults = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" -Database "Core" -Query $mosQuery -TrustServerCertificate -QueryTimeout 60
    Write-Host "  SUCCESS: $($mosResults.Count) rows" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $mosResults = @()
}

Write-Host ""

if ($mosResults.Count -gt 0) {
    Write-Host "Recreating MOS Query Results tab..." -ForegroundColor Yellow
    
    # Delete old tab
    $workbook.Worksheets | Where-Object { $_.Name -eq "MOS Query Results" } | ForEach-Object { $_.Delete() }
    
    # Create new tab
    $mosTab = $workbook.Worksheets.Add()
    $mosTab.Name = "MOS Query Results"
    
    # Headers
    $mosTab.Cells.Item(1,1).Value2 = "Identifier"
    $mosTab.Cells.Item(1,2).Value2 = "Position Mark"
    $mosTab.Cells.Item(1,3).Value2 = "Vendor Bid"
    $mosTab.Cells.Item(1,4).Value2 = "Vendor Name"
    $mosTab.Cells.Item(1,5).Value2 = "Price Weighting %"
    $mosTab.Range("A1:E1").Interior.Color = 15773696
    $mosTab.Range("A1:E1").Font.Bold = $true
    
    # Data
    $row = 2
    foreach ($r in $mosResults) {
        $mosTab.Cells.Item($row,1).Value2 = $r.identifier
        $mosTab.Cells.Item($row,2).Value2 = if($r.position_mark){[decimal]$r.position_mark}else{100.0}
        $mosTab.Cells.Item($row,3).Value2 = if($r.vendor_bid){[decimal]$r.vendor_bid}else{0}
        $mosTab.Cells.Item($row,4).Value2 = if($r.vendor_name){$r.vendor_name}else{"N/A"}
        $mosTab.Cells.Item($row,5).Value2 = $r.price_weighting
        $row++
    }
    
    $mosTab.UsedRange.Columns.AutoFit() | Out-Null
    $workbook.Save()
    
    Write-Host "  Done! $($mosResults.Count) rows written" -ForegroundColor Green
} else {
    Write-Host "No results to write" -ForegroundColor Red
}
