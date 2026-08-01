# Quick Export - Create Query Result Tabs for VLOOKUP
# This creates 2 new tabs with all MOS and Solvas query results

$excelFile = ".\Output\PriceExceptionReport_20260713.xlsx"

Write-Host "Opening Excel..." -ForegroundColor Cyan
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $true
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open((Resolve-Path $excelFile).Path)

# Get CUSIPs from main tab
$mainSheet = $workbook.Worksheets.Item("MOS Analysis")
$rows = $mainSheet.UsedRange.Rows.Count
$cusips = @()
for ($r = 2; $r -le $rows; $r++) {
    $c = $mainSheet.Cells.Item($r, 1).Value2
    if ($c) { $cusips += "'$c'" }
}
$cusipList = $cusips -join ","

Write-Host "Found $($cusips.Count) CUSIPs" -ForegroundColor Green
Write-Host ""

# Load SQL
Import-Module SqlServer -ErrorAction SilentlyContinue

# MOS Query
Write-Host "Querying MOS..." -ForegroundColor Yellow
$mosQuery = "SELECT i.cusip, ISNULL(pm.position_mark,0) as position_mark, ISNULL(ip.price,0) as bid_price, 
CASE WHEN ABS(ISNULL(pm.position_mark,0)-ISNULL(ip.price,0))>0.001 THEN 'YES' ELSE 'NO' END as mismatch,
ISNULL(pw.price_weighting_percentage,100) as weighting
FROM Reference.vInstIdentifierCurrent i
LEFT JOIN Core.vPositionMark pm ON i.inst_id=pm.inst_id
LEFT JOIN Reference.vInstPriceCurrentRaw ip ON i.inst_id=ip.inst_id AND ip.data_source_name='MarkIt' AND ip.data_set_name='Bid'
LEFT JOIN Core.vPositionPriceWeightingActive pw ON i.inst_id=pw.inst_id
WHERE i.cusip IN ($cusipList)"

$mosData = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" -Database "Reference" -Query $mosQuery -TrustServerCertificate
Write-Host "  Got $($mosData.Count) MOS results" -ForegroundColor Green

# Solvas Query
Write-Host "Querying Solvas..." -ForegroundColor Yellow
$solvasQuery = "SELECT ei.cusip, dfmv.pricing_type_1*100 as solvas_price
FROM dbo.Entity_Issue_view ei
LEFT JOIN dbo.Deal_Facility_Market_Value dfmv ON ei.facility_id=dfmv.facility_id
WHERE ei.cusip IN ($cusipList)"

$solvasData = Invoke-Sqlcmd -ServerInstance "SOLVAS-SQL-D.mos.siepe.local,52156" -Database "solvas_am" -Query $solvasQuery -TrustServerCertificate
Write-Host "  Got $($solvasData.Count) Solvas results" -ForegroundColor Green
Write-Host ""

# Create MOS tab
Write-Host "Creating MOS Query Results tab..." -ForegroundColor Cyan
$workbook.Worksheets | Where-Object {$_.Name -eq "MOS Query Results"} | ForEach-Object {$_.Delete()}
$mosTab = $workbook.Worksheets.Add()
$mosTab.Name = "MOS Query Results"
$mosTab.Cells.Item(1,1).Value2 = "CUSIP"
$mosTab.Cells.Item(1,2).Value2 = "Position Mark"
$mosTab.Cells.Item(1,3).Value2 = "Bid Price"
$mosTab.Cells.Item(1,4).Value2 = "Mismatch"
$mosTab.Cells.Item(1,5).Value2 = "Weighting"
$mosTab.Range("A1:E1").Interior.Color = 15773696
$mosTab.Range("A1:E1").Font.Bold = $true

$row = 2
foreach ($d in $mosData) {
    $mosTab.Cells.Item($row,1).Value2 = $d.cusip
    $mosTab.Cells.Item($row,2).Value2 = [decimal]$d.position_mark
    $mosTab.Cells.Item($row,3).Value2 = [decimal]$d.bid_price
    $mosTab.Cells.Item($row,4).Value2 = $d.mismatch
    $mosTab.Cells.Item($row,5).Value2 = $d.weighting
    if ($d.mismatch -eq "YES") { $mosTab.Cells.Item($row,4).Interior.Color = 65535 }
    $row++
}
$mosTab.UsedRange.Columns.AutoFit() | Out-Null
Write-Host "  Done!" -ForegroundColor Green

# Create Solvas tab
Write-Host "Creating Solvas Query Results tab..." -ForegroundColor Cyan
$workbook.Worksheets | Where-Object {$_.Name -eq "Solvas Query Results"} | ForEach-Object {$_.Delete()}
$solvasTab = $workbook.Worksheets.Add()
$solvasTab.Name = "Solvas Query Results"
$solvasTab.Cells.Item(1,1).Value2 = "CUSIP"
$solvasTab.Cells.Item(1,2).Value2 = "Solvas Price"
$solvasTab.Range("A1:B1").Interior.Color = 15773696
$solvasTab.Range("A1:B1").Font.Bold = $true

$row = 2
foreach ($d in $solvasData) {
    $solvasTab.Cells.Item($row,1).Value2 = $d.cusip
    $solvasTab.Cells.Item($row,2).Value2 = if ($d.solvas_price) {[decimal]$d.solvas_price} else {"N/A"}
    $row++
}
$solvasTab.UsedRange.Columns.AutoFit() | Out-Null
Write-Host "  Done!" -ForegroundColor Green

Write-Host ""
Write-Host "Saving..." -ForegroundColor Yellow
$workbook.Save()

Write-Host ""
Write-Host "=== COMPLETE ===" -ForegroundColor Green
Write-Host "Created 2 tabs for VLOOKUP:" -ForegroundColor White
Write-Host "  - MOS Query Results" -ForegroundColor Cyan
Write-Host "  - Solvas Query Results" -ForegroundColor Cyan
