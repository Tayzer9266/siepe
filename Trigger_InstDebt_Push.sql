-- =====================================================
-- Publish Pub/Sub Message to Trigger InstDebt Push
-- Run this to manually trigger the complete pipeline
-- =====================================================

USE Enterprise;
GO

-- Publish message to trigger InstDebt Complete Push
INSERT INTO PubSub.tPublishedMessage (
    Subject,
    MessageText,
    CreatedDate,
    CreatedUser
)
VALUES (
    'GenericPush.InstDebt.Complete',
    'Manual trigger for complete InstDebt push (Feeds -> Core -> Reference)',
    GETDATE(),
    SYSTEM_USER
);

PRINT 'Pub/Sub message published successfully!';
PRINT 'Topic: GenericPush.InstDebt.Complete';
PRINT 'Script Adapter should process this message shortly.';
PRINT '';
PRINT 'Check execution status:';
PRINT 'SELECT TOP 10 * FROM ScriptAdapter.tScriptConfigurationHistory';
PRINT 'ORDER BY CreatedDate DESC;';

GO

-- Show recent executions
SELECT TOP 10 
    sch.ConfigurationHistoryID,
    sc.Name AS ScriptAdapterName,
    sch.StartTimeStamp,
    sch.EndTimeStamp,
    sch.RefRecStatusID,
    rrs.Name AS Status
FROM ScriptAdapter.tScriptConfigurationHistory sch
INNER JOIN ScriptAdapter.tScriptConfiguration sc ON sch.ScriptConfigurationID = sc.ScriptConfigurationID
INNER JOIN dbo.tRefRecStatus rrs ON sch.RefRecStatusID = rrs.RefRecStatusID
WHERE sc.Name LIKE '%InstDebt%'
ORDER BY sch.CreatedDate DESC;

GO
