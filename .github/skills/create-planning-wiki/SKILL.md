---
skill_name: create-planning-wiki
title: Planning Wiki Document Generator
description: Generate Azure DevOps wiki planning documents following standard format for Epics, Features, and User Stories. Creates Overview, Work Items, Roadmap, and Progress pages with proper structure and Azure CLI integration.
version: 1.0
organization: https://siepe.visualstudio.com/
project: Siepe.Software
wiki_name: Siepe Wiki
wiki_path: /Planning
output_format: azure_devops_wiki
last_updated: 2026-07-30
requires_cli: az boards, az devops wiki
applies_to:
  - pattern: "**/*"
    when_user_mentions:
      - "create planning wiki"
      - "planning document"
      - "epic planning"
      - "project planning"
      - "wiki page"
      - "roadmap document"
---

# Planning Wiki Document Generator

## Purpose

Generate comprehensive planning wiki documentation in Azure DevOps for Epics, Features, or User Stories following the standard Siepe planning format. Creates structured markdown pages with proper hierarchy, work item tracking, roadmap phases, and progress monitoring.

---

## When to Use This Skill

### ✅ Use this skill when:
- User asks to create planning documentation for an Epic, Feature, or User Story
- Starting a new project and need structured planning pages
- Need to generate Overview, Work Items, Roadmap, or Progress documentation
- Creating wiki pages in Azure DevOps /Planning folder
- User says "create planning wiki for {work item ID}"

### ❌ Do NOT use this skill when:
- Just viewing existing work items (use Azure CLI directly)
- Creating individual ADO work items without wiki documentation
- Updating existing wiki pages (use wiki edit commands)
- Generating standup reports (use daily-standup-report skill)

---

## Required Information

To create planning wiki pages, gather:

1. **Work Item ID** - Epic, Feature, or User Story ID from Azure DevOps (e.g., 85904)
2. **Project Folder Path** (optional) - Path to local project documentation (e.g., `C:\source\MD\ProjectName`)
3. **Developer Name** - Name for tracking (default: "Tay Nguyen")

---

## Wiki Structure

Planning wikis follow this hierarchy:

```
/Planning/
  └── YYYY-MM-DD-{workItemId}-{slug-name}/
      ├── Overview.md
      ├── Work Items.md
      ├── Roadmap.md
      ├── Progress.md
      ├── Test Plan.md (optional)
      └── Timing.md (optional)
```

### Naming Convention

**Parent page format**: `YYYY-MM-DD-{workItemId}-{project-slug}`

Example: `2026-07-30-85904-ice-price-request-automation`

- **YYYY-MM-DD**: Current date
- **workItemId**: Azure DevOps work item ID
- **project-slug**: Lowercase, hyphenated project name derived from work item title

---

## Workflow

### Step 1: Fetch Work Item Details

Use Azure CLI to get work item information:

```powershell
# Get work item details
$workItemId = 85904
$workItem = az boards work-item show --id $workItemId --org https://siepe.visualstudio.com/ --project "Siepe.Software" --output json | ConvertFrom-Json

$title = $workItem.fields.'System.Title'
$workItemType = $workItem.fields.'System.WorkItemType'
$state = $workItem.fields.'System.State'
$description = $workItem.fields.'System.Description'

Write-Host "Work Item: #$workItemId - $title ($workItemType)"
```

### Step 2: Fetch Child Work Items (for Epic/Feature)

```powershell
# Get all child work items
$relations = az boards work-item relation show --id $workItemId --org https://siepe.visualstudio.com/ --project "Siepe.Software" --output json | ConvertFrom-Json

# Extract child IDs
$childIds = $relations.relations | Where-Object { $_.rel -eq "System.LinkTypes.Hierarchy-Forward" } | ForEach-Object { 
    $_.url -replace '.*/', '' 
}

# Fetch each child work item
$children = @()
foreach ($childId in $childIds) {
    $child = az boards work-item show --id $childId --org https://siepe.visualstudio.com/ --project "Siepe.Software" --output json | ConvertFrom-Json
    $children += [PSCustomObject]@{
        ID = $childId
        Type = $child.fields.'System.WorkItemType'
        Title = $child.fields.'System.Title'
        State = $child.fields.'System.State'
        Parent = $workItemId
    }
}
```

### Step 3: Generate Page Slug

```powershell
# Create URL-friendly slug from title
$slug = $title.ToLower() -replace '[^a-z0-9\s-]', '' -replace '\s+', '-' -replace '-+', '-'
$today = Get-Date -Format "yyyy-MM-dd"
$pageName = "$today-$workItemId-$slug"

Write-Host "Planning page: /Planning/$pageName/" -ForegroundColor Green
```

### Step 4: Generate Overview.md

**Template**:

```markdown
# PROJECT: {Project Title}

## Vision
{One paragraph describing the end goal and value proposition - extract from work item description or ask user}

## Problem Statement
{What problem are we solving? What's the current pain point?}

## Solution
{How are we solving it? Key architectural approach}

## Scope – Phase 1 (Foundation)

### In Scope
- {Deliverable 1}
- {Deliverable 2}
- {Deliverable 3}

### Out of Scope (Future Phases)
- {Features deferred to later phases}
- {Known limitations}

## Goals
1. {Measurable goal with success metric}
2. {Another measurable goal}
3. {User satisfaction target}

## Architecture

### New Projects (if applicable)
| Project | Purpose |
|---------|---------|
| {Path/To/Project} | {Description} |

### Files to Modify (if applicable)
| File | Change |
|------|--------|
| {path/to/file} | {What changes} |

### Patterns to Reuse
| Pattern | Source |
|---------|--------|
| {PatternName} | {Where it's from} |

## Technical Constraints
- {Technical requirement 1}
- {Framework versions}
- {Coding standards}
- {Authentication requirements}

## {Work Item Type}
ADO #{workItemId} – {Work Item Title}
{Work Item URL}
```

### Step 5: Generate Work Items.md

**Template**:

```markdown
# Work Items

**Created:** {YYYY-MM-DD}
**Developer:** {Developer Name}
**{Work Item Type}:** #{workItemId} - {Title}
**URL:** https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{workItemId}

## Hierarchy

| ID | Type | Title | Parent | State |
|----|------|-------|--------|-------|
{For each work item in hierarchy:}
| {id} | {type} | {title} | {parent reference} | {state} |

## Phase to Feature Mapping

| Phase | Feature ID | Feature Title |
|-------|------------|---------------|
| 1 | #{featureId} | {Feature Title} |

## Summary

| Type | Count |
|------|-------|
| Epic | {count} |
| Features | {count} |
| User Stories | {count} |
| Tasks | {count} |
| **Total** | **{total}** |
```

### Step 6: Generate Roadmap.md

**Template**:

```markdown
# ROADMAP: {Project Title} – Phase 1 Foundation

## Overview
{Brief description of the phased approach and architecture decisions}

## Architecture Decision
{Key architectural choices and rationale}

---

## Phase 1: {Phase Name}
**Goal:** {What this phase accomplishes}
**Research:** {Yes/No - Does this phase require investigation?}
**Dependencies:** {Previous phases required, or "–" if none}
**Deliverables:**
- {Concrete deliverable 1}
- {Concrete deliverable 2}
- {Concrete deliverable 3}

**Success Signal:** {How we know this phase is complete}

---

## Phase 2: {Phase Name}
**Goal:** {What this phase accomplishes}
**Research:** {Yes/No}
**Dependencies:** {Phase 1}
**Deliverables:**
- {Deliverable 1}
- {Deliverable 2}

**Success Signal:** {Completion criteria}

---

## Phase Summary

| Phase | Title | Research | Dependencies | Est. Complexity |
|-------|-------|----------|--------------|-----------------|
| 1 | {title} | No | – | Low |
| 2 | {title} | Yes | 1 | High |
| 3 | {title} | No | 2 | Medium |
```

### Step 7: Generate Progress.md

**Template**:

```markdown
# Implementation Progress: {Project Title}

**Started:** {YYYY-MM-DD}
**Developer:** {Developer Name}
**Last Updated:** {YYYY-MM-DD}
**Status:** {In Progress / Not Started / Complete / Blocked}

## Progress Summary

- **Tasks:** 0/{total} complete (0%)
- **Stories:** 0/{total} complete (0%)
- **Features:** 0/{total} complete (0%)

## Completed Tasks

| Task | ID | Completed | Phase |
|------|----|-----------|-------|
| {No tasks completed yet} | - | - | - |

## Test Summary

- **Total tests:** 0
- **All passing:** N/A
- Phase 1: 0 tests
- Phase 2: 0 tests

## Verifications

| Work Item | Verified | Result | Issues |
|-----------|----------|--------|--------|
| {Not yet started} | - | - | - |

## Architecture Notes

- {Implementation details to be added during development}
- {Important decisions made during implementation}
- {Lessons learned}
```

### Step 8: Create Wiki Pages (Optional - requires confirmation)

```powershell
# Create parent planning page
$parentContent = "# Planning: $title`n`nSee subpages for detailed planning documentation."
az devops wiki page create --wiki "Siepe Wiki" --path "/Planning/$pageName" --content $parentContent --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Create Overview subpage
$overviewContent = Get-Content "Overview.md" -Raw
az devops wiki page create --wiki "Siepe Wiki" --path "/Planning/$pageName/Overview" --content $overviewContent --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Repeat for Work Items, Roadmap, Progress
```

---

## Output Format

### Generated Files

Create markdown files in local directory first:

```
C:\source\MD\Planning_{workItemId}\
  ├── Overview.md
  ├── Work Items.md
  ├── Roadmap.md
  └── Progress.md
```

### Console Output

```markdown
## Planning Wiki Generated

**Work Item:** #{workItemId} - {Title}
**Type:** {Epic/Feature/User Story}
**Page Name:** /Planning/{pageName}/

### Generated Files:
✅ Overview.md - Project vision and architecture
✅ Work Items.md - Complete work item hierarchy ({total} items)
✅ Roadmap.md - {phases} phase implementation plan
✅ Progress.md - Progress tracking initialized

### Next Steps:
1. Review generated markdown files in: C:\source\MD\Planning_{workItemId}\
2. Customize Overview with project-specific details
3. Add phase deliverables to Roadmap
4. Upload to Azure DevOps wiki (optional)

**Upload Command:**
```powershell
# Upload to wiki (confirm with user first)
az devops wiki page create --wiki "Siepe Wiki" --path "/Planning/{pageName}" --file "Overview.md" --org https://siepe.visualstudio.com/
```
```

---

## User Interaction Pattern

### Example Dialog

**User:** "Create planning wiki for task 85904"

**Agent:**
1. Fetches work item 85904 from Azure DevOps
2. Displays work item details: "#85904: 36168Q104 - ICE Price not Requested (Task)"
3. Asks clarifying questions:
   - "This is a Task. Would you like to create planning for the parent User Story/Feature instead?"
   - "Should I include project folder path for documentation? (optional)"
   - "Any specific phases or deliverables to include in roadmap?"
4. Generates markdown files
5. Shows summary with file locations
6. Asks: "Would you like me to upload these to Azure DevOps wiki?"

---

## Important Notes

### Work Item Type Considerations

- **Epic**: Create full planning structure with multiple phases
- **Feature**: Create planning with 1-3 phases
- **User Story**: Simplified planning, may skip roadmap if single-phase
- **Task**: Usually too granular - suggest planning for parent Story/Feature instead

### Content Customization

**Required from User:**
- Vision/problem statement (if not in work item description)
- In-scope vs out-of-scope items
- Phase deliverables
- Success metrics

**Auto-Generated:**
- Work item hierarchy table
- Child task list
- Summary counts
- Page structure and formatting

### Wiki Upload Confirmation

**ALWAYS ask before uploading to wiki** - user may want to review/edit files first.

```powershell
# Show confirmation prompt
Write-Host "`n⚠️  Ready to upload to Azure DevOps wiki?" -ForegroundColor Yellow
Write-Host "   Page: /Planning/$pageName/" -ForegroundColor Cyan
Write-Host "   Files: Overview.md, Work Items.md, Roadmap.md, Progress.md`n"
$confirm = Read-Host "Upload now? (y/n)"
```

---

## Azure CLI Reference

### Query Work Items by Parent

```powershell
# Get all children of a work item
az boards query --wiql "SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State] FROM WorkItems WHERE [System.Parent] = {parentId}" --org https://siepe.visualstudio.com/ --project "Siepe.Software"
```

### Get Work Item with Specific Fields

```powershell
az boards work-item show --id {workItemId} --org https://siepe.visualstudio.com/ --project "Siepe.Software" --fields "System.Title" "System.WorkItemType" "System.State" "System.Description" "System.AssignedTo"
```

### Create/Update Wiki Pages

```powershell
# Create new wiki page
az devops wiki page create --wiki "Siepe Wiki" --path "/Planning/{pageName}/Overview" --file "Overview.md" --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Update existing wiki page
az devops wiki page update --wiki "Siepe Wiki" --path "/Planning/{pageName}/Progress" --file "Progress.md" --org https://siepe.visualstudio.com/ --project "Siepe.Software" --version {etag}
```

---

## Error Handling

### Work Item Not Found
```
Error: Work item {id} not found or access denied.
Verify: 
- Work item ID is correct
- You have access to Siepe.Software project
- Azure CLI is authenticated: az login
```

### Wiki Permission Issues
```
Error: TF401019: The Git repository with name or identifier Siepe Wiki does not exist.
Resolution: Verify wiki name with: az devops wiki list --org https://siepe.visualstudio.com/
```

### Missing Work Item Description
```
Warning: Work item has no description. 
Action: Prompt user for vision/problem statement to populate Overview.
```

---

## Version History

- **v1.0** (2026-07-30): Initial skill created based on PLANNING_WIKI_FORMAT.md
