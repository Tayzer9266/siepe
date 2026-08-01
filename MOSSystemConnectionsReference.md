# MOS System Connections Reference

**Purpose:** Central reference for all MOS system connection strings, URLs, and access information  
**Audience:** Developers, MOS Support Team, MCP (Model Context Protocol) integrations  
**Last Updated:** 2026-07-24

---

## 🔐 Security Notice

**⚠️ WARNING:** This document contains connection information for production systems. 

- **Do NOT commit** credentials or passwords to source control
- **Use Windows Integrated Security** (SSO) for database connections when possible
- **Store secrets** in Azure Key Vault or secure credential managers
- **Follow** Siepe's security policies for access management

---

## 📊 MOS Production Database

### Primary Connection (MOS Core Database)

**Purpose:** Main operational database for MOS (positions, trades, cash rec, mappings)

```
Server: mos-sql-p.mos.siepe.local,52155
Database: Core
Authentication: Windows Integrated Security (SSO)
```

**Connection Strings:**

**C# / .NET:**
```csharp
var connectionString = "Server=mos-sql-p.mos.siepe.local,52155;Database=Core;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=60;";
```

**PowerShell (.NET SqlClient):**
```powershell
$connectionString = "Server=mos-sql-p.mos.siepe.local,52155;Database=Core;Integrated Security=True;TrustServerCertificate=True;"
$conn = New-Object System.Data.SqlClient.SqlConnection($connectionString)
$conn.Open()
```

**Azure Data Studio / SSMS:**
```
Server name: mos-sql-p.mos.siepe.local,52155
Authentication: Windows Authentication
Database: Core
```

### Reference Database

**Purpose:** Reference data, master data, mappings, and lookup tables

```
Server: mos-sql-p.mos.siepe.local,52155
Database: Reference
Authentication: Windows Integrated Security (SSO)
```

**Connection String:**
```csharp
var connectionString = "Server=mos-sql-p.mos.siepe.local,52155;Database=Reference;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=60;";
```


### Feeds Database 

**Purpose:** Data Normalization process from Solvas
```
Server: SOLVAS-SQL-P.mos.siepe.local,1433
Database: Feeds
Authentication: Windows Integrated Security (SSO)
```
**Connection String:**
```csharp
var connectionString = "SOLVAS-SQL-P.mos.siepe.local,1433;Database=Reference;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=60;";
```




### Available Databases

Based on production query (2026-06-30):

| Database Name | Purpose | Primary Use |
|---------------|---------|-------------|
| **Core** | Main operational database | Positions, Trades, Cash Rec, Process Flow |
| **Reference** | Reference and master data | Security Master, Mappings, Broker data |

**Note:** Solvas_AM database mentioned in documentation but not accessible from current permissions.

---

## 📚 Azure DevOps Wiki

### Siepe Wiki

**Purpose:** MOS operational documentation, support procedures, troubleshooting guides

**Web Access:**
```
https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki
```

**Direct Links:**

| Resource | URL |
|----------|-----|
| **MOS Overview** | https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe%20Wiki/1006/MOS |
| **Client Support** | https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe's%20Wiki/Client%20Support |
| **MOS Subsection** | https://siepe.visualstudio.com/Siepe.Software/_wiki/wikis/Siepe's%20Wiki/Client%20Support/MOS |

### Azure CLI Commands for Wiki Access

**Prerequisites:**
```powershell
# Install Azure CLI (if not already installed)
# Download from: https://aka.ms/installazurecliwindows

# Login to Azure DevOps
az login

# Set default organization
az devops configure --defaults organization=https://siepe.visualstudio.com/ project="Siepe.Software"
```

**Show Wiki Page:**
```powershell
az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path "/Siepe's Wiki/Client Support/MOS" `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software"
```

**List Wiki Pages:**
```powershell
az devops wiki page list `
    --wiki "Siepe Wiki" `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software"
```

**Export Wiki Page to File:**
```powershell
az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path "/Siepe's Wiki/Client Support/MOS/[PageName]" `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --output json | ConvertFrom-Json | Select-Object -ExpandProperty content | Out-File "output.md" -Encoding UTF8
```

---

## 📋 Azure DevOps Boards (Work Items & Backlog)

### Organization & Project

**Purpose:** Track development work, bugs, support tickets, feature requests

```
Organization: https://siepe.visualstudio.com/
Project: Siepe.Software
Area Path (Back Office): Siepe.Software\Back Office SQL Engineers
```

### 🔐 Authentication Setup

**⚠️ IMPORTANT:** Azure CLI must be authenticated before the agent can access Azure DevOps.

#### First-Time Setup

**1. Install Azure CLI (if not already installed):**
```powershell
# Check if installed
az --version

# If not installed, download from:
# https://aka.ms/installazurecliwindows
```

**2. Login to Azure DevOps:**
```powershell
# Interactive browser-based login (RECOMMENDED)
az login

# This will open a browser window for authentication
# Use your Siepe credentials (user@siepe.com)
# Credentials are cached locally after successful login
```

**3. Configure Default Organization & Project:**
```powershell
# Set defaults so you don't have to specify --org every time
az devops configure --defaults `
    organization=https://siepe.visualstudio.com/ `
    project="Siepe.Software"
```

**4. Verify Authentication:**
```powershell
# Test with a simple query
az boards query --wiql "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = 'Siepe.Software'" --org https://siepe.visualstudio.com/ --output table
```

#### Check Current Authentication Status

```powershell
# Show current logged-in account
az account show

# List available organizations
az devops project list --org https://siepe.visualstudio.com/
```

#### Troubleshooting Authentication

**If `az boards` commands fail with authentication error:**

```powershell
# Re-authenticate
az logout
az login

# Or use Personal Access Token (PAT)
$env:AZURE_DEVOPS_EXT_PAT = "your-personal-access-token"
az boards query --wiql "..." --org https://siepe.visualstudio.com/
```

**To create a Personal Access Token (PAT):**
1. Go to https://siepe.visualstudio.com/_usersSettings/tokens
2. Click "New Token"
3. Set scope: "Work Items (Read & Write)"
4. Copy token and store securely
5. Use in PowerShell: `$env:AZURE_DEVOPS_EXT_PAT = "your-token"`

**Note:** PAT tokens expire. Browser-based `az login` is preferred for interactive use.

**Web Access:**

| Resource | URL |
|----------|-----|
| **Project Dashboard** | https://siepe.visualstudio.com/Siepe.Software |
| **Boards (Work Items)** | https://siepe.visualstudio.com/Siepe.Software/_boards |
| **Backlogs** | https://siepe.visualstudio.com/Siepe.Software/_backlogs |
| **Sprints** | https://siepe.visualstudio.com/Siepe.Software/_sprints |
| **Queries** | https://siepe.visualstudio.com/Siepe.Software/_queries |

### Azure CLI Commands for Work Items

**Query Work Items:**
```powershell
# Query work items by WIQL (Work Item Query Language)
az boards query `
    --wiql "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = 'Siepe.Software' AND [System.State] <> 'Closed' ORDER BY [System.CreatedDate] DESC" `
    --org https://siepe.visualstudio.com/ `
    --output table
```

**Show Work Item Details:**
```powershell
az boards work-item show `
    --id [WorkItemID] `
    --org https://siepe.visualstudio.com/ `
    --output json
```

**Create Work Item:**
```powershell
az boards work-item create `
    --title "Title of work item" `
    --type "Bug" `
    --description "Description" `
    --assigned-to "user@siepe.com" `
    --area "Siepe.Software\MOS" `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software"
```

**Common Work Item Types:**
- `Bug` - Defects and issues
- `User Story` - Feature requests and enhancements
- `Task` - Development tasks
- `Epic` - Large initiatives
- `Feature` - Product features

### Common WIQL Query Examples

**All Open MOS-Related Items:**
```sql
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo]
FROM WorkItems 
WHERE [System.TeamProject] = 'Siepe.Software' 
    AND [System.AreaPath] UNDER 'Siepe.Software\MOS'
    AND [System.State] <> 'Closed'
ORDER BY [System.Priority] ASC, [System.CreatedDate] DESC
```

**Recently Created Bugs:**
```sql
SELECT [System.Id], [System.Title], [System.State], [System.CreatedDate]
FROM WorkItems 
WHERE [System.TeamProject] = 'Siepe.Software' 
    AND [System.WorkItemType] = 'Bug'
    AND [System.CreatedDate] >= @Today - 7
ORDER BY [System.CreatedDate] DESC
```

**Items in Current Sprint:**
```sql
SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo]
FROM WorkItems 
WHERE [System.TeamProject] = 'Siepe.Software' 
    AND [System.IterationPath] = @CurrentIteration
ORDER BY [System.State] ASC, [System.Priority] ASC
```

---

## 🏢 Client Environment Connection Strings

**Purpose:** Connection strings for all Siepe client databases across environments  
**Use Cases:** Cross-client data verification, client-specific investigations, data migration, testing

**Standard Configuration:**
- **Port:** 52155 (standard for most clients)
- **Authentication:** Windows Integrated Security (SSO)
- **Trust Server Certificate:** True
- **Connection Timeout:** 60 seconds

### Client Database Matrix

| Client | DEV | QA | PROD | UAT |
|--------|-----|----|----|-----|
| **Abry** | abry-sql-d.abry.aws,52155 | abry-sql-q.abry.aws,52155 | abry-sql-p.abry.aws,52155 | - |
| **Aero Capital** | acs-sql-d.acs.aws,52155 | acs-sql-q.acs.aws,52155 | acs-sql-p.acs.aws,52155 | - |
| **AGL** | agl-sql-d.agl.aws,52155 | - | agl-sql-p.agl.aws,52155 | - |
| **Anson** | anson-sql-d.anson.local,52155 | anson-sql-q.anson.local,52155 | anson-sql-p.anson.local,52155 | - |
| **Apex** | apex-sql-d.apex.aws,52155 | - | apex-sql-p.apex.aws,52155 | - |
| **Aristotle** | aristotle-sql-d.aristotle.aws,52155 | aristotle-sql-q.aristotle.aws,52155 | aristotle-sql-p.aristotle.aws,52155 | - |
| **Audax** | audax-sql-d.audax.aws,52155 | - | audax-sql-p.audax.aws,52155 | - |
| **Barrow Hanley** | barrowhanley-sql-d.barrowhanley.aws,52155 | - | barrowhanley-sql-p.barrowhanley.aws,52155 | - |
| **Blackstone** | blackstone-sql-d.blackstone.aws,52155 | - | blackstone-sql-p.blackstone.aws,52155 | - |
| **Blue Owl** | blueowl-sql-d.blueowl.aws,52155 | blueowl-sql-q.blueowl.aws,52155 | blueowl-sql-p.blueowl.aws,52155 | - |
| **Canonical Version** | 990sql02.company.aws,52155 | 990sql01.company.aws,52155 | 990sql00.company.aws,52155 | - |
| **Chamonix** | chamonix-sql-d.chamonix.aws,52155 | - | chamonix-sql-p.chamonix.aws,52155 | - |
| **Chatham** | chatham-sql-d.chatham.aws,52155 | - | chatham-sql-p.chatham.aws,52155 | - |
| **Citi Trustee** | ca-sql-d.cititrustee.aws,52155 | ca-sql-q.cititrustee.aws,52155 | ca-sql-p.cititrustee.aws,52155 | - |
| **Diameter** | diameter-sql-d.diameter.aws,52155 | diameter-sql-q.diameter.aws,52155 | diameter-sql-p.diameter.aws,52155 | - |
| **Elmwood** | elmwood-sql-d.elmwood.aws,52155 | elmwood-sql-q.elmwood.aws,52155 | elmwood-sql-p.elmwood.aws,52155 | - |
| **FIS-NT** | fis-sql01-d.fis.aws,52155 | - | fis-sql01-p.fis.aws,52155 | fis-sql01-u.fis.aws,52155 |
| **FIS-NT-2** | fis-sql02-d.fis.aws,52155 | - | fis-sql02-p.fis.aws,52155 | fis-sql02-u.fis.aws,52155 |
| **Garnet** | garnet-sql-d.garnet.aws,52155 | garnet-sql-q.garnet.aws,52155 | garnet-sql-p.garnet.aws,52155 | - |
| **Hayfin** | hayfin-sql-d.hayfin.aws,52155 | - | hayfin-sql-p.hayfin.aws,52155 | - |
| **Highland** | 005sql01b.highland.aws,52155 | 005sql05.highland.aws,52155 | pcoredb.highland.aws,52155 | PHCMDB01 |
| **King Street** | kingstreet-sql-d.kingstreet.aws,52155 | - | kingstreet-sql-p.kingstreet.aws,52155 | - |
| **Marathon** | marathon-sql-d.marathon.aws,52155 | - | marathon-sql-p.marathon.aws,52155 | - |
| **Midcap** | midcap-sql-d.midcap.aws,52155 | - | midcap-sql-p.midcap.aws,52155 | - |
| **MOS** | mos-sql-d.mos.siepe.local,52155 | mos-sql-q.mos.siepe.local,52155 | mos-sql-p.mos.siepe.local,52155 | - |
| **Nexpoint** | dcoredb.apps.nexpoint.local,52155 | qcoredb.apps.nexpoint.local,52155 | pcoredb.apps.nexpoint.local,52155 | - |
| **OFSI** | ofsi-sql-d.ofsi.aws,52155 | - | ofsi-sql-p.ofsi.aws,52155 | - |
| **Onex** | onex-sql-d.onex.aws,52155 | - | onex-sql-p.onex.aws,52155 | - |
| **Security Master** | secmaster-sql-d.siepe.local,52155 | - | secmaster-sql-p.siepe.local,52155 | - |
| **Siepe SPG Interim** | spg-sql-d.siepe.local,52155 | - | spg-sql-p.siepe.local,52155 | - |
| **Siepe-Demo-2** | demo2-sql-d.siepe.local,52155 | demo2-sql-q.siepe.local,52155 | demo2-sql-p.siepe.local,52155 | - |
| **Siepe-Internal** | connectwise-sql-p.siepe.local,52155 | connectwise-sql-p.siepe.local,52155 | connectwise-sql-p.siepe.local,52155 | - |
| **Siepe-Notices** | SOLVAS-SQL-D.mos.siepe.local,52156 | 998sql01u.mos.siepe.local,52156 | SOLVAS-SQL-P.mos.siepe.local,1433 | - |
| **Siepe-POC** | 000sql24p.siepe.local,52155 | - | - | - |
| **Siepe-Solvas** | SOLVAS-SQL-D.mos.siepe.local,52156 | 998sql01u.mos.siepe.local,52156 | SOLVAS-SQL-P.mos.siepe.local,1433 | - |
| **Sycamore** | stp-sql-d.stp.aws,52155 | stp-sql-q.stp.aws,52155 | stp-sql-p.stp.aws,52155 | - |
| **Trade Optimization** | 122sql06q.blueowl.aws,52155 | - | - | - |
| **Yost** | 900SQL04\SQL018,52163 | - | 018sql01p.yost.aws,52155 | - |

### Quick Reference by Client Name

**Commonly Used Clients (Alphabetical):**

```powershell
# Aristotle (Production) - Used in example ticket #82115
sqlcmd -S "aristotle-sql-p.aristotle.aws,52155" -d "Core" -Q "SELECT * FROM vCompany"

# Security Master (Production) - Reference data and pricing
sqlcmd -S "secmaster-sql-p.siepe.local,52155" -d "Core" -Q "SELECT * FROM vSecurityMaster"

# Diameter (Production) - Cash reconciliation platform
sqlcmd -S "diameter-sql-p.diameter.aws,52155" -d "Core" -Q "SELECT * FROM CashRec.vCashTransactions"

# MOS (Production) - Main middle office system
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" -Q "SELECT * FROM vInst"
```

### Connection String Template

**PowerShell (.NET SqlClient):**
```powershell
$server = "aristotle-sql-p.aristotle.aws,52155"
$database = "Core"
$connectionString = "Server=$server;Database=$database;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=60;"

$conn = New-Object System.Data.SqlClient.SqlConnection($connectionString)
$conn.Open()
# Execute queries...
$conn.Close()
```

**sqlcmd:**
```powershell
sqlcmd -S "{server},{port}" -d "{database}" -Q "{query}" -E
# -E = Use Windows Authentication (Integrated Security)
```

### Common Databases Per Client

| Database Name | Purpose |
|---------------|---------|
| **Core** | Main operational database (positions, trades, cash rec) |
| **Reference** | Reference data, security master, mappings |
| **Feeds** | Data normalization, source feeds |
| **Solvas_AM** | Loan portfolio management (Solvas clients) |

### Important Notes

**Environment Selection:**
- **PROD:** Live client data - use for production support tickets
- **QA:** Pre-production testing - use for UAT verification
- **DEV:** Development environment - use for testing queries before production

**Port Variations:**
- Standard: `52155`
- Solvas Production: `1433` (SOLVAS-SQL-P.mos.siepe.local,1433)
- Solvas Dev/QA: `52156` (SOLVAS-SQL-D.mos.siepe.local,52156)
- Yost Dev: `52163` (900SQL04\SQL018,52163)

**Access Requirements:**
- VPN connection to Siepe network (if remote)
- Windows domain account (siepe.local or client-specific)
- Database read permissions
- Appropriate security clearance for client data

**Security Reminder:**
- ⚠️ **Client data is confidential** - follow data handling policies
- ⚠️ **Use PROD only for support tickets** - prefer DEV/QA for testing
- ⚠️ **Do NOT extract/export client data** without authorization
- ⚠️ **Log all production queries** for audit compliance

---

## 🔗 Related Systems & Integrations

### Solvas (Loan Management System)

**Purpose:** Loan portfolio management, trade booking, entity accounting

```
System: Solvas_AM
Database: Solvas_AM (if accessible)
Access: Via CAMOS mapping and MOS integration
```

**Note:** Direct database access may be restricted. Use MOS Core database for Solvas-derived data.

### CAMOS (Entity Mapping System)

**Purpose:** Entity relationships, portfolio mapping, organizational hierarchy

```
Access: Through CAMOS web interface or API
Integration: Maps portfolios to entityIDs used in MOS
```

### Security Master

**Purpose:** Reference data and pricing (Markit for loans, ICE for bonds)

```
Database: Possibly in Reference database
Vendors: Markit, ICE, Sycamore
```

### Custodians (Cash & Position Data)

**Purpose:** Source of truth for cash transactions and positions

| Custodian | Data Source | Integration Point |
|-----------|-------------|-------------------|
| **Citi** | Cash statements, position files | MOS Cash Rec, Position Rec |
| **Northern Trust** | Cash & position data | MOS Cash Rec, Position Rec |
| **US Bank** | Cash & position data | MOS Cash Rec via Diameter |

### Maestro (Job Orchestration & Scheduling)

**Purpose:** Enterprise job scheduling, workflow orchestration, ETL job management, SSIS package execution

**System Type:** Job scheduling platform for MOS back office operations

**GitHub Repository:** [siepe-software/maestro](https://github.com/siepe-software/maestro)

**Key Capabilities:**
- SSIS package orchestration
- Report subscription (RS) job scheduling
- Script adapter (SA) job execution
- Price override workflows
- Data feed processing automation
- Dependency management between jobs

**Access:**
```
Web Interface: [URL TBD - To be confirmed]
Authentication: Windows Integrated Security (SSO)
```

**Common Use Cases:**

| Job Type | Description | Example |
|----------|-------------|---------|
| **SSIS Packages** | ETL data processing | Solvas data normalization, price loading |
| **Report Subscriptions (RS)** | Automated report generation | pSolvasExportPriceEntity (RS 500001246) |
| **Script Adapters (SA)** | File processing & data loading | Price file loading to Solvas |
| **Price Workflows** | Price override pipelines | Multi-company price exports (RS/SA split jobs) |
| **Data Feeds** | Vendor data ingestion | LSEG/Markit price feeds, custodian files |

**Integration Points:**
- **MOS Database:** Reads/writes operational data
- **SSIS Server:** Executes SQL Server Integration Services packages
- **Solvas:** Price file generation and loading
- **Azure DevOps:** Job failure notifications (optional)

**Job Monitoring:**
```powershell
# Check job status (if API/CLI available)
# Example commands to be documented

# View recent job executions
# [Command TBD]

# Monitor specific job
# [Command TBD]
```

**Related Documentation:**
- Price Override RS/PS Split Jobs: `.github/skills/price-overrides/RS_PS_Split_Jobs.txt`
- SSIS Error Checking Skill: `.github/skills/check-ssis-errors/SKILL.md`

**Notes:**
- Maestro coordinates complex workflows involving multiple systems
- Essential for automated back office operations
- Job dependencies ensure proper execution order
- Integration with Seq logging for monitoring and troubleshooting

---

## 🛠️ Development & Testing Environments

### AdminTools Application

**Location:** (To be confirmed - typically on application server)

```
Production: [URL TBD]
Development: [URL TBD]
Repository: [Git URL TBD]
```

**Application Architecture:**
- Framework: ASP.NET MVC with C# (.NET Framework)
- Frontend: AngularJS 1.6, Bootstrap, Kendo UI
- Structure: MVC Areas (modular features)
- Database: MOS Core (mos-sql-p.mos.siepe.local,52155)

### Source Code Repository

**Git Repository:** (To be confirmed)

```
Location: [Git URL TBD]
Branch Strategy: [TBD]
CI/CD Pipeline: [Azure DevOps Pipelines TBD]
```

---

## 📖 MCP (Model Context Protocol) Integration

### Database MCP Server Configuration

If using MCP for database access, configure with:

```json
{
  "mcpServers": {
    "mos-database": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-sql",
        "mssql://mos-sql-p.mos.siepe.local,52155/Core?integratedSecurity=true&trustServerCertificate=true"
      ]
    }
  }
}
```

### Azure DevOps MCP Server Configuration

For Azure DevOps wiki and work item access:

```json
{
  "mcpServers": {
    "azure-devops": {
      "command": "az",
      "args": ["devops"],
      "env": {
        "AZURE_DEVOPS_ORG": "https://siepe.visualstudio.com/",
        "AZURE_DEVOPS_PROJECT": "Siepe.Software"
      }
    }
  }
}
```

---

## 🔍 Quick Reference: Common Operations

### Database Operations

**Query Position Data:**
```sql
-- See today's active positions
SELECT TOP 100 
    Portfolio, 
    Instrument, 
    Quantity, 
    PositionMark
FROM Core.dbo.vPositionActive
WHERE refdatasetdate = CAST(GETDATE() AS DATE)
ORDER BY Portfolio, Instrument;
```

**Query Unmatched Cash Transactions:**
```sql
-- See unmatched cash rec items
SELECT 
    crf.FundName,
    cr.TransactionDate,
    cr.Amount,
    cr.Description
FROM Core.CashRec.tCashRec cr
JOIN Core.CashRec.tCashRecFund crf ON crf.CashRecFundID = cr.CashRecFundID
WHERE cr.MatchStatusID = 1 -- Unmatched
    AND cr.IsActive = 1
ORDER BY cr.TransactionDate DESC;
```

### Wiki Operations

**Get MOS Support Page:**
```powershell
az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path "/Siepe's Wiki/Client Support/MOS" `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software"
```

### Work Item Operations

**Query Open Bugs:**
```powershell
az boards query `
    --wiql "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.WorkItemType] = 'Bug' AND [System.State] = 'Active'" `
    --org https://siepe.visualstudio.com/
```

---

## 📞 Support Contacts

### Internal Teams

| Team | Contact | Responsibility |
|------|---------|----------------|
| **MOS Support** | [Email TBD] | Daily operations, issue resolution |
| **Development Team** | [Email TBD] | System enhancements, bug fixes |
| **Data Team** | [Email TBD] | Vendor feeds, data integration |
| **IT Infrastructure** | [Email TBD] | Server/network issues |
| **Asset Admin** | [Email TBD] | Facility creation, entity setup |

### External Vendors

| Vendor | Contact | Service |
|--------|---------|---------|
| **Markit** | [Contact TBD] | Loan pricing data |
| **ICE** | [Contact TBD] | Bond pricing data |
| **Citi** | [Contact TBD] | Custodian services |
| **Northern Trust** | [Contact TBD] | Custodian services |
| **US Bank** | [Contact TBD] | Custodian services |

---

## 🔄 Maintenance Notes

### Database Maintenance Windows

- **Standard Maintenance:** Sunday 2:00 AM - 4:00 AM EST
- **Emergency Maintenance:** As needed with 24-hour notice (when possible)
- **Backup Schedule:** Daily at 11:00 PM EST

### System Availability

- **Production Database:** 24/7 with 99.5% uptime SLA
- **Azure DevOps:** 24/7 (Microsoft managed)
- **AdminTools:** Business hours (6:00 AM - 8:00 PM EST) with on-call support

---

## 📝 Document Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2026-06-30 | 1.0 | Initial creation with production connection info | System Documentation |

---

## 🔗 Related Documentation

- [MOS Client Support Issues Summary](./MOS-Client-Support-Issues-Summary.md)
- [MOS Support Role Documentation](./MOS-Support-Role.md)
- [MOS Support Enhancement Plan](./MOS-Support-Enhancement-Plan.md)
- [MOS Database Schema](./MOS-Database-Schema.md)
- [MOS Back Office Backlog Analysis](./MOS-BackOffice-Backlog-Analysis.md)

---

**Last Verified:** 2026-06-30  
**Next Review:** 2026-09-30 (Quarterly)
