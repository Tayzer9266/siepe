# Middle Office Instrument Default Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficeInstDefaultLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** Instrument Default information
- **Log File Location:** `$dirLogFolder\MiddleOfficeInstDefaultLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes Instrument Default data from Siepe MOS, capturing default events and characteristics for debt instruments.

---

## Step Sequence

### Step 1: Initialize Script Environment
**Action:** Load configuration and create log folder  
**Dependencies:** 
- Environment variable: `$env:Powershell_ConfigRootLocation`
- Function library: `fMasterFunctionDeclare.ps1`
**Output:** Log file created with timestamp

**Log Message:** "$PSScriptName START"

---

### Step 2: Configure Job Parameters
**Action:** Set job-specific variables  
**Parameters:**
- `GenericJobName`: 'Siepe MOS InstDefault Load'
- `GenericNormalizationJobType`: 'Custodian Instrument'
- `GenericNormalizationFeedsLabel`: 'InstDefault'
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
  AND Name = 'Siepe MOS InstDefault Load' 
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
  AND FeedsLabel = 'InstDefault'
```
**Output:** `GenericNormalizationJobId`

---

### Step 5: Generic Import Job Execution
**Function:** `fGenericImportJob`  
**Action:** Import instrument default data files  
**Parameters:**
- GenericImportJobID
- SourceFolder
- ArchiveFolder (timestamped)

**Process:**
1. Scans source folder for default data files
2. Imports data into staging tables
3. Archives processed files
4. Returns `RefDataSetDate`

**Output:** `$RefDataSetDate` captured for use in subsequent steps

**Timing Note:** Check log for import duration

---

### Step 6: Generic Normalization - Instrument Default
**Function:** `fGenericNormalization`  
**Action:** Normalize instrument default records  
**Parameters:**
- GenericNormalizationJobID
- RefDataSetDate (from Step 5)

**Process:**
1. Transforms raw default data to standard format
2. Validates default event data
3. Associates defaults with instruments
4. Prepares for reference data push

**Timing Note:** Check log for normalization duration

---

### Step 7: Push Reference Data - Legal Entity
**Function:** `fGenericPushReferenceData`  
**Action:** Push Legal Entity updates  
**Parameters:**
- PushName: 'LegalEntity'
- RefDataSetDate

**Process:** Pushes any Legal Entity records associated with default events

---

### Step 8: Push Reference Data - Instrument
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument updates  
**Parameters:**
- PushName: 'Instrument'
- RefDataSetDate

**Process:** Updates instrument records with default-related information

---

### Step 9: Push Reference Data - InstIdentifier
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument Identifier records  
**Parameters:**
- PushName: 'InstIdentifier'
- RefDataSetDate

**Process:** Ensures all instrument identifiers are current

---

### Step 10: Push Reference Data - InstDefault
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument Default records  
**Parameters:**
- PushName: 'InstDefault'
- RefDataSetDate

**Process:** 
- Pushes default event records to Reference system
- Updates default status for instruments
- Critical for risk management and compliance

**Timing Note:** Check log for InstDefault push duration (critical step)

---

## Timing Analysis
**Review log file sections for:**
1. **Import Duration:** Time to import default data files
2. **Normalization Duration:** Time to normalize default records
3. **Push Phase Duration:**
   - LegalEntity push time
   - Instrument push time
   - InstIdentifier push time
   - InstDefault push time (most critical)
4. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily/On-demand
- **Typical Run Time:** TBD (review logs)
- **Dependencies:** 
  - Requires InstDefault extract files in SourceFolder
  - Should run after main Instrument Load
  - Critical for risk and compliance reporting

## Special Considerations
⚠️ **Risk Management:** Default data is critical for risk assessment  
⚠️ **Compliance:** Default events may trigger regulatory reporting  
⚠️ **Timing:** Should be processed promptly when defaults occur  
⚠️ **Data Sensitivity:** Default information may be time-sensitive

## Data Flow
1. **Source:** Siepe MOS InstDefault Extract
2. **Staging:** Feeds database (Custodian schema)
3. **Normalization:** Standard instrument default format
4. **Target:** Reference database (InstDefault table)

## Business Purpose
Captures and tracks instrument default events including:
- Default dates
- Default types
- Recovery information
- Credit events
- Covenant breaches

This data is essential for:
- Risk management
- Compliance reporting
- Portfolio valuation
- Credit analysis

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors
- Verify archive folder contains processed files
- Monitor InstDefault push for data integrity
- Validate default records in Reference database

## Related Processes
- **Instrument Load:** Must run before this load
- **Position Load:** May use default data for valuation
- **Risk Reporting:** Consumes default data
- **Compliance Reporting:** Requires default event tracking
