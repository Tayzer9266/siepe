# Fill Analysis Columns with Real Database Data
# Quick script to populate the 4 analysis columns

Write-Host "Connecting to Excel..." -ForegroundColor Cyan

$excel = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
$workbook = $excel.Workbooks.Item(1)
$sheet = $workbook.Worksheets.Item("MOS Analysis - Analysis")

Write-Host "Sheet: $($sheet.Name)" -ForegroundColor Green
Write-Host "Rows: $($sheet.UsedRange.Rows.Count)" -ForegroundColor White
Write-Host "Columns: $($sheet.UsedRange.Columns.Count)" -ForegroundColor White
Write-Host ""

# Get column positions (last 4 columns)
$totalCols = $sheet.UsedRange.Columns.Count
$colPosMark = $totalCols - 3
$colSolvas = $totalCols - 2  
$colBidPrice = $totalCols - 1
$colWeighting = $totalCols

Write-Host "Filling columns: $colPosMark, $colSolvas, $colBidPrice, $colWeighting" -ForegroundColor Yellow
Write-Host ""

# Get CUSIPs
$rows = $sheet.UsedRange.Rows.Count
$cusips = @()
for ($r = 2; $r -le $rows; $r++) {
    $c = $sheet.Cells.Item($r, 1).Value2
    if ($c) { $cusips += "'$c'" }
}

Write-Host "Querying MOS for $($cusips.Count) secur85689ities..." -ForegroundColor Cyan

$cusipList = $cusips -join ","
$mosServer = "mos-sql-p.mos.siepe.local,52155"

$query = @"
SELECT i.cusip,
       ISNULL(pm.position_mark, 0) as position_mark,
       ISNULL(ip.price, 0) as bid_price,
       ISNULL(pw.price_weighting_percentage, 100) as price_weighting
FROM Reference.vInstIdentifierCurrent i
LEFT JOIN Core.vPositionMark pm ON i.inst_id = pm.inst_id
LEFT JOIN Reference.vInstPriceCurrentRaw ip ON i.inst_id = ip.inst_id AND ip.data_source_name = 'MarkIt' AND ip.data_set_name = 'Bid'
LEFT JOIN Core.vPositionPriceWeightingActive pw ON i.inst_id = pw.inst_id
WHERE i.cusip IN ($cusipList)
"@

$results = Invoke-Sqlcmd -ServerInstance $mosServer -Database "MOS" -Query $query -TrustServerCertificate

Write-Host "Got $($results.Count) results" -ForegroundColor Green
Write-Host ""

# Create lookup
$lookup = @{}
foreach ($r in $results) {
    $lookup[$r.cusip] = $r
}

Write-Host "Filling Excel cells..." -ForegroundColor Yellow

$filled = 0
for ($row = 2; $row -le $rows; $row++) {
    $cusip = $sheet.Cells.Item($row, 1).Value2
    if (!$cusip) { continue }
    
    $data = $lookup[$cusip]
    if (!$data) { continue }
    
    $posMark = [decimal]$data.position_mark
    $bidPrice = [decimal]$data.bid_price
    $weighting = $data.price_weighting
    
    # Check mismatch
    $mismatch = if ([Math]::Abs($posMark - $bidPrice) -gt 0.001) { "YES" } else { "NO" }
    
    # Fill cells
    $sheet.Cells.Item($row, $colPosMark).Value2 = $mismatch
    $sheet.Cells.Item($row, $colSolvas).Value2 = "N/A"  # Solvas query separate
    $sheet.Cells.Item($row, $colBidPrice).Value2 = $bidPrice.ToString("F3")
    $sheet.Cells.Item($row, $colWeighting).Value2 = "$weighting%"
    
    # Highlight mismatches
    if ($mismatch -eq "YES") {
        $sheet.Cells.Item($row, $colPosMark).Interior.Color = 65535
    }
    
    $filled++
    if ($filled % 20 -eq 0) {
        Write-Host "  Filled $filled rows..." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Saving..." -ForegroundColor Yellow
$workbook.Save()

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "Filled $filled rows" -ForegroundColor White
Write-Host "Check Excel now!" -ForegroundColor Cyan
