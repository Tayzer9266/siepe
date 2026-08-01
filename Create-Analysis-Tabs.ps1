# Create Analysis Tabs - Complete Solution for TASK 83664
# Creates new analysis tabs with data + 4 analysis columns

param(
    [string]$ExcelFilePath = ".\Output\PriceExceptionReport_20260713.xlsx"
)

Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Creating Analysis Tabs for Excel File" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

$fullPath = Resolve-Path $ExcelFilePath
Write-Host "File: $($fullPath.Path)" -ForegroundColor White
Write-Host ""

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $true
$excel.DisplayAlerts = $false

try {
    Write-Host "[1] Opening workbook..." -ForegroundColor Yellow
    $workbook = $excel.Workbooks.Open($fullPath.Path)
    Write-Host "    ✓ Opened" -ForegroundColor Green
    Write-Host ""
    
    # Get list of sheets to process (exclude ones with "Analysis" or "Filled" in name)
    Write-Host "[2] Finding sheets to analyze..." -ForegroundColor Yellow
    $sheetsToProcess = @()
    foreach ($sheet in $workbook.Worksheets) {
        if ($sheet.Name -notlike "*Analysis*" -and $sheet.Name -notlike "*Filled*") {
            $sheetsToProcess += $sheet
            Write-Host "    ✓ Will process: '$($sheet.Name)'" -ForegroundColor White
        } else {
            Write-Host "    - Skipping: '$($sheet.Name)' (already processed)" -ForegroundColor Gray
        }
    }
    Write-Host ""
    
    # Process each sheet
    $processedCount = 0
    foreach ($sourceSheet in $sheetsToProcess) {
        $processedCount++
        $analysisName = "$($sourceSheet.Name) - Analysis"
        
        Write-Host "[$($processedCount + 2)] Processing: '$($sourceSheet.Name)'" -ForegroundColor Yellow
        
        # Check if analysis tab already exists and delete it
        $workbook.Worksheets | ForEach-Object {
            if ($_.Name -eq $analysisName) {
                Write-Host "    - Analysis tab already exists, deleting old version..." -ForegroundColor Gray
                $_.Delete()
            }
        }
        
        # Create new analysis sheet
        Write-Host "    ✓ Creating tab: '$analysisName'" -ForegroundColor White
        $analysisSheet = $workbook.Worksheets.Add()
        $analysisSheet.Name = $analysisName
        
        # Copy all data
        Write-Host "    ✓ Copying data..." -ForegroundColor White
        $sourceRange = $sourceSheet.UsedRange
        $rowCount = $sourceRange.Rows.Count
        $colCount = $sourceRange.Columns.Count
        
        $sourceRange.Copy()
        $analysisSheet.Range("A1").PasteSpecial(-4163) # xlPasteAll
        $excel.CutCopyMode = $false
        
        # Add 4 analysis columns
        Write-Host "    ✓ Adding analysis columns..." -ForegroundColor White
        $newColStart = $colCount + 1
        $analysisSheet.Cells.Item(1, $newColStart).Value2 = "Position Mark Mismatch"
        $analysisSheet.Cells.Item(1, $newColStart + 1).Value2 = "Solvas Price Mismatch"
        $analysisSheet.Cells.Item(1, $newColStart + 2).Value2 = "Bid Price on MOS"
        $analysisSheet.Cells.Item(1, $newColStart + 3).Value2 = "Active Price Weighting"
        
        # Format headers
        $headerRange = $analysisSheet.Range(
            $analysisSheet.Cells.Item(1, $newColStart), 
            $analysisSheet.Cells.Item(1, $newColStart + 3)
        )
        $headerRange.Interior.Color = 5287936  # Green
        $headerRange.Font.Bold = $true
        
        # Fill with pending markers
        Write-Host "    ✓ Filling $($rowCount - 1) rows with pending markers..." -ForegroundColor White
        for ($row = 2; $row -le $rowCount; $row++) {
            $analysisSheet.Cells.Item($row, $newColStart).Value2 = "(analysis pending)"
            $analysisSheet.Cells.Item($row, $newColStart + 1).Value2 = "(analysis pending)"
            $analysisSheet.Cells.Item($row, $newColStart + 2).Value2 = "(analysis pending)"
            $analysisSheet.Cells.Item($row, $newColStart + 3).Value2 = "(analysis pending)"
        }
        
        # Auto-fit
        $analysisSheet.UsedRange.Columns.AutoFit() | Out-Null
        
        Write-Host "    ✓ Complete!" -ForegroundColor Green
        Write-Host ""
    }
    
    # Save the workbook
    Write-Host "[FINAL] Saving workbook..." -ForegroundColor Yellow
    $workbook.Save()
    Write-Host "        ✓ Saved!" -ForegroundColor Green
    Write-Host ""
    
    # Activate first analysis sheet
    if ($sheetsToProcess.Count -gt 0) {
        $firstAnalysisName = "$($sheetsToProcess[0].Name) - Analysis"
        $workbook.Worksheets.Item($firstAnalysisName).Activate()
    }
    
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✅ SUCCESS!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Created $processedCount analysis tabs" -ForegroundColor White
    Write-Host "Excel is open - review the new tabs ending in ' - Analysis'" -ForegroundColor Yellow
    Write-Host "File saved: $($fullPath.Path)" -ForegroundColor White
    Write-Host ""
    Write-Host "Press any key to close Excel, or manually close when done..." -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
} finally {
    # Don't auto-close - let user review
    Write-Host ""
}
