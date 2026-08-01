# Example: ADO Webhook Handler with Invocation Tracking
# This script demonstrates how to integrate the tracking module with MOS Support Agent

# Import the tracking module
Import-Module "$PSScriptRoot\AgentInvocationTracking.psm1" -Force

<#
.SYNOPSIS
Main webhook handler for ADO ticket updates

.PARAMETER TicketId
ADO ticket ID from webhook payload

.PARAMETER ForceReprocess
Force reprocessing regardless of change detection

.EXAMPLE
Invoke-MOSAgentWebhook -TicketId 82117
#>
function Invoke-MOSAgentWebhook {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TicketId,
        
        [switch]$ForceReprocess
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "MOS Agent Webhook Invoked" -ForegroundColor Cyan
    Write-Host "Ticket ID: $TicketId" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    try {
        # Step 1: Fetch current ticket data from ADO
        Write-Host "[1/6] Fetching ticket data from ADO..." -ForegroundColor Yellow
        
        $ticketJson = az boards work-item show --id $TicketId --org https://siepe.visualstudio.com/ --output json
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to fetch ticket $TicketId from ADO"
        }
        
        $ticket = $ticketJson | ConvertFrom-Json
        $revision = $ticket.rev
        
        Write-Host "  ✓ Ticket fetched: Rev $revision, State: $($ticket.fields.'System.State')" -ForegroundColor Green
        
        # Step 2: Get last comment (if any)
        Write-Host "[2/6] Fetching comments..." -ForegroundColor Yellow
        
        $commentsJson = az boards work-item show --id $TicketId --org https://siepe.visualstudio.com/ --query "fields.['System.History']" --output json
        $lastCommentText = if ($commentsJson) { ($commentsJson | ConvertFrom-Json) } else { "" }
        
        # Step 3: Calculate state hash
        Write-Host "[3/6] Calculating state hash..." -ForegroundColor Yellow
        
        $ticketData = @{
            description = $ticket.fields.'System.Description'
            lastCommentText = $lastCommentText
            lastCommentDate = $ticket.fields.'System.ChangedDate'
            attachmentCount = ($ticket.relations | Where-Object { $_.rel -eq 'AttachedFile' } | Measure-Object).Count
            tags = $ticket.fields.'System.Tags'
        }
        
        $stateHash = Get-TicketStateHash -TicketData $ticketData
        Write-Host "  ✓ State hash: $($stateHash.Substring(0,16))..." -ForegroundColor Green
        
        # Step 4: Check if should process
        Write-Host "[4/6] Checking if processing is needed..." -ForegroundColor Yellow
        
        $decision = Test-ShouldProcessTicket -TicketId $TicketId -Revision $revision -StateHash $stateHash -ForceReprocess:$ForceReprocess
        
        if (-not $decision.shouldProcess) {
            Write-Host "  ⊘ SKIPPED: $($decision.reason)" -ForegroundColor Yellow
            
            # Log skip
            $invocationId = Start-AgentInvocation -TicketId $TicketId -Revision $revision -StateHash $stateHash -InvokedBy "Webhook"
            Complete-AgentInvocation -TicketId $TicketId -InvocationId $invocationId -Status "Skipped" -ErrorMessage $decision.reason
            
            return @{
                processed = $false
                reason = $decision.reason
            }
        }
        
        Write-Host "  ✓ Processing required: $($decision.reason)" -ForegroundColor Green
        
        # Step 5: Start tracking
        Write-Host "[5/6] Starting agent invocation..." -ForegroundColor Yellow
        
        $invocationId = Start-AgentInvocation -TicketId $TicketId -Revision $revision -StateHash $stateHash -InvokedBy "Webhook"
        
        # Step 6: Invoke MOS Support Agent
        Write-Host "[6/6] Invoking MOS Support Agent..." -ForegroundColor Yellow
        Write-Host "--------------------------------------" -ForegroundColor Gray
        
        # Call the agent (this would be your actual agent invocation)
        # For now, we'll simulate with a direct call
        $agentResult = Invoke-MOSupportAgent -TicketId $TicketId
        
        Write-Host "--------------------------------------" -ForegroundColor Gray
        
        if ($agentResult.success) {
            Complete-AgentInvocation `
                -TicketId $TicketId `
                -InvocationId $invocationId `
                -Status "Completed" `
                -ReportFile $agentResult.reportFile
            
            Write-Host "`n✓ SUCCESS: Agent completed processing" -ForegroundColor Green
            Write-Host "  Report: $($agentResult.reportFile)" -ForegroundColor Cyan
            
            return @{
                processed = $true
                success = $true
                invocationId = $invocationId
                reportFile = $agentResult.reportFile
            }
        } else {
            Complete-AgentInvocation `
                -TicketId $TicketId `
                -InvocationId $invocationId `
                -Status "Failed" `
                -ErrorMessage $agentResult.error
            
            Write-Host "`n✗ FAILED: $($agentResult.error)" -ForegroundColor Red
            
            return @{
                processed = $true
                success = $false
                error = $agentResult.error
            }
        }
        
    } catch {
        Write-Host "`n✗ ERROR: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        
        if ($invocationId) {
            Complete-AgentInvocation `
                -TicketId $TicketId `
                -InvocationId $invocationId `
                -Status "Failed" `
                -ErrorMessage $_.Exception.Message
        }
        
        return @{
            processed = $false
            success = $false
            error = $_.Exception.Message
        }
    }
}

<#
.SYNOPSIS
Invoke the MOS Support Agent (actual implementation)

.PARAMETER TicketId
ADO ticket ID

.EXAMPLE
$result = Invoke-MOSupportAgent -TicketId 82117
#>
function Invoke-MOSupportAgent {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TicketId
    )
    
    try {
        # This is where you'd integrate with your actual agent
        # For example, using GitHub Copilot CLI or API
        
        Write-Host "Processing ticket #$TicketId with MOS Support Agent..." -ForegroundColor Cyan
        
        # Example: You could invoke via GitHub Copilot Chat API
        # or run a script that triggers the agent
        
        # For demonstration, let's assume success
        $reportFile = "Output\Ticket_$TicketId`_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
        
        # Simulate agent work (replace with actual agent call)
        Start-Sleep -Seconds 2
        
        return @{
            success = $true
            reportFile = $reportFile
        }
        
    } catch {
        return @{
            success = $false
            error = $_.Exception.Message
        }
    }
}

<#
.SYNOPSIS
Check ticket comments for reprocess triggers

.PARAMETER TicketId
ADO ticket ID

.EXAMPLE
$shouldReprocess = Test-ReprocessTriggerInComments -TicketId 82117
#>
function Test-ReprocessTriggerInComments {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TicketId
    )
    
    $ticket = az boards work-item show --id $TicketId --org https://siepe.visualstudio.com/ --output json | ConvertFrom-Json
    $lastComment = $ticket.fields.'System.History'
    
    # Check for trigger keywords
    $triggers = @(
        '@MOS-Agent reprocess',
        'please re-investigate',
        'additional information',
        'new details',
        'rerun agent'
    )
    
    foreach ($trigger in $triggers) {
        if ($lastComment -match [regex]::Escape($trigger)) {
            return $true
        }
    }
    
    # Check for reprocess tag
    $tags = $ticket.fields.'System.Tags'
    if ($tags -match 'reprocess-agent') {
        return $true
    }
    
    return $false
}

# Example Usage:
# Invoke-MOSAgentWebhook -TicketId 82117
# Invoke-MOSAgentWebhook -TicketId 82117 -ForceReprocess

# Export functions
Export-ModuleMember -Function @(
    'Invoke-MOSAgentWebhook',
    'Invoke-MOSupportAgent',
    'Test-ReprocessTriggerInComments'
)
