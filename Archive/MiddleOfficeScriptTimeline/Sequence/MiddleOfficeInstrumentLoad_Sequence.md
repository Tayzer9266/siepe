# Middle Office Instrument Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficeInstrumentLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** Core Instrument data (master instrument records)
- **Log File Location:** `$dirLogFolder\MiddleOfficeInstrumentLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes core Instrument data from Siepe MOS. This is the foundational instrument master data load that other loads depend on. Includes deactivation of deleted instruments.

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
- `GenericJobName`: 'Siepe MOS Instrument Load'
- `GenericNormalizationJobType`: 'Custodian Instrument'
- `GenericNormalizationFeedsLabel`: 'Instrument Extract'
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
  AND Name = 'Siepe MOS Instrument Load' 
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
  AND FeedsLabel = 'Instrument Extract'
```
**Output:** `GenericNormalizationJobId`

---

### Step 5: Generic Import Job Execution
**Function:** `fGenericImportJob`  
**Action:** Import core instrument data files  
**Parameters:**
- GenericImportJobID
- SourceFolder
- ArchiveFolder (timestamped)

**Process:**
1. Scans source folder for instrument extract files
2. Imports master instrument data into staging tables
3. Archives processed files
4. Returns `RefDataSetDate`

**Output:** `$ReturnDate` captured for use in subsequent steps

**Timing Note:** Check log for import duration (may be substantial for full instrument set)

---

### Step 6: Generic Normalization - Instrument
**Function:** `fGenericNormalization`  
**Action:** Normalize core instrument records  
**Parameters:**
- GenericNormalizationJobID
- RefDataSetDate (from Step 5)

**Process:**
1. Transforms raw instrument data to standardized format
2. Validates instrument attributes
3. Creates/updates instrument master records
4. Prepares for reference data push

**Timing Note:** Check log for normalization duration (critical step)

---

### Step 7: Push Reference Data - Legal Entity
**Function:** `fGenericPushReferenceData`  
**Action:** Push Legal Entity updates  
**Parameters:**
- PushName: 'LegalEntity'
- RefDataSetDate

**Process:** Pushes any Legal Entity records associated with instruments (issuers, etc.)

---

### Step 8: Push Reference Data - Instrument
**Function:** `fGenericPushReferenceData`  
**Action:** Push core Instrument records  
**Parameters:**
- PushName: 'Instrument'
- RefDataSetDate

**Process:**
- Pushes instrument master records to Reference system
- Updates existing instruments
- Creates new instruments
- Critical step for entire instrument universe

**Timing Note:** Check log for Instrument push duration (most critical timing)

---

### Step 9: Push Reference Data - InstIdentifier
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument Identifier records  
**Parameters:**
- PushName: 'InstIdentifier'
- RefDataSetDate

**Process:**
- Pushes all instrument identifiers (CUSIP, ISIN, Ticker, etc.)
- Enables instrument lookups by various identifiers
- Critical for instrument matching

**Timing Note:** Check log for InstIdentifier push duration

---

### Step 10: Deactivate Deleted Instruments
**Action:** Execute stored procedure to deactivate instruments removed from MOS  
**SQL Command:**
```sql
EXEC Reference.Client.pSiepeMOSInstrumentDeactivation
```
**Database:** Reference  
**Timeout:** `$CommandTimeOut` (configurable)

**Purpose:**
- Identifies instruments that exist in Reference but not in latest MOS extract
- Deactivates (soft delete) these instruments
- Maintains data integrity
- Preserves historical references

**Process:**
1. Compares Reference instruments to latest MOS extract
2. Identifies instruments missing from MOS
3. Sets instruments to inactive status
4. Logs deactivation actions

**Timing Note:** Check log for deactivation procedure duration

---

## Timing Analysis
**Review log file sections for:**
1. **Import Duration:** Time to import instrument extract (large file)
2. **Normalization Duration:** Time to normalize all instruments (critical)
3. **Push Phase Duration:**
   - LegalEntity push time
   - Instrument push time (most critical - full instrument set)
   - InstIdentifier push time
4. **Deactivation Duration:** Time to run deactivation procedure
5. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily (foundational load)
- **Typical Run Time:** TBD (review logs) - Expect longer runtime
- **Dependencies:** 
  - Must run BEFORE most other instrument-related loads
  - Other loads depend on this completing successfully
  - Critical foundation for entire data pipeline

## Special Considerations
⚠️ **Foundational Load:** Most other loads depend on this completing successfully  
⚠️ **Full Instrument Universe:** Processes complete set of instruments  
⚠️ **Deactivation Logic:** Soft-deletes instruments removed from source  
⚠️ **Performance:** Large file processing - monitor for performance issues  
⚠️ **Data Integrity:** Critical for entire system - validate thoroughly

## Data Flow
1. **Source:** Siepe MOS Instrument Extract (full universe)
2. **Staging:** Feeds database (Custodian schema)
3. **Normalization:** Standard instrument master format
4. **Target:** Reference database (Instrument, InstIdentifier tables)
5. **Cleanup:** Deactivate instruments deleted from source

## Instrument Data Includes
- Instrument names and descriptions
- Instrument types and classifications
- Issuers and sponsors
- Identifiers (CUSIP, ISIN, Ticker, etc.)
- Basic characteristics
- Status information

## Dependent Loads
The following loads depend on Instrument Load completing:
- Agent Bank Load (InstLegalEntityRelation)
- Amortization Load (InstAmort)
- Contract Cash Flow Load (InstDebt, InstContract)
- Factor Load (InstAttributes, InstValue)
- Default Load (InstDefault)
- Inactive Instrument Load
- Position Load (references instruments)
- Trade Load (references instruments)

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors
- Verify archive folder contains processed files
- Monitor Instrument push for data integrity
- Check deactivation procedure results
- Validate instrument counts in Reference database

## Validation Checks
After successful run, verify:
1. Instrument count in Reference matches expectations
2. New instruments were added successfully
3. Updated instruments reflect changes
4. Deactivated instruments list is accurate
5. All identifiers are present
6. No orphaned records
