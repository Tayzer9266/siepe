# Middle Office Position Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficePositionLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** Daily Positions and Position Cash Flows
- **Log File Location:** `$dirLogFolder\MiddleOfficePositionLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes Position data and Position Cash Flow data from Siepe MOS. Processes historical dates and allows T+0 (current day) positions for daily deliverables. This is a complex dual-import process.

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
- `GenericJobNamePosition`: 'Siepe MOS Position Load'
- `GenericJobNamePositionCashFlow`: 'Siepe MOS PositionCashFlow Load'
- `GenericNormalizationJobType`: 'Custodian Position'
- `GenericNormalizationFeedsLabel`: 'Daily Positions'
- `GenericPushName`: 'Middle Office Position Load'
- `Source`: 'Siepe MOS'

**Manual Override Option:**
```powershell
# Uncomment to reprocess specific date:
# $ReturnDate = [datetime]::parseexact("10/26/2023", 'MM/dd/yyyy', $null)
```

---

### PHASE 1: POSITION IMPORT

### Step 3: Retrieve Position Import Job Configuration
**Action:** Query database for Position import settings  
**SQL Query:**
```sql
SELECT GenericImportJobId, SourceFolder, ArchiveLocation, FileName 
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1 
  AND Name = 'Siepe MOS Position Load' 
  AND Source = 'Siepe MOS'
```
**Retrieved Data:**
- `GenericImportJobId`
- `SourceFolder`
- `ArchiveLocation`

---

### Step 4: Determine Maximum Allowed Position Date
**Action:** Calculate maximum allowed date (T+0 for Aristotle)  
**SQL Query:**
```sql
SELECT dbo.fOffsetDate('{today}','C',0) AS MaxDate
```
**Special Note:** Unlike other loads, this allows T+0 (current day) positions  
**Purpose:** Support daily deliverable deadlines (after 4:00 PM CST validation in MOS)

**Output:** `MaxAllowedPositionDate`

---

### Step 5: Create Archive Folder
**Action:** Create timestamped archive folder  
**Location:** `$ArchiveFolder` (with timestamp)

---

### Step 6: Initialize Date Tracking Variables
**Action:** Set up date range tracking  
**Variables:**
- `$FromDate`: Empty string (will track earliest date)
- `$ToDate`: Empty string (will track latest date)

---

### Step 7: Change to Position Source Directory
**Action:** Navigate to position file location  
**Command:** `Set-Location $SourceFolder`

---

### Step 8: Split Raw Position Files by Date
**Function:** `fSplitFilesDate`  
**Action:** Split multi-date raw files into single-date files  
**File Pattern:** `MOS_Aristotle Position Extract Raw_*.csv`

**Parameters:**
- DateColumnName: 'RefDataSetDate'
- NewFileString: 'MOS_Aristotle Position Extract_'
- DateFormat: 'M/d/yyyy hh:mm:ss tt'

**Process:**
1. Reads raw file with multiple dates
2. Splits into separate files per date
3. Names files: `MOS_Aristotle Position Extract_{date}.csv`
4. Archives original raw file

**Timing Note:** Check log for file split duration

---

### Step 9: Import Position Files (Multi-File Loop)
**Function:** `fGenericImportJob`  
**Action:** Import each split position file  
**File Pattern:** `*MOS_Aristotle Position Extract_*.csv`

**Process for each file:**
1. Import position data to staging
2. Parse RefDataSetDate from filename
3. Track date range (FromDate/ToDate)
4. Archive processed file

**Date Tracking:**
- Updates `$FromDate` if current date is earlier
- Updates `$ToDate` if current date is later

**Timing Note:** Check log for each position file import time

---

### PHASE 2: POSITION CASH FLOW IMPORT

### Step 10: Retrieve PositionCashFlow Import Job Configuration
**Action:** Query database for PositionCashFlow import settings  
**SQL Query:**
```sql
SELECT GenericImportJobId, SourceFolder, ArchiveLocation, FileName 
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1 
  AND Name = 'Siepe MOS PositionCashFlow Load' 
  AND Source = 'Siepe MOS'
```
**Retrieved Data:**
- `GenericImportJobId` (PositionCashFlow)
- `SourceFolder` (PositionCashFlow)
- `ArchiveLocation`

---

### Step 11: Create PositionCashFlow Archive Folder
**Action:** Create timestamped archive folder for cash flows  

---

### Step 12: Retrieve Normalization Job Configuration
**Action:** Query for Position normalization job  
**SQL Query:**
```sql
SELECT GenericNormalizationJobID 
FROM Feeds.dbo.vGenericNormalizationJob 
WHERE RefRecStatusID = 1 
  AND GenericNormalizationJobType = 'Custodian Position' 
  AND FeedsRefDataSource = 'Siepe MOS' 
  AND FeedsLabel = 'Daily Positions'
```
**Output:** `GenericNormalizationJobId`

---

### Step 13: Retrieve Push Job Configuration
**Action:** Query for Position push job  
**SQL Query:**
```sql
SELECT GenericPushJobID 
FROM Feeds.dbo.vGenericPushJob 
WHERE Name = 'Middle Office Position Load' 
  AND RefRecStatusID = 1
```
**Output:** `GenericPushJobID`

---

### Step 14: Change to PositionCashFlow Source Directory
**Action:** Navigate to cash flow file location  
**Command:** `Set-Location $SourceFolder`

---

### Step 15: Split Raw PositionCashFlow Files by Date
**Function:** `fSplitFilesDate`  
**Action:** Split multi-date cash flow files into single-date files  
**File Pattern:** `MOS_Aristotle PositionCashflow Extract Raw_*.csv`

**Parameters:**
- DateColumnName: 'RefDataSetDate'
- NewFileString: 'MOS_Aristotle PositionCashflow Extract_'
- DateFormat: 'M/d/yyyy'

**Timing Note:** Check log for cash flow file split duration

---

### Step 16: Import PositionCashFlow Files (Multi-File Loop)
**Function:** `fGenericImportJob`  
**Action:** Import each split cash flow file  
**File Pattern:** `*MOS_Aristotle PositionCashflow Extract_*.csv`

**Process for each file:**
1. Import cash flow data to staging
2. Parse RefDataSetDate
3. Update date range tracking
4. Archive processed file

**Timing Note:** Check log for each cash flow file import time

---

### Step 17: Validate ToDate Against Maximum Allowed
**Action:** Enforce date cutoff  
**Logic:**
```powershell
if ($ToDate -gt $MaxAllowedPositionDate) { 
    $ToDate = $MaxAllowedPositionDate 
}
```

---

### PHASE 3: NORMALIZATION (Date Loop)

### Step 18: Validate Date Range
**Action:** Check if dates are valid DateTime objects  
**Condition:** `if ($FromDate -is [datetime] -and $ToDate -is [datetime])`

---

### Step 19: Generic Normalization Loop
**Function:** `fGenericNormalization`  
**Action:** Normalize position data for each date  
**Loop:** From `$FromDate` to `$ToDate` (day by day)

**Process for each date:**
1. Normalize position records
2. Normalize cash flow records
3. Execute InstAttributes capture (Step 20)
4. Increment to next day

**Timing Note:** Check log for normalization time per date (critical)

---

### Step 20: Capture InstAttributes (Per Date)
**Action:** Execute stored procedure per date  
**SQL Command:**
```sql
EXEC Custodian.pMiddleOfficeDataLoad_NormalizeInstAttributes 
  @RefDataSetDate = '{RefDataSetDate}'
```
**Purpose:** Extract instrument attributes from position data

**Timing Note:** Check log for InstAttributes time per date

---

### PHASE 4: REFERENCE DATA PUSH

### Step 21: Push Reference Data - Legal Entity
**Function:** `fGenericPushReferenceData`  
**Action:** Push Legal Entity updates  
**Parameters:**
- PushName: 'LegalEntity'
- RefDataSetDate: Final date in range

---

### Step 22: Push Reference Data - Instrument
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument updates  
**Parameters:**
- PushName: 'Instrument'
- RefDataSetDate

**Note:** Script has variable typo (`$pLogFile`) - check for errors

---

### Step 23: Push Reference Data - InstIdentifier
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument Identifier records  
**Parameters:**
- PushName: 'InstIdentifier'
- RefDataSetDate

---

### Step 24: Push Reference Data - InstValue
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument Value records  
**Parameters:**
- PushName: 'InstValue'
- RefDataSetDate

---

### Step 25: Push Position Data
**Function:** `fGenericPushPosition`  
**Action:** Push position records to Core system  
**Parameters:**
- GenericPushJobID
- RefDataSetDate

**Timing Note:** Check log for position push duration (may be substantial)

---

## Timing Analysis
**Review log file sections for:**

1. **Import Phase - Positions:**
   - File split time
   - Time per position file import
   - Total position import time
   - Number of position files processed

2. **Import Phase - Cash Flows:**
   - File split time
   - Time per cash flow file import
   - Total cash flow import time
   - Number of cash flow files processed

3. **Normalization Phase:**
   - Time per date normalization
   - Time per InstAttributes capture
   - Number of dates processed
   - Total normalization time

4. **Push Phase:**
   - Individual reference data push times
   - Position push time (critical metric)
   - Total push time

5. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily (likely automated)
- **Run Time:** After 4:00 PM CST (allows T+0 positions)
- **Typical Duration:** TBD (review logs) - Expect longer runtime for multi-date processing
- **Dependencies:** 
  - Position extract files in source folder
  - Cash flow extract files in source folder
  - MOS validation check (4:00 PM cutoff)

## Special Considerations
⚠️ **T+0 Processing:** Unlike other loads, this allows current day (T+0) positions  
⚠️ **Dual File Sets:** Processes both Position and PositionCashFlow files  
⚠️ **Date Range Processing:** Handles multiple dates in single run  
⚠️ **Daily Deliverables:** Critical for meeting client and vendor deadlines  
⚠️ **File Splitting:** Multi-date raw files are split before processing  
⚠️ **Date Synchronization:** Ensure Position and CashFlow files align on dates

## Data Flow
1. **Source Files:**
   - MOS_Aristotle Position Extract Raw CSV files
   - MOS_Aristotle PositionCashflow Extract Raw CSV files
2. **File Processing:** Split multi-date files into single-date files
3. **Staging:** Feeds database (Custodian schema)
4. **Normalization:** Per-date with InstAttributes capture
5. **Target:** Core database (Position tables)

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors
- Verify both Position and CashFlow imports completed
- Monitor date range alignment between file types
- Check archive folders for all processed files
- Review for variable typo errors in push phase

## File Naming Conventions
**Input Files:**
- `MOS_Aristotle Position Extract Raw_*.csv`
- `MOS_Aristotle PositionCashflow Extract Raw_*.csv`

**Split Files:**
- `MOS_Aristotle Position Extract_{date}.csv`
- `MOS_Aristotle PositionCashflow Extract_{date}.csv`

**Archive:** All files moved to timestamped archive folders
