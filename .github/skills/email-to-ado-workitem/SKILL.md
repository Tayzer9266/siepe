# Email to ADO Work Item - Skill

## Description
Automatically create Bug or Task work items in Azure DevOps from email files. Processes emails from a user-specific desktop folder, creates work items under the current sprint's BAU Support user story, and archives processed emails.

## When to Use
- User asks to "create a task/bug from email"
- User says "process emails to ADO"
- User wants to convert an email into an ADO work item
- Batch processing of support request emails

## Inputs
- Email files (`.msg` or `.eml`) in `C:\Users\{username}\Desktop\email-to-ado-workitem\`
- User's Windows username (automatically detected)

## Workflow

### 1. Get Current User Information
```powershell
# Get Windows username
$username = $env:USERNAME

# Resolve to ADO display name
az devops user show --user $username --org https://dev.azure.com/YourOrg --output json
```

**Username to Display Name Mapping:**
- Query Azure DevOps API to get user's display name
- Falls back to querying Active Directory if needed
- Used for work item assignment

### 2. Find Email Files
```powershell
$emailFolder = "C:\Users\$username\Desktop\email-to-ado-workitem"
$archiveFolder = "$emailFolder\Archive"

# Create folders if they don't exist
if (!(Test-Path $emailFolder)) {
    New-Item -Path $emailFolder -ItemType Directory
}
if (!(Test-Path $archiveFolder)) {
    New-Item -Path $archiveFolder -ItemType Directory
}

# Get all .msg and .eml files
$emails = Get-ChildItem -Path $emailFolder -Filter "*.msg" -ErrorAction SilentlyContinue
$emails += Get-ChildItem -Path $emailFolder -Filter "*.eml" -ErrorAction SilentlyContinue
```

### 3. Find Current Sprint BAU Support User Story
```powershell
# Query for Feature 35679
$featureId = 35679

# Find child User Stories matching pattern "CAMOS BAU Support {sprint}"
# Filter by State = "Active" OR State = "In Progress"
az boards work-item relation list-type --org https://dev.azure.com/YourOrg

# Query child work items of Feature 35679
$wiql = @"
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItemLinks
WHERE (
    [Source].[System.Id] = $featureId
    AND [System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward'
    AND [Target].[System.WorkItemType] = 'User Story'
    AND [Target].[System.Title] CONTAINS 'CAMOS BAU Support'
    AND ([Target].[System.State] = 'Active' OR [Target].[System.State] = 'In Progress')
)
ORDER BY [Target].[System.IterationPath] DESC
MODE (MustContain)
"@

az boards query --wiql $wiql --org https://dev.azure.com/YourOrg --output json
```

**Expected User Story Title Pattern:**
- "CAMOS BAU Support Sprint 145"
- "CAMOS BAU Support Sprint 146"
- etc.

**Selection Logic:**
- Get all matching user stories
- Sort by IterationPath (descending) to get current sprint
- Use the first result as parent

### 4. Process Each Email
For each email file:

#### A. Extract Email Data
```powershell
# Use Outlook COM object to read .msg files
$outlook = New-Object -ComObject Outlook.Application
$msg = $outlook.Session.OpenSharedItem($emailPath)

$subject = $msg.Subject
$body = $msg.Body
$sender = $msg.SenderEmailAddress
$receivedTime = $msg.ReceivedTime
$attachments = $msg.Attachments
```

#### B. Determine Work Item Type
**Criteria:**
- Check email subject/body for keywords
- "Bug", "Error", "Issue", "Broken", "Not working" → Bug
- "Task", "Request", "Enhancement", "Setup", "Configure" → Task
- Default: Task

#### C. Create Work Item Title
Use email subject as-is, or clean it up:
```powershell
$title = $subject -replace "^(RE:|FW:|FWD:)\s*", "" # Remove RE:/FW: prefixes
$title = $title.Trim()
```

#### D. Create Work Item Description
```markdown
## Issue Summary
{First paragraph or key points from email body}

## Objective
{What needs to be accomplished based on email content}

## Details
{Full email body or relevant excerpts}

---
**Original Email:**
- From: {sender}
- Received: {receivedTime}
- Subject: {subject}
```

#### E. Save Email Attachments Temporarily
```powershell
$tempAttachments = @()
foreach ($attachment in $msg.Attachments) {
    $attachmentPath = "$env:TEMP\$($attachment.FileName)"
    $attachment.SaveAsFile($attachmentPath)
    $tempAttachments += $attachmentPath
}
```

#### F. Save Original Email to Temp
```powershell
$emailBackupPath = "$env:TEMP\OriginalEmail_$(Get-Date -Format 'yyyyMMdd_HHmmss').msg"
$msg.SaveAs($emailBackupPath)
```

### 5. Create ADO Work Item
```powershell
# Create Bug or Task
$workItemType = "Task" # or "Bug"

az boards work-item create `
    --type $workItemType `
    --title $title `
    --description $description `
    --assigned-to $userDisplayName `
    --org https://dev.azure.com/YourOrg `
    --project "YourProject" `
    --fields "Microsoft.VSTS.Scheduling.RemainingWork=$estimatedHours" `
    --parent $bauSupportUserStoryId `
    --output json
```

**Field Mapping:**
- `System.Title` = Email subject (cleaned)
- `System.Description` = Generated description
- `System.AssignedTo` = User who invoked the skill (resolved display name)
- `Microsoft.VSTS.Scheduling.RemainingWork` = Estimated hours (ask user or default to 2)
- `System.Parent` = Current sprint's BAU Support User Story ID
- `System.Tags` = "EmailImport"

### 6. Attach Files to Work Item
```powershell
$workItemId = <newly created work item ID>

# Attach email attachments
foreach ($attachmentPath in $tempAttachments) {
    az boards work-item relation add `
        --id $workItemId `
        --relation-type "AttachedFile" `
        --target-url (Upload-FileToADO $attachmentPath) `
        --org https://dev.azure.com/YourOrg
}

# Attach original email
az boards work-item relation add `
    --id $workItemId `
    --relation-type "AttachedFile" `
    --target-url (Upload-FileToADO $emailBackupPath) `
    --org https://dev.azure.com/YourOrg
```

### 7. Add Comment to Work Item
```powershell
az boards work-item update `
    --id $workItemId `
    --discussion "Work item created automatically from email received on $receivedTime from $sender" `
    --org https://dev.azure.com/YourOrg
```

### 8. Archive Email
```powershell
# Move processed email to Archive folder
$archivePath = "$archiveFolder\$(Get-Date -Format 'yyyyMMdd_HHmmss')_$($email.Name)"
Move-Item -Path $email.FullName -Destination $archivePath -Force

# Clean up temp files
Remove-Item $tempAttachments -Force -ErrorAction SilentlyContinue
Remove-Item $emailBackupPath -Force -ErrorAction SilentlyContinue
```

### 9. Log Results
```powershell
$result = @{
    EmailFile = $email.Name
    WorkItemId = $workItemId
    WorkItemType = $workItemType
    AssignedTo = $userDisplayName
    ProcessedAt = Get-Date
    Status = "Success"
}

# Output summary
Write-Host "Created $workItemType #$workItemId from email: $($email.Name)"
```

## Example Usage

**User asks:**
> "Process my support emails and create tasks"

**Agent response:**
1. Detects username: `tcnguyen`
2. Resolves to display name: "Tay Nguyen <tcnguyen@company.com>"
3. Finds emails in `C:\Users\tcnguyen\Desktop\email-to-ado-workitem\`
4. Finds current sprint User Story: "CAMOS BAU Support Sprint 146" (#84579)
5. For each email:
   - Creates Task or Bug
   - Sets title from subject
   - Generates description with summary
   - Assigns to Tay Nguyen
   - Adds estimated hours (asks user or defaults to 2)
   - Attaches all images/documents from email
   - Attaches original email file
   - Links as child of User Story #84579
   - Moves email to Archive folder
6. Outputs: "Created Task #86543 from email: SupportRequest_20260801.msg"

## Error Handling

### Email Folder Not Found
```powershell
if (!(Test-Path $emailFolder)) {
    Write-Host "Email folder not found. Creating: $emailFolder"
    New-Item -Path $emailFolder -ItemType Directory
    Write-Host "Please place email files (.msg or .eml) in this folder and run again."
    return
}
```

### No Emails Found
```powershell
if ($emails.Count -eq 0) {
    Write-Host "No email files found in $emailFolder"
    Write-Host "Supported formats: .msg, .eml"
    return
}
```

### BAU Support User Story Not Found
```powershell
if (!$bauSupportUserStory) {
    Write-Error "Could not find current sprint's 'CAMOS BAU Support' User Story under Feature #35679"
    Write-Host "Please ensure a User Story with title 'CAMOS BAU Support Sprint XXX' exists and is Active or In Progress"
    return
}
```

### Email Processing Failure
```powershell
try {
    # Process email
} catch {
    Write-Error "Failed to process email $($email.Name): $_"
    # Move to error folder instead of archive
    $errorFolder = "$emailFolder\Error"
    New-Item -Path $errorFolder -ItemType Directory -Force
    Move-Item -Path $email.FullName -Destination "$errorFolder\$($email.Name)" -Force
}
```

### User Resolution Failure
```powershell
if (!$userDisplayName) {
    Write-Warning "Could not resolve username '$username' to ADO user. Work item will be unassigned."
    Write-Host "Please manually assign the work item after creation."
}
```

## Configuration

### Folder Paths
- **Inbox**: `C:\Users\{username}\Desktop\email-to-ado-workitem\`
- **Archive**: `C:\Users\{username}\Desktop\email-to-ado-workitem\Archive\`
- **Error**: `C:\Users\{username}\Desktop\email-to-ado-workitem\Error\`

### ADO Settings
- **Organization**: `https://dev.azure.com/YourOrg`
- **Project**: `YourProject`
- **Parent Feature ID**: `35679`
- **User Story Pattern**: `CAMOS BAU Support Sprint {number}`

### Default Values
- **Estimated Hours**: Ask user, or default to `2.0`
- **Work Item Type**: Detect from keywords, default to `Task`
- **Tags**: `EmailImport`

## User Name Resolution

### Method 1: Outlook Current User (Most Reliable) ✅
```powershell
# Get both name and email from Outlook profile - most accurate!
$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")
$currentUser = $namespace.CurrentUser

$userEmail = $currentUser.Address  # e.g., "tcnguyen@company.com"
$userName = $currentUser.Name      # e.g., "Tay Nguyen"

# Return both pieces of information
@{
    Email = $userEmail
    DisplayName = $userName
    AdoDisplayName = $userName
}
```

**Why this is best:**
- Outlook is already required for reading emails
- Gets both the **full name** and **email address** from the logged-in Outlook profile
- No need to guess or map Windows username → email
- Works across domains and environments
- Provides proper display name for logging and reporting

### Method 2: Azure DevOps API (Fuzzy Match)
```powershell
# Get user by Windows username
$adoUsers = az devops user list --org https://dev.azure.com/YourOrg --output json | ConvertFrom-Json

$matchedUser = $adoUsers.value | Where-Object { 
    $_.mailAddress -like "*$username*" -or 
    $_.principalName -like "*$username*" 
} | Select-Object -First 1

# Return user information
@{
    Email = $matchedUser.mailAddress
    DisplayName = $matchedUser.displayName
    AdoDisplayName = $matchedUser.displayName
}
```

### Method 3: Active Directory (Fallback)
```powershell
# Query AD for user details
$adUser = Get-ADUser -Identity $username -Properties DisplayName, EmailAddress

# Return user information
@{
    Email = $adUser.EmailAddress
    DisplayName = $adUser.DisplayName
    AdoDisplayName = $adUser.DisplayName
}
```

### Method 4: Manual Mapping (Last Resort)
```powershell
# Hardcoded mapping table with full name and email
$userMapping = @{
    "tcnguyen" = @{ Email = "tcnguyen@company.com"; DisplayName = "Tay Nguyen" }
    "jsmith" = @{ Email = "jsmith@company.com"; DisplayName = "Jane Smith" }
    # Add more mappings as needed
}

# Return mapped information
$userInfo = $userMapping[$username]
@{
    Email = $userInfo.Email
    DisplayName = $userInfo.DisplayName
    AdoDisplayName = $userInfo.DisplayName
}
```

## Estimated Hours Handling

### Interactive Prompt
```powershell
$estimatedHours = Read-Host "Enter estimated hours for this work item (default: 2)"
if ([string]::IsNullOrWhiteSpace($estimatedHours)) {
    $estimatedHours = 2.0
} else {
    $estimatedHours = [decimal]$estimatedHours
}
```

### Smart Estimation (Optional)
- Analyze email body length
- Short email (< 500 chars) → 1 hour
- Medium email (500-2000 chars) → 2 hours
- Long email (> 2000 chars) → 4 hours
- Has attachments → +1 hour

## Output Format

```
Processing emails from: C:\Users\tcnguyen\Desktop\email-to-ado-workitem\

Current user: Tay Nguyen (tcnguyen@company.com)
Parent User Story: #84579 - CAMOS BAU Support Sprint 146
Found 3 email(s) to process

[1/3] Processing: SupportRequest_PriceIssue.msg
  → Created Task #86543: "Price discrepancy for LX293801"
  → Assigned to: Tay Nguyen
  → Estimated hours: 2.0
  → Attached: 2 files + original email
  → Archived: SupportRequest_PriceIssue.msg

[2/3] Processing: ErrorReport_SSIS.msg
  → Created Bug #86544: "SSIS package failure on 7/31"
  → Assigned to: Tay Nguyen
  → Estimated hours: 4.0
  → Attached: 1 file + original email
  → Archived: ErrorReport_SSIS.msg

[3/3] Processing: ChangeRequest_NewCompany.msg
  → Created Task #86545: "Setup new company portfolio"
  → Assigned to: Tay Nguyen
  → Estimated hours: 3.0
  → Attached: 3 files + original email
  → Archived: ChangeRequest_NewCompany.msg

✓ Successfully processed 3 email(s)
✓ Created 2 Task(s), 1 Bug(s)
✓ All work items linked to User Story #84579
```

## Dependencies
- Azure CLI (`az`) installed and authenticated
- Outlook COM object (for .msg files)
- Access to Feature #35679 and child User Stories
- ADO permissions: Create work items, add attachments

## Notes
- **No investigation performed**: Skill only creates work items, does not analyze or resolve issues
- **Multi-user support**: Each user has their own folder on their Desktop
- **Automatic assignment**: Work items are assigned to the user who invoked the skill
- **Sprint detection**: Finds the current sprint's BAU Support user story automatically
- **Attachment preservation**: All email attachments plus original email are attached to work item
