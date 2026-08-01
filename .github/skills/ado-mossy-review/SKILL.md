---
description: Monitor Azure DevOps work items tagged "Mossy Review" and "Mossy Review Again", investigate bugs/tasks, attach assessments, manage review queue with duplicate prevention, and mark items complete after review.
keywords: ado, azure devops, mossy review, work item, investigation, queue, tag, assessment, bug, task, monitoring, triage, reinvestigation
category: DevOps & Monitoring
status: production
version: 2.2.0
created: 2026-07-31
updated: 2026-07-31
---

# ADO Mossy Review - Automated Work Item Investigation

## Overview

This skill enables Mossy to:
1. **Monitor** Azure DevOps work items tagged with "Mossy Review" or "Mossy Review Again"
2. **Queue Management** - Add new items to review queue without duplicates
3. **Investigate** - Analyze bugs/tasks and generate detailed assessments
4. **Attach Assessment** - Post investigation results as comments on the work item
5. **Tag Completion** - Mark work items as reviewed and remove tags
6. **Reinvestigation** - Support "Mossy Review Again" tag for follow-up reviews with additional context

## When to Use This Skill

Invoke this skill when the user:
- Mentions "check ADO Mossy Review items"
- Wants to "investigate work items tagged Mossy Review"
- Asks about "pending Mossy Review queue"
- Says "review ADO bugs/tasks"
- Requests "check what needs Mossy's attention"
- Mentions "investigate Task #12345" or "Bug #67890"
- Asks about "Mossy Review Again" items

**Keywords that trigger this skill:**
- mossy review
- ado mossy review
- work item review
- investigate work item
- mossy queue
- review queue
- pending reviews
- reinvestigate

## Investigation Workflow

### Phase 1: Queue Detection & Management

1. **Monitor for Tagged Work Items**
   ```powershell
   cd C:\source\MD\AdminTools\.github\skills\ado-mossy-review
   .\Check-MossyReview-WorkItems.ps1
   ```

2. **Load Queue File**
   - Location: `C:\source\MD\AdminTools\Output\mossy-review-queue.json`
   - Structure:
     ```json
     {
       "85717": {
         "work_item_id": 85717,
         "title": "Price discrepancy investigation",
         "type": "Task",
         "status": "pending",
         "date_added": "2026-07-31 14:00:00",
         "sprint": "07.26b",
         "review_count": 1,
         "last_reviewed": null,
         "user_context": "",
         "assessments": []
       }
     }
     ```

3. **Check Concurrency Limit**
   - Count items with `status = "in_progress"` in queue
   - If count < 2, proceed to add new items
   - If count >= 2, log `[QUEUE_FULL]` and skip (will retry in 2 minutes)

4. **Check for Duplicates**
   - If work item ID exists in queue AND status != "pending", skip
   - If "Mossy Review Again" tag found, reset to "pending" and increment review_count
   - If new item with "Mossy Review" tag AND concurrency < 2, add to queue

5. **Log Queue Actions**
   - `[QUEUE_ADD] Task #85717 - Added to queue (In Progress: 0/2)`
   - `[QUEUE_SKIP] Bug #85904 - Already in queue (status: in_progress)`
   - `[QUEUE_FULL] Task #86001 - Queue is full (In Progress: 2/2). Will retry.`
   - `[REINVESTIGATION] Task #85717 - Review requested again (review #2)`

### Phase 2: Investigation

5. **Fetch Work Item Details**
   ```bash
   az boards work-item show --id 85717 --org https://siepe.visualstudio.com/ --output json
   ```

   **Extract:**
   - Title
   - Description
   - Work Item Type (Bug/Task)
   - State (New/Active/Closed)
   - Assigned To
   - Tags
   - Comments (especially if "Mossy Review Again" - check for additional context)
   - Parent User Story (if exists)

6. **Analyze Work Item**
   
   **For Bugs:**
   - Read error messages/stack traces
   - Identify affected system (MOS, Solvas, Security Master, SSIS)
   - Check for similar past issues
   - Determine root cause category (data, configuration, code, infrastructure)
   - Recommend fix approach
   
   **For Tasks:**
   - Understand request/requirement
   - Identify related systems
   - Estimate complexity (Simple/Medium/Complex)
   - Suggest implementation approach
   - List dependencies

7. **Check for Additional Context (Reinvestigation)**
   - If `review_count > 1`, read recent comments
   - Look for phrases like "Additional info:", "Update:", "New finding:"
   - Extract user-provided context to refine investigation

8. **Determine If Issue Can Be Resolved**
   
   **Use INCONCLUSIVE template if:**
   - Work item description is too vague or missing critical details
   - Issue requires specialized domain knowledge (e.g., complex accounting rules, regulatory requirements)
   - Root cause cannot be determined from available data sources
   - Multiple conflicting symptoms with no clear pattern
   - Issue involves systems/databases Mossy cannot access
   - Human judgment needed (e.g., "should we implement this feature?", business decisions)
   - Insufficient logs or error messages to diagnose root cause
   
   **Use STANDARD template if:**
   - Clear error message or symptom identified
   - Root cause can be determined from database queries
   - Standard troubleshooting procedures apply
   - Similar issues resolved in past (with documented solutions)
   - Recommendation path is clear even if implementation is complex
   
   **Key Principle:** Better to admit uncertainty and escalate than provide incorrect analysis. Users prefer honest acknowledgment of limitations over incorrect conclusions.

### Phase 3: Generate Assessment

9. **Create Assessment Comment**
   
   **Template Structure:**
   ```markdown
   ## 🔍 Mossy Investigation Assessment
   
   **Work Item:** #{work_item_id} - {title}  
   **Type:** {Bug|Task}  
   **Review:** #{review_count} | **Date:** {timestamp}
   
   ---
   
   ### 📋 Summary
   {1-2 sentence summary of the issue/request}
   
   ### 🔎 Investigation Findings
   {Detailed analysis based on work item type}
   
   **Root Cause:** {For bugs}
   **Affected Systems:** {List of systems}
   **Data Sources Checked:** {Databases/APIs queried}
   
   ### 💡 Recommendations
   1. {Primary recommendation}
   2. {Secondary recommendation}
   3. {Additional steps if needed}
   
   ### 🔗 Related Resources
   - Wiki: {relevant wiki links}
   - Similar Tickets: {past ADO items}
   - Database Queries: {saved query files}
   
   ### ⚠️ Considerations
   - {Risk factors}
   - {Dependencies}
   - {Timeline estimates}
   
   ---
   
   **Status:** Investigation Complete ✅  
   **Next Action:** {Assign to developer | Schedule fix | Needs more info}
   
   {If review_count > 1: _This is a follow-up investigation (#review_count). Previous assessments available in comment history._}
   ```

   **Template for Inconclusive Investigation (When Mossy Cannot Resolve):**
   ```markdown
   ## 🔍 Mossy Investigation Assessment
   
   **Work Item:** #{work_item_id} - {title}  
   **Type:** {Bug|Task}  
   **Review:** #{review_count} | **Date:** {timestamp}
   
   ---
   
   ### 📋 Summary
   {1-2 sentence summary of what was investigated}
   
   ### 🔎 Investigation Performed
   {List what Mossy checked - databases queried, logs reviewed, systems analyzed}
   
   **Data Sources Checked:**
   - {Database/table queries attempted}
   - {Log files reviewed}
   - {Systems examined}
   
   ### ⚠️ Investigation Status: Unable to Resolve
   
   **Reason:**
   - [ ] Insufficient information in work item description
   - [ ] Issue requires domain expertise beyond current capabilities
   - [ ] Missing access to necessary systems/databases
   - [ ] Complex issue requiring human judgment
   - [ ] Ambiguous requirements need clarification
   - [ ] External system dependencies cannot be verified
   
   **What I Found:**
   {Describe any partial findings, clues, or related information discovered}
   
   **What I Could Not Determine:**
   {Specific gaps in understanding or missing information needed}
   
   ### 💡 Recommendations for Next Steps
   
   1. **Immediate Action:** {Suggest who should look at this - specific team or person}
   2. **Additional Information Needed:** {List specific details that would help resolution}
   3. **Alternative Approach:** {Suggest manual investigation steps or escalation path}
   
   ### 🔗 Potentially Related Resources
   - {Any relevant wiki pages, even if not directly applicable}
   - {Similar past tickets that might provide context}
   - {Documentation that might be helpful}
   
   ### 📝 Suggested Owner
   **Recommended Assignment:**
   - **For pricing issues:** Back Office SQL Engineers / @{lead developer}
   - **For ETL/SSIS issues:** Data Engineering Team / @{SSIS specialist}
   - **For cash reconciliation:** Accounting Operations Team
   - **For performance issues:** Database Administrator / @{DBA}
   - **For data quality:** Data Governance Team
   
   ---
   
   **Status:** Investigation Inconclusive ⚠️  
   **Next Action:** Manual review required - recommend escalation to {specific team/person}
   
   **Note:** This issue requires specialized knowledge or additional context that is currently beyond my automated analysis capabilities. A human expert should review and provide guidance.
   
   {If review_count > 1: _This is a follow-up investigation (#review_count). Previous assessments available in comment history. Additional user context may have been provided since last review._}
   ```

10. **Save Assessment to Queue**
    ```json
   "assessments": [
     {
       "date": "2026-07-31 15:30:00",
       "comment_id": 12345,
       "status": "completed",
       "summary": "Price mismatch between MOS and Solvas"
     }
   ]
   ```

### Phase 4: Post Assessment

11. **Attach Comment to Work Item**
    ```bash
    az boards work-item update \
      --id 85717 \
      --org https://siepe.visualstudio.com/ \
      --discussion "$(cat assessment.md)"
    ```

12. **Update Queue Status**
    - Set `status: "reviewed"`
    - Set `last_reviewed: "2026-07-31 15:30:00"`
    - Append assessment to `assessments` array

### Phase 5: Tag Completion

13. **Remove Tags from Work Item**
    ```bash
    # Remove "Mossy Review" tag
    az boards work-item update \
      --id 85717 \
      --org https://siepe.visualstudio.com/ \
      --fields "System.Tags=;Mossy Review"
    
    # Also remove "Mossy Review Again" if present
    az boards work-item update \
      --id 85717 \
      --org https://siepe.visualstudio.com/ \
      --fields "System.Tags=;Mossy Review Again"
    ```

14. **Log Completion**
    ```
    [REVIEW_COMPLETE] Task #85717 - Assessment posted, tags removed
    ```

## Reinvestigation Workflow

### When User Adds "Mossy Review Again" Tag

1. **Detection**
   - Monitoring script detects both "Mossy Review" and "Mossy Review Again" tags
   - Checks queue for existing entry

2. **Queue Update**
   ```powershell
   $queueEntry = $queue[$workItemId]
   $queueEntry.status = "pending"
   $queueEntry.review_count++
   $queueEntry.user_context = "User requested reinvestigation"
   ```

3. **Context Extraction**
   - Read comments added since last review
   - Look for user-provided additional information
   - Store in `user_context` field

4. **Reinvestigation**
   - Run full investigation again
   - Include reference to previous assessment(s)
   - Highlight what changed or new information discovered

5. **Assessment Prefix**
   ```markdown
   ## 🔄 Mossy Re-Investigation Assessment (#2)
   
   **Previous Review:** 2026-07-29 10:15:00 (see comment history)  
   **New Information:** User reported additional symptoms...
   ```

## Queue Management Commands

### Via PowerShell

```powershell
# List all pending reviews
.\Manage-MossyReview-Queue.ps1 -Action List -Status pending

# Mark as reviewed
.\Manage-MossyReview-Queue.ps1 -Action MarkReviewed -WorkItemId 85717

# Remove from queue
.\Manage-MossyReview-Queue.ps1 -Action Remove -WorkItemId 85717

# View queue statistics
.\Manage-MossyReview-Queue.ps1 -Action Stats
```

### Via Mossy (Natural Language)

```
@Mossy show pending review queue
@Mossy what's in the Mossy Review queue?
@Mossy how many items need review?
@Mossy clear completed reviews from queue
```

## Investigation Examples

### Bug Investigation Example

**Work Item:** Bug #85904 - SSIS package failure  
**Tags:** Mossy Review

**Investigation Steps:**
1. Read error message from bug description
2. Check SSIS execution logs via Seq or database
3. Identify failed component (data flow, lookup, script task)
4. Query affected database tables
5. Determine root cause (schema change, data quality, timeout)
6. Recommend fix

**Assessment Output:**
```markdown
## 🔍 Mossy Investigation Assessment

**Work Item:** #85904 - SSIS Package Failure in Solvas Extract  
**Type:** Bug  
**Review:** #1 | **Date:** 2026-07-31 15:45:00

---

### 📋 Summary
SSIS package "Solvas_Transaction_Extract" failed with truncation error on 7/30/2026 at 03:15 AM.

### 🔎 Investigation Findings

**Root Cause:** Data truncation error in `dbo.tTransactionStaging` table. Source data contains 500-character descriptions but target column is VARCHAR(255).

**Affected Systems:** 
- Solvas_AM database (source)
- MOS Enterprise database (destination)
- SSIS package ID: 1234

**Data Sources Checked:**
- Enterprise.ScriptAdapter.tScriptConfigurationHistory
- Seq logs (timestamp 2026-07-30 03:15:00)
- Solvas_AM.dbo.tTransaction (source table)

**SQL Query Used:**
```sql
SELECT MAX(LEN(Description)) AS MaxLength 
FROM Solvas_AM.dbo.tTransaction 
WHERE CreateDate >= '2026-07-29'
-- Result: 487 characters
```

### 💡 Recommendations

1. **Immediate Fix:** Increase column size in staging table
   ```sql
   ALTER TABLE MOS.dbo.tTransactionStaging 
   ALTER COLUMN Description VARCHAR(500)
   ```

2. **Rerun Failed Package:** Execute SSIS package manually for 7/30/2026 data

3. **Long-term:** Add data validation in ETL to truncate/warn before load

### 🔗 Related Resources
- Wiki: [SSIS Troubleshooting Guide](https://siepe.visualstudio.com/...)
- Similar Tickets: Task #83664 (truncation error resolved)
- Schema: MOS.dbo.tTransactionStaging

### ⚠️ Considerations
- Schema change requires deployment to PROD (coordinate with DBA)
- Package rerun will take ~15 minutes
- Monitor for similar errors in other packages

---

**Status:** Investigation Complete ✅  
**Next Action:** Assign to Database Team for schema change
```

### Task Investigation Example

**Work Item:** Task #85717 - Implement new price validation report  
**Tags:** Mossy Review

**Investigation Steps:**
1. Read task description and acceptance criteria
2. Identify required data sources (MOS, Solvas, Security Master)
3. Check for existing similar reports
4. Estimate complexity
5. List dependencies
6. Suggest implementation approach

**Assessment Output:**
```markdown
## 🔍 Mossy Investigation Assessment

**Work Item:** #85717 - Price Validation Report for Sycamore  
**Type:** Task  
**Review:** #1 | **Date:** 2026-07-31 16:00:00

---

### 📋 Summary
Create automated report comparing MOS position marks vs Security Master vendor prices (ICE, LSEG, Markit) for Sycamore portfolios.

### 🔎 Investigation Findings

**Requirements Analysis:**
- Daily report comparing prices across 3 data sources
- Output: Excel workbook with discrepancies highlighted
- Delivery: Email to pricing team
- Scope: All Sycamore portfolios (CompanyID 500000004)

**Affected Systems:** 
- MOS Core database (position marks)
- MOS Reference database (vendor prices)
- Security Master (raw vendor data)

**Similar Existing Reports:**
- Bulk Price Validation Workbook (Task #83664 - can reuse Excel template)
- Daily Price Exception Report (RS 500002180 - similar query logic)

**Complexity:** Medium (3-5 days)

### 💡 Recommendations

1. **Reuse Existing Framework:**
   - Base on bulk-price-validation skill queries
   - Leverage existing Excel COM automation scripts

2. **Implementation Steps:**
   a. Create SQL stored procedure `Report.pPriceValidationDaily`
   b. Build PowerShell script using `Create-Analysis-Tabs.ps1` template
   c. Schedule as Script Adapter job (daily 8 AM)
   d. Configure email delivery via Report Subscription

3. **Query Strategy:**
   ```sql
   SELECT p.Portfolio, ii.Value AS Identifier, p.PositionMark,
          ice.Bid AS ICE_Price, lseg.Bid AS LSEG_Price, markit.Bid AS Markit_Price,
          ABS(p.PositionMark - ice.Bid) AS ICE_Diff
   FROM Core.dbo.vPosition p
   JOIN Reference.dbo.vInstPriceCurrent ice ON ...
   WHERE ABS(p.PositionMark - ice.Bid) > 0.01 -- Flag >1% variance
   ```

### 🔗 Related Resources
- Wiki: [Price Exception Procedures](https://siepe.visualstudio.com/.../2281)
- Skills: `bulk-price-validation`, `check-market-price`
- Queries: `C:\source\MD\AdminTools\.github\skills\check-market-price\Queries.sql`

### ⚠️ Considerations
- Requires read access to Security Master database
- Report generation takes ~5 minutes (can cause Excel file locks)
- Email delivery needs SMTP configuration in Report Subscription
- Timeline: 3 days (1 day dev, 1 day testing, 1 day UAT)

---

**Status:** Investigation Complete ✅  
**Next Action:** Assign to Back Office Dev Team, create child tasks for each implementation step
```

---

### Inconclusive Investigation Example

**Work Item:** Bug #86123 - Cash reconciliation fails intermittently  
**Tags:** Mossy Review

**Investigation Steps:**
1. Read bug description: "Cash rec sometimes fails but we don't know why"
2. Query SSIS execution logs - found 3 failures in 30 days
3. Error messages are generic: "Operation failed" (no stack trace)
4. Checked Solvas cash tables - data looks normal
5. Attempted to reproduce - cannot determine trigger conditions

**Problem:** Insufficient information, intermittent issue with no pattern, requires deep domain knowledge of cash reconciliation business rules.

**Assessment Output:**
```markdown
## 🔍 Mossy Investigation Assessment

**Work Item:** #86123 - Cash reconciliation fails intermittently  
**Type:** Bug  
**Review:** #1 | **Date:** 2026-07-31 16:30:00

---

### 📋 Summary
Investigating intermittent cash reconciliation failures with generic error messages and no clear reproduction steps.

### 🔎 Investigation Performed

**Data Sources Checked:**
- Enterprise.ScriptAdapter.tScriptConfigurationHistory (last 30 days)
- Solvas_AM.Accounting.tCashLedger (recent transactions)
- Enterprise Log Book (pub/sub messages for cash rec jobs)
- MOS Core.dbo.vCashSummary (reconciled vs unreconciled)

**Findings:**
- 3 failures detected in last 30 days (dates: 7/15, 7/22, 7/28)
- All failures occurred between 11:00 PM - 11:30 PM (night batch window)
- Error message: "Operation failed" (generic, no specific exception)
- SSIS package: Solvas_CashReconciliation_Daily.dtsx
- No data anomalies visible in cash tables on failure dates
- Successful runs (27 out of 30) show no pattern difference

### ⚠️ Investigation Status: Unable to Resolve

**Reason:**
- [x] Insufficient information in work item description
- [x] Issue requires domain expertise beyond current capabilities
- [ ] Missing access to necessary systems/databases
- [x] Complex issue requiring human judgment
- [ ] Ambiguous requirements need clarification
- [ ] External system dependencies cannot be verified

**What I Found:**
- Failures are time-correlated (late night batch window)
- Generic SSIS error suggests component-level issue (not SQL query)
- No obvious data pattern triggers the failure
- Issue is intermittent (90% success rate)

**What I Could Not Determine:**
- Which specific SSIS component is failing (Data Flow? Script Task? Lookup?)
- Business rule that determines when cash rec should fail validation
- Whether failures are actually errors or expected validation rejections
- What "Operation failed" refers to - need detailed SSIS logging enabled
- If timing dependency exists (concurrent jobs, lock timeouts)

### 💡 Recommendations for Next Steps

1. **Immediate Action:** Escalate to Data Engineering Team - requires SSIS package debugging with verbose logging enabled

2. **Additional Information Needed:**
   - Enable SSIS Diagnostic Events in package configuration
   - Business rule documentation: when SHOULD cash rec fail?
   - Determine if 7/15, 7/22, 7/28 had any data anomalies in source systems
   - Check if any manual cash entries were processed on failure dates
   - Review concurrent job execution (is anything else running at 11 PM?)

3. **Alternative Approach:** 
   - Add try-catch error handlers in SSIS package with detailed logging
   - Implement dead letter queue for failed cash transactions
   - Set up data snapshots before/after failure for comparison

### 🔗 Potentially Related Resources
- Wiki: [Cash Reconciliation Procedures](https://siepe.visualstudio.com/.../3401)
- Similar Ticket: Bug #82145 (also intermittent SSIS failure, resolved by adding timeout)
- SSIS Documentation: Solvas ETL Architecture (may have troubleshooting steps)

### 📝 Suggested Owner
**Recommended Assignment:**
- **Primary:** Data Engineering Team / @John (SSIS specialist)
- **Secondary:** Accounting Operations Team (to validate business rules)
- **Escalate if needed:** Database Administrator (check for timeout/locking issues)

---

**Status:** Investigation Inconclusive ⚠️  
**Next Action:** Manual review required - recommend escalation to Data Engineering Team for SSIS debugging

**Note:** This issue requires specialized SSIS debugging knowledge and business rule validation that is currently beyond my automated analysis capabilities. A human expert should review the package execution flow and enable detailed logging to capture the specific failure point.
```

**Key Points in This Example:**
- ✅ Honest acknowledgment that Mossy cannot resolve the issue
- ✅ Detailed list of what WAS checked (shows effort)
- ✅ Clear explanation of what's missing or unknown
- ✅ Specific, actionable next steps for human investigator
- ✅ Appropriate team/person recommendations
- ✅ Still adds value by narrowing down the problem space
- ✅ User understands this needs human expertise, not frustrated by lack of resolution

## Configuration

### Azure DevOps Settings

- **Organization:** https://siepe.visualstudio.com/
- **Project:** Siepe.Software
- **Authentication:** Azure CLI (`az login`)

### File Locations

- **Queue File:** `C:\source\MD\AdminTools\Output\mossy-review-queue.json`
- **State File:** `C:\source\MD\AdminTools\Output\mossy-review-state.json`
- **Log File:** `C:\source\MD\AdminTools\Output\mossy-review-monitor.log`
- **Scripts:** `C:\source\MD\AdminTools\.github\skills\ado-mossy-review\`

### Tags

- **Primary Tag:** `Mossy Review` - First-time review request
- **Reinvestigation Tag:** `Mossy Review Again` - Request follow-up review
- **Behavior:** Both tags removed after assessment posted

### Concurrency Control

**Maximum Concurrent Reviews:** 2 work items at a time

**Behavior:**
- Mossy can investigate maximum **2 work items simultaneously**
- When 2 items are already "in_progress", new items wait in queue
- Queue shows status: `[QUEUE_FULL] In Progress: 2/2. Will retry on next check.`
- Next check (2 minutes later) will add pending items if slots available

**Configuration Location:**
```powershell
# Edit in Check-MossyReview-WorkItems.ps1, line ~125
$maxConcurrentReviews = 2  # Change this value to adjust limit
```

**Why This Limit?**
- Prevents Mossy from being overwhelmed with too many investigations
- Ensures each work item gets proper attention and thorough analysis
- Maintains quality of assessments over quantity
- Allows user to monitor progress more effectively

**Example Output:**
```
[QUEUE_ADD] Work item #85717 added to queue (In Progress: 0/2)
[QUEUE_ADD] Work item #85904 added to queue (In Progress: 1/2)
[QUEUE_FULL] Work item #86001 detected but queue is full (In Progress: 2/2). Will retry on next check.

Queue Status: 5 total items | 2 in progress | 3 pending | 0 reviewed
```

## Scheduling

### Automated Monitoring (Every 2 Minutes)

```powershell
# Already configured via Setup-MossyReview-Monitor.ps1
Get-ScheduledTask -TaskName "Mossy Review ADO Monitor"
```

### Control Monitoring (Start/Stop)

**Easy Method - Double-click batch files:**

📂 Location: `C:\source\MD\AdminTools\.github\skills\ado-mossy-review\`

- **Start-MossyReview.bat** - Enable monitoring (runs every 2 minutes)
- **Stop-MossyReview.bat** - Disable monitoring (task remains but doesn't run)

**PowerShell Commands:**

```powershell
# Enable monitoring
Enable-ScheduledTask -TaskName "Mossy Review ADO Monitor"

# Disable monitoring
Disable-ScheduledTask -TaskName "Mossy Review ADO Monitor"

# Check status
Get-ScheduledTask -TaskName "Mossy Review ADO Monitor" | Select-Object TaskName, State

# Test immediately (one-time run)
Start-ScheduledTask -TaskName "Mossy Review ADO Monitor"
```

**Status Values:**
- `Ready` = Enabled and waiting for next trigger
- `Disabled` = Task exists but won't run automatically
- `Running` = Currently executing

### Manual Invocation

```
@Mossy check for new Mossy Review items
@Mossy investigate pending work items
@Mossy process review queue
```

## Queue Status Lifecycle

```
New Item → pending → in_progress → reviewed → [removed from queue after 30 days]
           ↑                                      ↓
           └──── Mossy Review Again tag ──────────┘
                (resets to pending, increments review_count)
```

## Troubleshooting

### Issue: Work Item Not Detected

**Check:**
1. Tag spelling: "Mossy Review" (exact match, case-sensitive)
2. Item in current sprint
3. Item state is Active/New (not Closed)

**Solution:**
```powershell
az boards work-item show --id 85717 | Select-String -Pattern "Mossy Review"
```

### Issue: Assessment Not Posted

**Check:**
1. Azure CLI authenticated: `az account show`
2. Permissions on work item
3. Comment length (Azure DevOps has 1MB limit)

**Solution:**
```bash
az login
az boards work-item update --id 85717 --discussion "Test comment"
```

### Issue: Tags Not Removed

**Check:**
1. Tag removal syntax (semicolon separator)
2. Permissions to edit work item

**Solution:**
```bash
# Manual tag removal
az boards work-item update --id 85717 --fields "System.Tags=;Mossy Review;Mossy Review Again"
```

### Issue: Duplicate Queue Entries

**Check:**
1. Queue file not corrupted
2. Script logic for duplicate detection

**Solution:**
```powershell
# Rebuild queue from scratch
Remove-Item "C:\source\MD\AdminTools\Output\mossy-review-queue.json"
.\Check-MossyReview-WorkItems.ps1
```

## Best Practices

1. **Always Check Previous Assessments**
   - For reinvestigations, reference prior findings
   - Highlight what's changed

2. **Include Actionable Recommendations**
   - Specific SQL queries
   - Exact commands to run
   - Timeline estimates

3. **Link to Resources**
   - Wiki pages
   - Similar tickets
   - Relevant code/queries

4. **Tag Appropriate People**
   - Mention assignee in assessment
   - Suggest next owner if needed

5. **Queue Maintenance**
   - Archive reviewed items after 30 days
   - Clean up orphaned entries
   - Monitor queue growth

## Related Skills

- `check-ssis-errors` - For SSIS package failure investigations
- `bulk-price-validation` - For price discrepancy analysis
- `job-execution-duration` - For Script Adapter timing issues
- `daily-standup-report` - For sprint board queries
- `outlook-email-extraction` - For email-triggered work items

## Version History

- **v2.0.0** (2026-07-31) - Added "Mossy Review Again" support, reinvestigation workflow, queue duplicate prevention
- **v1.0.0** (2026-07-30) - Initial release with basic monitoring and queue management

## Support

**For questions or issues:**
- Check `README.md` in skill directory
- Review monitoring logs
- Contact: Back Office Support Team
