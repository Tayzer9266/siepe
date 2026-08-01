# Middle Office Contract Cash Flow Debt Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficeContractCashFlowDebtLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** InstContractCashFlow, InstDebt, InstIssue
- **Log File Location:** `$dirLogFolder\MiddleOfficeContractCashFlowDebtLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes three related data types: Contract Cash Flows, Debt Instruments, and Issue details from Siepe MOS. This is a complex load with multiple sequential imports.

---

## Step Sequence

### Step 1: Initialize Script Environment
**Action:** Load configuration and create log folder  
**Dependencies:** 
- Environment variable: `$env:Powershell_ConfigRootLocation`
- Function library: `fMasterFunctionDeclare.ps1`
**Output:** Log file created with timestamp

---

### Step 2: Configure Job Parameters
**Action:** Set job-specific variables  
**Parameters:**
- `GenericJobNameInstDebt`: 'Siepe MOS InstDebt Load'
- `GenericJobNameInstIssue`: 'Siepe MOS InstIssue Load'
- `GenericJobNameInstContractCashflow`: 'Siepe MOS InstContractCashflow Load'
- `GenericNormalizationJobType`: 'Custodian Instrument'
- `GenericNormalizationFeedsLabel`: 'InstDebt-ContractCashFlow'
- `Source`: 'Siepe MOS'

**Manual Override Option:**
```powershell
# Uncomment to reprocess specific date:
# $ReturnDate = [datetime]::parseexact("10/26/2023", 'MM/dd/yyyy', $null)
```

---

### IMPORT PHASE 1: InstContractCashflow

### Step 3: Retrieve InstContractCashflow Import Job Configuration
**Action:** Query database for InstContractCashflow import settings  
**SQL Query:**
```sql
SELECT GenericImportJobId, SourceFolder, ArchiveLocation, FileName 
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1 
  AND Name = 'Siepe MOS InstContractCashflow Load' 
  AND Source = 'Siepe MOS'
```
**Output:** `GenericImportJobIdInstContractCashflow`

---

### Step 4: Generic Import - InstContractCashflow
**Function:** `fGenericImportJob`  
**Action:** Import contract cash flow data  
**Parameters:**
- GenericImportJobIdInstContractCashflow

**Process:**
1. Imports contract cash flow schedules
2. Returns `RefDataSetDate`

**Timing Note:** Check log for "InstContractCashflow" import duration

---

### IMPORT PHASE 2: InstDebt

### Step 5: Retrieve InstDebt Import Job Configuration
**Action:** Query database for InstDebt import settings  
**SQL Query:**
```sql
SELECT GenericImportJobId, SourceFolder, ArchiveLocation, FileName 
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1 
  AND Name = 'Siepe MOS InstDebt Load' 
  AND Source = 'Siepe MOS'
```
**Output:** `GenericImportJobInstDebtId`

---

### Step 6: Generic Import - InstDebt
**Function:** `fGenericImportJob`  
**Action:** Import debt instrument data  
**Parameters:**
- GenericImportJobInstDebtId

**Process:**
1. Imports debt instrument characteristics
2. Uses same `RefDataSetDate`

**Timing Note:** Check log for "InstDebt" import duration

---

### IMPORT PHASE 3: InstIssue

### Step 7: Retrieve InstIssue Import Job Configuration
**Action:** Query database for InstIssue import settings  
**SQL Query:**
```sql
SELECT GenericImportJobId, SourceFolder, ArchiveLocation, FileName 
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1 
  AND Name = 'Siepe MOS InstIssue Load' 
  AND Source = 'Siepe MOS'
```
**Output:** `GenericImportJobInstIssueID`

---

### Step 8: Generic Import - InstIssue
**Function:** `fGenericImportJob`  
**Action:** Import instrument issue data  
**Parameters:**
- GenericImportJobInstIssueID

**Process:**
1. Imports instrument issuance details
2. Uses same `RefDataSetDate`

**Timing Note:** Check log for "InstIssue" import duration

---

### NORMALIZATION PHASE

### Step 9: Retrieve Normalization Job Configuration
**Action:** Query for combined normalization job  
**SQL Query:**
```sql
SELECT GenericNormalizationJobID 
FROM Feeds.dbo.vGenericNormalizationJob 
WHERE RefRecStatusID = 1 
  AND GenericNormalizationJobType = 'Custodian Instrument' 
  AND FeedsRefDataSource = 'Siepe MOS' 
  AND FeedsLabel = 'InstDebt-ContractCashFlow'
```
**Output:** `GenericNormalizationJobId`

---

### Step 10: Generic Normalization - Combined Data
**Function:** `fGenericNormalization`  
**Action:** Normalize all three data types together  
**Parameters:**
- GenericNormalizationJobID
- RefDataSetDate

**Process:**
1. Normalizes InstContractCashflow data
2. Normalizes InstDebt data
3. Normalizes InstIssue data
4. Creates relationships between all three
5. Validates data integrity across all types

**Timing Note:** Check log for normalization duration (critical timing point)

---

### REFERENCE DATA PUSH PHASE

### Step 11: Push Reference Data - Legal Entity
**Function:** `fGenericPushReferenceData`  
**Action:** Push any Legal Entity updates  
**Parameters:**
- PushName: 'LegalEntity'
- RefDataSetDate

---

### Step 12: Push Reference Data - Instrument
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument updates  
**Parameters:**
- PushName: 'Instrument'
- RefDataSetDate

**Note:** Variable typo in original script (`$pLogFile` instead of `$LogFile`)

---

### Step 13: Push Reference Data - InstIdentifier
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument Identifier records  
**Parameters:**
- PushName: 'InstIdentifier'
- RefDataSetDate

---

### Step 14: Push Reference Data - InstDebt
**Function:** `fGenericPushReferenceData`  
**Action:** Push debt instrument characteristics  
**Parameters:**
- PushName: 'InstDebt'
- RefDataSetDate

**Timing Note:** Check log for InstDebt push duration

---

### Step 15: Push Reference Data - InstContract
**Function:** `fGenericPushReferenceData`  
**Action:** Push contract cash flow schedules  
**Parameters:**
- PushName: 'InstContract'
- RefDataSetDate

**Timing Note:** Check log for InstContract push duration

---

## Timing Analysis
**Review log file sections for:**
1. **Import Phase Duration:** 
   - InstContractCashflow import time
   - InstDebt import time
   - InstIssue import time
   - Total import time (sum of all three)

2. **Normalization Duration:** 
   - Combined normalization time (likely longest step)

3. **Push Phase Duration:**
   - Individual push times for each reference data type
   - Total push time

4. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily/On-demand
- **Typical Run Time:** TBD (review logs) - Expect longer runtime due to three imports
- **Dependencies:** 
  - Requires three separate extract files in source folders
  - All three files should have matching RefDataSetDate

## Critical Considerations
⚠️ **Sequential Dependency:** All three imports must complete successfully before normalization begins  
⚠️ **Data Consistency:** Ensure all three files are from the same business date  
⚠️ **Normalization Complexity:** Combined normalization may take longer due to cross-referencing

## Data Flow
1. **Source Files:**
   - InstContractCashflow extract
   - InstDebt extract
   - InstIssue extract
2. **Staging:** Feeds database (Custodian schema)
3. **Target:** Reference database (InstDebt, InstContract tables)

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors in each phase
- Verify all three imports completed before normalization
- Check archive folders for all processed files
