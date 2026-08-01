# Visual Investigation Report Generator
# Version: 1.0
# Date: 2026-07-28
# Purpose: Generate enhanced Markdown reports with embedded screenshots and visual evidence

<#
.SYNOPSIS
Generate investigation report with embedded screenshots

.DESCRIPTION
Creates a comprehensive markdown investigation report with inline images, screenshot analysis, and visual evidence sections

.PARAMETER TicketId
Azure DevOps ticket ID

.PARAMETER Title
Report title

.PARAMETER Sections
Hashtable of report sections with content

.PARAMETER Screenshots
Array of screenshot objects with paths and analysis

.PARAMETER OutputPath
Path to save the report (defaults to Output folder)

.EXAMPLE
$screenshots = @(
    @{ Path = "screenshot1.png"; Analysis = "SQL error shown"; Type = "SQL Error" }
)
$sections = @{
    "Problem" = "Database timeout occurred"
    "Root Cause" = "Missing index on tPrice table"
    "Resolution" = "Created index on CUSIP column"
}
New-VisualInvestigationReport -TicketId 12345 -Title "Database Performance Issue" `
    -Sections $sections -Screenshots $screenshots
#>
function New-VisualInvestigationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$TicketId,
        
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$Sections,
        
        [Parameter(Mandatory=$false)]
        [array]$Screenshots = @(),
        
        [Parameter(Mandatory=$false)]
        [string]$OutputPath
    )
    
    # Generate default output path if not provided
    if (-not $OutputPath) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $sanitizedTitle = $Title -replace '[^a-zA-Z0-9]', '_'
        $OutputPath = "C:\source\MD\AdminTools\Output\Investigation_${TicketId}_${sanitizedTitle}_${timestamp}.md"
    }
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Build markdown report
    $markdown = @()
    
    # Header
    $markdown += "# Investigation Report: $Title"
    $markdown += "**Ticket:** #$TicketId  "
    $markdown += "**Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  "
    $markdown += "**Investigator:** Mossy (AI Agent)  "
    $markdown += ""
    $markdown += "---"
    $markdown += ""
    
    # Screenshot Analysis Section (if screenshots provided)
    if ($Screenshots.Count -gt 0) {
        $markdown += "## 📸 Visual Evidence"
        $markdown += ""
        
        foreach ($screenshot in $Screenshots) {
            $filename = Split-Path $screenshot.Path -Leaf
            $relPath = Get-RelativePath -From $outputDir -To $screenshot.Path
            
            $markdown += "### Screenshot: $filename"
            if ($screenshot.Type) {
                $markdown += "**Type:** $($screenshot.Type)"
            }
            $markdown += ""
            
            # Embed image
            $markdown += "![Screenshot]($relPath)"
            $markdown += ""
            
            # Analysis
            if ($screenshot.Analysis) {
                $markdown += "**Analysis:**"
                $markdown += $screenshot.Analysis
                $markdown += ""
            }
            
            # Extracted data (if available)
            if ($screenshot.ExtractedData) {
                $markdown += "**Extracted Data:**"
                $markdown += "```"
                $markdown += ($screenshot.ExtractedData | ConvertTo-Json -Depth 5)
                $markdown += "```"
                $markdown += ""
            }
            
            $markdown += "---"
            $markdown += ""
        }
    }
    
    # Investigation Sections
    foreach ($sectionName in $Sections.Keys | Sort-Object) {
        $markdown += "## $sectionName"
        $markdown += ""
        $markdown += $Sections[$sectionName]
        $markdown += ""
    }
    
    # Footer
    $markdown += "---"
    $markdown += ""
    $markdown += "**Report Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $markdown += "**Tool:** Mossy Investigation Agent v2.0"
    
    # Save report
    $markdown | Out-File $OutputPath -Encoding UTF8
    
    Write-Host "Visual investigation report saved: $OutputPath" -ForegroundColor Green
    
    return $OutputPath
}

<#
.SYNOPSIS
Get relative path between two paths

.DESCRIPTION
Calculates the relative path from one location to another for markdown links

.PARAMETER From
Source path (usually the markdown file location)

.PARAMETER To
Target path (usually the image location)

.EXAMPLE
$rel = Get-RelativePath -From "C:\Reports\report.md" -To "C:\Images\screenshot.png"
#>
function Get-RelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,
        
        [Parameter(Mandatory=$true)]
        [string]$To
    )
    
    # Normalize paths
    $fromPath = (Resolve-Path $From -ErrorAction SilentlyContinue).Path
    $toPath = (Resolve-Path $To -ErrorAction SilentlyContinue).Path
    
    if (-not $fromPath -or -not $toPath) {
        # If paths can't be resolved, return absolute path
        return $To
    }
    
    # For simplicity, use absolute path for now
    # TODO: Implement proper relative path calculation
    return $toPath
}

<#
.SYNOPSIS
Create summary visualization for multiple investigations

.DESCRIPTION
Generates an index page with thumbnails and summaries of multiple investigation reports

.PARAMETER ReportPaths
Array of investigation report markdown file paths

.PARAMETER OutputPath
Path to save the summary index (defaults to Output/Investigation_Index.md)

.EXAMPLE
$reports = @("Investigation_12345.md", "Investigation_12346.md")
New-InvestigationSummary -ReportPaths $reports
#>
function New-InvestigationSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$ReportPaths,
        
        [Parameter(Mandatory=$false)]
        [string]$OutputPath = "C:\source\MD\AdminTools\Output\Investigation_Index.md"
    )
    
    $markdown = @()
    
    # Header
    $markdown += "# Mossy Investigation Summary"
    $markdown += "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  "
    $markdown += "**Total Investigations:** $($ReportPaths.Count)  "
    $markdown += ""
    $markdown += "---"
    $markdown += ""
    
    # Table of contents
    $markdown += "## Investigation Reports"
    $markdown += ""
    $markdown += "| # | Ticket | Title | Date | Status |"
    $markdown += "|---|--------|-------|------|--------|"
    
    $index = 1
    foreach ($reportPath in $ReportPaths) {
        if (Test-Path $reportPath) {
            # Extract metadata from report
            $content = Get-Content $reportPath -Raw
            
            $ticketMatch = [regex]::Match($content, '\*\*Ticket:\*\*\s+#(\d+)')
            $titleMatch = [regex]::Match($content, '^#\s+Investigation Report:\s+(.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            $dateMatch = [regex]::Match($content, '\*\*Date:\*\*\s+(.+?)  ')
            
            $ticket = if ($ticketMatch.Success) { $ticketMatch.Groups[1].Value } else { "N/A" }
            $title = if ($titleMatch.Success) { $titleMatch.Groups[1].Value } else { "Unknown" }
            $date = if ($dateMatch.Success) { $dateMatch.Groups[1].Value } else { "Unknown" }
            
            $relPath = Split-Path $reportPath -Leaf
            $status = "✅ Complete"
            
            $markdown += "| $index | #$ticket | [$title]($relPath) | $date | $status |"
            $index++
        }
    }
    
    $markdown += ""
    $markdown += "---"
    $markdown += ""
    
    # Statistics
    $markdown += "## Statistics"
    $markdown += ""
    $markdown += "- **Total Investigations:** $($ReportPaths.Count)"
    $markdown += "- **Reports with Screenshots:** TBD"
    $markdown += "- **Average Investigation Time:** TBD"
    $markdown += ""
    
    # Save summary
    $markdown | Out-File $OutputPath -Encoding UTF8
    
    Write-Host "Investigation summary saved: $OutputPath" -ForegroundColor Green
    
    return $OutputPath
}

<#
.SYNOPSIS
Export investigation report to PDF

.DESCRIPTION
Converts markdown investigation report to PDF using Pandoc (if available)

.PARAMETER MarkdownPath
Path to markdown investigation report

.PARAMETER PdfPath
Output PDF path (defaults to same name as markdown with .pdf extension)

.EXAMPLE
Export-InvestigationToPDF -MarkdownPath "Investigation_12345.md"
#>
function Export-InvestigationToPDF {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$MarkdownPath,
        
        [Parameter(Mandatory=$false)]
        [string]$PdfPath
    )
    
    # Check if Pandoc is installed
    $pandoc = Get-Command pandoc -ErrorAction SilentlyContinue
    
    if (-not $pandoc) {
        Write-Warning "Pandoc not found. Please install Pandoc to export to PDF."
        Write-Warning "Download from: https://pandoc.org/installing.html"
        return $null
    }
    
    # Generate default PDF path if not provided
    if (-not $PdfPath) {
        $PdfPath = $MarkdownPath -replace '\.md$', '.pdf'
    }
    
    # Convert to PDF
    try {
        pandoc $MarkdownPath -o $PdfPath --pdf-engine=xelatex
        
        if (Test-Path $PdfPath) {
            Write-Host "PDF export successful: $PdfPath" -ForegroundColor Green
            return $PdfPath
        } else {
            Write-Error "PDF export failed"
            return $null
        }
        
    } catch {
        Write-Error "Error exporting to PDF: $_"
        return $null
    }
}

# Export functions
Export-ModuleMember -Function @(
    'New-VisualInvestigationReport',
    'New-InvestigationSummary',
    'Export-InvestigationToPDF'
)
