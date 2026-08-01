# Siepe Database Standards Skill

## Overview

This skill provides comprehensive knowledge of Siepe's database development standards for SQL Server stored procedures, functions, views, tables, and other database objects.

**Reference Documentation:** C:\source\Siepe-Database\.database-standards

---

## When to Use This Skill

Use this skill when:
- Creating new stored procedures or functions
- Refactoring existing database code to meet standards
- Reviewing SQL code for compliance
- Writing T-SQL queries that interact with Siepe databases
- Creating database documentation or release notes

---

## Critical Standards - Stored Procedures

### MANDATORY Requirements (BLOCKING)

#### 1. Idempotency
- **MUST** use `DROP PROCEDURE IF EXISTS` before CREATE PROCEDURE
- **NEVER** use IF EXISTS patterns with sys.objects, sys.procedures, or SELECT checks
- This is a BLOCKING violation

```sql
✅ CORRECT:
DROP PROCEDURE IF EXISTS [Schema].[pProcedureName]
GO

❌ WRONG - ALL OF THESE ARE BLOCKING VIOLATIONS:
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Schema].[pProc]'))
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[Schema].[pProc]'))
```

#### 2. SET NOCOUNT ON
- **MUST** be the first statement after BEGIN
- Prevents extra result sets that interfere with DataReader

```sql
CREATE PROCEDURE [Schema].[pProcedure]
AS
BEGIN
    SET NOCOUNT ON;  -- MUST be first
    -- rest of code
END
```

#### 3. Documentation Header
- **MUST** include header comment block AFTER AS, BEFORE BEGIN
- **BLOCKING**: Header goes between AS and BEGIN, NOT before CREATE PROCEDURE
- **MUST** include: Description, Parameters, Returns, Example

```sql
✅ CORRECT:
CREATE PROCEDURE [Schema].[pProcedure]
    @Param INT
AS
/*
Description:
    Purpose and business logic

Parameters:
    @Param - Description

Returns:
    What it returns

Example:
    EXEC Schema.pProcedure @Param = 123
*/
BEGIN
    SET NOCOUNT ON;
```

#### 4. GRANT EXECUTE
- **MUST** include `GRANT EXECUTE ON [Schema].[pProc] TO [StandardUser]`
- Place AFTER the GO statement following procedure creation

```sql
GO
GRANT EXECUTE ON [Schema].[pProcedureName] TO [StandardUser]
GO
```

#### 5. Query Views, Not Tables (BLOCKING)
- **MUST** query views for all SELECT queries
- Query ANY view (Raw, Active, Current, or custom views with 'v' prefix)
- Exception: Direct table access ONLY for INSERT, UPDATE, DELETE operations
- Exception: UPDATE...FROM and INSERT...SELECT must query views in FROM/JOIN, but may write to tables

```sql
✅ CORRECT:
SELECT PromptID FROM Lumen.vPromptActive WHERE PromptType = 'System'
SELECT * FROM dbo.vPositionRaw P JOIN dbo.vRefDataSetActiveRaw R ...
UPDATE Lumen.tPrompt SET Name = 'X' WHERE PromptID = @ID
INSERT INTO Lumen.tPrompt (...) SELECT ... FROM Lumen.vPromptActive

❌ WRONG (BLOCKING):
SELECT PromptID FROM Lumen.tPrompt WHERE RefRecStatusID = 1
```

#### 6. Position View Pattern (BLOCKING)
- **DO NOT** use `dbo.vPosition` - it is incorrect
- **MUST** use `dbo.vPositionRaw` with `vRefDataSetActiveRaw` join instead

```sql
✅ CORRECT:
FROM dbo.vPositionRaw P
INNER JOIN dbo.vRefDataSetActiveRaw RDS 
    ON RDS.RefDataSetID = P.RefDataSetID

❌ WRONG (BLOCKING):
FROM dbo.vPosition
```

---

## Naming Conventions

### Stored Procedures
- **MUST** start with 'p' prefix
- Naming patterns:
  - `pTableNameI` - Insert, returns SCOPE_IDENTITY()
  - `pTableNameU` - Update
  - `pTableNameIU` - Time-series Insert/Update (inactivate + insert)
  - `pTableNameD` - Delete (soft delete, sets RefRecStatusID = 2)
  - `pTableName` - Get single item
  - `pTableNames` - Get multiple items
  - `pTableNameIUXML` - Batch insert/update from XML
  - `pTableNameXml` - Returns XML (FOR XML PATH)
  - `pTableNameJson` - Returns JSON (FOR JSON PATH)

### Parameters and Variables
- Use **@prefix + PascalCase**: `@PositionID`, `@AsOfDate`, `@RefDataSetID`
- NOT snake_case or camelCase

### Tables
- **MUST** start with 't' prefix: `tPosition`, `tPrompt`, `tEmployee`
- Primary key: `TableNameID` (without 't' prefix): `PositionID`, `PromptID`

### Views
- **MUST** start with 'v' prefix
- Standard suffixes:
  - `vTableNameActive` - Active records (RefRecStatusID = 1)
  - `vTableNameRaw` - All data, no filters
  - `vTableNameCurrent` - Current active (RefRecStatusID = 1 AND InactiveDate = '9999-01-01')

### Functions
- **MUST** start with 'f' prefix
- Optional suffixes: `S` (scalar), `T` (table-valued)
- Examples: `fCalculateValueS`, `fGetPositionsT`

### Schema Selection for Procedures

**CRITICAL: Dashboard vs Report Schema**

| Object Type | Schema | Purpose | Consumed By |
|-------------|--------|---------|-------------|
| **Dashboard Widget** | **Dashboard** | Real-time monitoring panels | Operations Dashboard UI |
| **Standalone Report** | **Report** | Ad-hoc queries, scheduled exports | Report Scheduler, SSRS, Manual queries |

**Examples:**
```sql
✅ CORRECT - Dashboard widget:
CREATE PROCEDURE Dashboard.pPricingInconsistenciesAcrossPortfolios
-- Used by Operations Dashboard panel

✅ CORRECT - Standalone report:
CREATE PROCEDURE Report.pEnhancedPricingReport  
-- Used by scheduled report exports

❌ WRONG - Dashboard widget in Report schema:
CREATE PROCEDURE Report.pPricingInconsistenciesAcrossPortfolios
-- This is a dashboard widget, must use Dashboard schema!
```

**Existing Dashboard Procedures:**
- `Dashboard.pIntegrityMissingPrices`
- `Dashboard.pIntegrityPriceSourceChanges`
- `Dashboard.pJobResearch`
- `Dashboard.pTodaysExceptions`
- `Dashboard.pTagAssetPriceOverrideByCompany`

**Rule:** If the user story mentions "dashboard widget" or "operations dashboard", use **Dashboard** schema.

### Dashboard Schema - Required Parameter

**MANDATORY for all Dashboard schema procedures:**

Every Dashboard schema stored procedure **MUST** include the `@GetColumnList` parameter:

```sql
CREATE PROCEDURE Dashboard.pProcedureName
    @AsOfDate        DATE = NULL,
    @CompanyID       INT  = NULL,
    @GetColumnList   BIT  = 0  -- REQUIRED for all Dashboard procedures
AS
/*
Description:
    Dashboard widget procedure
    
Parameters:
    @GetColumnList - When 1, returns column metadata only (no data)
*/
BEGIN
    SET NOCOUNT ON;
    
    -- REQUIRED: Handle GetColumnList mode
    IF @GetColumnList = 1
        SET @AsOfDate = '9999-01-01'  -- Force empty result set
    
    -- Regular procedure logic
    SELECT ...
    FROM ...
    WHERE RefDataSetDate = @AsOfDate
END
```

**Why Required:**
- Operations Dashboard UI calls with `@GetColumnList = 1` to discover column schema
- Setting `@AsOfDate = '9999-01-01'` returns column headers with no data rows
- Allows dashboard to build grid structure before loading data

---

## Dashboard Widget Field Naming Convention

**MANDATORY for all Dashboard schema procedures:**

All SELECT columns in Dashboard procedures **MUST** use the following format for proper display in Operations Dashboard widgets:

### Field Format
```sql
AS [DisplayName,DataType,DecimalPlaces,SortOrder]
```

### Components

| Component | Description | Valid Values |
|-----------|-------------|--------------|
| **DisplayName** | User-friendly column name shown in widget | Any descriptive text (e.g., "Portfolio Name", "Ending MV ($)") |
| **DataType** | Column data type indicator | `S` = String/Text<br>`N` = Numeric<br>`P` = Percentage<br>`D` = Date<br>`DT` = DateTime |
| **DecimalPlaces** | Number of decimal places for display | `0`, `1`, `2`, `4`, `8`, etc. (use `0` for non-numeric types) |
| **SortOrder** | Sorting priority in widget | `N` = Normal (no special sort)<br>`FIRST` = Sort this column first |

### Examples

```sql
-- From Dashboard.pIntegrityMissingPrices
SELECT
    CASE
        WHEN P.PositionMark IS NULL THEN 'Missing Price'
        ELSE 'Stale Price Date'
    END                                     AS [Issue,S,0,FIRST],
    
    F.FundName                              AS [Portfolio Name,S,0,FIRST],
    
    TRY_CONVERT(NVARCHAR(30), II.CUSIP)     AS [Symbol,S,0,FIRST],
    
    I.[Name]                                AS [Security Name,S,0,FIRST],
    
    TRY_CONVERT(DECIMAL(28,4), P.TradedQty) AS [Quantity,N,4,N],
    
    TRY_CONVERT(DECIMAL(28,8), P.PositionMark * ISNULL(IT.PriceFactor, 1))
                                            AS [Price,N,4,N],
    
    FORMAT(@RefDataSetDate, 'MM/dd/yyyy')   AS [Price Date,D,0,N],
    
    TRY_CONVERT(DECIMAL(28,4), P.TradedRCMV) AS [Ending MV ($),N,4,N],
    
    DATEDIFF(DAY, RS.SiepePriceDate, @RefDataSetDate)
                                            AS [Days Stale,N,0,FIRST],
    
    P.CreatedDate                           AS [PositionCreatedDate,DT,0,N]
FROM ...
```

```sql
-- From Dashboard.pInvestments
SELECT
    iss.Name                                AS [Issuer Name,S,0,N],
    
    at.assettype                            AS [Asset Class,S,0,N],
    
    a.Analyst                               AS [Portfolio Manager,S,0,N],
    
    SUM(p.mv)/1000000                       AS [MV ($ in millions),N,1,N],
    
    SUM(ABS(p.mv))/@Total                   AS [% of Total,P,1,N]
FROM ...
```

### Common Patterns

**String columns:**
```sql
AS [Column Name,S,0,N]              -- Basic string, no sort priority
AS [Column Name,S,0,FIRST]          -- String with sort priority
```

**Numeric columns:**
```sql
AS [Amount,N,0,N]                   -- Integer display (no decimals)
AS [Amount,N,2,N]                   -- Currency display (2 decimals)
AS [Price,N,4,N]                    -- Price display (4 decimals)
AS [Precise Value,N,8,N]            -- High precision (8 decimals)
```

**Percentage columns:**
```sql
AS [Percentage,P,1,N]               -- Display as percentage with 1 decimal
AS [Percentage,P,2,N]               -- Display as percentage with 2 decimals
```

**Date/DateTime columns:**
```sql
AS [Trade Date,D,0,N]               -- Date only
AS [Created Timestamp,DT,0,N]       -- Date and time
```

**Sort priority:**
```sql
AS [Primary Sort Column,S,0,FIRST]  -- This column sorts first
AS [Regular Column,N,2,N]           -- Normal sort order
```

### Reference Procedures

Study these existing Dashboard procedures for field naming examples:
- `Dashboard.pIntegrityMissingPrices` - Comprehensive example with all data types
- `Dashboard.pInvestments` - String, Numeric, and Percentage examples
- `Dashboard.pBondMaturityTrends` - Percentage and timeframe grouping
- `Dashboard.pLegalInvoiceAgingReport` - Date and currency formatting

---

## Testing Requirements

### MANDATORY: Test in Development Before Committing

**All stored procedures MUST be tested in Development environment before deployment:**

```powershell
# Connect to Development SQL Server
$devServer = "mos-sql-d.mos.siepe.local,52155"
$database = "Core"  # Or Dashboard, Report, etc.

# Test procedure execution
Invoke-Sqlcmd -ServerInstance $devServer -Database $database -Query @"
EXEC Dashboard.pProcedureName 
    @AsOfDate = '2026-07-23',
    @CompanyID = NULL,
    @GetColumnList = 0
"@

# Test GetColumnList mode (Dashboard procedures only)
Invoke-Sqlcmd -ServerInstance $devServer -Database $database -Query @"
EXEC Dashboard.pProcedureName 
    @GetColumnList = 1
"@
```

**Testing Checklist:**
- ✅ Procedure executes without errors
- ✅ Returns expected columns
- ✅ Returns expected row count range
- ✅ @GetColumnList = 1 returns column headers only (Dashboard procedures)
- ✅ Performance is acceptable (< 30 seconds for dashboard widgets)
- ✅ No blocking or deadlocks
- ✅ SQL follows all Siepe standards

**For Dashboard procedures, test BOTH modes:**
1. `@GetColumnList = 0` - Normal data retrieval
2. `@GetColumnList = 1` - Column metadata only (should return 0 rows)

---

## Syntax and Formatting

### Keywords
- **ALL SQL keywords MUST be UPPERCASE**
- Examples: `SELECT`, `FROM`, `WHERE`, `JOIN`, `CREATE`, `ALTER`, `BEGIN`, `END`, `TRY`, `CATCH`, `GO`, `GRANT`

### Column Aliases
- **MUST** use `AS` keyword for ALL aliased columns
- `SELECT EmployeeID AS ID, EmployeeName AS Name`
- **NOT**: `SELECT EmployeeID ID` (missing AS)

### Table Aliases (CRITICAL)

**MANDATORY**: Table/view aliases MUST be capitalized in multi-table queries

- **New code standard**: All table and view aliases MUST use capitalized letters
- **Legacy code note**: Existing code may use lowercase aliases; however, all new code and refactoring MUST use capitalized aliases
- **BLOCKING**: Multi-table queries MUST include table aliases - queries without aliases will be rejected

**Correct examples:**
```sql
✅ CORRECT - Capitalized aliases:
FROM dbo.tEmployee E 
JOIN dbo.tDepartment D ON E.DeptID = D.DeptID

FROM dbo.vPositionRaw P
INNER JOIN dbo.vRefDataSetActiveRaw R ON P.RefDataSetID = R.RefDataSetID

FROM Lumen.tPrompt PR 
JOIN dbo.tRefRecStatus RS ON PR.RefRecStatusID = RS.RefRecStatusID
WHERE PR.PromptType = 'System'
```

**Wrong examples:**
```sql
❌ WRONG - Lowercase aliases (legacy pattern, not allowed in new code):
FROM dbo.tEmployee e 
JOIN dbo.tDepartment d ON e.DeptID = d.DeptID

❌ WRONG - Missing aliases (BLOCKING):
FROM dbo.tEmployee 
INNER JOIN dbo.tDepartment ON tEmployee.DeptID = tDepartment.DeptID

❌ WRONG - Mixed case (lowercase/uppercase):
FROM dbo.tEmployee e
JOIN dbo.tDepartment D ON e.DeptID = D.DeptID
```

**Why capitalized aliases?**
- Consistency with SQL Server conventions (keywords are uppercase)
- Improved readability and code clarity
- Standard enforced in all new Siepe database development

### Schema References
- **MUST** explicitly reference schema when accessing objects in a **different schema** than where the procedure is deployed
- Objects in the **same schema** as the procedure do NOT require schema prefix (but including it is acceptable)
- **Rule:** If procedure is in Core schema (dbo), accessing Core objects does NOT need `dbo.` prefix
- **Rule:** If procedure is in Dashboard/Report/Reference schema, accessing Core objects REQUIRES `Core.dbo.` prefix

**Same-schema (prefix optional):**
```sql
-- Procedure deployed to Core (dbo) schema
CREATE PROCEDURE dbo.pGetPositions
AS
BEGIN
    SELECT * FROM vPositionRaw          -- ✅ Same schema, prefix optional
    SELECT * FROM dbo.vPositionRaw      -- ✅ Also acceptable (more explicit)
END
```

**Cross-schema (prefix REQUIRED):**
```sql
-- Procedure deployed to Dashboard schema
CREATE PROCEDURE Dashboard.pGetPositions
AS
BEGIN
    SELECT * FROM Core.dbo.vPositionRaw    -- ✅ REQUIRED for different schema
    SELECT * FROM Reference.dbo.vInst      -- ✅ REQUIRED for different schema
    SELECT * FROM vPositionRaw             -- ❌ WRONG - ambiguous, will fail
END
```

### SELECT * Usage (BLOCKING)
- **NEVER** use `SELECT *` for user tables or views
- ONLY acceptable in system catalog queries (IF EXISTS checks)
- **MUST** explicitly list all columns

```sql
✅ CORRECT:
SELECT PromptID, PromptName, PromptText FROM Lumen.tPrompt

❌ WRONG (BLOCKING):
SELECT * FROM Lumen.tPrompt
```

### GO Statement Placement
- **MUST** use GO after DROP statements
- **MUST** use GO after CREATE statements
- **MUST** use GO after GRANT statements

---

## Transaction and Error Handling

### When to Use Transactions
**REQUIRED for:**
- Multiple INSERT/UPDATE/DELETE operations
- Time-series IU procedures (inactivate + insert)
- XML/JSON batch operations
- Any multi-step operation that must be atomic

**NOT NEEDED for:**
- Single INSERT/UPDATE/DELETE (atomic by default)
- SELECT queries (read-only)
- Single stored procedure calls

### TRY/CATCH Pattern
**REQUIRED for:**
- All write operations (INSERT/UPDATE/DELETE)
- All procedures using transactions
- All procedures with cursors
- All XML/JSON batch operations

**NOT NEEDED for:**
- Simple read-only SELECT queries
- Single-statement procedures with no side effects

### Standard Error Handling
```sql
BEGIN TRY
    -- Procedure logic

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY()
    DECLARE @ErrorState INT = ERROR_STATE()

    RAISERROR(@ErrorMessage, @ErrorSeverity, 1)  -- Use 1, not @ErrorState
END CATCH
```

**Note:** Error state uses `1`, NOT `@ErrorState`

---

## Standard Procedure Template

```sql
DROP PROCEDURE IF EXISTS [SchemaName].[pProcedureName]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [SchemaName].[pProcedureName]
    @Parameter1 datatype,
    @Parameter2 datatype
AS
/*
Description:
    Clear purpose and business logic explanation

Parameters:
    @Parameter1 - Description
    @Parameter2 - Description

Returns:
    What the procedure returns (SCOPE_IDENTITY, DataReader, XML, JSON, None)

Example:
    EXEC SchemaName.pProcedureName @Parameter1 = 'value1', @Parameter2 = 'value2'

Notes:
    Optional special considerations
*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @ErrorMessage NVARCHAR(4000);
    
    BEGIN TRY
        -- Procedure logic here
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        SET @ErrorMessage = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, ERROR_SEVERITY(), 1);
    END CATCH
    
END
GO

GRANT EXECUTE ON [SchemaName].[pProcedureName] TO [StandardUser]
GO
```

---

## Procedure Patterns by Type

### Time-Series IU Pattern
- Inactivates current: `UPDATE ... SET InactiveDate = GETDATE() WHERE InactiveDate = '9999-01-01'`
- Inserts new: `INSERT ... VALUES (..., '9999-01-01', ...)`
- Uses transactions: `BEGIN TRANSACTION ... COMMIT`
- Returns `SCOPE_IDENTITY() AS TableNameID`
- TRY/CATCH error handling

### Simple Insert Pattern
- Single INSERT statement
- Returns `SCOPE_IDENTITY() AS TableNameID`
- TRY/CATCH error handling
- No transaction (single operation is atomic)
- Sets audit columns: `CreatedDate = GETDATE(), CreatedUser = @Login`

### Simple Update Pattern
- Single UPDATE statement
- Returns success indicator: `SELECT @PrimaryKeyID, 'UPDATE Successful'` followed by `RETURN`
- TRY/CATCH error handling
- No transaction (single operation is atomic)
- Optional: `@EnableExplicitNulls` parameter (0 = preserve existing, 1 = allow NULL)

### Simple Delete Pattern
- Soft delete: sets RefRecStatusID to 2
- Single UPDATE statement
- Returns nothing
- TRY/CATCH error handling
- No transaction (single operation is atomic)
- No @Login parameter needed

---

## Key Restrictions

### Extended Properties
- **NOT** required for stored procedures (only MANDATORY for tables and columns)
- If adding extended properties, **MUST** use `dbo.pExtendedPropertyIU`
- **BLOCKING**: **NEVER** use `sys.sp_addextendedproperty` - it is FORBIDDEN

### Cursors
- **Minimize** use - prefer set-based operations
- Only use when:
  - Processing rows that require calling other stored procedures
  - Complex row-by-row logic that cannot be expressed in set-based operations
  - XML/JSON batch processing with validation

### Standard Cursor Pattern (when needed)
```sql
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT columns FROM SchemaName.vViewName WHERE condition

OPEN cur
FETCH NEXT FROM cur INTO @var1, @var2

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Row processing logic
    
    FETCH NEXT FROM cur INTO @var1, @var2
END

CLOSE cur
DEALLOCATE cur
```

---

## Formatting Guidelines

### Column Lists
- One column per line in SELECT, INSERT, UPDATE statements
- Align column lists vertically
- Consistent indentation (tabs standard)

### Example
```sql
SELECT
    PositionID,
    PositionName,
    PositionType,
    CreatedDate,
    CreatedUser
FROM
    dbo.vPositionRaw P
    INNER JOIN dbo.vRefDataSetActiveRaw RDS
        ON RDS.RefDataSetID = P.RefDataSetID
WHERE
    P.RefRecStatusID = 1
ORDER BY
    PositionName
```

---

## Common Violations to Flag

### BLOCKING Violations (Must Fix)
1. Using IF EXISTS instead of DROP...IF EXISTS
2. Using SELECT * on user tables/views
3. Querying tables instead of views in SELECT statements
4. Using dbo.vPosition instead of dbo.vPositionRaw
5. Header comment before CREATE PROCEDURE instead of between AS and BEGIN
6. Missing schema prefix on object references
7. Using sys.sp_addextendedproperty instead of dbo.pExtendedPropertyIU

### Style Violations (Should Fix)
1. Lowercase SQL keywords
2. Missing AS keyword on column aliases
3. Lowercase table aliases
4. Missing GO statements
5. Missing GRANT EXECUTE
6. Missing SET NOCOUNT ON
7. Missing or incomplete header documentation

---

## Testing and Validation

### Always Include Examples
- Every procedure **MUST** have example EXEC statements in header
- Examples should cover common use cases
- Examples should use realistic test values

### Before Deployment
1. Test with @Debug = 1 (if applicable) to verify logic
2. Test with actual data
3. Verify GRANT EXECUTE works for StandardUser
4. Confirm procedure can be dropped and recreated (idempotency)
5. Review against code review checklist

---

## Additional Resources

For complete details, refer to:
- **C:\source\Siepe-Database\.database-standards\README.md** - Master index
- **C:\source\Siepe-Database\.database-standards\standards\stored-procedures.md** - Complete proc standards
- **C:\source\Siepe-Database\.database-standards\standards\naming-conventions.md** - Naming rules
- **C:\source\Siepe-Database\.database-standards\standards\syntax-formatting.md** - Formatting rules
- **C:\source\Siepe-Database\.database-standards\code-review\code-review.md** - Review checklist
