# Azure DevOps Webhook Setup Guide

## Overview

Azure DevOps **Service Hooks** enable you to trigger automated actions when work items (tasks, bugs, user stories) are created or updated. This guide shows how to configure webhooks to invoke the MOS Support Agent or other automation when DevOps tickets are opened.

**Use Cases:**
- Auto-assign MOS Support Agent when ticket matches specific criteria
- Trigger notifications to Slack/Teams
- Start automated diagnostics workflows
- Create linked work items in other systems
- Log ticket events to external monitoring

---

## Prerequisites

### Permissions Required

To create Service Hooks in Azure DevOps, you need:

- **Project Administrator** role, OR
- **Project Collection Administrator** role, OR
- **Custom permission:** `Edit subscriptions` enabled

**Check Your Permissions:**
1. Navigate to your Azure DevOps project
2. Click **Project Settings** (bottom left)
3. Click **Permissions** under General
4. Verify you're in a group with `Edit subscriptions` permission

### Endpoint Requirements

Your webhook endpoint must:
- Be **publicly accessible** via HTTPS (or use Azure DevOps self-hosted agent)
- Accept **POST requests** with JSON payload
- Return **HTTP 200** within 10 seconds (Azure DevOps timeout)
- Handle authentication (API key, shared secret, or OAuth)

---

## Method 1: Setup via Azure DevOps Web UI

### Step 1: Navigate to Service Hooks

1. Open your Azure DevOps organization: `https://dev.azure.com/{YourOrganization}`
2. Select your **Project** (e.g., "MOS Backoffice")
3. Click **Project Settings** (gear icon, bottom left)
4. Under **General**, click **Service Hooks**
5. Click **+ Create subscription**

### Step 2: Select Trigger Type

Choose the event that triggers your webhook:

**For New Tickets:**
- Select **Web Hooks** as the service
- Click **Next**
- Choose trigger: **Work item created**

**For Ticket Updates:**
- Select **Web Hooks** as the service
- Click **Next**
- Choose trigger: **Work item updated**

**For Comments:**
- Select **Web Hooks** as the service
- Click **Next**
- Choose trigger: **Work item commented on**

### Step 3: Configure Trigger Filters

Apply filters to only trigger on specific work items:

#### Filter by Work Item Type
- **Work item type:** `Task` or `Bug` (or leave blank for all types)

#### Filter by Area Path
- **Area path:** `\MOS Backoffice\Support` (targets specific team area)
- **Under path:** Check this box to include sub-areas

#### Filter by Tags
- **Contains tag:** `mos-support` or `auto-diagnose`
- Multiple tags: Use comma separation

#### Filter by Assigned To
- **Assigned to:** Specific user or team
- **[Any]** - Triggers for all assignments

#### Filter by State Changes
- **State:** `New`, `Active`, `Resolved`
- **Old state:** Use for state transitions (e.g., New → Active)

#### Filter by Fields
- **Field:** `Title`, `Description`, `Custom Field`
- **Operator:** Contains, Equals, Not Equals
- **Value:** Keyword to match (e.g., "pricing error", "position missing")

**Example Filter Configuration:**
```
Trigger: Work item created
Work item type: Bug OR Task
Area path: \MOS Backoffice\Support
Tags: contains "mos-support"
Title: contains "pricing" OR "position" OR "trade"
```

Click **Next** after configuring filters.

### Step 4: Configure Webhook Action

Enter your webhook endpoint details:

#### URL
```
https://your-endpoint.azurewebsites.net/api/devops/webhook
```
- Must be **HTTPS** for production
- Can use **ngrok** for local testing: `https://abc123.ngrok.io/webhook`

#### HTTP Headers (Optional)
Add authentication or metadata headers:

| Header Name | Value | Purpose |
|-------------|-------|---------|
| `Authorization` | `Bearer <your-api-key>` | API authentication |
| `X-Webhook-Secret` | `<shared-secret>` | Signature verification |
| `Content-Type` | `application/json` | Usually auto-set |
| `X-Source` | `AzureDevOps-MOS` | Identify webhook source |

**Example:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
X-Webhook-Secret: mos-webhook-secret-2026
```

#### HTTP Parameters (Optional)
Add query string parameters:

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `source` | `ado` | Identify source system |
| `project` | `MOS` | Project identifier |
| `environment` | `production` | Environment tag |

**Example URL with Parameters:**
```
https://your-endpoint.net/api/webhook?source=ado&project=MOS&environment=prod
```

#### Messages to Send
Choose what data to include in webhook payload:

- **Detailed messages to send:** Recommended (includes full work item details)
- **Summary messages to send:** Minimal payload (work item ID only)

Select **Detailed** for MOS Support Agent integration.

#### Resource Version
- **Latest (5.1):** Recommended - includes all fields
- **5.0, 4.1, etc.:** Use if endpoint expects older schema

### Step 5: Test the Webhook

1. Click **Test** button
2. Azure DevOps sends a sample payload to your endpoint
3. Verify your endpoint returns **HTTP 200**
4. Check response time (should be < 10 seconds)

**Sample Test Output:**
```
✓ Request sent successfully
✓ Response: HTTP 200 OK
✓ Duration: 1.2 seconds
```

If test fails:
- Check endpoint URL is correct and accessible
- Verify endpoint accepts POST requests
- Check firewall/network security rules
- Review endpoint logs for errors

### Step 6: Finish and Activate

1. Click **Finish**
2. Webhook subscription is now **active**
3. Listed in Service Hooks with status **Enabled**

---

## Method 2: Setup via Azure DevOps REST API

For automated provisioning or multiple subscriptions, use the REST API.

### Prerequisites
- **Personal Access Token (PAT)** with `Service Hooks (Read & Write)` scope
- REST client (PowerShell, cURL, Postman)

### Generate Personal Access Token

1. Click your **profile picture** (top right)
2. Select **Personal access tokens**
3. Click **+ New Token**
4. Set **Name:** "Service Hooks API"
5. Set **Organization:** Your Azure DevOps org
6. Set **Expiration:** Custom (90 days, 1 year, etc.)
7. Set **Scopes:** Custom defined
8. Check **Service Hooks:** Read & write
9. Click **Create**
10. **Copy token immediately** (won't be shown again)

### PowerShell: Create Webhook Subscription

```powershell
# Configuration
$Organization = "your-org-name"
$Project = "MOS Backoffice"
$PAT = "your-personal-access-token"

# Webhook configuration
$WebhookUrl = "https://your-endpoint.azurewebsites.net/api/devops/webhook"
$SharedSecret = "mos-webhook-secret-2026"

# Create subscription payload
$body = @{
    publisherId = "tfs"
    eventType = "workitem.created"
    resourceVersion = "5.1"
    consumerId = "webHooks"
    consumerActionId = "httpRequest"
    publisherInputs = @{
        workItemType = "Bug"
        areaPath = "\MOS Backoffice\Support"
        tag = "mos-support"
    }
    consumerInputs = @{
        url = $WebhookUrl
        httpHeaders = "Authorization: Bearer $SharedSecret"
        detailedMessagesToSend = "all"
        messagesToSend = "all"
        resourceDetailsToSend = "all"
    }
} | ConvertTo-Json -Depth 10

# Create Basic Auth header from PAT
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$PAT"))
$headers = @{
    Authorization = "Basic $base64AuthInfo"
    "Content-Type" = "application/json"
}

# Create subscription
$uri = "https://dev.azure.com/$Organization/_apis/hooks/subscriptions?api-version=7.1-preview.1"
$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body

Write-Host "Subscription created successfully!"
Write-Host "Subscription ID: $($response.id)"
Write-Host "Status: $($response.status)"
```

### cURL: Create Webhook Subscription

```bash
#!/bin/bash

# Configuration
ORGANIZATION="your-org-name"
PROJECT="MOS Backoffice"
PAT="your-personal-access-token"
WEBHOOK_URL="https://your-endpoint.azurewebsites.net/api/devops/webhook"

# Create subscription
curl -X POST \
  "https://dev.azure.com/$ORGANIZATION/_apis/hooks/subscriptions?api-version=7.1-preview.1" \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $(echo -n ":$PAT" | base64)" \
  -d '{
    "publisherId": "tfs",
    "eventType": "workitem.created",
    "resourceVersion": "5.1",
    "consumerId": "webHooks",
    "consumerActionId": "httpRequest",
    "publisherInputs": {
        "workItemType": "Bug",
        "areaPath": "\\MOS Backoffice\\Support",
        "tag": "mos-support"
    },
    "consumerInputs": {
        "url": "'$WEBHOOK_URL'",
        "httpHeaders": "Authorization: Bearer mos-webhook-secret-2026",
        "detailedMessagesToSend": "all",
        "messagesToSend": "all",
        "resourceDetailsToSend": "all"
    }
}'
```

---

## Webhook Payload Structure

When Azure DevOps triggers your webhook, it sends a POST request with this JSON structure:

### Work Item Created Event

```json
{
  "subscriptionId": "12345678-1234-1234-1234-123456789012",
  "notificationId": 1,
  "id": "98765432-abcd-efgh-1234-567890abcdef",
  "eventType": "workitem.created",
  "publisherId": "tfs",
  "message": {
    "text": "Bug #82309 (New pricing exception for Sycamore Tree CLO IX) created by John Doe",
    "html": "<a href=\"...\">Bug #82309</a> (New pricing exception...) created by John Doe",
    "markdown": "[Bug #82309](https://...) (New pricing exception...) created by John Doe"
  },
  "detailedMessage": {
    "text": "Bug #82309 (New pricing exception for Sycamore Tree CLO IX) created by John Doe.\r\n...",
    "html": "...",
    "markdown": "..."
  },
  "resource": {
    "id": 82309,
    "rev": 1,
    "fields": {
      "System.AreaPath": "MOS Backoffice\\Support",
      "System.TeamProject": "MOS Backoffice",
      "System.IterationPath": "MOS Backoffice\\Sprint 42",
      "System.WorkItemType": "Bug",
      "System.State": "New",
      "System.Reason": "New defect reported",
      "System.CreatedDate": "2026-07-06T10:30:00.000Z",
      "System.CreatedBy": {
        "displayName": "John Doe",
        "uniqueName": "john.doe@company.com",
        "id": "abc123-def456-...",
        "imageUrl": "https://..."
      },
      "System.ChangedDate": "2026-07-06T10:30:00.000Z",
      "System.ChangedBy": { "..." },
      "System.Title": "New pricing exception for Sycamore Tree CLO IX",
      "System.Description": "<div>Portfolio shows incorrect market price for CUSIP 12345ABC. Expected: 98.5, Actual: 87.2. Date: 2026-07-05.</div>",
      "System.Tags": "pricing; mos-support; urgent",
      "Microsoft.VSTS.Common.Priority": 2,
      "Microsoft.VSTS.Common.Severity": "2 - High"
    },
    "url": "https://dev.azure.com/your-org/_apis/wit/workItems/82309"
  },
  "resourceVersion": "5.1",
  "resourceContainers": {
    "collection": {
      "id": "abc123...",
      "baseUrl": "https://dev.azure.com/your-org/"
    },
    "account": {
      "id": "xyz789...",
      "baseUrl": "https://dev.azure.com/your-org/"
    },
    "project": {
      "id": "proj123...",
      "baseUrl": "https://dev.azure.com/your-org/"
    }
  },
  "createdDate": "2026-07-06T10:30:01.234Z"
}
```

### Work Item Updated Event

```json
{
  "subscriptionId": "12345678-1234-1234-1234-123456789012",
  "eventType": "workitem.updated",
  "resource": {
    "id": 82309,
    "rev": 2,
    "fields": {
      "System.State": "Active",
      "System.AssignedTo": {
        "displayName": "MOS Support Bot",
        "uniqueName": "support.bot@company.com"
      }
    },
    "revisedBy": {
      "displayName": "John Doe",
      "uniqueName": "john.doe@company.com"
    },
    "revisedDate": "2026-07-06T10:35:00.000Z"
  }
}
```

---

## Example Webhook Endpoint Implementation

### ASP.NET Core C# Example

```csharp
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

[ApiController]
[Route("api/devops")]
public class DevOpsWebhookController : ControllerBase
{
    private readonly ILogger<DevOpsWebhookController> _logger;
    private readonly IMOSSupportAgent _supportAgent;
    private readonly string _webhookSecret = "mos-webhook-secret-2026";

    public DevOpsWebhookController(
        ILogger<DevOpsWebhookController> logger,
        IMOSSupportAgent supportAgent)
    {
        _logger = logger;
        _supportAgent = supportAgent;
    }

    [HttpPost("webhook")]
    public async Task<IActionResult> HandleWebhook([FromBody] JsonElement payload)
    {
        try
        {
            // Verify webhook secret
            if (!Request.Headers.TryGetValue("X-Webhook-Secret", out var secret) 
                || secret != _webhookSecret)
            {
                _logger.LogWarning("Unauthorized webhook attempt");
                return Unauthorized("Invalid webhook secret");
            }

            // Parse event type
            var eventType = payload.GetProperty("eventType").GetString();
            _logger.LogInformation($"Received webhook event: {eventType}");

            // Extract work item details
            var resource = payload.GetProperty("resource");
            var workItemId = resource.GetProperty("id").GetInt32();
            var fields = resource.GetProperty("fields");
            
            var title = fields.GetProperty("System.Title").GetString();
            var description = fields.GetProperty("System.Description").GetString();
            var workItemType = fields.GetProperty("System.WorkItemType").GetString();
            var tags = fields.GetProperty("System.Tags").GetString();
            var state = fields.GetProperty("System.State").GetString();

            // Check if MOS Support Agent should be invoked
            if (ShouldInvokeMOSAgent(title, description, tags, workItemType))
            {
                _logger.LogInformation($"Invoking MOS Support Agent for work item {workItemId}");
                
                // Invoke MOS Support Agent
                var agentResult = await _supportAgent.InvestigateAsync(new TicketContext
                {
                    WorkItemId = workItemId,
                    Title = title,
                    Description = description,
                    Tags = tags?.Split(';').Select(t => t.Trim()).ToArray()
                });

                // Post agent findings as comment on work item
                await PostCommentToWorkItem(workItemId, agentResult.Findings);
                
                // Auto-assign if high confidence
                if (agentResult.Confidence > 0.8)
                {
                    await AssignWorkItem(workItemId, "MOS Support Team");
                }

                return Ok(new { status = "processed", agentInvoked = true });
            }

            return Ok(new { status = "processed", agentInvoked = false });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing webhook");
            return StatusCode(500, new { error = "Internal server error" });
        }
    }

    private bool ShouldInvokeMOSAgent(string title, string description, string tags, string workItemType)
    {
        // Check for MOS-related keywords
        var keywords = new[] { "pricing", "position", "trade", "cash", "reconciliation", "SSIS" };
        var text = $"{title} {description} {tags}".ToLower();
        
        return keywords.Any(k => text.Contains(k)) 
            && (workItemType == "Bug" || workItemType == "Task")
            && tags?.Contains("mos-support") == true;
    }

    private async Task PostCommentToWorkItem(int workItemId, string comment)
    {
        // Use Azure DevOps REST API to add comment
        // Implementation details...
    }

    private async Task AssignWorkItem(int workItemId, string assignTo)
    {
        // Use Azure DevOps REST API to update work item
        // Implementation details...
    }
}
```

### Node.js Express Example

```javascript
const express = require('express');
const app = express();
app.use(express.json());

const WEBHOOK_SECRET = 'mos-webhook-secret-2026';

app.post('/api/devops/webhook', async (req, res) => {
    try {
        // Verify webhook secret
        const secret = req.headers['x-webhook-secret'];
        if (secret !== WEBHOOK_SECRET) {
            console.warn('Unauthorized webhook attempt');
            return res.status(401).json({ error: 'Invalid webhook secret' });
        }

        const payload = req.body;
        const eventType = payload.eventType;
        
        console.log(`Received webhook event: ${eventType}`);

        // Extract work item details
        const resource = payload.resource;
        const workItemId = resource.id;
        const fields = resource.fields;
        
        const title = fields['System.Title'];
        const description = fields['System.Description'];
        const workItemType = fields['System.WorkItemType'];
        const tags = fields['System.Tags'];
        const state = fields['System.State'];

        // Check if MOS Support Agent should be invoked
        if (shouldInvokeMOSAgent(title, description, tags, workItemType)) {
            console.log(`Invoking MOS Support Agent for work item ${workItemId}`);
            
            // Invoke MOS Support Agent
            const agentResult = await invokeMOSSupportAgent({
                workItemId,
                title,
                description,
                tags: tags ? tags.split(';').map(t => t.trim()) : []
            });

            // Post agent findings as comment
            await postCommentToWorkItem(workItemId, agentResult.findings);
            
            // Auto-assign if high confidence
            if (agentResult.confidence > 0.8) {
                await assignWorkItem(workItemId, 'MOS Support Team');
            }

            return res.status(200).json({ 
                status: 'processed', 
                agentInvoked: true 
            });
        }

        res.status(200).json({ 
            status: 'processed', 
            agentInvoked: false 
        });

    } catch (error) {
        console.error('Error processing webhook:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

function shouldInvokeMOSAgent(title, description, tags, workItemType) {
    const keywords = ['pricing', 'position', 'trade', 'cash', 'reconciliation', 'SSIS'];
    const text = `${title} ${description} ${tags}`.toLowerCase();
    
    return keywords.some(k => text.includes(k))
        && (workItemType === 'Bug' || workItemType === 'Task')
        && tags?.includes('mos-support');
}

async function invokeMOSSupportAgent(context) {
    // Call MOS Support Agent API or message queue
    // Return agent investigation results
}

async function postCommentToWorkItem(workItemId, comment) {
    // Use Azure DevOps REST API to add comment
}

async function assignWorkItem(workItemId, assignTo) {
    // Use Azure DevOps REST API to update work item
}

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Webhook server listening on port ${PORT}`);
});
```

### Python Flask Example

```python
from flask import Flask, request, jsonify
import logging
import os

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

WEBHOOK_SECRET = os.getenv('WEBHOOK_SECRET', 'mos-webhook-secret-2026')

@app.route('/api/devops/webhook', methods=['POST'])
def handle_webhook():
    try:
        # Verify webhook secret
        secret = request.headers.get('X-Webhook-Secret')
        if secret != WEBHOOK_SECRET:
            logging.warning('Unauthorized webhook attempt')
            return jsonify({'error': 'Invalid webhook secret'}), 401

        payload = request.json
        event_type = payload.get('eventType')
        
        logging.info(f'Received webhook event: {event_type}')

        # Extract work item details
        resource = payload.get('resource', {})
        work_item_id = resource.get('id')
        fields = resource.get('fields', {})
        
        title = fields.get('System.Title')
        description = fields.get('System.Description')
        work_item_type = fields.get('System.WorkItemType')
        tags = fields.get('System.Tags', '')
        state = fields.get('System.State')

        # Check if MOS Support Agent should be invoked
        if should_invoke_mos_agent(title, description, tags, work_item_type):
            logging.info(f'Invoking MOS Support Agent for work item {work_item_id}')
            
            # Invoke MOS Support Agent
            agent_result = invoke_mos_support_agent({
                'work_item_id': work_item_id,
                'title': title,
                'description': description,
                'tags': [t.strip() for t in tags.split(';')] if tags else []
            })

            # Post agent findings as comment
            post_comment_to_work_item(work_item_id, agent_result['findings'])
            
            # Auto-assign if high confidence
            if agent_result['confidence'] > 0.8:
                assign_work_item(work_item_id, 'MOS Support Team')

            return jsonify({
                'status': 'processed',
                'agent_invoked': True
            }), 200

        return jsonify({
            'status': 'processed',
            'agent_invoked': False
        }), 200

    except Exception as e:
        logging.error(f'Error processing webhook: {str(e)}')
        return jsonify({'error': 'Internal server error'}), 500


def should_invoke_mos_agent(title, description, tags, work_item_type):
    keywords = ['pricing', 'position', 'trade', 'cash', 'reconciliation', 'SSIS']
    text = f'{title} {description} {tags}'.lower()
    
    return (any(k in text for k in keywords)
            and work_item_type in ['Bug', 'Task']
            and 'mos-support' in tags.lower())


def invoke_mos_support_agent(context):
    # Call MOS Support Agent API or message queue
    # Return agent investigation results
    pass


def post_comment_to_work_item(work_item_id, comment):
    # Use Azure DevOps REST API to add comment
    pass


def assign_work_item(work_item_id, assign_to):
    # Use Azure DevOps REST API to update work item
    pass


if __name__ == '__main__':
    port = int(os.getenv('PORT', 3000))
    app.run(host='0.0.0.0', port=port)
```

---

## Security Best Practices

### 1. Validate Webhook Authenticity

**Shared Secret Verification:**
```csharp
var expectedSecret = Configuration["Webhook:Secret"];
var receivedSecret = Request.Headers["X-Webhook-Secret"];

if (receivedSecret != expectedSecret)
{
    return Unauthorized("Invalid webhook secret");
}
```

**IP Whitelist (Azure DevOps IPs):**
```csharp
var allowedIPs = new[] { 
    "13.107.6.0/24",   // Azure DevOps service IPs
    "13.107.9.0/24",
    "13.107.42.0/24",
    "13.107.43.0/24"
};

var remoteIP = HttpContext.Connection.RemoteIpAddress;
if (!IsIPAllowed(remoteIP, allowedIPs))
{
    return Unauthorized("IP not whitelisted");
}
```

### 2. Use HTTPS Only

- **Never accept HTTP webhooks in production**
- Use valid SSL/TLS certificates
- Enforce TLS 1.2 or higher

### 3. Implement Rate Limiting

```csharp
[RateLimiting(Limit = 100, Period = "1m")]
public async Task<IActionResult> HandleWebhook([FromBody] JsonElement payload)
{
    // Implementation
}
```

### 4. Log All Webhook Activity

```csharp
_logger.LogInformation($"Webhook received: EventType={eventType}, WorkItemID={workItemId}, IP={remoteIP}");
```

### 5. Handle Secrets Securely

- Store secrets in **Azure Key Vault** or **environment variables**
- Never hardcode secrets in source code
- Rotate secrets regularly (every 90 days)

---

## Testing Webhooks

### Local Testing with ngrok

1. **Install ngrok:**
   ```bash
   choco install ngrok  # Windows
   brew install ngrok   # macOS
   ```

2. **Start your local webhook endpoint:**
   ```bash
   dotnet run  # or npm start, python app.py
   ```

3. **Expose local endpoint:**
   ```bash
   ngrok http 5000
   ```

4. **Use ngrok URL in Azure DevOps:**
   ```
   https://abc123.ngrok.io/api/devops/webhook
   ```

5. **Monitor requests:**
   - Open ngrok web UI: http://127.0.0.1:4040
   - View all webhook requests in real-time
   - Inspect headers, payload, response

### Manual Testing with Postman

1. **Import Azure DevOps sample payload** (see Webhook Payload Structure above)
2. **Set request method:** POST
3. **Set URL:** Your webhook endpoint
4. **Add headers:**
   ```
   Content-Type: application/json
   X-Webhook-Secret: mos-webhook-secret-2026
   ```
5. **Paste JSON payload in body**
6. **Send request**
7. **Verify 200 OK response**

---

## Monitoring & Troubleshooting

### Check Webhook Status in Azure DevOps

1. Go to **Project Settings** → **Service Hooks**
2. View list of subscriptions
3. Click subscription to view:
   - **History:** Last 100 delivery attempts
   - **Status:** Enabled/Disabled
   - **Success rate:** % of successful deliveries
   - **Last execution:** Timestamp and result

### View Delivery History

Click **History** tab to see:
- **Timestamp:** When webhook was triggered
- **Event:** Event type (workitem.created, etc.)
- **Status:** Success (✓) or Failed (✗)
- **Response code:** HTTP 200, 401, 500, etc.
- **Duration:** How long endpoint took to respond
- **Retry count:** Number of retry attempts

### Common Issues

#### Issue: Webhook not firing

**Possible Causes:**
- Filters too restrictive (no work items match)
- Subscription disabled
- Event type mismatch

**Resolution:**
- Review filter criteria
- Verify subscription status is "Enabled"
- Check event type matches your scenario

#### Issue: HTTP 401 Unauthorized

**Possible Causes:**
- Missing or incorrect authentication header
- Shared secret mismatch
- IP not whitelisted

**Resolution:**
- Verify `X-Webhook-Secret` header matches endpoint
- Check authentication configuration
- Add Azure DevOps IPs to whitelist

#### Issue: HTTP 500 Internal Server Error

**Possible Causes:**
- Endpoint code threw exception
- Database connection failed
- External API call timed out

**Resolution:**
- Check endpoint application logs
- Add try-catch error handling
- Implement timeout/retry logic for external calls

#### Issue: Timeout (no response)

**Possible Causes:**
- Endpoint processing took > 10 seconds
- Network connectivity issues
- Endpoint server down

**Resolution:**
- Return HTTP 200 immediately, process async
- Use message queue for long-running operations
- Verify endpoint is accessible from Azure DevOps

---

## Advanced Scenarios

### Scenario 1: Invoke Different Agents Based on Keywords

```csharp
private async Task<IActionResult> RouteToAgent(WorkItemContext context)
{
    var keywords = context.Title.ToLower();
    
    if (keywords.Contains("pricing") || keywords.Contains("market price"))
    {
        return await InvokePricingAgent(context);
    }
    else if (keywords.Contains("position") || keywords.Contains("holdings"))
    {
        return await InvokePositionAgent(context);
    }
    else if (keywords.Contains("trade") || keywords.Contains("execution"))
    {
        return await InvokeTradeAgent(context);
    }
    else if (keywords.Contains("ssis") || keywords.Contains("etl"))
    {
        return await InvokeSSISAgent(context);
    }
    else
    {
        return await InvokeGeneralMOSAgent(context);
    }
}
```

### Scenario 2: Queue Work Items for Batch Processing

```csharp
// Instead of processing immediately, queue for later
[HttpPost("webhook")]
public async Task<IActionResult> HandleWebhook([FromBody] JsonElement payload)
{
    // Extract work item ID
    var workItemId = payload.GetProperty("resource").GetProperty("id").GetInt32();
    
    // Add to Azure Service Bus queue
    await _serviceBusClient.SendMessageAsync(new ServiceBusMessage
    {
        MessageId = Guid.NewGuid().ToString(),
        Body = BinaryData.FromObjectAsJson(new {
            WorkItemId = workItemId,
            Timestamp = DateTime.UtcNow
        })
    });
    
    // Return immediately (< 1 second)
    return Ok(new { status = "queued" });
}
```

### Scenario 3: Multi-Tenant Webhook (Multiple Projects)

```csharp
[HttpPost("webhook")]
public async Task<IActionResult> HandleWebhook(
    [FromQuery] string project,
    [FromBody] JsonElement payload)
{
    // Route to project-specific handler
    var handler = _handlerFactory.GetHandler(project);
    if (handler == null)
    {
        return BadRequest($"Unknown project: {project}");
    }
    
    await handler.ProcessAsync(payload);
    return Ok();
}
```

---

## Complete Setup Checklist

### Azure DevOps Configuration
- [ ] Verify you have `Edit subscriptions` permission
- [ ] Navigate to Project Settings → Service Hooks
- [ ] Create new webhook subscription
- [ ] Select trigger event (workitem.created, workitem.updated)
- [ ] Configure filters (work item type, area path, tags, title keywords)
- [ ] Enter webhook endpoint URL (HTTPS)
- [ ] Add authentication headers (X-Webhook-Secret, Authorization)
- [ ] Select "Detailed messages to send"
- [ ] Test webhook subscription
- [ ] Verify HTTP 200 response
- [ ] Activate subscription

### Endpoint Configuration
- [ ] Deploy webhook endpoint to public URL
- [ ] Configure HTTPS with valid certificate
- [ ] Implement authentication (shared secret, API key)
- [ ] Parse Azure DevOps webhook payload
- [ ] Extract work item details (ID, title, description, tags)
- [ ] Implement routing logic (which agent to invoke)
- [ ] Return HTTP 200 within 10 seconds
- [ ] Log all webhook requests
- [ ] Handle errors gracefully (try-catch)
- [ ] Implement rate limiting

### Security
- [ ] Store shared secret in secure vault (Azure Key Vault, env variables)
- [ ] Validate webhook authenticity (shared secret, IP whitelist)
- [ ] Use HTTPS only
- [ ] Implement IP whitelisting for Azure DevOps IPs
- [ ] Rotate secrets every 90 days
- [ ] Log security events (unauthorized attempts)

### Testing
- [ ] Test with ngrok for local development
- [ ] Test with Postman using sample payload
- [ ] Verify webhook fires on work item creation
- [ ] Verify filters work correctly
- [ ] Verify agent is invoked successfully
- [ ] Test error scenarios (invalid secret, timeout)
- [ ] Monitor webhook history in Azure DevOps

### Monitoring
- [ ] Set up application logging (Application Insights, Seq)
- [ ] Monitor webhook delivery success rate
- [ ] Set up alerts for failed webhooks
- [ ] Track agent invocation metrics
- [ ] Review webhook history weekly

---

## Resources

### Azure DevOps Documentation
- [Service Hooks Overview](https://learn.microsoft.com/en-us/azure/devops/service-hooks/overview)
- [Web Hooks Service Hook](https://learn.microsoft.com/en-us/azure/devops/service-hooks/services/webhooks)
- [Work Item Events](https://learn.microsoft.com/en-us/azure/devops/service-hooks/events)
- [Create Service Hook Subscriptions](https://learn.microsoft.com/en-us/rest/api/azure/devops/hooks/subscriptions)

### Azure DevOps REST API
- [Work Items API](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/work-items)
- [Comments API](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/comments)
- [Service Hooks API](https://learn.microsoft.com/en-us/rest/api/azure/devops/hooks)

### Tools
- [ngrok](https://ngrok.com/) - Expose local endpoints for testing
- [Postman](https://www.postman.com/) - API testing
- [Azure DevOps CLI](https://learn.microsoft.com/en-us/cli/azure/devops) - Command-line automation

---

## Next Steps

1. **Deploy Webhook Endpoint**
   - Choose hosting platform (Azure App Service, AWS Lambda, etc.)
   - Deploy endpoint code
   - Configure environment variables

2. **Create Service Hook in Azure DevOps**
   - Follow steps in "Method 1: Setup via Azure DevOps Web UI"
   - Test webhook with sample work item

3. **Integrate MOS Support Agent**
   - Implement agent invocation logic in webhook handler
   - Configure agent routing based on keywords/tags
   - Set up automatic commenting/assignment

4. **Monitor and Iterate**
   - Review webhook delivery history
   - Adjust filters based on agent performance
   - Refine keyword detection logic
   - Measure time savings and accuracy

---

**Last Updated:** 2026-07-06  
**Maintained By:** MOS Support Team  
**Contact:** For questions, contact MOS Support or DevOps team
