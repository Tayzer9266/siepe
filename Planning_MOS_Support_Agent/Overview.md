# PROJECT: MOS Support Agent Development (Mossy)

## Vision
Build an intelligent AI agent that autonomously investigates and resolves 100% of MOS back office support tickets (~890 annually) by leveraging domain-specific skills, database analysis, AI vision for screenshots, and Azure DevOps wiki procedures. Transform reactive ticket support into proactive issue detection and resolution.

## Problem Statement
The Back Office SQL Engineers team handles ~890 support tickets annually across 11 categories (pricing issues, cash reconciliation, SSIS errors, data normalization, portfolio setup, etc.). Current challenges:

- **Manual Investigation:** Engineers spend 30-60 minutes per ticket querying databases, reviewing logs, comparing vendor data
- **Context Fragmentation:** Screenshots in ADO tickets are not analyzed; wiki procedures are referenced manually
- **Knowledge Silos:** Tribal knowledge not systematized; new engineers have steep learning curves
- **Repetitive Work:** 70% of tickets follow predictable patterns but require manual execution
- **Delayed Resolution:** Average ticket resolution time is 1-3 days due to investigation complexity

## Solution
Develop **Mossy**, an AI-powered MOS Support Agent with:

1. **Domain-Specific Skills** - 18+ specialized investigation skills for each support category
2. **Autonomous Investigation** - Direct database query access, log analysis, and vendor data comparison
3. **AI Vision Analysis** - Extract error messages, Excel data, and UI states from ticket screenshots
4. **Wiki Integration** - Automatically fetch and follow Azure DevOps wiki procedures
5. **ADO Automation** - Create work items, attach investigation reports, and update ticket status
6. **Workflow Orchestration** - Execute multi-step procedures (e.g., price corrections → Solvas sync → dataset refresh → position extract)

**Architecture:** VS Code Copilot Agent with Model Context Protocol (MCP) for database connectivity, Azure CLI for ADO integration, and custom skills packaged as markdown-based workflows.

## Scope – Phase 1 (Foundation)

### In Scope
- **Core Agent Framework** - Mossy agent configuration with skill discovery and invocation
- **Database Connectivity** - MSSQL MCP server for MOS, Solvas, Reference, Security Master databases
- **ADO Integration** - Fetch tickets, download attachments, create work items, update status
- **AI Vision** - Screenshot analysis for SQL errors, Excel data, UI states, log files
- **Wiki Access** - Retrieve and parse Azure DevOps wiki documentation
- **18 Production Skills** - All skills from MOSSupportSkillsBuildRoadmap.md (5 ready, 2 in dev, 11 planned)
- **Email Automation** - Outlook email processing for support requests (already functional)
- **Investigation Reports** - Markdown output with diagnostic results, root cause analysis, and remediation steps

### Out of Scope (Future Phases)
- **Automated Remediation** - Auto-execution of SQL fixes (Phase 2 - requires approval workflow)
- **Predictive Monitoring** - Proactive issue detection before tickets are filed (Phase 3)
- **Self-Service Portal** - Client-facing interface for status checks (Phase 3)
- **Multi-Tenant Support** - Expansion beyond MOS to other Siepe platforms (Phase 4)
- **Natural Language SQL** - Non-technical users writing queries in plain English (Phase 3)

## Goals
1. **Coverage:** Investigate 100% of ticket categories (11/11 categories) with specialized skills
2. **Speed:** Reduce average investigation time from 45 minutes to <5 minutes (90% reduction)
3. **Accuracy:** Achieve 95%+ accuracy in root cause identification (validated against engineer review)
4. **Automation:** Execute 80% of standard remediation workflows without human intervention
5. **User Satisfaction:** 4.5/5 rating from Back Office SQL Engineers on investigation quality

## Architecture

### Core Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Mossy Agent** | VS Code Copilot Agent (.agent.md) | Main orchestration and skill routing |
| **Skill Library** | Markdown (.skill.md files in .github/skills/) | Domain-specific investigation workflows |
| **Database Access** | MSSQL MCP Server | Query MOS, Solvas, Reference, SecurityMaster |
| **ADO Integration** | Azure CLI (az boards, az devops wiki) | Fetch tickets, download attachments, create work items |
| **AI Vision** | view_image tool | Extract text, errors, and data from screenshots |
| **Email Processor** | Microsoft Graph API via MCP | Parse Outlook emails, download attachments |
| **Report Generator** | Markdown templates | Structured investigation reports |

### New Projects
| Project | Purpose |
|---------|---------|
| `.github/skills/` | Skill definitions (18 skills covering 11 support categories) |
| `.github/agents/Mossy.agent.md` | Agent configuration with skill routing logic |
| `Investigation_*/` | Output folders for investigation reports and artifacts |
| `Planning_MOS_Support_Agent/` | Project planning documentation (this folder) |

### Existing Projects to Integrate
| Project | Integration Point |
|---------|-------------------|
| `outlook-email-extraction` | Email automation workflow (already functional) |
| `ado-mossy-review` | ADO work item review and classification |
| PowerShell scripts (`*.ps1`) | Excel analysis, query result formatting, cleanup utilities |

### Patterns to Reuse
| Pattern | Source | Usage |
|---------|--------|-------|
| **Skill Structure** | `check-market-price/SKILL.md` | Template for all 18 skills |
| **ADO Integration** | `ado-mossy-review/SKILL.md` | Ticket fetching, attachment handling |
| **Database Queries** | `Queries.sql` | Reusable SQL patterns for investigations |
| **Wiki Access** | `create-planning-wiki/SKILL.md` | Azure CLI wiki page retrieval |
| **Email Parsing** | `outlook-email-extraction/SKILL.md` | Attachment classification and routing |

## Technical Constraints

### Database Access
- **Required Databases:** MOS_Core, Solvas_AM, Reference, SecurityMaster (via MSSQL MCP)
- **Connection Security:** Windows Authentication for production databases
- **Query Performance:** Avoid full table scans; use indexed columns (InstID, RefDataSetDate, PortfolioID)
- **Transaction Limits:** Read-only access in Phase 1; write operations require approval workflow

### Azure DevOps
- **Organization:** https://siepe.visualstudio.com/
- **Project:** Siepe.Software
- **Wiki:** Siepe Wiki
- **Authentication:** Azure CLI login with PAT (Personal Access Token)

### Skill Development Standards
- **Format:** Markdown with YAML frontmatter
- **Location:** `C:\source\MD\AdminTools\.github\skills\{skill-name}/SKILL.md`
- **Required Sections:** Purpose, When to Use, Investigation Steps, Required Tools, Output Format
- **Confidence Threshold:** Each skill declares minimum confidence (0.65-0.85)
- **Error Handling:** Graceful degradation; return partial results if database unreachable

### AI Vision Integration
- **Supported Formats:** PNG, JPG, JPEG, GIF, WebP
- **Use Cases:** SQL error screenshots, Excel data snapshots, UI error dialogs, log file excerpts
- **Extraction Targets:** Error codes, table names, column values, timestamps, stack traces

### Performance Targets
- **Skill Invocation:** <10 seconds to route ticket to correct skill
- **Database Queries:** <30 seconds per investigation query
- **Screenshot Analysis:** <5 seconds per image
- **Full Investigation:** <5 minutes end-to-end (90% reduction from 45 minutes)

## Epic Structure
**Epic:** MOS Support Agent Development  
**Work Item Type:** Epic (to be created in ADO)  
**Duration:** 12 weeks (3 phases × 4 weeks)

### Features (3)
1. **Feature 1:** Agent Infrastructure & Core Skills (Phase 1 - Foundation)
2. **Feature 2:** Advanced Skills & Automation (Phase 2 - Enhancement)
3. **Feature 3:** Proactive Monitoring & Self-Service (Phase 3 - Intelligence)

### User Stories (18)
- 5 Production-ready skills (already complete)
- 2 In-development skills (Phase 1)
- 11 Planned skills (Phase 2-3)

### Estimated Task Count
- **Phase 1:** ~40 tasks (agent setup, database connectivity, 7 skills)
- **Phase 2:** ~60 tasks (11 skills, workflow automation, remediation engine)
- **Phase 3:** ~30 tasks (predictive monitoring, self-service portal, analytics)
- **Total:** ~130 tasks

## Success Metrics

### Phase 1 (Foundation)
- ✅ All 18 skills operational
- ✅ 100% ADO ticket category coverage
- ✅ <5 minute average investigation time
- ✅ 90%+ accuracy on root cause identification
- ✅ Screenshot analysis integrated in all skills

### Phase 2 (Enhancement)
- ✅ 80% automated remediation rate for standard workflows
- ✅ <2 minute average investigation time
- ✅ 95%+ accuracy on root cause identification
- ✅ Zero manual wiki lookups (auto-fetched)

### Phase 3 (Intelligence)
- ✅ Proactive issue detection (detect before ticket filed)
- ✅ Self-service status portal operational
- ✅ 50% reduction in ticket volume (issues auto-resolved)
- ✅ 4.5/5 user satisfaction rating

## Next Steps

1. **Create ADO Epic** - Generate Epic work item in Azure DevOps
2. **Create Features** - 3 features for each phase
3. **Create User Stories** - 18 user stories (one per skill)
4. **Populate Roadmap** - Define phase deliverables and dependencies
5. **Initialize Progress Tracking** - Set up task completion monitoring
6. **Upload to ADO Wiki** - Publish planning docs to /Planning/2026-07-31-mossy-agent-development/
