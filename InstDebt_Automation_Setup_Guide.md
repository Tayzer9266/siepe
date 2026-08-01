# InstDebt Complete Push Automation Setup

## Summary
Created automated pipeline for InstDebt data flow:
**Feeds → Core → Reference**

This fixes the 13-day backlog where InstDebt records weren't flowing to the portal.

---

## Files Created

### 1. PowerShell Script
**Location:** `\\998s02.mos.siepe.local\Siepe\Data\Scripts\PROD\InstDebt_CompletePush.ps1`

**Purpose:** Runs both push stages in sequence:
- **Step 1:** Feeds → Core (GenericPushInstDebt.dtsx)
- **Step 2:** Core → Reference (PushInstDebt.dtsx)
- **Step 3:** Verification queries

### 2. Script Adapter SQL
**Location:** `C:\source\MD\AdminTools\Create_InstDebt_ScriptAdapter.sql`

**Purpose:** Creates Script Adapter configuration (requires DBA permissions)

### 3. Pub/Sub Trigger SQL
**Location:** `C:\source\MD\AdminTools\Trigger_InstDebt_Push.sql`

**Purpose:** Manually trigger the script via pub/sub message

---

## Quick Start - Run Now

### Option A: Manual Execution on Server (RECOMMENDED FOR FIRST RUN)
```powershell
# RDP to 998S02 server
cd C:\Siepe\Data\Scripts\PROD
.\InstDebt_CompletePush.ps1
```

This will:
1. Calculate most recent weekday date
2. Push InstDebt from Feeds to Core
3. Push InstDebt from Core to Reference
4. Verify both databases
5. Create detailed log file

### Option B: Run from Your Workstation
```powershell
Invoke-Command -ComputerName 998S02 -ScriptBlock {
    cd C:\Siepe\Data\Scripts\PROD
    .\InstDebt_CompletePush.ps1
}
```

---

## Full Automation Setup

### Step 1: Create Script Adapter (Requires DBA)
Ask someone with INSERT permissions on Enterprise database to run:
```sql
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Enterprise" -i "C:\source\MD\AdminTools\Create_InstDebt_ScriptAdapter.sql"
```

This creates:
- **Script Adapter ID:** 1561 (or next available)
- **Name:** InstDebt Complete Push (Feeds -> Core -> Reference)
- **Pub/Sub Topic:** GenericPush.InstDebt.Complete
- **Script Path:** C:\Siepe\Data\Scripts\PROD\InstDebt_CompletePush.ps1

### Step 2: Set Up Daily Schedule

#### Option A: Create Report Subscription (Portal UI)
1. Go to MOS Portal → Admin → Report Subscriptions
2. Create new subscription:
   - **Name:** "Daily InstDebt Complete Push"
   - **Schedule:** Cron: `0 5 * * *` (Daily at 5:00 AM)
   - **Pub/Sub Publish Subject:** `GenericPush.InstDebt.Complete`
   - **Report:** Any simple report (just needed to trigger)
   
#### Option B: Add to Existing Scheduled Job
Modify an existing daily script to publish the trigger message:
```powershell
# Add this to an existing scheduled script
$SqlQuery = @"
INSERT INTO Enterprise.PubSub.tPublishedMessage (Subject, MessageText, CreatedDate, CreatedUser)
VALUES ('GenericPush.InstDebt.Complete', 'Automated daily trigger', GETDATE(), SYSTEM_USER)
"@
fExecuteSQL $ServerName $Enterprise $SqlQuery $LogFile
```

#### Option C: Windows Scheduled Task
```powershell
# Create Windows scheduled task on 998S02
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File "C:\Siepe\Data\Scripts\PROD\InstDebt_CompletePush.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At 5:00AM
Register-ScheduledTask -TaskName "InstDebt_Complete_Push" -Action $action -Trigger $trigger -User "DOMAIN\ServiceAccount"
```

---

## Verification

### Check Recent Execution
```sql
SELECT TOP 10 
    sch.ConfigurationHistoryID,
    sc.Name,
    sch.StartTimeStamp,
    sch.EndTimeStamp,
    DATEDIFF(SECOND, sch.StartTimeStamp, sch.EndTimeStamp) AS DurationSeconds,
    rrs.Name AS Status
FROM Enterprise.ScriptAdapter.tScriptConfigurationHistory sch
INNER JOIN Enterprise.ScriptAdapter.tScriptConfiguration sc ON sch.ScriptConfigurationID = sc.ScriptConfigurationID
INNER JOIN Enterprise.dbo.tRefRecStatus rrs ON sch.RefRecStatusID = rrs.RefRecStatusID
WHERE sc.Name LIKE '%InstDebt%'
ORDER BY sch.CreatedDate DESC;
```

### Verify Corelogic Bond Now Has SeniorityType
```sql
SELECT 
    i.InstID,
    i.Name,
    id.SeniorityTypeID,
    st.Name AS SeniorityDisplayValue,
    id.IssueDate,
    id.MaturityDate,
    id.OriginalGlobalAmount
FROM Reference.dbo.tInst i
LEFT JOIN Reference.dbo.tInstDebt id ON i.InstID = id.InstID
LEFT JOIN Reference.dbo.tSeniorityType st ON id.SeniorityTypeID = st.SeniorityTypeID
WHERE i.InstID = 1000598849  -- Corelogic bond
  AND i.RefRecStatusID = 1
  AND id.RefRecStatusID = 1;
```

**Expected Result:**
- SeniorityTypeID: 1000000001
- SeniorityDisplayValue: "Senior Secured"
- IssueDate: 2026-07-17
- MaturityDate: 2031-08-01
- OriginalGlobalAmount: 1,650,000,000

### Check Latest InstDebt Records
```sql
-- Core
SELECT TOP 5 InstDebtID, InstID, CreatedDate 
FROM Core.dbo.tInstDebt 
WHERE RefRecStatusID = 1 
ORDER BY CreatedDate DESC;

-- Reference
SELECT TOP 5 InstDebtID, InstID, CreatedDate 
FROM Reference.dbo.tInstDebt 
WHERE RefRecStatusID = 1 
ORDER BY CreatedDate DESC;
```

---

## Troubleshooting

### Script Fails at Step 1 (Feeds → Core)
**Check:** Normalization data exists
```sql
SELECT COUNT(*) 
FROM Feeds.Solvas.fBMSSecurityMasterInstDebtRefNormalization('2026-07-29');
```
Should return ~8,368 records

### Script Fails at Step 2 (Core → Reference)
**Check:** PushInstDebt.dtsx package exists
```powershell
Test-Path "\\998s02.mos.siepe.local\Siepe\Data\SSIS\Push\PushInstDebt.dtsx"
```
Should return True

### No Records Created
**Check:** SSIS execution logs
```sql
SELECT TOP 20 * 
FROM Enterprise.SSIS.tPackageExecutionHistory 
WHERE PackageName LIKE '%InstDebt%' 
ORDER BY CreatedDate DESC;
```

### Check Log Files
Log files are created in: `\\998s02.mos.siepe.local\Siepe\Data\Scripts\Log\`
Format: `InstDebt_CompletePush.YYYYMMDDTHHMMSS.txt`

---

## Architecture Summary

### Previous State (BROKEN)
- **SA 1008** (Run Default Push Configurations)
  - Last ran: 2026-02-27 (5 months ago)
  - No Report Subscription triggering it
  - Only pushed Feeds → Core (not Core → Reference)
- **Result:** 13-day backlog, no SeniorityType on portal

### New State (FIXED)
- **New Script:** InstDebt_CompletePush.ps1
  - Runs both stages: Feeds → Core → Reference
  - Includes verification
  - Comprehensive logging
- **New SA:** InstDebt Complete Push (pending DBA creation)
  - Pub/Sub topic: GenericPush.InstDebt.Complete
  - Can be scheduled daily
- **Result:** Complete pipeline automation

---

## Next Steps

1. ✅ **RUN NOW:** Execute `InstDebt_CompletePush.ps1` on server to clear backlog
2. ⏳ **Schedule:** Set up daily automation (Report Subscription or Scheduled Task)
3. ⏳ **Monitor:** Check logs and verify daily execution
4. ⏳ **Cleanup:** Consider deprecating SA 1008 (Run Default Push Configurations) if no longer needed

---

## Contact
For issues or questions, check:
- Log files: `\\998s02.mos.siepe.local\Siepe\Data\Scripts\Log\InstDebt_CompletePush.*.txt`
- Script Adapter history: `Enterprise.ScriptAdapter.tScriptConfigurationHistory`
- SSIS execution logs: `Enterprise.SSIS.tPackageExecutionHistory`
