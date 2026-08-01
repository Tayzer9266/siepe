---
skill_name: "InstMap Management"
category: "Data Quality"
keywords: ["instmap", "instrument mapping", "reference mapping", "core mapping", "pkid", "hcid", "groupid", "price resolution", "instrument linkage"]
databases: ["Reference"]
status: "Ready"
created: "2026-07-31"
last_updated: "2026-07-31"
---

# InstMap Management Skill

## Purpose

Manage instrument mappings between Reference database (PKID) and Core database (HCID) using GroupID linkages. This skill addresses pricing issues caused by missing or incorrect InstMap entries.

## When to Use This Skill

**Symptoms:**
- ✅ Position exists in Core but has no price
- ✅ Vendor price exists in Reference but doesn't flow to Core positions
- ✅ Different Core InstIDs should share the same Reference pricing data
- ✅ "InstMap shows PKID maps to different HCID" error
- ✅ Price weighting function cannot find prices for a security

**Keywords that trigger this skill:**
- InstMap missing
- Price not flowing to positions
- PKID/HCID mapping
- GroupID issue
- Reference InstID not linked to Core InstID
- Add instrument mapping
- Link Reference to Core

## Background: How InstMap Works

### The Three Key IDs

| ID Type | Range | Database | Purpose |
|---------|-------|----------|---------|
| **HCID** | 1 - 999,999,999 | Core | Core instrument ID (used by positions, trades) |
| **PKID** | 1,000,000,000+ | Reference | Reference instrument ID (has vendor prices, identifiers) |
| **GroupID** | Negative integer | Reference.dbo.tInstMap | Links PKIDs to HCIDs |

### Mapping Structure

```
GroupID -25613
├── HCID: 500022765 (Core InstID - used by Sycamore positions)
├── PKID: 1000598824 (Reference InstID - has Markit prices)
├── PKID: 1000598709 (Reference InstID - has LSEG prices)
├── PKID: 1000599449 (Reference InstID - has ICE prices)
└── PKID: 1000601061 (Reference InstID - has Sycamore prices)
```

**Key Concept:** All PKIDs in the same GroupID share the same HCID, allowing price weighting functions to aggregate prices from multiple vendors for a single Core security.

### Why Mappings Matter for Pricing

**Without mapping:**
```
Core Position (InstID 500022765) → No prices found ❌
Reference Price (InstID 1000598824, Markit, $100.50) → Orphaned, not used ❌
```

**With mapping:**
```
Core Position (InstID 500022765)
    ↓ (via GroupID -25613)
Reference Price (InstID 1000598824, Markit, $100.50) → Used for pricing ✅
```

---

## Procedures

### 1. `Reference.dbo.pInstMapD` - Delete Mapping

**Purpose:** Remove an instrument from a mapping group (soft delete, sets RefRecStatusID=2)

**Parameters:**
- `@IDs` - Comma-separated list of PKIDs to remove from mapping

**Usage:**
```sql
-- Remove PKID 1000598824 from its current mapping
EXEC Reference.dbo.pInstMapD
    @IDs = '1000598824'
```

**What it does:**
```sql
UPDATE dbo.tInstMap
SET RefRecStatusID = 2,      -- Mark as inactive
    EffThruDate = GETDATE()  -- Set expiration to now
WHERE PKID IN (SELECT id FROM @tab_IDs)
    AND RefRecStatusID = 1
```

**When to use:**
- Remove incorrect mappings before creating new ones
- Unlink a Reference InstID from a Core InstID
- Clean up duplicate or stale mappings

---

### 2. `Reference.dbo.pInstMapI` - Insert/Update Mapping

**Purpose:** Create or update instrument mappings by linking PKIDs together (and optionally to HCIDs)

**Parameters:**
- `@IDs` - Comma-separated list of InstIDs to map together (PKIDs and/or HCID)
- `@Comment` - Optional comment for audit trail
- `@CreatedUser` - Optional username (defaults to current user)

**Usage Examples:**

#### Example 1: Link Reference PKID to Core HCID
```sql
-- Link PKID 1000598824 (has Markit prices) to HCID 500022765 (used by positions)
EXEC Reference.dbo.pInstMapI
    @IDs = '1000598824,500022765',
    @Comment = 'Linking Markit prices to Sycamore positions - Task #85904'
```

#### Example 2: Add Additional Vendor to Existing Group
```sql
-- Add PKID 1000999999 (new ICE price) to existing group for HCID 500022765
EXEC Reference.dbo.pInstMapI
    @IDs = '1000999999,500022765',
    @Comment = 'Adding ICE pricing source to existing Sycamore instrument'
```

#### Example 3: Link Multiple PKIDs Together
```sql
-- Link multiple Reference InstIDs for the same security
EXEC Reference.dbo.pInstMapI
    @IDs = '1000111111,1000222222,1000333333',
    @Comment = 'Linking LSEG, Markit, and ICE prices for same bond'
```

**What it does:**
1. Validates that mappings won't create multiple Core records in same group (throws error if so)
2. Finds existing GroupID if any input IDs are already mapped
3. Creates new GroupID if no existing group found (uses negative auto-increment)
4. Inserts tInstMap records linking all PKIDs to the GroupID
5. Ensures only one HCID per GroupID (business rule)

**Key Logic:**
- If input includes HCID (1-999,999,999): All PKIDs join that HCID's GroupID
- If input is all PKIDs (1,000,000,000+): Creates new GroupID or merges into existing
- **CRITICAL:** Cannot map multiple HCIDs to same GroupID (procedure will throw error)

---

## Investigation Steps

### Step 1: Identify the Missing Mapping

**Symptom:** Position has no price even though vendor price exists

**Query to diagnose:**
```sql
-- Find position's Core InstID
SELECT p.InstID AS Core_InstID, p.RefDataSetDate, p.Mark, p.MarketValue
FROM Core.dbo.vPosition p
WHERE p.PortfolioID = {PortfolioID}
    AND p.InstID = {InstID}
    AND p.RefDataSetDate = '{Date}'

-- Check if Core InstID has any Reference mappings
SELECT im.PKID, im.HCID, im.GroupID, im.RefRecStatusID
FROM Reference.dbo.vInstMapCurrent im
WHERE im.HCID = {Core_InstID}

-- Check if vendor price exists for a Reference InstID
SELECT iv.InstID AS Ref_InstID, iv.RefDataSourceID, rds.Name AS Vendor,
       iv.Value AS Price, iv.RefDataSetDate
FROM Reference.dbo.tInstValue iv
JOIN Reference.dbo.vRefDataSourceRaw rds ON rds.RefDataSourceID = iv.RefDataSourceID
WHERE iv.InstID = {Reference_InstID}
    AND iv.RefDataSetDate = '{Date}'
ORDER BY rds.Name
```

### Step 2: Verify GroupID Structure

```sql
-- See all instruments in a GroupID
SELECT im.PKID, im.HCID, im.GroupID,
       CASE WHEN im.PKID < 1000000000 THEN 'CORE' ELSE 'REFERENCE' END AS ID_Type,
       i.Name AS Instrument_Name
FROM Reference.dbo.vInstMapCurrent im
LEFT JOIN Reference.dbo.vInst i ON i.InstID = im.PKID
WHERE im.GroupID = {GroupID}
ORDER BY im.PKID
```

### Step 3: Check for Conflicting Mappings

```sql
-- Check if PKID is already mapped to a DIFFERENT HCID
SELECT im.PKID, im.HCID, im.GroupID
FROM Reference.dbo.vInstMapCurrent im
WHERE im.PKID = {Reference_InstID}

-- This should show:
-- - No rows = PKID not mapped (need to add mapping)
-- - HCID matches expected = Already correct
-- - HCID different = CONFLICT - need pInstMapD then pInstMapI
```

### Step 4: Execute Fix

**Scenario A: PKID Not Mapped (Add New Mapping)**
```sql
-- Simply add the mapping
EXEC Reference.dbo.pInstMapI
    @IDs = '{PKID},{HCID}',
    @Comment = 'Task #{TaskNumber} - Linking vendor price to Core position'
```

**Scenario B: PKID Mapped to Wrong HCID (Remap)**
```sql
-- Step 1: Delete incorrect mapping
EXEC Reference.dbo.pInstMapD
    @IDs = '{PKID}'

-- Step 2: Create correct mapping
EXEC Reference.dbo.pInstMapI
    @IDs = '{PKID},{Correct_HCID}',
    @Comment = 'Task #{TaskNumber} - Correcting PKID mapping from wrong HCID'
```

**Scenario C: Add Additional Vendor to Existing Group**
```sql
-- Just add the new PKID to existing HCID's group
EXEC Reference.dbo.pInstMapI
    @IDs = '{New_PKID},{Existing_HCID}',
    @Comment = 'Task #{TaskNumber} - Adding {Vendor} pricing source'
```

### Step 5: Verify Fix

```sql
-- Confirm mapping was created
SELECT im.PKID, im.HCID, im.GroupID, im.RefRecStatusID
FROM Reference.dbo.vInstMapCurrent im
WHERE im.PKID = {PKID}
    OR im.HCID = {HCID}
ORDER BY im.PKID

-- Check if positions now have prices (may need to wait for next price calculation job)
SELECT p.InstID, p.RefDataSetDate, p.Mark, p.MarketValue
FROM Core.dbo.vPosition p
WHERE p.InstID = {HCID}
    AND p.RefDataSetDate >= '{Date}'
ORDER BY p.RefDataSetDate DESC
```

---

## Real-World Example: Task #85904

### Problem
**Sycamore positions** (Core InstID 500022765) had **no Markit prices**, even though Markit prices existed for Reference InstID 1000598824.

### Root Cause
InstID 1000598824 was mapped to a **different Core InstID** (500022696) via GroupID -25541, instead of the correct Core InstID 500022765 (GroupID -25613).

### Investigation
```sql
-- Check current mapping
SELECT PKID, HCID, GroupID FROM Reference.dbo.vInstMapCurrent
WHERE PKID = 1000598824
-- Result: PKID 1000598824 → HCID 500022696, GroupID -25541 (WRONG!)

-- Check what HCID Sycamore positions use
SELECT InstID FROM Core.dbo.vPosition
WHERE PortfolioID IN (SELECT PortfolioID FROM ...)
-- Result: Positions use HCID 500022765

-- Verify HCID 500022765's GroupID
SELECT HCID, GroupID FROM Reference.dbo.vInstMapCurrent
WHERE HCID = 500022765
-- Result: HCID 500022765 → GroupID -25613
```

### Solution
```sql
-- Step 1: Remove PKID from wrong group (optional, but cleaner)
EXEC Reference.dbo.pInstMapD
    @IDs = '1000598824'

-- Step 2: Add PKID to correct group
EXEC Reference.dbo.pInstMapI
    @IDs = '1000598824,500022765',
    @Comment = 'Task #85904 - Linking Markit prices to Sycamore positions'
```

### Verification
```sql
-- Confirm new mapping
SELECT PKID, HCID, GroupID FROM Reference.dbo.vInstMapCurrent
WHERE PKID = 1000598824
-- Result: PKID 1000598824 → HCID 500022765, GroupID -25613 ✅

-- See all instruments in the group
SELECT PKID, HCID, GroupID FROM Reference.dbo.vInstMapCurrent
WHERE HCID = 500022765 OR GroupID = -25613
ORDER BY PKID
-- Result: Shows all vendor PKIDs now linked to correct HCID ✅
```

---

## Common Scenarios

### Scenario 1: New Security Added to Core, Need to Link Vendor Prices

**Situation:** Client creates new position for a bond, but price doesn't flow from vendor

**Solution:**
1. Find Core InstID from position
2. Find Reference InstID(s) with vendor prices (search by CUSIP/ISIN)
3. Link them together

```sql
-- Find Core InstID
SELECT DISTINCT p.InstID FROM Core.dbo.vPosition p
WHERE p.PortfolioID = {PortfolioID}
    AND EXISTS (SELECT 1 FROM Core.dbo.vInstIdentifier ii
                WHERE ii.InstID = p.InstID AND ii.Value = '{CUSIP}')
-- Result: Core InstID = 500012345

-- Find Reference InstID with price
SELECT i.InstID FROM Reference.dbo.vInst i
JOIN Reference.dbo.vInstIdentifier ii ON ii.InstID = i.InstID
WHERE ii.Value = '{CUSIP}' AND ii.InstIdentifierType = 'CUSIP'
    AND i.InstID > 1000000000  -- Reference range
-- Result: Reference InstID = 1000678901

-- Link them
EXEC Reference.dbo.pInstMapI
    @IDs = '1000678901,500012345',
    @Comment = 'New bond - linking Markit price to Core position'
```

### Scenario 2: Multiple Vendors Price Same Security

**Situation:** Security has prices from Markit, LSEG, and ICE - need all vendors in same group for price weighting

**Solution:**
```sql
-- Add all vendor PKIDs to same HCID
EXEC Reference.dbo.pInstMapI
    @IDs = '1000111111,1000222222,1000333333,500012345',
    @Comment = 'Linking Markit (1000111111), LSEG (1000222222), ICE (1000333333) to Core 500012345'
```

### Scenario 3: Vendor Switched, Need to Update Mapping

**Situation:** Client switched from Markit to LSEG, need to remap positions

**Solution:**
```sql
-- Remove old vendor mapping
EXEC Reference.dbo.pInstMapD @IDs = '{Old_Markit_PKID}'

-- Add new vendor mapping
EXEC Reference.dbo.pInstMapI
    @IDs = '{New_LSEG_PKID},{HCID}',
    @Comment = 'Switching from Markit to LSEG pricing'
```

---

## Procedure Definitions

### pInstMapD (Delete Mapping)

```sql
CREATE PROCEDURE [dbo].[pInstMapD]
    @IDs varchar(8000)
AS
BEGIN
    SET NOCOUNT ON ;
    SET TRANSACTION ISOLATION LEVEL READ COMMITTED ;

    DECLARE @tab_IDs TABLE (id int NOT NULL) ;

    -- Split the input records ...
    INSERT INTO @tab_IDs (id)
        SELECT DISTINCT row
        FROM dbo.fnCOMSplitTableT(@IDs, ',')
        WHERE LEN(row) > 0 ;

    -- Delete any active records specified ...
    UPDATE dbo.tInstMap
    SET RefRecStatusID = 2 , EffThruDate = GETDATE()
    WHERE
        PKID IN (SELECT id FROM @tab_IDs)
        AND
        RefRecStatusID = 1

END
```

### pInstMapI (Insert/Update Mapping)

**Note:** Full procedure definition saved to:
- `C:\source\MD\AdminTools\Output\pInstMapI_Definition.sql`

**Key validation:**
```sql
-- Prevents multiple Core records in same GroupID
IF (SELECT COUNT(DISTINCT ID) FROM @CoreRecords) > 1
BEGIN
    RAISERROR ('Indicated mappings would create a group with more than one Core record. This is not allowed', 18, 128)
    RETURN @@ERROR;
END
```

**Core logic:**
- Determines GroupID (existing or new negative ID)
- Inserts tInstMap rows for each PKID
- Links all PKIDs to same GroupID
- Ensures only one HCID per GroupID

---

## Troubleshooting

### Error: "Indicated mappings would create a group with more than one Core record"

**Cause:** Trying to link two different HCIDs to the same GroupID (not allowed)

**Example:**
```sql
-- This will fail:
EXEC Reference.dbo.pInstMapI @IDs = '500011111,500022222'
-- Two different Core InstIDs cannot be in same group
```

**Solution:** Review which HCID should be the primary, delete incorrect mappings first

### Issue: Mapping Created But Prices Still Don't Flow

**Possible Causes:**
1. Price calculation job hasn't run yet (wait for next schedule)
2. Price data doesn't exist for that date
3. InstType filtering excludes the security
4. RefDataSourceID not enabled for portfolio

**Verification:**
```sql
-- Check if vendor price exists for date
SELECT * FROM Reference.dbo.tInstValue
WHERE InstID = {PKID} AND RefDataSetDate = '{Date}'

-- Check if price weighting function includes this vendor
-- (varies by client configuration)
```

---

## ADO Integration

### Creating Work Item Comments

```powershell
# Post findings to ADO ticket
az boards work-item update --id {TaskNumber} `
    --discussion "InstMap Fix Applied:
    - Deleted PKID {PKID} from GroupID {Old_GroupID}
    - Added PKID {PKID} to GroupID {New_GroupID} (HCID {HCID})
    - Verified mapping created successfully
    - Positions should receive vendor prices on next calculation"
```

---

## Quick Reference

| Action | Command | Use Case |
|--------|---------|----------|
| **Delete mapping** | `EXEC Reference.dbo.pInstMapD @IDs = '{PKID}'` | Remove incorrect mapping |
| **Add mapping** | `EXEC Reference.dbo.pInstMapI @IDs = '{PKID},{HCID}'` | Link vendor price to Core position |
| **Link multiple vendors** | `EXEC Reference.dbo.pInstMapI @IDs = '{PKID1},{PKID2},{HCID}'` | Add multiple pricing sources |
| **View group** | `SELECT * FROM Reference.dbo.vInstMapCurrent WHERE GroupID = {ID}` | See all instruments in group |
| **Find Core mapping** | `SELECT * FROM Reference.dbo.vInstMapCurrent WHERE HCID = {ID}` | See vendor sources for position |
| **Find Ref mapping** | `SELECT * FROM Reference.dbo.vInstMapCurrent WHERE PKID = {ID}` | See what Core InstID price maps to |

---

## Database Schema

**Table:** `Reference.dbo.tInstMap`

| Column | Type | Purpose |
|--------|------|---------|
| InstMapID | int | Primary key |
| PKID | int | Reference InstID or Core InstID |
| GroupID | int | Negative integer linking related instruments |
| RefRecStatusID | int | 1=Active, 2=Inactive |
| EffFromDate | datetime | Mapping effective from |
| EffThruDate | datetime | Mapping effective until (9999-01-01 = forever) |
| CreatedDate | datetime | When mapping was created |
| CreatedUser | varchar(100) | Who created the mapping |

**View:** `Reference.dbo.vInstMapCurrent`
- Pre-filtered: `RefRecStatusID = 1 AND EffThruDate = '9999-01-01'`
- Returns only currently active mappings

---

## Best Practices

1. ✅ **Always verify before deleting** - Check what other instruments are in the GroupID
2. ✅ **Use @Comment parameter** - Document why mapping was created (include task number)
3. ✅ **Test in DEV first** - For complex remapping scenarios
4. ✅ **Verify after creation** - Query vInstMapCurrent to confirm mapping
5. ✅ **Document in ADO** - Post command and results to task
6. ✅ **Check price flow** - Wait for price calculation job, verify positions have prices
7. ❌ **Never map multiple HCIDs to same GroupID** - Procedure will error
8. ❌ **Don't delete mappings without replacement** - Positions will lose prices

---

## See Also

- **Check Market Price Skill** - Diagnose why prices aren't flowing
- **Price Weighting Function** - How MOS selects prices from multiple vendors
- **Data Normalization Skill** - Reference data mapping and transformation
- **Portfolio Setup Skill** - Initial instrument and portfolio configuration

---

**Last Updated:** 2026-07-31  
**Maintained By:** Back Office SQL Engineers  
**Database:** Reference (mos-sql-p.mos.siepe.local,52155)
