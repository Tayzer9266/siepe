# Work Items

**Created:** 2026-07-31  
**Developer:** Tay Nguyen  
**Epic:** MOS Support Agent Development (Mossy)  
**Status:** Planning Phase

---

## Work Item Hierarchy

### Epic Level

| ID | Type | Title | State | Priority |
|----|------|-------|-------|----------|
| TBD | Epic | MOS Support Agent Development (Mossy) | New | 1 |

---

## Feature Level (3 Features)

| ID | Type | Title | Parent | State | Phase |
|----|------|-------|--------|-------|-------|
| TBD | Feature | Agent Infrastructure & Core Skills | Epic TBD | New | Phase 1 |
| TBD | Feature | Advanced Skills & Automation Workflows | Epic TBD | New | Phase 2 |
| TBD | Feature | Proactive Monitoring & Intelligence | Epic TBD | New | Phase 3 |

---

## User Story Level (18 User Stories)

### Phase 1: Foundation (7 Stories)

| ID | Type | Title | Parent Feature | State | Category | Tickets/Year |
|----|------|-------|----------------|-------|----------|--------------|
| TBD | User Story | Agent Framework - Mossy Configuration | Feature 1 | New | Infrastructure | N/A |
| TBD | User Story | Database Connectivity - MSSQL MCP Integration | Feature 1 | New | Infrastructure | N/A |
| TBD | User Story | check-market-price Skill (Production Ready) | Feature 1 | Done | 1 - Market Pricing | ~50 |
| TBD | User Story | bulk-price-validation Skill (Production Ready) | Feature 1 | Done | 1A - Bulk Validation | ~30 |
| TBD | User Story | check-ssis-errors Skill (Production Ready) | Feature 1 | Done | 4 - SSIS/PowerShell | ~150 |
| TBD | User Story | check-cash-reconciliation Skill | Feature 1 | In Progress | 2 - Cash Reconciliation | ~120 |
| TBD | User Story | check-data-normalization Skill | Feature 1 | In Progress | 3 - Data Normalization | ~80 |

**Phase 1 Coverage:** ~430 tickets/year (48% of total)

---

### Phase 2: Enhancement (11 Stories)

| ID | Type | Title | Parent Feature | State | Category | Tickets/Year |
|----|------|-------|----------------|-------|----------|--------------|
| TBD | User Story | check-data-feeds Skill | Feature 2 | New | 8 - Integration/Feeds | ~70 |
| TBD | User Story | check-data-quality Skill | Feature 2 | New | 6 - Data Quality | ~60 |
| TBD | User Story | setup-portfolio Skill | Feature 2 | New | 5 - Portfolio Setup | ~40 |
| TBD | User Story | optimize-performance Skill | Feature 2 | New | 7 - Performance | ~30 |
| TBD | User Story | price-overrides Skill (Production Ready) | Feature 2 | Done | 1B - Price Overrides | ~20 |
| TBD | User Story | remove-process-dashboard-reports Skill (Production Ready) | Feature 2 | Done | 11 - Dashboard Mgmt | ~15 |
| TBD | User Story | check-workflow Skill | Feature 2 | New | 9 - Workflow/Approval | ~25 |
| TBD | User Story | review-schema-change Skill | Feature 2 | New | 10 - Schema Changes | ~200 |
| TBD | User Story | Automated Remediation Engine | Feature 2 | New | Infrastructure | N/A |
| TBD | User Story | Workflow Orchestration - Multi-Step Procedures | Feature 2 | New | Infrastructure | N/A |
| TBD | User Story | Image Analysis Enhancement - All Skills | Feature 2 | New | Infrastructure | N/A |

**Phase 2 Coverage:** ~460 tickets/year (52% of total - cumulative 100%)

---

### Phase 3: Intelligence (3 Stories)

| ID | Type | Title | Parent Feature | State | Category | Tickets/Year |
|----|------|-------|----------------|-------|----------|--------------|
| TBD | User Story | Proactive Monitoring - Issue Detection | Feature 3 | New | Infrastructure | Target: -50% tickets |
| TBD | User Story | Self-Service Portal - Client Status Dashboard | Feature 3 | New | Infrastructure | N/A |
| TBD | User Story | Analytics Dashboard - Performance Metrics | Feature 3 | New | Infrastructure | N/A |

---

## Task Level Breakdown (Sample for Phase 1)

### User Story: Agent Framework - Mossy Configuration

| Task ID | Task Title | Estimate | Status |
|---------|-----------|----------|--------|
| TBD | Create Mossy.agent.md configuration file | 2h | New |
| TBD | Define skill routing logic | 4h | New |
| TBD | Configure confidence thresholds | 2h | New |
| TBD | Set up skill discovery from .github/skills/ | 3h | New |
| TBD | Implement argumentHint parsing | 2h | New |
| TBD | Test skill invocation from @Mossy mention | 2h | New |
| **Subtotal** | **6 tasks** | **15h** | - |

### User Story: Database Connectivity - MSSQL MCP Integration

| Task ID | Task Title | Estimate | Status |
|---------|-----------|----------|--------|
| TBD | Install and configure MSSQL MCP server | 3h | New |
| TBD | Test connection to MOS_Core database | 1h | New |
| TBD | Test connection to Solvas_AM database | 1h | New |
| TBD | Test connection to Reference database | 1h | New |
| TBD | Test connection to SecurityMaster database | 1h | New |
| TBD | Create reusable query templates | 4h | New |
| TBD | Implement error handling for connection failures | 3h | New |
| TBD | Document database schemas and key tables | 4h | New |
| **Subtotal** | **8 tasks** | **18h** | - |

### User Story: check-cash-reconciliation Skill

| Task ID | Task Title | Estimate | Status |
|---------|-----------|----------|--------|
| TBD | Review existing cash rec tickets (#70176, #69783, etc.) | 4h | New |
| TBD | Map CashRec database schema | 3h | New |
| TBD | Create balance discrepancy query templates | 4h | New |
| TBD | Create transaction matching query templates | 4h | New |
| TBD | Implement SFR status checking | 3h | New |
| TBD | Implement approval workflow validation | 3h | New |
| TBD | Add AI vision for cash rec screenshot analysis | 2h | New |
| TBD | Fetch wiki: /Cash-Reconciliation-Procedures | 1h | New |
| TBD | Create SKILL.md documentation | 2h | New |
| TBD | Test with historical tickets | 4h | New |
| **Subtotal** | **10 tasks** | **30h** | - |

### User Story: check-data-normalization Skill

| Task ID | Task Title | Estimate | Status |
|---------|-----------|----------|--------|
| TBD | Review normalization tickets (#74076, #69864, etc.) | 4h | New |
| TBD | Map custodian normalization views | 4h | New |
| TBD | Create transaction type mapping queries | 3h | New |
| TBD | Create balance normalization queries | 3h | New |
| TBD | Create position normalization queries | 3h | New |
| TBD | Implement mapping gap detection | 4h | New |
| TBD | Add AI vision for mapping screenshot analysis | 2h | New |
| TBD | Fetch wiki: /Feed-Mapping-Standards | 1h | New |
| TBD | Create SKILL.md documentation | 2h | New |
| TBD | Test with historical tickets | 4h | New |
| **Subtotal** | **10 tasks** | **30h** | - |

---

## Phase to Feature Mapping

| Phase | Feature ID | Feature Title | Duration | User Stories | Estimated Tasks |
|-------|------------|---------------|----------|--------------|-----------------|
| 1 | TBD | Agent Infrastructure & Core Skills | 4 weeks | 7 | ~40 |
| 2 | TBD | Advanced Skills & Automation Workflows | 6 weeks | 11 | ~60 |
| 3 | TBD | Proactive Monitoring & Intelligence | 2 weeks | 3 | ~30 |

---

## Summary

| Type | Count | Status Distribution |
|------|-------|---------------------|
| Epic | 1 | New: 1 |
| Features | 3 | New: 3 |
| User Stories | 21 | Done: 5, In Progress: 2, New: 14 |
| Tasks (Estimated) | ~130 | New: ~130 |
| **Total Work Items** | **~155** | - |

---

## Skill Coverage by Support Category

| Category | Annual Tickets | User Story | Priority | Status |
|----------|----------------|------------|----------|--------|
| 1 - Market Pricing | ~50 | check-market-price | High | ✅ Done |
| 1A - Bulk Price Validation | ~30 | bulk-price-validation | High | ✅ Done |
| 1B - Price Overrides | ~20 | price-overrides | High | ✅ Done |
| 2 - Cash Reconciliation | ~120 | check-cash-reconciliation | Critical | 🚧 In Progress |
| 3 - Data Normalization | ~80 | check-data-normalization | Medium | 🚧 In Progress |
| 4 - SSIS/PowerShell Errors | ~150 | check-ssis-errors | High | ✅ Done |
| 5 - Portfolio Setup | ~40 | setup-portfolio | Medium | 📋 Planned |
| 6 - Data Quality | ~60 | check-data-quality | Medium | 📋 Planned |
| 7 - Performance Optimization | ~30 | optimize-performance | High | 📋 Planned |
| 8 - Integration/Feeds | ~70 | check-data-feeds | High | 📋 Planned |
| 9 - Workflow/Approval | ~25 | check-workflow | Medium | 📋 Planned |
| 10 - Schema Changes | ~200 | review-schema-change | Low | 📋 Planned |
| 11 - Dashboard Management | ~15 | remove-process-dashboard-reports | Medium | ✅ Done |
| **TOTAL** | **~890** | **13 Skills** | - | **5 Done, 2 In Progress, 6 Planned** |

---

## Dependencies

### External Dependencies
- **MSSQL MCP Server** - Required for database connectivity
- **Azure CLI** - Required for ADO integration and wiki access
- **Microsoft Graph API MCP** - Required for email automation (already configured)
- **view_image tool** - Required for screenshot analysis (VS Code built-in)

### Internal Dependencies
- **Phase 2 depends on Phase 1** - Automated remediation requires all core skills operational
- **Phase 3 depends on Phase 2** - Proactive monitoring requires historical data from automated investigations

### Skill Dependencies
- **Workflow Orchestration** (Phase 2) depends on:
  - check-market-price (Phase 1) ✅
  - price-overrides (Phase 1) ✅
  - check-cash-reconciliation (Phase 1) 🚧
  - check-data-normalization (Phase 1) 🚧

---

## Next Steps

1. **Create Epic in ADO** - Use Azure CLI to create Epic work item
2. **Create 3 Features** - Link to Epic
3. **Create 21 User Stories** - Link to respective Features
4. **Break down tasks** - Detailed task planning for Phase 1 (7 stories → ~40 tasks)
5. **Assign priorities** - Set work item priorities based on ticket volume and impact
6. **Upload to ADO Wiki** - Publish this document to /Planning/2026-07-31-mossy-agent-development/Work-Items

**Azure CLI Commands:**

```powershell
# Create Epic
az boards work-item create --title "MOS Support Agent Development (Mossy)" --type "Epic" --org https://siepe.visualstudio.com/ --project "Siepe.Software"

# Create Feature 1
az boards work-item create --title "Agent Infrastructure & Core Skills" --type "Feature" --org https://siepe.visualstudio.com/ --project "Siepe.Software" --fields "System.Parent=<EPIC_ID>"

# Create User Story (example)
az boards work-item create --title "check-cash-reconciliation Skill" --type "User Story" --org https://siepe.visualstudio.com/ --project "Siepe.Software" --fields "System.Parent=<FEATURE_ID>"
```
