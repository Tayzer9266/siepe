# Mossy Skills Wiki Page Inventory
**Version:** 1.0  
**Last Updated:** 2026-07-28  
**Purpose:** Central mapping of Mossy skills to Azure DevOps wiki pages for standard operating procedures

---

## Wiki Page Mappings

| Skill Name | Wiki Path | Status | Purpose |
|------------|-----------|--------|---------|
| **bulk-price-validation** | `/2281/Price-Exception-Not-Matching-MarkIT-ICE-or-ICE-OR-NULL-Marks` | ✅ Confirmed | Bulk price validation procedures, price exception workflows |
| **check-market-price** | `/2281/Price-Exception-Not-Matching-MarkIT-ICE-or-ICE-OR-NULL-Marks` | ✅ Confirmed | Single security price investigation procedures |
| **check-ssis-errors** | `/SSIS-Troubleshooting-Guide` | ⏳ To Confirm | Common SSIS errors and resolutions, package debugging |
| **pricing-source-investigation** | `/Vendor-Pricing-Sources` | ⏳ To Confirm | Vendor price source hierarchy, weighting rules |
| **price-overrides** | `/6226/MOS-Ops-Price-Overrides` | ✅ Confirmed | Manual price override procedures, approval workflow |
| **data-normalization** | `/Feed-Mapping-Standards` | ⏳ To Confirm | Data normalization mapping conventions, transformation rules |
| **portfolio-setup** | `/Portfolio-Onboarding-Checklist` | ⏳ To Confirm | New fund setup procedures, portfolio configuration |
| **data-quality** | `/Data-Quality-Standards` | ⏳ To Confirm | Data validation rules, identifier standards, quality metrics |
| **performance-optimization** | `/Performance-Optimization-Best-Practices` | ⏳ To Confirm | Query optimization strategies, index guidelines, performance tuning |
| **import-file-investigation** | `/Vendor-File-Delivery-Locations` | ⏳ To Confirm | SFTP paths, DSE folder structures, file delivery patterns |
| **log-analysis** | `/Log-Analysis-Procedures` | ⏳ To Confirm | Seq log search patterns, error troubleshooting, log interpretation |
| **job-resequencing** | `/Job-Orchestration-Best-Practices` | ⏳ To Confirm | Maestro job sequencing, dependency rules, timing optimization |
| **mos-bug-tasks** | `/Bug-Reporting-Standards` | ⏳ To Confirm | Bug documentation templates, severity guidelines, reproduction steps |
| **user-story-task-creation** | `/Development-Task-Templates` | ⏳ To Confirm | Task breakdown patterns, hour estimation guidelines |
| **check-cash-reconciliation** | `/Cash-Reconciliation-Procedures` | ⏳ To Confirm | SFR approval process, balance matching logic |
| **tml-creation** | `/403/TML-Properties` | ✅ Confirmed | TML syntax reference, property documentation |
| **wiki-access** | N/A | N/A | Meta skill for wiki access - no specific wiki page needed |
| **process-mos-support-emails** | N/A | N/A | Email processing skill - uses multiple wiki references |

---

## Wiki Status Legend

- ✅ **Confirmed** - Wiki path verified and tested
- ⏳ **To Confirm** - Placeholder path, needs verification
- ❌ **Not Found** - Wiki page does not exist
- 🔄 **In Progress** - Wiki page being created
- N/A - No wiki page applicable for this skill

---

## Known Wiki Sections

### Price Exception Procedures
**Path:** `/2281/Price-Exception-Not-Matching-MarkIT-ICE-or-ICE-OR-NULL-Marks`  
**Used By:** bulk-price-validation, check-market-price  
**Content:**
- Vendor subscription verification steps
- Identifier mapping validation
- Price weighting configuration review
- Price source hierarchy validation

### Price Override Procedures
**Path:** `/6226/MOS-Ops-Price-Overrides`  
**Used By:** price-overrides  
**Content:**
- Manual override workflow
- MOS tagging procedures
- Solvas price deletion and insertion
- Approval requirements

### TML Properties Reference
**Path:** `/403/TML-Properties`  
**Used By:** tml-creation  
**Content:**
- TML syntax documentation
- Property definitions
- Report Schedule job configuration
- TML script examples

---

## Missing Wiki Pages (Need to Create)

The following wiki pages should be created to support Mossy skills:

1. **SSIS Troubleshooting Guide** (`/SSIS-Troubleshooting-Guide`)
   - Common error codes and resolutions
   - Package debugging procedures
   - Seq log interpretation
   - Connection troubleshooting

2. **Vendor Pricing Sources** (`/Vendor-Pricing-Sources`)
   - Vendor hierarchy and priority
   - Price weighting configuration
   - Vendor subscription management
   - Price source troubleshooting

3. **Feed Mapping Standards** (`/Feed-Mapping-Standards`)
   - Normalization mapping conventions
   - Transformation rules
   - Source system documentation
   - Mapping troubleshooting

4. **Portfolio Onboarding Checklist** (`/Portfolio-Onboarding-Checklist`)
   - New fund setup steps
   - Portfolio configuration requirements
   - Custodian connection setup
   - Cash reconciliation setup

5. **Data Quality Standards** (`/Data-Quality-Standards`)
   - Identifier requirements (CUSIP, ISIN, Bloomberg)
   - Validation rules
   - Duplicate detection
   - Data quality metrics

6. **Performance Optimization Best Practices** (`/Performance-Optimization-Best-Practices`)
   - Query optimization techniques
   - Index strategy
   - Execution plan analysis
   - Performance monitoring

7. **Vendor File Delivery Locations** (`/Vendor-File-Delivery-Locations`)
   - SFTP folder paths by vendor
   - DSE file locations
   - Import job configuration
   - File delivery schedules

8. **Log Analysis Procedures** (`/Log-Analysis-Procedures`)
   - Seq query patterns
   - Log level interpretation
   - Error pattern recognition
   - Troubleshooting workflows

9. **Job Orchestration Best Practices** (`/Job-Orchestration-Best-Practices`)
   - Maestro configuration
   - Job dependency management
   - Timing optimization
   - Failure handling

10. **Bug Reporting Standards** (`/Bug-Reporting-Standards`)
    - Bug template requirements
    - Severity classification
    - Reproduction step guidelines
    - Screenshot requirements

11. **Development Task Templates** (`/Development-Task-Templates`)
    - Task breakdown patterns
    - Hour estimation guidelines
    - Database development tasks
    - Dashboard development tasks

12. **Cash Reconciliation Procedures** (`/Cash-Reconciliation-Procedures`)
    - SFR approval workflow
    - Balance matching procedures
    - Discrepancy investigation
    - Client communication

---

## Wiki Access Commands

### Fetch Wiki Page
```powershell
az devops wiki page show `
    --wiki "Siepe Wiki" `
    --path "/page/path" `
    --include-content `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --output json
```

### List Wiki Pages
```powershell
az devops wiki page list `
    --wiki "Siepe Wiki" `
    --org https://siepe.visualstudio.com/ `
    --project "Siepe.Software" `
    --output table
```

### Search Wiki
```powershell
# Use grep to search through fetched wiki content
az devops wiki page show --wiki "Siepe Wiki" --path "/" --include-content | `
    Select-String "search term"
```

---

## Usage Pattern

**In Mossy Skills:**
```powershell
# Import wiki cache manager
Import-Module "C:\source\MD\AdminTools\.github\helpers\WikiCacheManager.psm1"

# Get cached wiki page (or fetch if not cached)
$wikiPath = "/2281/Price-Exception-Not-Matching-MarkIT-ICE"
$content = Get-CachedWikiPage -WikiPath $wikiPath

# Use wiki content in investigation
if ($content) {
    Write-Host "Following standard procedure from wiki: $wikiPath" -ForegroundColor Cyan
    # Include wiki reference in investigation report
}
```

---

## Maintenance Schedule

- **Weekly:** Clear expired wiki cache entries
- **Monthly:** Review and update wiki page mappings
- **Quarterly:** Verify all wiki paths are accessible
- **As Needed:** Add new wiki pages when procedures are documented

---

## Next Actions

1. ✅ Create wiki page inventory (this document)
2. ⏳ Verify placeholder wiki paths with actual Azure DevOps wiki
3. ⏳ Create missing wiki pages for undocumented procedures
4. ⏳ Update Mossy skills with confirmed wiki paths
5. ⏳ Implement wiki cache manager in all skills
6. ⏳ Document wiki contribution guidelines
