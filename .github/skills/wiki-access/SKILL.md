# Azure DevOps Wiki Access Skill

**Version:** 1.1  
**Enhanced:** AI vision screenshot analysis for wiki page images

## Purpose

Access and retrieve documentation from Azure DevOps Siepe Wiki, including TML Properties documentation, operational procedures, troubleshooting guides, and system documentation. Enhanced with wiki page screenshot analysis to extract documentation from images when wiki pages are not directly accessible.

## When to Use This Skill

- User asks about TML scripts, TML properties, or Report Schedule jobs
- Need to fetch wiki documentation for reference
- Looking up MOS operational procedures
- Retrieving system documentation or configuration guides
- Creating Report Schedule jobs or TML scripts

---

## Step 0: Analyze Wiki Page Screenshots (If Provided)

**When wiki pages are attached as screenshots instead of text:**

```powershell
# If user attached wiki page screenshots
$ticket = az boards work-item show --id $ticketId --org "https://siepe.visualstudio.com/" --output json | ConvertFrom-Json
$attachments = $ticket.relations | Where-Object { $_.rel -eq "AttachedFile" }
$imageFiles = $attachments | Where-Object { $_.url -match '\.(png|jpg|jpeg|gif|webp)$' }

# Agent uses view_image to analyze:
# - Wiki page screenshots showing documentation
# - Procedure steps from wiki images
# - Configuration examples from wiki
# - TML script examples visible in screenshots

# Extract text content from wiki images for reference
```

## Prerequisites

### Authentication Setup

**IMPORTANT:** Azure CLI must be authenticated before accessing wiki pages.

#### First-Time Setup

```powershell
# 1. Check if Azure CLI is installed
az --version

# 2. Login to Azure DevOps (opens browser for authentication)
az login

# 3. Set default organization and project
az devops configure --defaults organization=https://siepe.visualstudio.com/ project="Siepe.Software"
```

**Note:** Credentials are cached locally after successful login. Re-run `az login` if authentication expires.

---

## Wiki Access Commands

### List Available Wiki Pages

```powershell
# List all pages in Siepe Wiki
az devops wiki page list `
    --wiki "Siepe Wiki" `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software"
```

### Show Wiki Page Content

```powershell
# View page content in terminal
az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path "/path/to/page" `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software"
```

### Export Wiki Page to File

```powershell
# Export to markdown file
az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path "/path/to/page" `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --output json | ConvertFrom-Json | Select-Object -ExpandProperty content | Out-File "page.md" -Encoding UTF8
```

---

## Common Wiki Paths

### MOS Documentation

| Topic | Path |
|-------|------|
| **MOS Overview** | `/1006/MOS` |
| **Client Support** | `/Siepe's Wiki/Client Support` |
| **MOS Subsection** | `/Siepe's Wiki/Client Support/MOS` |

### TML & Report Schedule

| Topic | Path | URL |
|-------|------|-----|
| **TML Properties** | `/403/TML-Properties` | https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/403/TML-Properties |

**Note:** Path format may vary. Try both formats:
- `/403/TML-Properties` (page ID format)
- `/TML Properties - Overview` (page title format)

---

## Standard Workflow: Fetching TML Documentation

### Step 1: Fetch TML Properties Page

```powershell
# Export TML documentation to local file
az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path "/403/TML-Properties" `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --output json | ConvertFrom-Json | Select-Object -ExpandProperty content | Out-File "C:\source\MD\AdminTools\Output\TML_Properties.md" -Encoding UTF8
```

### Step 2: Read the Documentation

```powershell
# View the exported file
Get-Content "C:\source\MD\AdminTools\Output\TML_Properties.md"
```

### Step 3: Create TML Script

Based on the documentation, create TML script for Report Schedule jobs.

**Common TML Properties:**
- `ReportName`: Name of the stored procedure to execute
- `Parameters`: Parameters to pass to the procedure
- `Schedule`: Cron expression or schedule definition
- `EmailRecipients`: Who receives the report
- `Format`: Output format (HTML, Excel, CSV, etc.)

---

## Troubleshooting

### Error: "Wiki page could not be found"

**Cause:** Incorrect path format or page doesn't exist.

**Solutions:**
1. List all wiki pages to find the correct path:
   ```powershell
   az devops wiki page list --wiki "Siepe Wiki" --org https://siepe.visualstudio.com/ --project "Siepe.Software"
   ```

2. Try alternative path formats:
   - Page ID: `/403/TML-Properties`
   - Page title: `/TML Properties - Overview`
   - URL-encoded: `/TML%20Properties%20-%20Overview`

3. Check the URL in browser and extract the page ID (number after `/wikis/Siepe%20Wiki/`)

### Error: "Please run 'az login' to setup account"

**Cause:** Azure CLI not authenticated.

**Solution:**
```powershell
az login
```

This opens a browser for authentication. Use your Siepe credentials.

### Error: Loading identity providers (browser shows progress spinner)

**Cause:** Web page requires authentication or JavaScript to load content.

**Solution:** Use Azure CLI commands instead of web scraping. The CLI has proper authentication.

---

## Example: Complete TML Script Creation Workflow

### Scenario: Create Report Schedule job for pLedgerValueMMFMappings

```powershell
# 1. Fetch TML documentation
az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path "/403/TML-Properties" `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --output json | ConvertFrom-Json | Select-Object -ExpandProperty content | Out-File "TML_Properties.md" -Encoding UTF8

# 2. Read the documentation
Get-Content "TML_Properties.md"

# 3. Create TML script based on documentation format
# (Use the documentation as a template)

# 4. Deploy TML script to appropriate location
# (Location specified in TML documentation)
```

---

## References

- **MOSSystemConnectionsReference.md:** Full Azure DevOps and database connection details
- **Siepe Wiki URL:** https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki
- **Azure CLI Docs:** https://learn.microsoft.com/en-us/cli/azure/devops/wiki

---

## Quick Reference Commands

```powershell
# Login
az login

# Set defaults
az devops configure --defaults organization=https://siepe.visualstudio.com/ project="Siepe.Software"

# List wiki pages
az devops wiki page list --wiki "Siepe Wiki" --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Show TML Properties page
az devops wiki page show --wiki "Siepe Wiki" --path "/403/TML-Properties" --include-content --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Export to file
az devops wiki page show --wiki "Siepe Wiki" --path "/403/TML-Properties" --include-content --org https://siepe.visualstudio.com/ --project "Siepe.Software" --output json | ConvertFrom-Json | Select-Object -ExpandProperty content | Out-File "output.md" -Encoding UTF8
```
