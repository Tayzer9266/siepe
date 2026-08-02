# ============================================
# Invoke-ClaudeAPI.psm1
# Helper module for calling Claude API from PowerShell
# ============================================

<#
.SYNOPSIS
    Calls the Claude API with a user prompt and returns the response.

.DESCRIPTION
    This module provides a simple interface to call the Anthropic Claude API
    from PowerShell scripts. It handles authentication, request formatting,
    and response parsing.

.PARAMETER Prompt
    The user message/prompt to send to Claude

.PARAMETER SystemPrompt
    Optional system prompt to set Claude's behavior

.PARAMETER Model
    Claude model to use (default: claude-sonnet-4-20250514)

.PARAMETER MaxTokens
    Maximum tokens in response (default: 4096)

.PARAMETER APIKey
    Anthropic API key (if not provided, reads from environment variable)

.EXAMPLE"C:\Users\tcnguyen\Desktop\secret_key.txt"
    $response = Invoke-ClaudeAPI -Prompt "Analyze this SQL error: timeout"
    Write-Host $response

.EXAMPLE
    $response = Invoke-ClaudeAPI -Prompt "Investigate ticket" -SystemPrompt "You are a SQL database expert"
#>
"C:\Users\tcnguyen\Desktop\secret_key.txt"
function Invoke-ClaudeAPI {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [Parameter(Mandatory=$false)]
        [string]$SystemPrompt = "You are Mossy, an expert MOS back office database support agent. Analyze issues thoroughly and provide actionable investigation steps.",

        [Parameter(Mandatory=$false)]
        [string]$Model = "claude-3-5-sonnet-20241022",

        [Parameter(Mandatory=$false)]
        [int]$MaxTokens = 4096,

        [Parameter(Mandatory=$false)]
        [string]$APIKey
    )

    # Get API key from parameter or environment variable
    if (-not $APIKey) {
        $APIKey = $env:ANTHROPIC_API_KEY
    }

    if (-not $APIKey) {
        throw "API key not provided and ANTHROPIC_API_KEY environment variable not set. Please set the API key."
    }

    # Build request headers
    $headers = @{
        "x-api-key" = $APIKey
        "anthropic-version" = "2023-06-01"
        "content-type" = "application/json"
    }

    # Build request body
    $body = @{
        model = $Model
        max_tokens = $MaxTokens
        messages = @(
            @{
                role = "user"
                content = $Prompt
            }
        )
    }

    # Add system prompt if provided
    if ($SystemPrompt) {
        $body.system = $SystemPrompt
    }

    # Convert to JSON
    $jsonBody = $body | ConvertTo-Json -Depth 10

    Write-Verbose "Calling Claude API with model: $Model"
    Write-Verbose "Prompt length: $($Prompt.Length) characters"

    try {
        # Call Claude API
        $response = Invoke-RestMethod -Uri "https://api.anthropic.com/v1/messages" `
            -Method Post `
            -Headers $headers `
            -Body $jsonBody `
            -ErrorAction Stop

        # Extract text response
        $textResponse = $response.content[0].text

        Write-Verbose "Response received: $($textResponse.Length) characters"

        return $textResponse
    }
    catch {
        Write-Error "Claude API call failed: $($_.Exception.Message)"
        
        # Try to extract more details from response
        if ($_.ErrorDetails.Message) {
            $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($errorDetails.error) {
                Write-Error "API Error: $($errorDetails.error.type) - $($errorDetails.error.message)"
            }
        }
        
        throw
    }
}

# Export the function
Export-ModuleMember -Function Invoke-ClaudeAPI
