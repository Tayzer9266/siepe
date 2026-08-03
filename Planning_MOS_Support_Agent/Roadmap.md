# ROADMAP: MOS Support Agent Development – Mossy

## Overview
The MOS Support Agent (Mossy) will be developed in 3 phases over 12 weeks, transitioning from manual ticket investigation to fully autonomous resolution with proactive monitoring. The architecture leverages VS Code Copilot Agent framework with Model Context Protocol (MCP) for database connectivity and Azure CLI for ADO integration.

## Architecture Decision

**Why VS Code Copilot Agent?**
- ✅ **Native Tool Integration** - Direct access to databases (MSSQL MCP), Azure DevOps (Azure CLI), file systems, and AI vision
- ✅ **Skill Modularity** - Each support category becomes a standalone `.skill.md` file with clear routing logic
- ✅ **Context Awareness** - Automatically includes workspace files, terminal output, and investigation history
- ✅ **Extensibility** - Easy to add new skills as support categories evolve
- ✅ **Developer Experience** - Engineers can invoke Mossy from VS Code where they already work

**Key Design Principles:**
1. **Read-Only First** - Phase 1 focuses on investigation; Phase 2 adds remediation with approval
2. **Database-Driven** - All investigations query production databases directly (no middleware)
3. **Wiki-Grounded** - Follow existing Azure DevOps wiki procedures; don't reinvent workflows
4. **Screenshot-Aware** - Extract context from ADO ticket attachments (error messages, Excel data, UI states)
5. **Markdown Output** - All investigations generate structured markdown reports for engineer review

---

## Phase 1: Foundation – Agent Infrastructure & Core Skills
**Duration:** 4 weeks  
**Goal:** Operational agent with database connectivity, ADO integration, and 7 core skills covering 48% of ticket volume  
**Research:** Minimal (reuse existing PowerShell queries and wiki procedures)  
**Dependencies:** None

### Deliverables

#### 1.1 Agent Framework (Week 1)
- **Task:** Create `Mossy.agent.md` configuration
- **Components:**
  - Skill routing logic (match ticket description to skill)
  - Confidence threshold tuning (0.65-0.85 per skill)
  - ArgumentHint parser (extract ticket ID, identifiers, dates)
  - Error handling (graceful degradation if database unreachable)
- **Acceptance Criteria:** `@Mossy investigate #82115` correctly routes to `check-market-price` skill

#### 1.2 Database Connectivity (Week 1)
- **Task:** Configure MSSQL MCP server
- **Databases:**
  - MOS_Core (mos-sql-p.mos.siepe.local,52155)
  - Solvas_AM (solvas connection string)
  - Reference (Reference database)
  - SecurityMaster (securitymastertools.siepe.local)
- **Test Queries:**
  - Fetch position mark from `core.dbo.vposition`
  - Fetch vendor prices from `Reference.dbo.vinstpricecurrentraw`
  - Fetch Solvas prices from `solvas_am.dbo.deal_facility_market_value`
- **Acceptance Criteria:** Execute all queries from `Queries.sql` successfully

#### 1.3 ADO Integration (Week 1)
- **Task:** Implement Azure CLI ticket workflow
- **Functions:**
  - Fetch ticket details: `az boards work-item show --id {ticketId}`
  - Download attachments from ADO ticket
  - Create child tasks: `az boards work-item create --type Task --parent {ticketId}`
  - Update ticket status: `az boards work-item update --id {ticketId} --state "In Progress"`
- **Acceptance Criteria:** Download screenshot from ADO ticket and analyze with `view_image`

#### 1.4 AI Vision Integration (Week 1-2)
- **Task:** Add screenshot analysis to all skills
- **Extraction Targets:**
  - SQL error codes (e.g., "Invalid object name 'dbo.tPrice'")
  - Excel cell values (e.g., CUSIP, Position Mark, Vendor Bid)
  - UI error messages (e.g., "Cash Rec approval blocked")
  - Log file timestamps and stack traces
- **Acceptance Criteria:** Extract error message from SSIS screenshot and include in investigation report

#### 1.5 Wiki Integration (Week 2)
- **Task:** Fetch and parse Azure DevOps wiki pages
- **Command:** `az devops wiki page show --wiki "Siepe Wiki" --path "/Price-Exception-..."`
- **Target Pages:**
  - `/Price-Exception-Not-Matching-MarkIT-ICE-or-ICE-OR-NULL-Marks`
  - `/Cash-Reconciliation-Procedures`
  - `/SSIS-Troubleshooting-Guide`
- **Acceptance Criteria:** Investigation report includes "Following wiki procedure: {wiki_path}"

#### 1.6 Core Skills - Production Ready (Week 2-3)
**Already complete - validate integration:**
- ✅ `check-market-price` - Market pricing investigations (~50 tickets/year)
- ✅ `bulk-price-validation` - Bulk price exception reviews (~30 tickets/year)
- ✅ `price-overrides` - Manual price override workflows (~20 tickets/year)
- ✅ `check-ssis-errors` - SSIS package failure diagnosis (~150 tickets/year)
- ✅ `remove-process-dashboard-reports` - Dashboard cleanup (~15 tickets/year)

#### 1.7 Core Skills - In Development (Week 3-4)
- 🚧 `check-cash-reconciliation` - Balance discrepancies, transaction matching (~120 tickets/year)
  - **Tasks:** Map CashRec schema, create query templates, add SFR approval logic
  - **Wiki:** `/Cash-Reconciliation-Procedures`
- 🚧 `check-data-normalization` - Transaction/balance/position mapping (~80 tickets/year)
  - **Tasks:** Map custodian views, detect mapping gaps, suggest fixes
  - **Wiki:** `/Feed-Mapping-Standards`

### Success Signal
✅ Mossy investigates all 7 skill categories  
✅ Generates markdown reports with root cause + remediation steps  
✅ Screenshot analysis extracts SQL errors and Excel data  
✅ Wiki procedures auto-fetched and followed  
✅ <5 minute average investigation time  
✅ 90%+ accuracy on root cause identification (validated by engineers)

---

## Phase 2: Enhancement – Advanced Skills & Automation
**Duration:** 6 weeks  
**Goal:** 100% ticket category coverage, automated remediation workflows, and <2 minute investigation time  
**Research:** Moderate (requires workflow orchestration design)  
**Dependencies:** Phase 1 complete (agent operational)

### Deliverables

#### 2.1 Advanced Skills (Week 5-8)
- 📋 `check-data-feeds` - FTP/SFTP issues, vendor file validation (~70 tickets/year)
  - **Tasks:** Check import job status, validate file format, test connectivity
  - **Wiki:** `/Vendor-File-Delivery-Locations`
- 📋 `check-data-quality` - Missing identifiers, duplicates (~60 tickets/year)
  - **Tasks:** Detect duplicate records, find missing identifiers
  - **Wiki:** `/Data-Quality-Standards`
- 📋 `setup-portfolio` - New fund onboarding (~40 tickets/year)
  - **Tasks:** Validate portfolio setup, check configuration
  - **Wiki:** `/Portfolio-Onboarding-Checklist`
- 📋 `optimize-performance` - Slow queries, execution plans (~30 tickets/year)
  - **Tasks:** Analyze query plans, suggest indexes
  - **Wiki:** `/Performance-Tuning-Guide`
- 📋 `check-workflow` - Approval workflow issues (~25 tickets/year)
  - **Tasks:** Validate workflow state, check business rules
  - **Wiki:** `/Workflow-Configuration`
- 📋 `review-schema-change` - Database schema reviews (~200 tickets/year)
  - **Tasks:** Impact analysis, dependency checking
  - **Wiki:** `/Schema-Change-Policy`

#### 2.2 Automated Remediation Engine (Week 7-8)
- **Task:** Execute standard fixes with approval workflow
- **Workflows:**
  - Price correction → Solvas sync → dataset refresh → position extract
  - Cash rec auto-match → SFR approval → balance validation
  - SSIS package retry → log analysis → success confirmation
- **Approval Logic:**
  - Low-risk fixes: Auto-execute (e.g., SSIS retry)
  - Medium-risk fixes: Request engineer approval (e.g., price override)
  - High-risk fixes: Manual only (e.g., schema change)
- **Acceptance Criteria:** Execute price correction workflow end-to-end without human intervention

#### 2.3 Workflow Orchestration (Week 8-9)
- **Task:** Multi-step procedure execution
- **Example Workflow - Price Correction:**
  1. Detect price mismatch (check-market-price)
  2. Update Security Master (run RS 700002320)
  3. Wait 15 mins for file pickup
  4. Sync to Solvas (run pSolvasExportPriceEntity)
  5. Refresh datasets (trigger dataset refresh)
  6. Generate position extract (run pPositionExtract)
  7. Validate final position mark
- **Acceptance Criteria:** Execute workflow with status updates at each step

#### 2.4 Image Analysis Enhancement (Week 9-10)
- **Task:** Advanced screenshot parsing
- **Features:**
  - OCR for handwritten notes on screenshots
  - Table extraction from Excel screenshots (read entire grid)
  - Multi-page PDF analysis (combine context from multiple attachments)
  - Error message fuzzy matching (detect similar errors across tickets)
- **Acceptance Criteria:** Extract full Excel table from screenshot and compare with database

### Success Signal
✅ 100% ticket category coverage (13/13 skills operational)  
✅ 80% automated remediation rate for standard workflows  
✅ <2 minute average investigation time  
✅ 95%+ accuracy on root cause identification  
✅ Zero manual wiki lookups (all procedures auto-fetched)  
✅ Multi-step workflows execute without human intervention

---

## Phase 3: Intelligence – Proactive Monitoring & Self-Service
**Duration:** 2 weeks  
**Goal:** Detect issues before tickets are filed; reduce ticket volume by 50%  
**Research:** High (requires predictive modeling)  
**Dependencies:** Phase 2 complete (all workflows automated)

### Deliverables

#### 3.1 Proactive Monitoring (Week 11)
- **Task:** Scheduled issue detection
- **Monitors:**
  - **Price Monitoring:** Detect vendor price gaps >5% before cash rec
  - **SSIS Monitoring:** Alert on package failures within 5 mins
  - **Balance Monitoring:** Flag custodian balance discrepancies daily
  - **Data Quality Monitoring:** Detect missing identifiers on new instruments
- **Alert Mechanism:**
  - Create ADO ticket automatically with investigation pre-attached
  - Email notification to Back Office SQL Engineers
  - Slack integration (optional)
- **Acceptance Criteria:** Detect price issue 1 day before client reports it

#### 3.2 Self-Service Portal (Week 11-12)
- **Task:** Client-facing status dashboard
- **Features:**
  - Check ticket status (In Progress, Under Investigation, Resolved)
  - View investigation reports (markdown preview)
  - Download artifacts (Excel files, SQL scripts)
  - Request manual review (escalate to engineer)
- **Tech Stack:** Simple web UI (React) or PowerBI dashboard
- **Acceptance Criteria:** Client views ticket status without emailing engineer

#### 3.3 Analytics Dashboard (Week 12)
- **Task:** Mossy performance metrics
- **Metrics:**
  - Ticket volume by category (line chart)
  - Investigation time (average, median, p95)
  - Accuracy rate (% of investigations confirmed by engineers)
  - Automation rate (% of tickets auto-resolved)
  - User satisfaction (4.5/5 target)
- **Visualization:** PowerBI dashboard or Grafana
- **Acceptance Criteria:** Real-time dashboard shows all metrics

### Success Signal
✅ Proactive issue detection operational (50% ticket reduction)  
✅ Self-service portal deployed  
✅ Analytics dashboard shows 95%+ accuracy  
✅ 4.5/5 user satisfaction rating from engineers  
✅ <1 minute average investigation time

---

## Phase Summary

| Phase | Title | Research | Dependencies | Est. Complexity | Duration | User Stories | Deliverables |
|-------|-------|----------|--------------|-----------------|----------|--------------|--------------|
| 1 | Foundation – Agent Infrastructure & Core Skills | No | – | Medium | 4 weeks | 7 | Agent framework, DB connectivity, 7 skills, ADO integration, AI vision |
| 2 | Enhancement – Advanced Skills & Automation | Yes | Phase 1 | High | 6 weeks | 11 | 11 skills, remediation engine, workflow orchestration, enhanced image analysis |
| 3 | Intelligence – Proactive Monitoring | Yes | Phase 2 | High | 2 weeks | 3 | Proactive monitors, self-service portal, analytics dashboard |

**Total Duration:** 12 weeks  
**Total User Stories:** 21  
**Total Tasks (Estimated):** ~130

---

## Risk Mitigation

### High Risk: Database Performance
- **Risk:** Query performance degrades on large tables
- **Mitigation:** Use indexed columns (InstID, RefDataSetDate); limit result sets; implement query timeouts

### Medium Risk: MSSQL MCP Connectivity
- **Risk:** MSSQL MCP server loses connection to production databases
- **Mitigation:** Implement retry logic; fallback to read-only replica; cache common queries

### Medium Risk: Screenshot Quality
- **Risk:** Low-resolution or obfuscated screenshots prevent text extraction
- **Mitigation:** Request higher-resolution uploads; use OCR fallback; manual review for critical tickets

### Low Risk: Skill Routing Accuracy
- **Risk:** Mossy routes ticket to wrong skill
- **Mitigation:** Confidence thresholds (0.65-0.85); manual override option; user feedback loop

---

## Success Criteria by Phase

### Phase 1 Success (Foundation)
- [ ] Mossy agent operational in VS Code
- [ ] All 7 core skills generate investigation reports
- [ ] <5 minute average investigation time
- [ ] 90%+ root cause accuracy
- [ ] Screenshot analysis integrated

### Phase 2 Success (Enhancement)
- [ ] All 18 skills operational (100% category coverage)
- [ ] 80% automated remediation rate
- [ ] <2 minute average investigation time
- [ ] 95%+ root cause accuracy
- [ ] Multi-step workflows execute autonomously

### Phase 3 Success (Intelligence)
- [ ] Proactive monitoring detects issues before tickets filed
- [ ] 50% ticket volume reduction
- [ ] Self-service portal deployed
- [ ] Analytics dashboard operational
- [ ] 4.5/5 user satisfaction rating

---

## Next Steps

1. **Kickoff Meeting** - Review roadmap with Back Office SQL Engineers team
2. **Create ADO Work Items** - Epic, Features, User Stories (see Work Items.md)
3. **Begin Phase 1 Development** - Start with Agent Framework (Week 1)
4. **Schedule Weekly Demos** - Show progress to stakeholders every Friday
5. **Upload to ADO Wiki** - Publish this document to /Planning/2026-07-31-mossy-agent-development/Roadmap
