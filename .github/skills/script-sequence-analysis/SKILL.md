# Script Sequence Analysis Skill

## Overview

This skill provides comprehensive analysis of PowerShell Script Adapter workflows, extracting sequencing information, dependencies, SQL procedures, file paths, and pub/sub messaging patterns from ETL scripts.

**Reference Location:** C:\source\PipeWatch\PS_Scripts\MOS\

**Analysis Output:** C:\source\PipeWatch\public\docs\script-sequences.json

---

## When to Use This Skill

Use this skill when:
- Analyzing Script Adapter job workflows and dependencies
- Understanding data flow through PowerShell ETL scripts
- Identifying SQL procedures called by scripts
- Mapping pub/sub message sequences
- Troubleshooting script adapter job failures
- Documenting job dependencies and sequences
- Resequencing jobs after failures or changes

---

## Script Analysis Capabilities

### 1. SQL Procedures Extracted

The analyzer identifies all stored procedures called by scripts:

```json
"sql_procedures": [
  {
    "schema": "Reference",
    "name": "pAttributeAutomap",
    "full_name": "Reference.dbo.pAttributeAutomap"
  },
  {
    "schema": "MOS",
    "name": "pPortfolioCreation",
    "full_name": "MOS.dbo.pPortfolioCreation"
  }
]
```

**Use for:**
- Database dependency mapping
- Performance troubleshooting
- Identifying which procedures are called in sequence

### 2. Workflow Steps Identified

Standard workflow patterns extracted:

```json
"workflow_steps": [
  {
    "step": "File Import",
    "pattern": "fGenericImportJob"
  },
  {
    "step": "Data Normalization",
    "pattern": "fGenericNormalization"
  },
  {
    "step": "Attribute Mapping",
    "pattern": "EXEC.*pAttributeAutomap"
  },
  {
    "step": "Publish Completion Message",
    "pattern": "Write-PubSub"
  }
]
```

**Standard Sequence:**
1. File Import (fGenericImportJob)
2. Data Normalization (fGenericNormalization)
3. Attribute Mapping (pAttributeAutomap)
4. Publish Completion (Write-PubSub)

### 3. Pub/Sub Messages

Messages published by scripts for job sequencing:

```json
"pubsub_publishes": [
  "Abry.ALC.DataFile.Import.Completed",
  "ReportSubscription.WATC.CashTransactions.Done"
]
```

**Message Patterns:**
- `ClientName.JobType.Action.Status`
- `ReportSubscription.Client.DataType.Status`
- `ScriptAdapter.Process.Stage.Status`

### 4. File Paths and Locations

Source folders, archive locations, and file patterns:

```json
"file_paths": {
  "source_folders": ["\\\\mos.siepe.local\\SHARED\\CLIENTS\\998\\..."],
  "archive_folders": ["\\\\mos.siepe.local\\SHARED\\CLIENTS\\998\\Archive\\..."],
  "file_patterns": ["*.csv", "CashFile_*.xlsx"]
}
```

### 5. Normalization Jobs

Data normalization steps in sequence:

```json
"normalization_jobs": [
  "Abry ALC Instruments",
  "Abry Broker InstRatings"
]
```

### 6. Dependencies

Required config files, modules, and databases:

```json
"dependencies": {
  "config_files": [
    "ConnectionStrings.config.ps1",
    "IOFunctions.ps1",
    "fGenericImportJob.ps1"
  ],
  "powershell_modules": [
    "Siepe.Tools.PowerShell.PubSubSnapIn"
  ],
  "databases": [
    "Core",
    "Feeds",
    "Reference"
  ]
}
```

---

## Running the Script Analyzer

### Analyze All Scripts

```powershell
cd C:\source\PipeWatch
& ".\venv\Scripts\python.exe" .\scripts\analysis\analyze_script_sequences.py
```

**Output:** C:\source\PipeWatch\public\docs\script-sequences.json

### Merge with Job Data

After analysis, merge sequences into job-names-list.json:

```powershell
cd C:\source\PipeWatch
& ".\venv\Scripts\python.exe" .\scripts\generators\merge_script_sequences.py
```

**Result:** Adds `sequence` object to each Script Adapter job in job-names-list.json

---

## Querying Script Sequences in PipeWatch

### View in PipeWatch UI

1. Open PipeWatch: http://localhost:8000/
2. Search for Script Adapter job
3. Click job to view details
4. **Workflow Sequence** section shows:
   - SQL procedures called
   - Workflow steps in order
   - Pub/sub messages published
   - File paths used
   - Dependencies

### Example Analysis: Abry ALC DataFile Import

**Script:** Abry_ALC_DataFile_Import.ps1

**Workflow:**
1. ✅ Import File → fGenericImportJob (GenericImportJobID from vGenericImportJob)
2. ✅ Normalize Instruments → fGenericNormalization ('Abry ALC Instruments')
3. ✅ Normalize Ratings → fGenericNormalization ('Abry Broker InstRatings')
4. ✅ Attribute Mapping → EXEC Reference.dbo.pAttributeAutomap
5. ✅ Get FundID → SELECT FROM dbo.vFund WHERE FundName = 'Abry ALC DataFile'
6. ✅ Publish Message → Write-PubSub 'Abry.ALC.DataFile.Import.Completed'

**Publishes:** `Abry.ALC.DataFile.Import.Completed`

**Dependencies:**
- Databases: Core, Feeds, Reference
- Config: ConnectionStrings.config.ps1, IOFunctions.ps1
- PowerShell: Siepe.Tools.PowerShell.PubSubSnapIn

---

## Common Workflow Patterns

### Pattern 1: File Import → Normalize → Publish

```
1. fGenericImportJob (import file from source folder)
2. fGenericNormalization (normalize data using job labels)
3. Write-PubSub (notify completion)
```

**Example:** Cash file imports, position imports, transaction imports

### Pattern 2: Import → Normalize → Attribute Map → Publish

```
1. fGenericImportJob
2. fGenericNormalization (multiple normalization jobs)
3. EXEC Reference.dbo.pAttributeAutomap
4. Write-PubSub
```

**Example:** Security master updates, instrument attribute imports

### Pattern 3: Adhoc Re-Normalization

```
1. SELECT GenericNormalizationJobID
2. fGenericNormalization
3. (No pub/sub - manual execution)
```

**Example:** AdHoc normalization scripts, data fixes

---

## Troubleshooting with Sequence Data

### Problem: Script Adapter Job Failed

**Steps:**
1. Find job in PipeWatch
2. Review **Workflow Sequence** to see where it should be in the process
3. Check **SQL Procedures** - query database to see if procedures ran
4. Check **Pub/Sub Messages** - verify if completion message was published
5. Check **File Paths** - verify source files exist

### Problem: Job Not Triggering Next Job

**Check:**
1. **Pub/Sub Publishes** - What message does this job publish?
2. **Related Jobs → Triggers** - Which jobs listen for that message?
3. Verify pub/sub message was actually published (check logs)
4. Verify listening job has correct message subscription

### Problem: Data Not Normalized

**Check:**
1. **Normalization Jobs** - Which normalization labels are used?
2. Query: `SELECT * FROM Feeds.dbo.vGenericNormalizationJob WHERE ReferenceLabel = 'Label Name'`
3. Verify GenericNormalizationJobID exists and is active (RefRecStatusID = 1)
4. Check normalization view configuration

---

## Script Analysis Tools Location

**Analyzer Script:**
```
C:\source\PipeWatch\scripts\analysis\analyze_script_sequences.py
```

**Merge Script:**
```
C:\source\PipeWatch\scripts\generators\merge_script_sequences.py
```

**PowerShell Scripts:**
```
C:\source\PipeWatch\PS_Scripts\MOS\*.ps1
```

**Output Files:**
```
C:\source\PipeWatch\public\docs\script-sequences.json
C:\source\PipeWatch\public\docs\job-names-list.json (merged)
```

---

## Integration with Job Resequencing

When resequencing failed jobs, use script sequence data to:

1. **Identify Dependencies** - What must run before this job?
2. **Find Pub/Sub Chain** - What triggered this job? What does it trigger?
3. **Locate SQL Procedures** - Which stored procedures need to be re-run?
4. **Verify File Availability** - Check source folders for required files

**Example Resequence Workflow:**

```
Job Failed: "Abry ALC DataFile Import"

1. Check Sequence:
   - Should publish: "Abry.ALC.DataFile.Import.Completed"
   
2. Find Dependent Jobs:
   - Query PipeWatch Related Jobs → "Triggers"
   - Jobs listening for "Abry.ALC.DataFile.Import.Completed"
   
3. Rerun Sequence:
   - Execute script manually or via Script Adapter
   - Verify pub/sub message published
   - Verify dependent jobs triggered
```

---

## Statistics (Current Analysis)

**Total Scripts Analyzed:** 285  
**Script Adapter Jobs with Sequences:** 274  
**Coverage:** 96% (274/285 scripts matched to jobs)

**Extracted Data:**
- SQL Procedures: ~600+ unique procedures
- Pub/Sub Messages: ~300+ messages
- Normalization Jobs: ~500+ labels
- Import Jobs: ~400+ jobs

---

## Best Practices

1. **Always review workflow sequence** before manually rerunning a failed Script Adapter job
2. **Check pub/sub chain** to understand downstream impact
3. **Verify SQL procedures completed** before marking job as successful
4. **Use sequence data** to document job dependencies in troubleshooting tickets
5. **Re-analyze scripts** after PowerShell code changes:
   ```powershell
   # After script updates
   & ".\venv\Scripts\python.exe" .\scripts\analysis\analyze_script_sequences.py
   & ".\venv\Scripts\python.exe" .\scripts\generators\merge_script_sequences.py
   ```

---

## Example Queries

### Find scripts that call a specific procedure:

```python
# In Python or via PipeWatch search
sequences = json.load(open('script-sequences.json'))
scripts_calling_pAttributeAutomap = [
    s['script_name'] 
    for s in sequences['scripts']
    if any(p['name'] == 'pAttributeAutomap' for p in s['sql_procedures'])
]
```

### Find scripts publishing specific message:

```python
scripts_publishing = [
    s['script_name']
    for s in sequences['scripts']
    if 'Abry.ALC' in ' '.join(s['pubsub_publishes'])
]
```

### Count normalization jobs per script:

```python
norm_counts = {
    s['script_name']: len(s['normalization_jobs'])
    for s in sequences['scripts']
}
```
