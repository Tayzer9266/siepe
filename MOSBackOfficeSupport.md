---
name: "MOS Back Office Support Agent"
description: "Primary agent for MOS database support, pricing issues, cash reconciliation, and back office troubleshooting. Routes tickets to appropriate investigation skills, executes investigations, and automatically posts results to ADO tickets."
version: "1.1"
created: "2026-07-01"
updated: "2026-07-02"
applyTo:
  - pattern: "**/*.{sql,md}"
    when_user_mentions:
      - "pricing issue"
      - "pricing discrepancy"
      - "market price"
      - "cash reconciliation"
      - "balance issue"
      - "ADO ticket"
      - "MOS support"
      - "vendor price"
      - "Markit"
      - "LSEG"
      - "ICE"
      - "Sycamore"
tools_required:
  - "grep_search"
  - "read_file"
  - "semantic_search"
  - "run_in_terminal"
  - "sqlcmd"
databases:
  - "mos-sql-p.mos.siepe.local,52155 (Core, Reference, Employee)"
  - "SOLVAS-SQL-D.mos.siepe.local,52156 (Solvas_AM, Feeds)"
---

# MOS Back Office Support Agent
## Global Controller for Support Task Investigation

**Version:** 1.1  
**Last Updated:** 2026-07-02  
**Owner:** Back Office SQL Engineers

---

## 🤖 Quick Invoke

**To invoke the agent directly:**
```
@MOS Support Agent investigate ticket #{TicketNumber}
@MOS Support Agent {issue description}
```

**Agent File:** [.github/agents/MOSSupport.agent.md](./.github/agents/MOSSupport.agent.md)  
**This Document:** Controller documentation and workflow reference

---

## 🎯 Purpose

This agent orchestrates investigation of MOS support tickets by:

1. **Analyzing ticket content** → Extract key information (company, date, identifier, issue type)
2. **Routing to appropriate skill with confidence scoring** → Use taxonomy to select investigation pattern
3. **Executing database investigations** → Run queries against MOS production systems
4. **Formatting results for ADO** → Generate markdown reports and ticket comments
5. **Tracking low confidence routing** → Log tickets that don't fit taxonomy well (< 70% confidence)

---

## 🎲 Confidence Scoring System

**Purpose:** Track how well tickets match taxonomy categories to identify gaps and improve classification.

### Scoring Rubric

| Score Range | Level | Criteria | Agent Action |
|-------------|-------|----------|--------------|
| **90-100%** | High | 3+ exact keyword matches OR 1 exact + clear context | Execute skill immediately |
| **60-89%** | Medium | 1-2 exact keywords OR multiple related terms | Execute skill with caution |
| **30-59%** | Low | Partial keyword match, requires interpretation | **Log** + execute with warning |
| **0-29%** | Very Low | No keyword match, unclear category | **Log** + request manual review |

### Low Confidence Tracking

**Threshold:** Confidence < 70%

**Log File:** [Output/LowConfidenceTickets.md](./Output/LowConfidenceTickets.md)

**Logged Information:**
- Ticket ID and title
- Confidence score and routing decision
- Keywords found vs. expected
- Investigation outcome (correct/incorrect routing)
- Recommended taxonomy improvements

**Review Cadence:**
- Monthly review of logged tickets
- Identify patterns requiring new categories
- Update taxonomy keywords
- Prioritize skill development for common gaps

**Example:**
```
Ticket #82500 - "Daily NAV calculation mismatch"
Confidence: 65% (Medium-Low) → Routed to check-data-quality
Keywords: "NAV", "calculation", "mismatch"
Reason: "NAV" not explicitly in taxonomy, matched on "calculation" + "mismatch"
Recommendation: Add "NAV", "net asset value" to Category 6 keywords
```

---

## 📋 System Access

### Database Connections
See: [MOSSystemConnectionsReference.md](./MOSSystemConnectionsReference.md)

**Primary Systems:**
- **MOS Production:** mos-sql-p.mos.siepe.local,52155
  - Core (positions, trades, cash rec, mappings)
  - Reference (security master, vendor data, reference tables)
  - Employee (companies, users, permissions)
  
- **Solvas Development:** SOLVAS-SQL-D.mos.siepe.local,52156
  - Solvas_AM (client portfolios, accounts)
  - Feeds (data normalization, source feeds)

**Client Databases (40+ clients):**
- See full matrix in MOSSystemConnectionsReference.md
- Examples: Aristotle, Diameter, Security Master, Sycamore
- Standard port: 52155, Standard databases: Core, Reference
- Environments: DEV, QA, PROD, UAT

**Authentication:** Windows Integrated Security (SSO)

### Azure DevOps
- **Organization:** https://siepe.visualstudio.com/
- **Project:** Siepe.Software
- **Area Path:** Siepe.Software\Back Office SQL Engineers
- **Tool:** az boards (Azure CLI)

---

## 🗂️ Skill Routing

### Taxonomy Reference
See: [MOSSupportTaskTaxonomy.md](./MOSSupportTaskTaxonomy.md)

The taxonomy classifies **~825 annual tickets** into **10 categories** with specific investigation skills.

### Quick Routing Table

| Keywords in Ticket | Category | Skill to Invoke | Priority |
|-------------------|----------|-----------------|----------|
| "price", "pricing", "Markit", "LSEG", "vendor", "enhanced pricing" | 1 - Market Pricing | [check-market-price](./.github/skills/check-market-price/SKILL.md) | High |
| "cash", "balance", "reconciliation", "SFR", "cash rec" | 2 - Cash Reconciliation | CheckCashReconciliation | Critical |
| "normalization", "mapping", "data transform", "source data" | 3 - Data Normalization | CheckDataNormalization | Medium |
| "SSIS", "PowerShell", "job failed", "package error", "ETL" | 4 - SSIS/PowerShell | CheckSSISErrors | High |
| "new portfolio", "fund setup", "account setup", "onboarding" | 5 - Portfolio Setup | SetupPortfolio | Medium |
| "data quality", "missing data", "incorrect data", "validation" | 6 - Data Quality | CheckDataQuality | Medium |
| "slow", "performance", "timeout", "query optimization" | 7 - Performance | OptimizePerformance | High |
| "feed", "import", "integration", "vendor file", "data delivery" | 8 - Integration/Feeds | CheckDataFeeds | High |
| "workflow", "approval", "stuck", "pending approval" | 9 - Workflow | CheckWorkflow | Medium |
| "schema change", "add column", "new table", "alter" | 10 - Schema Changes | ReviewSchemaChange | Low |

---

## 🔄 Investigation Workflow

### Step 1: Parse Ticket Information

Extract from ADO ticket:

```markdown
**Ticket ID:** [System.Id]
**Title:** [System.Title]
**Work Item Type:** [Task | Bug | User Story]
**Created Date:** [System.CreatedDate]
**Assigned To:** [System.AssignedTo]
**State:** [System.State]
**Description:** [System.Description]
**Acceptance Criteria:** [Microsoft.VSTS.Common.AcceptanceCriteria]
```

**Key Information to Extract:**
- Company name or CompanyID
- Date of issue (often T-1, prior business day)
- Identifiers (CUSIP, ISIN, LoanX, AccountID, PortfolioID)
- Error messages or symptoms
- Report names mentioned

### Step 2: Route to Skill

Use the **Routing Table** above or consult the full taxonomy:

1. Scan ticket title and description for keywords
2. Match to category (1-10)
3. Select appropriate skill
4. Verify skill status (✅ Production Ready or 🚧 In Development)

**Decision Logic:**
```
IF keywords include ("price", "pricing", "Markit", "LSEG", "vendor")
   THEN Category = 1 (Market Pricing)
   SKILL = CheckMarketPrice.instructions.md
   
ELSE IF keywords include ("cash", "balance", "reconciliation")
   THEN Category = 2 (Cash Reconciliation)
   SKILL = CheckCashReconciliation.instructions.md
   
ELSE IF keywords include ("SSIS", "PowerShell", "job failed")
   THEN Category = 4 (SSIS/PowerShell)
   SKILL = CheckSSISErrors.instructions.md
   
ELSE
   CONSULT MOSSupportTaskTaxonomy.md for detailed routing
```

### Step 3: Execute Skill

**For Production-Ready Skills (✅):**

1. Open the skill file: `./Skills/{SkillName}.instructions.md`
2. Follow the skill's investigation steps
3. Execute SQL queries using sqlcmd:
   ```powershell
   sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" -Q "[SQL QUERY]"
   ```
4. Collect results and analysis

**For In-Development Skills (🚧):**

1. Consult taxonomy for investigation pattern
2. Perform manual analysis following category guidelines
3. Document findings
4. [Future] Flag ticket for skill development priority

### Step 4: Generate Output

**Markdown Report Format:**
- Filename: `{SkillName}-{Identifier}-{Date}.md`
- Location: `./Output/`
- Template: See skill file for specific format

**ADO Comment Format:**
```markdown
## Investigation Results - {Skill Name}

**Ticket:** #{TicketID}  
**Investigated By:** MOS Back Office Support Agent  
**Date:** {YYYY-MM-DD}  

### Summary
[Brief 1-2 sentence summary of findings]

### Root Cause
[Specific root cause identified]

### Analysis
[Detailed investigation results]

### Recommendation
[Action items or resolution steps]

### Supporting Data
[Key query results or evidence]

---
**Report:** [Link to detailed markdown report]
```

### Step 5: Update Ticket

**Automatic ADO Comment Posting (v1.1+):**

When a ticket number is provided (#XXXXX), the agent automatically:
1. Reads the full investigation report from `Output/` folder
2. Formats the report content as an ADO comment
3. Posts the comment to the ticket using Azure CLI:
   ```powershell
   az boards work-item update `
       --id {TicketID} `
       --discussion "{formatted comment}" `
       --org https://siepe.visualstudio.com/ `
       --project "Siepe.Software"
   ```
4. Confirms comment was posted successfully

**Requirements:**
- User must run `az login` before invoking agent
- Azure CLI with boards extension installed
- Permissions to comment on work items in Siepe.Software project

**Fallback (if authentication fails):**
1. Agent displays formatted comment for manual copy-paste
2. User navigates to ADO ticket
3. User pastes comment manually
4. User updates ticket state if resolved

**Comment Format:**
```markdown
## Investigation Results - {Skill Name}

**Ticket:** #{TicketID}  
**Routing Confidence:** {Score}% ({Category})  
**Investigated By:** MOS Support Agent  
**Date:** {YYYY-MM-DD}  

### Summary
[Brief 1-2 sentence summary of findings]

### Root Cause
[Specific root cause identified]

### Analysis
[Detailed investigation results with key query results]

### Recommendation
[Action items or resolution steps]

### SQL Queries Executed
[List of queries run during investigation]

---
**Report File:** `Output/{SkillName}_{Identifier}_{Date}.md`
```

---

## 📊 Available Skills

### ✅ Production Ready (Use Now)

#### 1. check-market-price
**File:** [./.github/skills/check-market-price/SKILL.md](./.github/skills/check-market-price/SKILL.md)  
**Category:** Market Pricing Issues (Category 1)  
**Handles:** ~50 tickets/year  
**Covers:**
- Missing vendor prices (Markit, LSEG, ICE, Sycamore)
- Price weighting configuration analysis
- Vendor source priority issues
- Root cause identification

**Example Usage:**
```
Ticket: "FW: Aristotle - Enhanced Pricing Report Daily"
Keywords: "pricing", "Markit", "Aristotle"
Route to: check-market-price
Inputs: Company="Aristotle Pacific Capital", Date="2026-06-30", CUSIP="83408EAA1"
```

### 🚧 In Development (Coming Soon)

See [MOSSupportTaskTaxonomy.md - Appendix B](./MOSSupportTaskTaxonomy.md#appendix-b-skill-development-roadmap) for development roadmap.

**Phase 1 Priority:**
- CheckCashReconciliation (~120 tickets/year, Critical priority)
- CheckDataNormalization (~80 tickets/year, Medium priority)
- CheckSSISErrors (~150 tickets/year, High priority)

---

## 🛠️ Tools & Commands

### SQL Query Execution

**PowerShell (Recommended):**
```powershell
# Simple query
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" -Q "SELECT TOP 10 * FROM Employee.vCompany"

# With output to file
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" -Q "SELECT * FROM vInstPriceCurrentRaw WHERE CUSIP = '83408EAA1'" -o "results.txt"

# Multi-line query from variable
$query = @"
SELECT CompanyID, Name 
FROM Employee.vCompany 
WHERE Name LIKE '%Aristotle%'
"@
sqlcmd -S "mos-sql-p.mos.siepe.local,52155" -d "Core" -Q $query
```

### Azure DevOps CLI

**Query Tickets:**
```powershell
# Get recent tickets
az boards query --wiql "SELECT [System.Id], [System.Title] FROM WorkItems WHERE [System.AreaPath] = 'Siepe.Software\Back Office SQL Engineers' AND [System.CreatedDate] >= '2026-06-01'" --org https://siepe.visualstudio.com/ --output table

# Get specific ticket details
az boards work-item show --id 82115 --org https://siepe.visualstudio.com/
```

**Update Tickets (Future):**
```powershell
# Add comment
az boards work-item update --id 82115 --discussion "Investigation complete. See attached report." --org https://siepe.visualstudio.com/

# Update state
az boards work-item update --id 82115 --state "Resolved" --org https://siepe.visualstudio.com/
```

### File Operations

**Create Output Report:**
```powershell
# Generate markdown report
$report | Out-File -FilePath ".\Output\CheckMarketPrice-83408EAA1-2026-06-30.md" -Encoding UTF8
```

---

## 📚 Documentation Structure

```
AdminTools/
├── MOSBackOfficeSupport.md              ← YOU ARE HERE (Global Controller)
├── MOSSupportTaskTaxonomy.md            ← Skill routing & category definitions
├── MOSSystemConnectionsReference.md     ← Database connection strings
├── README.md                            ← Quick start guide
│
├── .github/
│   ├── agents/
│   │   └── MOSSupport.agent.md
│   └── skills/                          ← Investigation skill library
│       ├── check-market-price/
│       │   └── SKILL.md
│       ├── check-cash-reconciliation/ (planned)
│       └── [other skills...]
│
├── Output/                              ← Investigation reports
│   ├── CheckMarketPrice_{CUSIP}_{Date}.md
│   └── [other reports...]
│
├── Reference/                           ← Supporting documentation
│   ├── MOSDatabaseSchema.md
│   ├── MOSPlayers.md
│   └── MOSSupportRole.md
│
└── Archive/                             ← Historical documents
    ├── MOSBackOfficeBacklogAnalysis.md
    └── [archived planning docs...]
```

---

## 🚀 Quick Start Examples

### Example 1: Pricing Investigation

**Ticket:** #82115 "FW: Aristotle - Enhanced Pricing Report Daily"

**Steps:**
1. Identify keywords: "pricing", "Aristotle", "enhanced pricing report"
2. Route to: Category 1 - Market Pricing → check-market-price skill
3. Extract inputs: Company="Aristotle Pacific Capital", Date="2026-06-30"
4. Open: `./.github/skills/check-market-price/SKILL.md`
5. Execute 5-step investigation process
6. Generate report: `./Output/CheckMarketPrice-83408EAA1-2026-06-30.md`
7. Format ADO comment with findings
8. Update ticket with resolution

**Outcome:** Root cause identified (vendor coverage gap), resolution provided.

---

### Example 2: Cash Reconciliation (Future)

**Ticket:** #XXXXX "Balance mismatch for Brotherhood Mutual - June 2026"

**Steps:**
1. Identify keywords: "balance", "reconciliation", "Brotherhood Mutual"
2. Route to: Category 2 - Cash Reconciliation → check-cash-reconciliation skill
3. Extract inputs: Company="Brotherhood Mutual", Date="2026-06-30", Account=[TBD]
4. Open: `./.github/skills/check-cash-reconciliation/SKILL.md`
5. Execute cash rec investigation
6. Generate report with discrepancy analysis
7. Update ADO ticket

---

## 🔐 Security & Access

### Required Permissions

**Database Access:**
- Read access to Core, Reference, Employee databases
- Windows authentication with siepe.local domain account
- VPN connection to Siepe network (if remote)

**Azure DevOps Access:**
- Member of "Back Office SQL Engineers" team
- Permission to view and comment on work items
- Area path: Siepe.Software\Back Office SQL Engineers

### Credential Management

**Do NOT:**
- ❌ Store passwords in files
- ❌ Commit credentials to source control
- ❌ Share connection strings with passwords

**Do:**
- ✅ Use Windows Integrated Security (SSO)
- ✅ Store secrets in Azure Key Vault (if needed)
- ✅ Follow Siepe security policies

---

## 📈 Success Metrics

### Agent Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| Average ticket resolution time | < 30 minutes | TBD |
| First-time resolution rate | > 80% | TBD |
| Skills coverage of tickets | > 70% | 6% (1/10 skills) |
| Agent usage adoption | > 50% of team | TBD |
| Ticket backlog reduction | -20% quarter over quarter | TBD |

### Skill Development Progress

See [MOSSupportTaskTaxonomy.md - Appendix B](./MOSSupportTaskTaxonomy.md#appendix-b-skill-development-roadmap) for Phase 1-3 roadmap.

**Current Status:**
- ✅ Phase 1: 1/3 skills complete (CheckMarketPrice)
- 🚧 Phase 2: 0/4 skills started
- 📋 Phase 3: 0/3 skills planned

---

## 🎓 Agent Development Guide

### Adding New Skills

When you create a new investigation skill:

1. **Create skill folder:** `./.github/skills/{skill-name}/`
2. **Create skill file:** `./.github/skills/{skill-name}/SKILL.md`
3. **Follow standard structure:**
   ```yaml
   ---
   skill_name: skill-kebab-case
   title: Human Readable Title
   description: What this skill investigates
   version: 1.0
   database: mos-prod
   output_format: markdown
   ---
   ```
3. **Include sections:**
   - Purpose & when to use
   - Required inputs
   - Database connection info
   - Investigation steps (numbered)
   - SQL query templates
   - Output format/template
   - Example tickets resolved
4. **Update taxonomy:** Add skill to appropriate category
5. **Update this controller:** Add to routing table and available skills
6. **Test:** Run against real ADO ticket
7. **Document:** Create example output in `./Output/` folder

---

## 📞 Support & Feedback

### Questions?

- **Team:** Back Office SQL Engineers
- **Lead:** [TBD]
- **Documentation:** This folder (AdminTools/)
- **ADO:** Siepe.Software\Back Office SQL Engineers area path

### Improvement Ideas

To suggest improvements to this agent:
1. Document issue or enhancement idea
2. Create ADO task with tag "agent-improvement"
3. Assign to Back Office SQL Engineers team

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-07-01 | Initial agent controller created with CheckMarketPrice skill integration |

---

**Last Updated:** 2026-07-01  
**Next Review:** 2026-10-01 (Quarterly)
