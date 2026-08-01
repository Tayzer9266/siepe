# Cleanup Excel Tabs and Add Date to Solvas Results

Write-Host "Cleaning up Excel workbook..." -ForegroundColor Cyan
Write-Host ""

# Get active Excel instance
$excel = [Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
$workbook = $excel.Workbooks.Item(1)

# Step 1: Delete unwanted sheets
Write-Host "[1/2] Removing unwanted sheets..." -ForegroundColor Yellow

$sheetsToRemove = @("MOS Null Marks - Analysis", "Sheet1", "Sheet3")

foreach ($sheetName in $sheetsToRemove) {
    try {
        $sheet = $workbook.Worksheets.Item($sheetName)
        $sheet.Delete()
        Write-Host "  OK Removed: $sheetName" -ForegroundColor Green
    } catch {
        Write-Host "  Could not find: $sheetName" -ForegroundColor Gray
    }
}

Write-Host ""

# Step 2: Add date column to Solvas Query Results
Write-Host "[2/2] Adding date column to Solvas Query Results..." -ForegroundColor Yellow

try {
    $solvasTab = $workbook.Worksheets.Item("Solvas Query Results")
    
    # Check if tab has data
    $rowCount = $solvasTab.UsedRange.Rows.Count
    Write-Host "  Current rows: $rowCount" -ForegroundColor Gray
    
    # Insert a new column at position 2 (between Identifier and Solvas Price)
    $solvasTab.Columns(2).Insert() | Out-Null
    
    # Set the header
    $solvasTab.Cells.Item(1, 2).Value2 = "Price Date"
    $solvasTab.Cells.Item(1, 2).Font.Bold = $true
    $solvasTab.Cells.Item(1, 2).Interior.Color = 15773696
    
    # Get the date from the main data sheet (use 6/15/2026 based on ticket info)
    $priceDate = "6/15/2026"
    
    # Fill the date for all data rows
    for ($row = 2; $row -le $rowCount; $row++) {
        $solvasTab.Cells.Item($row, 2).Value2 = $priceDate
    }
    
    # Adjust column width
    $solvasTab.Columns(2).AutoFit() | Out-Null
    
    Write-Host "  OK Added Price Date column with date: $priceDate" -ForegroundColor Green
    Write-Host "  Column order now: Identifier, Price Date, Solvas Price, Portfolio" -ForegroundColor Cyan
    
} catch {
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Save workbook
$workbook.Save()

Write-Host "COMPLETE!" -ForegroundColor Green
Write-Host ""
Write-Host "Remaining sheets:" -ForegroundColor Cyan
foreach ($ws in $workbook.Worksheets) {
    Write-Host "  - $($ws.Name)" -ForegroundColor White
}
