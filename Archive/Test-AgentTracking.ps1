# Test/Demo Script for Agent Invocation Tracking
# This demonstrates the tracking system in action

# Import modules
Import-Module "$PSScriptRoot\AgentInvocationTracking.psm1" -Force
Import-Module "$PSScriptRoot\MOSAgentWebhookHandler.ps1" -Force

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MOS Agent Invocation Tracking Demo" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Example 1: First invocation of a ticket
Write-Host "`n--- Example 1: First Invocation ---" -ForegroundColor Yellow
Write-Host "Simulating webhook for ticket #82117 (first time)..."
$result1 = Invoke-MOSAgentWebhook -TicketId 82117
Write-Host "Result: Processed = $($result1.processed), Success = $($result1.success)" -ForegroundColor Cyan

# Example 2: Duplicate invocation (same state)
Write-Host "`n--- Example 2: Duplicate Invocation (No Changes) ---" -ForegroundColor Yellow
Write-Host "Simulating webhook for ticket #82117 again (no changes)..."
$result2 = Invoke-MOSAgentWebhook -TicketId 82117
Write-Host "Result: Processed = $($result2.processed), Reason = $($result2.reason)" -ForegroundColor Cyan

# Example 3: Force reprocess
Write-Host "`n--- Example 3: Force Reprocess ---" -ForegroundColor Yellow
Write-Host "Setting force reprocess flag..."
Set-ForceReprocess -TicketId 82117

Write-Host "Simulating webhook with force reprocess..."
$result3 = Invoke-MOSAgentWebhook -TicketId 82117
Write-Host "Result: Processed = $($result3.processed), Success = $($result3.success)" -ForegroundColor Cyan

# Example 4: View ticket history
Write-Host "`n--- Example 4: Ticket History ---" -ForegroundColor Yellow
$history = Get-TicketInvocationHistory -TicketId 82117
Write-Host "Ticket #82117 History:" -ForegroundColor Cyan
Write-Host "  Last Processed Revision: $($history.lastProcessedRevision)" -ForegroundColor White
Write-Host "  Last Processed At: $($history.lastProcessedAt)" -ForegroundColor White
Write-Host "  Total Invocations: $($history.invocations.Count)" -ForegroundColor White

Write-Host "`n  Invocation Details:" -ForegroundColor White
foreach ($inv in $history.invocations) {
    $statusColor = switch ($inv.status) {
        "Completed" { "Green" }
        "Failed" { "Red" }
        "Skipped" { "Yellow" }
        default { "White" }
    }
    Write-Host "    - Rev $($inv.revision): $($inv.status) at $($inv.invokedAt) by $($inv.invokedBy)" -ForegroundColor $statusColor
}

# Example 5: Overall statistics
Write-Host "`n--- Example 5: Overall Statistics ---" -ForegroundColor Yellow
$stats = Get-InvocationStatistics
Write-Host "Agent Invocation Statistics:" -ForegroundColor Cyan
Write-Host "  Total Tickets: $($stats.totalTickets)" -ForegroundColor White
Write-Host "  Total Invocations: $($stats.totalInvocations)" -ForegroundColor White
Write-Host "  Completed: $($stats.completed)" -ForegroundColor Green
Write-Host "  Failed: $($stats.failed)" -ForegroundColor Red
Write-Host "  Skipped: $($stats.skipped)" -ForegroundColor Yellow
Write-Host "  Processing: $($stats.processing)" -ForegroundColor Cyan

# Example 6: Manual ticket processing
Write-Host "`n--- Example 6: Testing Another Ticket ---" -ForegroundColor Yellow
Write-Host "Simulating webhook for ticket #82309..."
$result6 = Invoke-MOSAgentWebhook -TicketId 82309

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Demo Complete!" -ForegroundColor Cyan
Write-Host "Check agent-invocations.json for full log" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
