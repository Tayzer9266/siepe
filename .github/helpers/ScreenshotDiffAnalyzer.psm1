# Screenshot Diff Analyzer
# Version: 1.0
# Date: 2026-07-28
# Purpose: Compare before/after screenshots to detect visual changes and regressions

<#
.SYNOPSIS
Compare two screenshots and identify differences

.DESCRIPTION
Uses AI vision to analyze two screenshots and describe visual differences. Useful for before/after comparisons in bug fixes and regression testing.

.PARAMETER BeforeImagePath
Path to the "before" screenshot

.PARAMETER AfterImagePath
Path to the "after" screenshot

.PARAMETER ComparisonType
Type of comparison (Bug Fix, Regression Test, Configuration Change, Data Update)

.EXAMPLE
$diff = Compare-Screenshots -BeforeImagePath "before.png" -AfterImagePath "after.png" -ComparisonType "Bug Fix"
#>
function Compare-Screenshots {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$BeforeImagePath,
        
        [Parameter(Mandatory=$true)]
        [string]$AfterImagePath,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Bug Fix", "Regression Test", "Configuration Change", "Data Update", "General")]
        [string]$ComparisonType = "General"
    )
    
    # Validate image files exist
    if (-not (Test-Path $BeforeImagePath)) {
        Write-Error "Before image not found: $BeforeImagePath"
        return $null
    }
    
    if (-not (Test-Path $AfterImagePath)) {
        Write-Error "After image not found: $AfterImagePath"
        return $null
    }
    
    Write-Host "Analyzing before screenshot..." -ForegroundColor Cyan
    # Note: AI vision analysis would be invoked here by the agent
    # For now, return a structured template
    
    $comparison = @{
        BeforeImage = $BeforeImagePath
        AfterImage = $AfterImagePath
        ComparisonType = $ComparisonType
        AnalysisDate = Get-Date
        Differences = @()
        Similarities = @()
        Verdict = $null
        Notes = @()
    }
    
    # Template for agent to fill in via view_image tool
    $comparison.Notes += "AGENT TODO: Use view_image tool to analyze $BeforeImagePath"
    $comparison.Notes += "AGENT TODO: Use view_image tool to analyze $AfterImagePath"
    $comparison.Notes += "AGENT TODO: Compare the two analyses and populate Differences array"
    
    return $comparison
}

<#
.SYNOPSIS
Generate diff report for screenshot comparison

.DESCRIPTION
Creates a markdown report documenting visual differences between before/after screenshots

.PARAMETER Comparison
Comparison object from Compare-Screenshots

.PARAMETER OutputPath
Path to save the diff report

.EXAMPLE
$diff = Compare-Screenshots -BeforeImagePath "before.png" -AfterImagePath "after.png"
New-ScreenshotDiffReport -Comparison $diff
#>
function New-ScreenshotDiffReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Comparison,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputPath
    )
    
    # Generate default output path
    if (-not $OutputPath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $OutputPath = "C:\source\MD\AdminTools\Output\Screenshot_Diff_${timestamp}.md"
    }
    
    $markdown = @()
    
    # Header
    $markdown += "# Screenshot Comparison Report"
    $markdown += "**Type:** $($Comparison.ComparisonType)  "
    $markdown += "**Analysis Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  "
    $markdown += ""
    $markdown += "---"
    $markdown += ""
    
    # Before Screenshot
    $markdown += "## Before Screenshot"
    $markdown += ""
    $beforeFilename = Split-Path $Comparison.BeforeImage -Leaf
    $markdown += "**File:** $beforeFilename  "
    $markdown += ""
    $markdown += "![Before]($($Comparison.BeforeImage))"
    $markdown += ""
    
    # After Screenshot
    $markdown += "## After Screenshot"
    $markdown += ""
    $afterFilename = Split-Path $Comparison.AfterImage -Leaf
    $markdown += "**File:** $afterFilename  "
    $markdown += ""
    $markdown += "![After]($($Comparison.AfterImage))"
    $markdown += ""
    
    # Differences
    $markdown += "## Differences Detected"
    $markdown += ""
    
    if ($Comparison.Differences.Count -gt 0) {
        foreach ($diff in $Comparison.Differences) {
            $markdown += "- **$($diff.Category):** $($diff.Description)"
        }
    } else {
        $markdown += "*No differences detected or analysis pending*"
    }
    $markdown += ""
    
    # Similarities
    $markdown += "## Unchanged Elements"
    $markdown += ""
    
    if ($Comparison.Similarities.Count -gt 0) {
        foreach ($sim in $Comparison.Similarities) {
            $markdown += "- $sim"
        }
    } else {
        $markdown += "*Analysis pending*"
    }
    $markdown += ""
    
    # Verdict
    $markdown += "## Verdict"
    $markdown += ""
    
    if ($Comparison.Verdict) {
        $markdown += $Comparison.Verdict
    } else {
        $markdown += "*Verdict pending analysis*"
    }
    $markdown += ""
    
    # Notes
    if ($Comparison.Notes.Count -gt 0) {
        $markdown += "## Notes"
        $markdown += ""
        foreach ($note in $Comparison.Notes) {
            $markdown += "- $note"
        }
        $markdown += ""
    }
    
    # Footer
    $markdown += "---"
    $markdown += "**Report Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # Save report
    $markdown | Out-File $OutputPath -Encoding UTF8
    
    Write-Host "Screenshot diff report saved: $OutputPath" -ForegroundColor Green
    
    return $OutputPath
}

<#
.SYNOPSIS
Batch compare multiple screenshot pairs

.DESCRIPTION
Compares multiple before/after screenshot pairs for regression testing

.PARAMETER ScreenshotPairs
Array of hashtables with BeforeImage and AfterImage paths

.PARAMETER OutputDirectory
Directory to save diff reports (defaults to Output folder)

.EXAMPLE
$pairs = @(
    @{ BeforeImage = "test1_before.png"; AfterImage = "test1_after.png" },
    @{ BeforeImage = "test2_before.png"; AfterImage = "test2_after.png" }
)
Start-BatchScreenshotComparison -ScreenshotPairs $pairs
#>
function Start-BatchScreenshotComparison {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$ScreenshotPairs,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputDirectory = "C:\source\MD\AdminTools\Output"
    )
    
    $results = @()
    $index = 1
    
    foreach ($pair in $ScreenshotPairs) {
        Write-Host "[$index/$($ScreenshotPairs.Count)] Comparing: $($pair.BeforeImage) vs $($pair.AfterImage)" -ForegroundColor Cyan
        
        $comparison = Compare-Screenshots `
            -BeforeImagePath $pair.BeforeImage `
            -AfterImagePath $pair.AfterImage `
            -ComparisonType "Regression Test"
        
        if ($comparison) {
            $reportPath = Join-Path $OutputDirectory "Diff_Report_$index.md"
            $savedReport = New-ScreenshotDiffReport -Comparison $comparison -OutputPath $reportPath
            
            $results += @{
                Index = $index
                BeforeImage = $pair.BeforeImage
                AfterImage = $pair.AfterImage
                ReportPath = $savedReport
                Comparison = $comparison
            }
        }
        
        $index++
    }
    
    # Generate summary
    Write-Host "`nBatch comparison complete: $($results.Count) pairs processed" -ForegroundColor Green
    
    return $results
}

<#
.SYNOPSIS
Detect visual regression by comparing UI screenshots

.DESCRIPTION
Specialized function for UI regression testing. Identifies unexpected visual changes in user interfaces.

.PARAMETER BaselineImage
Path to baseline (expected) screenshot

.PARAMETER CurrentImage
Path to current (actual) screenshot

.PARAMETER Tolerance
Tolerance level for differences (Low, Medium, High)

.EXAMPLE
$regression = Test-VisualRegression -BaselineImage "baseline.png" -CurrentImage "current.png" -Tolerance "Medium"
#>
function Test-VisualRegression {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$BaselineImage,
        
        [Parameter(Mandatory=$true)]
        [string]$CurrentImage,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Low", "Medium", "High")]
        [string]$Tolerance = "Medium"
    )
    
    $comparison = Compare-Screenshots `
        -BeforeImagePath $BaselineImage `
        -AfterImagePath $CurrentImage `
        -ComparisonType "Regression Test"
    
    # Add regression-specific analysis
    $regression = @{
        Passed = $null  # To be determined by agent analysis
        Tolerance = $Tolerance
        Comparison = $comparison
        RegressionIssues = @()
        AcceptableChanges = @()
    }
    
    # Template for agent to fill in
    $regression.RegressionIssues += "AGENT TODO: Identify unexpected UI changes"
    $regression.AcceptableChanges += "AGENT TODO: Identify expected/minor differences"
    
    return $regression
}

# Export functions
Export-ModuleMember -Function @(
    'Compare-Screenshots',
    'New-ScreenshotDiffReport',
    'Start-BatchScreenshotComparison',
    'Test-VisualRegression'
)
