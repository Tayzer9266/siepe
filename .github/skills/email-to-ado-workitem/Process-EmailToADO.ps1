# ================================================================
# Process Email to ADO Work Items
# ================================================================
# Description: Converts email files to Bug or Task work items in Azure DevOps
# Author: Auto-generated for CAMOS BAU Support
# Date: 2026-08-01
# ================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AdoOrg = "https://dev.azure.com/YourOrg",
    
    [Parameter(Mandatory = $false)]
    [string]$AdoProject = "YourProject",
    
    [Parameter(Mandatory = $false)]
    [int]$FeatureId = 35679,
    
    [Parameter(Mandatory = $false)]
    [decimal]$DefaultEstimatedHours = 2.0,
    
    [Parameter(Mandatory = $false)]
    [switch]$InteractiveHours
)

# ================================================================
# CONFIGURATION
# ================================================================

$ErrorActionPreference = "Stop"
$username = $env:USERNAME

# Paths
$emailFolder = "C:\Users\$username\Desktop\email-to-ado-workitem"
$archiveFolder = "$emailFolder\Archive"
$errorFolder = "$emailFolder\Error"

# Create folders if they don't exist
@($emailFolder, $archiveFolder, $errorFolder) | ForEach-Object {
    if (!(Test-Path $_)) {
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
}

# ================================================================
# FUNCTIONS
# ================================================================

function Get-ADOUserDisplayName {
    param([string]$Username)
    
    Write-Host "Resolving username '$Username' to ADO email..." -ForegroundColor Cyan
    
    # Method 1: Get email and name from Outlook (most reliable)
    try {
        Write-Host "  Checking Outlook for current user's information..." -ForegroundColor Gray
        $outlook = New-Object -ComObject Outlook.Application
        $namespace = $outlook.GetNamespace("MAPI")
        
        # Get current user's email and name from Outlook profile
        $currentUser = $namespace.CurrentUser
        if ($currentUser.Address -and $currentUser.Address -like "*@*") {
            $userEmail = $currentUser.Address
            $userName = $currentUser.Name  # Full name from Outlook
            
            Write-Host "  Found in Outlook: $userName ($userEmail)" -ForegroundColor Green
            
            # Clean up COM objects
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($namespace) | Out-Null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            
            # Verify this email exists in ADO
            try {
                $users = az devops user list --org $AdoOrg --output json | ConvertFrom-Json
                $matchedUser = $users.value | Where-Object { $_.mailAddress -eq $userEmail } | Select-Object -First 1
                
                if ($matchedUser) {
                    Write-Host "  Verified in ADO: $($matchedUser.displayName)" -ForegroundColor Green
                    # Return hashtable with both email and display name
                    return @{
                        Email = $userEmail
                        DisplayName = $userName  # From Outlook
                        AdoDisplayName = $matchedUser.displayName  # From ADO
                    }
                } else {
                    Write-Warning "  Email found in Outlook but not in ADO. Will use Outlook name."
                    # Return Outlook info even if not in ADO
                    return @{
                        Email = $userEmail
                        DisplayName = $userName
                        AdoDisplayName = $userName
                    }
                }
            } catch {
                Write-Warning "  Failed to verify in ADO: $_"
                # Return Outlook info as fallback
                return @{
                    Email = $userEmail
                    DisplayName = $userName
                    AdoDisplayName = $userName
                }
            }
        } else {
            Write-Host "  Outlook profile email not available (address: $($currentUser.Address))" -ForegroundColor Gray
            
            # Clean up COM objects
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($namespace) | Out-Null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }
    } catch {
        Write-Warning "  Failed to query Outlook: $_"
    }
    
    # Method 2: Query Azure DevOps by username
    try {
        Write-Host "  Searching ADO users by username..." -ForegroundColor Gray
        $users = az devops user list --org $AdoOrg --output json | ConvertFrom-Json
        
        $matchedUser = $users.value | Where-Object { 
            $_.mailAddress -like "*$Username*" -or 
            $_.principalName -like "*$Username*" -or
            $_.mailAddress -like "*$Username@*"
        } | Select-Object -First 1
        
        if ($matchedUser) {
            Write-Host "  Found in ADO: $($matchedUser.displayName) ($($matchedUser.mailAddress))" -ForegroundColor Green
            return @{
                Email = $matchedUser.mailAddress
                DisplayName = $matchedUser.displayName
                AdoDisplayName = $matchedUser.displayName
            }
        }
    } catch {
        Write-Warning "  Failed to query ADO users: $_"
    }
    
    # Method 3: Try Active Directory (if available)
    try {
        Write-Host "  Searching Active Directory..." -ForegroundColor Gray
        $adUser = Get-ADUser -Identity $Username -Properties DisplayName, EmailAddress -ErrorAction Stop
        if ($adUser.EmailAddress) {
            Write-Host "  Found in AD: $($adUser.DisplayName) ($($adUser.EmailAddress))" -ForegroundColor Green
            return @{
                Email = $adUser.EmailAddress
                DisplayName = $adUser.DisplayName
                AdoDisplayName = $adUser.DisplayName
            }
        }
    } catch {
        Write-Warning "  Active Directory query failed: $_"
    }
    
    # Method 4: Manual mapping (fallback)
    Write-Host "  Checking manual mapping..." -ForegroundColor Gray
    $userMapping = @{
        "tcnguyen" = @{ Email = "tcnguyen@company.com"; DisplayName = "Tay Nguyen" }
        # Add more mappings as needed: "username" = @{ Email = "email@company.com"; DisplayName = "Full Name" }
    }
    
    if ($userMapping.ContainsKey($Username.ToLower())) {
        $userInfo = $userMapping[$Username.ToLower()]
        Write-Host "  Found in manual mapping: $($userInfo.DisplayName) ($($userInfo.Email))" -ForegroundColor Yellow
        return @{
            Email = $userInfo.Email
            DisplayName = $userInfo.DisplayName
            AdoDisplayName = $userInfo.DisplayName
        }
    }
    
    Write-Warning "Could not resolve username '$Username'. Work item will be created unassigned."
    return $null
}

function Find-CurrentSprintBAUUserStory {
    param([int]$FeatureId)
    
    Write-Host "Finding current sprint's BAU Support User Story under Feature #$FeatureId..." -ForegroundColor Cyan
    
    # Simplified query - just search for User Stories with "CAMOS BAU Support" in title
    $wiql = "SELECT [System.Id], [System.Title], [System.State], [System.IterationPath] FROM WorkItems WHERE [System.WorkItemType] = 'User Story' AND [System.Title] CONTAINS 'CAMOS BAU Support' AND [System.State] <> 'Closed' ORDER BY [System.ChangedDate] DESC"
    
    try {
        # Execute query
        $results = az boards query --wiql $wiql --org $AdoOrg --project $AdoProject --output json | ConvertFrom-Json
        
        # Filter for Active or In Progress
        if ($results -and $results.Count -gt 0) {
            $activeStories = $results | Where-Object { 
                $_.fields.'System.State' -in @('Active', 'In Progress', 'New')
            } | Sort-Object -Property {$_.fields.'System.IterationPath'} -Descending
        
            if ($activeStories -and $activeStories.Count -gt 0) {
                $selected = $activeStories[0]
                Write-Host "  Found: #$($selected.id) - $($selected.fields.'System.Title')" -ForegroundColor Green
                return $selected.id
            } else {
                Write-Warning "No active BAU Support stories found."
                throw "Could not find current sprint's 'CAMOS BAU Support' User Story"
            }
        } else {
            throw "No work items found matching 'CAMOS BAU Support'"
        }
    } catch {
        Write-Error "Failed to query for BAU Support User Story: $_"
        throw
    }
}

function Read-EmailFile {
    param([string]$EmailPath)
    
    Write-Host "Reading email: $([System.IO.Path]::GetFileName($EmailPath))" -ForegroundColor Cyan
    
    $outlook = New-Object -ComObject Outlook.Application
    $msg = $outlook.Session.OpenSharedItem($EmailPath)
    
    $emailData = @{
        Subject = $msg.Subject
        Body = $msg.Body
        BodyHTML = $msg.HTMLBody
        Sender = $msg.SenderEmailAddress
        SenderName = $msg.SenderName
        ReceivedTime = $msg.ReceivedTime
        Attachments = @()
        AttachmentPaths = @()
    }
    
    # Save attachments
    if ($msg.Attachments.Count -gt 0) {
        Write-Host "  Found $($msg.Attachments.Count) attachment(s)" -ForegroundColor Gray
        
        foreach ($attachment in $msg.Attachments) {
            $attachmentPath = "$env:TEMP\$($attachment.FileName)"
            $attachment.SaveAsFile($attachmentPath)
            $emailData.Attachments += $attachment.FileName
            $emailData.AttachmentPaths += $attachmentPath
        }
    }
    
    # Save original email
    $emailBackupPath = "$env:TEMP\OriginalEmail_$(Get-Date -Format 'yyyyMMdd_HHmmss').msg"
    $msg.SaveAs($emailBackupPath)
    $emailData.OriginalEmailPath = $emailBackupPath
    
    # Close
    $msg.Close(0)
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($msg) | Out-Null
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    
    return $emailData
}

function Determine-WorkItemType {
    param(
        [string]$Subject,
        [string]$Body
    )
    
    $text = "$Subject $Body".ToLower()
    
    # Bug keywords
    $bugKeywords = @('bug', 'error', 'issue', 'broken', 'not working', 'failed', 'failure', 'exception', 'crash')
    
    foreach ($keyword in $bugKeywords) {
        if ($text -match $keyword) {
            return "Bug"
        }
    }
    
    # Default to Task
    return "Task"
}

function Create-WorkItemDescription {
    param(
        [string]$Body,
        [string]$Sender,
        [string]$SenderName,
        [datetime]$ReceivedTime,
        [string]$Subject
    )
    
    # Extract first few sentences or paragraphs for summary
    $lines = $Body -split "`r?`n" | Where-Object { $_.Trim() -ne "" }
    $summary = ($lines | Select-Object -First 3) -join "`n"
    
    if ($summary.Length -gt 500) {
        $summary = $summary.Substring(0, 500) + "..."
    }
    
    $description = @"
## Issue Summary
$summary

## Objective
Resolve the issue or request described in the email below.

## Full Details
$Body

---

**Original Email Information:**
- **From:** $SenderName ($Sender)
- **Received:** $($ReceivedTime.ToString('yyyy-MM-dd HH:mm:ss'))
- **Subject:** $Subject

**Note:** This work item was created automatically from an email. See attached files for original email and any supporting documents.
"@
    
    return $description
}

function Clean-WorkItemTitle {
    param([string]$Title)
    
    # Remove RE:, FW:, FWD: prefixes
    $cleaned = $Title -replace "^(RE:|FW:|FWD:)\s*", ""
    $cleaned = $cleaned.Trim()
    
    # Limit length
    if ($cleaned.Length -gt 100) {
        $cleaned = $cleaned.Substring(0, 97) + "..."
    }
    
    return $cleaned
}

function Get-EstimatedHours {
    param(
        [string]$Body,
        [int]$AttachmentCount
    )
    
    if ($InteractiveHours) {
        $hours = Read-Host "Enter estimated hours for this work item (press Enter for default: $DefaultEstimatedHours)"
        if ([string]::IsNullOrWhiteSpace($hours)) {
            return $DefaultEstimatedHours
        }
        return [decimal]$hours
    }
    
    # Smart estimation based on email length and attachments
    $bodyLength = $Body.Length
    
    if ($bodyLength -lt 500) {
        $hours = 1.0
    } elseif ($bodyLength -lt 2000) {
        $hours = 2.0
    } else {
        $hours = 4.0
    }
    
    # Add time for attachments
    if ($AttachmentCount -gt 0) {
        $hours += 1.0
    }
    
    return $hours
}

# ================================================================
# MAIN SCRIPT
# ================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Email to ADO Work Item Processor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get current user
$userInfo = Get-ADOUserDisplayName -Username $username
if ($userInfo) {
    Write-Host "Resolved User: $($userInfo.DisplayName) ($($userInfo.Email))" -ForegroundColor Green
} else {
    Write-Host "Could not resolve user. Work items will be unassigned." -ForegroundColor Yellow
}
Write-Host ""

# Find parent user story
$parentUserStoryId = Find-CurrentSprintBAUUserStory -FeatureId $FeatureId
Write-Host ""

# Find email files
Write-Host "Searching for email files in: $emailFolder" -ForegroundColor Cyan
$emailFiles = @()
$emailFiles += Get-ChildItem -Path $emailFolder -Filter "*.msg" -ErrorAction SilentlyContinue
$emailFiles += Get-ChildItem -Path $emailFolder -Filter "*.eml" -ErrorAction SilentlyContinue

if ($emailFiles.Count -eq 0) {
    Write-Host "No email files found (.msg or .eml)" -ForegroundColor Yellow
    Write-Host "Place email files in: $emailFolder" -ForegroundColor Gray
    exit 0
}

Write-Host "Found $($emailFiles.Count) email file(s) to process" -ForegroundColor Green
Write-Host ""

# Process each email
$results = @()
$successCount = 0
$errorCount = 0

for ($i = 0; $i -lt $emailFiles.Count; $i++) {
    $email = $emailFiles[$i]
    $index = $i + 1
    
    Write-Host "[$index/$($emailFiles.Count)] Processing: $($email.Name)" -ForegroundColor Cyan
    
    try {
        # Read email
        $emailData = Read-EmailFile -EmailPath $email.FullName
        
        # Determine work item type
        $workItemType = Determine-WorkItemType -Subject $emailData.Subject -Body $emailData.Body
        Write-Host "  Type: $workItemType" -ForegroundColor Gray
        
        # Prepare work item data
        $title = Clean-WorkItemTitle -Title $emailData.Subject
        $description = Create-WorkItemDescription `
            -Body $emailData.Body `
            -Sender $emailData.Sender `
            -SenderName $emailData.SenderName `
            -ReceivedTime $emailData.ReceivedTime `
            -Subject $emailData.Subject
        
        $estimatedHours = Get-EstimatedHours -Body $emailData.Body -AttachmentCount $emailData.Attachments.Count
        
        # Create work item
        Write-Host "  Creating $workItemType..." -ForegroundColor Gray
        
        $createArgs = @(
            "boards", "work-item", "create",
            "--type", $workItemType,
            "--title", $title,
            "--description", $description,
            "--org", $AdoOrg,
            "--project", $AdoProject,
            "--fields", "Microsoft.VSTS.Scheduling.RemainingWork=$estimatedHours",
            "--fields", "System.Tags=EmailImport",
            "--output", "json"
        )
        
        # Add assignment if user was resolved
        if ($userInfo) {
            $createArgs += "--assigned-to"
            $createArgs += $userInfo.Email
            Write-Host "  Assigning to: $($userInfo.DisplayName)" -ForegroundColor Gray
        }
        
        $workItemJson = & az @createArgs
        $workItem = $workItemJson | ConvertFrom-Json
        $workItemId = $workItem.id
        
        Write-Host "  Created: #$workItemId" -ForegroundColor Green
        
        # Link to parent user story
        Write-Host "  Linking to parent User Story #$parentUserStoryId..." -ForegroundColor Gray
        az boards work-item relation add `
            --id $workItemId `
            --relation-type "parent" `
            --target-id $parentUserStoryId `
            --org $AdoOrg `
            --output none
        
        # Upload and attach files
        if ($emailData.AttachmentPaths.Count -gt 0) {
            Write-Host "  Attaching $($emailData.AttachmentPaths.Count) file(s)..." -ForegroundColor Gray
            foreach ($attachmentPath in $emailData.AttachmentPaths) {
                az boards work-item relation add `
                    --id $workItemId `
                    --relation-type "AttachedFile" `
                    --target-url $attachmentPath `
                    --org $AdoOrg `
                    --output none
            }
        }
        
        # Attach original email
        Write-Host "  Attaching original email..." -ForegroundColor Gray
        az boards work-item relation add `
            --id $workItemId `
            --relation-type "AttachedFile" `
            --target-url $emailData.OriginalEmailPath `
            --org $AdoOrg `
            --output none
        
        # Archive email
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $archivePath = Join-Path $archiveFolder "$timestamp`_$($email.Name)"
        Move-Item -Path $email.FullName -Destination $archivePath -Force
        Write-Host "  Archived: $($email.Name)" -ForegroundColor Gray
        
        # Clean up temp files
        $emailData.AttachmentPaths + $emailData.OriginalEmailPath | ForEach-Object {
            if (Test-Path $_) {
                Remove-Item $_ -Force -ErrorAction SilentlyContinue
            }
        }
        
        $results += @{
            Email = $email.Name
            WorkItemId = $workItemId
            WorkItemType = $workItemType
            Status = "Success"
        }
        
        $successCount++
        
        Write-Host "  ✓ Success" -ForegroundColor Green
        Write-Host ""
        
    } catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        
        # Move to error folder
        $errorPath = Join-Path $errorFolder $email.Name
        Move-Item -Path $email.FullName -Destination $errorPath -Force -ErrorAction SilentlyContinue
        
        $results += @{
            Email = $email.Name
            WorkItemId = $null
            WorkItemType = $null
            Status = "Error: $_"
        }
        
        $errorCount++
        Write-Host ""
    }
}

# ================================================================
# SUMMARY
# ================================================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Processing Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
if ($userInfo) {
    Write-Host "Assigned to: $($userInfo.DisplayName) ($($userInfo.Email))" -ForegroundColor White
}
Write-Host "Total processed: $($emailFiles.Count)" -ForegroundColor White
Write-Host "  ✓ Successful: $successCount" -ForegroundColor Green
if ($errorCount -gt 0) {
    Write-Host "  ✗ Errors: $errorCount" -ForegroundColor Red
}
Write-Host ""

# Display created work items
if ($successCount -gt 0) {
    Write-Host "Created Work Items:" -ForegroundColor Cyan
    $results | Where-Object { $_.Status -eq "Success" } | ForEach-Object {
        Write-Host "  $($_.WorkItemType) #$($_.WorkItemId) - $($_.Email)" -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Host "Done!" -ForegroundColor Green
