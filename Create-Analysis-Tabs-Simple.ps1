# Create Analysis Tabs - Simple Version
# For TASK 83664 - Adds analysis tabs with 4 columns to Excel file

param([string]$ExcelFilePath = ".\Output\PriceExceptionReport_20260713.xlsx")

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Creating Analysis Tabs" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

$fullPath = (Resolve-Path $ExcelFilePath).Path
Write-Host "File: $fullPath`n" -ForegroundColor White

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $true
$excel.DisplayAlerts = $false

Write-Host "[1] Opening Excel..." -ForegroundColor Yellow
$workbook = $excel.Workbooks.Open($fullPath)
Write-Host "    ✓ Opened`n" -ForegroundColor Green

Write-Host "[2] Finding sheets to process..." -ForegroundColor Yellow
$sheetsToProcess = @()
foreach ($sheet in $workbook.Worksheets) {
    if ($sheet.Name -notmatch "Analysis|Filled") {
        $sheetsToProcess += $sheet
        Write-Host "    ✓ Will process: '$($sheet.Name)'" -ForegroundColor White
    }
}
Write-Host ""

$count = 0
foreach ($sourceSheet in $sheetsToProcess) {
    $count++
    $analysisName = "$($sourceSheet.Name) - Analysis"
    
    Write-Host "[$($count + 2)] Creating '$analysisName'..." -ForegroundColor Yellow
    
    # Delete existing analysis tab if present
    foreach ($sheet in $workbook.Worksheets) {
        if ($sheet.Name -eq $analysisName) {
            $sheet.Delete()
            break
        }
    }
    
    # Create new tab
    $analysisSheet = $workbook.Worksheets.Add()
    $analysisSheet.Name = $analysisName
    
    # Copy data
    $sourceRange = $sourceSheet.UsedRange
    $rowCount = $sourceRange.Rows.Count
    $colCount = $sourceRange.Columns.Count
    
    $sourceRange.Copy()
    $analysisSheet.Range("A1").PasteSpecial(-4163)
    $excel.CutCopyMode = $false
    
    # Add 4 analysis column headers
    $newCol = $colCount + 1
    $analysisSheet.Cells.Item(1, $newCol).Value2 = "Position Mark Mismatch"
    $analysisSheet.Cells.Item(1, $newCol + 1).Value2 = "Solvas Price Mismatch"
    $analysisSheet.Cells.Item(1, $newCol + 2).Value2 = "Bid Price on MOS"
    $analysisSheet.Cells.Item(1, $newCol + 3).Value2 = "Active Price Weighting"
    
    # Format headers green
    $headerRange = $analysisSheet.Range($analysisSheet.Cells.Item(1, $newCol), $analysisSheet.Cells.Item(1, $newCol + 3))
    $headerRange.Interior.Color = 5287936
    $headerRange.Font.Bold = $true
    
    # Fill with pending markers
    for ($row = 2; $row -le $rowCount; $row++) {
        $analysisSheet.Cells.Item($row, $newCol).Value2 = "(analysis pending)"
        $analysisSheet.Cells.Item($row, $newCol + 1).Value2 = "(analysis pending)"
        $analysisSheet.Cells.Item($row, $newCol + 2).Value2 = "(analysis pending)"
        $analysisSheet.Cells.Item($row, $newCol + 3).Value2 = "(analysis pending)"
    }
    
    $analysisSheet.UsedRange.Columns.AutoFit() | Out-Null
    Write-Host "    ✓ Done ($rowCount rows, 4 new columns)`n" -ForegroundColor Green
}

Write-Host "[FINAL] Saving..." -ForegroundColor Yellow
$workbook.Save()
Write-Host "        ✓ Saved!`n" -ForegroundColor Green

# Activate first analysis tab
if ($sheetsToProcess.Count -gt 0) {
    $firstAnalysis = "$($sheetsToProcess[0].Name) - Analysis"
    $workbook.Worksheets.Item($firstAnalysis).Activate()
}

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✅ SUCCESS! Created $count analysis tabs" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "`nExcel is open - review the new ' - Analysis' tabs" -ForegroundColor Yellow
Write-Host "File saved: $fullPath`n" -ForegroundColor White
