# ============================================
# Copy-Mossy-To-SupportTools.ps1
# Helper script to copy Mossy files to support-tools repo
# ============================================

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$SupportToolsPath = "C:\source\support-tools",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     Copy Mossy Agent to siepe-software/support-tools          ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# Check if support-tools repo exists
if (-not (Test-Path $SupportToolsPath)) {
    Write-Host "ERROR: support-tools repository not found at: $SupportToolsPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "To clone the repo:" -ForegroundColor Yellow
    Write-Host "  cd C:\source" -ForegroundColor White
    Write-Host "  git clone https://github.com/siepe-software/support-tools.git" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "Found support-tools repository" -ForegroundColor Green
Write-Host "  Path: $SupportToolsPath" -ForegroundColor White
Write-Host ""

# Define source and destination paths
$scriptRoot = $PSScriptRoot
$destMossyDir = Join-Path $SupportToolsPath "mossy-automated-agent"
$destWorkflowDir = Join-Path $SupportToolsPath ".github\workflows"

# Files to copy (ESSENTIAL FILES ONLY)
$filesToCopy = @(
    @{
        Source = Join-Path $scriptRoot "Invoke-ClaudeAPI.psm1"
        Dest = Join-Path $destMossyDir "Invoke-ClaudeAPI.psm1"
    },
    @{
        Source = Join-Path $scriptRoot "Process-MossyReview-Automated.ps1"
        Dest = Join-Path $destMossyDir "Process-MossyReview-Automated.ps1"
    },
    @{
        Source = Join-Path $scriptRoot "mossy-review-support-tools.yml"
        Dest = Join-Path $destWorkflowDir "mossy-review.yml"
    }
)

# Create directories if they don't exist
if (-not $DryRun) {
    if (-not (Test-Path $destMossyDir)) {
        New-Item -ItemType Directory -Path $destMossyDir -Force | Out-Null
        Write-Host "Created directory: mossy-automated-agent" -ForegroundColor Green
    }
    
    if (-not (Test-Path $destWorkflowDir)) {
        New-Item -ItemType Directory -Path $destWorkflowDir -Force | Out-Null
        Write-Host "Created directory: .github/workflows" -ForegroundColor Green
    }
    
    # Create Output directory
    $outputDir = Join-Path $destMossyDir "Output"
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-Host "Created directory: mossy-automated-agent/Output" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Files to copy:" -ForegroundColor Yellow
Write-Host ""

# Copy files
$copyCount = 0
foreach ($file in $filesToCopy) {
    $sourceName = Split-Path $file.Source -Leaf
    $destRelative = $file.Dest -replace [regex]::Escape($SupportToolsPath), ""
    
    if (Test-Path $file.Source) {
        Write-Host "  $sourceName" -ForegroundColor White
        Write-Host "    -> $destRelative" -ForegroundColor Gray
        
        if (-not $DryRun) {
            Copy-Item -Path $file.Source -Destination $file.Dest -Force
            $copyCount++
        }
    }
    else {
        Write-Host "  WARNING: MISSING: $sourceName" -ForegroundColor Yellow
    }
}

Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN MODE - No files were copied" -ForegroundColor Yellow
    Write-Host "  Run without -DryRun to actually copy files" -ForegroundColor Gray
}
else {
    Write-Host "Copied $copyCount files to support-tools repository" -ForegroundColor Green
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if (-not $DryRun) {
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Review changes:" -ForegroundColor White
    Write-Host "   cd $SupportToolsPath" -ForegroundColor Gray
    Write-Host "   git status" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Commit and push:" -ForegroundColor White
    Write-Host "   git add ." -ForegroundColor Gray
    Write-Host "   git commit -m `"Add Mossy automated agent`"" -ForegroundColor Gray
    Write-Host "   git push origin main" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Add GitHub Secrets:" -ForegroundColor White
    Write-Host "   Go to: https://github.com/siepe-software/support-tools/settings/secrets/actions" -ForegroundColor Gray
    Write-Host "   Add: ANTHROPIC_API_KEY" -ForegroundColor Gray
    Write-Host "   Add: AZURE_DEVOPS_PAT" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Test workflow:" -ForegroundColor White
    Write-Host "   Go to: https://github.com/siepe-software/support-tools/actions" -ForegroundColor Gray
    Write-Host "   Click: Mossy Automated Review Agent > Run workflow" -ForegroundColor Gray
    Write-Host ""
    Write-Host "See README.md in mossy-automated-agent folder for full instructions" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
Write-Host ""
