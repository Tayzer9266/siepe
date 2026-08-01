# Middle Office Data Loads - Actual Timing & Schedule Analysis
**Analysis Date:** July 8, 2026  
**Data Source:** Log files from Client Refresh Log folders (May-July 2026)

---

## Executive Summary

Based on analysis of recent log files, here are the **actual scheduled run times** and **typical durations** for each Middle Office data load script:

| Script Name | Typical Start Time | Average Duration | Run Frequency |
|-------------|-------------------|------------------|---------------|
| **MiddleOfficeInstrumentLoad** | **Hourly** (03:00-21:00) | ~15-20 min | **Multiple times per hour** |
| **MiddleOfficeAmortizationLoad** | **02:30 AM** | <5 min | **Daily** |
| **MiddleOfficeContractCashFlowDebtLoad** | **02:20-02:55 AM** | <10 min | **Daily** |
| **MiddleOfficeInstDefaultLoad** | **02:30-03:00 AM** | <5 min | **Daily** |
| **MiddleOfficeLiabilityCapstackLoad** | **02:20-02:55 AM** | <5 min | **Daily** |
| **MiddleOfficeFactorLoad** | **08:00-08:05 AM** | 5-10 min | **Daily** |
| **MiddleOfficeAgentBankLoad** | **09:00-09:05 AM** | 5-10 min | **Daily** |
| **MiddleOfficeTradeLoad** | **Multiple** (10:00 AM, 2:00 PM, 4:00 PM, 8:00 PM, 10:00 PM) | 10-15 min | **5-7 times daily** |
| **MiddleOfficePositionLoad** | **Multiple** (02:00-03:00 AM, Intraday) | 15-30 min | **Multiple daily** |
| **MiddleOfficePositionLoad_CurrentDay** | **03:00 PM & 07:00-08:00 PM** | 5-10 min | **2-3 times daily** |

---

## Detailed Script Timing Analysis

### 1. MiddleOfficeInstrumentLoad ⭐ FOUNDATIONAL
**Purpose:** Core instrument master data load - ALL other loads depend on this

**Schedule Pattern:**
- Runs **HOURLY** throughout the day
- Peak hours: 03:00, 04:00, 05:00, 06:00, 07:00, 08:00, 09:00, 10:00, 11:00, 12:00, 13:00, 14:00, 15:00, 16:00, 17:00, 18:00, 19:00, 20:00, 21:00
- Also runs at 30-minute intervals during some hours (e.g., 06:15, 12:15, 15:10, etc.)

**Recent Performance (July 7, 2026):**
| Run Time | Duration | Notes |
|----------|----------|-------|
| 03:10 AM | ~15 min | Early morning standard run |
| 06:15 AM | ~20 min | Mid-morning update |
| 09:15 AM | ~18 min | Business hours update |
| 12:15 PM | ~20 min | Midday update |
| 15:10 PM | ~18 min | Afternoon update |
| 18:20 PM | ~15 min | Evening update |

**Log Location:** `Client Refresh Log\Instrument\`

**Performance Notes:**
- Runs frequently (20+ times per day)
- Consistent ~15-20 minute duration
- Log files show successful completion with 11-12 KB file sizes
- Critical dependency - must complete before dependent loads start

---

### 2. MiddleOfficeAmortizationLoad
**Purpose:** Instrument amortization schedules

**Schedule:** **Daily at 02:30 AM** (02:27-03:00 AM range)

**Recent Performance (Past 7 Days):**
| Date | Start Time | Status |
|------|------------|--------|
| Jul 7 | 03:00 AM | ✅ Complete |
| Jul 6 | 02:50 AM | ✅ Complete |
| Jul 5 | 02:40 AM | ✅ Complete |
| Jul 4 | 02:44 AM | ✅ Complete |
| Jul 3 | 02:39 AM | ✅ Complete |

**Log Location:** `Client Refresh Log\Amortization\`

**Performance Notes:**
- Consistent daily morning execution
- Small log files (~35 KB) indicate quick processing
- Runs after ContractCashFlow but before Inst Default
- Dependencies: Must run after Instrument Load completes

---

### 3. MiddleOfficeContractCashFlowDebtLoad
**Purpose:** Debt instruments, contract cash flows, and issue data (3 file types)

**Schedule:** **Daily at 02:20-02:55 AM**

**Recent Performance:**
| Date | Start Time | Status |
|------|------------|--------|
| Jul 7 | 02:51 AM | ✅ Complete |
| Jul 6 | 02:46 AM | ✅ Complete |
| Jul 5 | 02:31 AM | ✅ Complete |
| Jul 4 | 02:35 AM | ✅ Complete |
| Jul 3 | 02:34 AM | ✅ Complete |

**Log Location:** `Client Refresh Log\ContractCashFlow\`

**Performance Notes:**
- Processes 3 sequential imports (InstContractCashFlow, InstDebt, InstIssue)
- Log files ~27 KB
- Runs early morning before other dependent loads
- Critical for debt-related calculations

---

### 4. MiddleOfficeInstDefaultLoad
**Purpose:** Instrument default events and data

**Schedule:** **Daily at 02:30-03:00 AM**

**Recent Performance:**
| Date | Start Time | Status |
|------|------------|--------|
| Jul 7 | 03:00 AM | ✅ Complete |
| Jul 6 | 02:50 AM | ✅ Complete |
| Jul 5 | 02:40 AM | ✅ Complete |
| Jul 4 | 02:44 AM | ✅ Complete |
| Jul 3 | 02:39 AM | ✅ Complete |

**Log Location:** `Client Refresh Log\InstDefault\`

**Performance Notes:**
- Small log files (~12 KB) - quick processing
- Runs alongside Amortization load
- Critical for risk management
- Same timing pattern as Amortization

---

### 5. MiddleOfficeLiabilityCapstackLoad
**Purpose:** Capital structure and debt hierarchy

**Schedule:** **Daily at 02:20-02:55 AM**

**Recent Performance:**
| Date | Start Time | Status |
|------|------------|--------|
| Jul 7 | 02:55 AM | ✅ Complete |
| Jul 6 | 02:45 AM | ✅ Complete |
| Jul 5 | 02:35 AM | ✅ Complete |
| Jul 4 | 02:39 AM | ✅ Complete |
| Jul 3 | 02:34 AM | ✅ Complete |

**Log Location:** `Client Refresh Log\LiabilityCapstack\`

**Performance Notes:**
- Log files ~35 KB
- Runs in early morning batch with other reference loads
- Completes quickly (under 5 minutes typical)

---

### 6. MiddleOfficeFactorLoad
**Purpose:** Instrument factors and attributes

**Schedule:** **Daily at 08:00-08:05 AM**

**Recent Performance:**
| Date | Start Time | Status |
|------|------------|--------|
| Jul 7 | 08:05 AM | ✅ Complete |
| Jul 6 | 08:05 AM | ✅ Complete |
| Jul 5 | 08:05 AM | ✅ Complete |
| Jul 4 | 08:04 AM | ✅ Complete |
| Jul 3 | 08:04 AM | ✅ Complete |

**Log Location:** `Client Refresh Log\Factor\`

**Performance Notes:**
- Very consistent 08:05 AM start time
- Log files ~14 KB
- Processes multi-date ranges
- Includes InstAttributes capture
- Critical for valuation

---

### 7. MiddleOfficeAgentBankLoad
**Purpose:** Agent Bank (Legal Entity) relationships

**Schedule:** **Daily at 09:00-09:05 AM**

**Recent Performance:**
| Date | Start Time | Status |
|------|------------|--------|
| Jul 7 | 09:05 AM | ✅ Complete |
| Jul 6 | 09:05 AM | ✅ Complete |
| Jul 5 | 09:05 AM | ✅ Complete |
| Jul 4 | 09:04 AM | ✅ Complete |
| Jul 3 | 09:04 AM | ✅ Complete |

**Log Location:** `Client Refresh Log\AgentBank\`

**Performance Notes:**
- Extremely consistent 09:05 AM start time
- Log files ~15 KB
- Two normalization jobs (LegalEntity + Custodian Instrument)
- Quick execution (5-10 minutes)

---

### 8. MiddleOfficeTradeLoad ⭐ CRITICAL
**Purpose:** ITD (Inception-To-Date) trades

**Schedule:** **Multiple times daily:**
- **10:00 AM** (10:49-10:56 AM)
- **01:00-02:00 PM** (13:40-14:00)
- **03:00-04:00 PM** (15:00-16:00)
- **08:00-09:00 PM** (20:00-21:00)
- **10:00-11:00 PM** (22:00-23:00)
- **02:00-03:00 AM** (02:24-03:00)

**Recent Performance (July 7, 2026):**
| Run Time | Status |
|----------|--------|
| 02:55 AM | ✅ Complete |
| 10:56 AM | ✅ Complete |
| 02:00 PM | ✅ Complete |
| 03:45 PM | ✅ Complete |
| 04:56 PM | ✅ Complete |

**Log Location:** `Client Refresh Log\TradeLoad\`

**Performance Notes:**
- Runs 5-7 times daily
- Log files ~14-15 KB
- ITD load (all trades, not incremental)
- Includes settlement date capture
- Includes instrument deactivation
- Duration: 10-15 minutes typical

---

### 9. MiddleOfficePositionLoad ⭐ CRITICAL
**Purpose:** Daily positions and position cash flows (historical + current day)

**Schedule:** **Multiple times daily:**
- **02:00-03:00 AM** - Overnight batch
- **07:00-09:00 AM** - Morning updates
- **11:00 AM-12:00 PM** - Late morning
- **01:00-03:00 PM** - Afternoon updates

**Recent Performance (July 7, 2026):**
| Run Time | Notes |
|----------|-------|
| 01:49 AM | Overnight batch |
| 09:35 AM | Morning update |
| 11:10 AM | Late morning |
| 11:55 AM | Pre-noon |
| 01:15 PM | Afternoon |
| 02:50 PM | Mid-afternoon |

**Log Location:** `Client Refresh Log\PositionLoad\`

**Performance Notes:**
- Processes multiple dates
- Handles Position + PositionCashFlow files
- File splitting for multi-date files
- Per-date normalization with InstAttributes
- Duration: 15-30 minutes typical
- Log files ~27 KB

**Special Consideration:** Allows T+0 (current day) positions for Aristotle client

---

### 10. MiddleOfficePositionLoad_CurrentDay
**Purpose:** Real-time/intraday current day (T+0) positions ONLY

**Schedule:** **2-3 times daily:**
- **03:00 PM** (14:50-15:00) - First current day run
- **07:00-08:00 PM** (19:00-20:00) - After 4PM cutoff
- Sometimes additional runs at 09:00 PM

**Recent Performance (July 7, 2026):**
| Run Time | Purpose |
|----------|---------|
| 02:50 PM | Pre-cutoff current day positions |

**Recent Performance (July 6, 2026):**
| Run Time | Purpose |
|----------|---------|
| 02:55 PM | Pre-cutoff |
| 08:15 PM | Post-cutoff (after 4PM validation) |

**Log Location:** `Client Refresh Log\PositionLoad\` (same folder, filename suffix: `_CurrentDay`)

**Performance Notes:**
- **Hardcoded path:** `\\aristotle.aws\SHARED\Clients\134\PROD\Siepe MOS\Position\Current Day`
- **Single file validation:** Script aborts if multiple dates found
- **Quick execution:** 5-10 minutes
- **Purpose:** Support intraday reporting and vendor feeds
- **Critical validation:** Ensures exactly 1 file for current day only

---

## Production Schedule Recommendation

Based on actual observed timing patterns:

```
PHASE 1: FOUNDATION (Sequential) - Must complete first
├─ 03:00 AM → MiddleOfficeInstrumentLoad (Hourly, ~20 min)

PHASE 2: REFERENCE DATA LOADS (Parallel after Instrument)
├─ 02:20 AM → MiddleOfficeContractCashFlowDebtLoad (~10 min)
├─ 02:30 AM → MiddleOfficeAmortizationLoad (~5 min)
├─ 02:30 AM → MiddleOfficeInstDefaultLoad (~5 min)
├─ 02:35 AM → MiddleOfficeLiabilityCapstackLoad (~5 min)
├─ 08:05 AM → MiddleOfficeFactorLoad (~10 min)
└─ 09:05 AM → MiddleOfficeAgentBankLoad (~10 min)

PHASE 3: TRANSACTIONAL DATA (After all reference complete)
├─ 02:30 AM → MiddleOfficePositionLoad (overnight batch, ~30 min)
├─ 10:50 AM → MiddleOfficeTradeLoad (first daily, ~15 min)
├─ 13:40 PM → MiddleOfficeTradeLoad (midday, ~15 min)
├─ 15:00 PM → MiddleOfficePositionLoad_CurrentDay (pre-cutoff, ~10 min)
├─ 16:00 PM → MiddleOfficeTradeLoad (afternoon, ~15 min)
├─ 20:00 PM → MiddleOfficeTradeLoad (evening, ~15 min)
├─ 20:00 PM → MiddleOfficePositionLoad_CurrentDay (post-cutoff, ~10 min)
└─ 22:00 PM → MiddleOfficeTradeLoad (final daily, ~15 min)

CONTINUOUS:
└─ MiddleOfficeInstrumentLoad runs hourly all day (foundation for all)
```

---

## Key Observations

### 1. **Instrument Load is Continuous**
- Runs every hour (sometimes more frequently)
- Provides fresh instrument data throughout the day
- All other loads depend on this
- Must monitor for failures - blocks entire pipeline

### 2. **Early Morning Batch (02:00-03:00 AM)**
- Most reference data loads cluster in this window
- Runs before business hours
- Processes prior day data
- Minimal contention

### 3. **Business Hours Updates (08:00-10:00 AM)**
- Factor Load at 08:05 AM
- Agent Bank at 09:05 AM
- Prepares for trading day

### 4. **Intraday Transaction Processing**
- Trade Load: 5-7 times daily
- Position Load: Multiple updates
- Current Day Position: 2-3 times (critical at 3PM & 8PM)

### 5. **Critical Cutoff Times**
- **4:00 PM CST:** MOS validation cutoff for current day data
- **3:00 PM:** Pre-cutoff position load
- **8:00 PM:** Post-cutoff position load (after 4PM validation)

---

## Performance Metrics Summary

| Metric | Value |
|--------|-------|
| **Total Daily Runs** | 40-50 script executions |
| **Peak Hours** | 02:00-03:00 AM, 08:00-10:00 AM, 02:00-04:00 PM, 08:00-10:00 PM |
| **Longest Duration** | MiddleOfficePositionLoad (~30 min) |
| **Shortest Duration** | MiddleOfficeInstDefaultLoad (~2-5 min) |
| **Most Frequent** | MiddleOfficeInstrumentLoad (hourly+) |
| **Critical Path** | Instrument → Reference → Trade → Position → CurrentDay |

---

## Monitoring Recommendations

### Critical Alerts
1. **Instrument Load Failure** - Blocks entire pipeline
2. **Position Load Duration > 45 min** - Performance degradation
3. **Trade Load Failure** - Impacts position calculations
4. **Current Day Position missing 8PM run** - Misses post-cutoff data

### Warning Alerts
1. **Reference load duration > 15 min** - Unusual slowness
2. **Missing hourly Instrument Load** - Gap in foundation data
3. **Trade Load runs < 5 times daily** - Missing expected runs

### Performance Tracking
- Monitor log file sizes (sudden changes indicate issues)
- Track run-to-run consistency
- Alert on schedule drift (>15 min variance)
- Monitor archive folder growth

---

## Log File Locations

All log files are stored in subfolders under:
```
C:\source\MD\AdminTools\Archive\MiddleOfficeScriptTimeline\Client Refresh Log\
```

Subfolders:
- `AgentBank\` - Agent Bank load logs
- `Amortization\` - Amortization load logs
- `ContractCashFlow\` - Contract/Cash Flow/Debt load logs
- `Factor\` - Factor load logs
- `InactiveInstrument\` - Inactive instrument logs (currently empty)
- `InstDefault\` - Instrument Default load logs
- `Instrument\` - Instrument Load logs (MANY files - hourly)
- `LiabilityCapstack\` - Liability Capstack load logs
- `PositionLoad\` - Position Load logs (includes CurrentDay variant)
- `TradeLoad\` - Trade Load logs

**Log File Naming:** `{ScriptName}.{YYYYMMDDTHHMMSS}.txt`

**Example:** `MiddleOfficeAgentBankLoad.20260707T090510.txt`
- Script: MiddleOfficeAgentBankLoad
- Date: July 7, 2026
- Time: 09:05:10 AM

---

## Next Steps for Operations

1. ✅ **Establish Baseline** - Use this document as performance baseline
2. ⏳ **Set Up Monitoring** - Implement alerts based on recommendations
3. ⏳ **Create Dashboards** - Visualize daily execution patterns
4. ⏳ **Document Dependencies** - Map critical path dependencies
5. ⏳ **Capacity Planning** - Project growth based on current patterns
6. ⏳ **Disaster Recovery** - Document recovery procedures for each load

---

**Document Version:** 1.0  
**Created:** July 8, 2026  
**Data Coverage:** May 1 - July 7, 2026  
**Next Review:** Quarterly or after major changes
