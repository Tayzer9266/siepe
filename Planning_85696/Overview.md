# PROJECT: MOS Support Agent Automation (Mossy)

## Vision
Transform MOS back office support from reactive manual investigation to proactive automated resolution by enabling the Mossy AI agent to autonomously triage, investigate, and resolve common support tickets through intelligent database queries, root cause analysis, and automated remediation workflows. Reduce support response time from hours to minutes and eliminate repetitive manual investigation tasks.

## Problem Statement
MOS back office support engineers spend 60-70% of their time on repetitive investigation tasks: checking price sources, reconciling cash balances, diagnosing SSIS failures, validating data quality, and tracing vendor file deliveries. These investigations follow predictable patterns but require manual SQL queries, log analysis, and cross-system correlation. Support tickets pile up during peak periods, causing delays in issue resolution and impacting client satisfaction. Critical patterns like "silent success failures" in SSIS packages go undetected for days because there's no automated monitoring.

## Solution
Deploy Mossy, an AI-powered support agent with specialized skills for each major support category. Each skill encodes expert investigation procedures as automated workflows that query databases, analyze logs, correlate data across systems, and generate detailed root cause reports. Mossy integrates with Azure DevOps to automatically create and assign work items based on email-driven support requests. The PipeWatch dashboard provides real-time ETL pipeline monitoring, alerting on anomalies before users report issues. Skills are continuously enhanced based on lessons learned from actual investigations.

## Scope – Phase 1 (Foundation)

### In Scope
- **9 Core Investigation Skills**: Price exceptions, cash reconciliation, data normalization, SSIS errors, portfolio setup, performance optimization, vendor file monitoring, work item creation, email automation
- **Automated Email Processing**: Parse mos-support inbox, extract ticket details, classify as Bug/Task, invoke appropriate skill, create ADO work items with proper parent linkage
- **PipeWatch Dashboard**: Real-time ETL job monitoring with failure alerts, execution history, environment filtering, and Seq log integration
- **Knowledge Base**: MOSSupportTaskTaxonomy with keyword-to-skill routing, common error patterns, SQL query templates
- **Skill Enhancement Framework**: Lessons learned from investigations automatically added to skill documentation (e.g., "silent success failure" pattern)
- **Azure DevOps Integration**: Work item creation, task assignment, status tracking, standup report generation

### Out of Scope (Future Phases)
- Automated remediation beyond investigation (Phase 2)
- Machine learning for pattern detection (Phase 3)
- Cross-tenant issue correlation (Phase 3)
- Self-healing SSIS package modification (Phase 4)
- Integration with ServiceNow or other ticketing systems

## Goals
1. **Reduce Investigation Time by 80%**: Typical price exception investigation from 30 minutes to 5 minutes
2. **Detect Silent Failures Within 1 Hour**: PipeWatch alerts on SSIS "silent success" patterns before users report missing data
3. **Automate 60% of Support Tickets**: Mossy handles routine investigations end-to-end without human intervention
4. **Zero Manual Email Classification**: All mos-support emails automatically parsed, classified, and routed
5. **95% Skill Accuracy**: Investigation reports match manual SQL engineer analysis

## Architecture

### Existing Projects
| Project | Purpose |
|---------|---------|
| c:\source\MD\AdminTools\.github\skills\ | Mossy's skill library with 15+ specialized investigation procedures |
| c:\source\PipeWatch\ | Real-time ETL orchestration monitoring dashboard (React + Node.js) |
| c:\source\Outlook\ | Outlook email extraction and automation scripts (PowerShell + Microsoft Graph API) |

### Files Modified
| File | Change |
|------|--------|
| AdminTools\.github\skills\check-ssis-errors\SKILL.md | Added "Silent Success Failure" pattern detection (2026-07-29) |
| AdminTools\MOSSupportTaskTaxonomy.md | Added category 14 (planning wiki), updated SSIS keywords |
| AdminTools\.github\skills\create-planning-wiki\SKILL.md | New skill for generating Azure DevOps planning documentation |
| AdminTools\.github\skills\outlook-email-extraction\SKILL.md | v2.0 - Complete workflow automation with AI vision and Mossy integration |

### Patterns to Reuse
| Pattern | Source |
|---------|--------|
| Skill-based investigation routing | MOSSupportTaskTaxonomy keyword mapping with confidence scoring |
| YAML frontmatter metadata | All skill files use standardized frontmatter for when_user_mentions patterns |
| Root cause markdown templates | check-ssis-errors outputs structured investigation reports |
| PowerShell + Azure CLI automation | outlook-email-extraction, daily-standup-report skills |
| Real-time data enrichment | PipeWatch job-names-list-enriched.json with execution history |

## Technical Constraints
- **Language Model**: Claude Sonnet 4.5 via GitHub Copilot
- **Database Access**: SQL Server via sqlcmd (MOS-SQL-P, SOLVAS-SQL-P servers)
- **Azure DevOps CLI**: Required for work item queries and wiki page creation
- **PowerShell 7+**: Cross-platform script execution
- **Microsoft Graph API**: Outlook email access with delegated permissions
- **Seq Logs**: Real-time log ingestion for SSIS error correlation
- **No Production Write Access**: Mossy investigates and reports but does not modify production data directly
- **Authentication**: Azure CLI must be pre-authenticated (az login)
- **Skill Documentation Standard**: All skills follow SKILL.md format with YAML frontmatter

## Feature
ADO #85696 – MOS Support Agent Automation
https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/85696
