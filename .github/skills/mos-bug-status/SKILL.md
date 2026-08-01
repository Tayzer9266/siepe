# MOS Bug Status and Updates

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration  
**Category:** DevOps Work Item Reporting  
**Difficulty:** Beginner-Intermediate  
**Est. Time:** 3-5 minutes

## Purpose

Query and summarize bug status from Azure DevOps. Enhanced with dashboard screenshot analysis to show bug status snapshots and trend visualizations. Provides updates on specific bugs or generates summary reports of all outstanding bugs under the current sprint's BAU Support user story.

---

## Step 0: Analyze Bug Dashboard Screenshots

**Step 0.1: Screenshot Analysis**
```powershell
# If ticket has attached screenshots, analyze them
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - Bug dashboard screenshots showing status distribution
# - Bug trend charts
# - Sprint board snapshots
# - Bug status changes over time
```

## Step 1: Determine Query Type

**User request patterns:**

| Request Pattern | Query Type | Action |
|----------------|------------|--------|
| "status of bug #83789" | Single Bug | Query specific work item |
| "update on task 83789" | Single Bug | Query specific work item |
| "what's going on with #83789" | Single Bug | Query specific work item |
| "outstanding bugs" | All Bugs | Query all non-closed bugs |
| "summarize bugs" | All Bugs | Query all bugs and group by status |
| "bug report" | All Bugs | Generate full report |
| "my bugs" | Assigned Bugs | Query bugs assigned to user |

---

## Step 2A: Query Single Bug Status

**Get bug details:**

```powershell
$bugId = 83789

# Get full work item details
$bug = az boards work-item show --id $bugId --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json

# Extract key fields
$bugInfo = @{
    Id = $bug.id
    Title = $bug.fields.'System.Title'
    State = $bug.fields.'System.State'
    AssignedTo = $bug.fields.'System.AssignedTo'.displayName
    CreatedDate = $bug.fields.'System.CreatedDate'
    ChangedDate = $bug.fields.'System.ChangedDate'
    Priority = $bug.fields.'Microsoft.VSTS.Common.Priority'
    Severity = $bug.fields.'Microsoft.VSTS.Common.Severity'
    OriginalEstimate = $bug.fields.'Microsoft.VSTS.Scheduling.OriginalEstimate'
    RemainingWork = $bug.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
    CompletedWork = $bug.fields.'Microsoft.VSTS.Scheduling.CompletedWork'
    Description = $bug.fields.'System.Description'
    Tags = $bug.fields.'System.Tags'
}

# Get recent comments/discussions
$comments = az boards work-item relation show --id $bugId --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json

# Calculate days open
$created = [DateTime]::Parse($bugInfo.CreatedDate)
$daysOpen = ([DateTime]::Now - $created).Days
```

**Expected Output:**

```
Bug #83789: Price override failing for equity 233
State: Active
Assigned To: Tay Nguyen
Priority: 2
Created: 2026-07-21 (1 day ago)
Last Updated: 2026-07-22 10:15 AM
Original Estimate: 6 hours
Remaining Work: 4 hours
Completed Work: 2 hours
Progress: 33%
```

---

## Step 2B: Query All Outstanding Bugs

**Find current sprint user story:**

```powershell
# Query for active BAU Support user story
$query = "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.Parent] = 82437 AND [System.Title] CONTAINS 'CAMOS BAU Support' AND [System.State] IN ('New', 'Active') ORDER BY [System.CreatedDate] DESC"

$userStory = az boards query --wiql $query --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json | Select-Object -First 1
$userStoryId = $userStory.workItems[0].id
```

**Query all bugs under user story:**

```powershell
# Get all child bugs
$bugQuery = "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.CreatedDate], [Microsoft.VSTS.Common.Priority], [Microsoft.VSTS.Scheduling.OriginalEstimate], [Microsoft.VSTS.Scheduling.RemainingWork] FROM WorkItems WHERE [System.Parent] = $userStoryId AND [System.WorkItemType] = 'Bug' AND [System.State] NOT IN ('Closed', 'Resolved', 'Removed') ORDER BY [Microsoft.VSTS.Common.Priority] ASC, [System.CreatedDate] ASC"

$bugs = az boards query --wiql $bugQuery --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json

# Process each bug
$bugList = @()
foreach ($bugRef in $bugs.workItems) {
    $bugDetail = az boards work-item show --id $bugRef.id --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json
    
    $bugList += [PSCustomObject]@{
        Id = $bugDetail.id
        Title = $bugDetail.fields.'System.Title'
        State = $bugDetail.fields.'System.State'
        AssignedTo = $bugDetail.fields.'System.AssignedTo'.displayName
        Priority = $bugDetail.fields.'Microsoft.VSTS.Common.Priority'
        Severity = $bugDetail.fields.'Microsoft.VSTS.Common.Severity'
        Created = $bugDetail.fields.'System.CreatedDate'
        Estimate = $bugDetail.fields.'Microsoft.VSTS.Scheduling.OriginalEstimate'
        Remaining = $bugDetail.fields.'Microsoft.VSTS.Scheduling.RemainingWork'
        DaysOpen = ([DateTime]::Now - [DateTime]::Parse($bugDetail.fields.'System.CreatedDate')).Days
    }
}

Write-Host "Found $($bugList.Count) outstanding bugs" -ForegroundColor Cyan
```

---

## Step 3: Generate Summary Statistics

**Group by state:**

```powershell
$byState = $bugList | Group-Object State | Select-Object Name, Count | Sort-Object Count -Descending

# Output
# Name      Count
# ----      -----
# Active    5
# New       3
# Resolved  1
```

**Group by assigned to:**

```powershell
$byAssignee = $bugList | Group-Object AssignedTo | Select-Object Name, Count | Sort-Object Count -Descending

# Output
# Name          Count
# ----          -----
# Tay Nguyen    4
# John Smith    3
# Unassigned    2
```

**Group by priority:**

```powershell
$byPriority = $bugList | Group-Object Priority | Select-Object @{N='Priority';E={
    switch($_.Name) {
        '1' {'1 - Critical'}
        '2' {'2 - High'}
        '3' {'3 - Medium'}
        '4' {'4 - Low'}
    }
}}, Count | Sort-Object Priority
```

**Calculate totals:**

```powershell
$totalEstimate = ($bugList | Measure-Object -Property Estimate -Sum).Sum
$totalRemaining = ($bugList | Measure-Object -Property Remaining -Sum).Sum
$totalCompleted = $totalEstimate - $totalRemaining
$percentComplete = if ($totalEstimate -gt 0) { [Math]::Round(($totalCompleted / $totalEstimate) * 100, 1) } else { 0 }

Write-Host "Total Estimate: $totalEstimate hours" -ForegroundColor Cyan
Write-Host "Completed: $totalCompleted hours ($percentComplete%)" -ForegroundColor Green
Write-Host "Remaining: $totalRemaining hours" -ForegroundColor Yellow
```

---

## Step 4: Generate HTML Report

### 4A: Single Bug Report

```html
<div class="mossy-response">
  
  <div class="response-header">
    <h2>🐛 Bug Status: #{BUG_ID}</h2>
    <div class="metadata">
      <span class="badge badge-{state-class}">{STATE}</span>
      <span class="badge badge-priority-{priority}">P{PRIORITY}</span>
      <span class="timestamp">Last Updated: {CHANGED_DATE}</span>
    </div>
  </div>

  <div class="summary-section">
    <h3>🎯 {BUG_TITLE}</h3>
    <div class="status-grid">
      <div class="status-card">
        <div class="card-title">⏱️ Days Open</div>
        <div class="card-value">{DAYS_OPEN}</div>
      </div>
      <div class="status-card">
        <div class="card-title">📊 Progress</div>
        <div class="card-value">{PERCENT_COMPLETE}%</div>
      </div>
      <div class="status-card">
        <div class="card-title">⏳ Remaining</div>
        <div class="card-value">{REMAINING_HOURS}h</div>
      </div>
    </div>
  </div>

  <div class="content-section">
    <h3>📋 Details</h3>
    
    <table class="data-table">
      <tr>
        <td><strong>Assigned To</strong></td>
        <td>{ASSIGNED_TO}</td>
      </tr>
      <tr>
        <td><strong>Priority</strong></td>
        <td>{PRIORITY_LABEL}</td>
      </tr>
      <tr>
        <td><strong>Severity</strong></td>
        <td>{SEVERITY_LABEL}</td>
      </tr>
      <tr>
        <td><strong>Created</strong></td>
        <td>{CREATED_DATE}</td>
      </tr>
      <tr>
        <td><strong>Original Estimate</strong></td>
        <td>{ORIGINAL_ESTIMATE} hours</td>
      </tr>
      <tr>
        <td><strong>Completed Work</strong></td>
        <td>{COMPLETED_WORK} hours</td>
      </tr>
      <tr>
        <td><strong>Remaining Work</strong></td>
        <td>{REMAINING_WORK} hours</td>
      </tr>
    </table>

    <div class="code-block">
      <div class="code-header">
        <span class="language-badge">Description</span>
      </div>
      <pre><code>{DESCRIPTION}</code></pre>
    </div>

    <details class="collapsible-section">
      <summary><strong>💬 Recent Comments</strong></summary>
      <div class="collapsible-content">
        {COMMENTS_LIST}
      </div>
    </details>
  </div>

  <div class="response-footer">
    <button class="btn btn-primary" onclick="window.open('https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{BUG_ID}', '_blank')">
      🐛 View in Azure DevOps
    </button>
  </div>

</div>
```

### 4B: All Bugs Summary Report

```html
<div class="mossy-response">
  
  <div class="response-header">
    <h2>🐛 Outstanding Bugs Summary</h2>
    <div class="metadata">
      <span class="badge badge-info">Sprint {SPRINT_NUMBER}</span>
      <span class="timestamp">{TIMESTAMP}</span>
    </div>
  </div>

  <div class="summary-section">
    <h3>🎯 Overview</h3>
    <div class="status-grid">
      <div class="status-card status-info">
        <div class="card-title">🐛 Total Bugs</div>
        <div class="card-value">{TOTAL_BUGS}</div>
        <div class="card-detail">Outstanding</div>
      </div>
      <div class="status-card status-warning">
        <div class="card-title">⏳ Total Hours</div>
        <div class="card-value">{TOTAL_REMAINING}h</div>
        <div class="card-detail">Remaining work</div>
      </div>
      <div class="status-card status-success">
        <div class="card-title">✅ Progress</div>
        <div class="card-value">{PERCENT_COMPLETE}%</div>
        <div class="card-detail">Complete</div>
      </div>
    </div>
  </div>

  <div class="content-section">
    <h3>📊 Bugs by State</h3>
    <table class="data-table">
      <thead>
        <tr>
          <th>State</th>
          <th>Count</th>
          <th>Percentage</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td><span class="badge badge-info">New</span></td>
          <td>{NEW_COUNT}</td>
          <td>{NEW_PERCENT}%</td>
        </tr>
        <tr>
          <td><span class="badge badge-warning">Active</span></td>
          <td>{ACTIVE_COUNT}</td>
          <td>{ACTIVE_PERCENT}%</td>
        </tr>
        <tr>
          <td><span class="badge badge-success">Resolved</span></td>
          <td>{RESOLVED_COUNT}</td>
          <td>{RESOLVED_PERCENT}%</td>
        </tr>
      </tbody>
    </table>

    <h3>👥 Bugs by Assignee</h3>
    <table class="data-table">
      <thead>
        <tr>
          <th>Assignee</th>
          <th>Bugs</th>
          <th>Remaining Hours</th>
        </tr>
      </thead>
      <tbody>
        {ASSIGNEE_ROWS}
      </tbody>
    </table>

    <details class="collapsible-section">
      <summary>
        <strong>🔥 High Priority Bugs</strong>
        <span class="badge badge-danger">{HIGH_PRIORITY_COUNT}</span>
      </summary>
      <div class="collapsible-content">
        <table class="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Title</th>
              <th>State</th>
              <th>Assigned To</th>
              <th>Days Open</th>
            </tr>
          </thead>
          <tbody>
            {HIGH_PRIORITY_BUG_ROWS}
          </tbody>
        </table>
      </div>
    </details>

    <details class="collapsible-section">
      <summary>
        <strong>📋 All Outstanding Bugs</strong>
        <span class="badge badge-info">{TOTAL_BUGS}</span>
      </summary>
      <div class="collapsible-content">
        <table class="data-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Title</th>
              <th>State</th>
              <th>Priority</th>
              <th>Assigned To</th>
              <th>Estimate</th>
              <th>Remaining</th>
              <th>Days Open</th>
            </tr>
          </thead>
          <tbody>
            {ALL_BUG_ROWS}
          </tbody>
        </table>
      </div>
    </details>
  </div>

  <div class="recommendations-section">
    <h3>⚠️ Attention Needed</h3>
    <ul class="recommendation-list">
      <li class="recommendation-item high-priority" *ngIf="{HAS_OLD_BUGS}">
        <strong>{OLD_BUG_COUNT} bugs older than 7 days:</strong> Review and prioritize
        <span class="priority-badge">High</span>
      </li>
      <li class="recommendation-item medium-priority" *ngIf="{HAS_UNASSIGNED}">
        <strong>{UNASSIGNED_COUNT} unassigned bugs:</strong> Assign to team members
        <span class="priority-badge">Medium</span>
      </li>
      <li class="recommendation-item low-priority">
        <strong>Sprint Progress:</strong> {PERCENT_COMPLETE}% complete
        <span class="priority-badge">Info</span>
      </li>
    </ul>
  </div>

  <div class="response-footer">
    <button class="btn btn-primary" onclick="window.open('https://siepe.visualstudio.com/Siepe.Software/_sprints/taskboard/Back%20Office%20SQL%20Engineers/Siepe.Software/{SPRINT_NUMBER}', '_blank')">
      📊 View Sprint Board
    </button>
    <button class="btn btn-secondary" onclick="exportBugReport()">
      💾 Export Report
    </button>
  </div>

</div>
```

---

## Step 5: Return Results

**For single bug:**
- Display current state, progress, assignee
- Show days open and remaining work
- Include recent comments/updates

**For all bugs:**
- Summary statistics (total, by state, by assignee)
- Highlight high-priority and old bugs
- Progress percentage

**Save detailed report to:** `Output/BugStatus_{SPRINT}_{DATE}.md`

---

## Usage Examples

**Example 1: Single bug status**
```
User: "@Mossy what's going on with bug #83789?"
Mossy: [Queries bug → Returns status: Active, 2 hours completed, 4 hours remaining, 33% done]
```

**Example 2: All outstanding bugs**
```
User: "@Mossy summarize outstanding bugs"
Mossy: [Queries sprint → Gets all bugs → Returns: 9 total, 5 active, 3 new, 1 resolved, 45 hours remaining]
```

**Example 3: My assigned bugs**
```
User: "@Mossy show my bugs"
Mossy: [Filters by current user → Returns: 4 bugs assigned to you, 18 hours remaining]
```

---

## Configuration

**Query Settings:**

```powershell
# Outstanding bug definition
$outstandingStates = @('New', 'Active', 'Committed', 'In Progress')

# Excluded states
$closedStates = @('Closed', 'Resolved', 'Removed', 'Done', 'Completed')

# Priority labels
$priorityLabels = @{
    '1' = '🔴 Critical'
    '2' = '🟠 High'
    '3' = '🟡 Medium'
    '4' = '🟢 Low'
}

# Old bug threshold
$oldBugDays = 7
```
