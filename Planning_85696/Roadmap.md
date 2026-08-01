# ROADMAP: MOS Support Agent Automation – Mossy

## Overview
Mossy's development follows a phased approach prioritizing high-impact, frequently-used investigation skills first. Phase 1 focuses on critical support categories (pricing, SSIS, email automation) that account for 60% of support tickets. Phase 2 adds cash reconciliation and data quality checks. Phase 3 enables performance optimization and vendor file monitoring. Each phase delivers immediately usable skills that reduce manual investigation time.

## Architecture Decision
Skills are self-contained markdown documents with YAML frontmatter for invocation patterns, eliminating complex routing logic. The MOSSupportTaskTaxonomy provides keyword-based routing with confidence scoring. Each skill outputs structured markdown reports following standardized templates. PipeWatch dashboard uses enriched JSON for real-time job monitoring without database polling overhead. Email automation uses Microsoft Graph API with AI vision for screenshot analysis.

---

## Phase 1: Critical Support Automation (COMPLETE ✅)
**Goal:** Automate the three highest-volume support categories: pricing issues, SSIS errors, and email-driven ticket creation.

**Research:** No – Reuses existing SQL queries and investigation procedures already documented.

**Dependencies:** None

**Deliverables:**
- ✅ bulk-price-validation skill (compare vendor prices across MOS/Solvas/SecurityMaster)
- ✅ check-market-price skill (trace pricing source hierarchy, ICE/Markit/LSEG investigation)
- ✅ check-ssis-errors skill with Silent Success Failure pattern detection
- ✅ outlook-email-extraction v2.0 with complete workflow automation
- ✅ process-mos-support-emails skill (parse emails, invoke Mossy, create ADO work items)
- ✅ user-story-task-creation skill (generate child tasks with assignments)
- ✅ create-planning-wiki skill (generate Azure DevOps documentation)
- ✅ daily-standup-report skill (sprint board summary)
- ✅ MOSSupportTaskTaxonomy with keyword routing and confidence scoring

**Success Signal:** 
- Mossy successfully investigates price exceptions end-to-end (task #82115 validation)
- SSIS silent failure pattern detected in GenericPushInstDebt.dtsx investigation
- Email automation creates ADO work items with correct parent User Story linkage
- Planning wiki documentation generated for Mossy agent itself

**Completed:** 2026-07-29

---

## Phase 2: Data Quality & Cash Reconciliation (IN PROGRESS 🚧)
**Goal:** Automate cash balance reconciliation and data normalization validation, which are time-consuming and error-prone when done manually.

**Research:** Yes – Cash reconciliation requires understanding SFR (Statement of Financial Record) table structure and balance rollforward logic.

**Dependencies:** Phase 1 (taxonomy and skill framework must be established)

**Deliverables:**
- 🚧 cash-reconciliation skill (SFR balance validation, discrepancy detection)
- 🚧 data-normalization skill (validate Solvas → MOS feed mappings)
- 📋 data-quality skill (missing data detection, integrity checks)
- 📋 portfolio-setup skill (new company/fund configuration validation)

**Success Signal:**
- Mossy detects balance discrepancies within 5 minutes of feed import
- Normalization issues identified before users report missing attributes
- Portfolio setup validation prevents configuration errors

**Target Completion:** 2026-08-15

---

## Phase 3: Performance & Monitoring (PLANNED 📋)
**Goal:** Enable Mossy to diagnose slow queries, optimize database performance, and monitor vendor file deliveries proactively.

**Research:** Yes – Performance optimization requires query execution plan analysis and index recommendation logic.

**Dependencies:** Phase 2 (data quality checks must be working to avoid false positives)

**Deliverables:**
- 📋 performance-optimization skill (slow query analysis, index recommendations)
- 📋 import-file-investigation skill (vendor file delivery tracking, FTP/SFTP log analysis)
- 📋 job-resequencing skill (Script Adapter dependency analysis, execution order validation)
- 📋 PipeWatch advanced features (SLA tracking, custom alerts, REST API)

**Success Signal:**
- Mossy identifies missing vendor files within 1 hour of expected delivery
- Query performance recommendations reduce execution time by 50%+
- PipeWatch alerts on job failures before users report data issues

**Target Completion:** 2026-09-15

---

## Phase 4: Autonomous Remediation (FUTURE 🔮)
**Goal:** Move beyond investigation to automated remediation – Mossy fixes issues without human intervention where safe to do so.

**Research:** Yes – Requires extensive testing and rollback mechanisms.

**Dependencies:** Phases 1-3 (investigation must be 95%+ accurate before attempting automated fixes)

**Deliverables:**
- Automated price override application (with approval workflow)
- SSIS package parameter correction (for silent success failures)
- Automatic ledger unmapping for stale references
- Self-healing Script Adapter retry logic
- Machine learning for pattern detection and anomaly alerting

**Success Signal:**
- 80% of routine issues resolved without human intervention
- Zero incidents caused by automated remediation
- Mean time to resolution (MTTR) reduced from hours to minutes

**Target Completion:** 2027-Q1

---

## Phase Summary

| Phase | Title | Research | Dependencies | Est. Complexity | Status | Target |
|-------|-------|----------|--------------|-----------------|--------|--------|
| 1 | Critical Support Automation | No | – | Medium | ✅ Complete | 2026-07-29 |
| 2 | Data Quality & Cash Reconciliation | Yes | 1 | High | 🚧 In Progress | 2026-08-15 |
| 3 | Performance & Monitoring | Yes | 2 | High | 📋 Planned | 2026-09-15 |
| 4 | Autonomous Remediation | Yes | 1, 2, 3 | Very High | 🔮 Future | 2027-Q1 |

---

## Recent Wins (Week of 2026-07-29)

**Silent Success Failure Detection:**
- Discovered new SSIS failure pattern where packages return SUCCESS but process 0 rows
- GenericPushInstDebt.dtsx executed in 1.469 seconds (expected 5-10 seconds for 11,024 records)
- Created 13-day data backlog for InstDebt pipeline
- Enhanced check-ssis-errors skill with detection methodology
- Updated taxonomy with silent failure keywords

**InstDebt Investigation:**
- Resolved missing SeniorityType for bond CUSIP 21871DAG8 (Corelogic)
- Root cause: SSIS parameter not mapped to OLE DB Source query
- Manual stored procedure insert unblocked user
- Created InstDebt_CompletePush.ps1 automation script
- Documented complete investigation in management email

**Planning Documentation:**
- Created create-planning-wiki skill for Azure DevOps
- Generated planning documents for Mossy agent itself (meta!)
- Added category 14 to taxonomy for planning-related tickets

---

## Key Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Skills Ready | 9 | 15 (Phase 3) |
| Average Investigation Time | 15 min | 3 min |
| Tickets Automated | 40% | 60% (Phase 2) |
| Silent Failure Detection Time | 13 days | < 1 hour |
| Email Auto-Classification | 90% | 95% |
| Planning Doc Generation Time | Manual (2 hours) | Automated (5 min) |
