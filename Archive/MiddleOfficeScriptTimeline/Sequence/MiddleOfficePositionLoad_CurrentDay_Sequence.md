# Middle Office Position Load (Current Day) - Process Sequence

## Script Information
- **Script Name:** MiddleOfficePositionLoad_CurrentDay.ps1
- **Source:** Siepe MOS
- **Data Type:** Current Day (T+0) Positions and Position Cash Flows
- **Log File Location:** `$dirLogFolder\MiddleOfficePositionLoad_CurrentDay.{timestamp}.txt`

## Process Overview
**SPECIAL PURPOSE:** This is a specialized version of MiddleOfficePositionLoad.ps1 designed specifically for loading CURRENT DAY (T+0) positions from a dedicated "Current Day" folder. Used for real-time/intraday position updates.

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
- `SourceFolder` (from database)
- `ArchiveLocation`

---

### Step 4: Determine Maximum Position Date
**Action:** Calculate maximum allowed date (T+0 for current day processing)  
**SQL Query:**
```sql
SELECT dbo.fOffsetDate('{today}','C',0) AS MaxDate
```
**Purpose:** Allow current day (T+0) positions  
**Output:** `MaxPositionDate` (today's business date)

---

### Step 5: Create Archive Folder
**Action:** Create timestamped archive folder  

---

### Step 6: Initialize Date Tracking Variables
**Action:** Set up date range tracking  
**Variables:**
- `$FromDate`: Empty string (will track earliest date)
- `$ToDate`: Empty string (will track latest date)

---

### Step 7: **OVERRIDE** Source Folder to Current Day Path
**Action:** Set hardcoded path for current day files  
**Code:**
```powershell
$SourceFolder = "\\aristotle.aws\SHARED\Clients\134\PROD\Siepe MOS\Position\Current Day"
$ArchiveFolder = "\\aristotle.aws\SHARED\Clients\134\PROD\Siepe MOS\Position\Current Day\Archive"
```
**⚠️ CRITICAL:** This overrides the database configuration and points to a dedicated "Current Day" folder

**Purpose:** Separate current day positions from historical loads

---

### Step 8: Change to Current Day Source Directory
**Action:** Navigate to current day position file location  
**Command:** `Set-Location $SourceFolder`

---

### Step 9: Split Raw Position Files by Date
**Function:** `fSplitFilesDate`  
**Action:** Split raw files into single-date files  
**File Pattern:** `MOS_Aristotle Position Extract Raw_*.csv`

**Parameters:**
- DateColumnName: 'RefDataSetDate'
- NewFileString: 'MOS_Aristotle Position Extract_'
- DateFormat: 'M/d/yyyy hh:mm:ss tt'

**Timing Note:** Check log for file split duration

---

### Step 10: Validate Single File After Split
**Action:** Ensure only ONE position file exists after split  
**Code:**
```powershell
$SplitFiles = @(Get-ChildItem -Path $SourceFolder | 
    Where-Object { $_.Name -ilike '*MOS_Aristotle Position Extract_*.csv' })
if ($SplitFiles.Count -ne 1) {
    fLog -pLogFile $LogFile -pMessage "ERROR: Expected 1 Position file after split, found $($SplitFiles.Count). Aborting."
    exit
}
```
**⚠️ CRITICAL:** Script expects exactly ONE date (current day) - aborts if multiple dates found

**Timing Note:** Check log for validation result

---

### Step 11: Import Position File
**Function:** `fGenericImportJob`  
**Action:** Import the single position file  
**File Pattern:** `*MOS_Aristotle Position Extract_*.csv`

**Process:**
1. Import current day position data
2. Parse RefDataSetDate
3. Track date (should be today)
4. Archive processed file

**Timing Note:** Check log for import time

---

### Step 12: Retrieve PositionCashFlow Import Job Configuration
**Action:** Query database for PositionCashFlow import settings  
**SQL Query:**
```sql
SELECT GenericImportJobId, SourceFolder, ArchiveLocation, FileName 
FROM Feeds.dbo.vGenericImportJob 
WHERE RefRecStatusID = 1 
  AND Name = 'Siepe MOS PositionCashFlow Load' 
  AND Source = 'Siepe MOS'
```

**Note:** Script truncates here in the provided excerpt - remaining steps would follow the standard Position Load pattern for cash flows, normalization, and pushes.

---

## Timing Analysis
**Review log file sections for:**
1. **Validation Duration:** Time to validate single file requirement
2. **Import Duration:** Time to import current day position file
3. **File Count Check:** Verify exactly 1 file was processed
4. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Intraday/Multiple times per day
- **Run Time:** After current day data becomes available (after 4:00 PM CST)
- **Typical Duration:** TBD (review logs) - Should be faster than full Position Load
- **Dependencies:** 
  - Current day position file in "Current Day" folder
  - MOS validation check passed (4:00 PM cutoff)
  - Separate from historical position loads

## Special Considerations
⚠️ **CURRENT DAY ONLY:** This script is designed ONLY for T+0 (today) positions  
⚠️ **HARDCODED PATH:** Uses hardcoded "Current Day" folder path, not database config  
⚠️ **SINGLE FILE VALIDATION:** Aborts if multiple files/dates found  
⚠️ **REAL-TIME PROCESSING:** Supports intraday position updates  
⚠️ **SEPARATE ARCHIVE:** Uses dedicated "Current Day\Archive" folder  
⚠️ **ISOLATED PROCESSING:** Independent from historical Position Load

## Differences from Standard Position Load
| Aspect | Standard Position Load | Current Day Position Load |
|--------|----------------------|--------------------------|
| **Source Folder** | Database configured | Hardcoded "Current Day" path |
| **Date Range** | T-1 and earlier | T+0 only (current day) |
| **File Count** | Multiple dates allowed | Exactly 1 date required |
| **Run Frequency** | Daily | Intraday/multiple |
| **Purpose** | Historical loads | Real-time updates |
| **Validation** | Date range check | Single file check |

## Data Flow
1. **Source:** Current Day folder (hardcoded path)
2. **Validation:** Exactly 1 position file for today
3. **Staging:** Feeds database (Custodian schema)
4. **Normalization:** Same as standard position load
5. **Target:** Core database (Position tables)

## Use Cases
- **Intraday Reporting:** Provide current day positions before EOD
- **Real-Time Dashboards:** Update positions during trading day
- **Client Deliverables:** Meet tight delivery deadlines
- **Vendor Feeds:** Provide current positions to vendors
- **Compliance Monitoring:** Real-time position monitoring

## Error Handling
- All errors logged to timestamped log file
- **CRITICAL:** Script aborts if file count ≠ 1
- Check log for file validation errors
- Verify "Current Day" folder path accessible
- Monitor for path/permission issues
- Check archive folder for processed file

## Validation Checks
After successful run, verify:
1. Exactly 1 position file was processed
2. RefDataSetDate = current business day
3. File was moved to Current Day archive
4. Positions loaded to Core database
5. No files left in Current Day source folder

## Path References
- **Source:** `\\aristotle.aws\SHARED\Clients\134\PROD\Siepe MOS\Position\Current Day`
- **Archive:** `\\aristotle.aws\SHARED\Clients\134\PROD\Siepe MOS\Position\Current Day\Archive`

## Client-Specific Note
This script appears to be Aristotle-specific based on:
- Path references to "aristotle.aws"
- Client ID 134 in path
- File naming convention "MOS_Aristotle Position Extract"
