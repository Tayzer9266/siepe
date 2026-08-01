# Fix Query Results - Get Real Data from Databases
# This script will properly query MOS and Solvas databases and fill the tabs

param(
    [string]$ExcelPath = ".\Output\PriceExceptionReport_20260713.xlsx"
)

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Fix Query Results - Get Real Database Data" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Kill Excel and reopen
Write-Host "[1/6] Closing Excel processes..." -ForegroundColor Yellow
Get-Process -Name EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Write-Host "  ✓ Done" -ForegroundColor Green
Write-Host ""

# Step 2: Open Excel
Write-Host "[2/6] Opening Excel file..." -ForegroundColor Yellow
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $true
$excel.DisplayAlerts = $false
$workbook = $excel.Workbooks.Open((Resolve-Path $ExcelPath).Path)
$mainSheet = $workbook.Worksheets.Item("MOS Analysis")
Write-Host "  ✓ File opened" -ForegroundColor Green
Write-Host ""

# Step 3: Read identifiers from Excel
Write-Host "[3/6] Reading identifiers from Excel..." -ForegroundColor Yellow
$rows = $mainSheet.UsedRange.Rows.Count
Write-Host "  Total rows in sheet: $($rows - 1)" -ForegroundColor White

# Examine first row to find identifier column
$headers = @{}
for ($c = 1; $c -le 20; $c++) {
    $header = $mainSheet.Cells.Item(1, $c).Value2
    if ($header) {
        $headers[$c] = $header
        Write-Host "  Column $c : $header" -ForegroundColor Gray
    }
}

# Find the identifier column (look for CUSIP, Identifier, LX, etc.)
$idColumn = 0
foreach ($col in $headers.Keys) {
    $header = $headers[$col]
    if ($header -match "identifier|cusip|security|lx|isin") {
        $idColumn = $col
        Write-Host "  ✓ Found identifier column: $col ($header)" -ForegroundColor Green
        break
    }
}

if ($idColumn -eq 0) {
    Write-Host "  ⚠ Could not find identifier column, using column 1" -ForegroundColor Yellow
    $idColumn = 1
}

# Read all identifiers
$identifiers = @()
for ($r = 2; $r -le $rows; $r++) {
    $id = $mainSheet.Cells.Item($r, $idColumn).Value2
    if ($id -and $id -ne "" -and $id -ne $null) {
        $identifiers += $id.ToString().Trim()
    }
}

Write-Host "  ✓ Found $($identifiers.Count) identifiers" -ForegroundColor Green
Write-Host "  Sample: $($identifiers[0]), $($identifiers[1]), $($identifiers[2])..." -ForegroundColor Gray
Write-Host ""

# Step 4: Load SQL module
Write-Host "[4/6] Loading SQL module..." -ForegroundColor Yellow
Import-Module SqlServer -ErrorAction SilentlyContinue
if (-not (Get-Module SqlServer)) {
    Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck | Out-Null
    Import-Module SqlServer
}
Write-Host "  ✓ SQL module loaded" -ForegroundColor Green
Write-Host ""

# Step 5: Query databases
Write-Host "[5/6] Querying databases..." -ForegroundColor Yellow

# Build identifier list for SQL IN clause
$idList = ($identifiers | ForEach-Object { "'$_'" }) -join ","

# MOS Query - try with actual identifier values
Write-Host "  Running MOS query..." -ForegroundColor Cyan
$mosQuery = @"
SELECT TOP 100
    i.value as identifier,
    CAST(ISNULL(pm.position_mark, 0) as decimal(18,3)) as position_mark,
    CAST(ISNULL(ip.price, 0) as decimal(18,3)) as vendor_bid,
    r.name as vendor_name,
    CAST(ISNULL(pw.price_weighting_percentage, 100) as int) as price_weighting
FROM Reference.dbo.vInstIdentifierCurrent i
LEFT JOIN Core.dbo.vPositionMark pm ON i.inst_id = pm.inst_id
LEFT JOIN Reference.dbo.vInstPriceCurrentRaw ip ON i.inst_id = ip.inst_id 
LEFT JOIN Reference.dbo.vRefDataSource r ON r.RefDataSourceID = ip.RefDataSourceID
LEFT JOIN Core.dbo.vPositionPriceWeightingActive pw ON i.inst_id = pw.inst_id
WHERE i.value IN ($idList)
ORDER BY i.value
"@


try {
    $mosResults = Invoke-Sqlcmd -ServerInstance "mos-sql-p.mos.siepe.local,52155" `
        -Database "Reference" `
        -Query $mosQuery `
        -TrustServerCertificate `
        -QueryTimeout 60 `
        -ErrorAction Stop
    
    Write-Host "    ✓ MOS: $($mosResults.Count) results" -ForegroundColor Green
} catch {
    Write-Host "    ❌ MOS query failed: $($_.Exception.Message)" -ForegroundColor Red
    $mosResults = @()
}

# Solvas Query
Write-Host "  Running Solvas query..." -ForegroundColor Cyan
$solvasQuery = @"
SELECT TOP 100
    ev.lx_identifier as identifier,
    CAST(d.pricing_type_1 * 100 as decimal(18,3)) as solvas_price,
    e.deal_name as portfolio
FROM solvas_am.dbo.deal_facility_market_value d
JOIN solvas_am.dbo.entity e ON e.entity_id = d.entity_id
JOIN solvas_am.dbo.Entity_Issue_view ev ON COALESCE(ev.facility_id, ev.Issue_id) = d.facility_id 
    AND ev.entity_id = e.entity_id
WHERE ev.lx_identifier IN ($idList)
ORDER BY ev.lx_identifier
"@

try {
    $solvasResults = Invoke-Sqlcmd -ServerInstance "SOLVAS-SQL-D.mos.siepe.local,52156" `
        -Database "solvas_am" `
        -Query $solvasQuery `
        -TrustServerCertificate `
        -QueryTimeout 60 `
        -ErrorAction Stop
    
    Write-Host "    ✓ Solvas: $($solvasResults.Count) results" -ForegroundColor Green
} catch {
    Write-Host "    ❌ Solvas query failed: $($_.Exception.Message)" -ForegroundColor Red
    $solvasResults = @()
}

Write-Host ""

# Step 6: Fill Excel tabs
Write-Host "[6/6] Filling Excel tabs..." -ForegroundColor Yellow

# Clear and refill MOS tab
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
Write-Host "  ✓ MOS tab filled with $($mosResults.Count) rows" -ForegroundColor Green

# Clear and refill Solvas tab
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
Write-Host "  ✓ Solvas tab filled with $($solvasResults.Count) rows" -ForegroundColor Green

$workbook.Save()

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ COMPLETE!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "Results:" -ForegroundColor Cyan
Write-Host "  MOS Query Results: $($mosResults.Count) rows" -ForegroundColor White
Write-Host "  Solvas Query Results: $($solvasResults.Count) rows" -ForegroundColor White
Write-Host ""

if ($mosResults.Count -eq 0 -or $solvasResults.Count -eq 0) {
    Write-Host "⚠️ WARNING: Some queries returned no data!" -ForegroundColor Yellow
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "  - Database permissions issue" -ForegroundColor Gray
    Write-Host "  - Identifiers don't exist in database" -ForegroundColor Gray
    Write-Host "  - Schema/table name incorrect" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Check Excel tabs to see sample structure for VLOOKUP" -ForegroundColor Cyan
}
