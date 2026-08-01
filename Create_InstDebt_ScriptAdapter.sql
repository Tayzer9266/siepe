-- =====================================================
-- Create Script Adapter for Complete InstDebt Push
-- Purpose: Automates Feeds → Core → Reference pipeline
-- =====================================================

USE Enterprise;
GO

-- Find next available Script Adapter ID
DECLARE @NextID INT;
SELECT @NextID = ISNULL(MAX(ScriptConfigurationID), 1000) + 1 
FROM ScriptAdapter.tScriptConfiguration;

PRINT 'Creating Script Adapter ID: ' + CAST(@NextID AS VARCHAR(10));

-- Insert Script Adapter Configuration
INSERT INTO ScriptAdapter.tScriptConfiguration (
    ScriptConfigurationID,
    Name,
    ScriptPath,
    PubSubSubject,
    AllowConcurrent,
    TimeOut,
    RefRecStatusID
)
VALUES (
    @NextID,
    'InstDebt Complete Push (Feeds -> Core -> Reference)',
    'C:\Siepe\Data\Scripts\PROD\InstDebt_CompletePush.ps1',
    'GenericPush.InstDebt.Complete',
    0,  -- Do not allow concurrent runs
    0,  -- No timeout
    1   -- Active
);

PRINT 'Script Adapter Created Successfully!';
PRINT '';
PRINT 'Script Adapter ID: ' + CAST(@NextID AS VARCHAR(10));
PRINT 'Name: InstDebt Complete Push (Feeds -> Core -> Reference)';
PRINT 'Pub/Sub Topic: GenericPush.InstDebt.Complete';
PRINT 'Script: C:\Siepe\Data\Scripts\PROD\InstDebt_CompletePush.ps1';
PRINT '';
PRINT '=== HOW TO TRIGGER ===';
PRINT '1. Manual execution on server:';
PRINT '   cd C:\Siepe\Data\Scripts\PROD';
PRINT '   .\InstDebt_CompletePush.ps1';
PRINT '';
PRINT '2. Via Pub/Sub message:';
PRINT '   Publish to topic: GenericPush.InstDebt.Complete';
PRINT '';
PRINT '3. Add to scheduled job:';
PRINT '   Include in existing Report Subscription or create new one';
PRINT '';

-- Verify creation
SELECT 
    ScriptConfigurationID,
    Name,
    ScriptPath,
    PubSubSubject,
    RefRecStatusID,
    CreatedDate
FROM ScriptAdapter.tScriptConfiguration
WHERE ScriptConfigurationID = @NextID;

GO
