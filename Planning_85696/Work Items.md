# Work Items

**Created:** 2026-07-30
**Developer:** Tay Nguyen
**Feature:** #85696 - MOS Support Agent Automation
**URL:** https://siepe.visualstudio.com/Siepe.Software/_workitems/edit/85696

## Hierarchy

| ID | Type | Title | Parent | State |
|----|------|-------|--------|-------|
| 85696 | Feature | MOS Support Agent Automation | – | New |
| 85755 | User Story | Price Exception Investigation & Resolution | Feature #85696 | New |
| 85756 | User Story | Cash Reconciliation Automation | Feature #85696 | New |
| 85757 | User Story | Data Normalization & Quality Checks | Feature #85696 | New |
| 85758 | User Story | SSIS Pipeline Error Diagnosis | Feature #85696 | New |
| 85759 | User Story | Portfolio/Company Setup Verification | Feature #85696 | New |
| 85760 | User Story | Performance Optimization Analysis | Feature #85696 | New |
| 85761 | User Story | Vendor File Delivery Monitoring | Feature #85696 | New |
| 85762 | User Story | Work Item Creation & Task Assignment | Feature #85696 | New |
| 85799 | User Story | Email Bugs or Tasks for Enhancements | Feature #85696 | New |

## Phase to User Story Mapping

| Phase | Story ID | Story Title | Skill(s) |
|-------|----------|-------------|----------|
| 1 | #85755 | Price Exception Investigation & Resolution | bulk-price-validation, check-market-price, price-overrides |
| 1 | #85758 | SSIS Pipeline Error Diagnosis | check-ssis-errors, ssis-troubleshooting |
| 1 | #85762 | Work Item Creation & Task Assignment | user-story-task-creation, mos-bug-tasks |
| 1 | #85799 | Email Bugs or Tasks for Enhancements | outlook-email-extraction, process-mos-support-emails |
| 2 | #85756 | Cash Reconciliation Automation | cash-reconciliation |
| 2 | #85757 | Data Normalization & Quality Checks | data-normalization, data-quality |
| 2 | #85759 | Portfolio/Company Setup Verification | portfolio-setup |
| 3 | #85760 | Performance Optimization Analysis | performance-optimization |
| 3 | #85761 | Vendor File Delivery Monitoring | import-file-investigation, job-resequencing |

## Skill Status Summary

| Status | Skills | Count |
|--------|--------|-------|
| ✅ Ready | bulk-price-validation, check-market-price, check-ssis-errors, price-overrides, outlook-email-extraction, process-mos-support-emails, user-story-task-creation, create-planning-wiki, daily-standup-report | 9 |
| 🚧 Phase 1 | cash-reconciliation, data-normalization | 2 |
| 📋 Phase 2 | data-quality, portfolio-setup, performance-optimization | 3 |
| 📋 Phase 3 | import-file-investigation (partially ready), job-resequencing | 2 |

## Summary

| Type | Count |
|------|-------|
| Feature | 1 |
| User Stories | 9 |
| Tasks | 0 (to be created per User Story) |
| **Total** | **10** |

## Completed Enhancements (2026-07-29)

- ✅ check-ssis-errors skill enhanced with "Silent Success Failure" pattern detection
- ✅ MOSSupportTaskTaxonomy updated with silent failure keywords and category 14
- ✅ create-planning-wiki skill created for Azure DevOps documentation generation
- ✅ InstDebt investigation successfully resolved CUSIP 21871DAG8 missing SeniorityType

## Active Development

- 🔄 #85713: Initial Research and Review (In Progress)
- 🔄 #85717: Reconciliation of Price Data (In Progress)
- 🔄 #85904: 36168Q104 - ICE Price not Requested (In Progress)
- 🔄 #85918: Update SolvasAM_PriceLoad.ps1 Timeout # to 4000 (In Progress)
