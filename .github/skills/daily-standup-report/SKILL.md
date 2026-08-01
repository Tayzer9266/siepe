---
skill_name: daily-standup-report
title: Daily Standup Report Generator
description: Generate concise bullet-point standup updates from Tay Nguyen's Azure DevOps sprint board showing yesterday's completed work and today's in-progress tasks using Azure CLI.
version: 2.0
query_url: https://siepe.visualstudio.com/Siepe.Software/_queries/query-edit/4d3d26ea-89d8-4baf-bd76-9525f9cad5ed/
query_id: 4d3d26ea-89d8-4baf-bd76-9525f9cad5ed
organization: https://siepe.visualstudio.com/
project: Siepe.Software
output_format: markdown_bullets
last_updated: 2026-07-24
requires_cli: az boards
apply_to:
  - pattern: "**/*"
    when_user_mentions:
      - "standup"
      - "daily standup"
      - "scrum update"
      - "what did I work on"
      - "sprint status"
      - "daily status"
---

# Daily Standup Report Generator

## Purpose

Generate a concise daily standup summary for scrum meetings by reviewing Tay Nguyen's Azure DevOps sprint board and reporting:
- **Yesterday**: What was completed
- **Today**: What is currently in progress

Output is short bullet points - no lengthy descriptions.

---

## When to Use This Skill

### ✅ Use this skill when:
- User asks for standup update
- User needs to report to scrum team what they worked on yesterday
- User wants to know what's in progress today
- Preparing for daily scrum meeting
- Quick status check on assigned work items

### ❌ Do NOT use this skill when:
- User wants detailed sprint planning or full backlog review
- Creating new work items or tasks
- Investigating specific bugs or issues (use specialized skills instead)
- Generating weekly or monthly reports

---

## Query Information

**Query URL**: [CAMOS ALL - Boards](https://siepe.visualstudio.com/Siepe.Software/_queries/query-edit/4d3d26ea-89d8-4baf-bd76-9525f9cad5ed/)

**Query Filters**:
- Assigned to: Tay Nguyen
- Includes completed work items for historical tracking
- Current sprint focus

---

## Workflow

### Step 1: Access Azure DevOps Query via CLI

Use the Azure DevOps CLI to query work items assigned to Tay Nguyen:

```powershell
az boards query --id 4d3d26ea-89d8-4baf-bd76-9525f9cad5ed --organization https://siepe.visualstudio.com/ --project "Siepe.Software" --output table
```

This query returns all work items from the "CAMOS ALL - Boards" query including their:
- ID
- Work Item Type (Task, Bug, User Story, Database Release, etc.)
- Title
- Assigned To
- State (New, In Progress, Closed, etc.)

**Query URL**: [CAMOS ALL - Boards](https://siepe.visualstudio.com/Siepe.Software/_queries/query-edit/4d3d26ea-89d8-4baf-bd76-9525f9cad5ed/)

### Step 2: Identify Relevant Work Items

Filter work items from the CLI output by **State**:

**Yesterday's Work** (Completed):
- State: Closed
- Completed Date: Previous business day (use session history if available)
- Include task title and ID

**Today's Work** (In Progress):
- State: **In Progress** only (not "New")
- Currently assigned to Tay Nguyen
- Include task title and ID
- Include User Stories if they are "In Progress"

**Important**: Only include items with State = "In Progress" in the Today section. Do NOT include "New" items unless specifically requested.

### Step 3: Generate Bullet Points

**Format**:
```markdown
## Yesterday
- #12345: Fixed price override validation bug
- #12346: Completed SSIS error investigation for Elmwood

## Today
- #12347: Create Price Override Dashboard
- #12348: Create stored procedure Dashboard.pIntegrityAssetsPricedAtCost
```

**Rules**:
- ✅ **Keep it brief**: Task ID + task title (can shorten if needed)
- ✅ **Use exact titles from DevOps**: No need to elaborate
- ✅ **Yesterday section**: Can reference session history for context
- ✅ **Today section**: Only "In Progress" items from DevOps query
- ❌ **No lengthy details**: Avoid implementation specifics
- ❌ **No blockers section**: Unless user specifically asks

### Step 4: Present to User

Deliver the formatted bullet points immediately. User can copy-paste directly into standup chat or meeting notes.

---

## Example Output

### Scenario: User asks "What's my standup update?"

**Agent Response**:

## Yesterday
- #85341: Create stored procedure Report.pPricingInconsistenciesAcrossPortfolios
- #85344: Create TML file for pPricingInconsistenciesAcrossPortfolios deployment
- #85348: Create TML file for Day-Over-Day Price Changes deployment
- #85294: MOS - Missing Files for USBank

## Today
- #83816: Create Tag Pricing Override Dashboard for MOS (User Story)
- #84220: Create Price Override Dashboard
- #84463: Create a report that will auto unmap any reference ledgers
- #85341: Create stored procedure Report.pPricingInconsistenciesAcrossPortfolios
- #85345: Create stored procedure Dashboard.pIntegrityDayOverDayPriceChanges
- #85349: Create stored procedure Dashboard.pIntegrityAssetsPricedAtCost

---

## Alternative: Session Memory Approach

If Azure CLI is not available or user prefers session-based tracking:

1. Review session files for yesterday's date using session_store_sql
2. Extract completed tasks from file operations and ticket references
3. Check current open files or recent ticket activity for today's work
4. Generate bullet points from this data

**Note**: The CLI approach is preferred as it provides the most accurate, real-time view of DevOps work items.

---

## Notes

- **Keep it conversational**: Standup updates should be scannable
- **Use past tense** for yesterday, **present tense** for today's work
- **No need for "blockers"** unless user mentions impediments
- **Time estimate**: Should take <30 seconds to generate
- **Azure CLI Required**: Ensure `az boards` commands are available
- **Query ID**: 4d3d26ea-89d8-4baf-bd76-9525f9cad5ed (CAMOS ALL - Boards)
- **Only "In Progress" for Today**: Don't include "New" items in today's section
