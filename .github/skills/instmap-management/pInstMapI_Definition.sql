CREATE PROCEDURE dbo.pInstMapI
	@IDs varchar(8000) 
	,@Comment varchar(8000) = NULL
	,@CreatedUser varchar(100) = NULL
AS
BEGIN
	SET NOCOUNT ON ;    
	SET TRANSACTION ISOLATION LEVEL READ COMMITTED ;    
    
	DECLARE @TranCounter int ;    
	SET @TranCoun
ter = @@TRANCOUNT ;    
    
	DECLARE @tab_IDs TABLE (id int UNIQUE NOT NULL) ;    
    
	DECLARE @cur_num_groups int ;    
	DECLARE @cur_existing_ids int ;    
    
	DECLARE @merge_groups TABLE (id int NOT NULL) ;    
    
	DECLARE @dest_group_id int ;  
  
    
	if @CreatedUser is null set @CreatedUser=suser_sname()    
	-- Split the records ...    
	INSERT INTO @tab_IDs (id)    
	SELECT DISTINCT row    
	FROM dbo.fnCOMSplitTableT(@IDs, ',')    
	WHERE LEN(row) > 0 ;    
    
	--************ BEGIN SECTIO
N ****** Added by MD on 03/21/2016    
	--Before doing anything else, make sure that indicated mappings will not result in more than one Core record per group    
	DECLARE @CoreRecords TABLE (ID INT)    
    
	INSERT INTO @CoreRecords    
	SELECT id FROM 
@tab_IDs WHERE id BETWEEN 1 AND 999999999    
    
	INSERT INTO @CoreRecords    
	SELECT PKID FROM dbo.tInstMap WHERE RefRecStatusID = 1 AND EffThruDate = '9999-01-01' AND PKID BETWEEN 1 AND 999999999 AND GroupID IN ( 
		SELECT GroupID FROM dbo.tInstMap W
HERE RefRecStatusID = 1 AND EffThruDate = '9999-01-01' AND PKID IN (    
			SELECT id FROM @tab_IDs    
		)
	)    
    
	IF (SELECT COUNT(DISTINCT ID) FROM @CoreRecords) > 1    
	BEGIN    
	 	 DECLARE @FailedID nvarchar(255), @FailureMessage nvarchar(512)

  		SELECT TOP 1 @FailedID = LTRIM(ID) from @CoreRecords
		SELECT @FailureMessage = 'Indicated mappings would create a group with more than one Core record. This is not allowed - please review your mappings and correct. Note: some mappings may need to be
 deleted before the desired action can be taken.'
							+ @FailedID + ' Ids: ' + @IDs 
		RAISERROR (@FailureMessage, 18, 128) WITH SETERROR;    
		RETURN @@ERROR;    
	END    
	--************ END SECTION ****** Added by MD on 03/21/2016    
    
	IF @Tra
nCounter > 0    
		SAVE TRANSACTION pInstMapI_SAVE ;    
	ELSE    
		BEGIN TRANSACTION    
    
	BEGIN TRY    
		-- Find any existing groups ...    
		SELECT @cur_num_groups =    
			ISNULL(COUNT(DISTINCT GroupID), 0)    
		FROM dbo.vInstMapRaw    
		WHER
E    
			PKID IN (SELECT id FROM @tab_IDs)    
			AND    
			RefRecStatusID = 1 ;    
    
		-- Find any existing IDs that are already in dbo.vInstMapRaw    
		SELECT @cur_existing_ids =    
			ISNULL(COUNT(*), 0)    
		FROM dbo.vInstMapRaw    
		WHERE   
 
			PKID IN (SELECT id FROM @tab_IDs)    
			AND    
			RefRecStatusID = 1 ;    
    
		-- If we are not actually mapping anything, just return ...    
		IF (@cur_num_groups = 0) AND (@cur_existing_ids = (SELECT ISNULL(COUNT(DISTINCT id), 0) FROM @tab_ID
s))    
			RETURN ;    
    
		-- Determine the GroupID for the mappings ...    
		IF @cur_num_groups > 0    
		BEGIN    
			-- Use an existing group for the mappings ...    
			SELECT @dest_group_id = MAX(GroupID) -- This is actually the oldest group ins
erted ...    
			FROM dbo.vInstMapRaw    
			WHERE    
				PKID IN (SELECT id FROM @tab_IDs)    
				AND    
				RefRecStatusID = 1    
    
			-- Carry over some mappings ...    
			INSERT INTO @tab_IDs (id)    
			SELECT DISTINCT PKID    
			FROM dbo.vI
nstMapRaw    
			WHERE    
				RefRecStatusID = 1    
				AND    
				GroupID IN (    
					SELECT DISTINCT GroupID    
					FROM dbo.vInstMapRaw    
					WHERE    
						GroupID <> @dest_group_id     
						AND    
						PKID IN (SELECT id FROM @tab_IDs)
    
						AND    
						RefRecStatusID = 1    
				)    
				AND    
				PKID NOT IN (SELECT id FROM @tab_IDs)    
    
			-- Remove any old groups ..    
			UPDATE dbo.vInstMapRaw    
			SET RefRecStatusID = 2 , EffThruDate = GETDATE()    
			WHERE    

				RefRecStatusID = 1    
				AND    
				PKID IN (SELECT id FROM @tab_IDs)    
				AND    
				GroupID <> @dest_group_id    
		END    
		ELSE    
		BEGIN    
			-- Just get the smallest GroupID - 1 (like an identity) ...    
			SELECT @dest_group_id = I
SNULL(MIN(GroupID), 0) - 1    
			FROM dbo.vInstMapRaw    
		END

		IF @dest_group_id IS NULL AND (NOT EXISTS (SELECT * FROM dbo.vInstMapRaw WHERE GroupId = -1))
			SET @dest_group_id = -1
    
		-- Insert the mappings into the GroupID ...    
		INSERT IN
TO dbo.vInstMapRaw (PKID , GroupID , EffFromDate , EffThruDate , RefRecStatusID, CreatedUser)    
		SELECT DISTINCT id , @dest_group_id , GETDATE() , '9999-01-01' , 1, @CreatedUser    
		FROM @tab_IDs    
		WHERE -- Where not already in our destination gr
oup ...    
			id NOT IN (SELECT DISTINCT PKID FROM dbo.vInstMapRaw WHERE RefRecStatusID = 1 AND GroupID = @dest_group_id)    
    
		IF @TranCounter = 0    
			COMMIT TRANSACTION    
	END TRY    
    
	BEGIN CATCH    
		IF @TranCounter = 0    
			ROLLBAC
K TRANSACTION    
		ELSE    
			IF XACT_STATE() <> -1    
				ROLLBACK TRANSACTION pInstMapI_SAVE ;    
    
		RAISERROR (
			'ERROR in Reference.dbo.pInstMapI', -- Message text.    
			11, -- Severity.    
			1 -- State.    
		);    
	END CATCH    
    

END
