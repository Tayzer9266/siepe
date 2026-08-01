# Debug Query Results - Check what's in the tabs

$excel = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
$workbook = $excel.Workbooks.Item(1)

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Checking Excel Tabs" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check MOS Query Results tab
try {
    $mosTab = $workbook.Worksheets.Item("MOS Query Results")
    $mosRows = $mosTab.UsedRange.Rows.Count
    $mosCols = $mosTab.UsedRange.Columns.Count
    
    Write-Host "MOS Query Results tab:" -ForegroundColor Yellow
    Write-Host "  Rows: $mosRows" -ForegroundColor White
    Write-Host "  Columns: $mosCols" -ForegroundColor White
    
    if ($mosRows -gt 1) {
        Write-Host "  ✓ Has data rows" -ForegroundColor Green
        Write-Host ""
        Write-Host "  First data row:" -ForegroundColor Cyan
        for ($c = 1; $c -le $mosCols; $c++) {
            $header = $mosTab.Cells.Item(1, $c).Value2
            $value = $mosTab.Cells.Item(2, $c).Value2
            Write-Host "    $header : $value" -ForegroundColor White
        }
    } else {
        Write-Host "  ❌ Only headers, no data rows" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ MOS Query Results tab not found" -ForegroundColor Red
}

Write-Host ""

# Check Solvas Query Results tab
try {
    $solvasTab = $workbook.Worksheets.Item("Solvas Query Results")
    $solvasRows = $solvasTab.UsedRange.Rows.Count
    $solvasCols = $solvasTab.UsedRange.Columns.Count
    
    Write-Host "Solvas Query Results tab:" -ForegroundColor Yellow
    Write-Host "  Rows: $solvasRows" -ForegroundColor White
    Write-Host "  Columns: $solvasCols" -ForegroundColor White
    
    if ($solvasRows -gt 1) {
        Write-Host "  ✓ Has data rows" -ForegroundColor Green
        Write-Host ""
        Write-Host "  First data row:" -ForegroundColor Cyan
        for ($c = 1; $c -le $solvasCols; $c++) {
            $header = $solvasTab.Cells.Item(1, $c).Value2
            $value = $solvasTab.Cells.Item(2, $c).Value2
            Write-Host "    $header : $value" -ForegroundColor White
        }
    } else {
        Write-Host "  ❌ Only headers, no data rows" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Solvas Query Results tab not found" -ForegroundColor Red
}
