# Middle Office Data Load Process - Master Overview

## Document Purpose
This master document provides an overview of all Middle Office data load scripts, their execution sequence, dependencies, and timing analysis guidance.

## Related Documentation
- **[Master Execution Charts](MiddleOffice_Master_Execution_Charts.md)** ⭐ - Comprehensive visual charts showing:
  - Execution frequency & intraday patterns
  - 24-hour timeline with all scripts
  - Step-by-step breakdown with actual durations
  - **Database deadlock & concurrency risk analysis** (NEW)
  - Performance bottlenecks & optimization opportunities
  - Weekly patterns & SLA recommendations
- **[Actual Timing & Schedule Analysis](MiddleOffice_Actual_Timing_Schedule.md)** - Detailed timing analysis with actual run schedules, performance metrics, and monitoring recommendations
- Individual sequence documentation files for each script in the [Sequence](Sequence/) folder (see Script Inventory below)

---

## Script Inventory

| Script Name | Data Type | Priority | Dependencies |
|------------|-----------|----------|--------------|
| MiddleOfficeInstrumentLoad | Core Instruments | **CRITICAL - RUN FIRST** | None |
| MiddleOfficeAgentBankLoad | Agent Bank / Legal Entity | High | Instrument Load |
| MiddleOfficeAmortizationLoad | Amortization Schedules | Medium | Instrument Load |
| MiddleOfficeContractCashFlowDebtLoad | Debt/Cash Flow/Issue | High | Instrument Load |
| MiddleOfficeFactorLoad | Factors/Attributes | Medium | Instrument Load |
| MiddleOfficeInstDefaultLoad | Defaults | High | Instrument Load |
| MiddleOfficeInactiveInstrumentLoad | Inactive Instruments | Medium | Instrument Load |
| MiddleOfficeLiabilityCapstackLoad | Capital Structure | Medium | Instrument Load |
| MiddleOfficePositionLoad | Positions | **CRITICAL** | All Reference Loads |
| MiddleOfficePositionLoad_CurrentDay | Current Day Positions | High | All Reference Loads |
| MiddleOfficeTradeLoad | Trades | **CRITICAL** | Instrument, Portfolio |

---

## Recommended Execution Order

### Phase 1: Foundation (Reference Data)
**Must Complete First - Other Loads Depend On These**

1. **MiddleOfficeInstrumentLoad** ⭐ FOUNDATIONAL
   - Creates core instrument master records
   - ALL other loads depend on this
   - Typical Runtime: 15-20 minutes
   - Schedule: Hourly (runs 20+ times daily)
   - Log Review: Focus on import and push timing

---

### Phase 2: Instrument Attributes (Can Run in Parallel)
**Run After Instrument Load Completes**

2. **MiddleOfficeAgentBankLoad**
   - Legal Entity and Agent Bank relationships
   - Schedule: Daily at 09:05 AM
   - Typical Runtime: 5-10 minutes
   - Can run in parallel with other Phase 2 loads

3. **MiddleOfficeAmortizationLoad**
   - Amortization schedules
   - Schedule: Daily at 02:30 AM
   - Typical Runtime: <5 minutes
   - Can run in parallel with other Phase 2 loads

4. **MiddleOfficeContractCashFlowDebtLoad**
   - Debt instruments, cash flows, and issues
   - Processes 3 file types sequentially
   - Schedule: Daily at 02:20-02:55 AM
   - Typical Runtime: <10 minutes

5. **MiddleOfficeFactorLoad**
   - Factors and instrument attributes
   - Handles multi-date processing
   - Schedule: Daily at 08:05 AM
   - Typical Runtime: 5-10 minutes
   - Can run in parallel with other Phase 2 loads

6. **MiddleOfficeInstDefaultLoad**
   - Default events
   - Schedule: Daily at 02:30-03:00 AM
   - Typical Runtime: <5 minutes
   - Can run in parallel with other Phase 2 loads

7. **MiddleOfficeInactiveInstrumentLoad**
   - Inactive instrument tracking
   - Schedule: TBD (no recent logs)
   - Can run in parallel with other Phase 2 loads

8. **MiddleOfficeLiabilityCapstackLoad**
   - Capital structure
   - Schedule: Daily at 02:20-02:55 AM
   - Typical Runtime: <5 minutes
   - Can run in parallel with other Phase 2 loads

---

### Phase 3: Transactional Data
**Run After All Reference Data Completes**

9. **MiddleOfficeTradeLoad** ⭐ CRITICAL
   - ITD (Inception-To-Date) trades
   - Must complete before Position Load
   - Schedule: 5-7 times daily (10:00 AM, 02:00 PM, 04:00 PM, 08:00 PM, 10:00 PM, 02:00 AM)
   - Typical Runtime: 10-15 minutes

10. **MiddleOfficePositionLoad** ⭐ CRITICAL
    - Daily positions and cash flows
    - Processes multiple dates
    - Allows T+0 (current day)
    - Schedule: Multiple times daily (02:00-03:00 AM, intraday updates)
    - Typical Runtime: 15-30 minutes

11. **MiddleOfficePositionLoad_CurrentDay**
    - Real-time/intraday positions
    - Runs separately from historical load
    - Schedule: 2-3 times daily (03:00 PM pre-cutoff, 07:00-08:00 PM post-cutoff)
    - Typical Runtime: 5-10 minutes

---

## Dependency Map

```
MiddleOfficeInstrumentLoad (Foundation)
    ├── MiddleOfficeAgentBankLoad
    ├── MiddleOfficeAmortizationLoad
    ├── MiddleOfficeContractCashFlowDebtLoad
    ├── MiddleOfficeFactorLoad
    ├── MiddleOfficeInstDefaultLoad
    ├── MiddleOfficeInactiveInstrumentLoad
    ├── MiddleOfficeLiabilityCapstackLoad
    ├── MiddleOfficeTradeLoad
    │       └── MiddleOfficePositionLoad
    │               └── MiddleOfficePositionLoad_CurrentDay (Optional/Intraday)
    └── MiddleOfficePositionLoad (Alternative: can run parallel with Trade Load)
```

---

## Timing Analysis Framework

### How to Use Log Files for Timing Analysis

Each script creates a timestamped log file in `$dirLogFolder`:
- Format: `{ScriptName}.{yyyyMMddTHHmmss}.txt`
- Example: `MiddleOfficeInstrumentLoad.20260708T143022.txt`

### Key Timing Metrics to Extract

#### 1. **Overall Script Timing**
```
Search for: "{ScriptName} START"
Search for: Script completion or last operation
Calculate: Total elapsed time
```

#### 2. **Import Phase Timing**
```
Search for: "Generic Import" or "fGenericImportJob"
Search for: File names and counts
Search for: "Changed directory" (indicates file processing)
Calculate: Time from start to archive completion
```

#### 3. **Normalization Phase Timing**
```
Search for: "Generic Normalization" or "fGenericNormalization"
Search for: RefDataSetDate being processed
For multi-date: Calculate time per date
Calculate: Total normalization time
```

#### 4. **Push Phase Timing**
```
Search for: "Push" or "fGenericPushReferenceData"
Track each push type: LegalEntity, Instrument, InstIdentifier, etc.
Calculate: Time per push type
Calculate: Total push time
```

#### 5. **Special Operations Timing**
```
Search for: "pMiddleOfficeDataLoad_NormalizeInstAttributes" (Factor/Position)
Search for: "pInactiveInstrumentsLoad" (Inactive Instrument)
Search for: "pSiepeMOSInstrumentDeactivation" (Instrument/Trade)
Search for: "pSiepeMosSettleDateCapture" (Trade)
Calculate: Time per stored procedure
```

---

## Log File Analysis Template

### For Each Script, Track:

| Metric | Search Pattern | Expected Range | Actual Time | Notes |
|--------|---------------|----------------|-------------|-------|
| Total Runtime | START to END | TBD | | |
| Import Time | Import START to END | TBD | | |
| File Count | "Found X files" | TBD | | |
| Normalization Time | Normalization START to END | TBD | | |
| Dates Processed | RefDataSetDate entries | TBD | | |
| LegalEntity Push | "LegalEntity" push | TBD | | |
| Instrument Push | "Instrument" push | TBD | | |
| InstIdentifier Push | "InstIdentifier" push | TBD | | |
| Other Pushes | Varies by script | TBD | | |
| Special Procs | Stored proc names | TBD | | |
| Errors/Warnings | "ERROR", "FAILED", "WARNING" | 0 | | |

---

## Sample Timing Extraction Queries

### PowerShell Script to Extract Timing from Logs

```powershell
# Extract timing information from log file
param([string]$LogFile)

$Content = Get-Content $LogFile
$StartTime = $null
$EndTime = $null

foreach ($Line in $Content) {
    if ($Line -match '(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}:\d{3})') {
        $Timestamp = [DateTime]::ParseExact($Matches[1], 'yyyy/MM/dd HH:mm:ss:fff', $null)
        
        if ($Line -match 'START' -and $null -eq $StartTime) {
            $StartTime = $Timestamp
        }
        
        $EndTime = $Timestamp  # Keep updating to get last timestamp
    }
    
    # Extract specific operations
    if ($Line -match 'GenericImportJobId') { Write-Host "Import Job: $Line" }
    if ($Line -match 'RefDataSetDate') { Write-Host "Processing Date: $Line" }
    if ($Line -match 'Push|push') { Write-Host "Push Operation: $Line" }
    if ($Line -match 'ERROR|FAILED') { Write-Host "ERROR: $Line" -ForegroundColor Red }
}

if ($StartTime -and $EndTime) {
    $Duration = $EndTime - $StartTime
    Write-Host "`nTotal Duration: $($Duration.TotalMinutes) minutes"
    Write-Host "Start: $StartTime"
    Write-Host "End: $EndTime"
}
```

---

## Performance Baseline Template

### Create a Performance Baseline Spreadsheet

| Script Name | Date | Start Time | End Time | Duration (min) | File Count | Record Count | Errors | Notes |
|------------|------|------------|----------|----------------|------------|--------------|--------|-------|
| MiddleOfficeInstrumentLoad | | | | | | | | |
| MiddleOfficeAgentBankLoad | | | | | | | | |
| MiddleOfficeAmortizationLoad | | | | | | | | |
| MiddleOfficeContractCashFlowDebtLoad | | | | | | | | |
| MiddleOfficeFactorLoad | | | | | | | | |
| MiddleOfficeInstDefaultLoad | | | | | | | | |
| MiddleOfficeInactiveInstrumentLoad | | | | | | | | |
| MiddleOfficeLiabilityCapstackLoad | | | | | | | | |
| MiddleOfficePositionLoad | | | | | | | | |
| MiddleOfficePositionLoad_CurrentDay | | | | | | | | |
| MiddleOfficeTradeLoad | | | | | | | | |

### Track Over Time
- Create weekly averages
- Identify performance degradation
- Spot anomalies
- Plan for scaling

---

## Common Performance Bottlenecks

### Based on Script Analysis

1. **MiddleOfficeInstrumentLoad**
   - Bottleneck: Instrument push (full universe)
   - Monitor: Large file import times
   - Optimization: Consider incremental loads if possible

2. **MiddleOfficeContractCashFlowDebtLoad**
   - Bottleneck: Three sequential imports
   - Monitor: Combined normalization time
   - Optimization: Can't parallelize (dependencies)

3. **MiddleOfficeFactorLoad**
   - Bottleneck: Per-date normalization loop
   - Monitor: InstAttributes capture per date
   - Optimization: Date range determines performance

4. **MiddleOfficePositionLoad**
   - Bottleneck: Multi-date processing, dual file sets
   - Monitor: File split time, normalization per date
   - Optimization: Limit date range processed

5. **MiddleOfficeTradeLoad**
   - Bottleneck: ITD (all trades), large data volume
   - Monitor: Trade push duration
   - Optimization: Consider incremental if ITD not required

---

## Monitoring and Alerting Recommendations

### Set Up Alerts For:

1. **Duration Alerts**
   - Script runs longer than baseline + 50%
   - Script runs longer than absolute threshold (e.g., 60 minutes)

2. **Failure Alerts**
   - Errors in log files
   - Zero files processed
   - Archive folder empty
   - Push failures

3. **Data Quality Alerts**
   - Record counts significantly different from baseline
   - Missing expected files
   - Date range gaps

4. **Dependency Alerts**
   - Instrument Load fails (blocks all others)
   - Reference loads incomplete before transactional loads

---

## Troubleshooting Guide

### Script Fails or Runs Slow?

1. **Check Log File First**
   - Location: `$dirLogFolder\{ScriptName}.{timestamp}.txt`
   - Search for: ERROR, FAILED, WARNING

2. **Common Issues**
   - Source folder empty: No files to process
   - Archive folder permissions: Cannot move files
   - Database connectivity: SQL timeout errors
   - SQL deadlocks: Concurrent execution conflicts
   - Disk space: Archive folder full

3. **Performance Issues**
   - Large file size: Import taking too long
   - Date range: Too many dates being processed
   - Missing indexes: Database performance degraded
   - Network latency: UNC path slowness

---

## Schedule Recommendations

### Daily Production Schedule

```
Phase 1: Foundation (Sequential)
06:00 - MiddleOfficeInstrumentLoad

Phase 2: Attributes (Parallel - after Instrument completes)
07:00 - MiddleOfficeAgentBankLoad
07:00 - MiddleOfficeAmortizationLoad  
07:00 - MiddleOfficeFactorLoad
07:00 - MiddleOfficeInstDefaultLoad
07:00 - MiddleOfficeInactiveInstrumentLoad
07:00 - MiddleOfficeLiabilityCapstackLoad
07:00 - MiddleOfficeContractCashFlowDebtLoad (may take longer)

Phase 3: Transactional (Sequential - after all Phase 2 completes)
09:00 - MiddleOfficeTradeLoad
10:00 - MiddleOfficePositionLoad (after Trade completes)

Phase 4: Intraday (Multiple times)
12:00 - MiddleOfficePositionLoad_CurrentDay (first run)
16:00 - MiddleOfficePositionLoad_CurrentDay (after 4PM cutoff)
18:00 - MiddleOfficePositionLoad_CurrentDay (final run)
```

**Adjust times based on actual runtime from log analysis**

---

## Documentation References

Individual sequence documents for each script:
- [MiddleOfficeAgentBankLoad_Sequence.md](Sequence/MiddleOfficeAgentBankLoad_Sequence.md)
- [MiddleOfficeAmortizationLoad_Sequence.md](Sequence/MiddleOfficeAmortizationLoad_Sequence.md)
- [MiddleOfficeContractCashFlowDebtLoad_Sequence.md](Sequence/MiddleOfficeContractCashFlowDebtLoad_Sequence.md)
- [MiddleOfficeFactorLoad_Sequence.md](Sequence/MiddleOfficeFactorLoad_Sequence.md)
- [MiddleOfficeInactiveInstrumentLoad_Sequence.md](Sequence/MiddleOfficeInactiveInstrumentLoad_Sequence.md)
- [MiddleOfficeInstDefaultLoad_Sequence.md](Sequence/MiddleOfficeInstDefaultLoad_Sequence.md)
- [MiddleOfficeInstrumentLoad_Sequence.md](Sequence/MiddleOfficeInstrumentLoad_Sequence.md)
- [MiddleOfficeLiabilityCapstackLoad_Sequence.md](Sequence/MiddleOfficeLiabilityCapstackLoad_Sequence.md)
- [MiddleOfficePositionLoad_Sequence.md](Sequence/MiddleOfficePositionLoad_Sequence.md)
- [MiddleOfficePositionLoad_CurrentDay_Sequence.md](Sequence/MiddleOfficePositionLoad_CurrentDay_Sequence.md)
- [MiddleOfficeTradeLoad_Sequence.md](Sequence/MiddleOfficeTradeLoad_Sequence.md)

---

## Next Steps

1. ✅ Review individual sequence documents for each script
2. ⏳ Collect log files for recent runs
3. ⏳ Extract timing metrics using log analysis
4. ⏳ Create performance baseline spreadsheet
5. ⏳ Establish monitoring and alerting
6. ⏳ Optimize identified bottlenecks
7. ⏳ Document production schedule

---

**Document Created:** 2026-07-08  
**Last Updated:** 2026-07-08  
**Version:** 1.0
