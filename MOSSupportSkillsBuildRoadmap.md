# MOS Support Skills Build Roadmap
## Prioritized Skill Development Based on Back Office SQL Engineers Backlog

**Created:** 2026-07-13  
**Purpose:** Identify and prioritize new skills to build based on actual ADO ticket patterns  
**Source:** MOSSupportTaskTaxonomy.md analysis + ADO backlog review

---

## Current Skill Coverage Status

### ✅ Production Ready Skills (5)
| Skill Name | Category | Tickets/Year | Priority | Status |
|-----------|----------|--------------|----------|--------|
| check-market-price | 1 - Market Pricing | ~50 | High | ✅ Ready |
| bulk-price-validation | 1A - Bulk Price Validation | ~30 | High | ✅ Ready |
| price-overrides | 1B - Price Overrides | ~20 | High | ✅ Ready |
| check-ssis-errors | 4 - SSIS/PowerShell Errors | ~150 | High | ✅ Ready |
| remove-process-dashboard-reports | 11 - Dashboard Management | ~15 | Medium | ✅ Ready |

**Total Coverage:** ~265 tickets/year (30% of ~890 annual tickets)

### 🚧 In Development (2)
| Skill Name | Category | Tickets/Year | Priority | Status |
|-----------|----------|--------------|----------|--------|
| check-cash-reconciliation | 2 - Cash Reconciliation | ~120 | Critical | 🚧 Phase 1 |
| check-data-normalization | 3 - Data Normalization | ~80 | Medium | 🚧 Phase 1 |

**Potential Coverage:** +200 tickets/year (22% more)

### 📋 To Be Built (6)
| Skill Name | Category | Tickets/Year | Priority | Phase |
|-----------|----------|--------------|----------|-------|
| check-data-feeds | 8 - Integration/Feeds | ~70 | High | Phase 2 |
| check-data-quality | 6 - Data Quality | ~60 | Medium | Phase 2 |
| setup-portfolio | 5 - Portfolio Setup | ~40 | Medium | Phase 2 |
| optimize-performance | 7 - Performance | ~30 | High | Phase 2 |
| check-workflow | 9 - Workflow/Approval | ~25 | Medium | Phase 3 |
| review-schema-change | 10 - Schema Changes | ~200 | Low | Phase 3 |

**Future Coverage:** +425 tickets/year (48% more)

**Full Implementation:** 890 tickets/year (100% coverage)

---

## Skill Recommendation Priority Matrix

Based on **Impact × Frequency × Complexity**:

| Priority Tier | Skill Name | Impact Score | Frequency | Complexity | Build Effort | ROI Score |
|--------------|------------|--------------|-----------|------------|--------------|-----------|
| **🔴 Critical** | check-cash-reconciliation | 10/10 | ~120/yr | High | 40 hrs | **95** |
| **🟠 High** | check-data-normalization | 8/10 | ~80/yr | Medium | 20 hrs | **88** |
| **🟠 High** | check-data-feeds | 8/10 | ~70/yr | Medium | 24 hrs | **82** |
| **🟡 Medium-High** | check-data-quality | 7/10 | ~60/yr | Medium | 16 hrs | **75** |
| **🟡 Medium** | optimize-performance | 9/10 | ~30/yr | High | 32 hrs | **72** |
| **🟡 Medium** | setup-portfolio | 6/10 | ~40/yr | Medium | 28 hrs | **68** |
| **🟢 Low** | check-workflow | 6/10 | ~25/yr | Low | 12 hrs | **62** |
| **🟢 Low** | review-schema-change | 4/10 | ~200/yr | Low | 8 hrs | **58** |

**ROI Score Formula:** (Impact × 5) + (Frequency/10) + (100 - Complexity×5) + (50 - Build Effort)

---

## Phase 1: Critical Operations Support (🚧 In Progress)

### 1. check-cash-reconciliation (🚧 Development)
**Category:** Cash Reconciliation  
**Annual Volume:** ~120 tickets  
**Priority:** Critical  
**Confidence Threshold:** 0.75

#### Example Task IDs for Review:
- **#70176** - "Prior Day Balance Discrepancies in Cash Rec - SQL Updates"
- **#69783** - "Balance not feeding in for MissionSquare PLUS Fund"
- **#72227** - "MMF Balances Not Feeding into MOS Portal"
- **#74168** - "Review Match groups from 3/31 QE"
- **#69410** - "Discuss Automatch matching logic for previously match"
- **#73280** - "Update Cash Rec SFR Refresh to use concurrent Imports"
- **#70536** - "Testing Cash Rec Balance Button and SFR Button Refresh"
- **#74056** - "Add ability to approve cash rec if there is a balance adjustment"
- **#71392** - "Remove Stale Balances Check for Approving Rec"

#### Key Investigation Areas:
1. **Balance Discrepancies** - Compare custodian vs. MOS balances
2. **Transaction Matching** - Auto-match logic and tolerance settings
3. **Single Fund Refresh** - SFR workflow and status checking
4. **Approval Workflow** - Business rules and blocking conditions

#### Required Database Access:
- `CashRec.vBalance` - Balance comparison
- `CashRec.vTransaction` - Transaction details
- `CashRec.vMatchGroups` - Match logic
- Custodian normalization views

#### Automation Opportunity:
- Query balance differences automatically
- Compare transaction lists side-by-side
- Identify missing/duplicate transactions
- Check SFR status and dependencies

---

### 2. check-data-normalization (🚧 Development)
**Category:** Data Normalization  
**Annual Volume:** ~80 tickets  
**Priority:** Medium  
**Confidence Threshold:** 0.70

#### Example Task IDs for Review:
- **#74076** - "Update Cash Rec Approval logic"
- **#69864** - "Update Transaction extracts for transaction type"
- **#70530** - "Update Normalization from TransactionTypes"
- **#72815** - "Review Balances Normalizations and combine union to outerapply"
- **#69952** - "Review Balances Normalizations and combine union to outerapply"
- **#70531** - "Update Position Normalization for realized gain/loss for Piks"
- **#72713** - "MOS Position Normalization Fails on T Date"

#### Key Investigation Areas:
1. **Transaction Normalization** - Transaction type mapping issues
2. **Balance Normalization** - Portfolio/account mapping
3. **Position Normalization** - Factor application and calculations

#### Required Database Access:
- Custodian transaction tables (raw data)
- Normalization views (transformation logic)
- `Reference.dbo.vTransactionType` - Type mappings
- Portfolio mapping tables

#### Automation Opportunity:
- Test normalization views with sample data
- Compare raw vs. normalized data
- Identify mapping gaps
- Generate missing mapping statements

---

## Phase 2: High-Volume Support Areas (📋 Priority)

### 3. check-data-feeds (Priority 1)
**Category:** Integration/Feed Issues  
**Annual Volume:** ~70 tickets  
**Priority:** High  
**Confidence Threshold:** 0.75

#### Example Task IDs for Review:
- **#73082** - "[Seq Error Triage] PowerShell - Sycamore file access failure"
- **#73081** - "[Seq Error Triage] PowerShell - CitiTrustee SSIS file access"
- **#69951** - "Identify failed Powershell and add BlankFile check"
- **#71082** - "FactSet - Weekend file with stale data"
- **#70724** - "[Bug Report Triage] MOS/Solvas Data Refresh - Backdated Transaction..."
- **#70672** - "[Bug Report Triage] MOS Restructure Creating Data Differences"
- **#69617** - "Citi Cash Balances for 4/6 failing"
- **#70558** - "Request for support on State Street holdings file"
- **#69407** - "JPM MMFs Missing"
- **#74078** - "Garnet Credit Management Outbound FTP CDO Suite UAT Testing"
- **#73215** - "Test Outbound USBank-Garnet Transaction"

#### Key Investigation Areas:
1. **Vendor File Import** - FTP/SFTP issues, file format validation
2. **Solvas Integration** - Data flow from Solvas to MOS
3. **Custodian File Processing** - Citi, Northern Trust, State Street, JPM
4. **Outbound Integration** - Data exports to downstream systems

#### Required Database Access:
- `Reference.dbo.vRefDataImportCurrent` - Import history
- Import job logs and status tables
- Vendor file delivery logs
- FTP/SFTP connection logs

#### Automation Opportunity:
- Check import job status automatically
- Validate file format against schema
- Test FTP/SFTP connectivity
- Identify file delivery timing issues
- Generate sample data for testing

#### Build Estimate: 24 hours
**Complexity:** Medium - Requires integration with external systems

---

### 4. check-data-quality (Priority 2)
**Category:** Data Quality Issues  
**Annual Volume:** ~60 tickets  
**Priority:** Medium  
**Confidence Threshold:** 0.70

#### Example Task IDs for Review:
- **#69622** - "Instruments Missing Identifiers"
- **#70669** - "Bad Identifiers on Assets - Bloomberg IDs Not M..."
- **#70673** - "Incorrect Identifiers and Loans Missing Bloombe..."
- **#72293** - "Remove Duplicate custodian portfoliotypes"
- **#70709** - "[Bug Report Triage] MOS - Duplicate Fund Types Created"
- **#70727** - "[Bug Report Triage] Diameter Traded Cost Calculation Discrepancy"
- **#70725** - "[Bug Report Triage] Diameter TradedMV Incorrect"
- **#73096** - "ABS Bond TradedQty not reflecting correctly"
- **#70723** - "[Bug Report Triage] MOS DW - Bad Issuer/Instrument Names"
- **#70726** - "[Bug Report Triage] MOS - Base Rate Issuers Have Incorrect Legal En..."
- **#70694** - "[Bug Report Triage] MOS - Solvas Transaction Types Too Specific"

#### Key Investigation Areas:
1. **Missing Identifiers** - CUSIP, ISIN, Bloomberg, LoanX
2. **Duplicate Records** - Deduplication logic and cleanup
3. **Calculation Discrepancies** - Market value, gain/loss, accruals
4. **Reference Data Issues** - Issuers, legal entities, transaction types

#### Required Database Access:
- `Core.dbo.vInst` - Instrument details
- `Reference.dbo.vInstIdentifierCurrent` - Identifiers
- `Core.dbo.vPosition` - Position data
- Reference data tables (issuers, legal entities, etc.)

#### Automation Opportunity:
- Scan for missing identifiers by asset type
- Identify duplicate records with key analysis
- Validate calculations with test cases
- Cross-reference with vendor data
- Generate correction scripts

#### Build Estimate: 16 hours
**Complexity:** Medium - Pattern recognition and validation logic

---

### 5. optimize-performance (Priority 3)
**Category:** Performance Issues  
**Annual Volume:** ~30 tickets  
**Priority:** High  
**Confidence Threshold:** 0.80

#### Example Task IDs for Review:
- **#72350** - "[Slow Query Triage] adhoc:1bf679273aa5 ID-check"
- **#72349** - "[Slow Query Triage] adhoc:98f7fd08cc42 (SecMaster) - avg 47060ms"
- **#72338** - "[Slow Query Triage] dbo.pRefDataSetIU (Elmwood) - avg 72302ms"
- **#69346** - "[Slow Query Triage] solvas_am.pTransactionLoader (MOS) - avg 232509ms"
- **#69298** - "[Seq Error Triage] PowerShell - Onex SSIS deadlock on Script Task"

#### Key Investigation Areas:
1. **Slow Query Analysis** - Execution plans, index usage
2. **Deadlock Detection** - Lock order analysis
3. **Timeout Issues** - Long-running queries, blocking
4. **Resource Contention** - CPU, memory, I/O bottlenecks

#### Required Database Access:
- `sys.dm_exec_query_stats` - Query statistics
- `sys.dm_exec_requests` - Current requests
- Execution plan analysis
- Extended events for deadlocks
- Performance monitoring tables

#### Automation Opportunity:
- Capture execution plans automatically
- Identify table scans and missing indexes
- Analyze wait statistics
- Generate index recommendations
- Review query patterns

#### Build Estimate: 32 hours
**Complexity:** High - Requires deep SQL Server performance expertise

---

### 6. setup-portfolio (Priority 4)
**Category:** Portfolio/Fund Setup  
**Annual Volume:** ~40 tickets  
**Priority:** Medium  
**Confidence Threshold:** 0.80

#### Example Task IDs for Review:
- **#71329** - "Setup New Company: MidCap Financial Services"
- **#72701** - "New Solvas Portfolio for Citi Compliance - Shizen Funding Ldt."
- **#72833** - "Bryant Park Citi Master WH Ltd."
- **#74027** - "5) update Parent relationship in CA PEARL POINT CLO, LTD."
- **#70535** - "Update Ledger Portfolio map to only allow one ledger"
- **#73258** - "Name Change: Project Quacker to APD Acquisitions Fund in MOS"
- **#73492** - "2) MOS DW Name Change: Pearl Point CLO, Ltd MOS to Garnet CLO 6"

#### Key Investigation Areas:
1. **New Company Setup** - Complete configuration checklist
2. **Fund/Portfolio Mapping** - Parent/child relationships
3. **Name Changes** - Cross-system updates

#### Required Database Access:
- `Employee.tCompany` - Company records
- `Core.dbo.tFund` - Fund records
- `Core.dbo.tPortfolio` - Portfolio records
- `Core.dbo.tCompanyPortfolioMap` - Portfolio mappings
- `Core.dbo.tPositionPriceWeighting` - Price weighting config
- Cash rec configuration tables

#### Automation Opportunity:
- Generate company setup checklist
- Validate configuration completeness
- Test data flows after setup
- Generate SQL statements for setup steps
- Cross-system name change coordination

#### Build Estimate: 28 hours
**Complexity:** Medium - Multi-system coordination required

---

## Phase 3: Workflow & Maintenance (📋 Lower Priority)

### 7. check-workflow (Priority 5)
**Category:** Workflow/Approval  
**Annual Volume:** ~25 tickets  
**Priority:** Medium  
**Confidence Threshold:** 0.70

#### Example Task IDs for Review:
- **#74056** - "Add ability to approve cash rec if there is a balance adjustment"
- **#71392** - "Remove Stale Balances Check for Approving Rec"
- **#73109** - "Review workflow with support / OPs"
- **#70178** - "Modify Balance Refresh / SFR Workflow"

#### Key Investigation Areas:
1. **Cash Rec Approval** - Business rules and blocking conditions
2. **Single Fund Refresh** - Component dependencies and state
3. **Record Locking** - SOX locking issues

#### Required Database Access:
- `CashRec` approval tables
- SFR status tables
- Workflow state tables
- Lock status queries

#### Automation Opportunity:
- Check workflow state automatically
- Validate business rules
- Review component dependencies
- Identify locking issues

#### Build Estimate: 12 hours
**Complexity:** Low-Medium - State machine analysis

---

### 8. review-schema-change (Priority 6)
**Category:** Database Schema Changes  
**Annual Volume:** ~200 tickets  
**Priority:** Low  
**Confidence Threshold:** 0.90

#### Example Task IDs for Review:
- Hundreds of "Database Release" work items
- Pattern: "2025-11-XX-[ObjectName] - [Environment]"
- **#72246** - "Create Cash Rec Schema tables and IU / Views"
- **#72248** - "Drop / Deprecate old tables"

#### Key Investigation Areas:
1. **Stored Procedure Deployment** - Code review and testing
2. **Table Schema Changes** - Migration scripts and rollback
3. **View/Function Updates** - Logic validation

#### Required Database Access:
- Database schema metadata
- Deployment scripts
- Version control integration

#### Automation Opportunity:
- Validate SQL syntax automatically
- Check for breaking changes
- Generate deployment checklists
- Test scripts in isolated environment
- Document changes automatically

#### Build Estimate: 8 hours
**Complexity:** Low - Primarily validation and documentation

---

## Build Prioritization Recommendation

### Immediate (Next 2 Sprints)
1. ✅ **Complete check-cash-reconciliation** (Critical, 120 tickets/yr)
2. ✅ **Complete check-data-normalization** (High, 80 tickets/yr)

### Short-Term (Next Quarter)
3. **Build check-data-feeds** (High priority, 70 tickets/yr, moderate complexity)
4. **Build check-data-quality** (Medium priority, 60 tickets/yr, lower complexity)

### Medium-Term (Next 6 Months)
5. **Build setup-portfolio** (Medium priority, 40 tickets/yr, moderate complexity)
6. **Build optimize-performance** (High impact, 30 tickets/yr, high complexity)

### Long-Term (Next Year)
7. **Build check-workflow** (Low priority, 25 tickets/yr, low complexity)
8. **Build review-schema-change** (High volume but low complexity, 200 tickets/yr)

---

## Skill Development Checklist Template

For each skill to build, follow this template:

### [Skill Name]

#### 1. Requirements Gathering
- [ ] Review all example task IDs listed above
- [ ] Extract common investigation patterns
- [ ] Document required database queries
- [ ] Identify automation opportunities
- [ ] Define success criteria

#### 2. Skill Structure
- [ ] Create `.github/skills/[skill-name]/SKILL.md`
- [ ] Add YAML frontmatter with confidence threshold
- [ ] Write "Purpose" and "When to Use" sections
- [ ] Add "Requirements Validation" section
- [ ] Document investigation workflow (steps)
- [ ] Include database queries with examples
- [ ] Add troubleshooting guide
- [ ] Document expected output format

#### 3. Testing & Validation
- [ ] Test with 3-5 actual tickets from example list
- [ ] Verify database queries return correct results
- [ ] Validate PowerShell scripts execute successfully
- [ ] Test requirements validation logic
- [ ] Confirm output format matches needs

#### 4. Integration
- [ ] Update MOSSupportTaskTaxonomy.md with skill status
- [ ] Add skill to routing table in MOSBackOfficeSupport.md
- [ ] Update agent invocation keywords
- [ ] Test agent routing to new skill
- [ ] Document in README.md

#### 5. Documentation
- [ ] Add example ticket investigation walkthrough
- [ ] Document common error patterns
- [ ] Create troubleshooting guide
- [ ] Add performance optimization tips
- [ ] Document ADO posting format

---

## Key Success Metrics

### Coverage Metrics
- **Current:** 265 tickets/year (30% coverage)
- **Phase 1 Complete:** 465 tickets/year (52% coverage) 
- **Phase 2 Complete:** 665 tickets/year (75% coverage)
- **Phase 3 Complete:** 890 tickets/year (100% coverage)

### Time Savings Estimates
- **Average manual investigation time:** 2-4 hours per ticket
- **Average skill-automated time:** 15-30 minutes per ticket
- **Time savings per ticket:** 1.5-3.5 hours
- **Annual time savings at 100% coverage:** ~2,200-3,100 hours

### Quality Improvements
- Consistent investigation methodology
- Reduced human error
- Standardized documentation
- Faster response times
- Better knowledge retention

---

## Next Steps

1. **Review Task IDs:** Examine the specific tickets listed for each skill category
2. **Prioritize by Business Need:** Align with team priorities and quarterly goals
3. **Start with Quick Wins:** check-data-quality and check-workflow are lower complexity
4. **Build Incrementally:** Complete skills in phases, test thoroughly
5. **Gather Feedback:** Use initial skills to refine development approach

---

## Appendix: Full Task ID Reference

### Category 1: Market Pricing (✅ Skills Complete)
- #82115, #74046, #73505, #71075 (check-market-price)
- #82309 (bulk-price-validation)
- #82685 (price-overrides)

### Category 2: Cash Reconciliation (🚧 In Development)
- #70176, #69783, #72227, #74168, #69410, #73280, #70536, #74056, #71392

### Category 3: Data Normalization (🚧 In Development)
- #74076, #69864, #70530, #72815, #69952, #70531, #72713

### Category 4: SSIS Errors (✅ Skill Complete)
- #74228, #74087, #74003, #74007, #70606, #73082, #73081, #69298

### Category 5: Portfolio Setup (📋 To Build)
- #71329, #72701, #72833, #74027, #70535, #73258, #73492

### Category 6: Data Quality (📋 To Build)
- #69622, #70669, #70673, #72293, #70709, #70727, #70725, #73096, #70723, #70726, #70694

### Category 7: Performance (📋 To Build)
- #72350, #72349, #72338, #69346, #69298

### Category 8: Integration/Feeds (📋 To Build)
- #73082, #73081, #69951, #71082, #70724, #70672, #69617, #70558, #69407, #74078, #73215

### Category 9: Workflow (📋 To Build)
- #74056, #71392, #73109, #70178

### Category 10: Schema Changes (📋 To Build)
- #72246, #72248 + hundreds of "Database Release" items

### Category 11: Dashboard Management (✅ Skill Complete)
- #82117

---

**End of Roadmap**
