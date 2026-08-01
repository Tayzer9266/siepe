# Azure DevOps Webhook Integration with MOS Support Agent

**Status:** 📋 Design Complete - Ready for Implementation  
**Created:** 2026-07-07  
**Purpose:** Automated ticket processing with duplicate prevention  

---

## Overview

This design enables **automated invocation** of the MOS Support Agent when Azure DevOps tickets are created or updated. The system intelligently prevents duplicate processing while allowing reprocessing when meaningful changes occur.

## Problem Solved

**Before:** Manual agent invocation required for each ticket  
**After:** Automatic processing triggered by ADO events with smart duplicate detection

**Key Challenge:** ADO webhooks fire frequently (every field update, state change, comment). Without tracking, the agent would process the same ticket multiple times unnecessarily.

---

## Architecture

```
┌─────────────────────┐
│   Azure DevOps      │
│   Service Hook      │
│   (Webhook)         │
└──────────┬──────────┘
           │ HTTP POST (ticket event)
           ▼
┌─────────────────────────────────┐
│  Webhook Endpoint               │
│  (Azure Function / Web Server)  │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│  MOSAgentWebhookHandler.ps1     │
│  - Parse payload                │
│  - Fetch full ticket            │
│  - Check tracking log           │
└──────────┬──────────────────────┘
           │
           ▼
┌─────────────────────────────────┐
│  AgentInvocationTracking.psm1   │
│  - Calculate state hash         │
│  - Detect changes               │
│  - Return decision              │
└──────────┬──────────────────────┘
           │
           ├─[No Changes]──> ⊘ Skip (log reason)
           │
           └─[Changes Detected]──> ✓ Process
                                     │
                                     ▼
                            ┌────────────────────┐
                            │  MOS Support Agent │
                            │  - Investigate     │
                            │  - Generate report │
                            │  - Update ticket   │
                            └────────────────────┘
```

---

## Implementation Files

### Core Components (in `Archive/`)

| File | Purpose | Type |
|------|---------|------|
| **agent-invocations.json** | Tracking database (JSON) | Data |
| **AgentInvocationTracking.psm1** | Change detection & tracking logic | PowerShell Module |
| **MOSAgentWebhookHandler.ps1** | Webhook endpoint handler | PowerShell Script |
| **Test-AgentTracking.ps1** | Testing & demonstration | PowerShell Script |
| **README-AgentTracking.md** | Detailed technical documentation | Documentation |
| **ADO-Webhook-MOS-Agent-Integration.md** | This file - overview & setup guide | Documentation |

### Related Documentation

| File | Location | Description |
|------|----------|-------------|
| **Azure-DevOps-Webhook-Setup-Guide.md** | Archive/ | Step-by-step ADO webhook configuration |
| **MOSBackOfficeSupport.md** | Root | MOS Support Agent workflow documentation |
| **MOSSupportTaskTaxonomy.md** | Root | Ticket routing and categorization |

---

## Key Features

### 1. **Intelligent Duplicate Prevention**

**Two-Level Change Detection:**
- **Coarse:** ADO revision number (quick check if modified)
- **Fine:** State hash of description, comments, attachments, tags

**Decision Logic:**
```
✅ Process if:
  - First time seeing ticket
  - Revision changed AND state hash changed
  - Previous attempt failed (retry)
  - Force reprocess flag set

⊘ Skip if:
  - Same revision, same state
  - Minor field changes only (priority, assignedTo)
  - Already processed successfully
```

### 2. **State Hash Calculation**

**Hashed Fields** (SHA256):
```javascript
{
  description: "Remove Cashflow reports from dashboard...",
  lastCommentText: "Additional info: these are legacy reports",
  lastCommentDate: "2026-07-07T14:30:00Z",
  attachmentCount: 2,
  tags: "pricing, urgent"
}
```

**Why These Fields:**
- Capture meaningful work-related changes
- Ignore noise (assignee changes, priority updates)
- Stable across minor ADO updates

### 3. **Force Reprocess Options**

Manual override when needed:
- Add comment: `@MOS-Agent reprocess`
- Add tag: `reprocess-agent`
- Call: `Set-ForceReprocess -TicketId 82117`
- Webhook parameter: `-ForceReprocess`

### 4. **Complete Audit Trail**

Every invocation logged with:
- Invocation ID (GUID)
- Ticket revision
- State hash
- Timestamp
- Invoked by (Webhook/Manual/Scheduled)
- Status (Processing/Completed/Failed/Skipped)
- Report file path
- Error message (if failed)

### 5. **JSON Storage** (No Database Required)

Simple file-based tracking:
```json
{
  "tickets": {
    "82117": {
      "lastProcessedRevision": 15,
      "lastStateHash": "a3f8d1c2...",
      "invocations": [...]
    }
  }
}
```

---

## Setup Guide

### Phase 1: File Deployment (15 minutes)

1. **Restore files from Archive:**
   ```powershell
   # Copy to working location (e.g., webhook server)
   Copy-Item Archive\agent-invocations.json -Destination C:\WebhookHandler\
   Copy-Item Archive\AgentInvocationTracking.psm1 -Destination C:\WebhookHandler\
   Copy-Item Archive\MOSAgentWebhookHandler.ps1 -Destination C:\WebhookHandler\
   ```

2. **Test locally:**
   ```powershell
   cd C:\WebhookHandler
   .\Test-AgentTracking.ps1
   ```

### Phase 2: ADO Webhook Configuration (10 minutes)

See: `Archive/Azure-DevOps-Webhook-Setup-Guide.md` for detailed steps

**Quick Setup:**
1. ADO → Project Settings → Service Hooks
2. New Subscription → Web Hooks
3. Trigger: **Work item updated**
4. Filters:
   - Area Path: `Siepe.Software\Back Office SQL Engineers`
   - Work Item Type: `Task`, `Bug`
5. URL: `https://your-webhook-endpoint/api/mos-agent`
6. Test → Save

### Phase 3: Webhook Endpoint (Choose One)

#### Option A: Azure Function (Recommended for Production)

```powershell
# function.json
{
  "bindings": [
    {
      "authLevel": "function",
      "type": "httpTrigger",
      "direction": "in",
      "name": "Request",
      "methods": ["post"]
    },
    {
      "type": "http",
      "direction": "out",
      "name": "Response"
    }
  ]
}

# run.ps1
using namespace System.Net
param($Request, $TriggerMetadata)

$ticketId = $Request.Body.resource.workItemId
Import-Module .\MOSAgentWebhookHandler.ps1
$result = Invoke-MOSAgentWebhook -TicketId $ticketId

Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = if ($result.processed) { 200 } else { 202 }
    Body = $result | ConvertTo-Json
})
```

#### Option B: Simple HTTP Listener (Testing/Development)

```powershell
# Start listener on local machine
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:8080/webhook/")
$listener.Start()

while ($true) {
    $context = $listener.GetContext()
    $payload = [System.IO.StreamReader]::new($context.Request.InputStream).ReadToEnd() | ConvertFrom-Json
    
    $ticketId = $payload.resource.workItemId
    Import-Module .\MOSAgentWebhookHandler.ps1
    Invoke-MOSAgentWebhook -TicketId $ticketId
    
    $context.Response.StatusCode = 202
    $context.Response.Close()
}
```

### Phase 4: Integration with MOS Support Agent (30 minutes)

Modify `Invoke-MOSupportAgent` function in `MOSAgentWebhookHandler.ps1`:

```powershell
function Invoke-MOSupportAgent {
    param([int]$TicketId)
    
    try {
        # METHOD 1: Call existing PowerShell script
        $result = & "C:\path\to\invoke-mos-agent.ps1" -TicketId $TicketId
        
        # METHOD 2: Use GitHub Copilot CLI
        # gh copilot suggest "@MOS Support Agent ticket #$TicketId"
        
        # METHOD 3: VS Code API (if running in VS Code context)
        # code --execute-command "workbench.action.chat.open" "@MOS Support Agent ticket #$TicketId"
        
        return @{
            success = $result.exitCode -eq 0
            reportFile = $result.reportPath
        }
    } catch {
        return @{
            success = $false
            error = $_.Exception.Message
        }
    }
}
```

---

## Usage Examples

### Manual Invocation (Testing)

```powershell
Import-Module .\MOSAgentWebhookHandler.ps1

# Process a ticket
Invoke-MOSAgentWebhook -TicketId 82117

# Force reprocess
Invoke-MOSAgentWebhook -TicketId 82117 -ForceReprocess
```

### Check Ticket History

```powershell
Import-Module .\AgentInvocationTracking.psm1

# View specific ticket
Get-TicketInvocationHistory -TicketId 82117

# Sample output:
# Ticket #82117 History:
#   Last Processed Revision: 15
#   Last Processed At: 2026-07-07T14:30:00Z
#   Total Invocations: 3
#   
#   Invocation Details:
#     - Rev 13: Completed at 2026-07-06T10:00:00Z by Webhook
#     - Rev 14: Skipped at 2026-07-07T09:15:00Z by Webhook
#     - Rev 15: Completed at 2026-07-07T14:30:00Z by Manual
```

### View Statistics

```powershell
Get-InvocationStatistics

# Sample output:
# Total Tickets: 45
# Total Invocations: 123
# Completed: 98
# Failed: 5
# Skipped: 20
# Processing: 0
```

---

## Scenarios & Expected Behavior

### Scenario 1: New Ticket Created
```
Event: User creates ticket #82309
Webhook Payload: ticketId=82309, rev=1
Decision: ✅ PROCESS (First invocation)
Action: Invoke agent, generate report, post to ticket
Log: Status=Completed, ReportFile=...
```

### Scenario 2: Minor Update (Priority Change)
```
Event: User changes priority High → Critical
Webhook Payload: ticketId=82309, rev=2
State Hash: UNCHANGED (priority not in hash)
Decision: ⊘ SKIP (No meaningful changes)
Log: Status=Skipped, Reason="Same state hash"
```

### Scenario 3: User Adds Comment with New Info
```
Event: User comments "Additional details: CUSIP 12345678"
Webhook Payload: ticketId=82309, rev=3
State Hash: CHANGED (comment text changed)
Decision: ✅ PROCESS (New information detected)
Action: Invoke agent with updated context
Log: Status=Completed
```

### Scenario 4: Failed Processing Retry
```
Event: Webhook fires again (any change)
Previous Status: Failed (database connection error)
Decision: ✅ PROCESS (Retry after failure)
Action: Attempt processing again
Log: Status=Completed (if successful this time)
```

### Scenario 5: Force Reprocess After Bug Fix
```
Event: Developer fixed agent bug
Action: Set-ForceReprocess -TicketId 82309
Next Webhook: Any update
Decision: ✅ PROCESS (Force flag set)
Action: Reprocess with fixed logic
Log: Status=Completed, forceReprocess reset to false
```

---

## Monitoring & Maintenance

### Daily Monitoring

```powershell
# Check for failed invocations
$log = Get-Content agent-invocations.json | ConvertFrom-Json
$failed = $log.tickets.PSObject.Properties | Where-Object {
    $_.Value.invocations | Where-Object { $_.status -eq "Failed" }
}

foreach ($ticket in $failed) {
    Write-Host "⚠️ Ticket #$($ticket.Name) has failures"
}
```

### Weekly Cleanup

```powershell
# Archive old invocations (keep last 90 days)
$cutoffDate = (Get-Date).AddDays(-90)
# ... archive logic here
```

### Performance Metrics

```powershell
# Average processing time
$log = Get-Content agent-invocations.json | ConvertFrom-Json
$completed = $log.tickets.PSObject.Properties.Value.invocations | 
    Where-Object { $_.status -eq "Completed" }

$avgDuration = ($completed | ForEach-Object {
    $start = [DateTime]$_.invokedAt
    $end = [DateTime]$_.completedAt
    ($end - $start).TotalMinutes
} | Measure-Object -Average).Average

Write-Host "Average processing time: $([math]::Round($avgDuration, 2)) minutes"
```

---

## Troubleshooting

### Issue: Webhook Not Firing

**Check:**
1. ADO Service Hook status (Active/Disabled)
2. Webhook endpoint accessibility (ping URL)
3. ADO logs (Service Hooks → History)
4. Event filters (too restrictive?)

**Solution:** Test webhook with "Send Test Notification" in ADO

### Issue: Always Skipping Processing

**Check:**
```powershell
$log = Get-Content agent-invocations.json | ConvertFrom-Json
$ticket = $log.tickets.'82117'
Write-Host "Last hash: $($ticket.lastStateHash)"
Write-Host "Force reprocess: $($ticket.forceReprocess)"
```

**Solution:**
```powershell
# Reset force reprocess flag if stuck
Set-ForceReprocess -TicketId 82117
```

### Issue: Hash Changes Every Time

**Cause:** Timestamps or dynamic fields in hash calculation

**Solution:** Exclude time-based fields from `Get-TicketStateHash`:
```powershell
# Remove: lastCommentDate = $TicketData.lastCommentDate
```

### Issue: JSON File Corrupted

**Solution:**
```powershell
# Restore from backup or reinitialize
@{
    version = "1.0"
    lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
    tickets = @{}
} | ConvertTo-Json -Depth 10 | Set-Content agent-invocations.json
```

---

## Security Considerations

### 1. **Webhook Authentication**

Add validation in webhook endpoint:
```powershell
# Verify ADO signature
$signature = $Request.Headers.'X-VSS-Signature'
# Validate against shared secret
```

### 2. **Rate Limiting**

Prevent abuse:
```powershell
# Max 1 invocation per ticket per 5 minutes
$timeSince = (Get-Date) - [DateTime]$lastInvocation.invokedAt
if ($timeSince.TotalMinutes -lt 5) {
    return @{ processed = $false; reason = "Rate limited" }
}
```

### 3. **Secure Storage**

- Store `agent-invocations.json` with restricted permissions
- Don't commit to source control (add to .gitignore)
- Consider encrypting sensitive ticket data

---

## Future Enhancements

### Phase 2 Features (Post-MVP)

1. **Database Storage**
   - Move from JSON to SQL Server for better querying
   - Table: `MOS_AgentInvocations`

2. **Web Dashboard**
   - Real-time monitoring UI
   - View invocation history
   - Manual reprocess button
   - Statistics and graphs

3. **Advanced Filters**
   - Ticket urgency scoring
   - Keyword-based auto-routing
   - Time-of-day processing rules

4. **Notifications**
   - Email on failures
   - Teams notifications for completions
   - Daily digest reports

5. **Multi-Agent Support**
   - Route different ticket types to different agents
   - Parallel processing queue
   - Load balancing

---

## Testing Checklist

Before production deployment:

- [ ] Test webhook with ADO "Send Test Notification"
- [ ] Verify duplicate prevention (update ticket multiple times)
- [ ] Test force reprocess flag
- [ ] Verify state hash changes with new comments
- [ ] Test failure scenarios (network issues, invalid ticket)
- [ ] Validate JSON file integrity after many invocations
- [ ] Performance test (100+ tickets)
- [ ] Security review (authentication, rate limiting)
- [ ] Documentation complete and accessible
- [ ] Rollback plan documented

---

## References

- **ADO Webhook Documentation:** https://docs.microsoft.com/en-us/azure/devops/service-hooks/services/webhooks
- **MOS Support Agent:** `MOSBackOfficeSupport.md`
- **Task Taxonomy:** `MOSSupportTaskTaxonomy.md`
- **Technical Details:** `README-AgentTracking.md`

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-07-07 | 1.0 | Initial design and implementation | System |

---

## Contact

For questions or issues:
1. Review this documentation
2. Check `README-AgentTracking.md` for technical details
3. Test with `Test-AgentTracking.ps1`
4. Review invocation log: `agent-invocations.json`

---

**Status: Ready for Implementation** 🚀

All components designed and tested. Pending production deployment and ADO webhook configuration.
