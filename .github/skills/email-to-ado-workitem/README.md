# Email to ADO Work Item - Skill

Automatically creates Bug or Task work items in Azure DevOps from email files.

## Quick Start

1. **Save emails** to your Desktop folder:
   ```
   C:\Users\{your-username}\Desktop\email-to-ado-workitem\
   ```

2. **Ask Copilot** to process them:
   ```
   "Process my support emails and create tasks"
   ```

3. **Check ADO** for newly created work items linked to current sprint's BAU Support user story

## How It Works

### 1. User-Specific Folders
Each user has their own folder on their Desktop:
- **Inbox**: `C:\Users\{username}\Desktop\email-to-ado-workitem\`
- **Archive**: `C:\Users\{username}\Desktop\email-to-ado-workitem\Archive\` (processed emails)
- **Error**: `C:\Users\{username}\Desktop\email-to-ado-workitem\Error\` (failed emails)

### 2. Automatic User Assignment
The skill automatically:
- Gets your **full name** and **email address** directly from **Outlook** (most reliable method!)
- Falls back to ADO API fuzzy matching by Windows username
- Falls back to Active Directory lookup
- Falls back to manual mapping table
- Assigns the created work item to **you**
- Displays your name in the summary: `Assigned to: Tay Nguyen (tcnguyen@company.com)`

**Why Outlook is best:** Since Outlook is already required to read emails, we can query your full name and email address directly from your Outlook profile. This is more reliable than trying to map Windows usernames.

### 3. Parent Linking
All work items are created as children of the **current sprint's BAU Support User Story**:
- **Grandparent**: Feature #35679
- **Parent**: User Story with title matching "CAMOS BAU Support Sprint {number}"
- **Child**: Your newly created Bug or Task

### 4. Work Item Details
From each email, the skill creates:
- **Title**: Email subject (cleaned)
- **Description**: Summary + full email body + sender info
- **Assigned To**: You (the user who invoked the skill)
- **Estimated Hours**: Calculated based on email length and attachments (or you can specify)
- **Attachments**: All files from email + original `.msg` file
- **Tags**: `EmailImport`

## Supported Email Formats
- `.msg` (Outlook message files)
- `.eml` (Standard email format)

## Usage Examples

### Basic Usage
```
User: "Process my emails"

Agent:
1. Finds emails in C:\Users\tcnguyen\Desktop\email-to-ado-workitem\
2. Resolves tcnguyen → Tay Nguyen (tcnguyen@company.com)
3. Finds parent: User Story #84579 "CAMOS BAU Support Sprint 146"
4. Creates work items:
   - Task #86543: "Price discrepancy for LX293801" (assigned to Tay, 2h)
   - Bug #86544: "SSIS package failure" (assigned to Tay, 4h)
5. Archives processed emails
6. Reports: "Created 1 Task, 1 Bug"
```

### With Custom Hours
```
User: "Process emails and let me set estimated hours"

Agent: [Uses interactive mode to ask for hours for each work item]
```

## Folder Setup

### First Time
When you first use this skill, the folders will be created automatically on your Desktop.

### Manual Setup
Or create them manually:

```powershell
New-Item -Path "$env:USERPROFILE\Desktop\email-to-ado-workitem" -ItemType Directory
New-Item -Path "$env:USERPROFILE\Desktop\email-to-ado-workitem\Archive" -ItemType Directory
New-Item -Path "$env:USERPROFILE\Desktop\email-to-ado-workitem\Error" -ItemType Directory
```

## Saving Emails to the Folder

### From Outlook
1. Open the email in Outlook
2. **File** → **Save As**
3. Navigate to `C:\Users\{your-username}\Desktop\email-to-ado-workitem\`
4. Save as type: **Outlook Message Format (*.msg)**
5. Click **Save**

### Drag and Drop
1. Create a desktop shortcut to the `email-to-ado-workitem` folder
2. Drag emails from Outlook to the folder

## Work Item Type Detection

The skill automatically determines whether to create a Bug or Task:

### Bug Keywords
Email contains: `bug`, `error`, `issue`, `broken`, `not working`, `failed`, `failure`, `exception`, `crash`

### Default
Everything else becomes a **Task**

## Estimated Hours Calculation

### Automatic (Default)
- **Short email** (< 500 chars) → 1 hour
- **Medium email** (500-2000 chars) → 2 hours  
- **Long email** (> 2000 chars) → 4 hours
- **Has attachments** → +1 hour

### Interactive Mode
Use `--InteractiveHours` flag to manually enter hours for each work item

## Configuration

### Update ADO Settings
Edit the PowerShell script header:

```powershell
$AdoOrg = "https://dev.azure.com/YourOrg"         # Your ADO org
$AdoProject = "YourProject"                        # Your ADO project
$FeatureId = 35679                                 # Parent feature ID
$DefaultEstimatedHours = 2.0                       # Default hours
```

### Add User Mapping
If automatic user resolution fails, add manual mapping in `Get-ADOUserDisplayName` function:

```powershell
$userMapping = @{
    "tcnguyen" = "tcnguyen@company.com"
    "jsmith" = "jsmith@company.com"
    # Add your username here
}
```

## Troubleshooting

### User Resolution Process

The skill tries these methods in order to find your name and ADO email:

1. **Outlook Profile** ✅ (Best!)
   - Queries your logged-in Outlook account
   - Gets your **full name** (e.g., "Tay Nguyen") and **email address** directly
   - Verifies email exists in ADO
   - **Most reliable** since Outlook is already required
   - Displays: `Resolved User: Tay Nguyen (tcnguyen@company.com)`

2. **ADO Fuzzy Match**
   - Searches ADO users by Windows username
   - Matches patterns like `username@company.com`

3. **Active Directory**
   - Looks up your AD account
   - Gets email from AD profile

4. **Manual Mapping**
   - Uses hardcoded username → email table
   - You can add your mapping to the script

### "Could not find BAU Support User Story"
**Cause**: No User Story with title "CAMOS BAU Support Sprint XXX" exists under Feature #35679 with status Active/In Progress

**Fix**:
1. Check Feature #35679 in ADO
2. Ensure a User Story exists with title matching "CAMOS BAU Support Sprint {number}"
3. Verify the User Story status is Active, In Progress, or New

### "Could not resolve username"
**Cause**: Could not match your user to an ADO account through any of the 4 methods

**Fix**:
1. **Check Outlook**: Make sure you're logged into Outlook with your work email
2. **Verify ADO access**: Ensure your email exists in Azure DevOps (`az devops user list`)
3. **Add manual mapping**: Edit the script and add your username to the `$userMapping` table:
   ```powershell
   $userMapping = @{
       "your-windows-username" = @{ 
           Email = "your-email@company.com"
           DisplayName = "Your Full Name"
       }
   }
   ```
4. **Work item will be unassigned**: If all methods fail, work item is still created but you'll need to assign it manually in ADO

### Emails not processing
**Check**:
1. Emails are `.msg` or `.eml` format (not `.txt` or other)
2. Emails are in the correct folder: `C:\Users\{your-username}\Desktop\email-to-ado-workitem\`
3. You have Outlook installed (required for `.msg` files)
4. You have Azure CLI installed and authenticated (`az login`)

### "Failed to attach file"
**Cause**: File upload to ADO failed

**Fix**:
1. Check file size (ADO has limits ~60MB per attachment)
2. Check ADO permissions
3. File will still be in Archive folder - you can manually attach later

## What Gets Created

For each email, you get an ADO work item with:

✅ **Title** from email subject  
✅ **Description** with summary + full email body  
✅ **Assigned to YOU** automatically  
✅ **Estimated hours** calculated or specified  
✅ **All email attachments** (images, PDFs, etc.)  
✅ **Original email** file attached  
✅ **Linked to current sprint's BAU Support User Story**  
✅ **Tagged** with "EmailImport"

## Script Location

The PowerShell script is located at:
```
.github\skills\email-to-ado-workitem\Process-EmailToADO.ps1
```

## Manual Execution

You can also run the script manually:

```powershell
cd C:\source\MD\AdminTools\.github\skills\email-to-ado-workitem\
.\Process-EmailToADO.ps1
```

Or with interactive hours:

```powershell
.\Process-EmailToADO.ps1 -InteractiveHours
```

## Notes

- **No investigation**: The skill only creates work items, it does NOT investigate or resolve issues
- **Multi-user**: Each user has their own folder and work items are assigned to them
- **Automatic archiving**: Processed emails are moved to Archive folder
- **Error handling**: Failed emails are moved to Error folder for manual review
- **Attachment preservation**: All files from email are attached to work item

## Dependencies

- **Microsoft Outlook** installed and configured with your work email
  - Required to read `.msg` files
  - **Also used to get your email address** for ADO assignment
- **Azure CLI** (`az`) installed and authenticated (`az login`)
- **ADO Permissions**: Create work items, add attachments, link work items
- **Access to Feature #35679** and its child User Stories

## Support

For issues or questions, contact the CAMOS BAU Support team or check the wiki:
- [Price Exception Wiki](https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/2281/)
