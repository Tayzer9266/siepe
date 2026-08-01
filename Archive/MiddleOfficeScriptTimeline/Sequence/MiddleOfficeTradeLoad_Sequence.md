# Middle Office Trade Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficeTradeLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** ITD (Inception-To-Date) Trades
- **Log File Location:** `$dirLogFolder\MiddleOfficeTradeLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes Trade data from Siepe MOS, capturing all inception-to-date trade activity. Includes settlement date auto-update functionality for unsettled trades.

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
- `GenericJobName`: 'Siepe MOS Trade Load'
- `GenericNormalizationJobType`: 'Custodian Trade'
- `GenericNormalizationFeedsLabel`: 'ITD Trades'
- `GenericPushName`: 'Middle Office Trade Load'
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
  AND Name = 'Siepe MOS Trade Load' 
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
**Action:** Query for Custodian Trade normalization job  
**SQL Query:**
```sql
SELECT GenericNormalizationJobID 
FROM Feeds.dbo.vGenericNormalizationJob 
WHERE RefRecStatusID = 1 
  AND GenericNormalizationJobType = 'Custodian Trade' 
  AND FeedsRefDataSource = 'Siepe MOS' 
  AND FeedsLabel = 'ITD Trades'
```
**Output:** `GenericNormalizationJobId`

---

### Step 5: Retrieve Push Job Configuration
**Action:** Query for Trade push job  
**SQL Query:**
```sql
SELECT GenericPushJobID 
FROM Feeds.dbo.vGenericPushJob 
WHERE RefRecStatusID = 1 
  AND Name = 'Middle Office Trade Load'
```
**Output:** `GenericPushJobId`

**Note:** Used in Step 12 for pushing trades

---

### Step 6: Generic Import Job Execution
**Function:** `fGenericImportJob`  
**Action:** Import ITD trade data files  
**Parameters:**
- GenericImportJobID
- SourceFolder
- ArchiveFolder (timestamped)

**Process:**
1. Scans source folder for trade files
2. Imports all inception-to-date trades
3. Archives processed files
4. Returns `RefDataSetDate`

**Output:** `$RefDataSetDate` captured

**Timing Note:** Check log for import duration (may be large file with all trades)

---

### Step 7: Generic Normalization - Trades
**Function:** `fGenericNormalization`  
**Action:** Normalize trade records  
**Parameters:**
- GenericNormalizationJobID
- RefDataSetDate

**Process:**
1. Transforms raw trade data to standard format
2. Validates trade attributes
3. Associates trades with instruments and portfolios
4. Prepares for reference data push and trade push

**Timing Note:** Check log for normalization duration

---

### REFERENCE DATA PUSH PHASE

### Step 8: Push Reference Data - Legal Entity
**Function:** `fGenericPushReferenceData`  
**Action:** Push Legal Entity updates  
**Parameters:**
- PushName: 'LegalEntity'
- RefDataSetDate

**Process:** Pushes any Legal Entity records associated with trades (counterparties, brokers)

---

### Step 9: Push Reference Data - Instrument
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument updates  
**Parameters:**
- PushName: 'Instrument'
- RefDataSetDate

**Process:** Ensures instruments referenced in trades exist in Reference

**Note:** Variable typo in script (`$pLogFile` instead of `$LogFile`)

---

### Step 10: Push Reference Data - InstIdentifier
**Function:** `fGenericPushReferenceData`  
**Action:** Push Instrument Identifier records  
**Parameters:**
- PushName: 'InstIdentifier'
- RefDataSetDate

---

### Step 11: Push Reference Data - Portfolio
**Function:** `fGenericPushReferenceData`  
**Action:** Push Portfolio records  
**Parameters:**
- PushName: 'Portfolio'
- RefDataSetDate

**Process:** Ensures all portfolios referenced in trades exist

---

### TRADE DATA PUSH PHASE

### Step 12: Push Trade Data
**Function:** `fGenericPushTrade`  
**Action:** Push trade records to Core system  
**Parameters:**
- GenericPushJobID
- RefDataSetDate
- ScriptName: $PSScriptName

**Process:**
1. Validates normalized trade data
2. Pushes trades to Core.Trade tables
3. Creates/updates trade records
4. Links trades to instruments and portfolios

**Timing Note:** Check log for trade push duration (critical timing for large trade volumes)

---

### SETTLEMENT DATE UPDATE PHASE

### Step 13: Check Client Configuration for Settlement Date Auto-Update
**Action:** Query client configuration setting  
**SQL Query:**
```sql
SELECT [Value] 
FROM Core.dbo.tClientConfiguration 
WHERE [Module] = 'OMS' 
  AND [Name] = 'US Bank Unsettled Trade File'
```
**Output:** `$ClientConfigurationValue`

**Purpose:** Determine if automatic settlement date capture is enabled

---

### Step 14: Execute Settlement Date Capture (Conditional)
**Action:** Update ActualSettleDate for unsettled trades  
**Condition:** Only runs if `$ClientConfigurationValue = 'TRUE'`

**SQL Command:**
```sql
EXEC Client.pSiepeMosSettleDateCapture
```
**Database:** Core  
**Timeout:** `$CommandTimeOut`

**Purpose:**
- Automatically updates ActualSettleDate in Trade Capture
- Uses MOS tTrade data to update settlement dates
- Keeps settlement status current
- Reduces manual intervention

**Timing Note:** Check log for settlement capture duration

---

### INSTRUMENT DEACTIVATION PHASE

### Step 15: Deactivate Deleted Instruments
**Action:** Execute instrument deactivation procedure  
**SQL Command:**
```sql
EXEC Reference.Client.pSiepeMOSInstrumentDeactivation @Debug = 0
```
**Database:** Reference  
**Timeout:** `$CommandTimeOut`

**Purpose:**
- Identifies instruments no longer in MOS
- Deactivates (soft delete) removed instruments
- Maintains data integrity
- Runs as part of trade load for comprehensive cleanup

**Timing Note:** Check log for deactivation duration

---

## Timing Analysis
**Review log file sections for:**
1. **Import Duration:** Time to import ITD trade file (may be large)
2. **Normalization Duration:** Time to normalize all trades
3. **Reference Data Push Duration:**
   - LegalEntity push time
   - Instrument push time
   - InstIdentifier push time
   - Portfolio push time
4. **Trade Push Duration:** Time to push all trades (critical metric)
5. **Settlement Capture Duration:** Time for ActualSettleDate updates (if enabled)
6. **Deactivation Duration:** Time for instrument deactivation
7. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily
- **Typical Run Time:** TBD (review logs) - Expect substantial runtime for full ITD
- **Dependencies:** 
  - Requires ITD trade extract file
  - Should run after Instrument Load
  - Should run after Portfolio references are available

## Special Considerations
⚠️ **ITD (Inception-To-Date):** Processes ALL trades, not just new/updated  
⚠️ **Large Data Volume:** May contain thousands of historical trades  
⚠️ **Settlement Auto-Update:** Conditional feature based on client config  
⚠️ **Instrument Cleanup:** Includes instrument deactivation as part of load  
⚠️ **Variable Typo:** Script has `$pLogFile` typo in Steps 9-10 - may cause log issues

## Data Flow
1. **Source:** Siepe MOS Trade Extract (ITD)
2. **Staging:** Feeds database (Custodian schema)
3. **Normalization:** Standard trade format
4. **Reference Push:** LegalEntity, Instrument, Portfolio
5. **Trade Push:** Core database (Trade tables)
6. **Post-Processing:** Settlement date updates, instrument cleanup

## Trade Data Includes
- Trade identification
- Trade date and settlement date
- Instrument and portfolio references
- Quantity and price
- Trade type (Buy, Sell, etc.)
- Counterparty information
- Broker information
- Commission and fees
- Settlement status
- Trade status

## Client Configuration Feature
**US Bank Unsettled Trade File:**
- Module: OMS
- Name: 'US Bank Unsettled Trade File'
- Value: 'TRUE' or 'FALSE'
- Effect: Enables automatic settlement date capture from MOS data

## Business Purpose
Captures complete trade history including:
- Historical trades (inception-to-date)
- New trades
- Trade amendments
- Settlement updates
- Trade cancellations
- Counterparty relationships

Essential for:
- Position reconciliation
- P&L calculations
- Trade reporting
- Compliance reporting
- Settlement tracking
- Commission analysis

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors
- Verify archive folder contains processed files
- Monitor trade push for data integrity
- Check settlement capture results (if enabled)
- Verify instrument deactivation results
- Watch for variable typo errors in reference pushes

## Validation Checks
After successful run, verify:
1. Trade count matches expectations
2. New trades were added successfully
3. Updated trades reflect changes
4. Settlement dates updated (if feature enabled)
5. Instrument deactivation list is accurate
6. Portfolio references are valid
7. Instrument references are valid
8. No orphaned records

## Related Processes
- **Position Load:** Depends on trades for position calculation
- **Instrument Load:** Must run before trade load
- **Portfolio Management:** Trade assignments to portfolios
- **Settlement Processing:** Uses trade data for settlement
- **P&L Calculation:** Consumes trade data
- **Compliance Reporting:** Requires trade data
