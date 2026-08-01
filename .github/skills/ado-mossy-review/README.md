# Mossy Review ADO Work Items Monitor

Automated monitoring system for Azure DevOps work items tagged with "Mossy Review".

## 📋 Overview

Three monitoring approaches:

1. **Task Scheduler** (Recommended) - Runs every 2 minutes via Windows Task Scheduler
2. **Continuous Loop** - PowerShell script that runs continuously
3. **Manual** - Run checks on-demand

## 🚀 Quick Start

### Option 1: Task Scheduler (Recommended for Production)

**Setup (run once):**
```powershell
cd C:\source\MD\AdminTools\.github\skills\ado-mossy-review
.\Setup-MossyReview-Monitor.ps1
```

**With logging enabled:**
```powershell
.\Setup-MossyReview-Monitor.ps1 -EnableLogging
```

**Features:**
- ✅ Runs automatically every 2 minutes
- ✅ Survives logoff/reboot
- ✅ Minimal resource usage
- ✅ Integrated with Windows Task Scheduler
- ✅ Detects new work items
- ✅ Tracks state changes

**Management:**
```powershell
# Start immediately (test)
Start-ScheduledTask -TaskName "Mossy Review ADO Monitor"

# Disable monitoring
Disable-ScheduledTask -TaskName "Mossy Review ADO Monitor"

# Enable monitoring
Enable-ScheduledTask -TaskName "Mossy Review ADO Monitor"

# Remove monitoring
Unregister-ScheduledTask -TaskName "Mossy Review ADO Monitor" -Confirm:$false

# View task status
Get-ScheduledTask -TaskName "Mossy Review ADO Monitor" | Format-List
```

---

### Option 2: Continuous Loop (For Active Sessions)

**Start monitoring:**
```powershell
cd C:\source\MD\AdminTools\.github\skills\ado-mossy-review
.\Monitor-MossyReview-Continuous.ps1
```

**With verbose output:**
```powershell
.\Monitor-MossyReview-Continuous.ps1 -Verbose
```

**With custom interval (e.g., 5 minutes):**
```powershell
.\Monitor-MossyReview-Continuous.ps1 -IntervalMinutes 5
```

**Stop monitoring:** Press `Ctrl+C`

**Features:**
- ✅ Real-time console output
- ✅ Highlights new items immediately
- ✅ Shows state changes
- ✅ Logs completed items
- ⚠️ Requires PowerShell window open
- ⚠️ Stops when you log off

---

### Option 3: Manual Check (On-Demand)

**Run single check:**
```powershell
cd C:\source\MD\AdminTools\.github\skills\ado-mossy-review
.\Check-MossyReview-WorkItems.ps1
```

**With logging:**
```powershell
.\Check-MossyReview-WorkItems.ps1 -LogToFile
```

**Only show when changes detected:**
```powershell
.\Check-MossyReview-WorkItems.ps1 -OnlyShowChanges
```

---

## 📊 Output Examples

### New Item Detected
```
==========================================
🔔 NEW MOSSY REVIEW ITEMS DETECTED!
==========================================
Task #85904 - Investigate Price Reconciliation
  URL: https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/85904
==========================================
```

### Active Items Summary
```
==========================================
MOSSY REVIEW WORK ITEMS - 2026-07-31 14:30:15
==========================================
Found 1 active work item(s):

Task #85717 - Reconciliation of Price Data
  State: In Progress
  Sprint: 07.26b [CURRENT SPRINT]
  Tags: Bug Triage; Mossy Review
  Assigned: Tay Nguyen
  URL: https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/85717

==========================================
```

### State Change Notification
```
🔄 STATE CHANGES (1):
  Task #85717 - Reconciliation of Price Data
    New → In Progress
```

---

## 🗂️ Files Generated

| File | Purpose |
|------|---------|
| `mossy-review-monitor.log` | Execution history and changes log |
| `mossy-review-state.json` | Current state of work items (for change detection) |

**Location:** `C:\source\MD\AdminTools\Output\`

---

## 🔧 Configuration

### Change Check Interval (Task Scheduler)

After setup, modify the trigger:
```powershell
$trigger = Get-ScheduledTaskTrigger -TaskName "Mossy Review ADO Monitor"
$trigger.Repetition.Interval = "PT5M"  # 5 minutes (ISO 8601 format)
Set-ScheduledTask -TaskName "Mossy Review ADO Monitor" -Trigger $trigger
```

Common intervals:
- `PT2M` = 2 minutes
- `PT5M` = 5 minutes
- `PT10M` = 10 minutes
- `PT30M` = 30 minutes
- `PT1H` = 1 hour

### Change Azure DevOps Project

Edit scripts and update parameters:
```powershell
-Organization "https://your-org.visualstudio.com/"
-Project "Your-Project-Name"
```

### Modify WIQL Query

Edit `Check-MossyReview-WorkItems.ps1` line ~22 to customize the query:
```sql
-- Example: Include different tags
WHERE [System.Tags] CONTAINS 'Mossy Review' 
   OR [System.Tags] CONTAINS 'Urgent Review'

-- Example: Filter by assigned user
WHERE [System.Tags] CONTAINS 'Mossy Review'
  AND [System.AssignedTo] = 'Your Name'

-- Example: Include specific area path
WHERE [System.Tags] CONTAINS 'Mossy Review'
  AND [System.AreaPath] UNDER 'Siepe.Software\Back Office SQL Engineers'
```

---

## 🔍 Current Sprint Detection

The scripts automatically detect if a work item is in the current sprint:

**Sprint Naming Convention:**
- Format: `MM.YYx` (e.g., `07.26b`)
- Month-based matching
- Marked with `[CURRENT SPRINT]` indicator

**To Improve Sprint Detection:**

Replace basic month check with date range logic in `Check-MossyReview-WorkItems.ps1`:

```powershell
# Query sprint dates from ADO
$sprints = az boards iteration project list --project $Project --output json | ConvertFrom-Json

# Find current sprint by date range
$currentSprint = $sprints | Where-Object {
    $start = [DateTime]::Parse($_.'startDate')
    $finish = [DateTime]::Parse($_.'finishDate')
    $today -ge $start -and $today -le $finish
} | Select-Object -First 1
```

---

## 🐛 Troubleshooting

### Task Scheduler Not Running

**Check task status:**
```powershell
Get-ScheduledTask -TaskName "Mossy Review ADO Monitor" | Select-Object State, LastRunTime, NextRunTime
```

**View task history:**
1. Open Task Scheduler (`taskschd.msc`)
2. Navigate to: Task Scheduler Library
3. Find: "Mossy Review ADO Monitor"
4. Click "History" tab

**Common issues:**
- ❌ Azure CLI not in PATH → Add to system environment variables
- ❌ Not logged into Azure → Run `az login` once
- ❌ Network issues → Check `RunOnlyIfNetworkAvailable` setting

### No Work Items Detected

**Verify query manually:**
```powershell
az boards query --wiql "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.Tags] CONTAINS 'Mossy Review'" --output table
```

**Check tag format:**
- Tags are case-sensitive
- Must be exact match: `Mossy Review` (not `mossy review`)
- Multiple tags separated by semicolons in ADO

### State File Issues

**Reset state tracking:**
```powershell
Remove-Item "C:\source\MD\AdminTools\Output\mossy-review-state.json"
```

This will treat all current items as "new" on next check.

---

## 📈 Integration with Mossy Agent

Create a skill to query this data:

**File:** `.github/skills/ado-review/SKILL.md`
```yaml
---
name: ado-review
description: Query and manage Mossy Review work items from Azure DevOps
keywords: [ado, azure devops, mossy review, work items, tasks, bugs]
category: backoffice
status: active
---

# Mossy Review ADO Integration

When user asks about Mossy Review work items, execute:

```powershell
C:\source\MD\AdminTools\.github\skills\ado-mossy-review\Check-MossyReview-WorkItems.ps1
```

Parse output and present to user with:
- Current sprint items highlighted
- Direct links to ADO work items
- State and assignment information
```

**Invoke from Mossy:**
```
@Mossy what are my Mossy Review work items?
@Mossy check current sprint Mossy Review items
@Mossy list active Mossy Review tasks
```

---

## 🔐 Security

- Uses `az boards` CLI (Windows Auth)
- Requires Azure DevOps read permissions
- No credentials stored in scripts
- Logs may contain work item titles (sensitive data)

**Secure log files:**
```powershell
# Restrict access to Output folder
$acl = Get-Acl "C:\source\MD\AdminTools\Output"
$acl.SetAccessRuleProtection($true, $false)
Set-Acl "C:\source\MD\AdminTools\Output" $acl
```

---

## 📝 Changelog

**2026-07-31 - v1.0**
- Initial release
- Task Scheduler integration
- Continuous monitoring option
- Manual check script
- Change detection (new items, state changes)
- Current sprint detection
- Logging support

---

## 🤝 Support

For issues or enhancements, contact Back Office SQL Engineers team or update scripts directly.
