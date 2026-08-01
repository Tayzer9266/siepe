# TML File Creation for Report Schedule Jobs

## Overview
TML (Template Markup Language) files are used to define Report Schedule jobs and database deployments in the Siepe database system. They specify which stored procedures, views, and data scripts to deploy across different environments.

## File Structure

### Basic TML Format
```
[Global]
Procs = ["Schema.pProcedureName.sql", "Schema.pOtherProcedure.sql"]
Views = ["Schema.vViewName.sql"]

[Envs]
[Envs.EnvironmentName]
Data = ["DataScript.sql"]
```

### Sections

#### [Global]
Defines objects that deploy to ALL environments:
- `Procs = [...]` - Array of stored procedure file names
- `Views = [...]` - Array of view file names
- `Functions = [...]` - Array of function file names

#### [Envs]
Defines environment-specific deployments:
- `[Envs.MOS]` - MOS Production environment
- `[Envs.Aristotle]` - Aristotle Production environment  
- `[Envs.ClientName]` - Client-specific environments

Environment sections can have:
- `Data = [...]` - Data scripts (inserts/updates)
- `Procs = [...]` - Environment-specific procedures
- `Views = [...]` - Environment-specific views

## Examples

### Simple Report Schedule Job
```
[Global]
Procs = ["Report.pLedgerValueMMFMappings.sql"]
```

### Multi-Environment Deployment
```
[Global]
Views = [
    "Report.vSubscriptionXMLJournalRaw.sql",
    "Report.vDeliveryFrequencyRaw.sql",
]
Procs = [
    "dbo.pReportUpdatedReportSubscriptionJobs.sql",
    "dbo.pReportRecentReportSubscriptionTriggers.sql",
]

[Envs]
[Envs.Nexpoint]
Data = ["CompanyAndNameUpdate.sql"]
```

### Complex Deployment
```
[Global]
Procs = [
    "Report.pSubscriptionDynamicReportContentXml.sql",
    "DynamicReports.pUserReportTypeParametersXml.sql"
]

[Envs]
[Envs.MOS]
Data = ["MOS_ConfigData.sql"]

[Envs.Aristotle]
Data = ["Aristotle_ConfigData.sql"]
```

## File Naming Convention

TML files should be named using the pattern:
```
YYYY-MM-DD-DescriptiveName.tml
```

Examples:
- `2026-07-22-pLedgerValueMMFMappings.tml`
- `2025-12-22-report-self-schedule.tml`
- `2026-01-13-CAMOSRSTrackingReports.tml`

## Report Schedule Job Creation Workflow

1. **Create stored procedure** in Report schema
   - Follow Siepe database standards
   - Include proper error handling
   - Test on dev environment

2. **Save procedure to SQL file**
   - Named: `Report.pProcedureName.sql`
   - Includes DROP...IF EXISTS header
   - Includes GRANT EXECUTE statement

3. **Create TML file**
   ```
   [Global]
   Procs = ["Report.pProcedureName.sql"]
   ```

4. **Deploy to environments**
   - Dev (testing)
   - QA (validation)
   - Production (scheduled execution)

## Common Patterns

### Daily Report Schedule
```
[Global]
Procs = ["Report.pDailyReconciliation.sql"]
# Report Schedule system will handle scheduling
```

### Multi-Client Deployment
```
[Global]
Procs = ["Report.pGenericReport.sql"]

[Envs]
[Envs.ClientA]
Data = ["ClientA_Config.sql"]

[Envs.ClientB]
Data = ["ClientB_Config.sql"]
```

## Best Practices

1. **Keep it simple** - Use Global section for procedures that apply to all environments
2. **Environment-specific data** - Use Envs sections only when configuration differs
3. **File paths** - Always use relative paths from ReleaseSpec folder
4. **Array format** - Each file in quotes, comma-separated
5. **Schema prefix** - Always include schema name (Report.pName, not just pName)

## Troubleshooting

### TML Not Deploying
- Check file name syntax (must be .tml extension)
- Verify SQL file names match exactly
- Ensure proper TOML array format with quotes

### Procedure Not Executing
- Verify GRANT EXECUTE permissions in SQL file
- Check Report Schedule configuration in database
- Review execution logs in AdminTools

## Related Files

When creating a TML file, ensure these exist:
1. `ProcedureName.sql` - The actual stored procedure
2. `YYYY-MM-DD-Description/` - Folder containing TML and SQL files
3. Any referenced data scripts or views

## Reference

TML files are processed by the Siepe deployment system which:
- Parses TOML format
- Executes SQL scripts in dependency order
- Creates Report Schedule jobs automatically
- Handles rollback on errors
