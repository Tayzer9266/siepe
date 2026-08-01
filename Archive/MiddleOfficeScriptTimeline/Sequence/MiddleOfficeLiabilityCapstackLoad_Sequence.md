# Middle Office Liability Capstack Load - Process Sequence

## Script Information
- **Script Name:** MiddleOfficeLiabilityCapstackLoad.ps1
- **Source:** Siepe MOS
- **Data Type:** Liability Capstack (capital structure/debt hierarchy)
- **Log File Location:** `$dirLogFolder\MiddleOfficeLiabilityCapstackLoad.{timestamp}.txt`

## Process Overview
Imports and normalizes Liability Capstack data from Siepe MOS, capturing capital structure and debt hierarchy information for instruments.

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
- `GenericJobName`: 'Siepe MOS LiabilityCapstack Load'
- `GenericNormalizationJobType`: 'Custodian Instrument'
- `GenericNormalizationFeedsLabel`: 'LiabilityCapstack'
- `Source`: 'Siepe MOS'

**Manual Override Options:**
```powershell
# Option 1: Already commented out in script:
# $ReturnDate = [datetime]::parseexact("07/31/2023", 'MM/dd/yyyy', $null)

# Option 2: Uncomment to reprocess specific date:
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
  AND Name = 'Siepe MOS LiabilityCapstack Load' 
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
  AND FeedsLabel = 'LiabilityCapstack'
```
**Output:** `GenericNormalizationJobId`

---

### Step 5: Generic Import Job Execution
**Function:** `fGenericImportJob`  
**Action:** Import liability capstack data files  
**Parameters:**
- GenericImportJobID
- pDirSourceFolder: null (uses configured folder)
- pDirArchiveFolder: null (uses configured folder)

**Process:**
1. Scans source folder for capstack files
2. Imports capital structure data into staging tables
3. Archives processed files
4. Returns `RefDataSetDate`

**Output:** `$ReturnDate` captured for use in subsequent steps

**Timing Note:** Check log for import duration

---

### Step 6: Generic Normalization - Liability Capstack
**Function:** `fGenericNormalization`  
**Action:** Normalize liability capstack records  
**Parameters:**
- GenericNormalizationJobID
- RefDataSetDate (from Step 5)

**Process:**
1. Transforms raw capstack data to standard format
2. Validates capital structure hierarchies
3. Associates debt layers with instruments
4. Validates seniority and subordination relationships
5. Prepares for reference data push

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
   - LiabilityCapstack (capital structure data)
3. Updates push status for each type

**Timing Note:** Check log for individual push durations

---

## Timing Analysis
**Review log file sections for:**
1. **Import Duration:** Time to import capstack files
2. **Normalization Duration:** Time to normalize capital structure data
3. **Push Duration:** Total time for all reference data pushes
4. **Total Runtime:** Script START to completion

## Schedule Information
- **Run Frequency:** Daily/On-demand
- **Typical Run Time:** TBD (review logs)
- **Dependencies:** 
  - Requires LiabilityCapstack extract files in SourceFolder
  - Should run after Instrument Load
  - May depend on Legal Entity and InstDebt loads

## Special Considerations
⚠️ **Capital Structure:** Data represents debt hierarchy and seniority  
⚠️ **Waterfall Analysis:** Used for payment waterfall calculations  
⚠️ **Credit Analysis:** Critical for credit and risk assessment  
⚠️ **Valuation:** Impacts instrument valuation and recovery analysis

## Data Flow
1. **Source:** Siepe MOS LiabilityCapstack Extract
2. **Staging:** Feeds database (Custodian schema)
3. **Normalization:** Standard capital structure format
4. **Target:** Reference database (LiabilityCapstack tables)

## Business Purpose
Captures liability capital structure including:
- Debt layers and tranches
- Seniority levels
- Subordination relationships
- Collateral backing
- Priority of payments
- Recovery hierarchies

This data is essential for:
- Credit risk analysis
- Recovery rate estimation
- Valuation modeling
- Waterfall calculations
- Covenant analysis
- Restructuring scenarios

## Data Elements
Typical capstack data includes:
- Instrument identification
- Layer/tranche name
- Seniority level (Senior, Mezzanine, Subordinated, etc.)
- Secured vs. Unsecured status
- Collateral description
- Priority ranking
- Size of debt layer
- Covenant information

## Error Handling
- All errors logged to timestamped log file
- Check log for SQL execution errors
- Verify archive folder contains processed files
- Validate capital structure relationships
- Check for orphaned records
- Verify seniority hierarchy integrity

## Related Processes
- **Instrument Load:** Must run before this load
- **InstDebt Load:** May contain related debt information
- **Default Load:** Uses capstack for recovery calculations
- **Valuation:** Consumes capstack for pricing models
- **Risk Reporting:** Uses capstack for credit analysis
