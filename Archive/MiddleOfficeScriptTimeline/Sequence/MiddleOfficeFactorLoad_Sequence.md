# Middle Office Factor Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficeFactorLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** Aristotle Factor Extract (Instrument attributes/factors)
- **Log File Location:** `$dirLogFolder\MiddleOfficeFactorLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes Factor data from Siepe MOS. Processes multiple dates from raw files and includes InstAttributes capture.

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
- `GenericImportJobID`: 29 (hardcoded)
- Script retrieves SourceFolder and ArchiveLocation from database

---

### Step 3: Retrieve Import Job Folder Configuration
**Action:** Query database for folder paths  
**SQL Query:**
```sql
SELECT SourceFolder, ArchiveLocation 
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1 
  AND GenericImportJobID = '29'
```
**Retrieved Data:**
- `SourceFolder` → stored in `$dirDeliveryStoreFolder`
- `ArchiveLocation` → stored in `$dirArchiveFolder` (with timestamp)

**Log Output:**
- SourceFolder path
- ArchiveFolder path

---

### Step 4: Determine Maximum Position Date
**Action:** Calculate maximum allowed date for processing  
**SQL Query:**
```sql
SELECT dbo.fOffsetDate('{today}','C',-1) AS MaxDate
```
**Purpose:** Prevent loading data beyond the most recent weekday  
**Output:** `MaxPositionDate` (T-1 business day)

**Timing Note:** Ensures data integrity by respecting cutoff dates

---

### Step 5: Create Archive Folder
**Action:** Create timestamped archive folder if it doesn't exist  
**Location:** `$dirArchiveFolder`

---

### Step 6: Change to Source Directory
**Action:** Navigate to delivery folder  
**Command:** `Set-Location $dirDeliveryStoreFolder`

---

### COMMENTED OUT: File Splitting Step
**Note:** The file splitting step is commented out in the script  
```powershell
# foreach ($strFileName in Get-ChildItem -Path $dirDeliveryStoreFolder | 
#   Where-Object {$_.Name -ilike "MOS_Aristotle Factor Extract Raw_*.csv"}) {
#   fSplitFilesDate -pDateColumnName "RefDataSetDate" ...
# }
```
**Reason:** Files may already be pre-split or script handles multi-date files differently

---

### Step 7: Generic Import Job Execution (Multi-File Loop)
**Function:** `fGenericImportJob`  
**Action:** Import each Factor extract file  
**File Pattern:** `*MOS_Aristotle Factor Extract Raw_*.csv`

**Process for each file:**
1. Import raw factor data
2. Parse RefDataSetDate from file
3. Track date range (`$FromDate` to `$ToDate`)
4. Archive processed file

**Date Tracking:**
- `$FromDate`: Earliest date found in files
- `$ToDate`: Latest date found in files

**Timing Note:** Check log for each file import duration

---

### Step 8: Validate Date Range
**Action:** Ensure ToDate doesn't exceed MaxPositionDate  
**Logic:**
```powershell
if ($ToDate -gt $MaxPositionDate) { $ToDate = $MaxPositionDate }
```
**Purpose:** Enforce business date cutoff

---

### NORMALIZATION PHASE (Date Loop)

### Step 9: Generic Normalization Loop
**Function:** `fGenericNormalization`  
**Action:** Normalize factor data for each date in range  
**Loop:** From `$FromDate` to `$ToDate` (day by day)

**Parameters:**
- GenericNormalizationJobID: 19 (hardcoded)
- RefDataSetDate: Current date in loop

**Process for each date:**
1. Normalize factor data for the date
2. Execute InstAttributes capture (Step 10)
3. Increment to next day

**Timing Note:** Check log for normalization time per date

---

### Step 10: Capture InstAttributes (Per Date)
**Action:** Execute stored procedure to normalize instrument attributes  
**SQL Command:**
```sql
EXEC Custodian.pMiddleOfficeDataLoad_NormalizeInstAttributes 
  @RefDataSetDate = '{RefDataSetDate}'
```
**Purpose:** Extract and normalize instrument-specific attributes from factor data

**Timing Note:** Check log for InstAttributes capture time per date

---

### REFERENCE DATA PUSH PHASE

### Step 11: Push Reference Data - Legal Entity
**Function:** `fGenericPushReferenceData`  
**Action:** Push Legal Entity updates  
**Parameters:**
- PushName: 'LegalEntity'
- RefDataSetDate: Final date in range

---

### Step 12: Push Reference Data - Instrument
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument updates  
**Parameters:**
- PushName: 'Instrument'
- RefDataSetDate

---

### Step 13: Push Reference Data - InstIdentifier
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument Identifier records  
**Parameters:**
- PushName: 'InstIdentifier'
- RefDataSetDate

---

### Step 14: Push InstValues
**Action:** Execute InstValue push stored procedure  
**SQL Command:**
```sql
EXEC GenericPushClient.pRunInstValuePush
```
**Database:** Reference  
**Timeout:** 600 seconds (10 minutes)

**Purpose:** Push all instrument values/factors to client system

**Timing Note:** Check log for InstValue push duration (may be lengthy)

---

## Timing Analysis
**Review log file sections for:**

1. **Import Phase:**
   - Time per file import
   - Total import time for all files
   - Number of files processed

2. **Normalization Phase:**
   - Time per date normalization
   - Time per InstAttributes capture
   - Number of dates processed
   - Total normalization time

3. **Push Phase:**
   - Individual reference data push times
   - InstValue push time (critical - 10 minute timeout)
   - Total push time

4. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily/On-demand
- **Typical Run Time:** TBD (review logs) - May process multiple dates
- **Dependencies:** 
  - Requires Factor extract files in source folder
  - Date range determined by file contents
  - Respects T-1 business day cutoff

## Special Considerations
⚠️ **Multi-Date Processing:** Script can process multiple dates in single run  
⚠️ **Date Validation:** Automatically prevents loading future dates  
⚠️ **InstAttributes:** Special processing step per date for instrument attributes  
⚠️ **InstValue Timeout:** 10-minute timeout on final push (monitor for timeouts)

## Data Flow
1. **Source:** MOS_Aristotle Factor Extract Raw CSV files
2. **Staging:** Feeds database (Custodian schema)
3. **Normalization:** Per-date normalization with attribute capture
4. **Target:** Reference database (InstValue, InstAttributes)

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors
- Verify date range processing completed
- Monitor InstValue push for timeout errors
- Check archive folder for all processed files

## File Naming Convention
**Input:** `MOS_Aristotle Factor Extract Raw_*.csv`  
**Archive:** Files moved to timestamped archive folder after processing
