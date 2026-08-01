# Wiki Cache Manager for Mossy Skills
# Version: 1.0
# Date: 2026-07-28
# Purpose: Cache wiki content locally to reduce Azure DevOps API calls and improve performance

<#
.SYNOPSIS
Get cached wiki page or fetch from Azure DevOps if not cached

.DESCRIPTION
Retrieves wiki page from local cache if available and not expired, otherwise fetches from Azure DevOps and caches the result

.PARAMETER WikiPath
The wiki page path (e.g., "/2281/Price-Exception-Not-Matching-MarkIT-ICE")

.PARAMETER CacheExpirationHours
Number of hours before cache expires (default: 168 hours = 1 week)

.PARAMETER ForceRefresh
Force refresh from Azure DevOps even if cache is valid

.EXAMPLE
$content = Get-CachedWikiPage -WikiPath "/2281/Price-Exception-Not-Matching-MarkIT-ICE"
#>
function Get-CachedWikiPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$WikiPath,
        
        [Parameter(Mandatory=$false)]
        [int]$CacheExpirationHours = 168,  # 1 week default
        
        [Parameter(Mandatory=$false)]
        [switch]$ForceRefresh
    )
    
    # Ensure cache directory exists
    $cacheDir = "C:\source\MD\AdminTools\.cache\wiki"
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    
    # Generate cache file name from wiki path
    $sanitizedPath = $WikiPath -replace '[\\/:*?"<>|]', '_'
    $cacheFile = Join-Path $cacheDir "$sanitizedPath.md"
    $metaFile = Join-Path $cacheDir "$sanitizedPath.meta.json"
    
    # Check if cache exists and is valid
    $useCache = $false
    if ((Test-Path $cacheFile) -and (Test-Path $metaFile) -and -not $ForceRefresh) {
        $meta = Get-Content $metaFile -Raw | ConvertFrom-Json
        $cacheAge = (Get-Date) - [DateTime]::Parse($meta.CachedDate)
        
        if ($cacheAge.TotalHours -lt $CacheExpirationHours) {
            $useCache = $true
            Write-Verbose "Using cached wiki page (age: $([Math]::Round($cacheAge.TotalHours, 1)) hours)"
        } else {
            Write-Verbose "Cache expired (age: $([Math]::Round($cacheAge.TotalHours, 1)) hours, max: $CacheExpirationHours hours)"
        }
    }
    
    # Return cached content if valid
    if ($useCache) {
        return Get-Content $cacheFile -Raw
    }
    
    # Fetch from Azure DevOps
    Write-Verbose "Fetching wiki page from Azure DevOps: $WikiPath"
    
    try {
        $result = az devops wiki page show `
            --wiki "Siepe Wiki" `
            --path $WikiPath `
            --include-content `
            --org https://siepe.visualstudio.com/ `
            --project "Siepe.Software" `
            --output json 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to fetch wiki page: $WikiPath"
            return $null
        }
        
        $wikiPage = $result | ConvertFrom-Json
        $content = $wikiPage.content
        
        # Cache the content
        $content | Out-File $cacheFile -Encoding UTF8
        
        # Save metadata
        $meta = @{
            WikiPath = $WikiPath
            CachedDate = (Get-Date).ToString("o")
            ExpirationHours = $CacheExpirationHours
        }
        $meta | ConvertTo-Json | Out-File $metaFile -Encoding UTF8
        
        Write-Verbose "Wiki page cached successfully"
        
        return $content
        
    } catch {
        Write-Error "Error fetching wiki page: $_"
        return $null
    }
}

<#
.SYNOPSIS
Clear expired wiki cache entries

.DESCRIPTION
Removes cached wiki pages that have expired based on their metadata

.EXAMPLE
Clear-ExpiredWikiCache
#>
function Clear-ExpiredWikiCache {
    [CmdletBinding()]
    param()
    
    $cacheDir = "C:\source\MD\AdminTools\.cache\wiki"
    
    if (-not (Test-Path $cacheDir)) {
        Write-Verbose "Cache directory does not exist"
        return
    }
    
    $metaFiles = Get-ChildItem -Path $cacheDir -Filter "*.meta.json"
    $removedCount = 0
    
    foreach ($metaFile in $metaFiles) {
        $meta = Get-Content $metaFile.FullName -Raw | ConvertFrom-Json
        $cacheAge = (Get-Date) - [DateTime]::Parse($meta.CachedDate)
        
        if ($cacheAge.TotalHours -ge $meta.ExpirationHours) {
            # Remove both meta and content files
            $contentFile = $metaFile.FullName -replace '\.meta\.json$', '.md'
            
            Remove-Item $metaFile.FullName -Force
            if (Test-Path $contentFile) {
                Remove-Item $contentFile -Force
            }
            
            $removedCount++
            Write-Verbose "Removed expired cache: $($meta.WikiPath)"
        }
    }
    
    Write-Host "Cleared $removedCount expired wiki cache entries" -ForegroundColor Green
}

<#
.SYNOPSIS
Clear all wiki cache

.DESCRIPTION
Removes all cached wiki pages regardless of expiration

.EXAMPLE
Clear-AllWikiCache
#>
function Clear-AllWikiCache {
    [CmdletBinding()]
    param()
    
    $cacheDir = "C:\source\MD\AdminTools\.cache\wiki"
    
    if (-not (Test-Path $cacheDir)) {
        Write-Verbose "Cache directory does not exist"
        return
    }
    
    $files = Get-ChildItem -Path $cacheDir -File
    $count = $files.Count
    
    if ($count -gt 0) {
        Remove-Item -Path "$cacheDir\*" -Force
        Write-Host "Cleared $count wiki cache files" -ForegroundColor Green
    } else {
        Write-Host "Wiki cache is already empty" -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
Get wiki cache statistics

.DESCRIPTION
Returns information about cached wiki pages

.EXAMPLE
Get-WikiCacheStats
#>
function Get-WikiCacheStats {
    [CmdletBinding()]
    param()
    
    $cacheDir = "C:\source\MD\AdminTools\.cache\wiki"
    
    if (-not (Test-Path $cacheDir)) {
        return @{
            TotalEntries = 0
            ValidEntries = 0
            ExpiredEntries = 0
            TotalSizeKB = 0
        }
    }
    
    $metaFiles = Get-ChildItem -Path $cacheDir -Filter "*.meta.json"
    $validCount = 0
    $expiredCount = 0
    
    foreach ($metaFile in $metaFiles) {
        $meta = Get-Content $metaFile.FullName -Raw | ConvertFrom-Json
        $cacheAge = (Get-Date) - [DateTime]::Parse($meta.CachedDate)
        
        if ($cacheAge.TotalHours -lt $meta.ExpirationHours) {
            $validCount++
        } else {
            $expiredCount++
        }
    }
    
    $allFiles = Get-ChildItem -Path $cacheDir -File
    $totalSize = ($allFiles | Measure-Object -Property Length -Sum).Sum / 1KB
    
    return @{
        TotalEntries = $metaFiles.Count
        ValidEntries = $validCount
        ExpiredEntries = $expiredCount
        TotalSizeKB = [Math]::Round($totalSize, 2)
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-CachedWikiPage',
    'Clear-ExpiredWikiCache',
    'Clear-AllWikiCache',
    'Get-WikiCacheStats'
)
