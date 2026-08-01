$e = [Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
$wb = $e.Workbooks.Item(1)

Write-Host "=== WORKBOOK ANALYSIS ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Sheets:" -ForegroundColor Yellow
$wb.Worksheets | ForEach-Object { Write-Host "  - $($_.Name)" }

Write-Host ""
Write-Host "Checking 'MOS Marks That Don't Match Mark' sheet:" -ForegroundColor Yellow
try {
    $sheet = $wb.Worksheets.Item("MOS Marks That Don't Match Mark")
    $rows = $sheet.UsedRange.Rows.Count
    Write-Host "  Rows: $rows"
    
    Write-Host "  Row 1:" -ForegroundColor Cyan
    1..10 | ForEach-Object {
        $val = $sheet.Cells.Item(1, $_).Value2
        if ($val) { Write-Host "    Col $_ = $val" }
    }
    
    Write-Host "  Row 2:" -ForegroundColor Cyan
    1..10 | ForEach-Object {
        $val = $sheet.Cells.Item(2, $_).Value2
        if ($val) { Write-Host "    Col $_ = $val" }
    }
} catch {
    Write-Host "  Sheet not found" -ForegroundColor Red
}
