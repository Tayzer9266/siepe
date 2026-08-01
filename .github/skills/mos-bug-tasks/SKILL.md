# MOS Bug Task Management

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration  
**Category:** DevOps Work Item Management  
**Difficulty:** Intermediate  
**Est. Time:** 5-10 minutes

## Purpose

Monitor the Back Office SQL Engineers sprint taskboard and create new bug work items under the current sprint's BAU Support user story. Enhanced with bug reproduction screenshot analysis and UI error image interpretation. Automatically detects similar bugs (≥60% match) before creating to prevent duplicates.

**Key Features:**
- ✅ Finds current sprint's active/new user story automatically
- ✅ Smart duplicate detection (60% similarity threshold)
- ✅ Auto-calculates estimated hours based on complexity
- ✅ Defaults to Medium priority/severity unless specified
- ✅ Links bug as child to user story
- ✅ HTML-formatted reports for creation and duplicate detection

---

## Step 0: Analyze Bug Screenshots and Wiki

**Step 0.1: Screenshot Analysis**
```powershell
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - Bug reproduction screenshots showing error dialogs
# - UI screenshots showing incorrect behavior
# - Error messages from application
# - Before/after screenshots for visual bugs
```

**Step 0.2: Fetch Wiki Procedures**
```powershell
$wikiPath = "/Bug-Reporting-Standards"  # Update with actual path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_BugReporting.md" -Encoding UTF8
```

## Step 1: Identify Current Sprint

**Find the latest sprint number:**

The sprint format is `MM.##[a-z]` (e.g., 07.26b, 08.01a)

**Query for current sprint:**

```powershell
# Get the parent feature (Back Office SQL Engineers Taskboard)
$feature = az boards work-item show --id 82437 --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json

# Query for BAU Support user stories (try Active first, then New if none found)
$queryActive = "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.Parent] = 82437 AND [System.Title] CONTAINS 'CAMOS BAU Support' AND [System.State] = 'Active' ORDER BY [System.CreatedDate] DESC"

$userStory = az boards query --wiql $queryActive --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json

# If no Active user stories found, search for New
if (-not $userStory.workItems -or $userStory.workItems.Count -eq 0) {
    $queryNew = "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.Parent] = 82437 AND [System.Title] CONTAINS 'CAMOS BAU Support' AND [System.State] = 'New' ORDER BY [System.CreatedDate] DESC"
    $userStory = az boards query --wiql $queryNew --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json
}
```

**Expected Output:**
```json
{
  "id": 83456,
  "title": "CAMOS BAU Support 07.26b",
  "state": "Active",
  "sprint": "07.26b"
}
```

**Extract sprint number from title:**
```powershell
$title = "CAMOS BAU Support 07.26b"
if ($title -match "(\d{2}\.\d{2}[a-z])") {
    $currentSprint = $matches[1]
    Write-Host "Current Sprint: $currentSprint" -ForegroundColor Cyan
}
```

**Red Flags:**
- ⚠️ No active BAU Support user story found (sprint may have ended)
- ⚠️ Multiple active BAU Support stories (clarify which to use)

---

## Step 2: Check if Bug Already Exists

**Query existing bugs under the BAU Support user story:**

```powershell
$userStoryId = $userStory.workItems[0].id  # From Step 1

# Get all child bugs (including closed ones for comprehensive check)
$query = "SELECT [System.Id], [System.Title], [System.Description], [System.State] FROM WorkItems WHERE [System.Parent] = $userStoryId AND [System.WorkItemType] = 'Bug' ORDER BY [System.CreatedDate] DESC"

$existingBugs = az boards query --wiql $query --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json

# Function to calculate similarity percentage between two strings
function Get-StringSimilarity {
    param(
        [string]$str1,
        [string]$str2
    )
    
    # Normalize strings (lowercase, remove special chars, split into words)
    $words1 = $str1.ToLower() -replace '[^\w\s]', '' -split '\s+' | Where-Object { $_.Length -gt 2 }
    $words2 = $str2.ToLower() -replace '[^\w\s]', '' -split '\s+' | Where-Object { $_.Length -gt 2 }
    
    if ($words1.Count -eq 0 -or $words2.Count -eq 0) { return 0 }
    
    # Count matching words
    $matchingWords = 0
    foreach ($word in $words1) {
        if ($words2 -contains $word) {
            $matchingWords++
        }
    }
    
    # Calculate similarity as percentage of unique words matched
    $totalUniqueWords = ($words1 + $words2 | Select-Object -Unique).Count
    $similarity = ($matchingWords * 2 / $totalUniqueWords) * 100
    
    return [Math]::Round($similarity, 1)
}

# Check for duplicates with 60% similarity threshold
$similarityThreshold = 60
$potentialDuplicates = @()

foreach ($bugRef in $existingBugs.workItems) {
    $bugDetail = az boards work-item show --id $bugRef.id --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json
    
    $existingTitle = $bugDetail.fields.'System.Title'
    $existingDescription = $bugDetail.fields.'System.Description'
    $existingState = $bugDetail.fields.'System.State'
    
    # Calculate title similarity
    $titleSimilarity = Get-StringSimilarity -str1 $bugTitle -str2 $existingTitle
    
    # Calculate description similarity if both exist
    $descriptionSimilarity = 0
    if ($bugDescription -and $existingDescription) {
        $descriptionSimilarity = Get-StringSimilarity -str1 $bugDescription -str2 $existingDescription
    }
    
    # Weighted average: title 70%, description 30%
    $overallSimilarity = if ($descriptionSimilarity -gt 0) {
        ($titleSimilarity * 0.7) + ($descriptionSimilarity * 0.3)
    } else {
        $titleSimilarity
    }
    
    # If 60% or more similar, flag as potential duplicate
    if ($overallSimilarity -ge $similarityThreshold) {
        $potentialDuplicates += [PSCustomObject]@{
            Id = $bugDetail.id
            Title = $existingTitle
            State = $existingState
            Similarity = $overallSimilarity
        }
    }
}

# If duplicates found, STOP and report
if ($potentialDuplicates.Count -gt 0) {
    Write-Host "⚠️ DUPLICATE DETECTED - Bug creation halted" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Found $($potentialDuplicates.Count) similar bug(s) (≥60% match):" -ForegroundColor Cyan
    
    foreach ($dup in $potentialDuplicates | Sort-Object Similarity -Descending) {
        Write-Host ""
        Write-Host "  Bug #$($dup.Id) - $([Math]::Round($dup.Similarity))% similar" -ForegroundColor Yellow
        Write-Host "  Title: $($dup.Title)" -ForegroundColor Gray
        Write-Host "  State: $($dup.State)" -ForegroundColor Gray
        Write-Host "  Link: https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/$($dup.Id)" -ForegroundColor Blue
    }
    
    Write-Host ""
    Write-Host "❌ Not creating new bug - please review existing bug(s) above" -ForegroundColor Red
    
    # STOP - Return duplicate information in HTML format to user
    # Generate HTML report and exit
    return @{
        Status = "Duplicate"
        Duplicates = $potentialDuplicates
    }
}

Write-Host "✅ No duplicates found (checked $($existingBugs.workItems.Count) existing bugs)" -ForegroundColor Green
```

**Similarity Detection:**
- **Algorithm:** Word-based comparison with normalization
- **Weighting:** Title 70%, Description 30%
- **Threshold:** 60% similarity = duplicate
- **Scope:** All bugs under user story (including closed)

**If duplicate found (≥60% similar):**
- ❌ STOP - Do not create new bug
- Display all matching bugs with similarity scores
- Provide links to existing bugs
- Return to user for decision

**If no duplicates found (< 60% similar), proceed to Step 3**

---

## Step 3: Calculate Estimated Hours

**Analyze bug description to estimate complexity:**

**Estimation Logic:**

| Complexity | Keywords/Indicators | Hours |
|------------|-------------------|-------|
| **Simple** | typo, config, setting, enable/disable, single value | 2 |
| **Low-Medium** | query fix, data correction, single table update | 4 |
| **Medium** | multiple queries, investigation needed, join multiple tables | 6 |
| **Medium-High** | SSIS package, stored procedure, complex logic | 8 |
| **High** | schema change, new feature, multiple systems, architecture | 12-16 |

**PowerShell estimation function:**

```powershell
function Get-BugEstimate {
    param([string]$Description)
    
    $desc = $Description.ToLower()
    
    # Simple patterns
    if ($desc -match "typo|config|setting|enable|disable|single value") {
        return 2
    }
    
    # Low-Medium patterns
    if ($desc -match "query fix|data correction|update.*table|insert.*row") {
        return 4
    }
    
    # Medium patterns  
    if ($desc -match "investigation|analyze|join|multiple tables|price override") {
        return 6
    }
    
    # Medium-High patterns
    if ($desc -match "ssis|package|stored procedure|complex|normalization") {
        return 8
    }
    
    # High patterns
    if ($desc -match "schema|new feature|architecture|multiple systems|refactor") {
        return 12
    }
    
    # Default
    return 6
}

$estimate = Get-BugEstimate -Description $bugDescription
Write-Host "Estimated Hours: $estimate" -ForegroundColor Cyan
```

**User Override:**
If user provides explicit estimate, use that instead.

---

## Step 4: Create Bug Work Item

**Required fields:**
- **Title** - From user or generated from description
- **Description** - From user
- **Assigned To** - Default: "Tay Nguyen <tcnguyen@siepe.com>" or user-specified
- **Original Estimate** - Calculated in Step 3
- **Priority** - Default: 3 (Medium) unless user specifies
- **Severity** - Default: 3 (Medium) unless user specifies
- **Parent** - User Story ID from Step 1 (linked as Child)
- **Work Item Type** - Bug
- **State** - New
- **Area Path** - Siepe.Software\Back Office SQL Engineers
- **Iteration Path** - Current sprint iteration
- **Tags** - "BAU; MOS Support"

**Create bug via Azure CLI:**

```powershell
# Build the fields JSON
$priority = 3  # Default: 3 = Medium (unless user specifies: 1=Critical, 2=High, 3=Medium, 4=Low)
$severity = 3  # Default: 3 = Medium (unless user specifies: 1=Critical, 2=High, 3=Medium, 4=Low)

$fields = @{
    "System.Title" = $bugTitle
    "System.Description" = $bugDescription
    "System.AssignedTo" = "tcnguyen@siepe.com"  # Default or user-specified
    "Microsoft.VSTS.Scheduling.OriginalEstimate" = $estimatedHours
    "Microsoft.VSTS.Common.Priority" = $priority
    "Microsoft.VSTS.Common.Severity" = $severity
    "System.State" = "New"
    "System.AreaPath" = "Siepe.Software\Back Office SQL Engineers"
    "System.Tags" = "BAU; MOS Support"
} | ConvertTo-Json

# Create bug
$newBug = az boards work-item create `
    --title $bugTitle `
    --type "Bug" `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --fields $fields `
    --output json | ConvertFrom-Json

Write-Host "✅ Created Bug #$($newBug.id): $bugTitle" -ForegroundColor Green

# Link as child to user story
az boards work-item relation add `
    --id $newBug.id `
    --relation-type "Child" `
    --target-id $userStoryId `
    --org https://siepe.visualstudio.com/

Write-Host "✅ Linked as child to User Story #$userStoryId" -ForegroundColor Green
```

**Example creation:**

```powershell
# User input
$bugTitle = "Price override failing for equity 233"
$bugDescription = @"
When applying price override for equity_id 233 (Kleopatra Finco), the system fails to delete existing market values before inserting new override price.

**Issue:** deal_equity_market_value_del procedure not being called for all entity_ids

**Affected Entities:** 295, 298-304 (Trestles CLO portfolios)

**Expected:** DELETE statements for 22 days × 8 entities = 176 deletions
**Actual:** 0 deletions executed

**Root Cause:** Script missing loop to iterate through entity_ids
"@
$assignedTo = "tcnguyen@siepe.com"
$estimatedHours = 6  # Medium complexity - investigation + fix

# Execute creation
# (Commands from above)
```

---

## Step 5: Generate HTML Report

### 5A: Duplicate Detection Report (if duplicates found)

**If duplicates were found in Step 2, return this HTML:**

```html
<div class="mossy-response">
  
  <div class="response-header">
    <h2>⚠️ Duplicate Bug Detected</h2>
    <div class="metadata">
      <span class="badge badge-warning">Creation Blocked</span>
      <span class="timestamp">{TIMESTAMP}</span>
    </div>
  </div>

  <div class="summary-section">
    <h3>🔍 Similarity Check Results</h3>
    <div class="status-indicator status-warning">
      <span class="status-icon">⚠️</span>
      <span class="status-text">Found {DUPLICATE_COUNT} similar bug(s) - Not creating duplicate</span>
    </div>
  </div>

  <div class="content-section">
    <h3>📋 Your Request</h3>
    <table class="data-table">
      <tr>
        <td><strong>Title</strong></td>
        <td>{REQUESTED_TITLE}</td>
      </tr>
      <tr>
        <td><strong>Description</strong></td>
        <td>{REQUESTED_DESCRIPTION}</td>
      </tr>
    </table>

    <h3>🎯 Similar Bugs Found (≥60% match)</h3>
    <table class="data-table">
      <thead>
        <tr>
          <th>Bug ID</th>
          <th>Title</th>
          <th>State</th>
          <th>Similarity</th>
          <th>Link</th>
        </tr>
      </thead>
      <tbody>
        {DUPLICATE_ROWS}
        <!-- Example row:
        <tr>
          <td><span class="badge badge-info">#{BUG_ID}</span></td>
          <td>{BUG_TITLE}</td>
          <td><span class="badge badge-{STATE_CLASS}">{STATE}</span></td>
          <td><span class="badge badge-warning">{SIMILARITY}%</span></td>
          <td><a href="https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{BUG_ID}" target="_blank">View →</a></td>
        </tr>
        -->
      </tbody>
    </table>
  </div>

  <div class="recommendations-section">
    <h3>💡 Recommended Actions</h3>
    <ul class="recommendation-list">
      <li class="recommendation-item high-priority">
        <strong>Review Existing Bug:</strong> Check if the similar bug matches your needs
        <span class="priority-badge">Immediate</span>
      </li>
      <li class="recommendation-item medium-priority">
        <strong>Update Existing:</strong> Add comments or details to existing bug if needed
        <span class="priority-badge">Next</span>
      </li>
      <li class="recommendation-item low-priority">
        <strong>Create New:</strong> If truly different, rephrase title/description and retry
        <span class="priority-badge">Optional</span>
      </li>
    </ul>
  </div>

  <div class="response-footer">
    <button class="btn btn-primary" onclick="window.open('https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{FIRST_DUPLICATE_ID}', '_blank')">
      🐛 View Most Similar Bug
    </button>
    <button class="btn btn-secondary" onclick="window.open('https://siepe.visualstudio.com/Siepe.Software/_sprints/taskboard/Back%20Office%20SQL%20Engineers/Siepe.Software/{SPRINT_NUMBER}', '_blank')">
      📊 View Sprint Board
    </button>
  </div>

</div>
```

---

### 5B: Success Report (if bug created)

**Create structured HTML response:**

```html
<div class="mossy-response">
  
  <div class="response-header">
    <h2>🐛 Bug Work Item Created</h2>
    <div class="metadata">
      <span class="badge badge-success">Bug #{BUG_ID}</span>
      <span class="timestamp">{TIMESTAMP}</span>
    </div>
  </div>

  <div class="summary-section">
    <h3>🎯 Summary</h3>
    <div class="status-indicator status-success">
      <span class="status-icon">✅</span>
      <span class="status-text">Bug created in sprint {SPRINT_NUMBER}</span>
    </div>
  </div>

  <div class="content-section">
    <h3>📋 Bug Details</h3>
    
    <table class="data-table">
      <tr>
        <td><strong>Bug ID</strong></td>
        <td><a href="https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{BUG_ID}" target="_blank">#{BUG_ID}</a></td>
      </tr>
      <tr>
        <td><strong>Title</strong></td>
        <td>{BUG_TITLE}</td>
      </tr>
      <tr>
        <td><strong>Assigned To</strong></td>
        <td>{ASSIGNED_TO}</td>
      </tr>
      <tr>
        <td><strong>Estimated Hours</strong></td>
        <td>{ESTIMATED_HOURS} hours</td>
      </tr>
      <tr>
        <td><strong>Sprint</strong></td>
        <td>{SPRINT_NUMBER}</td>
      </tr>
      <tr>
        <td><strong>Parent User Story</strong></td>
        <td><a href="https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{USER_STORY_ID}" target="_blank">#{USER_STORY_ID} - CAMOS BAU Support {SPRINT_NUMBER}</a></td>
      </tr>
      <tr>
        <td><strong>State</strong></td>
        <td><span class="badge badge-info">New</span></td>
      </tr>
    </table>

    <div class="code-block">
      <div class="code-header">
        <span class="language-badge">Description</span>
      </div>
      <pre><code>{BUG_DESCRIPTION}</code></pre>
    </div>
  </div>

  <div class="recommendations-section">
    <h3>✅ Next Steps</h3>
    <ul class="recommendation-list">
      <li class="recommendation-item high-priority">
        <strong>1. Review Bug:</strong> Verify description and estimate are accurate
        <span class="priority-badge">Immediate</span>
      </li>
      <li class="recommendation-item medium-priority">
        <strong>2. Start Work:</strong> Move to Active when ready to begin
        <span class="priority-badge">Next</span>
      </li>
      <li class="recommendation-item low-priority">
        <strong>3. Track Progress:</strong> Update remaining hours as work progresses
        <span class="priority-badge">Ongoing</span>
      </li>
    </ul>
  </div>

  <div class="response-footer">
    <button class="btn btn-primary" onclick="window.open('https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{BUG_ID}', '_blank')">
      🐛 View Bug
    </button>
    <button class="btn btn-secondary" onclick="window.open('https://siepe.visualstudio.com/Siepe.Software/_sprints/taskboard/Back%20Office%20SQL%20Engineers/Siepe.Software/{SPRINT_NUMBER}', '_blank')">
      📊 View Sprint Board
    </button>
  </div>

</div>
```

**If duplicate found, return:**

```html
<div class="alert alert-warning">
  <strong>⚠️ Bug Already Exists:</strong> This issue is already tracked as 
  <a href="https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{EXISTING_BUG_ID}" target="_blank">Bug #{EXISTING_BUG_ID}</a>
</div>
```

---

## Step 6: Return Results

**Provide to user:**
1. ✅ Bug ID and link to work item
2. ✅ Confirmation of creation
3. ✅ Parent user story link
4. ✅ Sprint board link
5. ✅ Estimated hours assigned

**Save to:** `Output/BugCreated_{BUG_ID}_{DATE}.md`

---

## Error Handling

### Sprint Not Found
```
❌ No active CAMOS BAU Support user story found for current sprint.
Please verify sprint has started and user story exists.
```

### Authentication Failed
```
❌ Azure DevOps authentication required.
Run: az login
```

### Duplicate Bug
```
⚠️ Bug already exists: #{12345}
Skipping creation. View existing bug for details.
```

### Missing Required Field
```
❌ Missing required field: [Title|Description|Assigned To]
Please provide all required information.
```

---

## Usage Examples

**Example 1: Create bug with auto-assignment**
```
User: "@Mossy create bug - Price override failing for equity 233 due to missing DELETE loop"
Mossy: [Finds sprint → Checks duplicates → Estimates 6 hours → Creates bug → Returns #83789]
```

**Example 2: Duplicate detected**
```
User: "@Mossy create bug - Equity price override not working for security 233"
Mossy: ⚠️ DUPLICATE DETECTED - Bug creation halted
      
      Found 1 similar bug (≥60% match):
      
      Bug #83789 - 78% similar
      Title: Price override failing for equity 233 due to missing DELETE loop
      State: Active
      Link: https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/83789
      
      ❌ Not creating new bug - please review existing bug above
```

**Example 3: Create bug with specific assignment**
```
User: "@Mossy create bug assigned to John Smith - SSIS package normalization error for Aristotle tenant, investigate GenericNormalizationJob failures"
Mossy: [Creates bug assigned to jsmith@siepe.com → Estimates 8 hours → Returns #83790]
```

**Example 4: Create bug with explicit estimate**
```
User: "@Mossy create bug (2 hours) - Fix typo in Process Dashboard report title"
Mossy: [Uses 2 hour estimate provided → Creates bug → Returns #83791]
```

---

## Configuration

**Default Values (customizable):**

```powershell
# Configuration
$config = @{
    ParentFeatureId = 82437
    DefaultAssignee = "tcnguyen@siepe.com"
    AreaPath = "Siepe.Software\Back Office SQL Engineers"
    DefaultTags = "BAU; MOS Support"
    DefaultState = "New"
    Organization = "https://siepe.visualstudio.com/"
    Project = "Siepe.Software"
}
```
