# User Story Task Creation Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis + wiki integration

## Purpose
Read Azure DevOps user stories and create detailed technical tasks with proper assignments and hour estimates. Enhanced with requirement diagram analysis and mockup screenshot interpretation to extract task details. This skill breaks down user stories into actionable development tasks, creates them in Azure DevOps, links them to the parent user story, and assigns them to Tay Nguyen with realistic time estimates.

## When to Use This Skill
- User asks to "create tasks for user story #XXXXX"
- User wants to "break down user story into tasks"
- User requests "task breakdown for development work"
- User says "analyze user story and create tasks assigned to Tay Nguyen"
- User provides user story number and asks for task planning

## Prerequisites
- Azure DevOps CLI configured (`az login` completed)
- User story ID from Azure DevOps (e.g., 84579)
- Access to Siepe.Software project in Azure DevOps
- Knowledge of MOS/Aristotle system architecture

---

## Investigation Methodology

### Phase 0: Analyze User Story Attachments and Wiki

**Step 0.1: Screenshot Analysis**
```powershell
$userStory = az boards work-item show --id $userStoryId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $userStory.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent analyzes:
# - Requirement diagrams showing system architecture
# - UI mockups showing desired functionality
# - Workflow diagrams showing process flows
# - Database schema diagrams
```

**Step 0.2: Fetch Wiki Task Templates**
```powershell
$wikiPath = "/Development-Task-Templates"  # Update with actual path
az devops wiki page show --wiki "Siepe Wiki" --path $wikiPath --include-content `
    --org https://siepe.visualstudio.com/ --project "Siepe.Software" `
    --output json 2>$null | ConvertFrom-Json | Select-Object -ExpandProperty content | `
    Out-File "C:\source\MD\AdminTools\Output\Wiki_TaskTemplates.md" -Encoding UTF8
```

### Phase 1: Retrieve User Story Details

**Objective:** Fetch the user story from Azure DevOps and understand requirements.

**Query:**
```powershell
az boards work-item show --id {UserStoryID} --org https://siepe.visualstudio.com --output json
```

**Extract:**
- `fields.'System.Title'` - User story title
- `fields.'System.Description'` - Detailed requirements (HTML format)
- `fields.'Microsoft.VSTS.Common.AcceptanceCriteria'` - Success criteria
- `fields.'System.State'` - Current state (New, Active, etc.)
- `fields.'System.AssignedTo'` - Current assignee (if any)
- `fields.'System.Tags'` - Tags for context (MOS, Aristotle, Dashboard, etc.)

**Key Information:**
- What feature/functionality is being requested?
- What are the acceptance criteria?
- Which system(s) are involved? (MOS, Aristotle, both)
- Is this a new feature, bug fix, or enhancement?
- Are there database changes required?
- Are there UI/dashboard components?

---

### Phase 2: Analyze Requirements and Plan Tasks

**Objective:** Break down the user story into logical, actionable tasks.

**Common Task Patterns:**

#### Database Development Tasks
When user story involves stored procedures, tables, or views:
1. **Create Database Objects** (Stored Procedures/Views/Tables)
   - Estimate: 4-8 hours depending on complexity
   - Tables involved
   - Business logic description
   - Query patterns

2. **Create Unit Tests**
   - Estimate: 2-4 hours
   - Test scenarios
   - Expected results validation

3. **Test on Dev/Prod Environments**
   - Estimate: 2-4 hours
   - MOS environments (Dev/Prod)
   - Aristotle environments (Dev/Prod)
   - Performance validation
   - **Dashboard procedures: Test @GetColumnList parameter (both 0 and 1)**
   - Verify column metadata mode returns headers with no data rows

#### Dashboard/UI Tasks
When user story involves dashboard widgets or UI:
1. **Create Dashboard Widget**
   - Estimate: 4-8 hours
   - Widget type (chart, grid, KPI, etc.)
   - Data source (which procedure)
   - Filter parameters
   - Drill-down functionality

2. **Create Widget Configuration**
   - Estimate: 2-3 hours
   - Dashboard.tWidget entries
   - Dashboard.tWidgetParameter settings
   - User permissions

#### Deployment Tasks
For production deployment:
1. **Create TML Deployment File**
   - Estimate: 1-3 hours
   - TML script for database objects
   - Deployment targets (MOS, Aristotle)
   - Rollback plan

2. **Create Release Documentation**
   - Estimate: 1-2 hours
   - Release notes
   - Testing verification steps
   - Deployment instructions

**Estimation Guidelines:**
- Simple procedure (1-2 tables, basic logic): 4-6 hours
- Medium procedure (3-5 tables, joins, aggregations): 6-10 hours
- Complex procedure (6+ tables, CTEs, multiple calculations): 10-16 hours
- Dashboard widget: 4-8 hours
- Testing per environment: 2-4 hours
- TML deployment: 1-3 hours
- Documentation: 1-2 hours

**Total Estimate Range:** Most user stories = 12-30 hours total across all tasks

---

### Phase 3: Create Tasks in Azure DevOps

**Objective:** Create tasks in Azure DevOps linked to parent user story, assigned to Tay Nguyen.

**Critical Fields:**
- `--type "Task"` - Work item type
- `--title` - Task title (descriptive, specific)
- `--description` - Detailed HTML-formatted description with tables, logic, requirements
- `--assigned-to "tcnguyen@siepe.com"` - Tay Nguyen's email
- `--fields "System.Parent={UserStoryID}"` - Link to parent user story
- `--fields "Custom.Estimate={hours}"` - Estimated hours (REQUIRED field)
- `--org https://siepe.visualstudio.com` - Organization
- `--project "Siepe.Software"` - Project name

**Task Creation Pattern:**
```powershell
$task = az boards work-item create `
  --type "Task" `
  --title "Create stored procedure [Schema].pProcedureName" `
  --description "Detailed description with HTML formatting<br><br><b>Tables:</b><ul><li>Table1</li></ul>" `
  --assigned-to "tcnguyen@siepe.com" `
  --fields "System.Parent={UserStoryID}" "Custom.Estimate={hours}" `
  --org https://siepe.visualstudio.com `
  --project "Siepe.Software" `
  --output json | ConvertFrom-Json
```

**IMPORTANT:** 
- `Custom.Estimate` is a REQUIRED field for tasks in Siepe.Software project
- **Schema Selection:** Use `Dashboard` for dashboard widgets, `Report` for standalone reports
- HTML formatting allowed in description: `<b>`, `<ul>`, `<li>`, `<ol>`, `<br>`
- Task ID is returned in `$task.id`

---

### Phase 4: Link Tasks to User Story

**Objective:** Ensure all tasks are properly linked as child work items of the user story.

**Linking Method:**
```powershell
az boards work-item relation add `
  --id {TaskID} `
  --relation-type "parent" `
  --target-id {UserStoryID} `
  --org https://siepe.visualstudio.com
```

**Verification:**
```powershell
$task = az boards work-item show --id {TaskID} --org https://siepe.visualstudio.com --output json | ConvertFrom-Json
$parentId = $task.fields.'System.Parent'
# Should equal UserStoryID
```

**Note:** If `System.Parent` field is set during task creation (`--fields "System.Parent={ID}"`), the link is automatic. If not set, use `relation add` command.

---

### Phase 5: Verification and Summary

**Objective:** Verify all tasks created, linked, and assigned correctly.

**Verification Checklist:**
1. ✅ All tasks created successfully (no errors)
2. ✅ All tasks linked to parent user story (`System.Parent` field set)
3. ✅ All tasks assigned to Tay Nguyen (`System.AssignedTo` = tcnguyen@siepe.com)
4. ✅ All tasks have hour estimates (`Custom.Estimate` field populated)
5. ✅ Task titles are descriptive and specific
6. ✅ Task descriptions include detailed requirements

**Summary Output:**
```
=== Tasks Created for USER STORY #{ID} ===

User Story: "{Title}"

Tasks Created:
  #{TaskID1} - {Title1} ({Hours} hours)
  #{TaskID2} - {Title2} ({Hours} hours)
  #{TaskID3} - {Title3} ({Hours} hours)

Total Estimate: {TotalHours} hours
Assigned To: Tay Nguyen (tcnguyen@siepe.com)
Parent User Story: #{UserStoryID}

View in Azure DevOps: https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/{UserStoryID}
```

---

## Stored Procedure Creation Workflow - Mossy's Workflow

**When creating stored procedures for tasks, Mossy MUST follow this workflow:**

### Step 1: Read Siepe Database Standards
```
Read `.github/skills/siepe-database-standards/SKILL.md` to understand all requirements
```

### Step 2: Create Stored Procedure File
- Use correct schema (Dashboard for widgets, Report for reports)
- Include all MANDATORY elements:
  - `DROP PROCEDURE IF EXISTS` (idempotency)
  - `SET ANSI_NULLS ON` / `SET QUOTED_IDENTIFIER ON`
  - Documentation header AFTER AS, BEFORE BEGIN
  - `SET NOCOUNT ON` as first statement
  - For Dashboard procedures: Include `@GetColumnList BIT = 0` parameter
  - For Dashboard procedures: Add `IF @GetColumnList = 1 SET @RefDataSetDate = '9999-01-01'` logic
  - `GRANT EXECUTE ON [Schema].[pProc] TO [StandardUser]`
  - Query views, not tables
  - All SQL keywords UPPERCASE

### Step 3: Save to Output Folder
```powershell
Save file to: C:\source\MD\AdminTools\Output\[Schema].[pProcedureName].sql
```

### Step 4: **MANDATORY - Test in Development**

**CRITICAL: Always test stored procedures in Development before posting to ADO task**

```powershell
# Connect to MOS Development
$devServer = "mos-sql-d.mos.siepe.local,52155"
$database = "Core"  # Or Dashboard, Report, etc.

# Test 1: Normal execution
Invoke-Sqlcmd -ServerInstance $devServer -Database $database -Query @"
EXEC Dashboard.pProcedureName 
    @AsOfDate = '2026-07-23',
    @CompanyID = NULL,
    @GetColumnList = 0
"@

# Test 2: GetColumnList mode (Dashboard procedures only)
Invoke-Sqlcmd -ServerInstance $devServer -Database $database -Query @"
EXEC Dashboard.pProcedureName 
    @GetColumnList = 1
"@
```

**Testing Verification:**
- ✅ Procedure executes without errors
- ✅ Returns expected columns
- ✅ Returns data rows when @GetColumnList = 0
- ✅ Returns 0 data rows (column headers only) when @GetColumnList = 1
- ✅ Performance is acceptable (< 30 seconds for dashboard widgets)
- ✅ SQL follows all Siepe standards

### Step 5: Post SQL to ADO Task

Only after successful testing in Development:
```powershell
az boards work-item update --id {TaskID} --discussion "Stored procedure created and tested in Development. SQL file attached." --org https://siepe.visualstudio.com/
```

### Step 6: Attach SQL File to Task

```powershell
# Upload and attach SQL file to work item
# (Use ADO REST API or manual attachment via web UI)
```

**Example Complete Workflow:**

```powershell
# 1. Create procedure file
$sql = @"
DROP PROCEDURE IF EXISTS Dashboard.pPricingInconsistencies
GO

CREATE PROCEDURE Dashboard.pPricingInconsistencies
    @AsOfDate        DATE = NULL,
    @CompanyID       INT  = NULL,
    @GetColumnList   BIT  = 0
AS
/*
Description:
    Identifies pricing inconsistencies across portfolios

Parameters:
    @GetColumnList - When 1, returns column metadata only
*/
BEGIN
    SET NOCOUNT ON;
    
    IF @GetColumnList = 1
        SET @AsOfDate = '9999-01-01'
    
    -- Procedure logic here
END
GO

GRANT EXECUTE ON Dashboard.pPricingInconsistencies TO [StandardUser]
GO
"@

# Save to Output folder
$sql | Out-File -FilePath "C:\source\MD\AdminTools\Output\Dashboard.pPricingInconsistencies.sql" -Encoding UTF8

# 2. Test in Development
Invoke-Sqlcmd -ServerInstance "mos-sql-d.mos.siepe.local,52155" -Database "Dashboard" -Query $sql

# 3. Test execution (both modes)
Invoke-Sqlcmd -ServerInstance "mos-sql-d.mos.siepe.local,52155" -Database "Dashboard" -Query "EXEC Dashboard.pPricingInconsistencies @AsOfDate = '2026-07-23', @GetColumnList = 0"
Invoke-Sqlcmd -ServerInstance "mos-sql-d.mos.siepe.local,52155" -Database "Dashboard" -Query "EXEC Dashboard.pPricingInconsistencies @GetColumnList = 1"

# 4. If tests pass, post to ADO
az boards work-item update --id 85341 --discussion "✅ Stored procedure created and tested successfully in MOS Development. SQL file attached." --org https://siepe.visualstudio.com/
```

---

## Example Investigation

### User Request:
"Create tasks for USER STORY 84579 and assign to Tay Nguyen with estimated hours"

### Investigation Steps:

#### Step 1: Retrieve User Story
```powershell
az boards work-item show --id 84579 --org https://siepe.visualstudio.com
```

**Extracted:**
- Title: "Develop a pricing inconsistencies between portfolios dashboard widget"
- Description: "Price Inconsistencies across portfolios at Aristotle would be more than one fund holds an asset and that asset has a different price across the funds for the same day."
- Acceptance Criteria: "Pricing inconsistencies dashboard deployed at MOS and Aristotle"
- Tags: Dashboard, Reporting

#### Step 2: Task Breakdown

**Analysis:**
- Database work: Need stored procedure to identify price inconsistencies
- Dashboard work: Widget to display results
- Deployment: TML file for production release
- Testing: Validate on MOS and Aristotle environments

**Planned Tasks:**
1. Create stored procedure `Dashboard.pPricingInconsistenciesAcrossPortfolios` (8 hours)
2. Test procedure on MOS and Aristotle Dev/Prod (4 hours)
3. Create Dashboard Widget for Pricing Inconsistencies (6 hours)
4. Create TML deployment file (2 hours)

**Total Estimate:** 20 hours

**IMPORTANT - Schema Selection:**
- Dashboard widgets: Use **Dashboard** schema (e.g., Dashboard.pProcedureName)
- Standalone reports: Use **Report** schema (e.g., Report.pProcedureName)
- This user story is for a dashboard widget, so use Dashboard schema!

**MANDATORY - Dashboard Schema Requirements:**
- All Dashboard procedures MUST include `@GetColumnList BIT = 0` parameter
- Add logic: `IF @GetColumnList = 1 SET @RefDataSetDate = '9999-01-01'`
- This allows Operations Dashboard to retrieve column metadata without data

#### Step 3: Create Tasks

**Task 1: Stored Procedure**
```powershell
$task1 = az boards work-item create `
  --type "Task" `
  --title "Create stored procedure Dashboard.pPricingInconsistenciesAcrossPortfolios" `
  --description "Create stored procedure to identify pricing inconsistencies where the same instrument has different prices across multiple portfolios on the same day.<br><br><b>Schema:</b> Dashboard (for dashboard widgets)<br><br><b>Required Parameters:</b><ul><li>@AsOfDate DATE</li><li>@CompanyID INT (optional)</li><li>@GetColumnList BIT = 0 (REQUIRED for all Dashboard procedures)</li></ul><br><br><b>Tables Involved:</b><ul><li>Core.dbo.vPosition - Position marks by portfolio and date</li><li>Reference.dbo.vInst* - Instrument identifiers</li><li>Core.dbo.vPortfolio - Portfolio information</li></ul><br><b>Logic:</b><ol><li>Group positions by InstID and RefDataSetDate</li><li>Find instruments held in multiple portfolios on same date</li><li>Compare PositionMark values across portfolios</li><li>Flag where marks differ beyond threshold</li><li>Handle @GetColumnList = 1 mode (return column metadata only)</li></ol>" `
  --assigned-to "tcnguyen@siepe.com" `
  --fields "System.Parent=84579" "Custom.Estimate=8" `
  --org https://siepe.visualstudio.com `
  --project "Siepe.Software" `
  --output json | ConvertFrom-Json

Write-Host "✅ Task Created: #$($task1.id) - Estimate: 8 hours"
```

**Task 2: Testing**
```powershell
$task2 = az boards work-item create `
  --type "Task" `
  --title "Test pPricingInconsistenciesAcrossPortfolios on MOS and Aristotle" `
  --description "Test the pricing inconsistencies stored procedure on both MOS and Aristotle environments.<br><br><b>Environments:</b><ul><li>MOS Dev: mos-sql-d.mos.siepe.local,52155</li><li>MOS Prod: mos-sql-p.mos.siepe.local,52155</li><li>Aristotle Dev: aristotle-sql-d.aristotle.aws,52155</li><li>Aristotle Prod: aristotle-sql-p.aristotle.aws,52155</li></ul><br><b>Testing Checklist:</b><ol><li>Execute procedure with sample date and verify no errors</li><li>Validate results against known pricing inconsistencies</li><li>Test @GetColumnList = 0 (normal data mode)</li><li>Test @GetColumnList = 1 (column metadata mode - should return 0 rows)</li><li>Check performance (must be < 30 seconds for dashboard)</li><li>Verify column names and data types match dashboard requirements</li><li>Document sample output and performance metrics</li></ol>" `
  --assigned-to "tcnguyen@siepe.com" `
  --fields "System.Parent=84579" "Custom.Estimate=4" `
  --org https://siepe.visualstudio.com `
  --project "Siepe.Software" `
  --output json | ConvertFrom-Json

Write-Host "✅ Task Created: #$($task2.id) - Estimate: 4 hours"
```

**Task 3: Dashboard Widget**
```powershell
$task3 = az boards work-item create `
  --type "Task" `
  --title "Create Dashboard Widget for Pricing Inconsistencies" `
  --description "Create dashboard widget to display pricing inconsistencies across portfolios.<br><br><b>Requirements:</b><ul><li>Widget displays real-time pricing inconsistencies</li><li>Filter by portfolio, date range, instrument type</li><li>Show count of inconsistencies and affected instruments</li><li>Drill-down to detailed view</li></ul><br><b>Tables/Procedures:</b><ul><li>Dashboard.pPricingInconsistenciesAcrossPortfolios (data source)</li><li>Dashboard.tWidget (widget configuration)</li><li>Dashboard.tWidgetParameter (widget filters)</li></ul>" `
  --assigned-to "tcnguyen@siepe.com" `
  --fields "System.Parent=84579" "Custom.Estimate=6" `
  --org https://siepe.visualstudio.com `
  --project "Siepe.Software" `
  --output json | ConvertFrom-Json

Write-Host "✅ Task Created: #$($task3.id) - Estimate: 6 hours"
```

**Task 4: TML Deployment**
```powershell
$task4 = az boards work-item create `
  --type "Task" `
  --title "Create TML file for pPricingInconsistenciesAcrossPortfolios deployment" `
  --description "Create TML deployment configuration file to deploy the pricing inconsistencies procedure and dashboard widget to MOS and Aristotle environments.<br><br><b>TML File:</b> YYYY-MM-DD-PricingInconsistenciesWidget.tml<br><br><b>Deployment Targets:</b><ul><li>MOS Production</li><li>Aristotle Production</li></ul><br><b>Components:</b><ol><li>Dashboard.pPricingInconsistenciesAcrossPortfolios.sql</li><li>Dashboard widget configuration</li><li>Widget parameters</li></ol><br><b>Reference:</b> See .github/skills/tml-creation/SKILL.md for TML format and examples." `
  --assigned-to "tcnguyen@siepe.com" `
  --fields "System.Parent=84579" "Custom.Estimate=2" `
  --org https://siepe.visualstudio.com `
  --project "Siepe.Software" `
  --output json | ConvertFrom-Json

Write-Host "✅ Task Created: #$($task4.id) - Estimate: 2 hours"
```

#### Step 4: Verify Linking

```powershell
$tasks = @($task1.id, $task2.id, $task3.id, $task4.id)
foreach ($taskId in $tasks) {
    # If linking failed during creation, add relation
    az boards work-item relation add `
      --id $taskId `
      --relation-type "parent" `
      --target-id 84579 `
      --org https://siepe.visualstudio.com
}
```

#### Step 5: Summary Report

```
=== Tasks Created for USER STORY #84579 ===

User Story: "Develop a pricing inconsistencies between portfolios dashboard widget"

Tasks Created:
  #85341 - Create stored procedure (8 hours)
  #85342 - Test procedure on MOS/Aristotle (4 hours)
  #85343 - Create dashboard widget (6 hours)
  #85344 - Create TML deployment file (2 hours)

Total Estimate: 20 hours
Assigned To: Tay Nguyen (tcnguyen@siepe.com)
Parent User Story: #84579

View in Azure DevOps: https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/84579
```

---

## Technical Details

### Database Connection Strings
See `MOSSystemConnectionsReference.md` for:
- MOS Production SQL: `mos-sql-p.mos.siepe.local,52155`
- MOS Dev SQL: `mos-sql-d.mos.siepe.local,52155`
- Aristotle Production SQL: `aristotle-sql-p.aristotle.aws,52155`
- Aristotle Dev SQL: `aristotle-sql-d.aristotle.aws,52155`

### Common Tables for Task Descriptions
- **Position Data:** Core.dbo.vPosition, Core.dbo.tPosition
- **Instrument Data:** Reference.dbo.vInst*, Reference.dbo.tInst*
- **Portfolio Data:** Core.dbo.vPortfolio, Core.dbo.tPortfolio
- **Pricing Data:** Feeds.dbo.vMarketPrice, Feeds.dbo.tPriceSource
- **Dashboard:** Dashboard.tWidget, Dashboard.tWidgetParameter
- **Reports:** Report.* (stored procedures)

### Azure DevOps CLI Authentication

If authentication errors occur:
```powershell
az login
az account set --subscription "Siepe Production"
```

### Error Handling

**Common Errors:**

1. **"Rule Error for field Estimate. Error code: Required, InvalidEmpty"**
   - **Cause:** Custom.Estimate field not provided or empty
   - **Fix:** Always include `"Custom.Estimate={hours}"` in --fields parameter

2. **"Cannot find field Siepe.Estimate"**
   - **Cause:** Wrong field name used
   - **Fix:** Use `Custom.Estimate`, not `Siepe.Estimate` or `Microsoft.VSTS.Scheduling.OriginalEstimate`

3. **"Relation type 'parent' not found"**
   - **Cause:** Wrong relation type name
   - **Fix:** Use `"parent"` (lowercase) or include in `System.Parent` field during creation

4. **Task created but parent link missing**
   - **Cause:** System.Parent field not set during creation
   - **Fix:** Add parent link post-creation using `az boards work-item relation add`

---

## Best Practices

### Task Naming Conventions
- ✅ GOOD: "Create stored procedure Dashboard.pPricingInconsistenciesAcrossPortfolios" (for dashboard widgets)
- ✅ GOOD: "Create stored procedure Report.pEnhancedPricingReport" (for standalone reports)
- ✅ GOOD: "Test pPricingInconsistenciesAcrossPortfolios on MOS and Aristotle"
- ✅ GOOD: "Create TML file for pProcedureName deployment"
- ❌ BAD: "Create procedure" (too vague)
- ❌ BAD: "Testing" (not specific)
- ❌ BAD: "Fix the pricing issue" (not a development task)

### Task Description Quality
- Include specific tables/views involved
- Describe business logic clearly
- List validation steps
- Reference related documentation (SKILL files, wiki pages)
- Use HTML formatting for readability (`<b>`, `<ul>`, `<ol>`)

### Estimation Accuracy
- Consider complexity of SQL logic (CTEs, window functions, recursive queries)
- Factor in number of tables/joins
- Include testing time across environments
- Account for deployment preparation
- Add buffer for unexpected issues (+20% for complex work)

### Assignment Guidelines
- **Always assign to:** tcnguyen@siepe.com (Tay Nguyen)
- **Exception:** If user specifies different assignee, use that email
- Ensure assignee has access to Siepe.Software project

---

## Deliverables

### Required Output
1. **Summary Table:** Tasks created with IDs, titles, estimates
2. **Total Estimate:** Sum of all task hours
3. **Assignee Confirmation:** Verify tcnguyen@siepe.com assigned
4. **Parent Link Verification:** Confirm all tasks linked to user story
5. **Azure DevOps Link:** Provide URL to user story work item

### Optional Enhancements
- Group tasks by category (Database, Testing, Deployment, etc.)
- Show dependency order if tasks must be sequential
- Highlight critical path tasks
- Flag high-risk or complex tasks

---

## Skill Metadata

- **Skill Name:** user-story-task-creation
- **Category:** DevOps Work Item Management
- **Complexity:** Medium
- **Execution Time:** 3-5 minutes (depends on number of tasks)
- **Prerequisites:** Azure DevOps CLI authentication, user story ID
- **Outputs:** Task IDs, summary report, verification confirmation

---

## Related Skills

- **mos-bug-tasks:** Creating bugs in current sprint BAU Support
- **mos-bug-status:** Querying and summarizing bug status
- **tml-creation:** Creating TML deployment files (often a task output)
- **siepe-database-standards:** Coding standards for procedure creation
- **wiki-access:** Retrieving TML documentation for deployment tasks
