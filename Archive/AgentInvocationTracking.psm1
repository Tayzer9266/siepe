# MOS Agent Invocation Tracking Module
# Purpose: Track agent invocations to prevent duplicate processing and detect meaningful changes

$script:InvocationLogPath = "$PSScriptRoot\agent-invocations.json"

<#
.SYNOPSIS
Calculate a state hash for a ticket to detect meaningful changes

.PARAMETER TicketData
Hashtable containing ticket fields from ADO

.EXAMPLE
$hash = Get-TicketStateHash -TicketData $ticket
#>
function Get-TicketStateHash {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$TicketData
    )
    
    # Select only fields that indicate meaningful work changes
    $relevantFields = @{
        description = $TicketData.description
        lastCommentText = $TicketData.lastCommentText
        lastCommentDate = $TicketData.lastCommentDate
        attachmentCount = $TicketData.attachmentCount
        tags = $TicketData.tags
    }
    
    # Convert to JSON and hash
    $json = $relevantFields | ConvertTo-Json -Compress -Depth 5
    $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($json))
    $hash = [System.BitConverter]::ToString($hashBytes) -replace '-', ''
    
    return $hash
}

<#
.SYNOPSIS
Load the invocation log from JSON file

.EXAMPLE
$log = Get-InvocationLog
#>
function Get-InvocationLog {
    if (-not (Test-Path $script:InvocationLogPath)) {
        # Create initial log structure
        $initialLog = @{
            version = "1.0"
            lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
            tickets = @{}
        }
        $initialLog | ConvertTo-Json -Depth 10 | Set-Content $script:InvocationLogPath -Encoding UTF8
        return $initialLog
    }
    
    $json = Get-Content $script:InvocationLogPath -Raw -Encoding UTF8
    return $json | ConvertFrom-Json
}

<#
.SYNOPSIS
Save the invocation log to JSON file

.PARAMETER Log
The log object to save

.EXAMPLE
Save-InvocationLog -Log $log
#>
function Save-InvocationLog {
    param(
        [Parameter(Mandatory=$true)]
        $Log
    )
    
    $Log.lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
    $Log | ConvertTo-Json -Depth 10 | Set-Content $script:InvocationLogPath -Encoding UTF8
}

<#
.SYNOPSIS
Check if a ticket should be processed based on changes

.PARAMETER TicketId
ADO ticket ID

.PARAMETER Revision
Current ADO revision number

.PARAMETER StateHash
Hash of current ticket state

.PARAMETER ForceReprocess
Force reprocessing even if no changes detected

.EXAMPLE
$decision = Test-ShouldProcessTicket -TicketId 82117 -Revision 15 -StateHash "abc123..."
if ($decision.shouldProcess) {
    # Invoke agent
}
#>
function Test-ShouldProcessTicket {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TicketId,
        
        [Parameter(Mandatory=$true)]
        [int]$Revision,
        
        [Parameter(Mandatory=$true)]
        [string]$StateHash,
        
        [switch]$ForceReprocess
    )
    
    $log = Get-InvocationLog
    $ticketIdStr = $TicketId.ToString()
    
    # Case 1: Never processed before
    if (-not $log.tickets.$ticketIdStr) {
        return @{
            shouldProcess = $true
            reason = "First invocation - ticket never processed"
            isFirstRun = $true
        }
    }
    
    $ticketLog = $log.tickets.$ticketIdStr
    
    # Case 2: Force reprocess flag
    if ($ForceReprocess -or $ticketLog.forceReprocess) {
        return @{
            shouldProcess = $true
            reason = "Force reprocess requested"
            isFirstRun = $false
        }
    }
    
    # Case 3: Check for failed previous attempts
    $lastInvocation = $ticketLog.invocations[-1]
    if ($lastInvocation.status -eq "Failed") {
        return @{
            shouldProcess = $true
            reason = "Retry after previous failure"
            isFirstRun = $false
        }
    }
    
    # Case 4: Revision changed
    if ($Revision -gt $ticketLog.lastProcessedRevision) {
        # Check if meaningful change occurred
        if ($StateHash -ne $ticketLog.lastStateHash) {
            return @{
                shouldProcess = $true
                reason = "New changes detected (rev $Revision, hash changed)"
                isFirstRun = $false
            }
        } else {
            return @{
                shouldProcess = $false
                reason = "Revision changed but no meaningful updates (rev $Revision)"
                isFirstRun = $false
            }
        }
    }
    
    # Case 5: Already processed, no changes
    return @{
        shouldProcess = $false
        reason = "Already processed at rev $($ticketLog.lastProcessedRevision) with same state"
        isFirstRun = $false
    }
}

<#
.SYNOPSIS
Log the start of an agent invocation

.PARAMETER TicketId
ADO ticket ID

.PARAMETER Revision
ADO revision number

.PARAMETER StateHash
Hash of ticket state

.PARAMETER InvokedBy
Source of invocation (Webhook, Manual, Scheduled)

.EXAMPLE
$invocationId = Start-AgentInvocation -TicketId 82117 -Revision 15 -StateHash "abc..." -InvokedBy "Webhook"
#>
function Start-AgentInvocation {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TicketId,
        
        [Parameter(Mandatory=$true)]
        [int]$Revision,
        
        [Parameter(Mandatory=$true)]
        [string]$StateHash,
        
        [Parameter(Mandatory=$false)]
        [string]$InvokedBy = "Manual"
    )
    
    $log = Get-InvocationLog
    $ticketIdStr = $TicketId.ToString()
    
    # Initialize ticket entry if doesn't exist
    if (-not $log.tickets.$ticketIdStr) {
        $log.tickets | Add-Member -NotePropertyName $ticketIdStr -NotePropertyValue ([PSCustomObject]@{
            ticketId = $TicketId
            lastProcessedRevision = 0
            lastStateHash = ""
            lastProcessedAt = $null
            forceReprocess = $false
            invocations = @()
        })
    }
    
    # Create invocation entry
    $invocationId = (New-Guid).ToString()
    $invocation = [PSCustomObject]@{
        invocationId = $invocationId
        revision = $Revision
        stateHash = $StateHash
        invokedAt = (Get-Date).ToUniversalTime().ToString("o")
        invokedBy = $InvokedBy
        status = "Processing"
        completedAt = $null
        reportFile = $null
        error = $null
    }
    
    $log.tickets.$ticketIdStr.invocations += $invocation
    
    Save-InvocationLog -Log $log
    
    Write-Host "Started invocation $invocationId for ticket $TicketId (rev $Revision)" -ForegroundColor Cyan
    
    return $invocationId
}

<#
.SYNOPSIS
Update an agent invocation with completion status

.PARAMETER TicketId
ADO ticket ID

.PARAMETER InvocationId
Invocation ID returned from Start-AgentInvocation

.PARAMETER Status
Status: Processing, Completed, Failed, Skipped

.PARAMETER ReportFile
Path to generated report file

.PARAMETER ErrorMessage
Error message if failed

.EXAMPLE
Complete-AgentInvocation -TicketId 82117 -InvocationId $id -Status "Completed" -ReportFile "report.md"
#>
function Complete-AgentInvocation {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TicketId,
        
        [Parameter(Mandatory=$true)]
        [string]$InvocationId,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Processing", "Completed", "Failed", "Skipped")]
        [string]$Status,
        
        [Parameter(Mandatory=$false)]
        [string]$ReportFile,
        
        [Parameter(Mandatory=$false)]
        [string]$ErrorMessage
    )
    
    $log = Get-InvocationLog
    $ticketIdStr = $TicketId.ToString()
    
    if (-not $log.tickets.$ticketIdStr) {
        Write-Error "Ticket $TicketId not found in invocation log"
        return
    }
    
    # Find the invocation
    $invocation = $log.tickets.$ticketIdStr.invocations | Where-Object { $_.invocationId -eq $InvocationId }
    
    if (-not $invocation) {
        Write-Error "Invocation $InvocationId not found for ticket $TicketId"
        return
    }
    
    # Update invocation
    $invocation.status = $Status
    $invocation.completedAt = (Get-Date).ToUniversalTime().ToString("o")
    
    if ($ReportFile) {
        $invocation.reportFile = $ReportFile
    }
    
    if ($ErrorMessage) {
        $invocation.error = $ErrorMessage
    }
    
    # Update ticket-level tracking if completed successfully
    if ($Status -eq "Completed") {
        $log.tickets.$ticketIdStr.lastProcessedRevision = $invocation.revision
        $log.tickets.$ticketIdStr.lastStateHash = $invocation.stateHash
        $log.tickets.$ticketIdStr.lastProcessedAt = $invocation.completedAt
        $log.tickets.$ticketIdStr.forceReprocess = $false
    }
    
    Save-InvocationLog -Log $log
    
    $color = switch ($Status) {
        "Completed" { "Green" }
        "Failed" { "Red" }
        "Skipped" { "Yellow" }
        default { "White" }
    }
    
    Write-Host "Invocation $InvocationId for ticket $TicketId: $Status" -ForegroundColor $color
}

<#
.SYNOPSIS
Set force reprocess flag for a ticket

.PARAMETER TicketId
ADO ticket ID

.EXAMPLE
Set-ForceReprocess -TicketId 82117
#>
function Set-ForceReprocess {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TicketId
    )
    
    $log = Get-InvocationLog
    $ticketIdStr = $TicketId.ToString()
    
    if ($log.tickets.$ticketIdStr) {
        $log.tickets.$ticketIdStr.forceReprocess = $true
        Save-InvocationLog -Log $log
        Write-Host "Force reprocess flag set for ticket $TicketId" -ForegroundColor Yellow
    } else {
        Write-Warning "Ticket $TicketId not found in log. It will be processed on next invocation anyway."
    }
}

<#
.SYNOPSIS
Get invocation history for a ticket

.PARAMETER TicketId
ADO ticket ID

.EXAMPLE
Get-TicketInvocationHistory -TicketId 82117
#>
function Get-TicketInvocationHistory {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TicketId
    )
    
    $log = Get-InvocationLog
    $ticketIdStr = $TicketId.ToString()
    
    if (-not $log.tickets.$ticketIdStr) {
        Write-Host "No invocation history for ticket $TicketId" -ForegroundColor Yellow
        return $null
    }
    
    return $log.tickets.$ticketIdStr
}

<#
.SYNOPSIS
Get summary statistics of agent invocations

.EXAMPLE
Get-InvocationStatistics
#>
function Get-InvocationStatistics {
    $log = Get-InvocationLog
    
    $stats = @{
        totalTickets = 0
        totalInvocations = 0
        completed = 0
        failed = 0
        processing = 0
        skipped = 0
    }
    
    foreach ($ticketId in $log.tickets.PSObject.Properties.Name) {
        $stats.totalTickets++
        $ticket = $log.tickets.$ticketId
        
        foreach ($invocation in $ticket.invocations) {
            $stats.totalInvocations++
            
            switch ($invocation.status) {
                "Completed" { $stats.completed++ }
                "Failed" { $stats.failed++ }
                "Processing" { $stats.processing++ }
                "Skipped" { $stats.skipped++ }
            }
        }
    }
    
    return [PSCustomObject]$stats
}

# Export functions
Export-ModuleMember -Function @(
    'Get-TicketStateHash',
    'Test-ShouldProcessTicket',
    'Start-AgentInvocation',
    'Complete-AgentInvocation',
    'Set-ForceReprocess',
    'Get-TicketInvocationHistory',
    'Get-InvocationStatistics'
)
