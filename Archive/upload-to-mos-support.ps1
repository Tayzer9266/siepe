<#
.SYNOPSIS
    Upload files to mos-support S3 bucket with duplicate checking
.DESCRIPTION
    Sweeps files from a local folder and uploads them to S3 organized by date (YYYY/MM/DD).
    Checks if files already exist in S3 for the current day before uploading.
.PARAMETER SourceFolder
    The local folder path to sweep files from
.PARAMETER BucketName
    The S3 bucket name (default: mos-support)
.PARAMETER TargetDate
    Optional date to use for organizing files (default: today). Format: yyyy-MM-dd
.EXAMPLE
    .\upload-to-mos-support.ps1 -SourceFolder "C:\Users\tcnguyen\Desktop\mos_file_testing"
.EXAMPLE
    .\upload-to-mos-support.ps1 -SourceFolder "C:\Documents\Daily" -TargetDate "2026-07-08"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceFolder,
    
    [Parameter(Mandatory=$false)]
    [string]$BucketName = "mos-support",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetDate
)

# Read AWS credentials from connection file
$connectionFile = "C:\source\MD\Connection_strings\mos-support-credentials.txt"
if (-not (Test-Path $connectionFile)) {
    Write-Error "AWS connection file not found: $connectionFile"
    exit 1
}

Write-Host "Reading AWS credentials..." -ForegroundColor Cyan
$awsConfig = Get-Content $connectionFile
$accessKey = ($awsConfig | Select-String "Access Key:").ToString().Split(":")[1].Trim()
$secretKey = ($awsConfig | Select-String "Secret Key:").ToString().Split(":")[1].Trim()
$region = ($awsConfig | Select-String "Region:").ToString().Split(":")[1].Trim()

# Set AWS credentials as environment variables
$env:AWS_ACCESS_KEY_ID = $accessKey
$env:AWS_SECRET_ACCESS_KEY = $secretKey
$env:AWS_DEFAULT_REGION = $region

Write-Host "AWS Region: $region" -ForegroundColor Green

# Validate source folder
if (-not (Test-Path $SourceFolder)) {
    Write-Error "Source folder not found: $SourceFolder"
    exit 1
}

# Determine target date
if ([string]::IsNullOrEmpty($TargetDate)) {
    $date = Get-Date
} else {
    try {
        $date = [DateTime]::ParseExact($TargetDate, "yyyy-MM-dd", $null)
    } catch {
        Write-Error "Invalid date format. Use yyyy-MM-dd"
        exit 1
    }
}

# Create S3 path structure: YYYY/MM/DD/
$year = $date.ToString("yyyy")
$month = $date.ToString("MM")
$day = $date.ToString("dd")
$s3Prefix = "$year/$month/$day/"

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "MOS Support S3 Upload Script" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Bucket: s3://$BucketName" -ForegroundColor White
Write-Host "Date: $($date.ToString('yyyy-MM-dd'))" -ForegroundColor White
Write-Host "S3 Path: $s3Prefix" -ForegroundColor White
Write-Host "Source: $SourceFolder" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Yellow

# Get all files from source folder
Write-Host "Scanning source folder..." -ForegroundColor Cyan
$localFiles = Get-ChildItem -Path $SourceFolder -File -Recurse
Write-Host "Found $($localFiles.Count) file(s) in source folder`n" -ForegroundColor Green

if ($localFiles.Count -eq 0) {
    Write-Host "No files to upload. Exiting." -ForegroundColor Yellow
    exit 0
}

# Get existing files in S3 for today's date
Write-Host "Checking existing files in S3 for today..." -ForegroundColor Cyan
$s3Uri = "s3://$BucketName/$s3Prefix"
$s3ListOutput = aws s3 ls $s3Uri --recursive 2>&1

$existingFiles = @()
if ($LASTEXITCODE -eq 0 -and $s3ListOutput) {
    $existingFiles = $s3ListOutput | ForEach-Object {
        if ($_ -match '\s+(\S+)$') {
            [System.IO.Path]::GetFileName($matches[1])
        }
    }
    Write-Host "Found $($existingFiles.Count) existing file(s) in S3 for today`n" -ForegroundColor Green
} else {
    Write-Host "No existing files found in S3 for today (or folder doesn't exist yet)`n" -ForegroundColor Green
}

# Track upload statistics
$uploadCount = 0
$skipCount = 0
$errorCount = 0
$uploadedFiles = @()
$skippedFiles = @()
$errorFiles = @()

# Process each file
Write-Host "Processing files..." -ForegroundColor Cyan
Write-Host "----------------------------------------`n" -ForegroundColor Gray

foreach ($file in $localFiles) {
    $fileName = $file.Name
    $s3Key = "$s3Prefix$fileName"
    $s3FullPath = "s3://$BucketName/$s3Key"
    
    # Check if file already exists in S3
    if ($existingFiles -contains $fileName) {
        Write-Host "[SKIP] $fileName (already exists in S3)" -ForegroundColor Yellow
        $skipCount++
        $skippedFiles += $fileName
        continue
    }
    
    # Upload file to S3
    Write-Host "[UPLOAD] $fileName..." -ForegroundColor Cyan -NoNewline
    
    try {
        $uploadResult = aws s3 cp $file.FullName $s3FullPath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host " SUCCESS" -ForegroundColor Green
            $uploadCount++
            $uploadedFiles += $fileName
        } else {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "  Error: $uploadResult" -ForegroundColor Red
            $errorCount++
            $errorFiles += $fileName
        }
    } catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Red
        $errorCount++
        $errorFiles += $fileName
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "Upload Summary" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "Total Files Processed: $($localFiles.Count)" -ForegroundColor White
Write-Host "Uploaded: $uploadCount" -ForegroundColor Green
Write-Host "Skipped (already exist): $skipCount" -ForegroundColor Yellow
Write-Host "Errors: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "White" })
Write-Host "========================================`n" -ForegroundColor Yellow

# Detailed lists
if ($uploadedFiles.Count -gt 0) {
    Write-Host "Uploaded Files:" -ForegroundColor Green
    $uploadedFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($skippedFiles.Count -gt 0) {
    Write-Host "Skipped Files:" -ForegroundColor Yellow
    $skippedFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    Write-Host ""
}

if ($errorFiles.Count -gt 0) {
    Write-Host "Failed Files:" -ForegroundColor Red
    $errorFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
    Write-Host ""
}

# Generate S3 console link
$consoleUrl = "https://s3.console.aws.amazon.com/s3/buckets/$BucketName?region=$region&prefix=$s3Prefix"
Write-Host "View in S3 Console:" -ForegroundColor Cyan
Write-Host $consoleUrl -ForegroundColor Blue
Write-Host ""

# Exit with appropriate code
if ($errorCount -gt 0) {
    exit 1
} else {
    exit 0
}
