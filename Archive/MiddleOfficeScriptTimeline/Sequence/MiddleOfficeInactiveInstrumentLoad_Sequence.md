# Middle Office Inactive Instrument Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficeInactiveInstrumentLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** Inactive Instruments (WatchList mapping)
- **Log File Location:** `$dirLogFolder\MiddleOfficeInactiveInstrumentLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes Inactive Instrument data from Siepe MOS, then maps these instruments to the WatchListMap table for monitoring purposes.

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
- `GenericJobName`: 'Siepe MOS Inactive Instruments'
- `GenericNormalizationJobType`: 'Custodian Instrument'
- `GenericNormalizationFeedsLabel`: 'InactiveInstruments'
- `Source`: 'Siepe MOS'

**Manual Override Options:**
```powershell
# Option 1: Uncomment to reprocess specific date:
# $ReturnDate = [datetime]::parseexact("10/26/2023", 'MM/dd/yyyy', $null)

# Option 2: Already commented out in script:
# $ReturnDate = [datetime]::parseexact("07/31/2023", 'MM/dd/yyyy', $null)
```

---

### Step 3: Retrieve Generic Import Job Configuration
**Action:** Query database for import job settings  
**SQL Query:**
```sql
SELECT GenericImportJobId, SourceFolder, ArchiveLocation, FileName 
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1 
  AND Name = 'Siepe MOS Inactive Instruments' 
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

### Step 4: Generic Import Job Execution
**Function:** `fGenericImportJob`  
**Action:** Import inactive instrument data files  
**Parameters:**
- GenericImportJobID
- pDirSourceFolder: null (uses configured folder)
- pDirArchiveFolder: null (uses configured folder)

**Process:**
1. Scans source folder for inactive instrument files
2. Imports data into staging tables
3. Archives processed files
4. Returns `RefDataSetDate`

**Timing Note:** Check log for import duration

---

### Step 5: Retrieve Normalization Job Configuration
**Action:** Query for Custodian Instrument normalization job  
**SQL Query:**
```sql
SELECT GenericNormalizationJobID 
FROM Feeds.dbo.vGenericNormalizationJob 
WHERE RefRecStatusID = 1 
  AND GenericNormalizationJobType = 'Custodian Instrument' 
  AND FeedsRefDataSource = 'Siepe MOS' 
  AND FeedsLabel = 'InactiveInstruments'
```
**Output:** `GenericNormalizationJobId`

---

### Step 6: Generic Normalization - Inactive Instruments
**Function:** `fGenericNormalization`  
**Action:** Normalize inactive instrument records  
**Parameters:**
- GenericNormalizationJobID
- RefDataSetDate (from Step 4)

**Process:**
1. Transforms raw inactive instrument data to standard format
2. Validates instrument references
3. Prepares for reference data push and watchlist mapping

**Timing Note:** Check log for normalization duration

---

### Step 7: Push All Reference Data Items
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
   - Other related reference data
3. Updates push status for each type

**Timing Note:** Check log for push duration

---

### Step 8: Map Inactive Instruments to WatchListMap
**Action:** Execute stored procedure to map instruments  
**SQL Command:**
```sql
EXEC dbo.pInactiveInstrumentsLoad
```
**Database:** Core  

**Purpose:** 
- Maps inactive instruments to WatchListMap table
- Enables monitoring and tracking of inactive instruments
- Supports compliance and risk management

**Timing Note:** Check log for mapping procedure duration

---

## Timing Analysis
**Review log file sections for:**
1. **Import Duration:** Time to import inactive instrument files
2. **Normalization Duration:** Time to normalize records
3. **Push Duration:** Time for all reference data pushes
4. **Mapping Duration:** Time to execute pInactiveInstrumentsLoad
5. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily/On-demand
- **Typical Run Time:** TBD (review logs)
- **Dependencies:** 
  - Requires inactive instrument extract files in SourceFolder
  - Should run after main Instrument Load
  - Core.dbo.WatchListMap table must exist

## Special Considerations
⚠️ **WatchList Integration:** Final step populates monitoring/watchlist table  
⚠️ **Compliance:** Inactive instruments may require special tracking  
⚠️ **Reference Data:** Pushes updates to existing reference data before mapping

## Data Flow
1. **Source:** Siepe MOS Inactive Instruments Extract
2. **Staging:** Feeds database (Custodian schema)
3. **Normalization:** Standard instrument format
4. **Reference Push:** Updates Reference database
5. **Final Target:** Core.dbo.WatchListMap table

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors
- Verify archive folder contains processed files
- Check WatchListMap table for proper population
- Monitor pInactiveInstrumentsLoad procedure for errors

## Business Purpose
This load identifies instruments that have become inactive in the source system and ensures they are properly tracked and monitored through the WatchList functionality.
