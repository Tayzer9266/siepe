# Planning Wiki Format Guide

This document describes the expected format for planning wiki pages in Azure DevOps.

## Required Information

To create a planning wiki page, you need:

1. **Epic ID** or **Feature ID** or **User Story ID** - The work item ID from Azure DevOps
2. **Project Folder Path** - Path to your local project/documentation folder (e.g., `C:\source\MD\payload_render_client_side_formulas`)
3. **Developer Name** - Your name for tracking (e.g., "Tay Nguyen")

## Wiki Structure

Planning wikis follow this structure:

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

Parent page name format: `YYYY-MM-DD-{workItemId}-{project-slug}`

Example: `2026-05-29-12345-client-side-formula-rendering`

- **YYYY-MM-DD**: Current date
- **workItemId**: Azure DevOps Epic/Feature/Story ID
- **project-slug**: Lowercase, hyphenated project name

## Page Templates

### 1. Overview.md

**Purpose:** High-level project description, vision, architecture, and scope.

**Required Sections:**
```markdown
# PROJECT: {Project Title}

## Vision
One paragraph describing the end goal and value proposition.

## Problem Statement
What problem are we solving? What's the current pain point?

## Solution
How are we solving it? Key architectural approach.

## Scope – Phase 1 (Foundation)

### In Scope
- Bullet list of deliverables
- Features to implement
- Components to build

### Out of Scope (Future Phases)
- Features deferred to later phases
- Known limitations

## Goals
1. Measurable goal with success metric
2. Another measurable goal
3. User satisfaction target

## Architecture

### New Projects (if applicable)
| Project | Purpose |
|---------|---------|
| Path/To/Project | Description |

### Files to Modify (if applicable)
| File | Change |
|------|--------|
| path/to/file | What changes |

### Patterns to Reuse
| Pattern | Source |
|---------|--------|
| PatternName | Where it's from |

## Technical Constraints
- List of technical requirements
- Framework versions
- Coding standards
- Authentication requirements

## Epic
ADO #{epicId} – {Epic Title}
```

### 2. Work Items.md

**Purpose:** Complete hierarchy of all work items (Epic > Features > Stories > Tasks).

**Required Sections:**
```markdown
# Work Items

**Created:** YYYY-MM-DD
**Developer:** {Your Name}
**Epic:** #{epicId} - {Epic Title}
**URL:** https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{epicId}

## Hierarchy

| ID | Type | Title | Parent |
|----|------|-------|--------|
| {id} | Epic | {title} | - |
| {id} | Feature | {title} | Epic #{parentId} |
| {id} | User Story | {title} | Feature #{parentId} |
| {id} | Task | {title} | Story #{parentId} |

## Phase to Feature Mapping

| Phase | Feature ID | Feature Title |
|-------|------------|---------------|
| 1 | #{id} | {title} |
| 2 | #{id} | {title} |

## Summary

| Type | Count |
|------|-------|
| Epic | 1 |
| Features | X |
| User Stories | Y |
| Tasks | Z |
| **Total** | **N** |
```

**Azure CLI Commands to Fetch Work Items:**

```powershell
# Get Epic details
az boards work-item show --id {epicId} --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Get all child work items (Features, Stories, Tasks)
az boards work-item relation show --id {epicId} --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Query work items by parent
az boards query --wiql "SELECT [System.Id], [System.Title], [System.WorkItemType] FROM WorkItems WHERE [System.Parent] = {parentId}" --org https://siepe.visualstudio.com/ --project "Siepe.Software"
```

### 3. Roadmap.md

**Purpose:** Phase-by-phase implementation plan.

**Required Sections:**
```markdown
# ROADMAP: {Project Title} – Phase 1 Foundation

## Overview
Brief description of the phased approach and architecture decisions.

## Architecture Decision
Key architectural choices and rationale.

---

## Phase {N}: {Phase Name}
**Goal:** What this phase accomplishes.
**Research:** Yes/No - Does this phase require investigation?
**Dependencies:** Previous phases required (if any)
**Deliverables:**
- Concrete deliverable 1
- Concrete deliverable 2
- Concrete deliverable 3

**Success Signal:** How we know this phase is complete.

---

## Phase Summary

| Phase | Title | Research | Dependencies | Est. Complexity |
|-------|-------|----------|--------------|-----------------|
| 1 | {title} | No | – | Low |
| 2 | {title} | Yes | 1 | High |
| 3 | {title} | No | 2 | Medium |
```

### 4. Progress.md

**Purpose:** Track implementation progress with dates and status.

**Required Sections:**
```markdown
# Implementation Progress: {Project Title}

**Started:** YYYY-MM-DD
**Developer:** {Your Name}
**Last Updated:** YYYY-MM-DD
**Status:** {In Progress / Complete / Blocked}

## Progress Summary

- **Tasks:** X/Y complete (Z%)
- **Stories:** A/B complete
- **Features:** C/D complete

## Completed Tasks

| Task | ID | Completed | Phase |
|------|----|-----------|-------|
| {task title} | #{id} | YYYY-MM-DD | 1 |
| {task title} | #{id} | YYYY-MM-DD | 1 |

## Test Summary

- **Total tests:** X
- **All passing:** Yes/No
- Phase 1: X tests
- Phase 2: Y tests

## Verifications

| Work Item | Verified | Result | Issues |
|-----------|----------|--------|--------|
| #{id} Phase 1 | YYYY-MM-DD | Passed | None |
| #{id} Phase 2 | YYYY-MM-DD | Passed | None |

## Architecture Notes

- Key implementation details
- Important decisions made during implementation
- Lessons learned
```

### 5. Test Plan.md (Optional)

**Purpose:** Testing strategy and test cases.

### 6. Timing.md (Optional)

**Purpose:** Milestones and timeline estimates.

## Azure CLI Commands Reference

### Fetch Epic/Feature/Story Details
```powershell
# Get work item by ID
az boards work-item show --id {workItemId} --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Get all child work items
az boards work-item relation show --id {workItemId} --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Get specific fields only
az boards work-item show --id {workItemId} --org https://siepe.visualstudio.com/ --project "Siepe.Software" --fields "System.Title" "System.WorkItemType" "System.State"
```

### Create Wiki Pages
```powershell
# Create parent planning page
az devops wiki page create --wiki "Siepe Wiki" --path "/Planning/{page-name}" --content "{markdown content}" --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Create subpage
az devops wiki page create --wiki "Siepe Wiki" --path "/Planning/{parent-page}/Overview" --content "{markdown content}" --org https://siepe.visualstudio.com/ --project "Siepe.Software"
```

## Usage Workflow

1. **Identify Work Item**: Get the Epic, Feature, or User Story ID from Azure DevOps
2. **Prepare Project Docs**: Have your project documentation/implementation notes ready
3. **Run Generator Script**: Use the planning generator script with:
   - Work Item ID
   - Project folder path
   - Your developer name
4. **Review & Customize**: The script generates base structure; customize with specific details
5. **Upload to Wiki**: Script automatically creates wiki pages in correct format

## Example

For project: Client-Side Formula Rendering
- **Epic ID**: 75123
- **Developer**: Tay Nguyen
- **Project Folder**: `C:\source\MD\payload_render_client_side_formulas`
- **Date**: 2026-05-29

**Generated Planning Page**: `/Planning/2026-05-29-75123-client-side-formula-rendering/`

With subpages:
- Overview (extracted from IMPLEMENTATION_STRATEGY.md)
- Work Items (fetched from Azure DevOps API)
- Roadmap (generated from phases)
- Progress (initialized with starting status)
