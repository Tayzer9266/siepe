# Middle Office Agent Bank Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficeAgentBankLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** Agent Bank (Legal Entity & Custodian Instrument relationships)
- **Log File Location:** `$dirLogFolder\MiddleOfficeAgentBankLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes Agent Bank data from Siepe MOS, creating Legal Entity records and Instrument-Legal Entity relationships.

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
- `GenericJobName`: 'Siepe MOS Agent Bank Load'
- `GenericNormalizationJobType1`: 'LegalEntity'
- `GenericNormalizationJobType2`: 'Custodian Instrument'
- `GenericNormalizationFeedsLabel`: 'Agent Bank'
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
  AND Name = 'Siepe MOS Agent Bank Load' 
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

### Step 4: Retrieve Normalization Job Configuration (Legal Entity)
**Action:** Query for Legal Entity normalization job  
**SQL Query:**
```sql
SELECT GenericNormalizationJobID 
FROM Feeds.dbo.vGenericNormalizationJob 
WHERE RefRecStatusID = 1 
  AND GenericNormalizationJobType = 'LegalEntity' 
  AND FeedsRefDataSource = 'Siepe MOS' 
  AND FeedsLabel = 'Agent Bank'
```
**Output:** `GenericNormalizationJobId1`

---

### Step 5: Retrieve Normalization Job Configuration (Custodian Instrument)
**Action:** Query for Custodian Instrument normalization job  
**SQL Query:**
```sql
SELECT GenericNormalizationJobID 
FROM Feeds.dbo.vGenericNormalizationJob 
WHERE RefRecStatusID = 1 
  AND GenericNormalizationJobType = 'Custodian Instrument' 
  AND FeedsRefDataSource = 'Siepe MOS' 
  AND FeedsLabel = 'Agent Bank'
```
**Output:** `GenericNormalizationJobId2`

---

### Step 6: Generic Import Job Execution
**Function:** `fGenericImportJob`  
**Action:** Import raw data files from source folder  
**Parameters:**
- GenericImportJobID
- SourceFolder
- ArchiveFolder (timestamped)

**Process:**
1. Scans source folder for new files
2. Imports data into staging tables
3. Archives processed files
4. Returns `RefDataSetDate` for processed data

**Timing Note:** Check log for import duration

---

### Step 7: Generic Normalization - Legal Entity
**Function:** `fGenericNormalization`  
**Action:** Normalize Agent Bank as Legal Entity records  
**Parameters:**
- GenericNormalizationJobID1
- RefDataSetDate (from Step 6)

**Process:**
1. Transforms raw data into standardized Legal Entity format
2. Validates data integrity
3. Prepares records for push to Reference system

**Timing Note:** Check log for normalization duration

---

### Step 8: Generic Normalization - Instrument Relation
**Function:** `fGenericNormalization`  
**Action:** Normalize Instrument-Legal Entity relationships  
**Parameters:**
- GenericNormalizationJobID2
- RefDataSetDate (from Step 6)

**Process:**
1. Creates relationships between Instruments and Agent Banks
2. Validates relationship integrity
3. Prepares for reference data push

---

### Step 9: Push Reference Data - Legal Entity
**Function:** `fGenericPushReferenceData`  
**Action:** Push Legal Entity records to Reference system  
**Parameters:**
- PushName: 'LegalEntity'
- RefDataSetDate

**Process:**
1. Validates normalized Legal Entity data
2. Pushes to Reference.LegalEntity table
3. Updates push status

**Timing Note:** Check log for push duration

---

### Step 10: Push Reference Data - Instrument
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument updates to Reference system  
**Parameters:**
- PushName: 'Instrument'
- RefDataSetDate

---

### Step 11: Push Reference Data - InstIdentifier
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument Identifier records  
**Parameters:**
- PushName: 'InstIdentifier'
- RefDataSetDate

---

### Step 12: Push Reference Data - InstLegalEntityRelation
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument-Agent Bank relationship records  
**Parameters:**
- PushName: 'InstLegalEntityRelation'
- RefDataSetDate

**Final Process:** Establishes complete Agent Bank relationships in Reference system

---

## Timing Analysis
**Review log file sections for:**
1. **Import Duration:** Time between "Generic Import START" and "Generic Import END"
2. **Normalization Duration:** Time for each normalization job
3. **Push Duration:** Time for each reference data push
4. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily/On-demand
- **Typical Run Time:** TBD (review logs)
- **Dependencies:** Requires source files in SourceFolder

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors
- Verify archive folder for processed files
