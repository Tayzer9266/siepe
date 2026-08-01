# MOS Agent Invocation Tracking System

## Overview

This system prevents duplicate processing of ADO tickets by the MOS Support Agent while allowing intelligent reprocessing when meaningful changes occur.

## Components

### 1. `agent-invocations.json`
Central tracking file that stores the history of all agent invocations.

**Structure:**
```json
{
  "version": "1.0",
  "lastUpdated": "2026-07-07T14:30:00Z",
  "tickets": {
    "82117": {
      "ticketId": 82117,
      "lastProcessedRevision": 15,
      "lastStateHash": "a3f8d1c2...",
      "lastProcessedAt": "2026-07-07T14:30:00Z",
      "forceReprocess": false,
      "invocations": [
        {
          "invocationId": "guid-1234...",
          "revision": 15,
          "stateHash": "a3f8d1c2...",
          "invokedAt": "2026-07-07T14:30:00Z",
          "invokedBy": "Webhook",
          "status": "Completed",
          "completedAt": "2026-07-07T14:35:00Z",
          "reportFile": "RemoveProcessDashboardReports_Cashflow_82117_20260707.md",
          "error": null
        }
      ]
    }
  }
}
```

### 2. `AgentInvocationTracking.psm1`
PowerShell module with core tracking functions.

**Key Functions:**
- `Get-TicketStateHash` - Calculate hash of ticket state
- `Test-ShouldProcessTicket` - Decide if processing is needed
- `Start-AgentInvocation` - Log invocation start
- `Complete-AgentInvocation` - Log invocation completion
- `Set-ForceReprocess` - Force reprocessing a ticket
- `Get-TicketInvocationHistory` - View ticket history
- `Get-InvocationStatistics` - Overall statistics

### 3. `MOSAgentWebhookHandler.ps1`
Webhook integration script that orchestrates the workflow.

**Main Function:**
- `Invoke-MOSAgentWebhook` - Main webhook entry point

### 4. `Test-AgentTracking.ps1`
Demo script showing example usage.

## How It Works

### Change Detection

The system uses **two-level change detection**:

1. **Coarse-grained**: ADO revision number
   - Quick check if ticket was modified at all
   
2. **Fine-grained**: State hash
   - Detects meaningful changes in:
     - Description
     - Last comment text
     - Last comment date
     - Attachment count
     - Tags

### Processing Decision Logic

```
┌─────────────────────────────┐
│  Webhook receives ticket    │
│  update notification        │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Calculate current state    │
│  hash from ticket fields    │
└──────────┬──────────────────┘
           │
           ▼
    ┌──────────────┐
    │ First time?  │───YES──> ✅ PROCESS
    └──────┬───────┘
           │ NO
           ▼
    ┌──────────────┐
    │Force reprocess│───YES──> ✅ PROCESS
    │  flag set?   │
    └──────┬───────┘
           │ NO
           ▼
    ┌──────────────┐
    │Previous run  │───YES──> ✅ PROCESS
    │  failed?     │          (Retry)
    └──────┬───────┘
           │ NO
           ▼
    ┌──────────────┐
    │ Revision #   │───YES──> Check hash
    │  changed?    │          ┌────────┐
    └──────┬───────┘          │Hash    │
           │ NO               │changed?│
           │                  └───┬────┘
           │              YES ┌───┴───┐ NO
           │                  │PROCESS│ │SKIP│
           ▼                  └───────┘ └────┘
    ┌──────────────┐
    │  ⊘ SKIP      │
    │ (No changes) │
    └──────────────┘
```

## Installation

1. Ensure files are in the `Output/` folder:
   ```
   Output/
   ├── agent-invocations.json
   ├── AgentInvocationTracking.psm1
   ├── MOSAgentWebhookHandler.ps1
   └── Test-AgentTracking.ps1
   ```

2. No additional dependencies required (uses built-in PowerShell)

## Usage

### Basic Usage (Manual)

```powershell
# Import the webhook handler
Import-Module .\Output\MOSAgentWebhookHandler.ps1

# Process a ticket
Invoke-MOSAgentWebhook -TicketId 82117

# Force reprocess a ticket
Invoke-MOSAgentWebhook -TicketId 82117 -ForceReprocess
```

### Webhook Integration

Create an Azure Function or webhook endpoint that calls:

```powershell
# webhook-endpoint.ps1
param($Request, $TriggerMetadata)

$ticketId = $Request.Body.resource.workItemId
$revision = $Request.Body.resource.revision.rev

# Import module
Import-Module .\Output\MOSAgentWebhookHandler.ps1

# Process
$result = Invoke-MOSAgentWebhook -TicketId $ticketId

# Return response
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = if ($result.success) { 200 } else { 500 }
    Body = $result | ConvertTo-Json
})
```

### Check Ticket History

```powershell
Import-Module .\Output\AgentInvocationTracking.psm1

# View specific ticket
Get-TicketInvocationHistory -TicketId 82117

# View statistics
Get-InvocationStatistics
```

### Force Reprocess

```powershell
Import-Module .\Output\AgentInvocationTracking.psm1

# Set flag for next invocation
Set-ForceReprocess -TicketId 82117

# Or use -ForceReprocess switch
Invoke-MOSAgentWebhook -TicketId 82117 -ForceReprocess
```

## Reprocessing Triggers

### Automatic (Detected by Change Hash)
- ✅ Description modified
- ✅ New comment added
- ✅ Attachment added/removed
- ✅ Tags changed

### Manual Override
- Add comment: `@MOS-Agent reprocess`
- Add tag: `reprocess-agent`
- Set force flag: `Set-ForceReprocess -TicketId 82117`

### Skipped (No Processing)
- ⊘ Minor field changes (priority, assigned to)
- ⊘ Same revision, same state hash
- ⊘ Automated/system comments

## Example Scenarios

### Scenario 1: First Investigation
```powershell
# User creates ticket #82117
# Webhook triggered
Invoke-MOSAgentWebhook -TicketId 82117

# Result: Processed ✅
# Reason: "First invocation - ticket never processed"
```

### Scenario 2: Duplicate Webhook (No Changes)
```powershell
# ADO fires webhook again due to minor update
Invoke-MOSAgentWebhook -TicketId 82117

# Result: Skipped ⊘
# Reason: "Already processed at rev 15 with same state"
```

### Scenario 3: User Adds New Information
```powershell
# User adds comment: "Additional details: pricing source was LSEG"
# Webhook triggered (revision 16)
Invoke-MOSAgentWebhook -TicketId 82117

# Result: Processed ✅
# Reason: "New changes detected (rev 16, hash changed)"
```

### Scenario 4: Force Rerun After Fix
```powershell
# Developer fixed agent bug, wants to reprocess
Set-ForceReprocess -TicketId 82117
Invoke-MOSAgentWebhook -TicketId 82117

# Result: Processed ✅
# Reason: "Force reprocess requested"
```

## Testing

Run the demo script:
```powershell
.\Output\Test-AgentTracking.ps1
```

This will:
1. Process ticket #82117 (first time)
2. Try to process again (skipped)
3. Force reprocess
4. Show ticket history
5. Display statistics

## Monitoring

### View All Invocations
```powershell
Get-Content .\Output\agent-invocations.json | ConvertFrom-Json | ConvertTo-Json -Depth 10
```

### View Recent Activity
```powershell
$log = Get-Content .\Output\agent-invocations.json | ConvertFrom-Json

foreach ($ticketId in $log.tickets.PSObject.Properties.Name) {
    $ticket = $log.tickets.$ticketId
    $lastInvocation = $ticket.invocations[-1]
    
    Write-Host "Ticket #$ticketId - Last: $($lastInvocation.status) at $($lastInvocation.invokedAt)"
}
```

### Check Failed Invocations
```powershell
$log = Get-Content .\Output\agent-invocations.json | ConvertFrom-Json

$log.tickets.PSObject.Properties | ForEach-Object {
    $ticket = $_.Value
    $failed = $ticket.invocations | Where-Object { $_.status -eq "Failed" }
    
    if ($failed) {
        Write-Host "Ticket #$($ticket.ticketId) has $($failed.Count) failed invocation(s)"
        $failed | ForEach-Object {
            Write-Host "  - $($_.invokedAt): $($_.error)"
        }
    }
}
```

## Customization

### Modify State Hash Fields

Edit `Get-TicketStateHash` in `AgentInvocationTracking.psm1`:

```powershell
$relevantFields = @{
    description = $TicketData.description
    lastCommentText = $TicketData.lastCommentText
    # Add more fields:
    assignedTo = $TicketData.assignedTo
    priority = $TicketData.priority
}
```

### Add Custom Processing Logic

Edit `Test-ShouldProcessTicket` to add your own conditions:

```powershell
# Case 6: Custom rule - always reprocess high priority
if ($ticketData.priority -eq 1) {
    return @{
        shouldProcess = $true
        reason = "High priority ticket - always reprocess"
    }
}
```

### Change Reprocess Keywords

Edit `Test-ReprocessTriggerInComments`:

```powershell
$triggers = @(
    '@MOS-Agent reprocess',
    'please re-investigate',
    # Add your own:
    'rerun analysis',
    'need fresh look'
)
```

## Best Practices

1. **Monitor Failed Invocations**: Check regularly for failed runs and investigate
2. **Clean Old Data**: Periodically archive old invocations (keep last 30 days)
3. **Backup Log File**: Include `agent-invocations.json` in backups
4. **Test Changes**: Use `Test-AgentTracking.ps1` before deploying changes
5. **Document Custom Rules**: Comment any custom processing logic added

## Troubleshooting

### Issue: Ticket Always Skipped
**Solution**: Check if `forceReprocess` flag is stuck:
```powershell
$log = Get-Content .\Output\agent-invocations.json | ConvertFrom-Json
$log.tickets.'82117'.forceReprocess = $false
$log | ConvertTo-Json -Depth 10 | Set-Content .\Output\agent-invocations.json
```

### Issue: Hash Changes on Every Invocation
**Solution**: ADO might be returning timestamps. Exclude time-based fields:
```powershell
# Remove lastCommentDate from hash calculation
$relevantFields = @{
    description = $TicketData.description
    lastCommentText = $TicketData.lastCommentText
    # Remove: lastCommentDate = $TicketData.lastCommentDate
}
```

### Issue: JSON File Corrupted
**Solution**: Restore from backup or reinitialize:
```powershell
@{
    version = "1.0"
    lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
    tickets = @{}
} | ConvertTo-Json -Depth 10 | Set-Content .\Output\agent-invocations.json
```

## Integration with MOS Support Agent

To fully integrate with the MOS Support Agent workflow:

1. Modify `Invoke-MOSupportAgent` function in `MOSAgentWebhookHandler.ps1`
2. Replace simulation with actual agent invocation
3. Example integration points:
   - Call GitHub Copilot CLI
   - Invoke agent via VS Code API
   - Trigger automation workflow

```powershell
function Invoke-MOSupportAgent {
    param([int]$TicketId)
    
    try {
        # YOUR ACTUAL AGENT INVOCATION HERE
        # Example: Call existing automation
        $result = & "C:\path\to\invoke-mos-agent.ps1" -TicketId $TicketId
        
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

## Files Reference

| File | Purpose | Type |
|------|---------|------|
| `agent-invocations.json` | Tracking data | Data |
| `AgentInvocationTracking.psm1` | Core functions | Module |
| `MOSAgentWebhookHandler.ps1` | Webhook integration | Script |
| `Test-AgentTracking.ps1` | Demo/testing | Script |
| `README-AgentTracking.md` | Documentation | Docs |

## Support

For issues or questions:
1. Check this README
2. Review `Test-AgentTracking.ps1` examples
3. Examine `agent-invocations.json` for invocation history
4. Enable verbose logging in scripts
