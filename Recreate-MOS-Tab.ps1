# Recreate MOS Query Results with correct database schema

Write-Host "Recreating MOS Query Results..." -ForegroundColor Cyan
Write-Host ""

# Kill Excel and reopen
Write-Host "[1/5] Restarting Excel..." -ForegroundColor Yellow
Get-Process -Name EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $true
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open((Resolve-Path ".\Output\PriceExceptionReport_20260713.xlsx").Path)

# Read identifiers from the data sheet
Write-Host "[2/5] Reading identifiers..." -ForegroundColor Yellow
$dataSheet = $workbook.Worksheets.Item("MOS Marks That Don't Match Mark")
$rows = $dataSheet.UsedRange.Rows.Count
$identifiers = @()

for ($r = 2; $r -le $rows; $r++) {
    $id = $dataSheet.Cells.Item($r, 6).Value2  # Column 6 = Primary Identifier
    if ($id) {
        $identifiers += $id.ToString().Trim()
    }
}

Write-Host "  Found $($identifiers.Count) identifiers" -ForegroundColor Green
Write-Host ""

# Load SQL module
Import-Module SqlServer -ErrorAction SilentlyContinue

# Build identifier list
$idList = ($identifiers | ForEach-Object { "'" + $_ + "'" }) -join ","

# Query MOS with CORRECT schema references
Write-Host "[3/5] Querying MOS database..." -ForegroundColor Yellow

# Use three-part naming: Database.Schema.Object
$mosQuery = "SELECT i.value as identifier, CAST(ISNULL(pm.position_mark, 0) as decimal(18,3)) as position_mark, CAST(ISNULL(ip.price, 0) as decimal(18,3)) as vendor_bid, r.name as vendor_name, CAST(ISNULL(pw.price_weighting_percentage, 100) as int) as price_weighting FROM Reference.dbo.vInstIdentifierCurrent i LEFT JOIN Core.dbo.vPositionMark pm ON i.inst_id = pm.inst_id LEFT JOIN Reference.dbo.vInstPriceCurrentRaw ip ON i.inst_id = ip.inst_id AND ip.data_source_name IN ('MarkIt', 'ICE') AND ip.data_set_name = 'Bid' LEFT JOIN Reference.dbo.vRefDataSource r ON r.RefDataSourceID = ip.RefDataSourceID LEFT JOIN Core.dbo.vPositionPriceWeightingActive pw ON i.inst_id = pw.inst_id WHERE i.value IN ($idList) ORDER BY i.value"

try {
    $mosResults = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" -Database "Reference" -Query $mosQuery -TrustServerCertificate -QueryTimeout 60
    Write-Host "  MOS: $($mosResults.Count) rows" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
    $mosResults = @()
}

Write-Host ""

# Delete and recreate MOS Query Results tab
Write-Host "[4/5] Creating MOS Query Results tab..." -ForegroundColor Yellow

$workbook.Worksheets | Where-Object { $_.Name -eq "MOS Query Results" } | ForEach-Object { $_.Delete() }
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
    $mosTab.Cells.Item($row,2).Value2 = if($r.position_mark){[decimal]$r.position_mark}else{0}
    $mosTab.Cells.Item($row,3).Value2 = if($r.vendor_bid){[decimal]$r.vendor_bid}else{0}
    $mosTab.Cells.Item($row,4).Value2 = if($r.vendor_name){$r.vendor_name}else{"N/A"}
    $mosTab.Cells.Item($row,5).Value2 = $r.price_weighting
    $row++
}

$mosTab.UsedRange.Columns.AutoFit() | Out-Null

Write-Host "  Created tab with $($mosResults.Count) data rows" -ForegroundColor Green
Write-Host ""

# Save
Write-Host "[5/5] Saving workbook..." -ForegroundColor Yellow
$workbook.Save()

Write-Host ""
Write-Host "COMPLETE!" -ForegroundColor Green
Write-Host "  MOS Query Results: $($mosResults.Count) rows" -ForegroundColor White
