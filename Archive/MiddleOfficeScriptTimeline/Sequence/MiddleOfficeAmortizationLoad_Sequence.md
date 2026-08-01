# Middle Office Amortization Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficeAmortizationLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** Instrument Amortization schedules
- **Log File Location:** `$dirLogFolder\MiddleOfficeAmortizationLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes Amortization data from Siepe MOS for Custodian Instruments.

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
- `GenericJobName`: 'Siepe MOS Amortization Load'
- `GenericNormalizationJobType`: 'Custodian Instrument'
- `GenericNormalizationFeedsLabel`: 'InstAmort'
- `Source`: 'Siepe MOS'

**Manual Override Option:**
```powershell
# Uncomment to reprocess specific date:
# $ReturnDate = [datetime]::parseexact("10/26/2023", 'MM/dd/yyyy', $null)
```

---

### Step 3: Retrieve Generic Import Job Configuration
**Action:** Query database for import job settings  
**SQL Query:**
```sql
SELECT GenericImportJobId, SourceFolder, ArchiveLocation, FileName 
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1 
  AND Name = 'Siepe MOS Amortization Load' 
  AND Source = 'Siepe MOS'
```
**Retrieved Data:**
- `GenericImportJobId`
- `SourceFolder`
- `ArchiveLocation`

**Log Output:**
- GenericImportJobId
- SourceFolder path
- ArchiveFolder path (with timestamp)

---

### Step 4: Retrieve Normalization Job Configuration
**Action:** Query for Custodian Instrument normalization job  
**SQL Query:**
```sql
SELECT GenericNormalizationJobID 
FROM Feeds.dbo.vGenericNormalizationJob 
WHERE RefRecStatusID = 1 
  AND GenericNormalizationJobType = 'Custodian Instrument' 
  AND FeedsRefDataSource = 'Siepe MOS' 
  AND FeedsLabel = 'InstAmort'
```
**Output:** `GenericNormalizationJobId`

---

### Step 5: Retrieve Normalization View Configuration
**Action:** Query for normalization view settings  
**SQL Query:**
```sql
SELECT DISTINCT REFRefDataSourceID, ReferenceRefDataSetType, ReferenceLabel 
FROM Feeds.dbo.vNormalizationView 
WHERE RefRecStatusID = 1 
  AND GenericNormalizationJobID = {GenericNormalizationJobID}
```
**Retrieved Data:**
- `Ref_RefDataSourceID`
- `RefDataSetType`
- `RefLabel`

---

### Step 6: Generic Import Job Execution
**Function:** `fGenericImportJob`  
**Action:** Import raw amortization data files  
**Parameters:**
- GenericImportJobID
- SourceFolder
- ArchiveFolder (timestamped)

**Process:**
1. Scans source folder for amortization files
2. Imports data into staging tables
3. Archives processed files
4. Returns `RefDataSetDate`

**Timing Note:** Check log for import duration

---

### Step 7: Generic Normalization - Instrument Amortization
**Function:** `fGenericNormalization`  
**Action:** Normalize amortization schedules  
**Parameters:**
- GenericNormalizationJobID
- RefDataSetDate (from Step 6)

**Process:**
1. Transforms raw amortization data to standard format
2. Validates amortization schedule integrity
3. Associates amortization data with instruments
4. Prepares for reference data push

**Timing Note:** Check log for normalization duration

---

### Step 8: Push All Reference Data Items
**Function:** `fGenericPushRunReferenceDataItems`  
**Action:** Execute all configured reference data pushes  
**Parameters:**
- LogFile

**Process:**
1. Identifies all reference data types to push
2. Executes pushes in proper sequence:
   - LegalEntity
   - Instrument
   - InstIdentifier
   - InstAmort (amortization schedules)
3. Updates push status for each type

**Timing Note:** Check log for individual push durations

---

## Timing Analysis
**Review log file sections for:**
1. **Import Duration:** Time to import amortization files
2. **Normalization Duration:** Time to normalize amortization schedules
3. **Push Duration:** Total time for all reference data pushes
4. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily/On-demand
- **Typical Run Time:** TBD (review logs)
- **Dependencies:** 
  - Requires amortization extract files in SourceFolder
  - Depends on Instrument Load completion

## Data Flow
1. Source: Siepe MOS Amortization Extract
2. Staging: Feeds database (Custodian schema)
3. Target: Reference database (InstAmort tables)

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors
- Verify archive folder contains processed files
