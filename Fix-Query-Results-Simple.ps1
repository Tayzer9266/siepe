# Fix Query Results - Simpler Version

param(
    [string]$ExcelPath = ".\Output\PriceExceptionReport_20260713.xlsx"
)

Write-Host "Fixing Query Results..." -ForegroundColor Cyan
Write-Host ""

# Kill Excel
Get-Process -Name EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Open Excel
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $true
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open((Resolve-Path $ExcelPath).Path)
$mainSheet = $workbook.Worksheets.Item("MOS Marks That Don't Match Mark")

# Read identifiers from column 6 (Primary Identifier)
Write-Host "Reading identifiers..." -ForegroundColor Yellow
$rows = $mainSheet.UsedRange.Rows.Count
$identifiers = @()
for ($r = 2; $r -le $rows; $r++) {
    $id = $mainSheet.Cells.Item($r, 6).Value2
    if ($id) {
        $identifiers += $id.ToString().Trim()
    }
}

Write-Host "Found $($identifiers.Count) identifiers" -ForegroundColor Green
Write-Host "Sample: $($identifiers[0..2] -join ', ')..." -ForegroundColor Gray
Write-Host ""

# Load SQL module
Import-Module SqlServer -ErrorAction SilentlyContinue

# Build SQL IN list
$idList = ($identifiers | ForEach-Object { "'" + $_ + "'" }) -join ","

# MOS Query
Write-Host "Querying MOS database..." -ForegroundColor Yellow
$mosQuery = "SELECT i.value as identifier, CAST(ISNULL(pm.position_mark, 0) as decimal(18,3)) as position_mark, CAST(ISNULL(ip.price, 0) as decimal(18,3)) as vendor_bid, r.name as vendor_name, CAST(ISNULL(pw.price_weighting_percentage, 100) as int) as price_weighting FROM Reference.vInstIdentifierCurrent i LEFT JOIN Core.vPositionMark pm ON i.inst_id = pm.inst_id LEFT JOIN Reference.vInstPriceCurrentRaw ip ON i.inst_id = ip.inst_id LEFT JOIN Reference.vRefDataSource r ON r.RefDataSourceID = ip.RefDataSourceID LEFT JOIN Core.vPositionPriceWeightingActive pw ON i.inst_id = pw.inst_id WHERE i.value IN ($idList) ORDER BY i.value"

try {
    $mosResults = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" -Database "MOS" -Query $mosQuery -TrustServerCertificate -QueryTimeout 60
    Write-Host "  MOS results: $($mosResults.Count) rows" -ForegroundColor Green
} catch {
    Write-Host "  MOS failed: $($_.Exception.Message)" -ForegroundColor Red
    $mosResults = @()
}

# Solvas Query  
Write-Host "Querying Solvas database..." -ForegroundColor Yellow
$solvasQuery = "SELECT ev.lx_identifier as identifier, CAST(d.pricing_type_1 * 100 as decimal(18,3)) as solvas_price, e.deal_name as portfolio FROM solvas_am.dbo.deal_facility_market_value d JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id JOIN solvas_am.dbo.Entity_Issue_view ev ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id AND ev.entity_id = e.entity_id WHERE ev.lx_identifier IN ($idList) ORDER BY ev.lx_identifier"

try {
    $solvasResults = Invoke-Sqlcmd -ServerInstance "SOLVAS-SQL-D.mos.siepe.local,52156" -Database "solvas_am" -Query $solvasQuery -TrustServerCertificate -QueryTimeout 60
    Write-Host "  Solvas results: $($solvasResults.Count) rows" -ForegroundColor Green
} catch {
    Write-Host "  Solvas failed: $($_.Exception.Message)" -ForegroundColor Red
    $solvasResults = @()
}

Write-Host ""

# Delete old tabs and create new ones
Write-Host "Creating result tabs..." -ForegroundColor Yellow

$workbook.Worksheets | Where-Object { $_.Name -eq "MOS Query Results" } | ForEach-Object { $_.Delete() }
$mosTab = $workbook.Worksheets.Add()
$mosTab.Name = "MOS Query Results"

$mosTab.Cells.Item(1,1).Value2 = "Identifier"
$mosTab.Cells.Item(1,2).Value2 = "Position Mark"
$mosTab.Cells.Item(1,3).Value2 = "Vendor Bid"
$mosTab.Cells.Item(1,4).Value2 = "Vendor Name"
$mosTab.Cells.Item(1,5).Value2 = "Price Weighting %"
$mosTab.Range("A1:E1").Interior.Color = 15773696
$mosTab.Range("A1:E1").Font.Bold = $true

$row = 2
foreach ($r in $mosResults) {
    $mosTab.Cells.Item($row,1).Value2 = $r.identifier
    $mosTab.Cells.Item($row,2).Value2 = [decimal]$r.position_mark
    $mosTab.Cells.Item($row,3).Value2 = [decimal]$r.vendor_bid
    $mosTab.Cells.Item($row,4).Value2 = if($r.vendor_name){$r.vendor_name}else{"N/A"}
    $mosTab.Cells.Item($row,5).Value2 = $r.price_weighting
    $row++
}
$mosTab.UsedRange.Columns.AutoFit() | Out-Null

$workbook.Worksheets | Where-Object { $_.Name -eq "Solvas Query Results" } | ForEach-Object { $_.Delete() }
$solvasTab = $workbook.Worksheets.Add()
$solvasTab.Name = "Solvas Query Results"

$solvasTab.Cells.Item(1,1).Value2 = "Identifier"
$solvasTab.Cells.Item(1,2).Value2 = "Solvas Price"
$solvasTab.Cells.Item(1,3).Value2 = "Portfolio"
$solvasTab.Range("A1:C1").Interior.Color = 15773696
$solvasTab.Range("A1:C1").Font.Bold = $true

$row = 2
foreach ($r in $solvasResults) {
    $solvasTab.Cells.Item($row,1).Value2 = $r.identifier
    $solvasTab.Cells.Item($row,2).Value2 = [decimal]$r.solvas_price
    $solvasTab.Cells.Item($row,3).Value2 = if($r.portfolio){$r.portfolio}else{"N/A"}
    $row++
}
$solvasTab.UsedRange.Columns.AutoFit() | Out-Null

$workbook.Save()

Write-Host ""
Write-Host "COMPLETE!" -ForegroundColor Green
Write-Host "  MOS tab: $($mosResults.Count) rows" -ForegroundColor White
Write-Host "  Solvas tab: $($solvasResults.Count) rows" -ForegroundColor White
